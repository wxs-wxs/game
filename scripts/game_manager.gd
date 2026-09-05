class_name GameManager
extends RefCounted

const BlueprintSystemClass = preload("res://scripts/blueprint_system.gd")
const ConstructionSkillClass = preload("res://scripts/construction_skill.gd")
const SurvivalDirectorClass = preload("res://scripts/survival_director.gd")
const CraftingSystemClass = preload("res://scripts/crafting_system.gd")

const PHASE_MORNING := "morning"
const PHASE_DAY := "day"
const PHASE_EVENT := "event"
const PHASE_REPORT := "report"
const PHASE_ENDED := "ended"
const SAVE_VERSION := 8

const NORMAL_BODY_TEMPERATURE_C := 37.0
const BODY_TEMPERATURE_DAMAGE_THRESHOLD_C := 35.0
const BODY_TEMPERATURE_DAMAGE_INTERVAL := 8.0
const WEATHER_TEMPERATURES := {"晴朗": 16.0, "多云": 11.0, "浓雾": 7.0, "暴雨": 9.0, "寒冷": -5.0}

var resources := ResourceManager.new()
var time := TimeManager.new()
var tasks := TaskSystem.new()
var buildings := BuildingSystem.new()
var events := EventSystem.new()
var saves := SaveSystem.new()
var blueprints = BlueprintSystemClass.new()
var construction_skill = ConstructionSkillClass.new()
var survival = SurvivalDirectorClass.new()
var crafting = CraftingSystemClass.new()
var audio
var exploration_world
var in_house := false
var house_id := "starter_hut"
var house_level := 0
var fire_states: Dictionary = {}
var house_fire_lit: bool:
	get:
		return is_fire_active("house_fireplace")
	set(value):
		var state: Dictionary = fire_states.get("house_fireplace", {})
		if state.is_empty():
			state = _default_fire_states().get("house_fireplace", {}).duplicate(true)
		if value:
			state["lit"] = is_fire_active("house_fireplace")
		else:
			state["lit"] = false
			state["fuel_remaining"] = 0.0
		fire_states["house_fireplace"] = state
var outdoor_position := Vector2(180, 155)
var built_facilities: Array[String] = []
var rng := RandomNumberGenerator.new()
var random_seed: int = 14072026
var day: int = 1
var phase: String = PHASE_MORNING
var weather: String = "晴朗"
var environment_temperature: float = 16.0
var survivors: Array = []
var daily_log: Array[String] = []
var report_lines: Array[String] = []
var key_choices: Array[String] = []
var no_food_days: int = 0
var safety: int = 50
var won: bool = false
var end_reason: String = ""
var exploration_mode: bool = true
var day_return_required: bool = false
var night_settlement_applied: bool = false
var night_context: Dictionary = {}
var torch_bonus_pending := false
var deployed_traps: int = 0

func _init() -> void:
	new_game(random_seed)

func new_game(seed_value: int = 14072026) -> void:
	random_seed = seed_value
	rng.seed = random_seed
	resources = ResourceManager.new()
	time = TimeManager.new()
	tasks = TaskSystem.new()
	buildings = BuildingSystem.new()
	events = EventSystem.new()
	blueprints = BlueprintSystemClass.new()
	blueprints.setup(buildings)
	construction_skill = ConstructionSkillClass.new()
	crafting = CraftingSystemClass.new(); crafting.setup(self)
	survival = SurvivalDirectorClass.new()
	survival.reset(random_seed)
	fire_states = _default_fire_states()
	blueprints.unlock("storage_shelf")
	blueprints.unlock("workbench")
	resources.set_workbench_available(false)
	day = 1; phase = PHASE_MORNING; weather = "晴朗"; environment_temperature = 16.0; no_food_days = 0; safety = 50; exploration_mode = true
	day_return_required = false; night_settlement_applied = false; night_context = {}
	in_house = false; house_id = "starter_hut"; house_level = 0; house_fire_lit = false; outdoor_position = Vector2(180, 155); built_facilities = []
	torch_bonus_pending = false; deployed_traps = 0
	daily_log = ["第 1 天清晨，营地在灰烬中醒来。"]
	report_lines = []; key_choices = []; won = false; end_reason = ""
	survivors = []
	# Exploration has one directly controlled survivor; the old work roster is no longer the main loop.
	survivors.append(Survivor.create_profile({"id":"protagonist","name":"阿禾","role":"流浪者","color":"91ad75","gather":2,"build":1,"medical":1}))

func start_exploration() -> void:
	phase = PHASE_DAY
	day_return_required = false
	night_settlement_applied = false
	night_context = {}
	time.reset_day()
	exploration_mode = true
	var previous_threat: int = int(survival.threat)
	survival.begin_day(day, weather, self)
	_emit_survival_audio(previous_threat)
	daily_log.append("第 %d 天：离开营地，开始探索。" % day)
	_refresh_world_audio_context()
	if audio != null:
		audio.emit_event("day.dawn")

func advance_exploration(delta: float) -> void:
	if check_protagonist_health(): return
	if not exploration_mode or phase != PHASE_DAY or time.paused or day_return_required: return
	var before_elapsed := time.elapsed
	var before_progress := time.progress()
	time.advance(delta)
	_update_temperature(maxf(0.0, time.elapsed - before_elapsed))
	_emit_dusk_warning_if_crossed(before_progress)
	survival.observe_resources(self)
	if check_protagonist_health(): return
	if time.is_finished():
		day_return_required = true

func begin_morning() -> void:
	phase = PHASE_MORNING
	day_return_required = false
	night_settlement_applied = false
	night_context = {}
	time.reset_day()
	var previous_threat: int = int(survival.threat)
	survival.begin_day(day, weather, self)
	_emit_survival_audio(previous_threat)
	_refresh_world_audio_context()
	if audio != null:
		audio.emit_event("day.dawn")

func advance(delta: float) -> void:
	if check_protagonist_health(): return
	if exploration_mode:
		advance_exploration(delta)
	else:
		tick(delta)

func finish_exploration_day() -> Dictionary:
	if phase != PHASE_DAY or not day_return_required:
		return {"ok": false, "phase": phase, "reason": "请先回到床边。"}
	if night_settlement_applied:
		return {"ok": false, "phase": phase, "reason": "今天已经结算。"}
	return _resolve_night()

func _resolve_night() -> Dictionary:
	if night_settlement_applied:
		return {"ok": false, "phase": phase, "reason": "今天已经结算。"}
	night_settlement_applied = true
	night_context = {
		"day": day,
		"weather": weather,
		"resource_before": resources.to_dict(),
		"threat_before": survival.threat,
		"temperature_before": environment_temperature,
		"completed_buildings": _canonical_built_ids()
	}
	report_lines = _night_settlement()
	var previous_threat: int = int(survival.threat)
	report_lines.append_array(survival.settle_day(self))
	_emit_survival_audio(previous_threat)
	if check_protagonist_health():
		return {"ok": true, "phase": phase, "reason": "主角生命值归零，游戏结束。"}
	var created := events.create_weighted_event(rng, survival.event_context(self))
	if created.is_empty(): phase = PHASE_REPORT
	else:
		phase = PHASE_EVENT
		_emit_audio("event.reveal", {"event_id": str(created.get("id", ""))})
	_refresh_world_audio_context()
	if audio != null:
		audio.emit_event("night.report")
	return {"ok": true, "phase": phase, "reason": "夜间结算完成。"}

func _finish_exploration_day() -> void:
	day_return_required = true
	finish_exploration_day()

func start_day() -> Dictionary:
	if phase != PHASE_MORNING: return {"ok":false,"reason":"当前不能开始白天"}
	phase = PHASE_DAY
	time.reset_day()
	var previous_threat: int = int(survival.threat)
	survival.begin_day(day, weather, self)
	_emit_survival_audio(previous_threat)
	tasks.begin_day(survivors)
	daily_log.append("工作开始：%s" % assignments_text())
	_emit_audio("day.dawn")
	return {"ok":true,"reason":"白天开始"}

func tick(delta: float) -> bool:
	if check_protagonist_health(): return false
	if phase != PHASE_DAY: return false
	var before_elapsed := time.elapsed
	var before_progress := time.progress()
	var task_ticks := time.advance(delta)
	_update_temperature(maxf(0.0, time.elapsed - before_elapsed))
	_emit_dusk_warning_if_crossed(before_progress)
	for index in task_ticks:
		_resolve_work_tick()
		if check_protagonist_health(): return true
	if time.is_finished():
		finish_day()
		return true
	return task_ticks > 0

func finish_day() -> void:
	if phase != PHASE_DAY: return
	_resolve_night()

func force_finish_day() -> void:
	if phase != PHASE_DAY: return
	var before_elapsed := time.elapsed
	var before_progress := time.progress()
	var remaining_ticks: int = time.remaining_work_ticks()
	for index in range(maxi(0, remaining_ticks)): _resolve_work_tick()
	time.elapsed = TimeManager.DAY_SECONDS
	_update_temperature(maxf(0.0, time.elapsed - before_elapsed))
	_emit_dusk_warning_if_crossed(before_progress)
	finish_day()

func _resolve_work_tick() -> void:
	var lines := tasks.resolve_tick(survivors, resources, buildings, weather, rng)
	survival.observe_resources(self)
	for line in lines: daily_log.append(line)
	if not lines.is_empty():
		_emit_audio("task.complete", {"lines": lines})
	var completed_id := buildings.last_completed_id
	if completed_id != "":
		apply_building_effect(completed_id)
		survival.record_building(completed_id)
	if completed_id != "": built_facilities = _canonical_built_ids()
	buildings.last_completed_id = ""

func choose_event(index: int) -> Dictionary:
	if phase != PHASE_EVENT: return {"ok":false,"reason":"当前没有待处理事件"}
	var cost := events.choice_cost(index)
	if not resources.can_afford(cost): return {"ok":false,"reason":resources.missing_cost_text(cost)}
	var event_id := str(events.current_event.get("id", ""))
	var choice_id := ""
	if not events.current_event.is_empty():
		var choices: Array = events.current_event.get("data", {}).get("choices", [])
		if index >= 0 and index < choices.size(): choice_id = str(choices[index].get("id", ""))
	var health_before: int = get_protagonist().health if get_protagonist() != null else 0
	var result := events.resolve_choice(index, self)
	if result.is_empty():
		return {"ok":false,"reason":"事件选择无效，事件仍待处理。"}
	var previous_threat: int = int(survival.threat)
	survival.record_event(event_id, choice_id)
	_emit_audio("event.choice", {"event_id": event_id, "choice_id": choice_id})
	_emit_survival_audio(previous_threat)
	var hero_after := get_protagonist()
	if hero_after != null and hero_after.health < health_before:
		_emit_audio("player.hurt", {"source": "event", "amount": health_before - hero_after.health})
	for line in result: report_lines.append(line)
	if check_protagonist_health(): return {"ok":true, "reason":"主角生命值归零，游戏结束。"}
	phase = PHASE_REPORT
	return {"ok":true,"reason":"事件已处理"}

func continue_from_report() -> void:
	if phase != PHASE_REPORT: return
	if check_protagonist_health(): return
	day += 1
	weather = _roll_weather()
	begin_morning()
	daily_log = ["第 %d 天清晨：%s。" % [day, weather]]

func assign_work(survivor_index: int, work_name: String) -> Dictionary:
	if phase != PHASE_MORNING: return {"ok":false,"reason":"只能在清晨分配工作"}
	if survivor_index < 0 or survivor_index >= survivors.size(): return {"ok":false,"reason":"幸存者不存在"}
	if tasks.assign(survivors[survivor_index], work_name): return {"ok":true,"reason":"工作已分配"}
	return {"ok":false,"reason":"无法分配该工作"}

func begin_construction(building_id: String) -> Dictionary:
	if phase != PHASE_MORNING: return {"ok":false,"reason":"请在清晨规划建造"}
	return buildings.start_project(building_id, resources, construction_skill.level)

func construction_catalog(group: String = "") -> Array[Dictionary]:
	return buildings.catalog(group)

func construction_status(building_id: String) -> Dictionary:
	var definition: Dictionary = buildings.get_definition(building_id)
	if definition.is_empty(): return {"id":building_id, "state":"unknown", "reason":"未知设施"}
	var id := str(building_id)
	var status := {"id":id, "name":str(definition.get("name", id)), "cost":definition.get("cost", {}).duplicate(true), "build_time":float(definition.get("build_time", 0.0)), "required_skill_level":int(definition.get("required_skill_level", 1)), "context":str(definition.get("context", "camp")), "effect":str(definition.get("description", ""))}
	if buildings.has(id): status["state"] = "completed"
	elif buildings.active_project.get("id", "") == id or buildings.world_projects.has(id): status["state"] = "building"
	elif not buildings.is_unlocked(id, construction_skill.level): status["state"] = "locked"; status["reason"] = "需要建造技能 Lv.%d" % int(definition.get("required_skill_level", 1))
	elif not resources.can_afford(definition.get("cost", {})): status["state"] = "materials"; status["reason"] = resources.missing_cost_text(definition.get("cost", {}))
	else: status["state"] = "available"
	return status

func construction_entries(group: String = "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for definition in buildings.catalog(group): entries.append(construction_status(str(definition.get("id", ""))))
	return entries

func apply_building_effect(building_id: String) -> void:
	if building_id.is_empty() or not buildings.has(building_id) or buildings.effect_applied.has(building_id):
		return
	buildings.effect_applied[building_id] = true
	match building_id:
		"storage_shelf":
			resources.add_capacity_all(5)
			daily_log.append("储物架扩充了所有资源容量。")
			if exploration_world != null and exploration_world.has_method("register_outdoor_shelf"): exploration_world.register_outdoor_shelf()
		"shed":
			resources.add_capacity_all(10); daily_log.append("储物棚扩充了所有资源容量。")
		"workbench":
			resources.set_workbench_available(true); daily_log.append("简易工作台完成，工具和制作配方已解锁。")
		"fire_basin": daily_log.append("火盆完成，寒冷夜间的保温效果已启用。")
		"rain_collector": daily_log.append("雨水收集器完成，暴雨时可以收集水。")
		_:
			if building_id in ["campfire", "bed", "clinic", "fence"]: daily_log.append("%s完成。" % buildings.get_definition(building_id).get("name", building_id))

func complete_world_construction(building_id: String) -> void:
	var was_built := buildings.has(building_id)
	if was_built and buildings.effect_applied.has(building_id):
		built_facilities = _canonical_built_ids()
		return
	if not was_built:
		buildings.complete(building_id)
	apply_building_effect(building_id)
	built_facilities = _canonical_built_ids()
	daily_log.append("建造完成：%s。" % buildings.get_definition(building_id).get("name", building_id))
	survival.record_building(building_id)

func _canonical_built_ids() -> Array[String]:
	var result: Array[String] = []
	for key in buildings.built:
		if str(key) not in result: result.append(str(key))
	return result

func upgrade_house() -> Dictionary:
	if in_house: return {"ok":false, "reason":"请在小屋外进行升级。"}
	var costs := [{"wood":6,"fiber":3,"metal":1}, {"wood":10,"stone":4,"metal":2}, {"wood":18,"stone":8,"metal":3}]
	if house_level >= costs.size(): return {"ok":false, "reason":"小屋已经达到最高等级。"}
	var cost: Dictionary = costs[house_level]
	if not resources.can_afford(cost): return {"ok":false, "reason":resources.missing_cost_text(cost)}
	resources.spend(cost); house_level += 1; construction_skill.repaired_count += 1; construction_skill.add_experience(12)
	survival.record_action("house_upgrade")
	daily_log.append("小屋升级至等级 %d。" % house_level)
	if audio != null:
		audio.emit_event("house.upgrade")
	return {"ok":true, "reason":"小屋升级至等级 %d。" % house_level}

func grant_construction_xp(amount: int) -> bool:
	var leveled := construction_skill.add_experience(amount)
	if leveled or amount > 0:
		for blueprint_id in buildings.definitions:
			var definition: Dictionary = buildings.definitions[blueprint_id]
			if str(definition.get("context", "camp")) == "exploration" and int(definition.get("required_skill_level", 1)) <= construction_skill.level:
				var id := str(blueprint_id)
				var was_unlocked := blueprints.is_unlocked(id)
				if blueprints.unlock(id) and not was_unlocked:
					_emit_audio("blueprint.unlocked", {"blueprint_id": id})
	return leveled

func toggle_pause() -> void:
	if phase == PHASE_DAY: time.paused = not time.paused

func get_protagonist() -> Survivor:
	return survivors[0] if not survivors.is_empty() else null

func _fire_config() -> Dictionary:
	if survival != null and survival.definitions.get("fire", {}) is Dictionary:
		return survival.definitions.get("fire", {})
	return {}

func _default_fire_states() -> Dictionary:
	var config := _fire_config()
	var capacity := maxf(0.1, float(config.get("fuel_capacity", 360.0)))
	var per_wood := maxf(0.1, float(config.get("fuel_per_wood", 120.0)))
	return {
		"campfire": {"lit": false, "fuel_remaining": 0.0, "fuel_capacity": capacity, "fuel_per_wood": per_wood},
		"house_fireplace": {"lit": false, "fuel_remaining": 0.0, "fuel_capacity": capacity, "fuel_per_wood": per_wood}
	}

func fire_state(source_id: String) -> Dictionary:
	var state: Dictionary = fire_states.get(source_id, {})
	return state.duplicate(true)

func add_fire_fuel(source_id: String, wood: int = 1) -> Dictionary:
	if wood <= 0 or not fire_states.has(source_id):
		return {"ok": false, "reason": "无法添加燃料。"}
	var state: Dictionary = fire_states[source_id]
	if not resources.can_afford({"wood": wood}):
		return {"ok": false, "reason": resources.missing_cost_text({"wood": wood})}
	var was_lit := bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0
	var per_wood := maxf(0.1, float(state.get("fuel_per_wood", 120.0)))
	var available := maxf(0.0, float(state.get("fuel_capacity", 360.0)) - float(state.get("fuel_remaining", 0.0)))
	var accepted_wood := mini(wood, int(ceil(available / per_wood)))
	var added := minf(float(accepted_wood) * per_wood, available)
	if accepted_wood <= 0 or added <= 0.0:
		return {"ok": false, "reason": "燃料已经满了。"}
	resources.spend({"wood": accepted_wood})
	state["fuel_remaining"] = float(state.get("fuel_remaining", 0.0)) + added
	state["lit"] = true
	fire_states[source_id] = state
	_refresh_world_audio_context()
	return {"ok": true, "reason": "火焰重新燃旺。", "state": state.duplicate(true)}

func tick_fire(delta: float) -> void:
	if delta <= 0.0:
		return
	var changed := false
	for source_id in fire_states.keys():
		var state: Dictionary = fire_states[source_id]
		var was_lit := bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0
		var before_remaining := float(state.get("fuel_remaining", 0.0))
		var remaining := maxf(0.0, float(state.get("fuel_remaining", 0.0)) - delta)
		state["fuel_remaining"] = remaining
		if remaining <= 0.0:
			state["lit"] = false
			if was_lit and before_remaining > 0.0:
				if audio != null:
					audio.emit_event("fire.extinguish")
				changed = true
		elif before_remaining > 20.0 and remaining <= 20.0 and was_lit:
			if audio != null:
				audio.emit_event("fire.fuel_low")
			changed = true
		fire_states[source_id] = state
	if changed:
		_refresh_world_audio_context()

func is_fire_active(source_id: String) -> bool:
	var state: Dictionary = fire_states.get(source_id, {})
	return bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0

func get_environment_temperature() -> float:
	var base := float(WEATHER_TEMPERATURES.get(weather, 12.0))
	var daylight := sin(clampf(time.progress(), 0.0, 1.0) * PI) * 7.0
	var temperature := base + daylight
	var fire_config := _fire_config()
	if in_house: temperature += 10.0
	if in_house and is_fire_active("house_fireplace"): temperature += float(fire_config.get("house_fireplace_warmth", 7.0))
	if buildings != null and buildings.has("fire_basin"): temperature += 4.0
	if not in_house:
		var position := outdoor_position
		if exploration_world != null and exploration_world.player != null:
			position = exploration_world.player.global_position
		if is_fire_active("campfire") and position.distance_to(Vector2(210, 153)) <= 110.0: temperature += float(fire_config.get("campfire_warmth", 6.0))
	environment_temperature = snappedf(temperature, 0.1)
	return environment_temperature

func get_temperature_status() -> Dictionary:
	var hero := get_protagonist()
	return {"environment":get_environment_temperature(), "body":float(hero.body_temperature) if hero != null else NORMAL_BODY_TEMPERATURE_C, "threshold":BODY_TEMPERATURE_DAMAGE_THRESHOLD_C}

func _update_temperature(simulation_seconds: float) -> void:
	if simulation_seconds <= 0.0: return
	tick_fire(simulation_seconds)
	var hero := get_protagonist()
	if hero == null or not hero.alive: return
	var environment := get_environment_temperature()
	# Warm shelter aims at normal body temperature. Outdoors in a cold
	# environment pulls the target down, so hypothermia develops over time.
	var target := clampf(NORMAL_BODY_TEMPERATURE_C + (environment - 12.0) * 0.35, 28.0, NORMAL_BODY_TEMPERATURE_C)
	var response := 0.006 if target < NORMAL_BODY_TEMPERATURE_C else 0.009
	hero.body_temperature = clampf(hero.body_temperature + (target - hero.body_temperature) * response * simulation_seconds, -50.0, NORMAL_BODY_TEMPERATURE_C)
	if hero.body_temperature < BODY_TEMPERATURE_DAMAGE_THRESHOLD_C:
		_emit_audio("survival.temperature_warning", {"body_temperature": hero.body_temperature})
		hero.temperature_damage_accumulator += simulation_seconds
		while hero.temperature_damage_accumulator >= BODY_TEMPERATURE_DAMAGE_INTERVAL:
			hero.temperature_damage_accumulator -= BODY_TEMPERATURE_DAMAGE_INTERVAL
			hero.apply_change("health", -1)
			_emit_audio("player.hurt", {"source": "cold", "amount": 1, "body_temperature": hero.body_temperature})
			if check_protagonist_health(): return
	else:
		hero.temperature_damage_accumulator = maxf(0.0, hero.temperature_damage_accumulator - simulation_seconds * 0.5)

func check_protagonist_health() -> bool:
	if phase == PHASE_ENDED:
		return true
	var hero := get_protagonist()
	if hero != null and hero.alive and hero.health > 0:
		return false
	phase = PHASE_ENDED
	won = false
	exploration_mode = false
	time.paused = false
	end_reason = "%s生命值归零，探索结束。" % (hero.display_name if hero != null else "主角")
	daily_log.append(end_reason)
	if audio != null:
		audio.emit_event("player.death")
		_refresh_world_audio_context()
		audio.emit_event("game.over")
	return true

func change_all(stat: String, amount: int) -> void:
	for survivor in survivors:
		if survivor.alive: survivor.apply_change(stat, amount)

func adjust_relation(key: String, amount: int) -> void:
	for survivor in survivors:
		survivor.relations[key] = int(survivor.relations.get(key, 0)) + amount

func random_alive() -> Survivor:
	var alive: Array = []
	for survivor in survivors:
		if survivor.alive: alive.append(survivor)
	if alive.is_empty(): return null
	return alive[rng.randi_range(0, alive.size() - 1)]

func add_wanderer() -> void:
	var profile := {"id":"wanderer_%d" % day,"name":"诺","role":"流浪者","color":"c98c62","gather":1,"build":1,"medical":1}
	var newcomer := Survivor.create_profile(profile)
	newcomer.health = 65; newcomer.hunger = 40; newcomer.energy = 35
	survivors.append(newcomer)
	survival.record_recruitment()

func alive_count() -> int:
	var count := 0
	for survivor in survivors:
		if survivor.alive: count += 1
	return count

func assignments_text() -> String:
	var rows: Array[String] = []
	for survivor in survivors:
		if survivor.alive: rows.append("%s-%s" % [survivor.display_name, survivor.current_work])
	return "、".join(rows)

## Small integration surface for HUD, input, and future systems.
func set_camp_policy(next_policy_id: String) -> Dictionary:
	var result := survival.set_policy(next_policy_id, self)
	if bool(result.get("ok", false)):
		daily_log.append(str(result.get("reason", "政策已更新")))
	return result

func get_survival_status() -> Dictionary:
	return survival.get_status(self)

func get_daily_goal() -> Dictionary:
	return survival.get_goal_summary(self)

func get_weather_effect() -> Dictionary:
	return survival.weather_effect(weather)

func record_survival_action(action_id: String, amount: int = 1) -> void:
	survival.record_action(action_id, amount)

func _emit_audio(event_id: String, params: Dictionary = {}) -> void:
	if audio != null and audio.has_method("emit_event"):
		audio.emit_event(event_id, params)

func _emit_survival_audio(previous_threat: int) -> void:
	if previous_threat != survival.threat:
		_emit_audio("survival.threat_changed", {"before": previous_threat, "after": survival.threat})

func _emit_dusk_warning_if_crossed(previous_progress: float) -> void:
	if previous_progress < 0.8 and time.progress() >= 0.8:
		_emit_audio("day.dusk_warning", {"progress": time.progress()})

## Tool crafting is owned by ResourceManager; these thin wrappers keep the
## public game API convenient for HUDs, tests, and future crafting stations
## without introducing a second source of truth.
func has_axe() -> bool:
	return resources != null and resources.has_method("has_axe") and bool(resources.has_axe())

func has_pickaxe() -> bool:
	return resources != null and resources.has_method("has_pickaxe") and bool(resources.has_pickaxe())

func axe_status() -> Dictionary:
	if resources != null and resources.has_method("axe_status"):
		return resources.axe_status()
	return {"id":"axe", "owned":false, "unlocked":false, "can_craft":false}

func pickaxe_status() -> Dictionary:
	if resources != null and resources.has_method("pickaxe_status"):
		return resources.pickaxe_status()
	return {"id":"pickaxe", "owned":false, "unlocked":false, "can_craft":false}

func unlock_axe() -> Dictionary:
	if resources == null or not resources.has_method("unlock_axe"):
		return {"ok":false, "reason":"制作系统未就绪。"}
	return resources.unlock_axe()

func craft_axe() -> Dictionary:
	if resources == null or not resources.has_method("craft_axe"):
		return {"ok":false, "reason":"制作系统未就绪。"}
	var result: Dictionary = resources.craft_axe()
	if bool(result.get("ok", false)):
		daily_log.append(str(result.get("reason", "制作了石斧。")))
		_emit_audio("craft.complete", {"recipe_id": "axe"})
	else:
		_emit_audio("craft.failed", {"recipe_id": "axe"})
	return result

func craft_pickaxe() -> Dictionary:
	if resources == null or not resources.has_method("craft_pickaxe"):
		return {"ok":false, "reason":"制作系统未就绪。"}
	var result: Dictionary = resources.craft_pickaxe()
	if bool(result.get("ok", false)):
		daily_log.append(str(result.get("reason", "制作了石镐。")))
		_emit_audio("craft.complete", {"recipe_id": "pickaxe"})
	else:
		_emit_audio("craft.failed", {"recipe_id": "pickaxe"})
	return result

func craft_item(recipe_id: String) -> Dictionary:
	if crafting == null: return {"ok":false, "reason":"制作系统未就绪。"}
	return crafting.craft(recipe_id)

func use_item(item_id: String) -> Dictionary:
	if crafting == null: return {"ok":false, "reason":"制作系统未就绪。"}
	return crafting.use_item(item_id)

func _night_settlement() -> Array[String]:
	var lines: Array[String] = ["夜间结算"]
	survival.observe_resources(self)
	var alive: Array = []
	for survivor in survivors:
		if survivor.alive: alive.append(survivor)
	var meals := mini(resources.get_amount("food"), alive.size())
	resources.add("food", -meals)
	for index in alive.size():
		var survivor: Survivor = alive[index]
		if index < meals:
			survivor.apply_change("hunger", 18)
		else:
			survivor.apply_change("hunger", -22); survivor.apply_change("health", -7); survivor.apply_change("morale", -8)
			if survivor == get_protagonist(): _emit_audio("player.hurt", {"source": "night_food", "amount": 7})
	if meals < alive.size():
		lines.append("食物不足：%d 人空腹，生命与士气下降。" % [alive.size() - meals])
		_emit_audio("survival.food_warning", {"missing_meals": alive.size() - meals})
	else: lines.append("配给完成：消耗 %d 食物。" % meals)
	lines.append("夜间温度结算：低温伤害已在探索过程中实时计算。")
	if weather == "暴雨":
		var collected_water := buildings.rain_water_yield()
		if collected_water > 0:
			var actual_water := resources.add("water", collected_water)
			lines.append("暴雨收集：获得 %d 水。" % actual_water)
	if weather == "暴雨" and rng.randf() < (0.35 if not in_house or house_level == 0 else 0.12):
		var patient := random_alive()
		if patient != null:
			patient.sick = true; patient.apply_change("health", -4); lines.append("暴雨让 %s 着凉生病。" % patient.display_name)
	if resources.get_amount("food") == 0: no_food_days += 1
	else: no_food_days = 0
	for survivor in survivors:
		if survivor.alive and (survivor.health <= 0 or survivor.hunger <= 0):
			survivor.apply_change("health", -12)
			if survivor == get_protagonist(): _emit_audio("player.hurt", {"source": "night_starvation", "amount": 12})
			if not survivor.alive: lines.append("%s 没能撑过这一夜。" % survivor.display_name)
	return lines

func _roll_weather() -> String:
	var roll := rng.randi_range(0, 99)
	if roll < 20: return "暴雨"
	if roll < 42: return "寒冷"
	if roll < 68: return "多云"
	if roll < 82: return "浓雾"
	return "晴朗"

func save_state() -> bool:
	return saves.save_game(to_dict())

func load_state() -> bool:
	var data := saves.load_game()
	if data.is_empty(): return false
	from_dict(data)
	return true

func to_dict() -> Dictionary:
	var survivor_data: Array = []
	for survivor in survivors: survivor_data.append(survivor.to_dict())
	var world_data: Dictionary = exploration_world.serialize_state() if exploration_world != null else {"in_house":in_house,"outdoor_position":[outdoor_position.x, outdoor_position.y]}
	return {"version":SAVE_VERSION,"random_seed":random_seed,"rng_state":rng.state,"day":day,"phase":phase,"weather":weather,"environment_temperature":environment_temperature,"exploration_mode":exploration_mode,"day_return_required":day_return_required,"night_settlement_applied":night_settlement_applied,"night_context":night_context.duplicate(true),"survivors":survivor_data,"resources":resources.to_dict(),"time":time.to_dict(),"buildings":buildings.to_dict(),"events":events.to_dict(),"survival":survival.to_dict(),"daily_log":daily_log,"report_lines":report_lines,"key_choices":key_choices,"no_food_days":no_food_days,"safety":safety,"won":won,"end_reason":end_reason,"house_id":house_id,"house_level":house_level,"house_fire_lit":house_fire_lit,"fire_states":fire_states.duplicate(true),"built_facilities":built_facilities,"construction_skill":construction_skill.to_dict(),"blueprints":blueprints.to_dict(),"crafting":{"torch_bonus_pending":torch_bonus_pending,"deployed_traps":deployed_traps},"world":world_data}

func from_dict(data: Dictionary) -> void:
	var raw_version := int(data.get("version", 0))
	saves = SaveSystem.new()
	data = saves.migrate(data)
	random_seed = int(data.get("random_seed", 14072026)); rng.seed = random_seed; rng.state = int(data.get("rng_state", rng.state))
	resources = ResourceManager.new(); resources.from_dict(data.get("resources", {}))
	time = TimeManager.new(); time.from_dict(data.get("time", {}))
	tasks = TaskSystem.new(); buildings = BuildingSystem.new(); buildings.from_dict(data.get("buildings", {}))
	events = EventSystem.new(); events.from_dict(data.get("events", {}))
	blueprints = BlueprintSystemClass.new(); blueprints.setup(buildings); blueprints.from_dict(data.get("blueprints", {}))
	construction_skill = ConstructionSkillClass.new(); construction_skill.from_dict(data.get("construction_skill", {}))
	crafting = CraftingSystemClass.new(); crafting.setup(self)
	survival = SurvivalDirectorClass.new()
	var survival_data: Dictionary = data.get("survival", {})
	if survival_data.is_empty(): survival.reset(random_seed)
	else: survival.from_dict(survival_data)
	var migrate_legacy_house_fire: bool = not data.has("fire_states") and bool(data.get("house_fire_lit", false))
	fire_states = _default_fire_states()
	var saved_fire_states: Variant = data.get("fire_states", {})
	if saved_fire_states is Dictionary:
		for source_id in fire_states.keys():
			var saved_state: Variant = saved_fire_states.get(source_id, {})
			if saved_state is Dictionary:
				var merged_state: Dictionary = fire_states[source_id].duplicate(true)
				for key in saved_state:
					merged_state[key] = saved_state[key]
				merged_state["fuel_remaining"] = clampf(float(merged_state.get("fuel_remaining", 0.0)), 0.0, float(merged_state.get("fuel_capacity", 360.0)))
				merged_state["lit"] = bool(merged_state.get("lit", false)) and float(merged_state.get("fuel_remaining", 0.0)) > 0.0
				fire_states[source_id] = merged_state
	if not data.has("blueprints"):
		blueprints.unlock("storage_shelf"); blueprints.unlock("workbench")
	day = int(data.get("day", 1)); phase = str(data.get("phase", PHASE_MORNING)); weather = str(data.get("weather", "晴朗")); environment_temperature = float(data.get("environment_temperature", WEATHER_TEMPERATURES.get(weather, 12.0))); exploration_mode = bool(data.get("exploration_mode", true)); day_return_required = bool(data.get("day_return_required", false)); night_settlement_applied = bool(data.get("night_settlement_applied", false)); night_context = data.get("night_context", {}) if data.get("night_context", {}) is Dictionary else {}
	survivors = []
	for row in data.get("survivors", []): survivors.append(Survivor.from_dict(row))
	daily_log = []
	for line in data.get("daily_log", []): daily_log.append(str(line))
	if migrate_legacy_house_fire:
		daily_log.append("旧存档兼容：炉火获得一次初始燃料。")
	if raw_version < SaveSystem.CURRENT_VERSION:
		var migration_refund: Variant = data.get("migration_refund", {})
		if migration_refund is Dictionary and not migration_refund.is_empty():
			var refunded: Array[String] = []
			for key in migration_refund:
				var amount := resources.add(str(key), maxi(0, int(migration_refund[key])))
				if amount > 0: refunded.append("%s+%d" % [resources.display_name(str(key)), amount])
			if not refunded.is_empty():
				daily_log.append("旧存档兼容：重复施工材料已返还（%s）。" % "、".join(refunded))
	report_lines = []
	for line in data.get("report_lines", []): report_lines.append(str(line))
	key_choices = []
	for line in data.get("key_choices", []): key_choices.append(str(line))
	no_food_days = int(data.get("no_food_days", 0)); safety = int(data.get("safety", 50)); won = bool(data.get("won", false)); end_reason = str(data.get("end_reason", ""))
	house_id = str(data.get("house_id", "starter_hut")); house_level = int(data.get("house_level", 0)); built_facilities = []
	if migrate_legacy_house_fire:
		var legacy_fire: Dictionary = fire_states["house_fireplace"]
		legacy_fire["fuel_remaining"] = minf(float(legacy_fire.get("fuel_capacity", 360.0)), float(legacy_fire.get("fuel_per_wood", 120.0)))
		legacy_fire["lit"] = true
		fire_states["house_fireplace"] = legacy_fire
	for item in data.get("built_facilities", []):
		var legacy_id := str(item)
		if buildings.definitions.has(legacy_id):
			buildings.built[legacy_id] = 1
			buildings.effect_applied[legacy_id] = true
	for item in _canonical_built_ids(): built_facilities.append(item)
	for built_id in buildings.built:
		if not buildings.effect_applied.has(str(built_id)): buildings.effect_applied[str(built_id)] = true
	resources.set_workbench_available(buildings.has_workbench())
	var crafting_state: Dictionary = data.get("crafting", {}) if data.get("crafting", {}) is Dictionary else {}
	torch_bonus_pending = bool(crafting_state.get("torch_bonus_pending", false)); deployed_traps = maxi(0, int(crafting_state.get("deployed_traps", 0)))
	var world_data: Dictionary = data.get("world", {})
	in_house = bool(world_data.get("in_house", false))
	var saved_position = world_data.get("outdoor_position", [180, 155])
	if saved_position is Array and saved_position.size() >= 2: outdoor_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	var legacy_audio: Variant = data.get("audio", {})
	if legacy_audio is Dictionary and not legacy_audio.is_empty():
		var service := _audio_service()
		if service != null:
			service.apply_settings(legacy_audio)
	if exploration_world != null: exploration_world.restore_state(world_data)

func _refresh_world_audio_context() -> void:
	if exploration_world != null and exploration_world.has_method("_refresh_audio_context"):
		exploration_world._refresh_audio_context()

func _audio_service() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var service := (main_loop as SceneTree).root.get_node_or_null("AudioService")
		if service != null and service.has_method("apply_settings"):
			return service
	if audio != null and audio.has_method("apply_settings"):
		return audio
	return null
