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
	game._finish_exploration_day()
	assert(game.survival.last_settled_day == 1)
	assert(game.day == 2 and game.phase == GameManager.PHASE_DAY)
	print("STRATEGY_SMOKE_OK policy=%s settled_day=%d" % [game.survival.policy_id, game.survival.last_settled_day])
	quit()
