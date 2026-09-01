extends Area3D
class_name Hurtbox

# ============================================================
# Hurtbox
#
# Pequena área de colisão anexada à cabeça ou ao corpo de um
# personagem-alvo. O Weapon.gd faz o raycast e, ao acertar uma
# Hurtbox, pergunta is_head_hit() para saber se foi headshot e
# então chama register_hit(), que repassa para o personagem-pai.
# ============================================================

@export var is_head: bool = false


func is_head_hit(_impact_position: Vector3) -> bool:
	return is_head


func register_hit(is_headshot: bool) -> void:
	var character := get_parent()
	if character and character.has_method("register_hit"):
		character.register_hit(is_headshot)
