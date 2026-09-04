class_name CraftingSystem
extends RefCounted

const DATA_PATH := "res://data/recipes.json"
var definitions: Dictionary = {}
var game

func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: definitions = parsed

func setup(manager) -> void:
	game = manager

func available_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in definitions: result.append(definitions[key].duplicate(true))
	return result

func recipe_status(recipe_id: String) -> Dictionary:
	var definition: Dictionary = definitions.get(recipe_id, {})
	if definition.is_empty(): return {"id":recipe_id, "known":false, "can_craft":false, "reason":"未知配方"}
	if not _has_workbench(): return {"id":recipe_id, "known":true, "unlocked":false, "can_craft":false, "reason":"需要简易工作台"}
	var cost: Dictionary = definition.get("cost", {})
	if not game.resources.can_afford(cost): return {"id":recipe_id, "known":true, "unlocked":true, "can_craft":false, "reason":game.resources.missing_cost_text(cost), "cost":cost}
	var output: Dictionary = definition.get("output", {})
	for item in output:
		if not game.resources.can_store_item(str(item), int(output[item])): return {"id":recipe_id, "known":true, "unlocked":true, "can_craft":false, "reason":"背包没有空间存放产出。", "cost":cost}
	return {"id":recipe_id, "known":true, "unlocked":true, "can_craft":true, "reason":"可以制作", "cost":cost, "output":output}

func craft(recipe_id: String) -> Dictionary:
	var status := recipe_status(recipe_id)
	if not bool(status.get("can_craft", false)):
		return {"ok":false, "recipe_id":recipe_id, "reason":str(status.get("reason", "无法制作")), "locked":not bool(status.get("unlocked", false))}
	var definition: Dictionary = definitions[recipe_id]
	var cost: Dictionary = definition.get("cost", {})
	if not game.resources.spend(cost): return {"ok":false, "reason":"材料不足，未扣除任何材料。"}
	for item in definition.get("output", {}):
		var granted: Dictionary = game.resources.grant_item(str(item), int(definition.output[item]))
		if not bool(granted.get("ok", false)):
			# The preflight check makes this unreachable; restore the cost if a
			# custom ResourceManager changes between checks.
			for key in cost: game.resources.add(str(key), int(cost[key]))
			return {"ok":false, "reason":str(granted.get("reason", "产出空间不足。"))}
	var result := {"ok":true, "recipe_id":recipe_id, "reason":"制作了%s。" % str(definition.get("name", recipe_id))}
	if game != null and game.has_method("record_survival_action"): game.record_survival_action("craft:" + recipe_id)
	if game != null and game.daily_log != null: game.daily_log.append(result.reason)
	return result

func use_item(item_id: String) -> Dictionary:
	if game == null or game.resources == null: return {"ok":false, "reason":"制作系统未就绪。"}
	var hero: Survivor = game.get_protagonist()
	if item_id == "bandage" and (hero == null or (not hero.injured and hero.health >= 100)):
		return {"ok":false, "reason":"当前没有受伤，绷带未消耗。"}
	if not _consume_item(item_id): return {"ok":false, "reason":"没有%s可使用。" % game.resources.display_name(item_id)}
	var message := ""
	match item_id:
		"cooked_food":
			if hero == null: return {"ok":false, "reason":"没有可用角色。"}
			hero.apply_change("hunger", 25); hero.apply_change("morale", 2); message = "食用了熟食，饥饿 +25，士气 +2。"
		"bandage":
			if hero == null: return {"ok":false, "reason":"没有可用角色。"}
			hero.apply_change("health", 20); hero.injured = false; message = "使用绷带，生命 +20，伤势已处理。"
		"torch":
			game.torch_bonus_pending = true; message = "点燃火把，下一次废墟搜寻失败率降低 20%。"
		"trap":
			game.deployed_traps = int(game.deployed_traps) + 1; message = "陷阱已部署，下一次野兽夜袭伤害降低 5。"
		_:
			_add_item_back(item_id); return {"ok":false, "reason":"该物品无法使用。"}
	if game.daily_log != null: game.daily_log.append(message)
	return {"ok":true, "reason":message, "item_id":item_id}

func _consume_item(item_id: String) -> bool:
	var resources: ResourceManager = game.resources
	if int(resources.backpack.get(item_id, 0)) > 0:
		resources.backpack[item_id] -= 1; resources.amounts[item_id] = maxi(0, int(resources.amounts.get(item_id, 0)) - 1); return true
	if int(resources.storage.get(item_id, 0)) > 0:
		resources.storage[item_id] -= 1; resources.amounts[item_id] = maxi(0, int(resources.amounts.get(item_id, 0)) - 1); return true
	return false

func _add_item_back(item_id: String) -> void:
	game.resources.backpack[item_id] = int(game.resources.backpack.get(item_id, 0)) + 1
	game.resources.amounts[item_id] = int(game.resources.amounts.get(item_id, 0)) + 1

func _has_workbench() -> bool:
	return game != null and game.buildings != null and game.buildings.has_workbench()
