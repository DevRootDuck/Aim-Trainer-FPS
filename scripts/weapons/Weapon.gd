extends Node3D
class_name Weapon

# ============================================================
# Weapon (classe base)
#
# Gerencia disparo hitscan, munição/recarga, recoil vertical,
# padrão de spray, bloom (dispersão progressiva ao segurar o
# gatilho), flash do cano, marcas de bala, hitmarker e headshot.
#
# Para criar uma nova arma: crie uma cena que estenda esta (ou
# duplique RifleAX.tscn) e ajuste os valores @export ou sobrescreva
# _build_model()/get_spray_pattern() para um comportamento único.
# ============================================================

@export var weapon_name: String = "Arma"
@export var magazine_size: int = 30
@export var fire_rate: float = 0.11          # segundos entre disparos (automática)
@export var reload_time: float = 1.6
@export var max_range: float = 150.0
@export var damage: int = 1
@export var automatic: bool = true

@export_group("Recoil / Spray / Bloom")
@export var recoil_kick_deg: float = 1.1     # chute vertical por tiro
@export var recoil_recover_speed: float = 9.0
@export var bloom_per_shot_deg: float = 0.35
@export var bloom_max_deg: float = 4.0
@export var bloom_recover_speed: float = 6.0
@export var base_spread_deg: float = 0.15

signal ammo_changed(current: int, max_ammo: int)
signal weapon_fired
signal reload_started(duration: float)
signal reload_finished
signal target_hit(is_headshot: bool)

var camera: Camera3D
var player: Node3D
var current_ammo: int
var is_reloading: bool = false
var _can_shoot: bool = true
var _shots_since_rest: int = 0
var _current_bloom_deg: float = 0.0
var _recoil_pitch_deg: float = 0.0
var _model_root: Node3D
var _muzzle_point: Node3D
var _rng := RandomNumberGenerator.new()
var _is_local: bool = true  # falso para a arma de um jogador remoto (multiplayer)
var _last_hit_position: Vector3 = Vector3.ZERO
var _last_hit_normal: Vector3 = Vector3.ZERO


func _ready() -> void:
	_rng.randomize()
	current_ammo = magazine_size
	# owner é a raiz da cena instanciada a que este nó pertence — ou seja,
	# sempre o Player "dono" desta arma, mesmo quando várias cópias de
	# Player (uma por jogador conectado) existem ao mesmo tempo em rede.
	# Isso evita o bug de todo mundo pegar "o jogador"/"a arma" errados
	# via busca por grupo, que só existe uma vez globalmente.
	player = owner
	_is_local = (not NetworkManager.is_multiplayer_active) or (player == null) or player.is_multiplayer_authority()
	if _is_local:
		add_to_group("weapon")
		camera = get_viewport().get_camera_3d()
	emit_signal("ammo_changed", current_ammo, magazine_size)
	_build_model()


func _process(delta: float) -> void:
	if not _is_local:
		return
	# Recupera bloom e o "pitch" acumulado de recoil suavemente com o tempo
	_current_bloom_deg = move_toward(_current_bloom_deg, 0.0, bloom_recover_speed * delta)
	_recoil_pitch_deg = move_toward(_recoil_pitch_deg, 0.0, recoil_recover_speed * delta)
	if not Input.is_action_pressed("shoot"):
		_shots_since_rest = 0

	# Disparo automático: precisa ser checado a cada frame (polling), já
	# que _input()/_unhandled_input() só disparam quando um NOVO evento
	# chega — segurar o botão parado não gera eventos repetidos.
	if automatic and GameManager.current_state != GameManager.GameState.PAUSED and Input.is_action_pressed("shoot"):
		try_shoot()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local:
		return
	if event.is_action_pressed("shoot") and not automatic:
		try_shoot()
	if event.is_action_pressed("reload"):
		try_reload()


func try_shoot() -> void:
	if not _is_local:
		return
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	if is_reloading or not _can_shoot:
		return
	if current_ammo <= 0:
		try_reload()
		return

	current_ammo -= 1
	_shots_since_rest += 1
	emit_signal("ammo_changed", current_ammo, magazine_size)
	emit_signal("weapon_fired")
	GameManager.register_shot()

	_fire_raycast()
	_play_muzzle_effects()
	_apply_recoil_and_bloom()
	if NetworkManager.is_multiplayer_active:
		_request_remote_fire_fx.rpc_id(1, _last_hit_position, _last_hit_normal)

	_can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	_can_shoot = true


@rpc("any_peer")
func _request_remote_fire_fx(hit_pos: Vector3, hit_normal: Vector3) -> void:
	# Recebido pelo host: repassa pra todo mundo tocar o flash/som do
	# tiro de um colega de equipe e o efeito de impacto (visual/áudio
	# apenas — a validação do acerto em si acontece separadamente, em
	# Target.gd).
	if not multiplayer.is_server():
		return
	_broadcast_fire_fx.rpc(hit_pos, hit_normal)


@rpc("authority", "call_local")
func _broadcast_fire_fx(hit_pos: Vector3, hit_normal: Vector3) -> void:
	if _is_local:
		return  # o atirador já tocou os efeitos localmente na hora do disparo
	_play_muzzle_effects()
	if hit_normal != Vector3.ZERO:
		_spawn_impact_effect(hit_pos, hit_normal)


func _apply_recoil_and_bloom() -> void:
	_recoil_pitch_deg += recoil_kick_deg
	_current_bloom_deg = min(_current_bloom_deg + bloom_per_shot_deg, bloom_max_deg)

	if player and player.has_method("apply_weapon_recoil"):
		player.apply_weapon_recoil(deg_to_rad(recoil_kick_deg))

	if _model_root:
		var kick_tween := create_tween()
		kick_tween.tween_property(_model_root, "position:z", 0.08, 0.03)
		kick_tween.parallel().tween_property(_model_root, "rotation:x", deg_to_rad(-6.0), 0.03)
		kick_tween.tween_property(_model_root, "position:z", 0.0, 0.12)
		kick_tween.parallel().tween_property(_model_root, "rotation:x", 0.0, 0.12)


func get_current_spread_deg() -> float:
	return base_spread_deg + _current_bloom_deg


func _fire_raycast() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return

	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var ray_from: Vector3 = camera.project_ray_origin(screen_center)
	var base_dir: Vector3 = camera.project_ray_normal(screen_center)

	# Aplica dispersão (spread/bloom) como um pequeno desvio aleatório no cone de tiro
	var spread_rad: float = deg_to_rad(get_current_spread_deg())
	var dir: Vector3 = base_dir
	if spread_rad > 0.0:
		var rand_yaw: float = _rng.randf_range(-spread_rad, spread_rad)
		var rand_pitch: float = _rng.randf_range(-spread_rad, spread_rad)
		dir = base_dir.rotated(camera.global_transform.basis.y, rand_yaw)
		dir = dir.rotated(camera.global_transform.basis.x, rand_pitch)

	var ray_to: Vector3 = ray_from + dir * max_range

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 | 8  # bit 0 (mundo, layer 1) + bit 3 (hurtboxes, layer 4)
	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		_spawn_impact_effect(result.position, result.normal)
		_last_hit_position = result.position
		_last_hit_normal = result.normal
		var collider = result.collider
		var is_headshot := false
		if collider and collider.has_method("is_head_hit"):
			is_headshot = collider.is_head_hit(result.position)
		if collider and collider.has_method("register_hit"):
			collider.register_hit(is_headshot)
			AudioManager.play_sfx_3d("headshot" if is_headshot else "impact", result.position)
			emit_signal("target_hit", is_headshot)
		else:
			GameManager.register_miss()
	else:
		_last_hit_normal = Vector3.ZERO
		GameManager.register_miss()


func _spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	var impact_scene: PackedScene = load("res://scenes/effects/ImpactEffect.tscn")
	var impact := impact_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	if normal != Vector3.ZERO:
		impact.look_at(pos + normal, Vector3.UP if abs(normal.y) < 0.99 else Vector3.RIGHT)


func _play_muzzle_effects() -> void:
	AudioManager.play_sfx_3d("shot", global_position)
	if _muzzle_point:
		_flash_muzzle()


func _flash_muzzle() -> void:
	# Flash simples: uma OmniLight temporária + partícula gerada em código
	var light := OmniLight3D.new()
	light.light_energy = 6.0
	light.omni_range = 3.0
	light.light_color = Color(1.0, 0.7, 0.3)
	_muzzle_point.add_child(light)
	var t := create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.06)
	t.tween_callback(light.queue_free)

	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 20.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.03
	mat.scale_max = 0.07
	mat.color = Color(1.0, 0.8, 0.4)
	particles.process_material = mat
	particles.draw_pass_1 = BoxMesh.new()
	particles.amount = 8
	particles.lifetime = 0.12
	particles.one_shot = true
	particles.emitting = true
	_muzzle_point.add_child(particles)
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)


func try_reload() -> void:
	if not _is_local:
		return
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	if is_reloading or current_ammo == magazine_size:
		return
	is_reloading = true
	emit_signal("reload_started", reload_time)
	AudioManager.play_sfx_3d("reload", global_position)

	if _model_root:
		var t := create_tween()
		t.tween_property(_model_root, "rotation:x", deg_to_rad(18.0), reload_time * 0.4)
		t.tween_property(_model_root, "rotation:x", 0.0, reload_time * 0.5)

	await get_tree().create_timer(reload_time).timeout

	current_ammo = magazine_size
	is_reloading = false
	emit_signal("ammo_changed", current_ammo, magazine_size)
	emit_signal("reload_finished")


# ---------------- Modelo procedural (100% original, sem assets externos) ----------------

func _build_model() -> void:
	# Implementado pelas subclasses (ex: RifleAX). Mantido aqui como fallback
	# simples para que a classe base também funcione sozinha.
	_model_root = Node3D.new()
	add_child(_model_root)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.scale = Vector3(0.08, 0.08, 0.35)
	_model_root.add_child(body)
	_muzzle_point = Node3D.new()
	_muzzle_point.position = Vector3(0, 0, -0.4)
	_model_root.add_child(_muzzle_point)
