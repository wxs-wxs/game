class_name StorageView
extends OverlayViewBase

var capacity_label: Label
var storage_buttons: Array[Button] = []
var backpack_buttons: Array[Button] = []
var storage_slot_refs: Array = []
var backpack_slot_refs: Array = []
var _wired := false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var close := callbacks.get("close_button") as Button
	storage_slot_refs = callbacks.get("storage_slots", []) if callbacks.get("storage_slots", []) is Array else []
	backpack_slot_refs = callbacks.get("backpack_slots", []) if callbacks.get("backpack_slots", []) is Array else []
	if _wired:
		return
	if close != null: close.pressed.connect(_emit_close)
	for slot in storage_slot_refs + backpack_slot_refs:
		if slot != null and slot is Object and slot.has_method("configure"):
			slot.transfer_owner = self
	_wired = true

func _can_storage_drop(payload: Dictionary, target_kind: String, target_key: String) -> bool:
	var validator: Variant = callbacks.get("drop_validator")
	if validator is Callable and (validator as Callable).is_valid():
		return bool((validator as Callable).call(payload, target_kind, target_key))
	return false

func _handle_storage_drop(payload: Dictionary, target_kind: String, target_key: String) -> void:
	_emit_intent({"kind":"storage_drop", "payload":payload, "target_kind":target_kind, "target_key":target_key})

func _build() -> void:
	panel = factory.panel(root, Vector2(24, 24), Vector2(912, 492), PixelTheme.PANEL_MID)
	panel.name = "StoragePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 21
	factory.label(panel, Vector2(24, 18), Vector2(520, 33), "储物架", 10, PixelTheme.TEXT_ACCENT)
	capacity_label = factory.label(panel, Vector2(24, 48), Vector2(720, 24), "", 6, PixelTheme.TEXT_MUTED)
	var close := factory.button(panel, Vector2(792, 18), Vector2(96, 33), "关闭")
	close.pressed.connect(_emit_close)
	var left := factory.panel(panel, Vector2(18, 84), Vector2(414, 372), PixelTheme.PANEL_LIGHT)
	var right := factory.panel(panel, Vector2(480, 84), Vector2(414, 372), PixelTheme.PANEL_LIGHT)
	factory.label(left, Vector2(15, 12), Vector2(384, 24), "储物架", 6, PixelTheme.TEXT_ACCENT)
	factory.label(right, Vector2(15, 12), Vector2(384, 24), "背包", 6, PixelTheme.TEXT_ACCENT)
	for index in range(12):
		var row := index / 4
		var col := index % 4
		var storage_button := factory.button(left, Vector2(15 + col * 96, 48 + row * 72), Vector2(84, 57), "空")
		storage_button.name = "StorageSlot%d" % index
		storage_button.pressed.connect(func(): _emit_intent({"kind":"storage_move", "source":"storage", "key":str(storage_button.get_meta("item_key", ""))}))
		storage_buttons.append(storage_button)
		var backpack_button := factory.button(right, Vector2(15 + col * 96, 48 + row * 72), Vector2(84, 57), "空")
		backpack_button.name = "StorageBackpackSlot%d" % index
		backpack_button.pressed.connect(func(): _emit_intent({"kind":"storage_move", "source":"backpack", "key":str(backpack_button.get_meta("item_key", ""))}))
		backpack_buttons.append(backpack_button)
	panel.visible = false

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if capacity_label == null:
		return
	capacity_label.text = str(snapshot.get("capacity_text", ""))
	_update_slots(storage_buttons, snapshot.get("storage", []))
	_update_slots(backpack_buttons, snapshot.get("backpack", []))

func _update_slots(buttons: Array[Button], values: Variant) -> void:
	var items: Array = values if values is Array else []
	for index in range(buttons.size()):
		var button := buttons[index]
		var item: Dictionary = items[index] if index < items.size() and items[index] is Dictionary else {}
		var key := str(item.get("key", ""))
		button.set_meta("item_key", key)
		button.text = str(item.get("label", key if not key.is_empty() else "空"))
		button.disabled = key.is_empty()
