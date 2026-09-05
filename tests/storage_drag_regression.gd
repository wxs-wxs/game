extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.storage_panel != null)
	assert(ui.storage_slots.size() == 12, "储物架应为 4x3 格子")
	assert(ui.storage_backpack_slots.size() == 12, "储物界面中的背包应为 4x3 格子")
	assert(ui.storage_panel.position.x < ui.storage_panel.position.x + ui.storage_panel.size.x)
	assert(ui.storage_panel.position.x + ui.storage_panel.size.x <= ui.VIEW_SIZE.x)
	assert(ui.storage_panel.position.y + ui.storage_panel.size.y <= ui.VIEW_SIZE.y)
	assert(ui.storage_grid_panel.position.x < ui.storage_backpack_grid_panel.position.x, "储物架应在左侧，背包应在右侧")
	assert(ui.storage_grid_panel.position.x + ui.storage_grid_panel.size.x <= ui.storage_backpack_grid_panel.position.x)
	for slot in ui.storage_slots:
		assert(slot.source_kind == "storage")
	for slot in ui.storage_backpack_slots:
		assert(slot.source_kind == "backpack")
		assert(slot.position.x == round(slot.position.x) and slot.position.y == round(slot.position.y))
		assert(slot.size.x == round(slot.size.x) and slot.size.y == round(slot.size.y))
		assert(slot.item_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)

	var resources = main.game.resources
	resources.backpack["wood"] = 2
	resources.storage["wood"] = 0
	resources.amounts["wood"] = 2
	ui._storage_open = true
	ui._refresh_storage_panel()
	var backpack_slot = null
	var storage_slot = null
	for slot in ui.storage_backpack_slots:
		if slot.item_key == "wood":
			backpack_slot = slot
			break
	for slot in ui.storage_slots:
		if slot.item_key.is_empty():
			storage_slot = slot
			break
	assert(backpack_slot != null and storage_slot != null)
	var payload: Variant = backpack_slot._get_drag_data(Vector2.ZERO)
	assert(payload is Dictionary and payload.get("source_kind") == "backpack")
	assert(storage_slot._can_drop_data(Vector2.ZERO, payload))
	storage_slot._drop_data(Vector2.ZERO, payload)
	assert(resources.backpack["wood"] == 1)
	assert(resources.storage["wood"] == 1)
	var storage_wood_slot = null
	var empty_backpack_slot = null
	for slot in ui.storage_slots:
		if slot.item_key == "wood":
			storage_wood_slot = slot
			break
	for slot in ui.storage_backpack_slots:
		if slot.item_key.is_empty() and slot.unlocked:
			empty_backpack_slot = slot
			break
	assert(storage_wood_slot != null and empty_backpack_slot != null)
	var reverse_payload: Variant = storage_wood_slot._get_drag_data(Vector2.ZERO)
	assert(empty_backpack_slot._can_drop_data(Vector2.ZERO, reverse_payload))
	empty_backpack_slot._drop_data(Vector2.ZERO, reverse_payload)
	assert(resources.backpack["wood"] == 2)
	assert(resources.storage["wood"] == 0)

	print("STORAGE_DRAG_REGRESSION_OK slots=%d/%d transfer=wood" % [ui.storage_slots.size(), ui.storage_backpack_slots.size()])
	quit()
