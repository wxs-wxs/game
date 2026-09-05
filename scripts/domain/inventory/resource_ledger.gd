class_name ResourceLedger
extends RefCounted

var catalog: ResourceCatalog
var amounts: Dictionary = {}
var capacities: Dictionary = {}
var total_collected := 0
var inventory: RefCounted = null

func _init(catalog_value = null, inventory_value = null) -> void:
	if catalog_value == null: catalog_value = ResourceCatalog.new()
	catalog = catalog_value
	inventory = inventory_value
	for key in catalog.ITEM_KEYS:
		amounts[key] = int(catalog.INITIAL_AMOUNTS.get(key, 0))
		capacities[key] = int(catalog.CAPACITIES.get(key, catalog.STACK_MAX))

func get_amount(key: String) -> int: return int(amounts.get(key, 0))
func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if get_amount(str(key)) < int(cost[key]): return false
	return true
func _source_allowed(key: String, source_id: String) -> bool:
	if source_id.is_empty() or not catalog.SOURCE_RULES.has(key): return true
	var normalized := source_id.to_lower()
	for variant in catalog.SOURCE_RULES[key]:
		if normalized.begins_with(str(variant).to_lower()): return true
	return false
func add(key: String, delta: int) -> int:
	if not amounts.has(key): return 0
	var before := get_amount(key)
	if delta < 0:
		var removed := mini(-delta, before)
		if inventory != null:
			var from_storage := mini(removed, int(inventory.storage.get(key, 0)))
			inventory.storage[key] = int(inventory.storage.get(key, 0)) - from_storage
			var remaining := removed - from_storage
			if remaining > 0:
				var from_backpack := mini(remaining, int(inventory.backpack.get(key, 0)))
				inventory.backpack[key] = int(inventory.backpack.get(key, 0)) - from_backpack
		amounts[key] = before - removed
		return removed
	amounts[key] = mini(int(capacities[key]), before + delta)
	var actual := get_amount(key) - before
	if actual > 0:
		total_collected += actual
		if inventory != null: inventory.storage[key] = int(inventory.storage.get(key, 0)) + actual
	return actual
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost): return false
	for key in cost: add(str(key), -int(cost[key]))
	return true
func can_collect_rewards(rewards: Dictionary) -> bool:
	var simulated := amounts.duplicate()
	var simulated_backpack: Dictionary = inventory.backpack.duplicate() if inventory != null else {}
	var used: int = inventory.backpack_slots_used() if inventory != null else 0
	for key in rewards:
		var id := str(key); var amount := int(rewards[key])
		if amount < 0 or amount == 0: continue
		if not catalog.ITEM_KEYS.has(id) or int(simulated.get(id, 0)) + amount > int(capacities.get(id, catalog.STACK_MAX)): return false
		if inventory != null:
			var current := int(simulated_backpack.get(id, 0))
			if current + amount > catalog.STACK_MAX: return false
			if current == 0:
				used += 1
				if used > inventory.backpack_capacity: return false
				simulated_backpack[id] = current + amount
		simulated[id] = int(simulated.get(id, 0)) + amount
	return true
func collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary:
	if rewards.is_empty(): return {"ok":true, "reason":"没有奖励。", "changed":false, "data":{}, "added":{}}
	if source_id == "camp_task":
		for key in rewards:
			var id := str(key); var amount := int(rewards[key])
			if amount <= 0: continue
			if not catalog.ITEM_KEYS.has(id) or get_amount(id) + amount > int(capacities.get(id, catalog.STACK_MAX)):
				return {"ok":false, "reason":"营地储备空间不足。", "changed":false, "data":{}}
		var stored := {}
		for key in rewards:
			var id := str(key); var amount := int(rewards[key])
			if amount <= 0: continue
			amounts[id] += amount
			if inventory != null: inventory.storage[id] = int(inventory.storage.get(id, 0)) + amount
			total_collected += amount; stored[id] = amount
		return {"ok":true, "reason":"奖励已存入营地。", "changed":not stored.is_empty(), "data":stored, "added":stored}
	if not can_collect_rewards(rewards): return {"ok":false, "reason":"携带空间不足，请先整理背包。", "changed":false, "data":{}}
	for key in rewards:
		if int(rewards[key]) > 0 and not _source_allowed(str(key), source_id): return {"ok":false, "reason":"该来源无法提供此奖励。", "changed":false, "data":{}}
	var added := {}
	for key in rewards:
		var amount := int(rewards[key])
		if amount <= 0: continue
		var id := str(key)
		if inventory != null:
			amounts[id] = int(amounts.get(id, 0)) + amount
			inventory.backpack[id] = int(inventory.backpack.get(id, 0)) + amount
			total_collected += amount
		else:
			var actual := add(id, amount)
			if actual != amount: return {"ok":false, "reason":"奖励领取失败。", "changed":false, "data":{}}
		added[str(key)] = amount
	return {"ok":true, "reason":"奖励已领取。", "changed":true, "data":added, "added":added}
func to_dict() -> Dictionary: return {"amounts":amounts.duplicate(true), "capacities":capacities.duplicate(true), "total_collected":total_collected}
func from_dict(data: Dictionary) -> void:
	for key in catalog.ITEM_KEYS:
		if data.get("amounts", {}) is Dictionary and data.amounts.has(key): amounts[key] = maxi(0, int(data.amounts[key]))
		if data.get("capacities", {}) is Dictionary and data.capacities.has(key): capacities[key] = maxi(1, int(data.capacities[key]))
	total_collected = int(data.get("total_collected", 0))
