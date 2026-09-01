extends Node3D

# ============================================================
# ImpactEffect
#
# Pequeno efeito instanciado no ponto onde o tiro atinge uma
# superfície: faíscas + marca de bala temporária + luz rápida.
# Construído inteiramente por código (sem depender de recursos
# de partícula definidos no .tscn) e se autodestrói ao terminar.
# ============================================================

func _ready() -> void:
	_spawn_sparks()
	_spawn_decal_mark()
	_spawn_flash_light()
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _spawn_sparks() -> void:
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, -6.0, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	mat.color = Color(1.0, 0.75, 0.35)
	particles.process_material = mat
	particles.draw_pass_1 = SphereMesh.new()
	particles.amount = 10
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emitting = true
	add_child(particles)


func _spawn_decal_mark() -> void:
	# Pequena marca de impacto (mancha escura) que desaparece com o tempo
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	mark.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = mat
	mark.rotation.x = deg_to_rad(-90.0)
	add_child(mark)

	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.5)


func _spawn_flash_light() -> void:
	var light := OmniLight3D.new()
	light.light_energy = 3.0
	light.omni_range = 1.5
	light.light_color = Color(1.0, 0.7, 0.4)
	add_child(light)
	var t := create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.15)
