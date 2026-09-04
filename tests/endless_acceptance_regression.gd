extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.new_game(20260905)
	var saved_report_phase := false
	game.add_fire_fuel("campfire", 1)
	assert(game.is_fire_active("campfire"))
	game.tick_fire(60.0)
	assert(game.is_fire_active("campfire"))
	var fire_save := game.to_dict()
	var fire_restored := GameManager.new()
	fire_restored.from_dict(fire_save)
	assert(is_equal_approx(float(fire_restored.fire_state("campfire").get("fuel_remaining", 0.0)), float(game.fire_state("campfire").get("fuel_remaining", 0.0))))

	for expected_day in range(1, 6):
		if game.phase == GameManager.PHASE_MORNING:
			game.start_exploration()
		game.day_return_required = true
		var night := game.finish_exploration_day()
		assert(bool(night.get("ok", false)) or game.phase == GameManager.PHASE_ENDED)
		if game.phase == GameManager.PHASE_EVENT:
			var choice := -1
			for index in range(2):
				if game.resources.can_afford(game.events.choice_cost(index)):
					choice = index
					break
			assert(choice >= 0)
			var chosen := game.choose_event(choice)
			assert(bool(chosen.get("ok", false)))
		if game.phase == GameManager.PHASE_REPORT:
			var report_save := game.to_dict()
			var report_restored := GameManager.new()
			report_restored.from_dict(report_save)
			assert(report_restored.phase == GameManager.PHASE_REPORT)
			saved_report_phase = true
			game.continue_from_report()
		assert(game.day >= expected_day + 1)
		assert(game.day < 100000)
	assert(saved_report_phase)
	assert(not game.won)
	assert(game.phase != GameManager.PHASE_ENDED)

	var death_game := GameManager.new()
	var hero := death_game.get_protagonist()
	hero.health = 0
	assert(death_game.check_protagonist_health())
	assert(death_game.phase == GameManager.PHASE_ENDED)
	assert(not death_game.won)
	print("ENDLESS_ACCEPTANCE_REGRESSION_OK day=%d" % game.day)
	quit()
