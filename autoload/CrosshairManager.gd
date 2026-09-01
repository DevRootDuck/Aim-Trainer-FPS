extends Node

# ============================================================
# CrosshairManager (Autoload / Singleton)
#
# Guarda toda a configuração da mira (cor, tamanho, espessura,
# gap, opacidade, outline, ponto central, tipo, comportamento
# dinâmico) e permite salvar/carregar/importar/exportar presets
# como arquivos JSON em user://save/crosshairs/.
# ============================================================

signal crosshair_changed

const PRESET_DIR := "user://save/crosshairs"
const LAST_PATH := "user://save/crosshair_last.json"

enum Type { CROSS, CROSS_THIN, CROSS_THICK, DOT_ONLY, CIRCLE, CIRCLE_DOT, DYNAMIC, STATIC }

var config: Dictionary = {
	"type": Type.CROSS,
	"color": Color(0.15, 1.0, 0.4),
	"size": 10.0,
	"thickness": 2.0,
	"gap": 6.0,
	"opacity": 1.0,
	"outline": true,
	"outline_thickness": 1.0,
	"outline_opacity": 0.6,
	"center_dot": true,
	"dot_size": 2.0,
	"dot_opacity": 1.0,
	"expand_on_shoot": true,
	"expand_on_run": true,
	"expand_on_jump": true,
	"expand_amount": 6.0,
	"return_speed": 8.0,
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PRESET_DIR)
	_load_json(LAST_PATH)


func set_field(key: String, value) -> void:
	config[key] = value
	emit_signal("crosshair_changed")
	_save_json(LAST_PATH)


func get_field(key: String):
	return config.get(key)


func _config_to_dict() -> Dictionary:
	var out := {}
	for key in config.keys():
		var v = config[key]
		if v is Color:
			out[key] = {"r": v.r, "g": v.g, "b": v.b, "a": v.a}
		else:
			out[key] = v
	return out


func _dict_to_config(d: Dictionary) -> void:
	for key in d.keys():
		if not config.has(key):
			continue
		var v = d[key]
		if typeof(v) == TYPE_DICTIONARY and v.has("r"):
			config[key] = Color(v["r"], v["g"], v["b"], v["a"])
		else:
			config[key] = v
	emit_signal("crosshair_changed")


func _save_json(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_config_to_dict(), "\t"))
		f.close()


func _load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_dict_to_config(parsed)
		return true
	return false


func save_preset(preset_name: String) -> void:
	var safe_name := preset_name.strip_edges().validate_filename()
	if safe_name.is_empty():
		return
	_save_json(PRESET_DIR + "/" + safe_name + ".json")


func load_preset(preset_name: String) -> void:
	_load_json(PRESET_DIR + "/" + preset_name + ".json")
	_save_json(LAST_PATH)


func delete_preset(preset_name: String) -> void:
	DirAccess.remove_absolute(PRESET_DIR + "/" + preset_name + ".json")


func list_presets() -> Array:
	var result := []
	var dir := DirAccess.open(PRESET_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				result.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	return result


func export_to_path(path: String) -> void:
	_save_json(path)


func import_from_path(path: String) -> bool:
	var ok := _load_json(path)
	if ok:
		_save_json(LAST_PATH)
	return ok
