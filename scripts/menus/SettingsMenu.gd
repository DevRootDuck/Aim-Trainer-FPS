extends Control

# ============================================================
# SettingsMenu
#
# Todas as configurações (mouse, áudio, vídeo, interface) lidas e
# escritas diretamente do/para o SettingsManager, aplicadas em
# tempo real assim que o valor muda. Interface construída por
# código, organizada em abas (TabContainer).
# ============================================================

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const MAX_FPS_OPTIONS := [0, 60, 120, 144, 240]

# Quando aberto por cima do PauseMenu (overlay, sem trocar de cena), o
# PauseMenu passa standalone = false e escuta o sinal "closed" para
# apenas esconder/remover este painel — assim o treino em andamento
# (estatísticas, alvos ativos) não é perdido.
@export var standalone: bool = true
signal closed

var tabs: TabContainer


func _ready() -> void:
	if standalone:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()


func _build_ui() -> void:
	if standalone:
		var bg := UIStyle.make_background(self)
		add_child(bg)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

	var panel := UIStyle.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -240)
	panel.custom_minimum_size = Vector2(520, 460)
	add_child(panel)

	var outer_vbox := UIStyle.make_vbox(10)
	panel.add_child(outer_vbox)
	outer_vbox.add_child(UIStyle.make_title("Configurações", 24))

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(480, 370)
	tabs.theme = UIStyle.theme
	outer_vbox.add_child(tabs)

	_build_mouse_tab()
	_build_audio_tab()
	_build_video_tab()
	_build_interface_tab()

	var back_button := UIStyle.make_button("Voltar")
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.position = Vector2(20, -60)
	add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)

	var crosshair_button := UIStyle.make_button("Editor de Mira")
	crosshair_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	crosshair_button.position = Vector2(-240, -60)
	add_child(crosshair_button)
	crosshair_button.pressed.connect(_on_crosshair_editor_pressed)


func _row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hbox := UIStyle.make_hbox(10)
	hbox.add_child(UIStyle.make_row_label(label_text))
	hbox.add_child(control)
	parent.add_child(hbox)


func _build_mouse_tab() -> void:
	var vbox := UIStyle.make_vbox(10)
	vbox.name = "Mouse"
	tabs.add_child(vbox)

	var s := SettingsManager
	var sens_slider := UIStyle.make_slider(1.0, 15.0, 0.1, s.get_value("mouse", "sensitivity") * 4000.0)
	_row(vbox, "Sensibilidade", sens_slider)
	sens_slider.value_changed.connect(func(v): s.set_value("mouse", "sensitivity", v / 4000.0))

	var invert_check := UIStyle.make_checkbox("Inverter eixo Y", s.get_value("mouse", "invert_y"))
	vbox.add_child(invert_check)
	invert_check.toggled.connect(func(v): s.set_value("mouse", "invert_y", v))

	var smoothing_slider := UIStyle.make_slider(0.0, 0.9, 0.05, s.get_value("mouse", "smoothing"))
	_row(vbox, "Suavização", smoothing_slider)
	smoothing_slider.value_changed.connect(func(v): s.set_value("mouse", "smoothing", v))


func _build_audio_tab() -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Áudio"
	tabs.add_child(vbox)

	var s := SettingsManager

	var master_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "master"))
	_row(vbox, "Volume Geral", master_slider)
	master_slider.value_changed.connect(func(v): s.set_value("audio", "master", v))

	var music_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "music"))
	_row(vbox, "Música", music_slider)
	music_slider.value_changed.connect(func(v): s.set_value("audio", "music", v))

	var shots_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "shots"))
	_row(vbox, "Tiros", shots_slider)
	shots_slider.value_changed.connect(func(v): s.set_value("audio", "shots", v))

	var footsteps_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "footsteps"))
	_row(vbox, "Passos", footsteps_slider)
	footsteps_slider.value_changed.connect(func(v): s.set_value("audio", "footsteps", v))

	var ui_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "ui"))
	_row(vbox, "Interface", ui_slider)
	ui_slider.value_changed.connect(func(v): s.set_value("audio", "ui", v))

	var headshot_slider := UIStyle.make_slider(0.0, 1.0, 0.05, s.get_value("audio", "headshot"))
	_row(vbox, "Headshots", headshot_slider)
	headshot_slider.value_changed.connect(func(v): s.set_value("audio", "headshot", v))

	var music_check := UIStyle.make_checkbox("Desligar música", not s.get_value("audio", "music_enabled"))
	vbox.add_child(music_check)
	music_check.toggled.connect(func(v):
		s.set_value("audio", "music_enabled", not v)
		if v:
			AudioManager.stop_music()
		else:
			AudioManager.play_music()
	)


func _build_video_tab() -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Vídeo"
	tabs.add_child(vbox)

	var s := SettingsManager

	var fullscreen_check := UIStyle.make_checkbox("Tela cheia", s.get_value("video", "fullscreen"))
	vbox.add_child(fullscreen_check)
	fullscreen_check.toggled.connect(func(v): s.set_value("video", "fullscreen", v))

	var resolution_option := UIStyle.make_option_button()
	for res in RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [res.x, res.y])
	var res_idx: int = RESOLUTIONS.find(s.get_value("video", "resolution"))
	resolution_option.select(max(res_idx, 0))
	_row(vbox, "Resolução", resolution_option)
	resolution_option.item_selected.connect(func(idx): s.set_value("video", "resolution", RESOLUTIONS[idx]))

	var fps_option := UIStyle.make_option_button()
	for fps in MAX_FPS_OPTIONS:
		fps_option.add_item("Ilimitado" if fps == 0 else str(fps))
	fps_option.select(max(MAX_FPS_OPTIONS.find(s.get_value("video", "max_fps")), 0))
	_row(vbox, "FPS Máximo", fps_option)
	fps_option.item_selected.connect(func(idx): s.set_value("video", "max_fps", MAX_FPS_OPTIONS[idx]))

	var vsync_check := UIStyle.make_checkbox("V-Sync", s.get_value("video", "vsync"))
	vbox.add_child(vsync_check)
	vsync_check.toggled.connect(func(v): s.set_value("video", "vsync", v))

	var fov_slider := UIStyle.make_slider(70.0, 110.0, 1.0, s.get_value("video", "fov"))
	_row(vbox, "FOV", fov_slider)
	fov_slider.value_changed.connect(func(v): s.set_value("video", "fov", v))

	var quality_option := UIStyle.make_option_button()
	quality_option.add_item("Baixo", 0)
	quality_option.add_item("Médio", 1)
	quality_option.add_item("Alto", 2)
	quality_option.select(s.get_value("video", "quality_preset"))
	_row(vbox, "Qualidade", quality_option)

	var shadow_option := UIStyle.make_option_button()
	var texture_option := UIStyle.make_option_button()
	for opt in [shadow_option, texture_option]:
		opt.add_item("Baixo", 0)
		opt.add_item("Médio", 1)
		opt.add_item("Alto", 2)
	shadow_option.select(s.get_value("video", "shadow_quality"))
	texture_option.select(s.get_value("video", "texture_quality"))
	_row(vbox, "Sombras", shadow_option)
	_row(vbox, "Texturas", texture_option)
	shadow_option.item_selected.connect(func(idx): s.set_value("video", "shadow_quality", idx))
	texture_option.item_selected.connect(func(idx): s.set_value("video", "texture_quality", idx))

	var render_distance_slider := UIStyle.make_slider(50.0, 300.0, 10.0, s.get_value("video", "render_distance"))
	_row(vbox, "Dist. Renderização", render_distance_slider)
	render_distance_slider.value_changed.connect(func(v): s.set_value("video", "render_distance", v))

	var aa_option := UIStyle.make_option_button()
	aa_option.add_item("Desligado", 0)
	aa_option.add_item("FXAA", 1)
	aa_option.add_item("MSAA 2x", 2)
	aa_option.select(s.get_value("video", "antialiasing"))
	_row(vbox, "Anti-aliasing", aa_option)
	aa_option.item_selected.connect(func(idx): s.set_value("video", "antialiasing", idx))

	quality_option.item_selected.connect(func(idx):
		s.apply_quality_preset(idx)
		shadow_option.select(s.get_value("video", "shadow_quality"))
		texture_option.select(s.get_value("video", "texture_quality"))
		render_distance_slider.value = s.get_value("video", "render_distance")
		aa_option.select(s.get_value("video", "antialiasing"))
	)


func _build_interface_tab() -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Interface"
	tabs.add_child(vbox)

	var s := SettingsManager

	var fps_check := UIStyle.make_checkbox("Mostrar FPS", s.get_value("interface", "show_fps"))
	vbox.add_child(fps_check)
	fps_check.toggled.connect(func(v): s.set_value("interface", "show_fps", v))

	var ping_check := UIStyle.make_checkbox("Mostrar Ping (multiplayer)", s.get_value("interface", "show_ping"))
	vbox.add_child(ping_check)
	ping_check.toggled.connect(func(v): s.set_value("interface", "show_ping", v))

	var stats_check := UIStyle.make_checkbox("Mostrar estatísticas", s.get_value("interface", "show_stats"))
	vbox.add_child(stats_check)
	stats_check.toggled.connect(func(v): s.set_value("interface", "show_stats", v))


func _on_back_pressed() -> void:
	AudioManager.play_ui()
	if standalone:
		get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
	else:
		emit_signal("closed")


func _on_crosshair_editor_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/CrosshairEditor.tscn")
