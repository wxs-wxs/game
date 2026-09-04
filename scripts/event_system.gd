class_name EventSystem
extends RefCounted

var definitions: Dictionary = {}
var current_event: Dictionary = {}

func _init() -> void:
	definitions = _load_json("res://data/events.json")

func create_event(rng: RandomNumberGenerator) -> Dictionary:
	var keys: Array = definitions.keys()
	keys.sort()
	var event_id := str(keys[rng.randi_range(0, keys.size() - 1)])
	current_event = {"id":event_id, "data":definitions[event_id]}
	return current_event

func choice_cost(index: int) -> Dictionary:
	if current_event.is_empty(): return {}
	var choices: Array = current_event.data.choices
	if index < 0 or index >= choices.size(): return {}
	return choices[index].get("cost", {})

func resolve_choice(index: int, game) -> Array[String]:
	var results: Array[String] = []
	if current_event.is_empty(): return results
	var choices: Array = current_event.data.choices
	if index < 0 or index >= choices.size(): return results
	var choice: Dictionary = choices[index]
	var cost: Dictionary = choice.get("cost", {})
	if not game.resources.spend(cost): return ["资源不足，无法执行该选择。"]
	var choice_id := str(choice.id)
	game.key_choices.append(str(current_event.data.title) + "：" + str(choice.label))
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
	current_event = {}
	return results

func to_dict() -> Dictionary: return {"current_event":current_event}
func from_dict(data: Dictionary) -> void: current_event = data.get("current_event", {})

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
