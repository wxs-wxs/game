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
		assert(slot.item_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "储物架物品名称不能拦截拖拽")
		assert(slot.count_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "储物架数量不能拦截拖拽")
	for slot in ui.storage_backpack_slots:
		assert(slot.source_kind == "backpack")
		assert(slot.item_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "背包物品名称不能拦截拖拽")
		assert(slot.count_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "背包数量不能拦截拖拽")
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

	# Exercise the actual viewport drag path, not only the virtual callbacks.
	resources.backpack["wood"] = 1
	resources.storage["wood"] = 0
	resources.amounts["wood"] = 1
	ui._refresh_storage_panel()
	backpack_slot = null
	storage_slot = null
	for slot in ui.storage_backpack_slots:
		if slot.item_key == "wood":
			backpack_slot = slot
			break
	for slot in ui.storage_slots:
		if slot.item_key.is_empty():
			storage_slot = slot
			break
	assert(backpack_slot != null and storage_slot != null)
	var source_position: Vector2 = backpack_slot.get_global_rect().get_center()
	var target_position: Vector2 = storage_slot.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source_position
	press.global_position = source_position
	root.get_viewport().push_input(press)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = target_position
	motion.global_position = target_position
	motion.relative = target_position - source_position
	root.get_viewport().push_input(motion)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target_position
	release.global_position = target_position
	root.get_viewport().push_input(release)
	await process_frame
	assert(resources.backpack["wood"] == 0, "真实鼠标拖拽应从背包扣除 1 个木材")
	assert(resources.storage["wood"] == 1, "真实鼠标拖拽应向储物架增加 1 个木材")

	# A populated slot with another item is still a valid destination: the
	# transfer is by item type and the UI reorders occupied slots after refresh.
	resources.backpack["wood"] = 1
	resources.storage["wood"] = 0
	resources.storage["stone"] = 1
	resources.amounts["wood"] = 1
	resources.amounts["stone"] = 1
	ui._refresh_storage_panel()
	var stone_storage_slot = null
	var wood_backpack_slot = null
	for slot in ui.storage_slots:
		if slot.item_key == "stone":
			stone_storage_slot = slot
			break
	for slot in ui.storage_backpack_slots:
		if slot.item_key == "wood":
			wood_backpack_slot = slot
			break
	assert(stone_storage_slot != null and wood_backpack_slot != null)
	var occupied_target_payload: Variant = stone_storage_slot._get_drag_data(Vector2.ZERO)
	assert(wood_backpack_slot._can_drop_data(Vector2.ZERO, occupied_target_payload), "不同物品的已占用槽也应接受跨栏拖拽")
	wood_backpack_slot._drop_data(Vector2.ZERO, occupied_target_payload)
	assert(resources.backpack["wood"] == 1)
	assert(resources.backpack["stone"] == 1)
	assert(resources.storage["stone"] == 0)

	print("STORAGE_DRAG_REGRESSION_OK slots=%d/%d transfer=wood" % [ui.storage_slots.size(), ui.storage_backpack_slots.size()])
	quit()
