class_name SnapshotContract
extends RefCounted

static func copy(data: Dictionary) -> Dictionary:
	return data.duplicate(true)

static func require_keys(data: Dictionary, keys: Array[String]) -> bool:
	for key in keys:
		if not data.has(key):
			return false
	return true
