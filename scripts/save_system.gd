class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://embers_camp_save.json"
const CURRENT_VERSION := 9

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

## Normalize old saves before any gameplay system consumes them. Unknown keys
## are intentionally retained at the top level for forward compatibility, but
## known nested collections are filtered by their owning systems.
func migrate(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var version := maxi(0, int(result.get("version", 0)))
	if version < CURRENT_VERSION:
		result["day_return_required"] = bool(result.get("day_return_required", false))
		result["night_settlement_applied"] = false
		result["night_context"] = {}
		# Leave the legacy fire flag visible to GameManager so it can grant the
		# documented one-time compatibility fuel using the current fire config.
		if not result.has("fire_states") and not bool(result.get("house_fire_lit", false)):
			result["fire_states"] = {}
		version = CURRENT_VERSION
	else:
		if not result.has("day_return_required"): result["day_return_required"] = false
		if not result.has("night_settlement_applied"): result["night_settlement_applied"] = false
		if not result.has("night_context"): result["night_context"] = {}
	var night_context: Variant = result.get("night_context", {})
	if night_context is Dictionary:
		var normalized_night_context: Dictionary = night_context.duplicate(true)
		normalized_night_context.erase("threat_before")
		result["night_context"] = normalized_night_context

	# Normalize the old split construction representation to one active project.
	var building_data: Variant = result.get("buildings", {})
	if building_data is Dictionary:
		var normalized_buildings: Dictionary = building_data.duplicate(true)
		var active: Variant = normalized_buildings.get("active_project", {})
		var legacy_world: Variant = normalized_buildings.get("world_projects", {})
		if (not active is Dictionary or active.is_empty()) and legacy_world is Dictionary and not legacy_world.is_empty():
			var legacy_values: Array = legacy_world.values()
			if not legacy_values.is_empty() and legacy_values[0] is Dictionary:
				normalized_buildings["active_project"] = legacy_values[0].duplicate(true)
		elif active is Dictionary and not active.is_empty() and legacy_world is Dictionary and not legacy_world.is_empty():
			var refund: Dictionary = {}
			for legacy_value in legacy_world.values():
				if not legacy_value is Dictionary:
					continue
				var legacy_cost: Variant = legacy_value.get("cost", {})
				if legacy_cost is Dictionary:
					for key in legacy_cost:
						refund[str(key)] = int(refund.get(str(key), 0)) + maxi(0, int(legacy_cost[key]))
			if not refund.is_empty():
				result["migration_refund"] = refund
		normalized_buildings["world_projects"] = {}
		result["buildings"] = normalized_buildings

	# The seven-day goal is no longer active. Historical milestone strings stay
	# untouched in unlocked_milestones and the daily log.
	var survival_data: Variant = result.get("survival", {})
	if survival_data is Dictionary:
		var normalized_survival: Dictionary = survival_data.duplicate(true)
		# Threat was removed in save version 9. Old values are intentionally
		# discarded so the retired mechanic cannot re-enter runtime state.
		normalized_survival.erase("threat")
		var goal: Variant = normalized_survival.get("current_goal", {})
		if goal is Dictionary and str(goal.get("id", "")) == "week_survivor":
			normalized_survival["current_goal"] = {}
		result["survival"] = normalized_survival
	result.erase("safety")

	result["version"] = CURRENT_VERSION
	return result
