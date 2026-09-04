class_name ResourceManager
extends RefCounted

const RESOURCE_KEYS := ["food", "wood", "medicine", "fuel", "scrap", "stone", "fiber", "cloth", "metal", "water"]
const FISH_KEYS := ["fish_carp", "fish_bass", "fish_trout", "fish_eel"]
const CRAFTED_ITEM_KEYS := ["cooked_food", "bandage", "torch", "trap"]
const ITEM_KEYS := RESOURCE_KEYS + FISH_KEYS + CRAFTED_ITEM_KEYS
const TOOL_KEYS := ["axe", "pickaxe"]
const BACKPACK_BASE_CAPACITY := 4
const BACKPACK_UPGRADED_CAPACITY := 12
const STACK_MAX := 999
const BACKPACK_COST := {"cloth": 2, "fiber": 4, "scrap": 2}
const FISH_DEFINITIONS := {
	"fish_carp": {"label":"鲤鱼", "food":2},
	"fish_bass": {"label":"鲈鱼", "food":3},
	"fish_trout": {"label":"鳟鱼", "food":4},
	"fish_eel": {"label":"鳗鱼", "food":5}
}
const TOOL_DEFINITIONS := {
	"axe": {
		"id": "axe",
		"label": "石斧",
		"cost": {"stone": 2, "wood": 3},
		"description": "砍伐森林中的树木，获得稳定木材。"
	},
	"pickaxe": {
		"id": "pickaxe",
		"label": "石镐",
		"cost": {"stone": 3, "wood": 2},
		"description": "开采地图上的石堆，获得更多石料。"
	}
}

# Resource acquisition is intentionally source-aware for exploration rewards.
# Direct add() remains available to the camp simulation and old integrations,
# while interaction points use add_from_source() to keep the field economy
# legible (stone comes from field pebbles and pickaxe-mined rock piles; wood
# comes from branches, berries, and trees).
const SOURCE_RULES := {
	"stone": ["field_pebble", "pebble", "rock_pile"],
	"wood": ["field_branch", "branch", "forest_berries", "forest_tree"]
}

var amounts: Dictionary = {"food":12, "wood":10, "medicine":3, "fuel":8, "scrap":6, "stone":4, "fiber":5, "cloth":2, "metal":2, "water":0, "cooked_food":0, "bandage":0, "torch":0, "trap":0}
var capacities: Dictionary = {"food":30, "wood":35, "medicine":15, "fuel":25, "scrap":30, "stone":20, "fiber":25, "cloth":15, "metal":15, "water":30, "cooked_food":30, "bandage":30, "torch":30, "trap":30}
var total_collected: int = 0
var tools: Dictionary = {"axe": false, "pickaxe": false}
var backpack: Dictionary = {}
var storage: Dictionary = {}
var backpack_owned := false
var backpack_capacity := BACKPACK_BASE_CAPACITY
## Standalone ResourceManager callers remain backwards compatible. GameManager
## explicitly disables this until its canonical workbench is completed.
var workbench_available := true

# Property-style compatibility for lightweight callers that prefer
# `resources.axe` over the explicit has_axe() method.
var axe: bool:
	get:
		return bool(tools.get("axe", false))
	set(value):
		tools["axe"] = value

var pickaxe: bool:
	get:
		return bool(tools.get("pickaxe", false))
	set(value):
		tools["pickaxe"] = value

# Recipes are known from the start. Keeping this separate from ownership gives
# the UI and future progression systems a stable unlock/craft API without
# making old saves or the first crafting action depend on a missing workbench.
var unlocked_tools: Array[String] = ["axe", "pickaxe"]

func _init() -> void:
	for key in ITEM_KEYS:
		backpack[key] = 0
		storage[key] = int(amounts.get(key, 0)) if key in RESOURCE_KEYS else 0

func get_amount(key: String) -> int:
	return int(amounts.get(key, 0))

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if get_amount(str(key)) < int(cost[key]):
			return false
	return true

func missing_cost_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for key in cost:
		var gap := int(cost[key]) - get_amount(str(key))
		if gap > 0: missing.append("%s-%d" % [display_name(str(key)), gap])
	return "资源不足：" + " ".join(missing)

func add(key: String, delta: int) -> int:
	if not amounts.has(key): return 0
	if delta < 0:
		return _remove_resource(key, -delta)
	var before := int(amounts[key])
	amounts[key] = clampi(before + delta, 0, int(capacities[key]))
	var actual := int(amounts[key]) - before
	if actual > 0:
		storage[key] = int(storage.get(key, 0)) + actual
		total_collected += actual
	return actual

func set_workbench_available(value: bool) -> void:
	workbench_available = value

func can_store_item(key: String, amount: int = 1) -> bool:
	return can_carry_item(key, amount)

func grant_item(key: String, amount: int = 1) -> Dictionary:
	var id := str(key)
	var quantity := maxi(0, amount)
	if quantity <= 0: return {"ok":false, "reason":"产出数量无效。"}
	if not ITEM_KEYS.has(id) or int(amounts.get(id, 0)) + quantity > int(capacities.get(id, STACK_MAX)) or not can_carry_item(id, quantity):
		return {"ok":false, "reason":"背包没有空间存放%s。" % display_name(id)}
	backpack[id] = int(backpack.get(id, 0)) + quantity
	amounts[id] = int(amounts.get(id, 0)) + quantity
	return {"ok":true, "amount":quantity}

func can_collect_from_source(key: String, source_id: String) -> bool:
	# Empty source IDs are used by legacy/camp systems and remain unrestricted.
	if source_id.is_empty() or not SOURCE_RULES.has(key): return true
	var normalized := source_id.to_lower()
	for allowed_variant in SOURCE_RULES[key]:
		if normalized.begins_with(str(allowed_variant).to_lower()): return true
	return false

func add_from_source(key: String, delta: int, source_id: String = "") -> int:
	if not can_collect_from_source(key, source_id): return 0
	return add(key, delta)

func can_carry(amount: int) -> bool:
	return carried_count() + maxi(0, amount) <= STACK_MAX * backpack_slot_capacity()

func backpack_slot_capacity() -> int:
	return backpack_capacity

func backpack_slots_used() -> int:
	var slots := 0
	for key in ITEM_KEYS:
		if int(backpack.get(key, 0)) > 0: slots += 1
	return slots

func can_carry_item(key: String, amount: int = 1) -> bool:
	if amount <= 0: return true
	var current := int(backpack.get(key, 0))
	if current + amount > STACK_MAX: return false
	if current > 0: return true
	return backpack_slots_used() < backpack_slot_capacity()

func carried_count() -> int:
	var total := 0
	for key in ITEM_KEYS: total += int(backpack.get(key, 0))
	return total

func collect_from_source(key: String, delta: int, source_id: String = "") -> int:
	if delta <= 0 or not amounts.has(key) or not can_collect_from_source(key, source_id): return 0
	if not can_carry_item(key, delta): return 0
	var before := int(amounts[key])
	amounts[key] = clampi(before + delta, 0, int(capacities[key]))
	var actual := int(amounts[key]) - before
	if actual > 0:
		backpack[key] = int(backpack.get(key, 0)) + actual
		total_collected += actual
	return actual

func can_collect_rewards(rewards: Dictionary) -> bool:
	var simulated := backpack.duplicate()
	var used := backpack_slots_used()
	for key in rewards:
		var item := str(key)
		var amount := maxi(0, int(rewards[key]))
		if amount == 0: continue
		var current := int(simulated.get(item, 0))
		if current + amount > STACK_MAX: return false
		if current == 0:
			used += 1
			if used > backpack_slot_capacity(): return false
		simulated[item] = current + amount
	return true

func catch_fish(fish_key: String) -> Dictionary:
	if not FISH_DEFINITIONS.has(fish_key): return {"ok":false, "reason":"未知鱼类。"}
	if not can_carry_item(fish_key, 1): return {"ok":false, "reason":"背包没有空格或该鱼已堆满。"}
	backpack[fish_key] = int(backpack.get(fish_key, 0)) + 1
	return {"ok":true, "fish_key":fish_key, "fish_name":fish_name(fish_key), "food_value":fish_food_value(fish_key)}

func fish_name(fish_key: String) -> String:
	return str(FISH_DEFINITIONS.get(fish_key, {}).get("label", fish_key))

func fish_food_value(fish_key: String) -> int:
	return int(FISH_DEFINITIONS.get(fish_key, {}).get("food", 0))

func fish_items() -> Array[String]:
	return FISH_KEYS.duplicate()

func convert_fish_to_food(fish_key: String) -> Dictionary:
	var count := int(backpack.get(fish_key, 0))
	if count <= 0: return {"ok":false, "reason":"背包中没有这条鱼。"}
	var food_amount := fish_food_value(fish_key)
	var food_capacity := int(capacities.get("food", 0))
	var current_food := int(backpack.get("food", 0))
	var food_stack_ok := current_food + food_amount <= STACK_MAX
	var food_slot_ok := current_food > 0 or (backpack_slots_used() - (1 if count == 1 else 0)) < backpack_slot_capacity()
	if int(amounts.get("food", 0)) >= food_capacity or not food_stack_ok or not food_slot_ok:
		return {"ok":false, "reason":"背包没有空间存放处理后的食物。"}
	backpack[fish_key] = count - 1
	var before := int(amounts.get("food", 0))
	amounts["food"] = clampi(before + food_amount, 0, int(capacities.get("food", 0)))
	var actual := int(amounts["food"]) - before
	backpack["food"] = int(backpack.get("food", 0)) + actual
	return {"ok":true, "food":actual, "reason":"已将%s处理成食物 +%d。" % [fish_name(fish_key), actual]}

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost): return false
	for key in cost: add(str(key), -int(cost[key]))
	return true

func _remove_resource(key: String, amount: int) -> int:
	var remaining := mini(amount, int(amounts.get(key, 0)))
	var from_storage := mini(remaining, int(storage.get(key, 0)))
	storage[key] = int(storage.get(key, 0)) - from_storage
	remaining -= from_storage
	if remaining > 0:
		var from_backpack := mini(remaining, int(backpack.get(key, 0)))
		backpack[key] = int(backpack.get(key, 0)) - from_backpack
		remaining -= from_backpack
	var removed := mini(amount, int(amounts.get(key, 0))) - remaining
	amounts[key] = int(amounts.get(key, 0)) - removed
	return removed

func has_backpack() -> bool:
	return backpack_owned

func craft_backpack() -> Dictionary:
	if backpack_owned:
		return {"ok":false, "already_owned":true, "reason":"已经拥有背包。"}
	if not can_afford(BACKPACK_COST):
		return {"ok":false, "reason":missing_cost_text(BACKPACK_COST), "missing":missing_cost(BACKPACK_COST)}
	spend(BACKPACK_COST)
	backpack_owned = true
	backpack_capacity = BACKPACK_UPGRADED_CAPACITY
	return {"ok":true, "reason":"制作了背包，携带容量提升至 %d。" % backpack_capacity}

func move_to_backpack(key: String, amount: int = 1) -> Dictionary:
	var quantity := mini(maxi(0, amount), int(storage.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":"储物架中没有%s。" % display_name(key)}
	if not can_carry_item(key, quantity): return {"ok":false, "reason":"背包已满或该物品堆叠达到 %d。" % STACK_MAX}
	storage[key] = int(storage.get(key, 0)) - quantity
	backpack[key] = int(backpack.get(key, 0)) + quantity
	return {"ok":true, "amount":quantity, "reason":"已将 %s%d 放入背包。" % [display_name(key), quantity]}

func move_to_storage(key: String, amount: int = 1) -> Dictionary:
	var quantity := mini(maxi(0, amount), int(backpack.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":"背包中没有%s。" % display_name(key)}
	backpack[key] = int(backpack.get(key, 0)) - quantity
	storage[key] = int(storage.get(key, 0)) + quantity
	return {"ok":true, "amount":quantity, "reason":"已将 %s%d 放回储物架。" % [display_name(key), quantity]}

func discard_from_storage(key: String, amount: int = 1) -> Dictionary:
	var quantity := mini(maxi(0, amount), int(storage.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":"储物架中没有%s。" % display_name(key)}
	storage[key] = int(storage.get(key, 0)) - quantity
	if amounts.has(key): amounts[key] = maxi(0, int(amounts.get(key, 0)) - quantity)
	return {"ok":true, "amount":quantity, "reason":"已丢弃%s%d。" % [display_name(key), quantity]}

func backpack_text() -> String:
	var rows: Array[String] = []
	for key in ITEM_KEYS:
		var amount := int(backpack.get(key, 0))
		if amount > 0: rows.append("%s%d" % [display_name(key), amount] if not key.begins_with("fish_") else "%s%d" % [fish_name(key), amount])
	return "、".join(rows) if not rows.is_empty() else "空"

func add_capacity_all(amount: int) -> void:
	for key in capacities: capacities[key] = int(capacities[key]) + amount

func display_name(key: String) -> String:
	if FISH_DEFINITIONS.has(key): return fish_name(key)
	return {"food":"食物","wood":"木材","medicine":"药品","fuel":"燃料","scrap":"废料","stone":"石料","fiber":"纤维","cloth":"布料","metal":"金属","water":"水","cooked_food":"熟食","bandage":"绷带","torch":"火把","trap":"陷阱","axe":"石斧","pickaxe":"石镐"}.get(key, key)

func compact_text() -> String:
	return "食%d 木%d 药%d 燃%d 废%d 石%d 纤%d 布%d 金%d 水%d" % [get_amount("food"), get_amount("wood"), get_amount("medicine"), get_amount("fuel"), get_amount("scrap"), get_amount("stone"), get_amount("fiber"), get_amount("cloth"), get_amount("metal"), get_amount("water")]

func tool_definition(tool_id: String) -> Dictionary:
	var definition = TOOL_DEFINITIONS.get(tool_id, {})
	return definition.duplicate(true) if definition is Dictionary else {}

func tool_display_name(tool_id: String) -> String:
	return str(tool_definition(tool_id).get("label", tool_id))

func is_tool_unlocked(tool_id: String) -> bool:
	return tool_id in unlocked_tools and TOOL_DEFINITIONS.has(tool_id)

func is_axe_unlocked() -> bool:
	return is_tool_unlocked("axe")

func unlock_tool(tool_id: String) -> Dictionary:
	if not TOOL_DEFINITIONS.has(tool_id):
		return {"ok":false, "reason":"未知工具：%s" % tool_id, "tool_id":tool_id}
	if is_tool_unlocked(tool_id):
		return {"ok":true, "already_unlocked":true, "reason":"已解锁%s配方。" % tool_display_name(tool_id), "tool_id":tool_id}
	unlocked_tools.append(tool_id)
	return {"ok":true, "unlocked":true, "reason":"已解锁%s配方。" % tool_display_name(tool_id), "tool_id":tool_id}

func unlock_axe() -> Dictionary:
	return unlock_tool("axe")

func has_tool(tool_id: String) -> bool:
	return bool(tools.get(tool_id, false))

func has_axe() -> bool:
	return has_tool("axe")

func has_pickaxe() -> bool:
	return has_tool("pickaxe")

func is_axe_owned() -> bool:
	return has_axe()

func can_craft_tool(tool_id: String) -> bool:
	if not workbench_available: return false
	if not TOOL_DEFINITIONS.has(tool_id) or has_tool(tool_id) or not is_tool_unlocked(tool_id): return false
	return can_afford(tool_definition(tool_id).get("cost", {}))

func can_craft_axe() -> bool:
	return can_craft_tool("axe")

func can_craft_pickaxe() -> bool:
	return can_craft_tool("pickaxe")

func tool_status(tool_id: String) -> Dictionary:
	var definition := tool_definition(tool_id)
	if definition.is_empty():
		return {"id":tool_id, "label":tool_id, "known":false, "unlocked":false, "owned":false, "can_craft":false, "cost":{}}
	return {
		"id":tool_id,
		"label":tool_display_name(tool_id),
		"known":true,
		"unlocked":is_tool_unlocked(tool_id),
		"owned":has_tool(tool_id),
		"can_craft":can_craft_tool(tool_id),
		"cost":definition.get("cost", {}).duplicate(true)
	}

func axe_status() -> Dictionary:
	return tool_status("axe")

func pickaxe_status() -> Dictionary:
	return tool_status("pickaxe")

func craft_tool(tool_id: String) -> Dictionary:
	if not TOOL_DEFINITIONS.has(tool_id):
		return {"ok":false, "reason":"未知工具：%s" % tool_id, "tool_id":tool_id}
	var label := tool_display_name(tool_id)
	if has_tool(tool_id):
		return {"ok":false, "already_owned":true, "reason":"已经拥有%s。" % label, "tool_id":tool_id}
	if not workbench_available:
		return {"ok":false, "locked":true, "reason":"需要简易工作台才能制作%s。" % label, "tool_id":tool_id}
	if not is_tool_unlocked(tool_id):
		return {"ok":false, "locked":true, "reason":"尚未解锁%s配方。" % label, "tool_id":tool_id}
	var definition := tool_definition(tool_id)
	var cost: Dictionary = definition.get("cost", {})
	if not can_afford(cost):
		return {"ok":false, "reason":missing_cost_text(cost), "missing":missing_cost(cost), "tool_id":tool_id}
	spend(cost)
	tools[tool_id] = true
	return {"ok":true, "crafted":true, "tool_id":tool_id, "reason":"制作了%s。" % label, "message":"制作了%s。" % label}

func craft_axe() -> Dictionary:
	return craft_tool("axe")

func craft_pickaxe() -> Dictionary:
	return craft_tool("pickaxe")

func missing_cost(cost: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for key in cost:
		var gap := int(cost[key]) - get_amount(str(key))
		if gap > 0: missing[str(key)] = gap
	return missing

func tools_text() -> String:
	var owned: Array[String] = []
	for tool_id in TOOL_KEYS:
		if has_tool(tool_id): owned.append(tool_display_name(tool_id))
	return "工具：" + ("、".join(owned) if not owned.is_empty() else "无")

func to_dict() -> Dictionary:
	return {"amounts":amounts, "capacities":capacities, "total_collected":total_collected, "tools":tools, "unlocked_tools":unlocked_tools, "backpack":backpack, "storage":storage, "backpack_owned":backpack_owned, "backpack_capacity":backpack_capacity, "workbench_available":workbench_available}

func from_dict(data: Dictionary) -> void:
	var old_amounts: Dictionary = data.get("amounts", {})
	var old_capacities: Dictionary = data.get("capacities", {})
	for key in ITEM_KEYS:
		if old_amounts.has(key): amounts[key] = maxi(0, int(old_amounts[key]))
		if old_capacities.has(key): capacities[key] = maxi(1, int(old_capacities[key]))
	backpack = {}
	storage = {}
	var saved_backpack = data.get("backpack", {})
	var saved_storage = data.get("storage", {})
	for key in ITEM_KEYS:
		backpack[key] = maxi(0, int(saved_backpack.get(key, 0))) if saved_backpack is Dictionary else 0
		var default_storage := int(amounts.get(key, 0)) if key in RESOURCE_KEYS else 0
		storage[key] = maxi(0, int(saved_storage.get(key, default_storage))) if saved_storage is Dictionary else default_storage
	backpack_owned = bool(data.get("backpack_owned", false))
	backpack_capacity = BACKPACK_UPGRADED_CAPACITY if backpack_owned else BACKPACK_BASE_CAPACITY
	if data.has("backpack_capacity"): backpack_capacity = maxi(BACKPACK_BASE_CAPACITY, int(data.get("backpack_capacity", backpack_capacity)))
	workbench_available = bool(data.get("workbench_available", true))
	total_collected = int(data.get("total_collected", 0))
	# Old saves do not contain tool fields, so they cleanly start without tools
	# while retaining the now-known axe and pickaxe recipes.
	tools = {"axe": false, "pickaxe": false}
	var saved_tools = data.get("tools", {})
	if saved_tools is Dictionary:
		for tool_id in TOOL_KEYS:
			if saved_tools.has(tool_id): tools[tool_id] = bool(saved_tools[tool_id])
	# Accept the compact legacy/experimental flag used by early prototypes.
	if bool(data.get("axe_crafted", false)) or bool(data.get("has_axe", false)) or bool(data.get("axe", false)):
		tools["axe"] = true
	unlocked_tools = ["axe", "pickaxe"]
	var saved_unlocked = data.get("unlocked_tools", null)
	if saved_unlocked is Array:
		unlocked_tools = []
		for tool_id in saved_unlocked:
			var id := str(tool_id)
			if TOOL_DEFINITIONS.has(id) and id not in unlocked_tools: unlocked_tools.append(id)
		# A malformed/legacy list should not strand a player without either
		# explicitly supported gathering recipe.
		if "axe" not in unlocked_tools: unlocked_tools.append("axe")
		if "pickaxe" not in unlocked_tools: unlocked_tools.append("pickaxe")
