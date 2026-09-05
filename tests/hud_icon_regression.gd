extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.hud != null)
	assert(ui._resource_icons.size() == 7)
	for icon in ui._resource_icons:
		assert(icon is TextureRect)
		assert(icon.texture != null)
		assert(icon.size == Vector2(16, 16))
		assert(icon.scale == Vector2.ONE)
	assert(ui.survivor_avatar_sprite != null)
	assert(ui.survivor_avatar_sprite.texture != null)
	assert(ui.survivor_avatar_sprite.size == Vector2(24, 36))
	assert(ui.survivor_avatar_sprite.scale == Vector2.ONE)
	assert(ui._rail_icons.is_empty())
	for index in range(7):
		assert(ui.hud.get_node_or_null("ActionRailButton%d" % index) == null)
	assert(ui.hud.get_node_or_null("ShortcutButton") != null)
	assert(ui.hud.get_node_or_null("ShortcutPanel") != null)
	assert(ui.temperature_label != null)
	assert(ui.backpack_button == null)
	assert(ui.build_tool_buttons["axe"].get_node_or_null("Icon") != null)
	assert(ui.build_tool_buttons["pickaxe"].get_node_or_null("Icon") != null)
	ui._open_build_selection()
	assert(ui.facility_buttons.size() == 9)
	for facility_id in ui.facility_buttons:
		var facility_card: Button = ui.facility_buttons[facility_id]
		var facility_icon := facility_card.get_node_or_null("Icon") as TextureRect
		assert(facility_icon != null, facility_id)
		assert(facility_icon.texture != null, facility_id)
		assert(facility_icon.size == Vector2(16, 16), facility_id)
		assert(facility_icon.scale == Vector2.ONE, facility_id)
		assert(facility_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, facility_id)
	ui._close_build_selection()
	assert(ui.hud.get_node_or_null("HelpButton") == null)
	var help_key := InputEventKey.new()
	help_key.keycode = KEY_H
	help_key.pressed = true
	main._input(help_key)
	assert(ui.shortcut_panel.visible)
	main._input(help_key)
	assert(not ui.shortcut_panel.visible)
	ui.toggle_log_panel()
	assert(ui.log_panel.visible)
	assert(ui.log_content_label.text != "")
	assert(ui.close_overlay())
	assert(not ui.log_panel.visible)
	print("HUD_ICONS_OK resources=%d rail=%d" % [ui._resource_icons.size(), ui._rail_icons.size()])
	quit()
