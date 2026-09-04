extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var resources := game.resources
	resources.backpack_capacity = 1
	resources.backpack = {"wood": 0}
	resources.storage = {}
	resources.amounts["stone"] = 0
	resources.amounts["fiber"] = 0
	resources.amounts["wood"] = 0
	resources.add("wood", 0)
	var rewards := {"stone": 2, "fiber": 2}
	var before_wood := resources.get_amount("wood")
	var result: Dictionary = resources.collect_rewards_atomic(rewards, "test")
	assert(not bool(result.get("ok", false)))
	assert(resources.get_amount("wood") == before_wood)
	assert(resources.get_amount("stone") == 0)
	assert(resources.get_amount("fiber") == 0)
	var director: SurvivalDirector = game.survival
	assert(is_equal_approx(director.gather_multiplier("晴朗"), 1.0))
	assert(is_equal_approx(director.gather_multiplier("浓雾"), 1.0))
	assert(is_equal_approx(director.gather_multiplier("暴雨"), 1.0))
	var worker := Survivor.new()
	worker.id = "worker"
	worker.display_name = "工人"
	worker.current_work = "搜寻食物"
	var worker_buildings := BuildingSystem.new()
	var worker_rng := RandomNumberGenerator.new()
	worker_rng.seed = 7
	var worker_before_slots := resources.backpack_slots_used()
	var worker_lines := TaskSystem.new().resolve_tick([worker], resources, worker_buildings, "暴雨", worker_rng)
	assert(not worker_lines.is_empty())
	assert(resources.backpack_slots_used() == worker_before_slots)
	assert(int(resources.storage.get("food", 0)) > 0)
	print("RESOURCE_ATOMIC_WEATHER_REGRESSION_OK")
	quit()
