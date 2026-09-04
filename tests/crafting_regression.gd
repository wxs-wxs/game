extends SceneTree

func _init() -> void:
	var game := GameManager.new(); game.start_exploration()
	game.buildings.complete("workbench"); game.apply_building_effect("workbench")
	var resources := game.resources
	resources.backpack_owned = true; resources.backpack_capacity = ResourceManager.BACKPACK_UPGRADED_CAPACITY
	resources.amounts["food"] = 10; resources.amounts["water"] = 5; resources.amounts["fuel"] = 5; resources.amounts["cloth"] = 3; resources.amounts["medicine"] = 3; resources.amounts["wood"] = 10; resources.amounts["fiber"] = 3; resources.amounts["scrap"] = 3
	var before := resources.amounts.duplicate(true)
	resources.amounts["food"] = 0
	var failed: Dictionary = game.craft_item("cooked_food")
	assert(not failed.get("ok", false)); assert(resources.amounts["water"] == 5 and resources.amounts["fuel"] == 5)
	resources.amounts["food"] = 10
	# Full backpack with four different item types blocks a new output atomically.
	resources.backpack_capacity = ResourceManager.BACKPACK_BASE_CAPACITY
	for id in ["food", "wood", "stone", "metal"]: resources.backpack[id] = 1
	var blocked_before := resources.amounts.duplicate(true)
	var blocked: Dictionary = game.craft_item("cooked_food")
	assert(not blocked.get("ok", false)); assert(resources.amounts["water"] == blocked_before["water"])
	resources.backpack.clear(); for id in ResourceManager.ITEM_KEYS: resources.backpack[id] = 0
	resources.backpack_capacity = ResourceManager.BACKPACK_UPGRADED_CAPACITY
	for id in ["cooked_food", "bandage", "torch", "trap"]:
		var crafted: Dictionary = game.craft_item(id)
		assert(crafted.get("ok", false), id)
	assert(resources.backpack["cooked_food"] == 1 and resources.backpack["bandage"] == 1 and resources.backpack["torch"] == 1 and resources.backpack["trap"] == 1)
	var hero := game.get_protagonist(); hero.injured = true; hero.health = 50; hero.hunger = 20
	assert(game.use_item("cooked_food").get("ok", false)); assert(hero.hunger > 20)
	assert(game.use_item("bandage").get("ok", false)); assert(not hero.injured and hero.health > 50)
	assert(game.use_item("torch").get("ok", false)); assert(game.torch_bonus_pending)
	assert(game.use_item("trap").get("ok", false)); assert(game.deployed_traps == 1)
	game.phase = GameManager.PHASE_EVENT
	game.events.current_event = {"id":"beast", "data":{"title":"野兽", "choices":[{"id":"alarm", "label":"警戒", "cost":{}}]}}
	var event_result: Dictionary = game.choose_event(0)
	assert(event_result.get("ok", false)); assert(game.deployed_traps == 0)
	var saved := game.to_dict(); var restored := GameManager.new(); restored.from_dict(saved)
	assert(restored.resources.backpack["cooked_food"] == 0 and restored.resources.backpack["bandage"] == 0)
	assert(restored.resources.amounts["water"] >= 0)
	print("CRAFTING_REGRESSION_OK recipes=%d trap=%d" % [game.crafting.definitions.size(), game.deployed_traps])
	quit()
