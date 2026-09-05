extends SceneTree

func _init() -> void:
	var game := GameManager.new(); game.start_exploration()
	game.buildings.complete("workbench"); game.apply_building_effect("workbench")
	var resources := game.resources
	resources.amounts["water"] = 5; resources.amounts["cloth"] = 3; resources.amounts["medicine"] = 3
	resources.amounts["wood"] = 10; resources.amounts["fiber"] = 3; resources.amounts["metal"] = 3
	resources.storage["cloth"] = 0; resources.storage["medicine"] = 0; resources.storage["wood"] = 0; resources.storage["fiber"] = 0; resources.storage["metal"] = 0
	resources.backpack_capacity = ResourceManager.BACKPACK_UPGRADED_CAPACITY

	# Cooking is a direct backpack action, independent of the removed fuel item.
	resources.backpack["food"] = 1; resources.amounts["food"] = 1; resources.storage["food"] = 0
	assert(resources.cook_berries().get("ok", false))
	assert(resources.backpack["food"] == 0 and resources.backpack["cooked_food"] == 1)
	var fish_key := "fish_carp"
	resources.backpack[fish_key] = 1; resources.amounts[fish_key] = 1
	var cooked := resources.cook_fish(fish_key)
	assert(cooked.get("ok", false)); assert(resources.backpack[fish_key] == 0)
	var cooked_key := resources.cooked_fish_key(fish_key)
	assert(resources.backpack[cooked_key] == 1)

	# Raw food gives a small heal, cooked food gives a large heal, and medicine
	# fills health completely.
	var hero := game.get_protagonist(); hero.health = 50; hero.hunger = 20
	assert(game.use_item("cooked_food").get("ok", false)); assert(hero.health == 78)
	resources.backpack["food"] = 1; resources.amounts["food"] = 1
	assert(game.use_item("food").get("ok", false)); assert(hero.health == 81)
	assert(game.use_item(cooked_key).get("ok", false)); assert(hero.health == 100)
	resources.backpack["medicine"] = 1; resources.amounts["medicine"] = 1
	hero.health = 42; hero.injured = true
	assert(game.use_item("medicine").get("ok", false)); assert(hero.health == 100 and not hero.injured)

	# Existing utility recipes remain available with current resources only.
	resources.amounts["medicine"] = 3; resources.storage["medicine"] = 3
	for id in ["bandage", "torch", "trap"]:
		var crafted: Dictionary = game.craft_item(id)
		assert(crafted.get("ok", false), id)
	assert(resources.backpack["bandage"] == 1 and resources.backpack["torch"] == 1 and resources.backpack["trap"] == 1)
	assert(game.use_item("torch").get("ok", false)); assert(game.torch_bonus_pending)
	assert(game.use_item("trap").get("ok", false)); assert(game.deployed_traps == 1)

	var state := resources.to_dict()
	assert(not state["amounts"].has("fuel") and not state["amounts"].has("scrap"))
	var restored := ResourceManager.new(); restored.from_dict(state)
	assert(restored.backpack[cooked_key] == 0 and restored.backpack["medicine"] == 0)
	print("CRAFTING_REGRESSION_OK cooked=%s medicine=%d trap=%d" % [cooked_key, hero.health, game.deployed_traps])
	quit()
