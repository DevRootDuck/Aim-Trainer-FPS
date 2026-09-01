extends CharacterBase
class_name Target

# ============================================================
# Target
#
# Alvo de treino com IA simples baseada em estados (FSM):
# aparece em posição aleatória, pode ficar parado, andar, correr,
# agachar, pular ocasionalmente, esconder-se atrás de obstáculos
# e voltar para outra posição — tudo de forma aleatória e
# adaptada ao modo de treino atual (GameManager.current_mode).
#
# MULTIPLAYER: em uma sessão em rede, o HOST é sempre a autoridade
# — só ele roda a IA (movimento, timers, decisões). Os clientes só
# recebem a posição/rotação/estado replicados (MultiplayerSynchronizer)
# e mostram isso; quando o cliente acerta um tiro, ele pede
# confirmação ao host via RPC antes de aplicar o efeito, para que
# dois jogadores não consigam "matar" o mesmo alvo ao mesmo tempo.
# Em modo solo, tudo roda localmente como sempre (is_multiplayer_
# active fica false e nenhum código de rede é acionado).
# ============================================================

signal target_hit
signal target_expired

enum AIState { IDLE, WALK, RUN, CROUCH, HIDDEN }

@export var move_speed: float = 2.0
@export var can_move: bool = true
@export var can_hide: bool = true

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var state_timer: Timer = $StateTimer
@onready var body_collision: CollisionShape3D = $BodyCollisionShape

var spawn_time: float = 0.0
var is_active: bool = false
var _ai_state: AIState = AIState.IDLE
var _synced_speed_ratio: float = 0.0
var _move_target: Vector3
var _spawn_bounds: AABB
var _obstacle_points: Array = []
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


var _character_id_preset: bool = false


func _ready() -> void:
	if not _character_id_preset:
		character_id = ["eva", "adao"][randi() % 2]
	super._ready()
	_build_physics_shape()
	monitoring_setup()
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	state_timer.timeout.connect(_on_state_timeout)
	hide_target()
	if NetworkManager.is_multiplayer_active:
		_setup_network_sync()


func set_character_before_spawn(id: String) -> void:
	# Chamado pela Arena ANTES de add_child(), pra que todo mundo em rede
	# veja o mesmo personagem no mesmo alvo (em vez de cada peer sortear
	# o seu, já que cada cópia roda seu próprio _ready()).
	character_id = id
	_character_id_preset = true


func _setup_network_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	for prop in [".:position", ".:rotation", ".:scale", ".:visible", ".:is_active",
			".:_ai_state", ".:_synced_speed_ratio", ".:character_id",
			"BodyCollisionShape:disabled", "HeadHurtbox:monitoring", "BodyHurtbox:monitoring"]:
		config.add_property(NodePath(prop))
	sync.replication_config = config
	add_child(sync)


func _build_physics_shape() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	body_collision.shape = shape
	body_collision.position = Vector3(0, 0.95, 0)


func monitoring_setup() -> void:
	head_hurtbox.monitoring = true
	body_hurtbox.monitoring = true


func set_obstacle_cover_points(points: Array) -> void:
	_obstacle_points = points


func activate(spawn_area: AABB) -> void:
	# Só o host (ou o próprio jogador em modo solo) decide isso — ver
	# comentário no topo do arquivo e o guard em Arena.gd que só chama
	# activate() do lado do servidor.
	_spawn_bounds = spawn_area
	var random_pos := Vector3(
	randf_range(spawn_area.position.x, spawn_area.end.x),
		spawn_area.position.y + 1.5,
		randf_range(spawn_area.position.z, spawn_area.end.z)
	)
	global_position = random_pos
	reset_visual()

	var settings: Dictionary = GameManager.get_current_settings()
	var mode: int = GameManager.current_mode

	scale = Vector3.ONE * settings["target_scale"]
	move_speed = settings["move_speed"]
	can_move = mode in [GameManager.TrainMode.MOVING, GameManager.TrainMode.SURVIVAL, GameManager.TrainMode.REFLEX]
	can_hide = mode in [GameManager.TrainMode.MOVING, GameManager.TrainMode.SURVIVAL]

	spawn_time = Time.get_ticks_msec() / 1000.0
	is_active = true
	show_target()

	var lifetime: float = settings["target_lifetime"]
	if mode == GameManager.TrainMode.REFLEX:
		lifetime *= 0.55
	elif mode == GameManager.TrainMode.STATIC:
		lifetime *= 1.6
	lifetime_timer.wait_time = max(lifetime, 0.3)
	lifetime_timer.start()

	_ai_state = AIState.IDLE
	_queue_next_state()


func register_hit(is_headshot: bool) -> void:
	if not is_active:
		return
	if NetworkManager.is_multiplayer_active:
		# Trava otimista local (evita o mesmo cliente disparar vários
		# pedidos enquanto aguarda a confirmação do host) + pede ao host
		# que valide e confirme o acerto pra todo mundo.
		is_active = false
		var shooter_id: int = multiplayer.get_unique_id()
		_request_hit_confirmation.rpc_id(1, is_headshot, shooter_id)
	else:
		_apply_hit(is_headshot, -1)


@rpc("any_peer")
func _request_hit_confirmation(is_headshot: bool, shooter_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not is_active:
		return  # outro tiro quase simultâneo já confirmou isso
	is_active = false
	_confirm_hit.rpc(is_headshot, shooter_id)


@rpc("authority", "call_local")
func _confirm_hit(is_headshot: bool, shooter_id: int) -> void:
	_apply_hit(is_headshot, shooter_id)


func _apply_hit(is_headshot: bool, shooter_id: int) -> void:
	is_active = false
	lifetime_timer.stop()
	state_timer.stop()

	var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - spawn_time
	var is_my_shot: bool = (not NetworkManager.is_multiplayer_active) or (shooter_id == multiplayer.get_unique_id())
	if is_my_shot:
		var counts_for_mode: bool = (GameManager.current_mode != GameManager.TrainMode.HEADSHOT_ONLY) or is_headshot
		if counts_for_mode:
			GameManager.register_hit(reaction_time, is_headshot)
		else:
			GameManager.register_miss()

	flash_hit(is_headshot)
	play_death()
	emit_signal("target_hit")


func is_head_hit(_pos: Vector3) -> bool:
	return false  # a decisão real acontece na Hurtbox; ver Hurtbox.gd


func _on_lifetime_timeout() -> void:
	if NetworkManager.is_multiplayer_active and not is_multiplayer_authority():
		return
	if is_active:
		is_active = false
		state_timer.stop()
		emit_signal("target_expired")
		hide_target()


func show_target() -> void:
	visible = true
	body_collision.disabled = false


func hide_target() -> void:
	visible = false
	body_collision.disabled = true


func _physics_process(delta: float) -> void:
	if NetworkManager.is_multiplayer_active and not is_multiplayer_authority():
		# Cliente: só reproduz a animação com base no estado replicado;
		# a posição/rotação de verdade já chega via MultiplayerSynchronizer.
		set_move_animation(_synced_speed_ratio, delta)
		set_crouch_visual(_ai_state == AIState.CROUCH, delta)
		return

	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	if not is_active or not can_move:
		set_move_animation(0.0, delta)
		_synced_speed_ratio = 0.0
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var to_target: Vector3 = _move_target - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	var speed_mult: float = 1.6 if _ai_state == AIState.RUN else (0.0 if _ai_state == AIState.CROUCH else 1.0)
	var current_speed: float = move_speed * speed_mult

	if dist > 0.2 and _ai_state != AIState.CROUCH and _ai_state != AIState.HIDDEN:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * current_speed
		velocity.z = dir.z * current_speed
		look_at(global_position + dir, Vector3.UP)
		set_move_animation(speed_mult, delta)
		_synced_speed_ratio = speed_mult
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)
		set_move_animation(0.0, delta)
		_synced_speed_ratio = 0.0

	set_crouch_visual(_ai_state == AIState.CROUCH, delta)
	move_and_slide()


func _queue_next_state() -> void:
	state_timer.wait_time = randf_range(1.0, 3.0)
	state_timer.start()


func _on_state_timeout() -> void:
	if NetworkManager.is_multiplayer_active and not is_multiplayer_authority():
		return
	if not is_active:
		return
	_pick_new_ai_state()
	_queue_next_state()


func _pick_new_ai_state() -> void:
	var roll: float = randf()
	if can_hide and roll < 0.15 and not _obstacle_points.is_empty():
		_ai_state = AIState.HIDDEN
		_move_target = _obstacle_points[randi() % _obstacle_points.size()]
	elif roll < 0.35:
		_ai_state = AIState.CROUCH
		_move_target = global_position
	elif roll < 0.45 and is_on_floor():
		velocity.y = 4.2  # pulo ocasional
		_ai_state = AIState.WALK
		_pick_random_move_target()
	elif can_move and roll < 0.75:
		_ai_state = AIState.WALK
		_pick_random_move_target()
	elif can_move:
		_ai_state = AIState.RUN
		_pick_random_move_target()
	else:
		_ai_state = AIState.IDLE
		_move_target = global_position


func _pick_random_move_target() -> void:
	_move_target = Vector3(
		randf_range(_spawn_bounds.position.x, _spawn_bounds.end.x),
		global_position.y,
		randf_range(_spawn_bounds.position.z, _spawn_bounds.end.z)
	)
