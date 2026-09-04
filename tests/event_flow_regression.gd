extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.day_return_required = true
	var result := game.finish_exploration_day()
	assert(bool(result.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var phase_after_first := game.phase
	var second := game.finish_exploration_day()
	assert(not bool(second.get("ok", false)))
	assert(game.phase == phase_after_first)
	if game.phase == GameManager.PHASE_EVENT:
		var event_before := game.events.current_event.duplicate(true)
		var invalid := game.choose_event(99)
		assert(not bool(invalid.get("ok", false)))
		assert(game.phase == GameManager.PHASE_EVENT)
		assert(game.events.current_event == event_before)
		var unaffordable_index := -1
		for index in range(2):
			if not game.resources.can_afford(game.events.choice_cost(index)):
				unaffordable_index = index
				break
		if unaffordable_index >= 0:
			var before_food := game.resources.get_amount("food")
			var bad := game.choose_event(unaffordable_index)
			assert(not bool(bad.get("ok", false)))
			assert(game.resources.get_amount("food") == before_food)
		var good_index := _first_affordable_choice(game)
		if good_index >= 0:
			var chosen := game.choose_event(good_index)
			assert(bool(chosen.get("ok", false)))
			assert(game.phase == GameManager.PHASE_REPORT or game.phase == GameManager.PHASE_ENDED)
	var legacy := GameManager.new()
	legacy.survival.from_dict({"current_goal":{"id":"week_survivor","kind":"survive","target":7,"label":"完成七天生存挑战","reward":{"food":1}}})
	assert(str(legacy.survival.current_goal.get("id", "")) != "week_survivor")
	print("EVENT_FLOW_REGRESSION_OK phase=%s day=%d" % [game.phase, game.day])
	quit()

func _first_affordable_choice(game) -> int:
	for index in range(2):
		if game.resources.can_afford(game.events.choice_cost(index)):
			return index
	return -1
