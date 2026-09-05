extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var status: Dictionary = game.get_survival_status()
	assert(not status.has("threat"))
	assert(not status.has("threat_label"))
	assert(not status.has("safety"))
	var weather_effect: Dictionary = game.get_weather_effect()
	assert(not weather_effect.has("threat_delta"))
	var saved: Dictionary = game.to_dict()
	assert(not saved.has("safety"))
	var saved_survival: Dictionary = saved.get("survival", {})
	assert(not saved_survival.has("threat"))

	var restored := GameManager.new()
	restored.from_dict({
		"version": 8,
		"day": 3,
		"safety": 1,
		"survival": {"threat": 100, "policy_id": "balanced", "current_goal": {}}
	})
	assert(not restored.get_survival_status().has("threat"))
	assert(not restored.to_dict().has("safety"))
	var migrated := SaveSystem.new().migrate({
		"version": 8,
		"safety": 1,
		"night_context": {"threat_before": 100, "day": 3},
		"survival": {"threat": 100}
	})
	assert(not migrated.has("safety"))
	assert(not migrated.get("night_context", {}).has("threat_before"))
	assert(not migrated.get("survival", {}).has("threat"))

	var events := EventSystem.new()
	var low_weight := events.event_weight("beast", {"weather": "多云", "built_facilities": [], "threat": 0})
	var high_weight := events.event_weight("beast", {"weather": "多云", "built_facilities": [], "threat": 100})
	assert(low_weight == high_weight)
	print("THREAT_REMOVAL_REGRESSION_OK")
	quit()
