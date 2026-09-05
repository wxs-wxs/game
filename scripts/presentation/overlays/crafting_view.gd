class_name CraftingView
extends OverlayViewBase

var hint_label: Label
var recipe_buttons: Dictionary = {}

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var close := callbacks.get("close_button") as Button
	if close != null and not close.pressed.is_connected(_emit_close):
		close.pressed.connect(_emit_close)
	var refs: Dictionary = callbacks.get("recipe_buttons", {}) if callbacks.get("recipe_buttons", {}) is Dictionary else {}
	for recipe_id in refs:
		var button := refs[recipe_id] as Button
		if button != null and not button.pressed.is_connected(_craft.bind(str(recipe_id))):
			button.pressed.connect(_craft.bind(str(recipe_id)))

func _craft(recipe_id: String) -> void:
	_emit_intent({"kind":"craft_recipe", "recipe":recipe_id})

func _build() -> void:
	panel = factory.panel(root, Vector2(237, 72), Vector2(486, 396), PixelTheme.PANEL_MID)
	panel.name = "CraftingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 42
	factory.label(panel, Vector2(24, 18), Vector2(300, 27), "用品制作", 9, PixelTheme.TEXT_ACCENT)
	hint_label = factory.label(panel, Vector2(24, 48), Vector2(438, 21), "需要简易工作台", 5, PixelTheme.TEXT_MUTED)
	var close := factory.button(panel, Vector2(372, 16), Vector2(90, 30), "关闭")
	close.pressed.connect(_emit_close)
	for index in range(3):
		var recipe_id: String = ["bandage", "torch", "trap"][index]
		var row := factory.panel(panel, Vector2(24, 81 + index * 78), Vector2(438, 63), PixelTheme.PANEL_LIGHT)
		factory.label(row, Vector2(58, 9), Vector2(220, 21), recipe_id, 6, PixelTheme.TEXT_ACCENT)
		var craft := factory.button(row, Vector2(316, 15), Vector2(108, 33), "制作")
		craft.name = "CraftButton"
		craft.pressed.connect(func(): _emit_intent({"kind":"craft_recipe", "recipe":recipe_id}))
		recipe_buttons[recipe_id] = craft
	panel.visible = false

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if hint_label == null:
		return
	var ready := bool(snapshot.get("workbench_ready", false))
	hint_label.text = str(snapshot.get("hint", "选择用品并制作" if ready else "需要简易工作台"))
	for recipe_id in recipe_buttons:
		var button: Button = recipe_buttons[recipe_id]
		var data: Dictionary = snapshot.get("recipes", {}).get(recipe_id, {}) if snapshot.get("recipes", {}) is Dictionary else {}
		button.disabled = not ready or not bool(data.get("can_craft", false))
		button.tooltip_text = str(data.get("reason", "无法制作"))
