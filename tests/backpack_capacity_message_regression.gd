extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var resources := game.resources
	for key in ResourceManager.ITEM_KEYS:
		resources.backpack[key] = 0
	resources.amounts["stone"] = int(resources.capacities["stone"])
	var pebble := PebbleSpot.new()
	pebble.failure_chance = 0.0
	pebble.setup(game)
	assert(pebble.interact().get("started", false))
	var blocked := pebble.tick_interaction(pebble.interaction_time + 0.1)
	assert(blocked.get("failed", false))
	assert(str(blocked.get("message", "")).contains("石料"))
	assert(not str(blocked.get("message", "")).contains("整理背包"))

	resources.amounts["stone"] = 0
	var collected := pebble.interact()
	assert(collected.get("started", false))
	var success := pebble.tick_interaction(pebble.interaction_time + 0.1)
	assert(success.get("ok", false))
	assert(resources.backpack["stone"] == 1)

	print("BACKPACK_CAPACITY_MESSAGE_REGRESSION_OK")
	quit()
