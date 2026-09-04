extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	assert(game.phase == GameManager.PHASE_MORNING)
	assert(game.day == 1)
	game.start_exploration()
	assert(game.phase == GameManager.PHASE_DAY)
	game.time.elapsed = TimeManager.DAY_SECONDS
	game.advance(0.1)
	assert(game.phase == GameManager.PHASE_DAY)
	assert(game.day_return_required)
	assert(not game.night_settlement_applied)
	assert(not game.time.paused)
	var saved: Dictionary = game.to_dict()
	var restored := GameManager.new()
	restored.from_dict(saved)
	assert(restored.day_return_required)
	assert(not restored.night_settlement_applied)
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var build = preload("res://scripts/build_mode_controller.gd").new()
	world.add_child(build)
	build.setup(world)
	build.selected_blueprint = "storage_shelf"
	world.player.position = Vector2(500, 500)
	build.ghost_position = world.player.position + Vector2(16, 0)
	assert(not build.confirm_build())
	var campfire = world.interactions.filter(func(point): return point is CampfirePoint)[0]
	world.player.position = campfire.position
	world._process(0.1)
	world.try_interact()
	assert(world.is_interacting())
	world.cancel_interaction()
	var forage = world.interactions.filter(func(point): return point is ForageSpot)[0]
	world.player.position = forage.position
	world._process(0.1)
	world.try_interact()
	assert(not world.is_interacting())
	var door = world.interactions.filter(func(point): return point is HouseDoor)[0]
	world.player.position = door.position
	world._process(0.1)
	world.try_interact()
	world._process(1.0)
	assert(world.is_inside)
	var bed = world.interior_manager.interior.sleep_bed
	world.player.global_position = bed.global_position
	world._process(0.1)
	world.try_interact()
	world._process(1.3)
	assert(game.night_settlement_applied)
	game.start_exploration()
	game.time.elapsed = TimeManager.DAY_SECONDS
	game.advance(0.1)
	var result: Dictionary = game.finish_exploration_day()
	assert(bool(result.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var day_after := game.day
	var repeated: Dictionary = game.finish_exploration_day()
	assert(not bool(repeated.get("ok", false)))
	assert(game.day == day_after)
	print("ENDLESS_DAY_FLOW_REGRESSION_OK day=%d phase=%s" % [game.day, game.phase])
	quit()
