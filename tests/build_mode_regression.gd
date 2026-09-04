extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	var build = world.build_mode
	build.toggle()
	assert(build.active)
	assert(build.can_place(), "build mode should find a valid tile at the default camp spawn")
	var expected_wood := game.resources.get_amount("wood") - 4
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	build._unhandled_input(event)
	assert(not build.active, "E should leave build mode after confirming")
	assert(build.site != null, "E should create a construction site")
	assert(game.resources.get_amount("wood") == expected_wood)
	print("BUILD_MODE_REGRESSION_OK ghost=%s wood=%d" % [build.site.position, game.resources.get_amount("wood")])
	quit()
