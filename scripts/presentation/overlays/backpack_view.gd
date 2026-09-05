class_name BackpackView
extends OverlayViewBase

var content_label: Label
var item_buttons: Array[Button] = []

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var close := callbacks.get("close_button") as Button
	if close != null and not close.pressed.is_connected(_emit_close):
		close.pressed.connect(_emit_close)

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
