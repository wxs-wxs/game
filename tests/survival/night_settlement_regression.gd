extends SceneTree

const NightSettlementService = preload("res://scripts/domain/survival/night_settlement_service.gd")

func _init() -> void:
	_test_contract_and_food()
	_test_storm_water_and_illness()
	_test_starvation_health_gate_and_audio()
	_test_missing_context_key()
	_test_invalid_context_types()
	print("NIGHT_SETTLEMENT_REGRESSION_OK")
	quit()

func _test_contract_and_food() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.resources.amounts["food"] = 2
	game.survivors[0].hunger = 50
	_stabilize_strategy(game)
	var result := NightSettlementService.new().resolve(_context(game))
	_assert_result_keys(result)
	assert(game.resources.get_amount("food") == 2)
	assert(game.survivors[0].hunger == 68)
	assert(result.no_food_days == 0)
	assert("消耗 1 食物" in "\n".join(result.report_lines))
	var ids := _audio_ids(result)
	assert(ids.has("event.reveal"))
	assert(ids[-1] == "night.report")
	assert(ids.find("event.reveal") < ids.find("night.report"))
	assert(result.night_context.temperature_before == game.environment_temperature)

func _test_storm_water_and_illness() -> void:
	var game := GameManager.new()
	game.weather = "暴雨"
	game.start_exploration()
	game.resources.amounts["food"] = 1
	game.resources.amounts["water"] = 0
	game.buildings.built["rain_collector"] = 1
	game.rng.seed = _storm_seed()
	_stabilize_strategy(game)
	var result := NightSettlementService.new().resolve(_context(game))
	assert(game.resources.get_amount("water") == 3)
	assert(game.survivors[0].sick)
	assert(game.survivors[0].health == 96)
	assert("暴雨收集：获得 3 水" in "\n".join(result.report_lines))
	assert("着凉生病" in "\n".join(result.report_lines))

func _test_starvation_health_gate_and_audio() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.resources.amounts["food"] = 0
	game.survivors[0].health = 10
	game.survivors[0].hunger = 0
	_stabilize_strategy(game)
	var result := NightSettlementService.new().resolve(_context(game, 2))
	_assert_result_keys(result)
	assert(result.no_food_days == 3)
	assert(result.health_depleted)
	assert(result.phase == GameManager.PHASE_ENDED)
	assert(not result.audio_events.any(func(item): return str(item.get("id", "")) == "night.report"))
	var ids := _audio_ids(result)
	assert(ids[-2] == "player.death")
	assert(ids[-1] == "game.over")
	assert("没能撑过这一夜" in "\n".join(result.report_lines))

func _test_missing_context_key() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var context := _context(game)
	context.erase("resources")
	var result := NightSettlementService.new().resolve(context)
	_assert_result_keys(result)
	assert(result.phase == "error")
	assert(result.event.is_empty())
	assert(result.audio_events.is_empty())
	assert("resources" in result.report_lines[-1])

func _test_invalid_context_types() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var service := NightSettlementService.new()
	var invalid_lines := _context(game)
	invalid_lines["report_lines"] = "not-an-array"
	var line_result := service.resolve(invalid_lines)
	_assert_result_keys(line_result)
	assert(line_result.phase == "error")
	var invalid_temperature := _context(game)
	invalid_temperature["temperature_before"] = "not-a-number"
	var temperature_result := service.resolve(invalid_temperature)
	_assert_result_keys(temperature_result)
	assert(temperature_result.phase == "error")
	var nan_temperature := _context(game)
	nan_temperature["temperature_before"] = NAN
	var nan_result := service.resolve(nan_temperature)
	_assert_result_keys(nan_result)
	assert(nan_result.phase == "error")
	var invalid_survivor := _context(game)
	invalid_survivor["survivors"] = [{}]
	var survivor_result := service.resolve(invalid_survivor)
	_assert_result_keys(survivor_result)
	assert(survivor_result.phase == "error")

func _context(game: GameManager, no_food_days: int = 0) -> Dictionary:
	return {
		"day": game.day, "weather": game.weather, "resources": game.resources,
		"survivors": game.survivors, "buildings": game.buildings,
		"survival": game.survival, "events": game.events, "rng": game.rng,
		"fire_states": game.fire_states, "house_level": game.house_level,
		"in_house": game.in_house, "temperature_before": game.environment_temperature,
		"no_food_days": no_food_days, "report_lines": []
	}

func _stabilize_strategy(game: GameManager) -> void:
	game.survival.current_goal = {"id":"test_stock", "kind":"resource_stock", "resource":"metal", "target":9999, "label":"测试目标", "reward":{}, "progress":0, "completed":false}
	game.survival.goal_day = game.day
	game.survival.last_started_day = game.day
	game.survival.last_settled_day = -1
	game.survival.policy_id = "balanced"

func _storm_seed() -> int:
	for seed in range(1, 100):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		if probe.randf() < 0.35:
			return seed
	return 1

func _audio_ids(result: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for item in result.audio_events:
		ids.append(str(item.get("id", "")))
	return ids

func _assert_result_keys(result: Dictionary) -> void:
	for key in ["report_lines", "phase", "event", "health_depleted", "night_context", "audio_events"]:
		assert(result.has(key), "missing result key: %s" % key)
