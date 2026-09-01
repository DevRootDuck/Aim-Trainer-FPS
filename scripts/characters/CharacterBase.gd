extends CharacterBody3D
class_name CharacterBase

# ============================================================
# CharacterBase
#
# Corpo humanoide 100% procedural (cabeça, tronco, braços e
# pernas construídos por primitivas em código — sem nenhum
# modelo importado), usado pelos dois personagens originais do
# jogo, Adão e Eva. Cuida da montagem visual, da animação simples
# de membros (idle/andar/correr) e dos efeitos de dano (cabeça
# fica vermelha, personagem cai ao "morrer").
#
# Para adicionar um novo personagem no futuro, baste chamar
# set_palette() com novas cores/proporções antes do _ready rodar,
# ou estender esta classe e sobrescrever _get_default_palette().
# ============================================================

signal died

const PALETTES := {
	"eva": {
		"display_name": "Eva",
		"description": "Ágil e precisa — especialista em reflexo.",
		"skin": Color(0.86, 0.68, 0.56),
		"primary": Color(0.55, 0.15, 0.55),
		"secondary": Color(0.18, 0.18, 0.22),
		"height_scale": 0.95,
		"build_scale": 0.9,
	},
	"adao": {
		"display_name": "Adão",
		"description": "Firme e resistente — ótimo para sobrevivência.",
		"skin": Color(0.75, 0.58, 0.45),
		"primary": Color(0.15, 0.35, 0.55),
		"secondary": Color(0.15, 0.15, 0.16),
		"height_scale": 1.05,
		"build_scale": 1.08,
	},
}

@export var character_id: String = "eva":
	set(value):
		var changed: bool = value != character_id
		character_id = value
		if changed and is_inside_tree() and _visual_root:
			_rebuild_materials()

var _head_mesh: MeshInstance3D
var _head_material: StandardMaterial3D
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D
var _visual_root: Node3D
var _walk_time: float = 0.0
var _is_dead: bool = false

@onready var head_hurtbox: Area3D = $HeadHurtbox
@onready var body_hurtbox: Area3D = $BodyHurtbox


func _ready() -> void:
	_build_body(PALETTES.get(character_id, PALETTES["eva"]))
	_build_hurtbox_shapes(PALETTES.get(character_id, PALETTES["eva"]))


func _build_hurtbox_shapes(palette: Dictionary) -> void:
	var scale_h: float = palette["height_scale"]
	var scale_b: float = palette["build_scale"]

	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.18 * scale_b
	var head_collision := CollisionShape3D.new()
	head_collision.shape = head_shape
	head_collision.position = Vector3(0, 1.55 * scale_h, 0)
	head_hurtbox.add_child(head_collision)

	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.28 * scale_b
	body_shape.height = 1.1 * scale_h
	var body_collision := CollisionShape3D.new()
	body_collision.shape = body_shape
	body_collision.position = Vector3(0, 1.0 * scale_h, 0)
	body_hurtbox.add_child(body_collision)


func _build_body(palette: Dictionary) -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	var scale_h: float = palette["height_scale"]
	var scale_b: float = palette["build_scale"]

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = palette["skin"]
	skin_mat.roughness = 0.8

	var shirt_mat := StandardMaterial3D.new()
	shirt_mat.albedo_color = palette["primary"]
	shirt_mat.roughness = 0.6

	var pants_mat := StandardMaterial3D.new()
	pants_mat.albedo_color = palette["secondary"]
	pants_mat.roughness = 0.7

	# --- Cabeça ---
	_head_material = StandardMaterial3D.new()
	_head_material.albedo_color = palette["skin"]
	_head_mesh = MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.16 * scale_b
	head_sphere.height = 0.32 * scale_b
	_head_mesh.mesh = head_sphere
	_head_mesh.material_override = _head_material
	_head_mesh.position = Vector3(0, 1.55 * scale_h, 0)
	_visual_root.add_child(_head_mesh)

	# --- Tronco ---
	var torso := MeshInstance3D.new()
	var torso_box := BoxMesh.new()
	torso_box.size = Vector3(0.42 * scale_b, 0.55 * scale_h, 0.24 * scale_b)
	torso.mesh = torso_box
	torso.material_override = shirt_mat
	torso.position = Vector3(0, 1.1 * scale_h, 0)
	_visual_root.add_child(torso)

	# --- Braços (pivôs no ombro para permitir balanço) ---
	_left_arm_pivot = _make_limb_pivot(Vector3(-0.28 * scale_b, 1.35 * scale_h, 0), 0.4 * scale_h, skin_mat)
	_right_arm_pivot = _make_limb_pivot(Vector3(0.28 * scale_b, 1.35 * scale_h, 0), 0.4 * scale_h, skin_mat)

	# --- Pernas (pivôs no quadril) ---
	_left_leg_pivot = _make_limb_pivot(Vector3(-0.12 * scale_b, 0.85 * scale_h, 0), 0.5 * scale_h, pants_mat)
	_right_leg_pivot = _make_limb_pivot(Vector3(0.12 * scale_b, 0.85 * scale_h, 0), 0.5 * scale_h, pants_mat)


func _make_limb_pivot(pos: Vector3, length: float, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	_visual_root.add_child(pivot)

	var limb := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.05
	cyl.height = length
	limb.mesh = cyl
	limb.material_override = mat
	limb.position = Vector3(0, -length / 2.0, 0)
	pivot.add_child(limb)
	return pivot


func set_move_animation(speed_ratio: float, delta: float) -> void:
	# speed_ratio: 0 = parado, 1 = andando normal, >1 = correndo
	if _is_dead:
		return
	if speed_ratio > 0.02:
		_walk_time += delta * (6.0 + speed_ratio * 4.0)
	else:
		_walk_time = lerp(_walk_time, 0.0, delta * 6.0)

	var swing: float = sin(_walk_time) * clamp(speed_ratio, 0.0, 1.6) * 0.6
	if _left_arm_pivot:
		_left_arm_pivot.rotation.x = swing
	if _right_arm_pivot:
		_right_arm_pivot.rotation.x = -swing
	if _left_leg_pivot:
		_left_leg_pivot.rotation.x = -swing
	if _right_leg_pivot:
		_right_leg_pivot.rotation.x = swing


func set_crouch_visual(is_crouching: bool, delta: float) -> void:
	var target_y: float = 0.7 if is_crouching else 1.0
	_visual_root.scale.y = lerp(_visual_root.scale.y, target_y, delta * 8.0)


func flash_hit(is_head: bool) -> void:
	var mat: StandardMaterial3D = _head_material if is_head else null
	if mat:
		var original: Color = PALETTES.get(character_id, PALETTES["eva"])["skin"]
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.05, 0.05)
		mat.emission_energy_multiplier = 2.0
		var t := create_tween()
		t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	else:
		var flash_overlay := StandardMaterial3D.new()
		flash_overlay.albedo_color = Color(1.0, 0.2, 0.2)
		for child in _visual_root.get_children():
			if child is MeshInstance3D:
				child.material_override = flash_overlay
			for grandchild in child.get_children():
				if grandchild is MeshInstance3D:
					grandchild.material_override = flash_overlay
		await get_tree().create_timer(0.12).timeout
		_rebuild_materials()


func _rebuild_materials() -> void:
	# Re-monta o corpo com os materiais corretos após um flash de dano no
	# corpo (mais simples e seguro do que guardar referências por membro).
	for child in _visual_root.get_children():
		child.queue_free()
	_build_body(PALETTES.get(character_id, PALETTES["eva"]))


func play_death() -> void:
	_is_dead = true
	head_hurtbox.set_deferred("monitoring", false)
	body_hurtbox.set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(_visual_root, "rotation:z", deg_to_rad(90.0), 0.3)
	t.parallel().tween_property(_visual_root, "position:y", -0.5, 0.3)
	t.tween_callback(func(): emit_signal("died"))


func reset_visual() -> void:
	_is_dead = false
	_visual_root.rotation = Vector3.ZERO
	_visual_root.position = Vector3.ZERO
	_visual_root.scale = Vector3.ONE
	head_hurtbox.monitoring = true
	body_hurtbox.monitoring = true
	_rebuild_materials()
