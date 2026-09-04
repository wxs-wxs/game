extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var ui := UIController.new()
	root.add_child(ui)
	ui.setup(game, world)
	var bar := ui.interaction_progress_bar
	assert(bar != null)
	assert(bar.size.x <= 180.0)
	ui._on_interaction_progress("搜寻废墟", 0.45)
	assert(is_equal_approx(bar.value, 0.45))
	assert(bar.get_parent().visible)
	var before := game.time.paused
	ui._open_pause_overlay("backpack")
	assert(game.time.paused)
	ui._close_pause_overlay("backpack")
	assert(game.time.paused == before)
	print("HUD_INTERACTION_OVERLAY_REGRESSION_OK")
	quit()
