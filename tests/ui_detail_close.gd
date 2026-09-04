extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ui: UIController = main.ui
	assert(ui != null)
	assert(ui.hud.get_node_or_null("DetailsDrawer") == null)
	assert(ui.hud.get_node_or_null("CloseDetailsButton") == null)
	assert(ui.hud.get_node_or_null("HelpButton") == null)
	assert(ui.exit_button != null)
	assert(ui.exit_button.get_parent() == ui.pause_panel)
	assert(ui.exit_button.text == "退出游戏")

	print("UI_DETAIL_REMOVED_OK")
	quit()
