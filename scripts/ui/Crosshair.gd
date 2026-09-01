extends Control
class_name CrosshairView

# ============================================================
# CrosshairView
#
# Desenha a mira no centro da tela usando os parâmetros do
# CrosshairManager. Usada tanto na HUD durante o treino quanto
# como pré-visualização ao vivo na tela de edição de mira.
# Reage a expand_on_shoot/run/jump com uma expansão suave que
# retorna à distância normal (return_speed).
# ============================================================

var _current_expand: float = 0.0
var _target_expand: float = 0.0
var live_preview: bool = false  # true na tela de editor: ignora estado de jogo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	CrosshairManager.crosshair_changed.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	if not live_preview:
		_update_dynamic_expand()
	var speed: float = CrosshairManager.get_field("return_speed")
	_current_expand = move_toward(_current_expand, _target_expand, speed * delta * 20.0)
	queue_redraw()


func _update_dynamic_expand() -> void:
	_target_expand = 0.0
	var player := get_tree().get_first_node_in_group("player")
	var weapon := get_tree().get_first_node_in_group("weapon")

	if CrosshairManager.get_field("expand_on_run") and player and player is CharacterBody3D:
		if Vector2(player.velocity.x, player.velocity.z).length() > 4.5:
			_target_expand += CrosshairManager.get_field("expand_amount") * 0.6

	if CrosshairManager.get_field("expand_on_jump") and player and player is CharacterBody3D:
		if not player.is_on_floor():
			_target_expand += CrosshairManager.get_field("expand_amount") * 0.5

	if weapon:
		pass  # expand_on_shoot é acionado via pulse_shoot() chamado pela HUD


func pulse_shoot() -> void:
	if CrosshairManager.get_field("expand_on_shoot"):
		_target_expand = CrosshairManager.get_field("expand_amount")
		await get_tree().create_timer(0.05).timeout
		_target_expand = max(_target_expand - CrosshairManager.get_field("expand_amount"), 0.0)


func _draw() -> void:
	var cfg: Dictionary = CrosshairManager.config
	var center: Vector2 = size / 2.0
	var color: Color = cfg["color"]
	color.a = cfg["opacity"]
	var outline_color := Color(0, 0, 0, cfg["outline_opacity"])

	var gap: float = cfg["gap"] + _current_expand
	var length: float = cfg["size"]
	var thickness: float = cfg["thickness"]
	var type: int = cfg["type"]

	if type == CrosshairManager.Type.DOT_ONLY:
		pass
	elif type == CrosshairManager.Type.CIRCLE or type == CrosshairManager.Type.CIRCLE_DOT:
		_draw_circle_outline(center, gap + length * 0.5, thickness, color, outline_color, cfg["outline"])
	else:
		var lines := [
			[Vector2(0, -gap - length), Vector2(0, -gap)],
			[Vector2(0, gap), Vector2(0, gap + length)],
			[Vector2(-gap - length, 0), Vector2(-gap, 0)],
			[Vector2(gap, 0), Vector2(gap + length, 0)],
		]
		for line in lines:
			var a: Vector2 = center + line[0]
			var b: Vector2 = center + line[1]
			if cfg["outline"]:
				draw_line(a, b, outline_color, thickness + cfg["outline_thickness"] * 2.0)
			draw_line(a, b, color, thickness)

	if cfg["center_dot"]:
		var dot_color: Color = color
		dot_color.a = cfg["dot_opacity"]
		draw_circle(center, cfg["dot_size"], dot_color)


func _draw_circle_outline(center: Vector2, radius: float, thickness: float, color: Color, outline_color: Color, has_outline: bool) -> void:
	var points := 32
	for i in points:
		var a1: float = TAU * float(i) / points
		var a2: float = TAU * float(i + 1) / points
		var p1: Vector2 = center + Vector2(cos(a1), sin(a1)) * radius
		var p2: Vector2 = center + Vector2(cos(a2), sin(a2)) * radius
		if has_outline:
			draw_line(p1, p2, outline_color, thickness + 2.0)
		draw_line(p1, p2, color, thickness)
