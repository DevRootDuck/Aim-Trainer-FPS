extends Node

# ============================================================
# SettingsManager (Autoload / Singleton)
#
# Guarda todas as configurações do jogador (mouse, áudio, vídeo,
# interface), aplica em tempo real e persiste em disco
# (user://save/settings.cfg) entre sessões.
# ============================================================

signal settings_changed

const SAVE_PATH := "user://save/settings.cfg"

var data: Dictionary = {
	"mouse": {
		"sensitivity": 0.0025,
		"invert_y": false,
		"smoothing": 0.0,          # 0 = sem suavização, até ~0.5
	},
	"audio": {
		"master": 1.0,
		"music": 0.5,
		"shots": 1.0,
		"footsteps": 0.8,
		"ui": 0.8,
		"headshot": 1.0,
		"music_enabled": true,
	},
	"video": {
		"fullscreen": true,
		"resolution": Vector2i(1920, 1080),
		"max_fps": 0,              # 0 = ilimitado
		"vsync": true,
		"fov": 90.0,
		"shadow_quality": 1,       # 0 baixo, 1 médio, 2 alto
		"texture_quality": 1,
		"render_distance": 150.0,
		"antialiasing": 1,         # 0 off, 1 FXAA, 2 MSAA2x
		"quality_preset": 1,       # 0 baixo, 1 médio, 2 alto
	},
	"interface": {
		"show_fps": true,
		"show_ping": false,
		"show_stats": true,
	}
}


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for section in data.keys():
		for key in data[section].keys():
			if cfg.has_section_key(section, key):
				data[section][key] = cfg.get_value(section, key)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section in data.keys():
		for key in data[section].keys():
			cfg.set_value(section, key, data[section][key])
	DirAccess.make_dir_recursive_absolute("user://save")
	cfg.save(SAVE_PATH)


func set_value(section: String, key: String, value) -> void:
	data[section][key] = value
	apply_all()
	emit_signal("settings_changed", section, key, value)
	save_settings()


func get_value(section: String, key: String):
	return data[section][key]


func apply_all() -> void:
	_apply_video()
	_apply_audio()


func _apply_video() -> void:
	var v: Dictionary = data["video"]

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if v["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not v["fullscreen"]:
		DisplayServer.window_set_size(v["resolution"])

	Engine.max_fps = v["max_fps"]
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED
	)

	match int(v["antialiasing"]):
		0:
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1:
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:
			get_viewport().msaa_3d = Viewport.MSAA_2X


func _apply_audio() -> void:
	var a: Dictionary = data["audio"]
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(a["master"]))

	_set_bus_volume("Music", a["music"] if a["music_enabled"] else 0.0)
	_set_bus_volume("SFX", a["shots"])
	_set_bus_volume("Footsteps", a["footsteps"])
	_set_bus_volume("UI", a["ui"])
	_set_bus_volume("Headshot", a["headshot"])


func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear_value, 0.0001)))


func apply_quality_preset(preset: int) -> void:
	# 0 = Baixo, 1 = Médio, 2 = Alto
	set_value("video", "quality_preset", preset)
	match preset:
		0:
			set_value("video", "shadow_quality", 0)
			set_value("video", "texture_quality", 0)
			set_value("video", "render_distance", 90.0)
			set_value("video", "antialiasing", 0)
		1:
			set_value("video", "shadow_quality", 1)
			set_value("video", "texture_quality", 1)
			set_value("video", "render_distance", 150.0)
			set_value("video", "antialiasing", 1)
		2:
			set_value("video", "shadow_quality", 2)
			set_value("video", "texture_quality", 2)
			set_value("video", "render_distance", 250.0)
			set_value("video", "antialiasing", 2)
