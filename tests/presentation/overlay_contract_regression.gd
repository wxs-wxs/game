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
		view.setup(host, null, {})
		view.open({"items": [], "capacity": 12, "storage": [], "backpack": [], "recipes": {}, "tools": {}, "choices": []})
		assert(view.is_open())
		view.refresh({"items": [], "capacity": 12, "storage": [], "backpack": [], "recipes": {}, "tools": {}, "choices": []})
		var button := _first_button(view.panel)
		if button != null:
			button.emit_signal("pressed")
			assert(intents.size() <= 1)
		view.close()
		assert(not view.is_open())
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

