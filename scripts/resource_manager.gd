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

## Domain services are exposed for newer callers while the dictionaries below
## remain live aliases for the legacy ResourceManager API.
var catalog: ResourceCatalog
var ledger: ResourceLedger
var inventory_state: InventoryState
var _amounts_alias: Dictionary = {}
var _capacities_alias: Dictionary = {}
var _backpack_alias: Dictionary = {}
var _storage_alias: Dictionary = {}
var amounts: Dictionary:
	get:
		return ledger.amounts if ledger != null else _amounts_alias
	set(value):
		_amounts_alias = value
		if ledger != null: ledger.amounts = value
var capacities: Dictionary:
	get:
		return ledger.capacities if ledger != null else _capacities_alias
	set(value):
		_capacities_alias = value
		if ledger != null: ledger.capacities = value
var total_collected: int:
	get:
		return ledger.total_collected if ledger != null else 0
	set(value):
		if ledger != null: ledger.total_collected = value
var tool_state: Dictionary = {"axe": false, "pickaxe": false}
var tools: Dictionary
var backpack: Dictionary:
	get:
		return inventory_state.backpack if inventory_state != null else _backpack_alias
	set(value):
		_backpack_alias = value
		if inventory_state != null: inventory_state.backpack = value
var storage: Dictionary:
	get:
		return inventory_state.storage if inventory_state != null else _storage_alias
	set(value):
		_storage_alias = value
		if inventory_state != null: inventory_state.storage = value
var backpack_capacity: int:
	get:
		return inventory_state.backpack_capacity if inventory_state != null else BACKPACK_BASE_CAPACITY
	set(value):
		if inventory_state != null: inventory_state.backpack_capacity = value
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
	catalog = ResourceCatalog.new()
	inventory_state = InventoryState.new(catalog)
	ledger = ResourceLedger.new(catalog, inventory_state)
	_bind_state_aliases()
	for key in ITEM_KEYS:
		storage[key] = int(amounts.get(key, 0)) if key in RESOURCE_KEYS else 0

func _bind_state_aliases() -> void:
	amounts = ledger.amounts
	capacities = ledger.capacities
	backpack = inventory_state.backpack
	storage = inventory_state.storage
	tools = tool_state

func get_amount(key: String) -> int:
	return ledger.get_amount(key)

func can_afford(cost: Dictionary) -> bool:
	return ledger.can_afford(cost)

func missing_cost_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for key in cost:
		var gap := int(cost[key]) - get_amount(str(key))
		if gap > 0: missing.append("%s-%d" % [display_name(str(key)), gap])
	return "资源不足：" + " ".join(missing)

func add(key: String, delta: int) -> int:
	return ledger.add(key, delta)

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
	return ledger._source_allowed(key, source_id)

func add_from_source(key: String, delta: int, source_id: String = "") -> int:
	if not can_collect_from_source(key, source_id): return 0
	return ledger.add(key, delta)

func can_carry(amount: int) -> bool:
	return carried_count() + maxi(0, amount) <= STACK_MAX * inventory_state.backpack_capacity

func backpack_slot_capacity() -> int:
	return backpack_capacity

func backpack_slots_used() -> int:
	return inventory_state.backpack_slots_used()

func can_carry_item(key: String, amount: int = 1) -> bool:
	return inventory_state.can_carry_item(key, amount)

func carried_count() -> int:
	var total := 0
	for key in ITEM_KEYS: total += int(inventory_state.backpack.get(key, 0))
	return total

func collect_from_source(key: String, delta: int, source_id: String = "") -> int:
	if delta <= 0 or not can_collect_from_source(key, source_id): return 0
	var result := ledger.collect_from_source(key, delta, source_id)
	return int(result.get("added", {}).get(key, 0)) if result.get("ok", false) else 0

func collect_rewards_preflight(rewards: Dictionary, source_id: String = "") -> Dictionary:
	return ledger.collect_rewards_preflight(rewards, source_id)

func can_collect_rewards(rewards: Dictionary) -> bool:
	return bool(collect_rewards_preflight(rewards).get("ok", false))

func collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary:
	return ledger.collect_rewards_atomic(rewards, source_id)

func catch_fish(fish_key: String) -> Dictionary:
	if not catalog.FISH_DEFINITIONS.has(fish_key): return {"ok":false, "reason":"未知鱼类。"}
	if not can_carry_item(fish_key, 1): return {"ok":false, "reason":"背包没有空格或该鱼已堆满。"}
	backpack[fish_key] = int(backpack.get(fish_key, 0)) + 1
	amounts[fish_key] = int(amounts.get(fish_key, 0)) + 1
	total_collected += 1
	return {"ok":true, "fish_key":fish_key, "fish_name":fish_name(fish_key), "food_value":fish_food_value(fish_key)}

func fish_name(fish_key: String) -> String:
	return catalog.fish_name(fish_key)

func fish_food_value(fish_key: String) -> int:
	return catalog.fish_food_value(fish_key)

func fish_items() -> Array[String]:
	return FISH_KEYS.duplicate()

func cooked_fish_key(fish_key: String) -> String:
	return catalog.cooked_fish_key(fish_key)

func cooked_fish_name(fish_key: String) -> String:
	return catalog.display_name(cooked_fish_key(fish_key))

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
	return inventory_state.move_to_backpack(key, amount)

func move_to_storage(key: String, amount: int = 1) -> Dictionary:
	var result := inventory_state.move_to_storage(key, amount)
	if result.get("ok", false): result["reason"] = "已将 %s%d 放回储物架。" % [display_name(key), int(result.get("amount", 0))]
	return result

func discard_from_storage(key: String, amount: int = 1) -> Dictionary:
	var result := inventory_state.discard_from_storage(key, amount)
	if result.get("ok", false):
		if amounts.has(key): ledger.amounts[key] = maxi(0, int(amounts.get(key, 0)) - int(result.get("amount", 0)))
		result["reason"] = "已丢弃%s%d。" % [display_name(key), int(result.get("amount", 0))]
	return result

func discard_from_backpack(key: String, amount: int = 1) -> Dictionary:
	var result := inventory_state.discard_from_backpack(key, amount)
	if result.get("ok", false):
		if amounts.has(key): ledger.amounts[key] = maxi(0, int(amounts.get(key, 0)) - int(result.get("amount", 0)))
		result["reason"] = "已从背包丢弃%s%d。" % [display_name(key), int(result.get("amount", 0))]
	return result

func backpack_text() -> String:
	var rows: Array[String] = []
	for key in ITEM_KEYS:
		var amount := int(backpack.get(key, 0))
		if amount > 0: rows.append("%s%d" % [display_name(key), amount] if not key.begins_with("fish_") else "%s%d" % [fish_name(key), amount])
	return "、".join(rows) if not rows.is_empty() else "空"

func add_capacity_all(amount: int) -> void:
	for key in capacities: capacities[key] = int(capacities[key]) + amount

func display_name(key: String) -> String:
	return catalog.display_name(key)

func compact_text() -> String:
	return "浆%d 木%d 药%d 石%d 纤%d 布%d 金%d 水%d" % [get_amount("food"), get_amount("wood"), get_amount("medicine"), get_amount("stone"), get_amount("fiber"), get_amount("cloth"), get_amount("metal"), get_amount("water")]

func tool_definition(tool_id: String) -> Dictionary:
	return catalog.tool_definition(tool_id)

func tool_display_name(tool_id: String) -> String:
	return str(tool_definition(tool_id).get("label", tool_id))

func is_tool_unlocked(tool_id: String) -> bool:
	return tool_id in unlocked_tools and catalog.TOOL_DEFINITIONS.has(tool_id)

func is_axe_unlocked() -> bool:
	return is_tool_unlocked("axe")

func unlock_tool(tool_id: String) -> Dictionary:
	if not catalog.TOOL_DEFINITIONS.has(tool_id):
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
	if not catalog.TOOL_DEFINITIONS.has(tool_id) or has_tool(tool_id) or not is_tool_unlocked(tool_id): return false
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
	if not catalog.TOOL_DEFINITIONS.has(tool_id):
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
	var result := ledger.to_dict()
	result.merge(inventory_state.to_dict(), true)
	result["tools"] = tools.duplicate(true)
	result["unlocked_tools"] = unlocked_tools.duplicate()
	result["workbench_available"] = workbench_available
	return result

func from_dict(data: Dictionary) -> void:
	var saved_amounts = data.get("amounts", {})
	var saved_capacities = data.get("capacities", {})
	for key in ITEM_KEYS:
		if saved_amounts is Dictionary and saved_amounts.has(key): ledger.amounts[key] = maxi(0, int(saved_amounts[key]))
		if saved_capacities is Dictionary and saved_capacities.has(key): ledger.capacities[key] = maxi(1, int(saved_capacities[key]))
	ledger.total_collected = int(data.get("total_collected", 0))
	inventory_state.from_dict(data)
	_bind_state_aliases()
	backpack_capacity = BACKPACK_BASE_CAPACITY
	workbench_available = bool(data.get("workbench_available", true))
	total_collected = int(data.get("total_collected", 0))
	# Old saves do not contain tool fields, so they cleanly start without tools
	# while retaining the now-known axe and pickaxe recipes.
	tool_state.clear()
	tool_state["axe"] = false
	tool_state["pickaxe"] = false
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
			if catalog.TOOL_DEFINITIONS.has(id) and id not in unlocked_tools: unlocked_tools.append(id)
		# A malformed/legacy list should not strand a player without either
		# explicitly supported gathering recipe.
		if "axe" not in unlocked_tools: unlocked_tools.append("axe")
		if "pickaxe" not in unlocked_tools: unlocked_tools.append("pickaxe")
