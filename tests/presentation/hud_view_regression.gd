extends SceneTree

const HudView = preload("res://scripts/presentation/hud/hud_view.gd")

func _init() -> void:
	var host := Control.new()
	root.add_child(host)
	var view := HudView.new()
	view.setup(host, null)
	var objective_children := view.objective_panel.get_child_count()
	view.refresh({
		"day": 1, "clock": "清晨", "weather": "晴朗", "temperature": 16.0,
		"resources": {}, "survivor": {}, "objective": {}, "log": [], "interaction": {}
	})
	assert(view.objective_panel.get_node("ObjectiveLogButton").tooltip_text == "查看最近日志")
	assert(view.objective_panel.get_node("ObjectiveShortcutButton").tooltip_text == "查看快捷键")
	assert(view.objective_panel.get_child_count() == objective_children)
	view.refresh({
		"day": 1, "clock": "清晨", "weather": "晴朗", "temperature": 16.0,
		"resources": {}, "survivor": {}, "objective": {}, "log": [], "interaction": {}
	})
	assert(view.objective_panel.get_child_count() == objective_children)
	var temperature_chip := host.get_node("TemperatureChip") as Panel
	assert(temperature_chip != null)
	assert(temperature_chip.clip_contents)
	assert(view.required_snapshot_keys().size() == 9)
	print("HUD_VIEW_REGRESSION_OK")
	quit()
