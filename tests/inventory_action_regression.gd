extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	# New gathering rewards are carried by the survivor and respect the base cap.
	var resources := game.resources
	assert(resources.carried_count() == 0)
	assert(resources.backpack_capacity == ResourceManager.BACKPACK_BASE_CAPACITY)
	assert(resources.collect_from_source("stone", 2, "field_pebble") == 2)
	assert(resources.backpack["stone"] == 2)
	assert(resources.storage["stone"] == 4)

	# Crafting expands the carry limit and persists through serialization.
	var crafted := resources.craft_backpack()
	assert(crafted.get("ok", false))
	assert(resources.has_backpack())
	assert(resources.backpack_capacity == ResourceManager.BACKPACK_UPGRADED_CAPACITY)
	var restored := ResourceManager.new()
	restored.from_dict(resources.to_dict())
	assert(restored.has_backpack())
	assert(restored.backpack_capacity == ResourceManager.BACKPACK_UPGRADED_CAPACITY)
	assert(restored.backpack["stone"] == 2)

	# A field interaction starts a named action on the human player rather than
	# relying on a progress-bar state.
	var pebble: PebbleSpot = null
	for point in world.interactions:
		if point is PebbleSpot:
			pebble = point
			break
	assert(pebble != null)
	world.player.global_position = pebble.global_position
	world._process(0.1)
	world.try_interact()
	assert(world.player.action_active)
	assert(world.player.action_id == "pickup")
	world._process(pebble.interaction_time + 0.1)
	assert(not world.player.action_active)

	print("INVENTORY_ACTION_REGRESSION_OK carry=%d/%d action=%s" % [resources.carried_count(), resources.backpack_capacity, pebble.action_id])
	quit()
