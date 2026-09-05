class_name NightSettlementService
extends RefCounted

## Resolves the shared, domain-only portion of a night.  The caller owns phase
## flags and audio playback; this service returns those decisions as data.
const REQUIRED_CONTEXT_KEYS := [
	"day", "weather", "resources", "survivors", "buildings", "survival",
	"events", "rng", "fire_states", "house_level", "in_house", "report_lines"
]

class SettlementContext extends RefCounted:
	var day: int
	var weather: String
	var resources
	var survivors: Array
	var buildings
	var phase := "day"
	var exploration_mode := true
	var in_house := false
	var built_facilities: Array[String] = []
	var deployed_traps := 0
	var audio = null

	func change_all(stat: String, amount: int) -> void:
		for survivor in survivors:
			if survivor.alive:
				survivor.apply_change(stat, amount)

	func adjust_relation(key: String, amount: int) -> void:
		for survivor in survivors:
			survivor.relations[key] = int(survivor.relations.get(key, 0)) + amount

	func alive_count() -> int:
		var count := 0
		for survivor in survivors:
			if survivor.alive:
				count += 1
		return count

class AudioCollector extends RefCounted:
	var events: Array[Dictionary] = []

	func emit_event(event_id: String, params: Dictionary = {}) -> String:
		events.append({"id": event_id, "params": params.duplicate(true)})
		return "collected"

func resolve(context: Dictionary) -> Dictionary:
	var result: Dictionary = settle(context)
	if str(result.get("phase", "")) == "error":
		return result
	if bool(result.get("health_depleted", false)):
		result["phase"] = "ended"
		result["audio_events"].append({"id": "player.death", "params": {}})
		result["audio_events"].append({"id": "game.over", "params": {}})
		return result
	var events = context.get("events")
	var rng = context.get("rng")
	var event: Dictionary = {}
	if events != null and rng != null and events.has_method("create_weighted_event"):
		var event_context := _event_context(str(context.get("weather", "晴朗")), context.get("buildings"), context.get("survival"))
		event = events.create_weighted_event(rng, event_context)
		if not event.is_empty():
			result["phase"] = "event"
			result["event"] = event
			result["audio_events"].append({"id": "event.reveal", "params": {"event_id": str(event.get("id", ""))}})
	result["audio_events"].append({"id": "night.report", "params": {}})
	return result

func settle(context: Dictionary) -> Dictionary:
	var contract_error := _validate_context(context)
	if not contract_error.is_empty():
		return _failure_result(context, contract_error)
	var resources = context.get("resources")
	var survivors: Array = context.get("survivors", [])
	var weather := str(context.get("weather", "晴朗"))
	var rng = context.get("rng")
	var buildings = context.get("buildings")
	var survival = context.get("survival")
	var lines: Array[String] = []
	for line in context.get("report_lines", []):
		lines.append(str(line))
	var audio_events: Array[Dictionary] = []
	var temperature_before := float(context.get("temperature_before", context.get("environment_temperature", 0.0)))
	var night_context := {
		"day": int(context.get("day", 1)),
		"weather": weather,
		"resource_before": resources.to_dict() if resources != null and resources.has_method("to_dict") else {},
		"temperature_before": temperature_before,
		"completed_buildings": _built_ids(buildings)
	}

	lines.append("夜间结算")
	if survival != null and survival.has_method("observe_resources"):
		var observation_context = _make_settlement_context(context, resources, survivors, buildings, weather)
		survival.observe_resources(observation_context)

	var alive: Array = []
	for survivor in survivors:
		if survivor.alive:
			alive.append(survivor)
	var meals := mini(resources.get_amount("food") if resources != null else 0, alive.size())
	if resources != null:
		resources.add("food", -meals)
	for index in alive.size():
		var survivor = alive[index]
		if index < meals:
			survivor.apply_change("hunger", 18)
		else:
			survivor.apply_change("hunger", -22)
			survivor.apply_change("health", -7)
			survivor.apply_change("morale", -8)
			if not survivors.is_empty() and survivor == survivors[0]:
				audio_events.append({"id": "player.hurt", "params": {"source": "night_food", "amount": 7}})
	if meals < alive.size():
		lines.append("食物不足：%d 人空腹，生命与士气下降。" % [alive.size() - meals])
		audio_events.append({"id": "survival.food_warning", "params": {"missing_meals": alive.size() - meals}})
	else:
		lines.append("配给完成：消耗 %d 食物。" % meals)

	# Temperature damage is applied continuously during exploration. Keep the
	# report marker here so settlement retains the legacy report ordering.
	lines.append("夜间温度结算：低温伤害已在探索过程中实时计算。")
	if weather == "暴雨":
		var collected_water: int = int(buildings.rain_water_yield()) if buildings != null and buildings.has_method("rain_water_yield") else 0
		if collected_water > 0 and resources != null:
			var actual_water: int = int(resources.add("water", collected_water))
			lines.append("暴雨收集：获得 %d 水。" % actual_water)
	if weather == "暴雨" and rng != null and rng.randf() < (0.35 if not bool(context.get("in_house", false)) or int(context.get("house_level", 0)) == 0 else 0.12):
		var patient = _random_alive(survivors, rng)
		if patient != null:
			patient.sick = true
			patient.apply_change("health", -4)
			lines.append("暴雨让 %s 着凉生病。" % patient.display_name)

	var no_food_days := int(context.get("no_food_days", 0))
	no_food_days = no_food_days + 1 if resources == null or resources.get_amount("food") == 0 else 0
	context["no_food_days"] = no_food_days
	for survivor in survivors:
		if survivor.alive and (survivor.health <= 0 or survivor.hunger <= 0):
			survivor.apply_change("health", -12)
			if survivor == (survivors[0] if not survivors.is_empty() else null):
				audio_events.append({"id": "player.hurt", "params": {"source": "night_starvation", "amount": 12}})
			if not survivor.alive:
				lines.append("%s 没能撑过这一夜。" % survivor.display_name)

	# Strategy settlement is intentionally last among report-producing systems,
	# matching GameManager._resolve_night() while remaining node-independent.
	if survival != null and survival.has_method("settle_day"):
		var strategy_game = _make_settlement_context(context, resources, survivors, buildings, weather)
		for line in survival.settle_day(strategy_game):
			lines.append(str(line))
	var collector = context.get("_audio_collector")
	if collector is AudioCollector:
		audio_events.append_array(collector.events)

	var health_depleted := _protagonist_depleted(survivors)
	return {
		"report_lines": lines,
		"phase": "ended" if health_depleted else "report",
		"event": {},
		"health_depleted": health_depleted,
		"night_context": night_context,
		"audio_events": audio_events,
		"no_food_days": no_food_days
	}

func _validate_context(context: Dictionary) -> String:
	for key in REQUIRED_CONTEXT_KEYS:
		if not context.has(key):
			return "缺少夜间结算上下文：%s。" % key
	for key in ["resources", "buildings", "survival", "events", "rng"]:
		if context.get(key) == null:
			return "夜间结算上下文无效：%s。" % key
	var survivors = context.get("survivors")
	if not survivors is Array:
		return "夜间结算上下文无效：survivors。"
	var report_lines = context.get("report_lines")
	if not report_lines is Array:
		return "夜间结算上下文无效：report_lines。"
	for survivor in survivors:
		if not survivor is Object or not survivor.has_method("apply_change") or not survivor.has_method("get"):
			return "夜间结算上下文无效：survivors 元素。"
		if not survivor.get("alive") is bool or not survivor.get("sick") is bool:
			return "夜间结算上下文无效：survivors.alive/sick。"
		if not survivor.get("health") is int or not survivor.get("hunger") is int or not survivor.get("morale") is int:
			return "夜间结算上下文无效：survivors 状态。"
		if not survivor.get("relations") is Dictionary or not survivor.get("display_name") is String:
			return "夜间结算上下文无效：survivors 资料。"
	if not context.get("fire_states") is Dictionary:
		return "夜间结算上下文无效：fire_states。"
	if not context.get("resources").has_method("get_amount") or not context.get("resources").has_method("add"):
		return "夜间结算上下文无效：resources。"
	if not context.get("buildings").has_method("rain_water_yield"):
		return "夜间结算上下文无效：buildings。"
	if not context.get("survival").has_method("settle_day"):
		return "夜间结算上下文无效：survival。"
	if not context.get("events").has_method("create_weighted_event"):
		return "夜间结算上下文无效：events。"
	if not context.get("rng").has_method("randf") or not context.get("rng").has_method("randi_range"):
		return "夜间结算上下文无效：rng。"
	if not context.has("temperature_before") and not context.has("environment_temperature"):
		return "缺少夜间结算温度快照：temperature_before。"
	var raw_temperature = context.get("temperature_before", context.get("environment_temperature"))
	if not raw_temperature is int and not raw_temperature is float:
		return "夜间结算上下文无效：temperature_before。"
	var temperature := float(raw_temperature)
	if is_nan(temperature) or is_inf(temperature):
		return "夜间结算上下文无效：temperature_before。"
	return ""

func _failure_result(context: Dictionary, reason: String) -> Dictionary:
	var lines: Array[String] = []
	var raw_lines = context.get("report_lines", [])
	if raw_lines is Array:
		for line in raw_lines:
			lines.append(str(line))
	lines.append(reason)
	return {
		"report_lines": lines,
		"phase": "error",
		"event": {},
		"health_depleted": false,
		"night_context": {},
		"audio_events": [],
		"no_food_days": int(context.get("no_food_days", 0))
	}

func _make_settlement_context(context: Dictionary, resources, survivors: Array, buildings, weather: String) -> SettlementContext:
	var adapter := SettlementContext.new()
	adapter.day = int(context.get("day", 1))
	adapter.weather = weather
	adapter.resources = resources
	adapter.survivors = survivors
	adapter.buildings = buildings
	adapter.in_house = bool(context.get("in_house", false))
	adapter.built_facilities = _built_ids(buildings)
	var collector: AudioCollector = context.get("_audio_collector")
	if collector == null:
		collector = AudioCollector.new()
	adapter.audio = collector
	context["_audio_collector"] = collector
	return adapter

func _built_ids(buildings) -> Array[String]:
	var ids: Array[String] = []
	if buildings != null and "built" in buildings:
		for key in buildings.built:
			ids.append(str(key))
	return ids

func _random_alive(survivors: Array, rng) -> Object:
	var alive: Array = []
	for survivor in survivors:
		if survivor.alive:
			alive.append(survivor)
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]

func _protagonist_depleted(survivors: Array) -> bool:
	if survivors.is_empty():
		return true
	var hero = survivors[0]
	return not hero.alive or hero.health <= 0

func _event_context(weather: String, buildings, survival) -> Dictionary:
	var built_ids := _built_ids(buildings)
	var recent_actions := {}
	if survival != null and "action_counts" in survival:
		recent_actions = survival.action_counts.duplicate(true)
	return {"weather": weather, "built_facilities": built_ids, "recent_actions": recent_actions}
