extends Control

# ============================================================
# CharacterSelect
#
# Mostra Eva e Adão em um SubViewport 3D (construído por código),
# girando lentamente, com nome e descrição. A escolha é salva em
# GameManager.selected_character.
# ============================================================

var viewport: SubViewport
var preview_pivot: Node3D
var name_label: Label
var description_label: Label
var _current_preview: Node = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_select_character(GameManager.selected_character)


func _build_ui() -> void:
	var bg := UIStyle.make_background(self)
	add_child(bg)

	# --- Viewport 3D com o personagem em pré-visualização ---
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = Vector2(500, 500)
	viewport_container.set_anchors_preset(Control.PRESET_CENTER)
	viewport_container.position = Vector2(-250, -260)
	add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.size = Vector2i(500, 500)
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	world.add_child(env)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 2.6)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	world.add_child(cam)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -25, 0)
	key_light.light_energy = 1.1
	world.add_child(key_light)

	preview_pivot = Node3D.new()
	world.add_child(preview_pivot)

	# --- Nome e descrição ---
	name_label = UIStyle.make_title("Eva", 30)
	name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_label.position = Vector2(-100, 90)
	add_child(name_label)

	description_label = UIStyle.make_label("", true)
	description_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	description_label.position = Vector2(-160, 130)
	description_label.custom_minimum_size = Vector2(320, 20)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(description_label)

	# --- Botões de seleção ---
	var buttons_container := UIStyle.make_hbox(16)
	buttons_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons_container.position = Vector2(-120, -100)
	add_child(buttons_container)

	var eva_button := UIStyle.make_button("Eva")
	var adao_button := UIStyle.make_button("Adão")
	buttons_container.add_child(eva_button)
	buttons_container.add_child(adao_button)
	eva_button.pressed.connect(func(): _select_character("eva"))
	adao_button.pressed.connect(func(): _select_character("adao"))

	var back_button := UIStyle.make_button("Voltar")
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.position = Vector2(20, -60)
	add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)


func _process(delta: float) -> void:
	if preview_pivot:
		preview_pivot.rotate_y(delta * 0.6)


func _select_character(character_id: String) -> void:
	AudioManager.play_ui()
	GameManager.selected_character = character_id
	var palette: Dictionary = CharacterBase.PALETTES[character_id]
	name_label.text = palette["display_name"]
	description_label.text = palette["description"]

	if _current_preview:
		_current_preview.queue_free()
	_current_preview = CharacterBase.new()
	_current_preview.character_id = character_id
	# As Hurtboxes precisam existir ANTES de entrar na árvore, pois
	# CharacterBase resolve @onready var head_hurtbox/body_hurtbox no
	# momento em que _ready() roda (ou seja, assim que add_child abaixo
	# for chamado).
	var head_hurtbox := Area3D.new()
	head_hurtbox.name = "HeadHurtbox"
	_current_preview.add_child(head_hurtbox)
	var body_hurtbox := Area3D.new()
	body_hurtbox.name = "BodyHurtbox"
	_current_preview.add_child(body_hurtbox)

	preview_pivot.add_child(_current_preview)


func _on_back_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
