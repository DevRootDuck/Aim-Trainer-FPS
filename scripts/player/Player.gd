extends CharacterBody3D

# ============================================================
# Player
#
# Controlador de movimento em primeira pessoa moderno:
# WASD + mouse look 360°, pulo, corrida, agachamento, head bob,
# inclinação de câmera ao correr, FOV dinâmico, aceleração e
# desaceleração suaves. O cursor é travado e escondido assim que
# a cena carrega — sem necessidade de clicar para começar a olhar.
#
# Estrutura de nós esperada (ver Player.tscn):
# Player (CharacterBody3D)
#  ├── CollisionShape3D   (CapsuleShape3D)
#  ├── Head (Node3D)                 -> yaw do corpo é feito no próprio Player
#  │    └── Camera3D                 -> pitch + roll (lean) + headbob + FOV
#  │         └── WeaponHolder (Node3D)
#  └── FootstepTimer (Timer)
# ============================================================

@export var walk_speed: float = 5.0
@export var run_speed: float = 8.5
@export var crouch_speed: float = 2.5
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 4.6
@export var air_control: float = 0.3

@export var base_fov: float = 90.0
@export var run_fov_add: float = 8.0
@export var fov_lerp_speed: float = 8.0

@export var lean_max_deg: float = 3.0
@export var lean_lerp_speed: float = 6.0

@export var bob_walk_speed: float = 10.0
@export var bob_walk_amount: float = 0.045
@export var bob_run_speed: float = 14.0
@export var bob_run_amount: float = 0.08

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var footstep_timer: Timer = $FootstepTimer

var standing_height: float = 1.8
var crouching_height: float = 1.0
var is_crouching: bool = false
var is_running: bool = false
var current_speed: float

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _camera_base_local_y: float = 0.0
var _bob_time: float = 0.0
var _mouse_delta_accum: Vector2 = Vector2.ZERO
var _smoothed_mouse: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	# Em multiplayer, o servidor nomeia cada Player spawnado com o peer id
	# (ex: "42"), e cada cliente usa isso pra descobrir qual cópia é a
	# "sua" (is_multiplayer_authority() só é true para o dono). Em modo
	# solo o nome continua "Player" (não numérico) e nada disso se aplica
	# — o comportamento de sempre-autoridade do single-player é mantido.
	if name.is_valid_int():
		set_multiplayer_authority(int(name))
	if is_multiplayer_authority():
		add_to_group("player")


func _ready() -> void:
	if is_multiplayer_authority():
		current_speed = walk_speed
		_camera_base_local_y = camera.position.y

		# Mouse controla a câmera imediatamente, sem precisar clicar.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true

		footstep_timer.timeout.connect(_on_footstep_timeout)
	else:
		_setup_remote_avatar()

	if NetworkManager.is_multiplayer_active:
		_setup_network_sync()


func _setup_remote_avatar() -> void:
	# Cópia de outro jogador na rede: sem input, sem câmera própria — só
	# mostra um corpo (Adão/Eva) na posição sincronizada, pra dar pra ver
	# os amigos andando/atirando na arena.
	set_physics_process(false)
	set_process(false)
	var info: Dictionary = NetworkManager.players.get(int(name), {})
	var avatar := CharacterBase.new()
	avatar.character_id = info.get("character", "eva")
	var head_hurtbox := Area3D.new()
	head_hurtbox.name = "HeadHurtbox"
	head_hurtbox.monitoring = false
	avatar.add_child(head_hurtbox)
	var body_hurtbox := Area3D.new()
	body_hurtbox.name = "BodyHurtbox"
	body_hurtbox.monitoring = false
	avatar.add_child(body_hurtbox)
	add_child(avatar)


func _setup_network_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	config.add_property(NodePath("Head:rotation"))
	sync.replication_config = config
	add_child(sync)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta_accum += event.relative


func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	_apply_mouse_look(delta)
	_apply_fov(delta)
	_apply_lean(delta)
	_apply_headbob(delta)


func _apply_mouse_look(delta: float) -> void:
	if _mouse_delta_accum == Vector2.ZERO and _smoothed_mouse == Vector2.ZERO:
		return

	var sens: float = SettingsManager.get_value("mouse", "sensitivity")
	var invert_y: bool = SettingsManager.get_value("mouse", "invert_y")
	var smoothing: float = SettingsManager.get_value("mouse", "smoothing")

	var target: Vector2 = _mouse_delta_accum
	_mouse_delta_accum = Vector2.ZERO

	if smoothing > 0.0:
		# Suavização exponencial: evita tremidas mantendo resposta rápida
		var factor: float = clamp(1.0 - smoothing, 0.02, 1.0)
		_smoothed_mouse = _smoothed_mouse.lerp(target, clamp(factor * 60.0 * delta, 0.05, 1.0))
	else:
		_smoothed_mouse = target

	var move: Vector2 = _smoothed_mouse
	rotate_y(-move.x * sens)

	var y_sign := 1.0 if invert_y else -1.0
	head.rotate_x(move.y * sens * y_sign)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _apply_fov(delta: float) -> void:
	var target_fov: float = base_fov
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if is_running and input_dir != Vector2.ZERO and is_on_floor() and not is_crouching:
		target_fov += run_fov_add
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)


func _apply_lean(delta: float) -> void:
	var strafe: float = Input.get_axis("move_left", "move_right")
	var target_roll_deg: float = 0.0
	if is_running and is_on_floor():
		target_roll_deg = -strafe * lean_max_deg
	camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(target_roll_deg), delta * lean_lerp_speed)


func _apply_headbob(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.2 and is_on_floor()

	var bob_speed: float = bob_run_speed if is_running else bob_walk_speed
	var bob_amount: float = bob_run_amount if is_running else bob_walk_amount
	if is_crouching:
		bob_amount *= 0.5

	if moving:
		_bob_time += delta * bob_speed
	else:
		_bob_time = lerp(_bob_time, 0.0, delta * 6.0)

	var offset: float = sin(_bob_time) * bob_amount if moving else 0.0
	camera.position.y = lerp(camera.position.y, _camera_base_local_y + offset, delta * 12.0)


func _physics_process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	_handle_gravity(delta)
	_handle_jump()
	_handle_crouch(delta)
	_handle_movement(delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity


func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	var target_height: float = crouching_height if is_crouching else standing_height
	var shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if shape:
		shape.height = lerp(shape.height, target_height, delta * 10.0)
		collision_shape.position.y = shape.height / 2.0


func _handle_movement(delta: float) -> void:
	is_running = Input.is_action_pressed("run") and not is_crouching

	if is_crouching:
		current_speed = crouch_speed
	elif is_running:
		current_speed = run_speed
	else:
		current_speed = walk_speed

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var accel: float = acceleration if is_on_floor() else acceleration * air_control
	var decel: float = deceleration if is_on_floor() else deceleration * air_control

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta * current_speed)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta * current_speed)
		_update_footsteps(true)
	else:
		velocity.x = move_toward(velocity.x, 0, decel * delta * current_speed)
		velocity.z = move_toward(velocity.z, 0, decel * delta * current_speed)
		_update_footsteps(false)


func _update_footsteps(moving: bool) -> void:
	if moving and is_on_floor():
		if footstep_timer.is_stopped():
			var interval: float = 0.55 if is_running else (0.8 if not is_crouching else 1.0)
			footstep_timer.wait_time = interval
			footstep_timer.start()
	else:
		footstep_timer.stop()


func apply_weapon_recoil(pitch_radians: float) -> void:
	# Chamado pela arma a cada tiro: empurra a câmera levemente para cima.
	# É somado à rotação do Head; a suavização de retorno é natural porque
	# o próximo movimento do mouse simplesmente parte desse novo ângulo.
	head.rotation.x = clamp(head.rotation.x - pitch_radians, deg_to_rad(-89.0), deg_to_rad(89.0))


func _on_footstep_timeout() -> void:
	AudioManager.play_sfx_3d("footstep", global_position)
	if is_on_floor() and (Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO):
		var interval: float = 0.55 if is_running else (0.8 if not is_crouching else 1.0)
		footstep_timer.wait_time = interval
		footstep_timer.start()
