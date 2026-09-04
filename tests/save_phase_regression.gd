extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.day_return_required = true
	var before := game.to_dict()
	assert(int(before.get("version", 0)) >= 8)
	assert(bool(before.get("day_return_required", false)))
	var restored := GameManager.new()
	restored.from_dict(before)
	assert(restored.phase == GameManager.PHASE_DAY)
	assert(restored.day_return_required)
	assert(not restored.night_settlement_applied)
	game.add_fire_fuel("campfire", 1)
	game.finish_exploration_day()
	game.night_context["marker"] = "saved"
	var night_data := game.to_dict()
	var night_restored := GameManager.new()
	night_restored.from_dict(night_data)
	assert(night_restored.phase == game.phase)
	assert(night_restored.events.current_event.get("id", "") == game.events.current_event.get("id", ""))
	assert(night_restored.night_context.get("marker", "") == "saved")
	assert(float(night_restored.fire_state("campfire").get("fuel_remaining", 0.0)) > 0.0)
	var old := {"version": 2, "day": 9, "resources": {"amounts": {"food": 2, "wood": 1, "medicine": 0, "water": 4}}}
	var migrated := GameManager.new()
	migrated.from_dict(old)
	assert(migrated.day == 9)
	assert(migrated.resources.get_amount("water") == 4)
	var old_fire := {"version": 2, "day": 3, "house_fire_lit": true}
	var migrated_fire := GameManager.new()
	migrated_fire.from_dict(old_fire)
	assert(migrated_fire.is_fire_active("house_fireplace"))
	assert(float(migrated_fire.fire_state("house_fireplace").get("fuel_remaining", 0.0)) > 0.0)
	print("SAVE_PHASE_REGRESSION_OK version=%d" % int(night_data.get("version", 0)))
	quit()
