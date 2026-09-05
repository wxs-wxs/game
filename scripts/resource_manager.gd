class_name ResourceManager
extends RefCounted

const RESOURCE_KEYS := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal", "water"]
const FISH_KEYS := ["fish_carp", "fish_bass", "fish_trout", "fish_eel"]
const COOKED_FISH_KEYS := ["cooked_fish_carp", "cooked_fish_bass", "cooked_fish_trout", "cooked_fish_eel"]
const CRAFTED_ITEM_KEYS := ["cooked_food", "bandage", "torch", "trap"]
const ITEM_KEYS := RESOURCE_KEYS + FISH_KEYS + COOKED_FISH_KEYS + CRAFTED_ITEM_KEYS
const TOOL_KEYS := ["axe", "pickaxe"]
const BACKPACK_BASE_CAPACITY := 12
## Kept as a read-only compatibility name for older callers. The backpack is
## no longer upgradeable, so both legacy and current saves use 12 slots.
const BACKPACK_UPGRADED_CAPACITY := BACKPACK_BASE_CAPACITY
const STACK_MAX := 999
const FISH_DEFINITIONS := {
	"fish_carp": {"label":"鲤鱼", "cooked_key":"cooked_fish_carp", "cooked_label":"熟鲤鱼", "food":2},
	"fish_bass": {"label":"鲈鱼", "cooked_key":"cooked_fish_bass", "cooked_label":"熟鲈鱼", "food":3},
	"fish_trout": {"label":"鳟鱼", "cooked_key":"cooked_fish_trout", "cooked_label":"熟鳟鱼", "food":4},
	"fish_eel": {"label":"鳗鱼", "cooked_key":"cooked_fish_eel", "cooked_label":"熟鳗鱼", "food":5}
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

var amounts: Dictionary = {"food":12, "wood":10, "medicine":3, "stone":4, "fiber":5, "cloth":2, "metal":2, "water":0, "cooked_food":0, "bandage":0, "torch":0, "trap":0, "fish_carp":0, "fish_bass":0, "fish_trout":0, "fish_eel":0, "cooked_fish_carp":0, "cooked_fish_bass":0, "cooked_fish_trout":0, "cooked_fish_eel":0}
var capacities: Dictionary = {"food":30, "wood":35, "medicine":15, "stone":20, "fiber":25, "cloth":15, "metal":15, "water":30, "cooked_food":30, "bandage":30, "torch":30, "trap":30, "fish_carp":30, "fish_bass":30, "fish_trout":30, "fish_eel":30, "cooked_fish_carp":30, "cooked_fish_bass":30, "cooked_fish_trout":30, "cooked_fish_eel":30}
var total_collected: int = 0
var tools: Dictionary = {"axe": false, "pickaxe": false}
var backpack: Dictionary = {}
var storage: Dictionary = {}
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
		if not ITEM_KEYS.has(item): return false
		var current := int(simulated.get(item, 0))
		if current + amount > STACK_MAX: return false
		if int(amounts.get(item, 0)) + amount > int(capacities.get(item, STACK_MAX)): return false
		if current == 0:
			used += 1
			if used > backpack_slot_capacity(): return false
		simulated[item] = current + amount
	return true

func collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary:
	if rewards.is_empty():
		return {"ok":true, "reason":"没有奖励。", "added":{}}
	if source_id == "camp_task":
		for key in rewards:
			var storage_id := str(key)
			var storage_amount := int(rewards[key])
			if storage_amount <= 0:
				continue
			if not amounts.has(storage_id) or int(amounts.get(storage_id, 0)) + storage_amount > int(capacities.get(storage_id, STACK_MAX)):
				return {"ok":false, "reason":"营地储备空间不足。", "added":{}}
		var stored: Dictionary = {}
		for key in rewards:
			var storage_id := str(key)
			var storage_amount := int(rewards[key])
			if storage_amount <= 0:
				continue
			var actual := add(storage_id, storage_amount)
			if actual != storage_amount:
				return {"ok":false, "reason":"营地奖励存储失败。", "added":{}}
			stored[storage_id] = storage_amount
		return {"ok":true, "reason":"奖励已存入营地。", "added":stored}
	if not can_collect_rewards(rewards):
		return {"ok":false, "reason":"携带空间不足，请先整理背包。", "added":{}}
	for key in rewards:
		var id := str(key)
		if int(rewards[key]) > 0 and not can_collect_from_source(id, source_id):
			return {"ok":false, "reason":"该来源无法提供此奖励。", "added":{}}
	var added: Dictionary = {}
	for key in rewards:
		var id := str(key)
		var amount := int(rewards[key])
		if amount <= 0:
			continue
		var actual := collect_from_source(id, amount, source_id)
		if actual != amount:
			return {"ok":false, "reason":"奖励领取失败。", "added":{}}
		added[id] = amount
	return {"ok":true, "reason":"奖励已领取。", "added":added}

func catch_fish(fish_key: String) -> Dictionary:
	if not FISH_DEFINITIONS.has(fish_key): return {"ok":false, "reason":"未知鱼类。"}
	if not can_carry_item(fish_key, 1): return {"ok":false, "reason":"背包没有空格或该鱼已堆满。"}
	backpack[fish_key] = int(backpack.get(fish_key, 0)) + 1
	amounts[fish_key] = int(amounts.get(fish_key, 0)) + 1
	total_collected += 1
	return {"ok":true, "fish_key":fish_key, "fish_name":fish_name(fish_key), "food_value":fish_food_value(fish_key)}

func fish_name(fish_key: String) -> String:
	return str(FISH_DEFINITIONS.get(fish_key, {}).get("label", fish_key))

func fish_food_value(fish_key: String) -> int:
	return int(FISH_DEFINITIONS.get(fish_key, {}).get("food", 0))

func fish_items() -> Array[String]:
	return FISH_KEYS.duplicate()

func cooked_fish_key(fish_key: String) -> String:
	return str(FISH_DEFINITIONS.get(fish_key, {}).get("cooked_key", ""))

func cooked_fish_name(fish_key: String) -> String:
	return str(FISH_DEFINITIONS.get(fish_key, {}).get("cooked_label", cooked_fish_key(fish_key)))

func _can_replace_with_item(source_key: String, output_key: String) -> bool:
	if int(amounts.get(output_key, 0)) >= int(capacities.get(output_key, STACK_MAX)): return false
	if int(backpack.get(output_key, 0)) > 0: return true
	return backpack_slots_used() - (1 if int(backpack.get(source_key, 0)) == 1 else 0) < backpack_slot_capacity()

func cook_fish(fish_key: String) -> Dictionary:
	var count := int(backpack.get(fish_key, 0))
	if count <= 0: return {"ok":false, "reason":"背包中没有这条鱼。"}
	var output_key := cooked_fish_key(fish_key)
	if output_key.is_empty() or not _can_replace_with_item(fish_key, output_key): return {"ok":false, "reason":"背包没有空间存放熟鱼。"}
	backpack[fish_key] = count - 1
	amounts[fish_key] = maxi(0, int(amounts.get(fish_key, 0)) - 1)
	backpack[output_key] = int(backpack.get(output_key, 0)) + 1
	amounts[output_key] = int(amounts.get(output_key, 0)) + 1
	return {"ok":true, "cooked_key":output_key, "reason":"已将%s烤成熟鱼。" % fish_name(fish_key)}

func cook_berries() -> Dictionary:
	if int(backpack.get("food", 0)) <= 0: return {"ok":false, "reason":"背包中没有浆果。"}
	if not _can_replace_with_item("food", "cooked_food"): return {"ok":false, "reason":"背包没有空间存放熟浆果。"}
	backpack["food"] = int(backpack.get("food", 0)) - 1
	amounts["food"] = maxi(0, int(amounts.get("food", 0)) - 1)
	backpack["cooked_food"] = int(backpack.get("cooked_food", 0)) + 1
	amounts["cooked_food"] = int(amounts.get("cooked_food", 0)) + 1
	return {"ok":true, "cooked_key":"cooked_food", "reason":"已将浆果烤成熟浆果。"}

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

func discard_from_backpack(key: String, amount: int = 1) -> Dictionary:
	var quantity := mini(maxi(0, amount), int(backpack.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":"背包中没有%s。" % display_name(key)}
	backpack[key] = int(backpack.get(key, 0)) - quantity
	if amounts.has(key): amounts[key] = maxi(0, int(amounts.get(key, 0)) - quantity)
	return {"ok":true, "amount":quantity, "reason":"已从背包丢弃%s%d。" % [display_name(key), quantity]}

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
	for fish_key in FISH_KEYS:
		if cooked_fish_key(fish_key) == key: return cooked_fish_name(fish_key)
	return {"food":"浆果","wood":"木材","medicine":"药品","stone":"石料","fiber":"纤维","cloth":"布料","metal":"金属","water":"水","cooked_food":"熟浆果","bandage":"绷带","torch":"火把","trap":"陷阱","axe":"石斧","pickaxe":"石镐"}.get(key, key)

func compact_text() -> String:
	return "浆%d 木%d 药%d 石%d 纤%d 布%d 金%d 水%d" % [get_amount("food"), get_amount("wood"), get_amount("medicine"), get_amount("stone"), get_amount("fiber"), get_amount("cloth"), get_amount("metal"), get_amount("water")]

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
	return {"amounts":amounts, "capacities":capacities, "total_collected":total_collected, "tools":tools, "unlocked_tools":unlocked_tools, "backpack":backpack, "storage":storage, "workbench_available":workbench_available}

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
	backpack_capacity = BACKPACK_BASE_CAPACITY
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
