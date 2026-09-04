class_name EventSystem
extends RefCounted

var definitions: Dictionary = {}
var current_event: Dictionary = {}

func _init() -> void:
	definitions = _load_json("res://data/events.json")

func create_event(rng: RandomNumberGenerator) -> Dictionary:
	return create_weighted_event(rng, {})

func event_weight(event_id: String, context: Dictionary) -> int:
	var definition: Dictionary = definitions.get(event_id, {})
	var weight := int(definition.get("base_weight", 10))
	var weather_bonus: Dictionary = definition.get("weather_bonus", {})
	weight += int(weather_bonus.get(str(context.get("weather", "")), 0))
	weight += int(round(float(definition.get("threat_bonus", 0)) * float(context.get("threat", 0)) / 100.0))
	var facility_bonus: Dictionary = definition.get("facility_bonus", {})
	for facility_id in context.get("built_facilities", []):
		weight += int(facility_bonus.get(str(facility_id), 0))
	return maxi(0, weight)

func create_weighted_event(random: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total := 0
	var keys: Array = definitions.keys(); keys.sort()
	for key in keys:
		var event_id := str(key)
		var weight := event_weight(event_id, context)
		if weight <= 0: continue
		candidates.append({"id": event_id, "weight": weight}); total += weight
	if candidates.is_empty() or total <= 0:
		current_event = {}; return {}
	var roll := random.randi_range(1, total)
	for candidate in candidates:
		roll -= int(candidate["weight"])
		if roll <= 0:
			var selected_id := str(candidate["id"])
			current_event = {"id": selected_id, "data": definitions[selected_id]}
			return current_event
	return {}

func choice_cost(index: int) -> Dictionary:
	if current_event.is_empty(): return {}
	var choices: Array = current_event.data.choices
	if index < 0 or index >= choices.size(): return {}
	return choices[index].get("cost", {})

func resolve_choice(index: int, game) -> Array[String]:
	if current_event.is_empty() or index < 0: return []
	var choices: Array = current_event.get("data", {}).get("choices", [])
	if index >= choices.size(): return []
	var choice: Dictionary = choices[index]
	var cost: Dictionary = choice.get("cost", {})
	if not game.resources.can_afford(cost): return ["资源不足，无法执行该选择。"]
	if not game.resources.spend(cost): return ["资源扣除失败，选择未执行。"]
	var results: Array[String] = _apply_choice_effect(index, game)
	if results.is_empty():
		for key in cost: game.resources.add(str(key), int(cost[key]))
		return ["事件选择无效，资源已退回。"]
	game.key_choices.append(str(current_event.data.title) + "：" + str(choice.label))
	current_event = {}
	return results

func _apply_choice_effect(index: int, game) -> Array[String]:
	var results: Array[String] = []
	var choice: Dictionary = current_event.data.choices[index]
	var choice_id := str(choice.id)
	match str(current_event.id):
		"rain":
			if choice_id == "reinforce": results.append("帐篷撑过了暴雨，只有少数补给受潮。")
			else:
				game.change_all("energy", -3); results.append("火光守住了体温，但大家一夜未眠。")
		"cold":
			if choice_id == "burn":
				game.change_all("morale", 4); results.append("火焰压住了寒气，营地重新安静下来。")
			else:
				game.change_all("energy", -7); results.append("大家靠在一起熬过寒夜，疲惫写在脸上。")
		"beast":
			var protection: int = game.buildings.attack_protection()
			if int(game.deployed_traps) > 0:
				game.deployed_traps -= 1
				protection += 5
				results.append("营地陷阱被触发，野兽退去。")
			if choice_id == "alarm": protection += 3
			if protection >= 4:
				results.append("野兽被火与动静驱走，营地没有伤亡。")
			else:
				var victim: Survivor = game.random_alive()
				if victim != null:
					victim.apply_change("health", -(8 - protection)); victim.injured = true
					results.append("混乱中 %s 受了伤。" % victim.display_name)
		"wanderer":
			if choice_id == "welcome":
				if game.survivors.size() < 5:
					game.add_wanderer(); game.change_all("morale", 3); results.append("流浪者醒来后加入了营地。")
				else: results.append("营地已没有空位，陌生人带着食物离开。")
			else:
				game.change_all("morale", -1); results.append("陌生人恢复了些力气，向北方慢慢离开。")
		"spoilage":
			if choice_id == "sort":
				game.resources.add("food", 3); results.append("仔细分拣后，仍救下了一些干粮。")
			else: results.append("腐坏的食物被清理干净，病菌没有扩散。")
		"argument":
			if choice_id == "mediate":
				game.change_all("morale", 3); game.adjust_relation("trust", 2); results.append("争吵被压了下来，彼此愿意再听一遍。")
			else:
				game.change_all("morale", 6); game.adjust_relation("inspire", 1); results.append("热食让怒气消散，营地重新有了笑声。")
		"cache":
			if choice_id == "salvage":
				game.resources.add("scrap", 6); game.resources.add("medicine", 1)
				if game.rng.randf() < 0.35:
					var victim: Survivor = game.random_alive()
					if victim != null: victim.apply_change("health", -5); victim.injured = true
				results.append("补给车里还有可用物资，搜寻的人带着擦伤回来。")
			else:
				game.resources.add("scrap", 2); results.append("位置已经标记，明天可以带足工具再去。")
	return results

func to_dict() -> Dictionary: return {"current_event":current_event}
func from_dict(data: Dictionary) -> void:
	current_event = data.get("current_event", {})
	if not current_event is Dictionary:
		current_event = {}
		return
	var event_id := str(current_event.get("id", ""))
	if definitions.has(event_id): current_event = {"id":event_id, "data":definitions[event_id]}
	elif not current_event.is_empty(): current_event = {}

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
