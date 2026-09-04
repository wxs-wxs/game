extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var goal := game.get_daily_goal()
	assert(not goal.is_empty())
	assert(str(goal.get("label", "")) != "")
	var policy_result := game.set_camp_policy("fortify")
	assert(bool(policy_result.get("ok", false)))
	assert(game.get_survival_status().get("policy", {}).get("id", "") == "fortify")
	var saved := game.to_dict()
	var restored := GameManager.new()
	restored.from_dict(saved)
	assert(restored.get_survival_status().get("policy", {}).get("id", "") == "fortify")
	game.time.elapsed = TimeManager.DAY_SECONDS
	game.advance(0.1)
	assert(game.day_return_required)
	var finish_result: Dictionary = game.finish_exploration_day()
	assert(bool(finish_result.get("ok", false)))
	if game.phase == GameManager.PHASE_EVENT:
		assert(bool(game.choose_event(0).get("ok", false)))
	assert(game.phase == GameManager.PHASE_REPORT)
	game.continue_from_report()
	assert(game.day == 2 and game.phase == GameManager.PHASE_MORNING)
	print("STRATEGY_SMOKE_OK policy=%s settled_day=%d" % [game.survival.policy_id, game.survival.last_settled_day])
	quit()
