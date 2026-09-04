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
var house_fire_lit := false
var outdoor_position := Vector2(180, 155)
var built_facilities: Array[String] = []
var rng := RandomNumberGenerator.new()
var random_seed: int = 14072026
var day: int = 1
var phase: String = PHASE_MORNING
var weather: String = "晴朗"
var survivors: Array = []
var daily_log: Array[String] = []
var report_lines: Array[String] = []
var key_choices: Array[String] = []
var no_food_days: int = 0
var safety: int = 50
var won: bool = false
var end_reason: String = ""
var exploration_mode: bool = true
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
	blueprints.unlock("storage_shelf")
	blueprints.unlock("workbench")
	resources.set_workbench_available(false)
	day = 1; phase = PHASE_MORNING; weather = "晴朗"; no_food_days = 0; safety = 50; exploration_mode = true
	in_house = false; house_id = "starter_hut"; house_level = 0; house_fire_lit = false; outdoor_position = Vector2(180, 155); built_facilities = []
	torch_bonus_pending = false; deployed_traps = 0
	daily_log = ["第 1 天清晨，营地在灰烬中醒来。"]
	report_lines = []; key_choices = []; won = false; end_reason = ""
	survivors = []
	# Exploration has one directly controlled survivor; the old work roster is no longer the main loop.
	survivors.append(Survivor.create_profile({"id":"protagonist","name":"阿禾","role":"流浪者","color":"91ad75","gather":2,"build":1,"medical":1}))

func start_exploration() -> void:
	phase = PHASE_DAY
	time.reset_day()
	exploration_mode = true
	survival.begin_day(day, weather, self)
	daily_log.append("第 %d 天：离开营地，开始探索。" % day)
	if audio != null: audio.play_music("day")

func advance_exploration(delta: float) -> void:
	if check_protagonist_health(): return
	if not exploration_mode or phase != PHASE_DAY or time.paused: return
	time.advance(delta)
	survival.observe_resources(self)
	if check_protagonist_health(): return
	if time.is_finished(): _finish_exploration_day()

func _finish_exploration_day() -> void:
	var lines := _night_settlement()
	lines.append_array(survival.settle_day(self))
	for line in lines: daily_log.append(line)
	if audio != null: audio.play_music("night")
	if check_protagonist_health(): return
	day += 1
	weather = _roll_weather()
	time.reset_day()
	survival.begin_day(day, weather, self)
	daily_log.append("第 %d 天清晨：%s。" % [day, weather])
	if audio != null: audio.play_music("day")

func start_day() -> Dictionary:
	if phase != PHASE_MORNING: return {"ok":false,"reason":"当前不能开始白天"}
	phase = PHASE_DAY
	time.reset_day()
	survival.begin_day(day, weather, self)
	tasks.begin_day(survivors)
	daily_log.append("工作开始：%s" % assignments_text())
	return {"ok":true,"reason":"白天开始"}

func tick(delta: float) -> bool:
	if check_protagonist_health(): return false
	if phase != PHASE_DAY: return false
	var task_ticks := time.advance(delta)
	for index in task_ticks:
		_resolve_work_tick()
		if check_protagonist_health(): return true
	if time.is_finished():
		finish_day()
		return true
	return task_ticks > 0

func finish_day() -> void:
	if phase != PHASE_DAY: return
	phase = PHASE_EVENT
	report_lines = _night_settlement()
	report_lines.append_array(survival.settle_day(self))
	if check_protagonist_health(): return
	events.create_event(rng)

func force_finish_day() -> void:
	if phase != PHASE_DAY: return
	var remaining_ticks: int = time.remaining_work_ticks()
	for index in range(maxi(0, remaining_ticks)): _resolve_work_tick()
	time.elapsed = TimeManager.DAY_SECONDS
	finish_day()

func _resolve_work_tick() -> void:
	var lines := tasks.resolve_tick(survivors, resources, buildings, weather, rng)
	survival.observe_resources(self)
	for line in lines: daily_log.append(line)
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
	var result := events.resolve_choice(index, self)
	survival.record_event(event_id, choice_id)
	for line in result: report_lines.append(line)
	if check_protagonist_health(): return {"ok":true, "reason":"主角生命值归零，游戏结束。"}
	phase = PHASE_REPORT
	return {"ok":true,"reason":"事件已处理"}

func continue_from_report() -> void:
	if phase != PHASE_REPORT: return
	if check_protagonist_health(): return
	day += 1
	weather = _roll_weather()
	phase = PHASE_MORNING
	survival.begin_day(day, weather, self)
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
	var costs := [{"wood":6,"fiber":3,"scrap":2}, {"wood":10,"scrap":5,"stone":4,"metal":2}, {"wood":18,"stone":8,"metal":5,"scrap":6}]
	if house_level >= costs.size(): return {"ok":false, "reason":"小屋已经达到最高等级。"}
	var cost: Dictionary = costs[house_level]
	if not resources.can_afford(cost): return {"ok":false, "reason":resources.missing_cost_text(cost)}
	resources.spend(cost); house_level += 1; construction_skill.repaired_count += 1; construction_skill.add_experience(12)
	survival.record_action("house_upgrade")
	daily_log.append("小屋升级至等级 %d。" % house_level)
	if audio != null: audio.play_sfx("build_complete")
	return {"ok":true, "reason":"小屋升级至等级 %d。" % house_level}

func grant_construction_xp(amount: int) -> bool:
	var leveled := construction_skill.add_experience(amount)
	if leveled or amount > 0:
		for blueprint_id in buildings.definitions:
			var definition: Dictionary = buildings.definitions[blueprint_id]
			if str(definition.get("context", "camp")) == "exploration" and int(definition.get("required_skill_level", 1)) <= construction_skill.level:
				blueprints.unlock(str(blueprint_id))
	return leveled

func toggle_pause() -> void:
	if phase == PHASE_DAY: time.paused = not time.paused

func get_protagonist() -> Survivor:
	return survivors[0] if not survivors.is_empty() else null

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
	return result

func craft_pickaxe() -> Dictionary:
	if resources == null or not resources.has_method("craft_pickaxe"):
		return {"ok":false, "reason":"制作系统未就绪。"}
	var result: Dictionary = resources.craft_pickaxe()
	if bool(result.get("ok", false)):
		daily_log.append(str(result.get("reason", "制作了石镐。")))
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
	if meals < alive.size():
		lines.append("食物不足：%d 人空腹，生命与士气下降。" % [alive.size() - meals])
	else: lines.append("配给完成：消耗 %d 食物。" % meals)
	var fuel_need := 2 + (2 if weather == "寒冷" else 0) - buildings.fuel_discount()
	if weather == "寒冷": fuel_need -= buildings.cold_fuel_discount()
	fuel_need = max(1, fuel_need)
	var fuel_used := mini(resources.get_amount("fuel"), fuel_need)
	resources.add("fuel", -fuel_used)
	if fuel_used < fuel_need:
		change_all("morale", -5)
		if weather == "寒冷":
			var cold_damage := 4 if not in_house else maxi(0, 2 - buildings.indoor_cold_damage_reduction())
			if cold_damage > 0: change_all("health", -cold_damage)
		lines.append("燃料不足，营地在黑暗与寒冷中度过。")
	else: lines.append("篝火维持：消耗 %d 燃料。" % fuel_used)
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
	return {"version":6,"random_seed":random_seed,"rng_state":rng.state,"day":day,"phase":phase,"weather":weather,"exploration_mode":exploration_mode,"survivors":survivor_data,"resources":resources.to_dict(),"time":time.to_dict(),"buildings":buildings.to_dict(),"events":events.to_dict(),"survival":survival.to_dict(),"daily_log":daily_log,"report_lines":report_lines,"key_choices":key_choices,"no_food_days":no_food_days,"safety":safety,"won":won,"end_reason":end_reason,"house_id":house_id,"house_level":house_level,"house_fire_lit":house_fire_lit,"built_facilities":built_facilities,"construction_skill":construction_skill.to_dict(),"blueprints":blueprints.to_dict(),"crafting":{"torch_bonus_pending":torch_bonus_pending,"deployed_traps":deployed_traps},"world":world_data,"audio":audio.to_dict() if audio != null else {}}

func from_dict(data: Dictionary) -> void:
	random_seed = int(data.get("random_seed", 14072026)); rng.seed = random_seed; rng.state = int(data.get("rng_state", rng.state))
	resources = ResourceManager.new(); resources.from_dict(data.get("resources", {}))
	time = TimeManager.new(); time.from_dict(data.get("time", {}))
	tasks = TaskSystem.new(); buildings = BuildingSystem.new(); buildings.from_dict(data.get("buildings", {}))
	events = EventSystem.new(); events.from_dict(data.get("events", {})); saves = SaveSystem.new()
	blueprints = BlueprintSystemClass.new(); blueprints.setup(buildings); blueprints.from_dict(data.get("blueprints", {}))
	construction_skill = ConstructionSkillClass.new(); construction_skill.from_dict(data.get("construction_skill", {}))
	crafting = CraftingSystemClass.new(); crafting.setup(self)
	survival = SurvivalDirectorClass.new()
	var survival_data: Dictionary = data.get("survival", {})
	if survival_data.is_empty(): survival.reset(random_seed)
	else: survival.from_dict(survival_data)
	if not data.has("blueprints"):
		blueprints.unlock("storage_shelf"); blueprints.unlock("workbench")
	day = int(data.get("day", 1)); phase = str(data.get("phase", PHASE_MORNING)); weather = str(data.get("weather", "晴朗")); exploration_mode = bool(data.get("exploration_mode", true))
	survivors = []
	for row in data.get("survivors", []): survivors.append(Survivor.from_dict(row))
	daily_log = []
	for line in data.get("daily_log", []): daily_log.append(str(line))
	report_lines = []
	for line in data.get("report_lines", []): report_lines.append(str(line))
	key_choices = []
	for line in data.get("key_choices", []): key_choices.append(str(line))
	no_food_days = int(data.get("no_food_days", 0)); safety = int(data.get("safety", 50)); won = bool(data.get("won", false)); end_reason = str(data.get("end_reason", ""))
	house_id = str(data.get("house_id", "starter_hut")); house_level = int(data.get("house_level", 0)); house_fire_lit = bool(data.get("house_fire_lit", false)); built_facilities = []
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
	if audio != null: audio.from_dict(data.get("audio", {}))
	if exploration_world != null: exploration_world.restore_state(world_data)
