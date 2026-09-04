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
	print("RESOURCE_ATOMIC_WEATHER_REGRESSION_OK")
	quit()
