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
	var result: Dictionary = game.finish_exploration_day()
	assert(bool(result.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var day_after := game.day
	var repeated: Dictionary = game.finish_exploration_day()
	assert(not bool(repeated.get("ok", false)))
	assert(game.day == day_after)
	print("ENDLESS_DAY_FLOW_REGRESSION_OK day=%d phase=%s" % [game.day, game.phase])
	quit()
