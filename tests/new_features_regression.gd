extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	if world.fish_school.fish.is_empty(): world.fish_school._ready()

	var camera: Camera2D = null
	for child in world.player.get_children():
		if child is Camera2D: camera = child
	assert(camera != null)
	assert(is_equal_approx(camera.zoom.x, 1.35) and is_equal_approx(camera.zoom.y, 1.35))
	assert(world.fish_school != null)
	assert(world.fish_school.fish.size() >= 4)

	var pebble: PebbleSpot = null
	for point in world.interactions:
		if point is PebbleSpot:
			pebble = point
			break
	assert(pebble != null)
	world.player.global_position = pebble.global_position
	world._process(0.1)
	assert(world.nearest == pebble)
	assert(pebble.interact().get("started", false))
	pebble.tick_interaction(pebble.interaction_time + 0.1)
	assert(not pebble.visible)
	assert(pebble.respawn_remaining > 0.0)
	var before := pebble.position
	pebble._process(pebble.respawn_remaining + 0.1)
	assert(pebble.visible)
	assert(pebble.position != before)

	var fishing := FishingSpot.new()
	fishing.failure_chance = 0.0
	fishing.setup(game)
	assert(fishing.interact().get("started", false))
	var result := fishing.tick_interaction(fishing.interaction_time + 0.1)
	assert(result.has("fish_key"))
	var fish_key := str(result.get("fish_key"))
	assert(game.resources.backpack.get(fish_key, 0) == 1)
	var processed := game.resources.convert_fish_to_food(fish_key)
	assert(processed.get("ok", false))
	assert(game.resources.backpack.get(fish_key, 0) == 0)
	# Converting the only fish in a full starter inventory reuses its slot.
	for key in ResourceManager.ITEM_KEYS: game.resources.backpack[key] = 0
	game.resources.backpack["fish_carp"] = 1
	game.resources.backpack["wood"] = 1
	game.resources.backpack["stone"] = 1
	game.resources.backpack["fiber"] = 1
	var full_convert := game.resources.convert_fish_to_food("fish_carp")
	assert(full_convert.get("ok", false))

	# Storage transfer accepts a new item type while an existing stack occupies
	# another slot, which is the case shown by the storage-shelf UI.
	game.resources.storage["food"] = 3
	game.resources.backpack["wood"] = 2
	var food_before := int(game.resources.backpack.get("food", 0))
	var moved := game.resources.move_to_backpack("food", 1)
	assert(moved.get("ok", false))
	assert(game.resources.backpack["food"] == food_before + 1)

	var tree := TreeSpot.new()
	tree.failure_chance = 0.0
	tree.setup(game)
	game.resources.axe = true
	assert(tree.interact().get("started", false))
	tree.tick_interaction(tree.interaction_time + 0.1)
	assert(tree.is_stump)
	assert(tree.regrow_remaining > 0.0)
	tree._process(tree.regrow_remaining + 0.1)
	assert(not tree.is_stump)

	# A multi-type ruin reward requires enough free slots; otherwise the action
	# stays unclaimed and asks the player to整理 the backpack.
	var ruin := RuinSpot.new()
	ruin.failure_chance = 0.0
	ruin.setup(game)
	for key in ResourceManager.ITEM_KEYS: game.resources.backpack[key] = 0
	game.resources.backpack["food"] = 1
	game.resources.backpack["wood"] = 1
	game.resources.backpack["stone"] = 1
	var scrap_before := game.resources.get_amount("scrap")
	assert(ruin.interact().get("started", false))
	var blocked_result := ruin.tick_interaction(ruin.interaction_time + 0.1)
	assert(blocked_result.get("failed", false))
	assert(game.resources.get_amount("scrap") == scrap_before)
	game.resources.backpack_owned = true
	game.resources.backpack_capacity = ResourceManager.BACKPACK_UPGRADED_CAPACITY
	assert(ruin.interact().get("started", false))
	ruin.tick_interaction(ruin.interaction_time + 0.1)
	assert(game.resources.get_amount("scrap") > scrap_before)
	print("NEW_FEATURES_REGRESSION_OK zoom=%.2f fish=%s respawn=%s" % [camera.zoom.x, fish_key, pebble.position])
	ruin.free()
	tree.free()
	fishing.free()
	world.free()
	quit()
