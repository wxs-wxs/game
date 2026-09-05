extends SceneTree

func _init() -> void:
	var resources := ResourceManager.new()
	assert(resources.backpack_capacity == 12)
	assert(resources.has_method("discard_from_backpack"))
	resources.backpack["food"] = 5
	resources.amounts["food"] = 5
	var discarded: Dictionary = resources.discard_from_backpack("food", 3)
	assert(discarded.get("ok", false))
	assert(discarded.get("amount", 0) == 3)
	assert(resources.backpack["food"] == 2)
	assert(resources.amounts["food"] == 2)

	var legacy := ResourceManager.new()
	legacy.from_dict({"backpack_capacity": 4, "backpack_owned": false, "backpack":{"food":2}, "amounts":{"food":2}})
	assert(legacy.backpack_capacity == 12)

	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.backpack_panel != null)
	assert(ui.backpack_slots.size() == 12)
	assert(ui.backpack_panel.get_node_or_null("CraftBackpackButton") == null)
	assert(ui.backpack_panel.get_node_or_null("ProcessFishButton") == null)
	assert(ui.backpack_panel.get_node_or_null("CookBerriesButton") == null)
	assert(ui.hud.get_node_or_null("FishProcessPanel") == null)
	assert(ui.recipe_buttons.size() == 3)
	for recipe_id in ui.recipe_buttons:
		assert(ui.recipe_buttons[recipe_id].get_parent().get_parent() == ui.crafting_panel)

	var game: GameManager = main.game
	game.resources.backpack["food"] = 4
	game.resources.amounts["food"] = 4
	ui.refresh()
	var first_cell: Panel = ui.backpack_slots[0].get("cell")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	first_cell.gui_input.emit(right_click)
	assert(ui.item_action_menu.visible)
	assert(ui.item_action_menu.get_node_or_null("DiscardButton") != null)
	assert(ui.item_action_menu.get_node_or_null("UseButton") != null)
	assert(not (ui.item_action_menu.get_node_or_null("CookButton") as Button).visible)

	ui._open_backpack_discard_dialog("food")
	assert(ui.discard_dialog.visible)
	ui.close_backpack()
	assert(not ui.discard_dialog.visible)
	assert(not ui.item_action_menu.visible)
	ui.toggle_backpack()
	assert(ui._backpack_open)
	ui._open_backpack_discard_dialog("food")
	assert(ui.discard_dialog.visible)
	ui.discard_quantity_spinbox.value = 3
	ui._confirm_discard_quantity()
	assert(game.resources.backpack["food"] == 1)

	game.resources.backpack["food"] = 1
	game.resources.amounts["food"] = 1
	game.fire_states["campfire"]["lit"] = true
	game.fire_states["campfire"]["fuel_remaining"] = 60.0
	main.world.player.global_position = Vector2(210, 153)
	ui.refresh()
	ui._open_backpack_item_menu(0)
	assert(ui.item_action_menu.get_node_or_null("CookButton") != null)

	main.world.player.global_position = Vector2(500, 500)
	ui.refresh()
	ui._open_backpack_item_menu(0)
	assert(not (ui.item_action_menu.get_node_or_null("CookButton") as Button).visible)
	ui._cook_backpack_action()
	assert(game.resources.backpack["food"] == 1)
	assert(game.resources.backpack["cooked_food"] == 0)

	print("BACKPACK_REDESIGN_REGRESSION_OK slots=%d discarded=%d" % [ui.backpack_slots.size(), 3])
	quit()
