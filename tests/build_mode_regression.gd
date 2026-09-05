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

	# A second facility must not consume materials or silently fail while another
	# project is still active; the E path should preserve build mode and expose
	# the same busy reason as the selection panel.
	var busy_game := GameManager.new()
	assert(busy_game.begin_construction("campfire").get("ok", false))
	var busy_world := ExplorationWorld.new()
	root.add_child(busy_world)
	busy_world.setup(busy_game)
	var busy_build = busy_world.build_mode
	var busy_ui := UIController.new()
	root.add_child(busy_ui)
	busy_ui.setup(busy_game, busy_world)
	busy_ui._open_build_selection()
	var busy_card: Button = busy_ui.facility_buttons["bed"]
	var busy_labels: Dictionary = busy_ui.facility_card_labels["bed"]
	assert(busy_card.disabled)
	assert((busy_labels["status"] as Label).text.contains("篝火"))
	busy_ui._close_build_selection()
	busy_build.selected_blueprint = "bed"
	busy_build.toggle()
	var busy_wood := busy_game.resources.get_amount("wood")
	var busy_event := InputEventKey.new()
	busy_event.keycode = KEY_E
	busy_event.physical_keycode = KEY_E
	busy_event.pressed = true
	busy_build._unhandled_input(busy_event)
	assert(busy_build.active, "E must not leave build mode when another project is active")
	assert(busy_game.resources.get_amount("wood") == busy_wood)
	assert(str(busy_build.placement_preflight().get("reason", "")).contains("篝火"))
	print("BUILD_MODE_REGRESSION_OK ghost=%s wood=%d" % [build.site.position, game.resources.get_amount("wood")])
	quit()
