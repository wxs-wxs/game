class_name TaskSystem
extends RefCounted

var work_data: Dictionary = {}

func _init() -> void:
	work_data = _load_json("res://data/tasks.json")

func assign(survivor: Survivor, work_name: String) -> bool:
	if not survivor.alive or not work_data.has(work_name): return false
	survivor.current_work = work_name
	return true

func resolve_tick(survivors: Array, resources: ResourceManager, buildings: BuildingSystem, weather: String, rng: RandomNumberGenerator) -> Array[String]:
	var lines: Array[String] = []
	var guard_power := 0
	for survivor in survivors:
		if not survivor.alive: continue
		var work := str(survivor.current_work)
		var data: Dictionary = work_data.get(work, {})
		if data.is_empty(): continue
		var fatigue: int = int(data.get("fatigue", 0)) + maxi(0, survivor.same_work_days - 1)
		if survivor.energy < 20 and fatigue > 0: fatigue += 2
		survivor.apply_change("energy", -fatigue)
		survivor.apply_change("morale", -int(data.get("morale", 0)) - (1 if survivor.same_work_days >= 3 else 0))
		match str(data.get("id", "")):
			"food":
				var food_gain := 1 + int(ceil(float(survivor.skill_value("gather")) * 0.65))
				if weather == "暴雨": food_gain = max(1, food_gain - 1)
				food_gain += rng.randi_range(0, 1)
				resources.add("food", food_gain); survivor.add_xp("gather", 1)
				lines.append("%s 找回 %d 食物" % [survivor.display_name, food_gain])
			"wood":
				var wood_gain: int = 1 + survivor.skill_value("gather")
				if weather == "暴雨": wood_gain = max(1, wood_gain - 1)
				resources.add("wood", wood_gain); survivor.add_xp("gather", 1)
				lines.append("%s 收集 %d 木材" % [survivor.display_name, wood_gain])
			"scrap":
				var scrap_gain := 1 + int(ceil(float(survivor.skill_value("gather")) * 0.55))
				resources.add("scrap", scrap_gain)
				if rng.randf() < 0.18: resources.add("medicine", 1)
				survivor.add_xp("gather", 1)
				lines.append("%s 回收 %d 废料" % [survivor.display_name, scrap_gain])
			"build":
				var built := buildings.add_work(survivor.skill_value("build"))
				if built != "": lines.append("%s 完成 %s" % [survivor.display_name, built])
				survivor.add_xp("build", 1)
			"heal":
				var target := _find_patient(survivors)
				if target != null and resources.get_amount("medicine") > 0:
					resources.add("medicine", -1)
					var heal: int = 2 + survivor.skill_value("medical") + buildings.clinic_bonus()
					target.apply_change("health", heal)
					target.injured = target.health < 88
					target.sick = target.health < 72 and target.sick
					survivor.add_xp("medical", 1)
					lines.append("%s 治疗 %s" % [survivor.display_name, target.display_name])
			"rest":
				var rest := 6 + buildings.rest_bonus()
				survivor.apply_change("energy", rest)
				survivor.apply_change("morale", 2)
			"guard":
				guard_power += 1 + int(survivor.morale / 40)
		buildings.guard_power = guard_power
	return lines

func begin_day(survivors: Array) -> void:
	for survivor in survivors:
		if survivor.alive: survivor.next_day_work_streak()

func _find_patient(survivors: Array) -> Survivor:
	var target: Survivor = null
	for survivor in survivors:
		if survivor.alive and (survivor.injured or survivor.sick or survivor.health < 70):
			if target == null or survivor.health < target.health: target = survivor
	return target

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
