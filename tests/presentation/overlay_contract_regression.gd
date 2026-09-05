extends SceneTree

const Views := [
	preload("res://scripts/presentation/overlays/backpack_view.gd"),
	preload("res://scripts/presentation/overlays/storage_view.gd"),
	preload("res://scripts/presentation/overlays/crafting_view.gd"),
	preload("res://scripts/presentation/overlays/build_view.gd"),
	preload("res://scripts/presentation/overlays/event_report_view.gd"),
	preload("res://scripts/presentation/overlays/pause_overlay.gd")
]

func _init() -> void:
	for script in Views:
		var host := Control.new()
		root.add_child(host)
		var view = script.new()
		var intents: Array[Dictionary] = []
		view.intent_requested.connect(func(value: Dictionary): intents.append(value))
		var callback_map: Dictionary = {"facility_ids":["campfire"]} if Views.find(script) == 3 else {}
		view.setup(host, null, callback_map)
		view.open({"items": [], "capacity": 12, "storage": [], "backpack": [], "recipes": {}, "tools": {}, "choices": []})
		assert(view.is_open())
		if Views.find(script) == 3 or Views.find(script) == 5:
			assert(view.dim != null and view.dim.visible)
		var snapshot := {"items": [{"key":"food", "label":"食物"}], "capacity": 12, "storage": [{"key":"wood", "label":"木材"}], "backpack": [{"key":"wood", "label":"木材"}], "workbench_ready": true, "recipes": {"bandage":{"can_craft":true}}, "tools": {"axe":{"can_craft":true}}, "facilities": {"campfire":{"label":"篝火", "can_build":true}}, "choices": ["选择"], "choice_enabled":[true]}
		view.refresh(snapshot)
		var button: Button
		var expected_kind := ""
		match Views.find(script):
			0:
				button = _button_named(view.panel, "BackpackSlot0")
				expected_kind = "use_item"
			1:
				button = _button_named(view.panel, "StorageSlot0")
				expected_kind = "storage_move"
			2:
				button = _button_named(view.panel, "CraftButton")
				expected_kind = "craft_recipe"
			3:
				button = _button_named(view.panel, "FacilityBuildCard_campfire")
				expected_kind = "select_facility"
			4:
				button = _first_button(view.panel)
				expected_kind = "choose_event"
			5:
				button = _button_with_text(view.panel, "继续游戏")
				expected_kind = "resume"
		assert(button != null, "view control missing for %s" % script.resource_path)
		if expected_kind == "select_facility":
			view.refresh({"facilities":{"campfire":{"label":"篝火", "can_build":false}}})
			assert(button.disabled)
			view.refresh(snapshot)
		button.emit_signal("pressed")
		assert(intents.size() == 1, "expected one intent for %s" % script.resource_path)
		assert(str(intents[0].get("kind", "")) == expected_kind)
		match expected_kind:
			"use_item": assert(str(intents[0].get("key", "")) == "food")
			"storage_move": assert(str(intents[0].get("source", "")) == "storage" and str(intents[0].get("key", "")) == "wood")
			"craft_recipe": assert(str(intents[0].get("recipe", "")) == "bandage")
			"select_facility": assert(str(intents[0].get("building_id", "")) == "campfire")
			"choose_event": assert(int(intents[0].get("index", -1)) == 0)
		if expected_kind == "choose_event":
			intents.clear()
			view.open({"mode":"report", "content":"隔离报告", "continue_text":"进入清晨", "terminal":false})
			assert(view.is_open() and view.report_panel.visible)
			view.report_continue_button.emit_signal("pressed")
			assert(intents.size() == 1 and intents[0].get("kind", "") == "report_continue")
		view.close()
		assert(not view.is_open())
		if Views.find(script) == 3 or Views.find(script) == 5:
			assert(not view.dim.visible)
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui.backpack_view.panel == ui.backpack_panel)
	assert(ui.storage_view.panel == ui.storage_panel)
	assert(ui.crafting_view.panel == ui.crafting_panel)
	assert(ui.build_view.panel == ui.build_selection_panel)
	assert(ui.event_report_view.panel == ui.event_panel)
	assert(ui.build_view.dim == ui.build_selection_dim)
	assert(ui.backpack_view.slot_controls.size() == 12)
	for slot in ui.storage_slots + ui.storage_backpack_slots:
		assert(slot.transfer_owner == ui.storage_view)
	assert(ui.pause_overlay.panel == ui.pause_panel)
	for node_name in ["BackpackPanel", "StoragePanel", "CraftingPanel", "BuildSelectionPanel", "PausePanel"]:
		assert(_count_named_nodes(ui.hud, node_name) == 1, node_name + " duplicated")
	var runtime_intents: Array[Dictionary] = []
	ui.backpack_view.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	ui.storage_view.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	ui.crafting_view.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	ui.build_view.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	ui.event_report_view.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	ui.pause_overlay.intent_requested.connect(func(value: Dictionary): runtime_intents.append(value))
	main.game.resources.backpack["food"] = 1
	main.game.resources.amounts["food"] = 1
	ui.toggle_backpack()
	var backpack_cell: Control = ui.backpack_slots[0].get("cell")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	backpack_cell.gui_input.emit(right_click)
	assert(runtime_intents.back().get("kind", "") == "backpack_context")
	(ui.item_action_menu.get_node_or_null("UseButton") as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "backpack_use_action")
	(ui.item_action_menu.get_node_or_null("DiscardButton") as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "backpack_discard_action")
	(ui.discard_dialog.get_node_or_null("CancelDiscardButton") as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "backpack_cancel_discard")
	ui.close_backpack()
	main.game.resources.backpack["wood"] = 1
	main.game.resources.storage["wood"] = 0
	main.game.resources.amounts["wood"] = 1
	ui._on_storage_open_requested()
	ui._refresh_storage_panel()
	var storage_source = null
	var storage_target = null
	for slot in ui.storage_backpack_slots:
		if slot.item_key == "wood": storage_source = slot
	for slot in ui.storage_slots:
		if slot.item_key.is_empty(): storage_target = slot; break
	assert(storage_source != null and storage_target != null)
	var drag_payload: Variant = storage_source._get_drag_data(Vector2.ZERO)
	storage_target._drop_data(Vector2.ZERO, drag_payload)
	assert(runtime_intents.back().get("kind", "") == "storage_drop")
	ui.close_storage()
	main.game.resources.workbench_available = true
	ui._open_crafting_panel()
	(ui.recipe_buttons["bandage"] as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "craft_recipe")
	ui.close_crafting_panel()
	ui._open_build_selection()
	(ui.build_tool_buttons["axe"] as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "craft_tool")
	ui._close_build_selection()
	ui.show_event({"id":"contract", "data":{"title":"事件", "text":"测试", "choices":[{"label":"等待", "cost":{}}]}})
	(ui.event_choice_buttons[0] as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "choose_event")
	ui.show_report(["报告"])
	assert(ui.event_report_view.is_open())
	assert(ui._overlay_pause_depth == 1 and main.game.time.paused)
	(ui.report_continue_button as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "report_continue")
	assert(not ui._report_open and ui._overlay_pause_depth == 0 and not main.game.time.paused)
	ui.toggle_pause_menu()
	assert(ui.paused_by_menu and ui.pause_overlay.is_open())
	(ui.pause_panel.get_node_or_null("PauseResumeButton") as Button).emit_signal("pressed")
	assert(runtime_intents.back().get("kind", "") == "resume")
	assert(not ui.paused_by_menu and not main.game.time.paused and not ui.pause_overlay.is_open())
	print("OVERLAY_CONTRACT_REGRESSION_OK")
	quit()

func _first_button(node: Node) -> Button:
	if node == null:
		return null
	for child in node.get_children():
		if child is Button and (child as Button).visible and not (child as Button).disabled:
			return child
		var nested := _first_button(child)
		if nested != null:
			return nested
	return null

func _count_named_nodes(node: Node, target_name: String) -> int:
	if node == null:
		return 0
	var count := 1 if node.name == target_name else 0
	for child in node.get_children():
		count += _count_named_nodes(child, target_name)
	return count

func _button_named(node: Node, target_name: String) -> Button:
	if node == null: return null
	if node.name == target_name and node is Button: return node as Button
	for child in node.get_children():
		var found := _button_named(child, target_name)
		if found != null: return found
	return null

func _button_with_text(node: Node, value: String) -> Button:
	if node == null: return null
	if node is Button and (node as Button).text == value: return node as Button
	for child in node.get_children():
		var found := _button_with_text(child, value)
		if found != null: return found
	return null
