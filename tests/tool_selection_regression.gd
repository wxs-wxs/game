extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	var game: GameManager = main.game
	assert(ui.build_selection_panel != null)
	assert(not ui.build_selection_panel.visible)
	assert(not main.world.build_mode.active)

	var build_key := InputEventKey.new()
	build_key.keycode = KEY_B
	build_key.pressed = true
	main._input(build_key)
	assert(ui.build_selection_panel.visible)
	assert(ui.build_selection_dim.visible)
	assert(game.time.paused)
	assert(ui.build_tool_buttons["axe"].disabled)
	assert(ui.build_tool_status_labels["axe"].text == "需要简易工作台")
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	main._input(escape_key)
	assert(not ui.build_selection_panel.visible)
	main._input(build_key)
	assert(ui.build_selection_panel.visible)

	game.buildings.complete("workbench")
	game.apply_building_effect("workbench")
	ui.refresh()
	assert(not ui.build_tool_buttons["axe"].disabled)
	ui._select_tool_and_craft("axe")
	assert(game.resources.has_axe())
	assert(not ui.build_selection_panel.visible)
	assert(not game.time.paused)

	game.resources.add("stone", 1)
	ui.toggle_build_mode()
	assert(not ui.build_tool_buttons["pickaxe"].disabled)
	ui._select_tool_and_craft("pickaxe")
	assert(game.resources.has_pickaxe())

	ui.toggle_build_mode()
	var facility_button := ui.build_selection_panel.get_node("FacilityBuildButton") as Button
	facility_button.pressed.emit()
	assert(main.world.build_mode.active)
	ui.toggle_build_mode()
	assert(not main.world.build_mode.active)
	print("TOOL_SELECTION_REGRESSION_OK axe=%s pickaxe=%s" % [game.resources.has_axe(), game.resources.has_pickaxe()])
	quit()
