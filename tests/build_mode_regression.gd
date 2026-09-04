extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var ui := UIController.new()
	root.add_child(ui)
	ui.setup(game, world)
	ui._open_build_selection()
	assert(ui.facility_buttons.size() >= 9)
	for button_variant in ui.facility_buttons.values():
		var card: Button = button_variant
		assert(Rect2(Vector2.ZERO, ui.build_selection_panel.size).has_point(card.position))
		assert(card.position.x + card.size.x <= ui.build_selection_panel.size.x)
		assert(card.position.y + card.size.y <= ui.build_selection_panel.size.y)
	assert(ui.facility_buttons.has("campfire"))
	ui.facility_buttons["campfire"].emit_signal("pressed")
	assert(world.build_mode.selected_blueprint == "campfire")
	assert(world.build_mode.active)
	world.build_mode.active = false
	ui._close_build_selection()

	var build = world.build_mode
	build.selected_blueprint = "storage_shelf"
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
