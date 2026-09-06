class_name BackpackView
extends OverlayViewBase

var content_label: Label
var item_buttons: Array[Button] = []
var slot_controls: Array = []
var _wired := false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var close := callbacks.get("close_button") as Button
	slot_controls = callbacks.get("slots", []) if callbacks.get("slots", []) is Array else []
	if _wired:
		return
	if close != null:
		close.pressed.connect(_emit_close)
	var action_buttons: Dictionary = callbacks.get("action_buttons", {}) if callbacks.get("action_buttons", {}) is Dictionary else {}
	var use_button := action_buttons.get("use") as Button
	if use_button != null: use_button.pressed.connect(func(): _emit_intent({"kind":"backpack_use_action"}))
	var cook_button := action_buttons.get("cook") as Button
	if cook_button != null: cook_button.pressed.connect(func(): _emit_intent({"kind":"backpack_cook_action"}))
	var discard_button := action_buttons.get("discard") as Button
	if discard_button != null: discard_button.pressed.connect(func(): _emit_intent({"kind":"backpack_discard_action"}))
	var confirm_button := action_buttons.get("confirm_discard") as Button
	if confirm_button != null: confirm_button.pressed.connect(func(): _emit_intent({"kind":"backpack_confirm_discard"}))
	var cancel_button := action_buttons.get("cancel_discard") as Button
	if cancel_button != null: cancel_button.pressed.connect(func(): _emit_intent({"kind":"backpack_cancel_discard"}))
	for index in range(slot_controls.size()):
		var slot_variant: Variant = slot_controls[index]
		var slot: Dictionary = slot_variant if slot_variant is Dictionary else {}
		var cell := slot.get("cell") as Control
		if cell != null:
			cell.gui_input.connect(_on_slot_gui_input.bind(index))
	_wired = true

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_emit_intent({"kind":"backpack_context", "index":index})
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_emit_intent({"kind":"backpack_dismiss_context"})
	if root != null and root.get_viewport() != null:
		root.get_viewport().set_input_as_handled()

func _build() -> void:
	panel = factory.panel(root, Vector2(171, 42), Vector2(618, 462), PixelTheme.PANEL_MID)
	panel.name = "BackpackPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 20
	factory.label(panel, Vector2(30, 21), Vector2(390, 33), "背包", 10, PixelTheme.TEXT_ACCENT)
	var close := factory.button(panel, Vector2(489, 18), Vector2(102, 36), "关闭")
	close.name = "BackpackCloseButton"
	close.tooltip_text = "关闭背包"
	close.pressed.connect(_emit_close)
	content_label = factory.label(panel, Vector2(30, 57), Vector2(552, 24), "", 6, PixelTheme.TEXT_MUTED)
	content_label.clip_text = true
	for index in range(12):
		var button := factory.button(panel, Vector2(30 + (index % 4) * 144, 90 + (index / 4) * 78), Vector2(132, 66), "空")
		button.name = "BackpackSlot%d" % index
		button.tooltip_text = "选择物品"
		button.pressed.connect(func(): _emit_intent({"kind":"use_item", "key":str(button.get_meta("item_key", ""))}))
		item_buttons.append(button)
	panel.visible = false

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if content_label == null:
		return
	var items: Array = snapshot.get("items", [])
	var capacity := int(snapshot.get("capacity", 12))
	content_label.text = "格子 %d/%d" % [items.size(), capacity]
	for index in range(item_buttons.size()):
		var button := item_buttons[index]
		var item: Dictionary = items[index] if index < items.size() and items[index] is Dictionary else {}
		var key := str(item.get("key", ""))
		button.set_meta("item_key", key)
		button.text = str(item.get("label", key if not key.is_empty() else "空"))
		button.disabled = key.is_empty()
