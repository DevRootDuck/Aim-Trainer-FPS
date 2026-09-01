extends CanvasLayer

# ============================================================
# HUD
#
# Interface minimalista exibida durante o treino. Toda a UI é
# construída por código em _ready() (sem depender de layout
# manual em .tscn), o que facilita expandir/reorganizar no
# futuro só editando este script.
#
# Mostra: mira central, munição, FPS, tempo restante, precisão,
# headshots, kills, tempo médio de reação, modo atual, hitmarker
# e indicador de headshot.
# ============================================================

var crosshair: CrosshairView
var ammo_label: Label
var reload_bar: ProgressBar
var timer_label: Label
var mode_label: Label
var accuracy_label: Label
var kills_label: Label
var headshots_label: Label
var reaction_label: Label
var fps_label: Label
var hitmarker: Label
var headshot_indicator: Label

var _fps_refresh_time: float = 0.0


func _ready() -> void:
	_build_ui()

	GameManager.stats_updated.connect(_update_stats)
	GameManager.headshot_landed.connect(_show_headshot_indicator)
	reload_bar.visible = false
	hitmarker.modulate.a = 0.0
	headshot_indicator.modulate.a = 0.0
	_update_stats()

	# Modo solo: o Player estático já existe na cena antes da HUD, então
	# a arma já está pronta aqui. Em multiplayer, o Player "local" pode
	# ainda nem ter chegado (spawn assíncrono via rede) — nesse caso é a
	# Arena que chama bind_to_weapon() assim que ele existir de verdade.
	var weapon = get_tree().get_first_node_in_group("weapon")
	if weapon:
		bind_to_weapon(weapon)


func bind_to_weapon(weapon: Node) -> void:
	if not weapon:
		return
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.target_hit.connect(_on_target_hit)
	weapon.weapon_fired.connect(_on_weapon_fired)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Crosshair central ---
	crosshair = CrosshairView.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(crosshair)

	# --- Topo esquerdo: estatísticas ---
	var top_left := UIStyle.make_vbox(4)
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.position = Vector2(20, 20)
	root.add_child(top_left)
	accuracy_label = UIStyle.make_label("Precisão: 0.0%")
	kills_label = UIStyle.make_label("Kills: 0")
	headshots_label = UIStyle.make_label("Headshots: 0")
	reaction_label = UIStyle.make_label("Reação média: 0.00s")
	for l in [accuracy_label, kills_label, headshots_label, reaction_label]:
		top_left.add_child(l)

	# --- Topo direito: FPS ---
	var top_right := UIStyle.make_vbox(4)
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-140, 20)
	root.add_child(top_right)
	fps_label = UIStyle.make_label("FPS: 0")
	top_right.add_child(fps_label)

	# --- Topo centro: tempo e modo ---
	var top_center := UIStyle.make_vbox(2)
	top_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_center.position = Vector2(-80, 20)
	root.add_child(top_center)
	timer_label = UIStyle.make_title("01:00", 26)
	mode_label = UIStyle.make_label(GameManager.get_mode_name(), true)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_center.add_child(timer_label)
	top_center.add_child(mode_label)

	# --- Inferior direito: munição e recarga ---
	var bottom_right := UIStyle.make_vbox(4)
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.position = Vector2(-160, -80)
	root.add_child(bottom_right)
	ammo_label = UIStyle.make_title("30 / 30", 28)
	reload_bar = ProgressBar.new()
	reload_bar.custom_minimum_size = Vector2(140, 10)
	reload_bar.theme = UIStyle.theme
	reload_bar.show_percentage = false
	bottom_right.add_child(ammo_label)
	bottom_right.add_child(reload_bar)

	# --- Hitmarker (centro, acima do crosshair) ---
	hitmarker = Label.new()
	hitmarker.text = "✕"
	hitmarker.theme = UIStyle.theme
	hitmarker.add_theme_font_size_override("font_size", 26)
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.pivot_offset = Vector2(10, 13)
	root.add_child(hitmarker)

	# --- Indicador de HEADSHOT ---
	headshot_indicator = UIStyle.make_title("HEADSHOT!", 30)
	headshot_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	headshot_indicator.set_anchors_preset(Control.PRESET_CENTER)
	headshot_indicator.position += Vector2(-60, -80)
	root.add_child(headshot_indicator)


func _process(delta: float) -> void:
	_update_timer_display()
	_update_fps(delta)


func _update_timer_display() -> void:
	if GameManager.current_mode == GameManager.TrainMode.FREE_PLAY:
		timer_label.text = "∞"
	else:
		var remaining: float = max(0.0, GameManager.training_time_total - GameManager.training_time_elapsed)
		var minutes: int = int(remaining) / 60
		var seconds: int = int(remaining) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
	mode_label.text = GameManager.get_mode_name()


func _update_fps(delta: float) -> void:
	_fps_refresh_time += delta
	if _fps_refresh_time < 0.25:
		return
	_fps_refresh_time = 0.0
	fps_label.visible = SettingsManager.get_value("interface", "show_fps")
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _update_stats() -> void:
	accuracy_label.text = "Precisão: %.1f%%" % GameManager.get_accuracy()
	kills_label.text = "Kills: %d" % GameManager.kills
	headshots_label.text = "Headshots: %d" % GameManager.headshots
	reaction_label.text = "Reação média: %.2fs" % GameManager.get_average_reaction_time()
	var show_stats: bool = SettingsManager.get_value("interface", "show_stats")
	accuracy_label.visible = show_stats
	kills_label.visible = show_stats
	headshots_label.visible = show_stats
	reaction_label.visible = show_stats


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "%d / %d" % [current, max_ammo]


func _on_reload_started(duration: float) -> void:
	reload_bar.visible = true
	reload_bar.value = 0
	var tween := create_tween()
	tween.tween_property(reload_bar, "value", 100, duration)


func _on_reload_finished() -> void:
	reload_bar.visible = false


func _on_weapon_fired() -> void:
	crosshair.pulse_shoot()


func _on_target_hit(is_headshot: bool) -> void:
	_flash_hitmarker(is_headshot)


func _flash_hitmarker(is_headshot: bool) -> void:
	hitmarker.modulate = Color(1, 0.25, 0.25) if is_headshot else Color(1, 1, 1)
	hitmarker.modulate.a = 1.0
	hitmarker.scale = Vector2(1.4, 1.4) if is_headshot else Vector2(1.0, 1.0)
	var t := create_tween()
	t.tween_property(hitmarker, "modulate:a", 0.0, 0.25)


func _show_headshot_indicator() -> void:
	headshot_indicator.modulate.a = 1.0
	headshot_indicator.position = Vector2(-60, -80)
	var t := create_tween()
	t.tween_property(headshot_indicator, "position:y", -120, 0.4)
	t.parallel().tween_property(headshot_indicator, "modulate:a", 0.0, 0.5).set_delay(0.2)
