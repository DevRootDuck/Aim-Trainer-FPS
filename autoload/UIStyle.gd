extends Node

# ============================================================
# UIStyle (Autoload / Singleton)
#
# Fábrica de widgets com visual consistente para todo o jogo:
# botões, painéis, sliders, checkboxes e labels compartilham a
# mesma paleta minimalista escura com um acento verde-ciano.
# Centralizar aqui evita duplicar StyleBoxes em cada menu e
# garante uma identidade visual única e coerente.
# ============================================================

const COLOR_BG := Color(0.07, 0.08, 0.09, 0.92)
const COLOR_PANEL := Color(0.1, 0.11, 0.13, 0.96)
const COLOR_ACCENT := Color(0.15, 0.85, 0.65)
const COLOR_ACCENT_DIM := Color(0.15, 0.85, 0.65, 0.5)
const COLOR_TEXT := Color(0.92, 0.93, 0.94)
const COLOR_TEXT_DIM := Color(0.65, 0.67, 0.7)
const COLOR_DANGER := Color(0.9, 0.3, 0.3)

var theme: Theme


func _ready() -> void:
	theme = Theme.new()
	_setup_button_style()
	_setup_label_style()
	_setup_slider_style()
	_setup_panel_style()
	_setup_checkbox_style()
	_setup_option_button_style()
	_setup_line_edit_style()


func _flat_style(color: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _setup_button_style() -> void:
	var normal := _flat_style(Color(0.14, 0.15, 0.17))
	var hover := _flat_style(Color(0.18, 0.2, 0.22))
	var pressed := _flat_style(COLOR_ACCENT_DIM)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_ACCENT)
	theme.set_font_size("font_size", "Button", 16)


func _setup_label_style() -> void:
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_font_size("font_size", "Label", 15)


func _setup_slider_style() -> void:
	var groove := _flat_style(Color(0.16, 0.17, 0.19), 4)
	var fill := _flat_style(COLOR_ACCENT, 4)
	theme.set_stylebox("slider", "HSlider", groove)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)


func _setup_panel_style() -> void:
	var sb := _flat_style(COLOR_PANEL, 10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	theme.set_stylebox("panel", "PanelContainer", sb)
	theme.set_stylebox("panel", "Panel", sb)


func _setup_checkbox_style() -> void:
	theme.set_color("font_color", "CheckBox", COLOR_TEXT)


func _setup_option_button_style() -> void:
	var normal := _flat_style(Color(0.14, 0.15, 0.17))
	theme.set_stylebox("normal", "OptionButton", normal)
	theme.set_color("font_color", "OptionButton", COLOR_TEXT)


func _setup_line_edit_style() -> void:
	var normal := _flat_style(Color(0.12, 0.13, 0.15))
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)


# ---------------- Fábrica de widgets ----------------

func make_title(text: String, size: int = 34) -> Label:
	var l := Label.new()
	l.text = text
	l.theme = theme
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLOR_ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func make_label(text: String, dim: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme = theme
	if dim:
		l.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	return l


func make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme
	b.custom_minimum_size = Vector2(220, 42)
	b.focus_mode = Control.FOCUS_NONE
	return b


func make_small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme
	b.custom_minimum_size = Vector2(110, 34)
	b.focus_mode = Control.FOCUS_NONE
	return b


func make_slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.theme = theme
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	return s


func make_checkbox(text: String, checked: bool = false) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.theme = theme
	c.button_pressed = checked
	c.focus_mode = Control.FOCUS_NONE
	return c


func make_option_button() -> OptionButton:
	var o := OptionButton.new()
	o.theme = theme
	o.custom_minimum_size = Vector2(220, 36)
	o.focus_mode = Control.FOCUS_NONE
	return o


func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = theme
	return p


func make_vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func make_hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func make_row_label(text: String) -> Label:
	var l := make_label(text)
	l.custom_minimum_size = Vector2(170, 0)
	return l


func make_background(parent_size_control: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg
