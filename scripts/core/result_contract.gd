class_name ResultContract
extends RefCounted

static func ok(data: Dictionary = {}, reason: String = "") -> Dictionary:
	return {
		"ok": true,
		"reason": reason,
		"changed": true,
		"data": data,
	}

static func fail(reason: String, data: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"changed": false,
		"data": data,
	}

static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var result: Dictionary = value
	for key in ["ok", "reason", "changed", "data"]:
		if not result.has(key):
			return false
	return typeof(result["ok"]) == TYPE_BOOL \
		and typeof(result["changed"]) == TYPE_BOOL
