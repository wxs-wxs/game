extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	# Complete a shelf, then verify its indoor interaction point is registered
	# and usable after the room is created.
	var build = world.build_mode
	build.toggle()
	var requested_position: Vector2 = build.ghost_position
	assert(build.confirm_build())
	for _step in range(6):
		build.site._process(1.0)
	assert("storage_shelf" in game.built_facilities)
	assert(game.resources.capacities["food"] == 35)
	var outdoor_shelf = null
	for point in world.interactions:
		if point.unique_id == "storage_shelf_outdoor":
			outdoor_shelf = point
	assert(outdoor_shelf != null)
	assert(outdoor_shelf.global_position == requested_position, "completed shelf must stay at the requested build position")
	world.player.global_position = outdoor_shelf.global_position
	world._process(0.1)
	assert(world.nearest == outdoor_shelf)
	world.enter_house()
	var shelf = world.interior_manager.interior.storage_shelf
	assert(shelf != null)
	world.player.global_position = shelf.global_position
	world._process(0.1)
	assert(world.nearest == shelf)
	world.try_interact()
	assert(world.is_interacting())
	world._process(0.7)
	assert(not world.is_interacting())
	print("FACILITY_REGRESSION_OK shelf=%s" % shelf.global_position)
	quit()
