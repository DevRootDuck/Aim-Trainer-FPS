extends Control

# ============================================================
# MainMenu
#
# Tela inicial, construída inteiramente por código: Jogar (início
# rápido), Treino (escolher modo/dificuldade), Selecionar
# Personagem, Configurações, Créditos e Sair — com transições
# suaves (fade) entre os painéis.
# ============================================================

var root_panel: Control
var training_panel: Control
var credits_panel: Control

var mode_option: OptionButton
var difficulty_option: OptionButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()

	root_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(root_panel, "modulate:a", 1.0, 0.4)


func _build_ui() -> void:
	var bg := UIStyle.make_background(self)
	add_child(bg)

	var title := UIStyle.make_title("AIM TRAINER", 46)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-160, 60)
	title.custom_minimum_size = Vector2(320, 60)
	add_child(title)

	_build_root_panel()
	_build_training_panel()
	_build_credits_panel()

	training_panel.modulate.a = 0.0
	training_panel.visible = false
	credits_panel.modulate.a = 0.0
	credits_panel.visible = false


func _build_root_panel() -> void:
	root_panel = UIStyle.make_panel()
	root_panel.set_anchors_preset(Control.PRESET_CENTER)
	root_panel.position = Vector2(-140, -190)
	add_child(root_panel)

	var vbox := UIStyle.make_vbox(10)
	root_panel.add_child(vbox)

	var play_button := UIStyle.make_button("Jogar")
	var training_button := UIStyle.make_button("Treino")
	var online_button := UIStyle.make_button("Jogar Online (Coop)")
	var character_button := UIStyle.make_button("Selecionar Personagem")
	var settings_button := UIStyle.make_button("Configurações")
	var credits_button := UIStyle.make_button("Créditos")
	var quit_button := UIStyle.make_button("Sair")

	for b in [play_button, training_button, online_button, character_button, settings_button, credits_button, quit_button]:
		vbox.add_child(b)

	play_button.pressed.connect(_on_play_pressed)
	training_button.pressed.connect(func(): _switch_panel(training_panel))
	online_button.pressed.connect(_on_online_pressed)
	character_button.pressed.connect(_on_character_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(func(): _switch_panel(credits_panel))
	quit_button.pressed.connect(_on_quit_pressed)


func _build_training_panel() -> void:
	training_panel = UIStyle.make_panel()
	training_panel.set_anchors_preset(Control.PRESET_CENTER)
	training_panel.position = Vector2(-140, -160)
	add_child(training_panel)

	var vbox := UIStyle.make_vbox(12)
	training_panel.add_child(vbox)

	vbox.add_child(UIStyle.make_label("Modo de treino"))
	mode_option = UIStyle.make_option_button()
	for mode in GameManager.MODE_NAMES.keys():
		mode_option.add_item(GameManager.MODE_NAMES[mode], mode)
	mode_option.select(mode_option.get_item_index(GameManager.current_mode))
	vbox.add_child(mode_option)

	vbox.add_child(UIStyle.make_label("Dificuldade"))
	difficulty_option = UIStyle.make_option_button()
	difficulty_option.add_item("Fácil", GameManager.Difficulty.EASY)
	difficulty_option.add_item("Médio", GameManager.Difficulty.MEDIUM)
	difficulty_option.add_item("Difícil", GameManager.Difficulty.HARD)
	difficulty_option.select(difficulty_option.get_item_index(GameManager.current_difficulty))
	vbox.add_child(difficulty_option)

	var start_button := UIStyle.make_button("Iniciar Treino")
	var back_button := UIStyle.make_button("Voltar")
	vbox.add_child(start_button)
	vbox.add_child(back_button)

	start_button.pressed.connect(_on_start_training_pressed)
	back_button.pressed.connect(func(): _switch_panel(root_panel))


func _build_credits_panel() -> void:
	credits_panel = UIStyle.make_panel()
	credits_panel.set_anchors_preset(Control.PRESET_CENTER)
	credits_panel.position = Vector2(-160, -140)
	add_child(credits_panel)

	var vbox := UIStyle.make_vbox(8)
	credits_panel.add_child(vbox)
	vbox.add_child(UIStyle.make_title("Créditos", 22))
	vbox.add_child(UIStyle.make_label("Aim Trainer FPS — projeto original."))
	vbox.add_child(UIStyle.make_label("Personagens, arma, mapa, HUD, mira e etc"))
	vbox.add_child(UIStyle.make_label("Discord do criador: 10szx ( Criado com ajuda de IA)"))
	vbox.add_child(UIStyle.make_label("sons são 100% originais/procedurais."))
	var back_button := UIStyle.make_button("Voltar")
	vbox.add_child(back_button)
	back_button.pressed.connect(func(): _switch_panel(root_panel))


func _switch_panel(target: Control) -> void:
	AudioManager.play_ui()
	for panel in [root_panel, training_panel, credits_panel]:
		if panel == target:
			continue
		if not panel.visible:
			continue
		var fade_out := create_tween()
		fade_out.tween_property(panel, "modulate:a", 0.0, 0.2)
		fade_out.tween_callback(func(): panel.visible = false)

	target.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(target, "modulate:a", 1.0, 0.25)


func _on_play_pressed() -> void:
	AudioManager.play_ui()
	GameManager.start_training(GameManager.current_difficulty, GameManager.current_mode)


func _on_start_training_pressed() -> void:
	AudioManager.play_ui()
	var mode: int = mode_option.get_selected_id()
	var difficulty: int = difficulty_option.get_selected_id()
	GameManager.start_training(difficulty as GameManager.Difficulty, mode as GameManager.TrainMode)


func _on_character_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/CharacterSelect.tscn")


func _on_online_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/MultiplayerLobby.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/SettingsMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
