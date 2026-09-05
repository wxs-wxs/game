class_name BuildView
extends OverlayViewBase

var hint_label: Label
var dim: Control
var tool_buttons: Dictionary = {}
var facility_buttons: Dictionary = {}
var _wired := false

func open(snapshot: Dictionary) -> void:
	super.open(snapshot)
	if dim != null: dim.visible = true

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if dim != null: dim.visible = _open
	if panel == null or hint_label == null:
		return
	var ready := bool(snapshot.get("workbench_ready", true))
	hint_label.text = str(snapshot.get("hint", "先建造简易工作台" if not ready else "选择工具后即可制作，或进入设施建造"))
	var tools: Dictionary = snapshot.get("tools", {}) if snapshot.get("tools", {}) is Dictionary else {}
	for id in tool_buttons:
		var data: Dictionary = tools.get(id, {})
		var button: Button = tool_buttons[id]
		button.disabled = bool(data.get("owned", false)) or not bool(data.get("can_craft", false))
		button.tooltip_text = str(data.get("reason", "制作" + id))
	var facilities: Dictionary = snapshot.get("facilities", {}) if snapshot.get("facilities", {}) is Dictionary else {}
	for id in facility_buttons:
		var button: Button = facility_buttons[id]
		var data: Dictionary = facilities.get(id, {})
		if data.has("label"): button.text = str(data.get("label", id))
		button.disabled = not bool(data.get("can_build", true))
		button.tooltip_text = str(data.get("reason", "选择" + id))

func close() -> void:
	super.close()
	if dim != null: dim.visible = false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var callback_dim := callbacks.get("dim") as Control
	if callback_dim != null: dim = callback_dim
	if _wired:
		return
	var close := callbacks.get("close_button") as Button
	if close != null: close.pressed.connect(_emit_close)
	var tools: Dictionary = callbacks.get("tool_buttons", {}) if callbacks.get("tool_buttons", {}) is Dictionary else {}
	for id in tools:
		var button := tools[id] as Button
		if button != null:
			button.pressed.connect(_tool.bind(str(id)))
	var facilities: Dictionary = callbacks.get("facility_buttons", {}) if callbacks.get("facility_buttons", {}) is Dictionary else {}
	for id in facilities:
		var facility := facilities[id] as Button
		if facility != null:
			facility.pressed.connect(_facility.bind(str(id)))
	var enter := callbacks.get("facility_button") as Button
	if enter != null:
		enter.pressed.connect(func(): _emit_intent({"kind":"enter_facility_build"}))
	var crafting := callbacks.get("crafting_button") as Button
	if crafting != null:
		crafting.pressed.connect(func(): _emit_intent({"kind":"open_crafting"}))
	_wired = true

func _tool(id: String) -> void:
	_emit_intent({"kind":"craft_tool", "tool":id})

func _facility(id: String) -> void:
	_emit_intent({"kind":"select_facility", "building_id":id})

func _build() -> void:
	dim = ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(960, 540)
	dim.color = Color("081013", 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "BuildSelectionDim"
	root.add_child(dim)
	panel = factory.panel(root, Vector2(168, 30), Vector2(624, 480), PixelTheme.PANEL_MID)
	panel.name = "BuildSelectionPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 41
	factory.label(panel, Vector2(30, 20), Vector2(300, 24), "选择建造内容", 9, PixelTheme.TEXT_ACCENT)
	hint_label = factory.label(panel, Vector2(30, 50), Vector2(444, 18), "选择工具后即可制作", 4, PixelTheme.TEXT_MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(2):
		var id: String = ["axe", "pickaxe"][index]
		var button := factory.button(panel, Vector2(30 + index * 234, 80), Vector2(210, 138), id)
		button.name = "BuildToolButton_%s" % id
		button.pressed.connect(func(): _emit_intent({"kind":"craft_tool", "tool":id}))
		tool_buttons[id] = button
	var facility_ids_variant: Variant = callbacks.get("facility_ids", [])
	var facility_ids: Array = facility_ids_variant if facility_ids_variant is Array else []
	for index in range(facility_ids.size()):
		var id := str(facility_ids[index])
		var card := factory.button(panel, Vector2(30 + (index % 3) * 174, 226 + (index / 3) * 54), Vector2(164, 48), id)
		card.name = "FacilityBuildCard_%s" % id
		card.pressed.connect(_facility.bind(id))
		facility_buttons[id] = card
	var close := factory.button(panel, Vector2(414, 400), Vector2(150, 32), "关闭")
	close.pressed.connect(_emit_close)
	dim.visible = false
	panel.visible = false
