class_name BlueprintSystem
extends RefCounted

## Compatibility facade for older callers. The BuildingSystem owns the
## catalog, unlocks, and completion state; this facade only exposes the old
## blueprint-shaped API.
var source: BuildingSystem
var definitions: Dictionary = {}
var unlocked: Array[String] = []

func setup(building_system: BuildingSystem) -> void:
	source = building_system
	definitions = source.definitions
	unlocked = source.unlocked

func _init() -> void:
	if source == null:
		var fallback := BuildingSystem.new()
		setup(fallback)

func unlock(blueprint_id: String) -> bool:
	if source == null: return false
	var result := source.unlock(blueprint_id)
	unlocked = source.unlocked
	return result

func is_unlocked(blueprint_id: String) -> bool:
	return source != null and source.is_unlocked(blueprint_id)

func available(skill_level: int) -> Array[String]:
	return source.available(skill_level) if source != null else []

func to_dict() -> Dictionary:
	return {"unlocked":source.unlocked.duplicate() if source != null else unlocked.duplicate()}

func from_dict(data: Dictionary) -> void:
	if source == null: return
	var payload := {"unlocked":data.get("unlocked", [])}
	var existing := source.to_dict()
	existing["unlocked"] = payload["unlocked"]
	source.from_dict(existing)
	definitions = source.definitions
	unlocked = source.unlocked
