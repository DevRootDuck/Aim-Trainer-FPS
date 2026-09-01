extends Control

# ============================================================
# ResultsScreen
#
# Resumo estatístico do treino: modo, dificuldade, tiros, acertos,
# erros, precisão, headshots, kills e tempo médio de reação.
# Construído por código.
# ============================================================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()


func _build_ui() -> void:
	var bg := UIStyle.make_background(self)
	add_child(bg)

	var panel := UIStyle.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -220)
	add_child(panel)

	var vbox := UIStyle.make_vbox(6)
	panel.add_child(vbox)

	var settings: Dictionary = GameManager.get_current_settings()

	vbox.add_child(UIStyle.make_title("Resultado do Treino", 26))
	vbox.add_child(UIStyle.make_label("Modo: %s" % GameManager.get_mode_name()))
	vbox.add_child(UIStyle.make_label("Dificuldade: %s" % settings["name"]))
	vbox.add_child(UIStyle.make_label("Tiros disparados: %d" % GameManager.shots_fired))
	vbox.add_child(UIStyle.make_label("Acertos: %d" % GameManager.hits))
	vbox.add_child(UIStyle.make_label("Erros: %d" % GameManager.misses))
	vbox.add_child(UIStyle.make_label("Precisão: %.1f%%" % GameManager.get_accuracy()))
	vbox.add_child(UIStyle.make_label("Headshots: %d" % GameManager.headshots))
	vbox.add_child(UIStyle.make_label("Kills: %d" % GameManager.kills))
	vbox.add_child(UIStyle.make_label("Tempo médio de reação: %.2fs" % GameManager.get_average_reaction_time()))

	var hbox := UIStyle.make_hbox(10)
	vbox.add_child(hbox)
	var restart_button := UIStyle.make_button("Repetir Treino")
	var menu_button := UIStyle.make_button("Voltar ao Menu")
	hbox.add_child(restart_button)
	hbox.add_child(menu_button)

	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		restart_button.disabled = true
		restart_button.text = "Repetir (só o host)"

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _on_restart_pressed() -> void:
	AudioManager.play_ui()
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.start_match()
	else:
		GameManager.restart_training()


func _on_menu_pressed() -> void:
	AudioManager.play_ui()
	GameManager.go_to_menu()
