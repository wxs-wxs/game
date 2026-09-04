class_name SurvivalDirector
extends RefCounted

## Long-term campaign layer for the camp loop.
## It deliberately owns only strategy state; GameManager remains the source of truth
## for resources, survivors, buildings, weather, and phase transitions.

const DATA_PATH := "res://data/survival_director.json"
const STATE_VERSION := 1

var definitions: Dictionary = {}
var policies: Dictionary = {}
var goal_pool: Array = []
var milestone_defs: Array = []
var weather_defs: Dictionary = {}

var campaign_seed: int = 14072026
var rng := RandomNumberGenerator.new()
var threat: int = 30
var policy_id: String = "balanced"
var streak: int = 0
var best_streak: int = 0
var completed_days: int = 0
var goal_cursor: int = 0
var goal_day: int = 0
var last_started_day: int = 0
var last_settled_day: int = -1
var current_goal: Dictionary = {}
var goal_start_amounts: Dictionary = {}
var day_resource_gains: Dictionary = {}
var last_observed_amounts: Dictionary = {}
var goal_start_built_count: int = 0
var goal_start_survivor_count: int = 0
var goal_start_total_collected: int = 0
var unlocked_milestones: Array[String] = []
var action_counts: Dictionary = {}
var last_report: Array[String] = []

func _init() -> void:
	definitions = _load_json(DATA_PATH)
	_normalize_definitions()
	reset(campaign_seed)

func reset(seed_value: int = 14072026) -> void:
	campaign_seed = seed_value
	rng.seed = _positive_seed(campaign_seed + 104729)
	threat = 30
	policy_id = "balanced" if policies.has("balanced") else str(policies.keys()[0])
	streak = 0
	best_streak = 0
	completed_days = 0
	goal_cursor = 0
	goal_day = 0
	last_started_day = 0
	last_settled_day = -1
	current_goal = {}
	goal_start_amounts = {}
	day_resource_gains = {}
	last_observed_amounts = {}
	goal_start_built_count = 0
	goal_start_survivor_count = 0
	goal_start_total_collected = 0
	unlocked_milestones = []
	action_counts = {}
	last_report = []

## Called once when the player enters a new morning. It is idempotent so both
## the exploration and legacy work-roster loops can safely call it.
func begin_day(day_value: int, weather: String, game = null) -> Dictionary:
	var normalized_day := maxi(1, day_value)
	if last_started_day == normalized_day and goal_day == normalized_day and not current_goal.is_empty():
		return get_goal_summary(game)
	last_started_day = normalized_day
	goal_day = normalized_day
	_snapshot_day(game)
	_select_goal(normalized_day)
	var weather_info := weather_effect(weather)
	threat = clampi(threat + int(weather_info.get("threat_delta", 0)), 0, 100)
	_sync_safety(game)
	return get_goal_summary(game)

## Resolve the strategy layer after food/night effects have been applied.
## The returned lines are intended for GameManager.daily_log/report_lines.
func settle_day(game) -> Array[String]:
	var lines: Array[String] = []
	if game == null:
		return lines
	var current_day := int(game.day)
	if last_settled_day == current_day:
		return lines
	if goal_day != current_day or current_goal.is_empty():
		begin_day(current_day, str(game.weather), game)

	var progress := goal_progress(game)
	var target := maxi(1, int(current_goal.get("target", 1)))
	var goal_complete := progress >= target
	if str(current_goal.get("kind", "")) == "survive":
		goal_complete = _alive_count(game) > 0
	current_goal["progress"] = progress
	current_goal["completed"] = goal_complete

	if goal_complete:
		streak += 1
		best_streak = maxi(best_streak, streak)
		var reward: Dictionary = _scaled_reward(current_goal.get("reward", {}), game)
		_grant_reward(game, reward)
		lines.append("每日目标完成：%s。连胜 %d 天。" % [_goal_label(current_goal), streak])
		if not reward.is_empty():
			lines.append("目标奖励：%s。" % _reward_text(reward, game))
		if streak >= 2 and streak % 2 == 0:
			var streak_reward := {"wood": 1, "food": 1}
			_grant_reward(game, streak_reward)
			lines.append("连胜奖励：补给箱 +%s。" % _reward_text(streak_reward, game))
	else:
		streak = 0
		var miss_threat := int(current_goal.get("miss_threat", 3))
		threat = clampi(threat + miss_threat, 0, 100)
		lines.append("每日目标未完成：%s，营地威胁 +%d。" % [_goal_label(current_goal), miss_threat])

	var policy_delta := _apply_policy(game, lines)
	var pressure_delta := _ambient_pressure(game)
	threat = clampi(threat + policy_delta + pressure_delta, 0, 100)
	if pressure_delta != 0:
		lines.append("营地压力变化：%+d。" % pressure_delta)
	_sync_safety(game)

	if threat >= 80:
		_apply_high_threat_incident(game, lines)
	completed_days += 1 if _alive_count(game) > 0 else 0
	_evaluate_milestones(game, lines)
	last_settled_day = current_day
	last_report = lines.duplicate()
	return lines

func set_policy(next_policy_id: String, game = null) -> Dictionary:
	if not policies.has(next_policy_id):
		return {"ok":false, "reason":"未知营地政策：%s" % next_policy_id}
	if game != null and str(game.phase) != "morning":
		var exploration_day := bool(game.exploration_mode) and str(game.phase) == "day" and not bool(game.in_house)
		if not exploration_day:
			return {"ok":false, "reason":"营地政策只能在清晨或户外探索时调整。"}
	policy_id = next_policy_id
	var policy: Dictionary = policies.get(policy_id, {})
	return {"ok":true, "reason":"已采用政策：%s" % str(policy.get("label", policy_id)), "policy":policy_summary()}

func get_policy_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in policies.keys():
		var policy: Dictionary = policies[key].duplicate(true)
		policy["id"] = str(key)
		result.append(policy)
	return result

func policy_summary() -> Dictionary:
	var policy: Dictionary = policies.get(policy_id, {})
	return {"id":policy_id, "label":str(policy.get("label", policy_id)), "description":str(policy.get("description", ""))}

func goal_progress(game = null) -> int:
	if current_goal.is_empty():
		return 0
	var kind := str(current_goal.get("kind", ""))
	var progress := int(current_goal.get("progress", 0))
	if game != null:
		match kind:
			"resource_gain":
				var resource_id := str(current_goal.get("resource", "food"))
				observe_resources(game)
				progress = int(day_resource_gains.get(resource_id, 0))
			"resource_stock":
				progress = int(game.resources.get_amount(str(current_goal.get("resource", "food"))))
			"morale_min":
				progress = _average_morale(game)
			"build_count":
				progress = maxi(0, _built_count(game) - goal_start_built_count)
			"survivor_count":
				progress = maxi(0, _survivor_count(game) - goal_start_survivor_count)
			"action_count":
				progress = int(action_counts.get(str(current_goal.get("action", "")), 0))
			"survive":
				progress = 1 if last_settled_day == goal_day and _alive_count(game) > 0 else 0
	current_goal["progress"] = progress
	return progress

func is_goal_complete(game = null) -> bool:
	if current_goal.is_empty():
		return false
	if str(current_goal.get("kind", "")) == "survive":
		return last_settled_day == goal_day and _alive_count(game) > 0
	return goal_progress(game) >= int(current_goal.get("target", 1))

func get_goal_summary(game = null) -> Dictionary:
	if current_goal.is_empty():
		return {"id":"", "day":goal_day, "label":"今日目标尚未开始", "progress":0, "target":0, "completed":false, "reward":{}}
	var summary: Dictionary = current_goal.duplicate(true)
	var progress := goal_progress(game)
	summary["day"] = goal_day
	summary["label"] = _goal_label(current_goal)
	summary["progress"] = progress
	summary["target"] = int(current_goal.get("target", 1))
	summary["completed"] = is_goal_complete(game)
	return summary

func get_status(game = null) -> Dictionary:
	var weather_name := str(game.weather) if game != null else ""
	return {
		"threat":threat,
		"threat_label":threat_label(),
		"safety":100 - threat,
		"policy":policy_summary(),
		"streak":streak,
		"best_streak":best_streak,
		"completed_days":completed_days,
		"goal":get_goal_summary(game),
		"milestones":unlocked_milestones.duplicate(),
		"weather":weather_effect(weather_name),
		"last_report":last_report.duplicate()
	}

func event_context(game) -> Dictionary:
	var built_ids: Array[String] = []
	if game != null and game.buildings != null:
		for key in game.buildings.built:
			built_ids.append(str(key))
	return {"weather": str(game.weather) if game != null else "", "threat": threat, "built_facilities": built_ids, "recent_actions": action_counts.duplicate(true)}

func status(game = null) -> Dictionary:
	return get_status(game)

func threat_label() -> String:
	if threat >= 80: return "危急"
	if threat >= 60: return "紧张"
	if threat >= 35: return "警戒"
	return "平稳"

func weather_effect(weather_name: String) -> Dictionary:
	var info: Dictionary = weather_defs.get(weather_name, {})
	if info.is_empty():
		return {"id":weather_name, "label":weather_name, "threat_delta":0, "gather_multiplier":1.0, "fuel_extra":0}
	var result: Dictionary = info.duplicate(true)
	result["id"] = weather_name
	result["label"] = weather_name
	return result

func gather_multiplier(_weather: String) -> float:
	return 1.0

func record_action(action_id: String, amount: int = 1) -> void:
	if action_id.is_empty():
		return
	action_counts[action_id] = int(action_counts.get(action_id, 0)) + maxi(0, amount)

func record_event(event_id: String, choice_id: String = "") -> void:
	if event_id.is_empty():
		return
	record_action("event:" + event_id)
	var delta_by_event := {"beast":4, "rain":2, "cold":2, "wanderer":-1, "spoilage":1, "argument":1, "cache":2}
	var delta := int(delta_by_event.get(event_id, 0))
	if choice_id in ["reinforce", "burn", "alarm", "mediate", "mark", "turn_away"]:
		delta -= 2
	threat = clampi(threat + delta, 0, 100)

func record_building(building_id: String) -> void:
	record_action("building:" + building_id)

func record_recruitment() -> void:
	record_action("recruitment")

func to_dict() -> Dictionary:
	return {
		"version":STATE_VERSION,
		"campaign_seed":campaign_seed,
		"rng_state":rng.state,
		"threat":threat,
		"policy_id":policy_id,
		"streak":streak,
		"best_streak":best_streak,
		"completed_days":completed_days,
		"goal_cursor":goal_cursor,
		"goal_day":goal_day,
		"last_started_day":last_started_day,
		"last_settled_day":last_settled_day,
		"current_goal":current_goal,
		"goal_start_amounts":goal_start_amounts,
		"day_resource_gains":day_resource_gains,
		"last_observed_amounts":last_observed_amounts,
		"goal_start_built_count":goal_start_built_count,
		"goal_start_survivor_count":goal_start_survivor_count,
		"goal_start_total_collected":goal_start_total_collected,
		"unlocked_milestones":unlocked_milestones,
		"action_counts":action_counts,
		"last_report":last_report
	}

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		reset(campaign_seed)
		return
	campaign_seed = int(data.get("campaign_seed", campaign_seed))
	rng.seed = _positive_seed(campaign_seed + 104729)
	if data.has("rng_state"):
		rng.state = int(data.get("rng_state", rng.state))
	threat = clampi(int(data.get("threat", 30)), 0, 100)
	policy_id = str(data.get("policy_id", "balanced"))
	if not policies.has(policy_id): policy_id = "balanced" if policies.has("balanced") else str(policies.keys()[0])
	streak = maxi(0, int(data.get("streak", 0)))
	best_streak = maxi(streak, int(data.get("best_streak", streak)))
	completed_days = maxi(0, int(data.get("completed_days", 0)))
	goal_cursor = maxi(0, int(data.get("goal_cursor", 0)))
	goal_day = int(data.get("goal_day", 0))
	last_started_day = int(data.get("last_started_day", goal_day))
	last_settled_day = int(data.get("last_settled_day", -1))
	current_goal = data.get("current_goal", {})
	if not current_goal is Dictionary: current_goal = {}
	if str(current_goal.get("id", "")) == "week_survivor":
		current_goal = {}
	if not current_goal.is_empty():
		var goal_resource := str(current_goal.get("resource", ""))
		if not goal_resource.is_empty() and not ResourceManager.RESOURCE_KEYS.has(goal_resource): current_goal = {}
		elif current_goal.get("reward", {}) is Dictionary: current_goal["reward"] = _filter_resource_values(current_goal.get("reward", {}), true)
	goal_start_amounts = _filter_resource_values(data.get("goal_start_amounts", {}))
	if not goal_start_amounts is Dictionary: goal_start_amounts = {}
	day_resource_gains = _filter_resource_values(data.get("day_resource_gains", {}))
	if not day_resource_gains is Dictionary: day_resource_gains = {}
	last_observed_amounts = _filter_resource_values(data.get("last_observed_amounts", {}))
	if not last_observed_amounts is Dictionary: last_observed_amounts = {}
	goal_start_built_count = maxi(0, int(data.get("goal_start_built_count", 0)))
	goal_start_survivor_count = maxi(0, int(data.get("goal_start_survivor_count", 0)))
	goal_start_total_collected = maxi(0, int(data.get("goal_start_total_collected", 0)))
	unlocked_milestones = []
	for item in data.get("unlocked_milestones", []):
		if str(item) not in unlocked_milestones: unlocked_milestones.append(str(item))
	action_counts = data.get("action_counts", {})
	if not action_counts is Dictionary: action_counts = {}
	last_report = []
	for line in data.get("last_report", []): last_report.append(str(line))

func _filter_resource_values(value, allow_stats: bool = false) -> Dictionary:
	var filtered: Dictionary = {}
	if not value is Dictionary: return filtered
	for key in value:
		var id := str(key)
		if ResourceManager.RESOURCE_KEYS.has(id) or (allow_stats and id in ["morale", "health", "hunger", "energy"]): filtered[id] = value[key]
	return filtered

func _snapshot_day(game) -> void:
	goal_start_amounts = {}
	day_resource_gains = {}
	last_observed_amounts = {}
	goal_start_built_count = 0
	goal_start_survivor_count = 0
	goal_start_total_collected = 0
	if game == null:
		return
	for key in ResourceManager.RESOURCE_KEYS:
		var amount := int(game.resources.get_amount(key))
		goal_start_amounts[key] = amount
		day_resource_gains[key] = 0
		last_observed_amounts[key] = amount
	goal_start_built_count = _built_count(game)
	goal_start_survivor_count = _survivor_count(game)
	goal_start_total_collected = int(game.resources.total_collected)

## Record positive resource deltas during the current day. GameManager samples
## this around exploration/work ticks and immediately before night loss.
func observe_resources(game) -> void:
	if game == null or game.resources == null:
		return
	for key in ResourceManager.RESOURCE_KEYS:
		var id := str(key)
		var amount := int(game.resources.get_amount(id))
		var previous := int(last_observed_amounts.get(id, amount))
		if amount > previous:
			day_resource_gains[id] = int(day_resource_gains.get(id, 0)) + amount - previous
		last_observed_amounts[id] = amount

func _select_goal(day_value: int) -> void:
	if goal_pool.is_empty():
		current_goal = {"id":"survive", "kind":"survive", "target":1, "label":"让所有幸存者撑过今晚", "reward":{"food":1}, "miss_threat":5, "progress":0, "completed":false}
		return
	var index := posmod(_positive_seed(campaign_seed) + day_value * 17 + goal_cursor, goal_pool.size())
	goal_cursor += 1
	current_goal = goal_pool[index].duplicate(true)
	current_goal["progress"] = 0
	current_goal["completed"] = false

func _goal_label(goal: Dictionary) -> String:
	var template := str(goal.get("label", goal.get("id", "今日目标")))
	if template.contains("%"):
		return template % int(goal.get("target", 1))
	return template

func _scaled_reward(raw_reward, game) -> Dictionary:
	var result: Dictionary = {}
	if not raw_reward is Dictionary:
		return result
	var policy: Dictionary = policies.get(policy_id, {})
	var multiplier := float(policy.get("reward_multiplier", 1.0))
	multiplier *= 1.0 + 0.1 * float(mini(3, maxi(0, streak - 1)))
	for key in raw_reward:
		var amount := int(raw_reward[key])
		if amount == 0:
			continue
		if str(key) in ["morale", "health", "hunger", "energy"]:
			result[str(key)] = amount
		else:
			result[str(key)] = maxi(1, int(round(float(amount) * multiplier)))
	return result

func _grant_reward(game, reward: Dictionary) -> void:
	for key in reward:
		var id := str(key)
		var amount := int(reward[key])
		if id in ["morale", "health", "hunger", "energy"]:
			game.change_all(id, amount)
		elif game.resources.amounts.has(id):
			game.resources.add(id, amount)

func _apply_policy(game, lines: Array[String]) -> int:
	var policy: Dictionary = policies.get(policy_id, {})
	var delta := int(policy.get("threat_delta", 0))
	var morale_delta := int(policy.get("morale_delta", 0))
	if morale_delta != 0:
		game.change_all("morale", morale_delta)
		lines.append("政策「%s」：全员士气 %+d。" % [str(policy.get("label", policy_id)), morale_delta])
	var food_save := int(policy.get("food_save", 0))
	if food_save > 0:
		var before := int(game.resources.get_amount("food"))
		var capacity := int(game.resources.capacities.get("food", before))
		var restored := mini(food_save, maxi(0, capacity - before))
		if restored > 0:
			game.resources.amounts["food"] = before + restored
			lines.append("政策「%s」节约了 %d 食物。" % [str(policy.get("label", policy_id)), restored])
		else:
			lines.append("政策「%s」未能节约食物（储备已满）。" % str(policy.get("label", policy_id)))
	var wood_cost := int(policy.get("wood_cost", 0))
	if wood_cost > 0:
		var cost := {"wood":wood_cost}
		if game.resources.can_afford(cost):
			game.resources.spend(cost)
			lines.append("政策「%s」消耗木材加固了防线。" % str(policy.get("label", policy_id)))
		else:
			delta += 5
			lines.append("政策「%s」缺少木材，防线出现缺口。" % str(policy.get("label", policy_id)))
	return delta

func _ambient_pressure(game) -> int:
	var delta := 0
	var no_food := int(game.no_food_days)
	if no_food > 0: delta += mini(10, no_food * 2)
	var morale := _average_morale(game)
	if morale < 35: delta += 5
	elif morale >= 75: delta -= 2
	var guard := 0
	if game.buildings != null:
		guard = int(game.buildings.guard_power)
	if guard > 0: delta -= mini(6, guard)
	if int(game.house_level) >= 2: delta -= 2
	return delta

func _apply_high_threat_incident(game, lines: Array[String]) -> void:
	var chance := clampf(0.15 + float(threat - 80) * 0.015, 0.15, 0.5)
	if rng.randf() > chance:
		lines.append("威胁过高但夜哨及时发现了动静。")
		return
	var victim = game.random_alive()
	if victim != null:
		var damage := 5 + int((threat - 80) / 5)
		victim.apply_change("health", -damage)
		victim.injured = true
		lines.append("高威胁事件：%s 在夜袭中受伤（-%d 生命）。" % [victim.display_name, damage])
	var lost := mini(2, int(game.resources.get_amount("metal")))
	if lost > 0:
		game.resources.add("metal", -lost)
		lines.append("夜袭还带走了 %d 金属。" % lost)

func _evaluate_milestones(game, lines: Array[String]) -> void:
	for definition_variant in milestone_defs:
		if not definition_variant is Dictionary:
			continue
		var definition: Dictionary = definition_variant
		var milestone_id := str(definition.get("id", ""))
		if milestone_id.is_empty() or milestone_id in unlocked_milestones:
			continue
		if not _milestone_met(definition, game):
			continue
		unlocked_milestones.append(milestone_id)
		var reward: Dictionary = definition.get("reward", {})
		_grant_reward(game, reward)
		lines.append("里程碑达成：%s。" % str(definition.get("label", milestone_id)))
		if not reward.is_empty(): lines.append("里程碑奖励：%s。" % _reward_text(reward, game))

func _milestone_met(definition: Dictionary, game) -> bool:
	var target := int(definition.get("target", 1))
	match str(definition.get("condition", "")):
		"days_survived": return completed_days >= target
		"built_count": return _built_count(game) >= target
		"survivor_count": return _survivor_count(game) >= target
		"resource_stock": return int(game.resources.get_amount(str(definition.get("resource", "food")))) >= target
		"threat_at_most": return threat <= target
		"total_collected": return int(game.resources.total_collected) >= target
	return false

func _reward_text(reward: Dictionary, game) -> String:
	var parts: Array[String] = []
	for key in reward:
		var id := str(key)
		var label := id
		if game != null and game.resources != null and game.resources.amounts.has(id): label = game.resources.display_name(id)
		elif id == "morale": label = "士气"
		elif id == "health": label = "生命"
		parts.append("%s+%d" % [label, int(reward[key])])
	return "、".join(parts)

func _average_morale(game) -> int:
	if game == null:
		return 0
	var total := 0
	var count := 0
	for survivor in game.survivors:
		if survivor.alive:
			total += int(survivor.morale)
			count += 1
	return int(round(float(total) / float(count))) if count > 0 else 0

func _alive_count(game) -> int:
	if game == null: return 0
	if game.has_method("alive_count"): return int(game.alive_count())
	var count := 0
	for survivor in game.survivors:
		if survivor.alive: count += 1
	return count

func _survivor_count(game) -> int:
	return int(game.survivors.size()) if game != null else 0

func _built_count(game) -> int:
	return int(game.built_facilities.size()) if game != null else 0

func _sync_safety(game) -> void:
	if game != null:
		game.safety = clampi(100 - threat, 0, 100)

func _positive_seed(value: int) -> int:
	if value == -9223372036854775808:
		return 1
	return absi(value) + 1

func _normalize_definitions() -> void:
	policies = definitions.get("policies", {})
	if not policies is Dictionary: policies = {}
	if policies.is_empty():
		policies = {"balanced":{"label":"均衡", "description":"保持营地稳定。", "threat_delta":0, "morale_delta":0, "food_save":0, "wood_cost":0, "reward_multiplier":1.0}}
	goal_pool = definitions.get("goals", [])
	if not goal_pool is Array: goal_pool = []
	var filtered_goals: Array = []
	for goal in goal_pool:
		if goal is Dictionary and str(goal.get("id", "")) == "week_survivor":
			continue
		filtered_goals.append(goal)
	goal_pool = filtered_goals
	milestone_defs = definitions.get("milestones", [])
	if not milestone_defs is Array: milestone_defs = []
	weather_defs = definitions.get("weather", {})
	if not weather_defs is Dictionary: weather_defs = {}
	if weather_defs.is_empty():
		weather_defs = {"晴朗":{"threat_delta":-1, "gather_multiplier":1.05, "fuel_extra":0}, "暴雨":{"threat_delta":5, "gather_multiplier":0.8, "fuel_extra":1}, "寒冷":{"threat_delta":4, "gather_multiplier":1.0, "fuel_extra":2}}

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
