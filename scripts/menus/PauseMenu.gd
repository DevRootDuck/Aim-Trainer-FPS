extends CanvasLayer

# ============================================================
# PauseMenu
#
# Aberto com ESC durante o treino (ver Arena.gd::toggle_pause).
# Continuar / Configurações / Reiniciar treino / Voltar ao menu /
# Sair do jogo. Construído por código; roda mesmo com o jogo
# logicamente pausado (GameManager.GameState.PAUSED).
# ============================================================

const SETTINGS_SCENE: PackedScene = preload("res://scenes/menus/SettingsMenu.tscn")

var panel: Control
var _settings_instance: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = UIStyle.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-120, -150)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(panel)

	var vbox := UIStyle.make_vbox(10)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(vbox)

	vbox.add_child(UIStyle.make_title("Pausado", 24))

	var resume_button := UIStyle.make_button("Continuar")
	var settings_button := UIStyle.make_button("Configurações")
	var restart_button := UIStyle.make_button("Reiniciar Treino")
	var menu_button := UIStyle.make_button("Voltar ao Menu")
	var quit_button := UIStyle.make_button("Sair do Jogo")

	for b in [resume_button, settings_button, restart_button, menu_button, quit_button]:
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		vbox.add_child(b)

	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		restart_button.disabled = true
		restart_button.text = "Reiniciar (só o host)"

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
	AudioManager.play_ui()
	get_parent().toggle_pause()


func _on_settings_pressed() -> void:
	AudioManager.play_ui()
	panel.visible = false
	_settings_instance = SETTINGS_SCENE.instantiate()
	_settings_instance.standalone = false
	_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_instance.closed.connect(_on_settings_closed)
	add_child(_settings_instance)


func _on_settings_closed() -> void:
	AudioManager.play_ui()
	if _settings_instance:
		_settings_instance.queue_free()
		_settings_instance = null
	panel.visible = true


func _on_restart_pressed() -> void:
	AudioManager.play_ui()
	get_parent().toggle_pause()
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.start_match()
	else:
		GameManager.restart_training()


func _on_menu_pressed() -> void:
	AudioManager.play_ui()
	GameManager.current_state = GameManager.GameState.MENU
	GameManager.go_to_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
