class_name BuildView
extends OverlayViewBase

var hint_label: Label
var tool_buttons: Dictionary = {}
var facility_buttons: Dictionary = {}

func _build() -> void:
	var dim := ColorRect.new()
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
	var close := factory.button(panel, Vector2(414, 400), Vector2(150, 32), "关闭")
	close.pressed.connect(_emit_close)
	dim.visible = false
	panel.visible = false

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if panel == null:
		return
	var ready := bool(snapshot.get("workbench_ready", true))
	hint_label.text = str(snapshot.get("hint", "先建造简易工作台" if not ready else "选择工具后即可制作，或进入设施建造"))
	var tools: Dictionary = snapshot.get("tools", {}) if snapshot.get("tools", {}) is Dictionary else {}
	for id in tool_buttons:
		var data: Dictionary = tools.get(id, {})
		var button: Button = tool_buttons[id]
		button.disabled = bool(data.get("owned", false)) or not bool(data.get("can_craft", false))
		button.tooltip_text = str(data.get("reason", "制作" + id))
