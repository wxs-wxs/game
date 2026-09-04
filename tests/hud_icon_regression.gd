extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.hud != null)
	assert(ui._resource_icons.size() == 9)
	for icon in ui._resource_icons:
		assert(icon is TextureRect)
		assert(icon.texture != null)
		assert(icon.size == Vector2(16, 16))
		assert(icon.scale == Vector2.ONE)
	assert(ui.survivor_avatar_sprite != null)
	assert(ui.survivor_avatar_sprite.texture != null)
	assert(ui.survivor_avatar_sprite.size == Vector2(24, 36))
	assert(ui.survivor_avatar_sprite.scale == Vector2.ONE)
	assert(ui._rail_icons.size() == 6)
	for icon in ui._rail_icons:
		assert(icon is TextureRect)
		assert(icon.size == Vector2(16, 16))
		assert(icon.scale == Vector2.ONE)
	assert(ui.hud.get_node_or_null("ShortcutButton") != null)
	assert(ui.hud.get_node_or_null("ShortcutPanel") != null)
	assert(ui.backpack_button.focus_mode == Control.FOCUS_ALL)
	assert(ui.backpack_button.get_theme_stylebox("focus") is StyleBoxTexture)
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
