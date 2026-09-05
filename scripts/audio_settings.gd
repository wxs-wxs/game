class_name AudioSettings
extends RefCounted

const KEYS := ["master", "music", "ambience", "sfx"]

var master: float = 1.0
var music: float = 1.0
var ambience: float = 1.0
var sfx: float = 1.0

func _init(data: Dictionary = {}) -> void:
	apply_dict(data)

func apply_dict(data: Dictionary) -> void:
	for key in KEYS:
		if data.has(key):
			set(key, clampf(float(data[key]), 0.0, 1.0))

func to_dict() -> Dictionary:
	return {
		"master": master,
		"music": music,
		"ambience": ambience,
		"sfx": sfx,
	}

func load_from_config(path: String = "user://audio_settings.cfg") -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	var data := {}
	for key in KEYS:
		if config.has_section_key("audio", key):
			data[key] = config.get_value("audio", key)
	apply_dict(data)
	return true

func save_to_config(path: String = "user://audio_settings.cfg") -> Error:
	var config := ConfigFile.new()
	for key in KEYS:
		config.set_value("audio", key, get(key))
	return config.save(path)
