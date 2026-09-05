extends SceneTree

const HudView = preload("res://scripts/presentation/hud/hud_view.gd")

func _init() -> void:
	var host := Control.new()
	root.add_child(host)
	var view := HudView.new()
	view.setup(host, null)
	view.refresh({
		"day": 1, "clock": "清晨", "weather": "晴朗", "temperature": 16.0,
		"resources": {}, "survivor": {}, "objective": {}, "log": [], "interaction": {}
	})
	assert(view.required_snapshot_keys().size() == 9)
	print("HUD_VIEW_REGRESSION_OK")
	quit()
