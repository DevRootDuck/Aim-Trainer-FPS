extends Weapon
class_name RifleAX

# ============================================================
# RifleAX
#
# Arma de assalto totalmente original ("AX-9"), com silhueta
# própria e sem semelhança intencional a nenhuma arma real ou de
# outro jogo. Modelo construído por primitivas (proceduralmente),
# o que garante originalidade total e facilita reskins futuros.
# ============================================================

var _sway_time: float = 0.0
@export var sway_amount: float = 0.01
@export var sway_speed: float = 1.6
@export var bob_amount: float = 0.015
@export var bob_speed: float = 9.0


func _ready() -> void:
	weapon_name = "AX-9"
	magazine_size = 30
	fire_rate = 0.1
	reload_time = 1.7
	damage = 1
	automatic = true
	recoil_kick_deg = 1.0
	bloom_max_deg = 3.5
	super._ready()


func _build_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "WeaponModel"
	add_child(_model_root)
	# A pose de "mãos" (posição/rotação relativa à câmera) fica no nó Weapon
	# em si (self), já que ele é instanciado direto sob o WeaponHolder.
	# _model_root permanece na origem local para que o recoil kick (que
	# anima _model_root) não interfira com o sway/bob (que anima self).
	position = Vector3(0.22, -0.18, -0.35)
	rotation.y = deg_to_rad(3.0)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.15)
	dark.metallic = 0.6
	dark.roughness = 0.35

	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.15, 0.85, 0.65)
	accent.emission_enabled = true
	accent.emission = Color(0.15, 0.85, 0.65)
	accent.emission_energy_multiplier = 0.6

	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.08, 0.08, 0.09)
	grip_mat.roughness = 0.9

	# Corpo principal (receiver)
	_add_box(_model_root, Vector3(0.07, 0.09, 0.42), Vector3(0, 0.0, -0.05), dark)
	# Cano
	_add_cylinder(_model_root, 0.018, 0.32, Vector3(0, 0.015, -0.42), dark)
	# Guarda-mão (handguard) sobre o cano
	_add_box(_model_root, Vector3(0.055, 0.055, 0.22), Vector3(0, 0.01, -0.32), dark)
	# Carregador (magazine) - angulado ligeiramente
	var mag := _add_box(_model_root, Vector3(0.035, 0.16, 0.05), Vector3(0, -0.14, -0.02), grip_mat)
	mag.rotation.x = deg_to_rad(-8.0)
	# Empunhadura (grip)
	var grip := _add_box(_model_root, Vector3(0.04, 0.13, 0.045), Vector3(0, -0.09, 0.08), grip_mat)
	grip.rotation.x = deg_to_rad(12.0)
	# Coronha (stock)
	_add_box(_model_root, Vector3(0.045, 0.06, 0.18), Vector3(0, 0.0, 0.28), dark)
	# Alça de mira (top rail sight)
	_add_box(_model_root, Vector3(0.02, 0.03, 0.08), Vector3(0, 0.065, -0.1), accent)
	# Detalhe frontal (flash hider) na ponta do cano
	_add_cylinder(_model_root, 0.02, 0.04, Vector3(0, 0.015, -0.6), dark)

	_muzzle_point = Node3D.new()
	_muzzle_point.name = "Muzzle"
	_muzzle_point.position = Vector3(0, 0.015, -0.63)
	_model_root.add_child(_muzzle_point)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh_instance.mesh = cyl
	mesh_instance.material_override = mat
	mesh_instance.rotation.x = deg_to_rad(90.0)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


func _process(delta: float) -> void:
	super._process(delta)
	_apply_sway_and_bob(delta)


func _apply_sway_and_bob(delta: float) -> void:
	if not player:
		return
	var moving: bool = player is CharacterBody3D and Vector2(player.velocity.x, player.velocity.z).length() > 0.3
	if moving:
		_sway_time += delta * bob_speed
	else:
		_sway_time = lerp(_sway_time, 0.0, delta * 5.0)

	var bob_offset := Vector3(sin(_sway_time) * bob_amount, abs(cos(_sway_time)) * bob_amount * 0.5, 0)

	var mouse_influence: Vector2 = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_influence = Input.get_last_mouse_velocity() * 0.00002

	var base_pos := Vector3(0.22, -0.18, -0.35)
	var target_pos := base_pos + bob_offset
	position = position.lerp(target_pos, delta * 10.0)
	rotation.y = lerp(rotation.y, deg_to_rad(3.0) - mouse_influence.x, delta * 6.0)
	rotation.x = lerp(rotation.x, mouse_influence.y, delta * 6.0)
