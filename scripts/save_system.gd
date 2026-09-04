class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://embers_camp_save.json"

func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH): return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)
