extends Control

# ============================================================
# CrosshairEditor
#
# Tela dedicada para editar a mira: tipo, cor, tamanho, espessura,
# gap, opacidade, outline, ponto central e comportamento dinâmico
# (expandir ao atirar/correr/pular). Toda alteração atualiza o
# CrosshairManager, que atualiza a pré-visualização ao vivo na
# hora. Permite salvar, carregar, importar e exportar presets.
# Interface construída por código.
# ============================================================

var preview: CrosshairView
var preset_list: ItemList
var preset_name_input: LineEdit
var file_dialog: FileDialog
var _dialog_mode: String = "export"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()


func _build_ui() -> void:
	var bg := UIStyle.make_background(self)
	add_child(bg)

	# --- Área de pré-visualização (lado esquerdo) ---
	var preview_area := Panel.new()
	preview_area.theme = UIStyle.theme
	preview_area.custom_minimum_size = Vector2(360, 360)
	preview_area.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	preview_area.position = Vector2(60, -180)
	add_child(preview_area)

	preview = CrosshairView.new()
	preview.live_preview = true
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_area.add_child(preview)

	# --- Painel de controles (lado direito, com abas) ---
	var panel := UIStyle.make_panel()
	panel.custom_minimum_size = Vector2(420, 480)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-460, -240)
	add_child(panel)

	var outer_vbox := UIStyle.make_vbox(10)
	panel.add_child(outer_vbox)
	outer_vbox.add_child(UIStyle.make_title("Editor de Mira", 22))

	var tabs := TabContainer.new()
	tabs.theme = UIStyle.theme
	tabs.custom_minimum_size = Vector2(380, 400)
	outer_vbox.add_child(tabs)

	_build_general_tab(tabs)
	_build_color_tab(tabs)
	_build_outline_tab(tabs)
	_build_dot_tab(tabs)
	_build_dynamic_tab(tabs)
	_build_presets_tab(tabs)

	var back_button := UIStyle.make_button("Voltar")
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.position = Vector2(20, -60)
	add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.json ; Crosshair Preset")
	file_dialog.size = Vector2i(600, 400)
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_file_dialog_selected)


func _row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hbox := UIStyle.make_hbox(10)
	hbox.add_child(UIStyle.make_row_label(label_text))
	hbox.add_child(control)
	parent.add_child(hbox)


func _build_general_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Geral"
	tabs.add_child(vbox)
	var c := CrosshairManager

	var type_option := UIStyle.make_option_button()
	type_option.add_item("Cruz", CrosshairManager.Type.CROSS)
	type_option.add_item("Cruz Fina", CrosshairManager.Type.CROSS_THIN)
	type_option.add_item("Cruz Grossa", CrosshairManager.Type.CROSS_THICK)
	type_option.add_item("Apenas Ponto", CrosshairManager.Type.DOT_ONLY)
	type_option.add_item("Círculo", CrosshairManager.Type.CIRCLE)
	type_option.add_item("Círculo + Ponto", CrosshairManager.Type.CIRCLE_DOT)
	type_option.add_item("Dinâmica", CrosshairManager.Type.DYNAMIC)
	type_option.add_item("Estática", CrosshairManager.Type.STATIC)
	type_option.select(type_option.get_item_index(c.get_field("type")))
	_row(vbox, "Tipo", type_option)
	type_option.item_selected.connect(func(idx): c.set_field("type", type_option.get_item_id(idx)))

	var size_slider := UIStyle.make_slider(2.0, 30.0, 1.0, c.get_field("size"))
	_row(vbox, "Tamanho", size_slider)
	size_slider.value_changed.connect(func(v): c.set_field("size", v))

	var thickness_slider := UIStyle.make_slider(1.0, 8.0, 0.5, c.get_field("thickness"))
	_row(vbox, "Espessura", thickness_slider)
	thickness_slider.value_changed.connect(func(v): c.set_field("thickness", v))

	var gap_slider := UIStyle.make_slider(0.0, 20.0, 1.0, c.get_field("gap"))
	_row(vbox, "Distância (gap)", gap_slider)
	gap_slider.value_changed.connect(func(v): c.set_field("gap", v))

	var opacity_slider := UIStyle.make_slider(0.0, 1.0, 0.05, c.get_field("opacity"))
	_row(vbox, "Opacidade", opacity_slider)
	opacity_slider.value_changed.connect(func(v): c.set_field("opacity", v))


func _build_color_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Cor"
	tabs.add_child(vbox)
	var c := CrosshairManager

	var color_picker := ColorPickerButton.new()
	color_picker.color = c.get_field("color")
	color_picker.custom_minimum_size = Vector2(200, 34)
	vbox.add_child(color_picker)
	color_picker.color_changed.connect(func(col): c.set_field("color", col))


func _build_outline_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Outline"
	tabs.add_child(vbox)
	var c := CrosshairManager

	var outline_check := UIStyle.make_checkbox("Ativar outline", c.get_field("outline"))
	vbox.add_child(outline_check)
	outline_check.toggled.connect(func(v): c.set_field("outline", v))

	var outline_thickness_slider := UIStyle.make_slider(0.0, 4.0, 0.5, c.get_field("outline_thickness"))
	_row(vbox, "Espessura", outline_thickness_slider)
	outline_thickness_slider.value_changed.connect(func(v): c.set_field("outline_thickness", v))

	var outline_opacity_slider := UIStyle.make_slider(0.0, 1.0, 0.05, c.get_field("outline_opacity"))
	_row(vbox, "Opacidade", outline_opacity_slider)
	outline_opacity_slider.value_changed.connect(func(v): c.set_field("outline_opacity", v))


func _build_dot_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Ponto Central"
	tabs.add_child(vbox)
	var c := CrosshairManager

	var dot_check := UIStyle.make_checkbox("Mostrar ponto central", c.get_field("center_dot"))
	vbox.add_child(dot_check)
	dot_check.toggled.connect(func(v): c.set_field("center_dot", v))

	var dot_size_slider := UIStyle.make_slider(1.0, 8.0, 0.5, c.get_field("dot_size"))
	_row(vbox, "Tamanho", dot_size_slider)
	dot_size_slider.value_changed.connect(func(v): c.set_field("dot_size", v))

	var dot_opacity_slider := UIStyle.make_slider(0.0, 1.0, 0.05, c.get_field("dot_opacity"))
	_row(vbox, "Opacidade", dot_opacity_slider)
	dot_opacity_slider.value_changed.connect(func(v): c.set_field("dot_opacity", v))


func _build_dynamic_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Dinâmica"
	tabs.add_child(vbox)
	var c := CrosshairManager

	var expand_shoot_check := UIStyle.make_checkbox("Expandir ao atirar", c.get_field("expand_on_shoot"))
	vbox.add_child(expand_shoot_check)
	expand_shoot_check.toggled.connect(func(v): c.set_field("expand_on_shoot", v))

	var expand_run_check := UIStyle.make_checkbox("Expandir ao correr", c.get_field("expand_on_run"))
	vbox.add_child(expand_run_check)
	expand_run_check.toggled.connect(func(v): c.set_field("expand_on_run", v))

	var expand_jump_check := UIStyle.make_checkbox("Expandir ao pular", c.get_field("expand_on_jump"))
	vbox.add_child(expand_jump_check)
	expand_jump_check.toggled.connect(func(v): c.set_field("expand_on_jump", v))

	var expand_amount_slider := UIStyle.make_slider(1.0, 20.0, 1.0, c.get_field("expand_amount"))
	_row(vbox, "Quantidade", expand_amount_slider)
	expand_amount_slider.value_changed.connect(func(v): c.set_field("expand_amount", v))

	var return_speed_slider := UIStyle.make_slider(1.0, 20.0, 1.0, c.get_field("return_speed"))
	_row(vbox, "Velocidade de retorno", return_speed_slider)
	return_speed_slider.value_changed.connect(func(v): c.set_field("return_speed", v))


func _build_presets_tab(tabs: TabContainer) -> void:
	var vbox := UIStyle.make_vbox(8)
	vbox.name = "Presets"
	tabs.add_child(vbox)

	preset_list = ItemList.new()
	preset_list.theme = UIStyle.theme
	preset_list.custom_minimum_size = Vector2(340, 160)
	vbox.add_child(preset_list)
	_refresh_preset_list()

	preset_name_input = LineEdit.new()
	preset_name_input.theme = UIStyle.theme
	preset_name_input.placeholder_text = "Nome do preset"
	vbox.add_child(preset_name_input)

	var row1 := UIStyle.make_hbox(8)
	vbox.add_child(row1)
	var save_button := UIStyle.make_small_button("Salvar")
	var load_button := UIStyle.make_small_button("Carregar")
	var delete_button := UIStyle.make_small_button("Excluir")
	row1.add_child(save_button)
	row1.add_child(load_button)
	row1.add_child(delete_button)

	var row2 := UIStyle.make_hbox(8)
	vbox.add_child(row2)
	var export_button := UIStyle.make_small_button("Exportar")
	var import_button := UIStyle.make_small_button("Importar")
	row2.add_child(export_button)
	row2.add_child(import_button)

	save_button.pressed.connect(_on_save_preset)
	load_button.pressed.connect(_on_load_preset)
	delete_button.pressed.connect(_on_delete_preset)
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)


func _refresh_preset_list() -> void:
	preset_list.clear()
	for preset_name in CrosshairManager.list_presets():
		preset_list.add_item(preset_name)


func _on_save_preset() -> void:
	var preset_name: String = preset_name_input.text
	if preset_name.strip_edges().is_empty():
		return
	CrosshairManager.save_preset(preset_name)
	_refresh_preset_list()
	AudioManager.play_ui()


func _on_load_preset() -> void:
	var selected: PackedInt32Array = preset_list.get_selected_items()
	if selected.is_empty():
		return
	CrosshairManager.load_preset(preset_list.get_item_text(selected[0]))
	AudioManager.play_ui()


func _on_delete_preset() -> void:
	var selected: PackedInt32Array = preset_list.get_selected_items()
	if selected.is_empty():
		return
	CrosshairManager.delete_preset(preset_list.get_item_text(selected[0]))
	_refresh_preset_list()
	AudioManager.play_ui()


func _on_export_pressed() -> void:
	_dialog_mode = "export"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()


func _on_import_pressed() -> void:
	_dialog_mode = "import"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()


func _on_file_dialog_selected(path: String) -> void:
	if _dialog_mode == "export":
		CrosshairManager.export_to_path(path)
	else:
		CrosshairManager.import_from_path(path)


func _on_back_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/SettingsMenu.tscn")
