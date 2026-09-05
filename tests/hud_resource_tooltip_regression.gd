extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.hud != null)
	assert(ui._resource_icons.size() == 7)
	assert(ui._resource_badges.size() == 7)
	var keys := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal"]
	for index in range(keys.size()):
		var key := str(keys[index])
		var expected := "%s：%d / %d" % [main.game.resources.display_name(key), main.game.resources.get_amount(key), main.game.resources.capacities[key]]
		var icon: TextureRect = ui._resource_icons[index]
		var badge: Label = ui._resource_badges[index]
		assert(icon.tooltip_text == expected)
		assert(badge.tooltip_text == expected)
		assert(icon.mouse_filter != Control.MOUSE_FILTER_IGNORE)
		assert(badge.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	print("HUD_RESOURCE_TOOLTIPS_OK resources=%d" % keys.size())
	quit()
