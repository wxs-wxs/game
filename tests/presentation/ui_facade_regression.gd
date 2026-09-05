extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ui: UIController = main.ui
	assert(ui != null)
	assert(ui.hud != null)
	assert(ui.hud.scale == Vector2.ONE)
	assert(ui.VIEW_SIZE == Vector2(960, 540))

	# Preserve the authored 960x540 rectangles while presentation views are
	# extracted from this compatibility facade.
	_assert_rect(ui.hud.get_node("StatusRail"), Vector2(12, 12), Vector2(210, 30))
	_assert_rect(ui.hud.get_node("ResourceChip"), Vector2(702, 12), Vector2(246, 42))
	_assert_rect(ui.survivor_panel, Vector2(12, 468), Vector2(246, 60))
	_assert_rect(ui.objective_panel, Vector2(702, 468), Vector2(246, 60))
	_assert_rect(ui.backpack_panel, Vector2(171, 42), Vector2(618, 462))
	_assert_rect(ui.storage_panel, Vector2(24, 24), Vector2(912, 492))
	_assert_rect(ui.shortcut_panel, Vector2(237, 75), Vector2(486, 390))

	assert(ui._resource_icons.size() == 7)
	for icon in ui._resource_icons:
		assert(icon is TextureRect)
		assert(icon.texture != null)
		assert(icon.size == Vector2(16, 16))
		assert(icon.scale == Vector2.ONE)
		assert(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(ui.survivor_avatar_sprite != null)
	assert(ui.survivor_avatar_sprite.texture != null)
	assert(ui.survivor_avatar_sprite.size == Vector2(24, 36))

	for method in ["toggle_backpack", "close_overlay", "show_event", "show_report"]:
		assert(ui.has_method(method), method)

	# The facade keeps the existing nested overlay pause contract: opening one
	# standard overlay adds exactly one pause layer and close_overlay removes it.
	assert(not ui.has_pause_overlay())
	assert(not main.game.time.paused)
	ui.toggle_backpack()
	assert(ui.backpack_panel.visible)
	assert(ui._overlay_pause_depth == 1)
	assert(ui.has_pause_overlay())
	assert(main.game.time.paused)
	assert(ui.close_overlay())
	assert(not ui.backpack_panel.visible)
	assert(ui._overlay_pause_depth == 0)
	assert(not ui.has_pause_overlay())
	assert(not main.game.time.paused)

	# Event/report methods remain callable and own one modal pause layer each.
	ui.show_event({
		"id": "facade_test",
		"data": {"title": "事件", "text": "测试", "choices": [{"label": "等待", "cost": {}}]},
	})
	assert(ui.event_panel.visible)
	assert(ui._overlay_pause_depth == 1)
	assert(main.game.time.paused)
	ui.show_report(["夜间报告"])
	assert(not ui.event_panel.visible)
	assert(ui.report_panel.visible)
	assert(ui._overlay_pause_depth == 1)
	assert(main.game.time.paused)
	ui._report_open = false
	ui._close_pause_overlay("report")
	ui.report_panel.visible = false
	assert(ui._overlay_pause_depth == 0)
	assert(not main.game.time.paused)

	print("UI_FACADE_REGRESSION_OK")
	quit()

func _assert_rect(control: Control, expected_position: Vector2, expected_size: Vector2) -> void:
	assert(control != null)
	assert(control.position == expected_position)
	assert(control.size == expected_size)
	assert(control.scale == Vector2.ONE)
