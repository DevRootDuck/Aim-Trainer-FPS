extends Node3D

# ============================================================
# Arena
#
# Cena principal do treino. Constrói proceduralmente uma arena
# própria e original (área aberta, área fechada, corredor, rampa,
# plataforma com escada, pilares, caixas e barris em distâncias
# variadas), gerencia o spawn dos alvos (Adão/Eva) conforme o
# modo de treino, cuida da pausa (ESC) e da iluminação leve
# otimizada para hardware modesto.
#
# Estrutura de nós esperada (ver Arena.tscn):
# Arena
#  ├── Player          (instância de Player.tscn)
#  ├── World            (Node3D vazio -> geometria procedural entra aqui)
#  ├── TargetsContainer (Node3D, guarda os alvos instanciados)
#  ├── HUD              (instância de HUD.tscn)
#  └── PauseMenu         (instância de PauseMenu.tscn, escondida por padrão)
# ============================================================

const TARGET_SCENE: PackedScene = preload("res://scenes/targets/Target.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

@export var spawn_area_size: Vector3 = Vector3(22, 3, 30)
@export var spawn_area_center: Vector3 = Vector3(0, 0.0, -8)

@onready var targets_container: Node3D = $TargetsContainer
@onready var world_root: Node3D = $World
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var directional_light: DirectionalLight3D = $World/Lighting/SunLight
@onready var static_player: Node = $Player  # usado só fora do multiplayer
@onready var hud: CanvasLayer = $HUD

var players_container: Node3D
var active_targets: Array = []
var _cover_points: Array = []
var _is_paused: bool = false


func _ready() -> void:
	_build_arena_geometry()
	_setup_lighting()
	AudioManager.play_music()

	if NetworkManager.is_multiplayer_active:
		_setup_multiplayer()
	else:
		var settings: Dictionary = GameManager.get_current_settings()
		for i in settings["max_targets"]:
			_spawn_new_target()

	SettingsManager.settings_changed.connect(_on_settings_changed)
	GameManager.current_state = GameManager.GameState.PLAYING
	pause_menu.visible = false


func _setup_multiplayer() -> void:
	# Em coop, cada jogador conectado tem seu próprio Player em rede
	# (nomeado com o peer id, ver Player.gd); o Player estático que já
	# vinha na cena (usado no modo solo) não é necessário aqui.
	if is_instance_valid(static_player):
		static_player.queue_free()

	players_container = Node3D.new()
	players_container.name = "PlayersContainer"
	add_child(players_container)

	var target_spawner := MultiplayerSpawner.new()
	target_spawner.spawn_path = targets_container.get_path()
	target_spawner.add_spawnable_scene("res://scenes/targets/Target.tscn")
	add_child(target_spawner)

	var player_spawner := MultiplayerSpawner.new()
	player_spawner.spawn_path = players_container.get_path()
	player_spawner.add_spawnable_scene("res://scenes/player/Player.tscn")
	player_spawner.spawned.connect(_on_player_spawned)
	add_child(player_spawner)

	# Só o host decide quando/onde alvos e jogadores aparecem — os
	# clientes só recebem tudo replicado automaticamente pelos
	# MultiplayerSpawners acima.
	if multiplayer.is_server():
		var settings: Dictionary = GameManager.get_current_settings()
		for i in settings["max_targets"]:
			_spawn_new_target()
		_spawn_all_players()


func _on_player_spawned(node: Node) -> void:
	# Chamado tanto localmente (quando o host cria os Players) quanto
	# quando a réplica chega via rede num cliente — em qualquer um dos
	# casos, é aqui que sabemos com certeza que a arma do jogador local
	# já existe de verdade, então conectamos a HUD a ela agora.
	if not node.is_multiplayer_authority():
		return
	var weapon: Node = node.get_node_or_null("Head/Camera3D/WeaponHolder/RifleAX")
	if weapon and hud:
		hud.bind_to_weapon(weapon)


func _spawn_all_players() -> void:
	var peer_ids: Array = NetworkManager.players.keys()
	var positions: Array = _get_player_spawn_positions(peer_ids.size())
	for i in peer_ids.size():
		_spawn_player(peer_ids[i], positions[i])


func _spawn_player(peer_id: int, spawn_pos: Vector3) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = spawn_pos
	players_container.add_child(player)


func _get_player_spawn_positions(count: int) -> Array:
	var positions: Array = []
	var n: int = max(count, 1)
	var radius: float = 3.0
	for i in n:
		var angle: float = TAU * float(i) / float(n)
		positions.append(Vector3(sin(angle) * radius, 0.2, 6.0 + cos(angle) * radius))
	return positions


func _process(delta: float) -> void:
	if not _is_paused:
		GameManager.update_timer(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	_is_paused = not _is_paused
	GameManager.current_state = GameManager.GameState.PAUSED if _is_paused else GameManager.GameState.PLAYING
	pause_menu.visible = _is_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_paused else Input.MOUSE_MODE_CAPTURED


func _get_spawn_bounds() -> AABB:
	var half: Vector3 = spawn_area_size / 2.0
	return AABB(spawn_area_center - half, spawn_area_size)


func _spawn_new_target() -> void:
	if NetworkManager.is_multiplayer_active and not multiplayer.is_server():
		return
	var target = TARGET_SCENE.instantiate()
	target.set_character_before_spawn(["eva", "adao"][randi() % 2])
	targets_container.add_child(target)
	target.set_obstacle_cover_points(_cover_points)
	target.target_hit.connect(_on_target_resolved.bind(target))
	target.target_expired.connect(_on_target_resolved.bind(target))
	target.activate(_get_spawn_bounds())
	active_targets.append(target)


func _on_target_resolved(target: Node) -> void:
	if NetworkManager.is_multiplayer_active and not multiplayer.is_server():
		return
	var settings: Dictionary = GameManager.get_current_settings()
	await get_tree().create_timer(settings["spawn_interval"] * 0.3).timeout
	if is_instance_valid(target):
		target.activate(_get_spawn_bounds())


func _on_settings_changed(_section: String, _key: String, _value) -> void:
	_setup_lighting()


func _setup_lighting() -> void:
	var quality: int = SettingsManager.get_value("video", "shadow_quality")
	directional_light.shadow_enabled = quality > 0
	directional_light.directional_shadow_max_distance = 60.0 if quality < 2 else 120.0


# ============================================================
# Geração procedural da arena (100% original, sem assets externos)
# ============================================================

func _build_arena_geometry() -> void:
	var mats := _make_materials()

	# Piso principal (área aberta)
	_add_box_static(world_root, Vector3(40, 0.4, 50), Vector3(0, -0.2, -8), mats.floor)

	# Paredes de contorno (delimitam a arena)
	_add_box_static(world_root, Vector3(0.6, 6, 50), Vector3(-20, 3, -8), mats.wall)
	_add_box_static(world_root, Vector3(0.6, 6, 50), Vector3(20, 3, -8), mats.wall)
	_add_box_static(world_root, Vector3(40, 6, 0.6), Vector3(0, 3, -33), mats.wall)
	_add_box_static(world_root, Vector3(40, 6, 0.6), Vector3(0, 3, 17), mats.wall)

	# --- Área fechada (sala menor conectada por corredor) ---
	var room_center := Vector3(28, 0, -8)
	_add_box_static(world_root, Vector3(14, 0.4, 14), room_center + Vector3(0, -0.2, 0), mats.floor)
	_add_box_static(world_root, Vector3(0.6, 4, 14), room_center + Vector3(-7, 2, 0), mats.wall)
	_add_box_static(world_root, Vector3(0.6, 4, 14), room_center + Vector3(7, 2, 0), mats.wall)
	_add_box_static(world_root, Vector3(14, 4, 0.6), room_center + Vector3(0, 2, -7), mats.wall)
	_add_box_static(world_root, Vector3(14, 4, 0.6), room_center + Vector3(0, 2, 7), mats.wall)

	# --- Corredor conectando a área aberta à sala fechada ---
	_add_box_static(world_root, Vector3(8, 0.4, 4), Vector3(20, -0.2, -8), mats.floor)
	_add_box_static(world_root, Vector3(8, 3, 0.4), Vector3(20, 1.5, -10), mats.wall)
	_add_box_static(world_root, Vector3(8, 3, 0.4), Vector3(20, 1.5, -6), mats.wall)

	# --- Rampa ---
	var ramp := _add_box_static(world_root, Vector3(6, 0.4, 10), Vector3(-14, 1.0, -24), mats.floor_alt)
	ramp.rotation.x = deg_to_rad(-12.0)

	# --- Plataforma elevada + escada ---
	_add_box_static(world_root, Vector3(8, 0.4, 8), Vector3(10, 2.4, -26), mats.floor_alt)
	for i in 6:
		_add_box_static(world_root, Vector3(2.2, 0.35, 1.0), Vector3(10, 0.4 * (i + 1), -21.5 - i * 1.0), mats.floor_alt)

	# --- Pilares (também servem de cobertura para a IA dos alvos) ---
	var pillar_positions := [
		Vector3(-8, 1.5, -14), Vector3(8, 1.5, -14),
		Vector3(-8, 1.5, -22), Vector3(0, 1.5, -18),
	]
	for p in pillar_positions:
		_add_cylinder_static(world_root, 0.5, 3.0, p, mats.pillar)
		_cover_points.append(p + Vector3(1.2, 0, 0))
		_cover_points.append(p + Vector3(-1.2, 0, 0))

	# --- Caixas e barris em distâncias variadas (treino de distância) ---
	var crate_distances := [-4, -10, -16, -22, -28]
	for z in crate_distances:
		var side: float = 1 if int(z) % 2 == 0 else -1
		var pos := Vector3(6.0 * side, 0.5, z)
		_add_box_static(world_root, Vector3(1.0, 1.0, 1.0), pos, mats.crate)
		_cover_points.append(pos + Vector3(0.8 * -side, 0, 0))

		var barrel_pos := Vector3(-3.0 * side, 0.5, z - 2)
		_add_cylinder_static(world_root, 0.4, 1.0, barrel_pos, mats.barrel)
		_cover_points.append(barrel_pos + Vector3(0.7 * side, 0, 0))


func _make_materials() -> Dictionary:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.17, 0.19)
	floor_mat.roughness = 0.9

	var floor_alt := StandardMaterial3D.new()
	floor_alt.albedo_color = Color(0.2, 0.21, 0.24)
	floor_alt.roughness = 0.85

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.22, 0.24, 0.27)
	wall_mat.roughness = 0.95

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.28, 0.3, 0.33)
	pillar_mat.roughness = 0.8

	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.45, 0.32, 0.18)
	crate_mat.roughness = 0.9

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.35, 0.1, 0.1)
	barrel_mat.roughness = 0.6
	barrel_mat.metallic = 0.3

	return {
		"floor": floor_mat, "floor_alt": floor_alt, "wall": wall_mat,
		"pillar": pillar_mat, "crate": crate_mat, "barrel": barrel_mat
	}


func _add_box_static(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	# Otimização: geometria estática distante deixa de ser desenhada
	mesh_instance.visibility_range_end = 120.0
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	return body


func _add_cylinder_static(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh_instance.mesh = cyl
	mesh_instance.material_override = mat
	mesh_instance.visibility_range_end = 120.0
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

	return body
