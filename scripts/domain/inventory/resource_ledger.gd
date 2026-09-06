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
			inventory.adjust_storage(key, -from_storage)
			var remaining := removed - from_storage
			if remaining > 0:
				var from_backpack := mini(remaining, int(inventory.backpack.get(key, 0)))
				inventory.adjust_backpack(key, -from_backpack)
		amounts[key] = before - removed
		return removed
	amounts[key] = mini(int(capacities[key]), before + delta)
	var actual := get_amount(key) - before
	if actual > 0:
		total_collected += actual
		if inventory != null: inventory.adjust_storage(key, actual)
	return actual
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost): return false
	for key in cost: add(str(key), -int(cost[key]))
	return true
func collect_rewards_preflight(rewards: Dictionary, source_id: String = "") -> Dictionary:
	if rewards.is_empty():
		return {"ok":true, "reason":"奖励可领取。"}
	var simulated_backpack: Dictionary = inventory.backpack.duplicate() if inventory != null else {}
	var used: int = inventory.backpack_slots_used() if inventory != null else 0
	for key in rewards:
		var id := str(key)
		var amount := maxi(0, int(rewards[key]))
		if amount == 0:
			continue
		if not catalog.ITEM_KEYS.has(id):
			return {"ok":false, "reason":"无法携带未知物品：%s。" % id}
		if not _source_allowed(id, source_id):
			return {"ok":false, "reason":"该来源无法提供%s。" % catalog.display_name(id)}
		var current := int(simulated_backpack.get(id, 0))
		if current + amount > catalog.STACK_MAX:
			return {"ok":false, "reason":"%s堆叠已达到每格上限 %d。" % [catalog.display_name(id), catalog.STACK_MAX]}
		var capacity := int(capacities.get(id, catalog.STACK_MAX))
		if get_amount(id) + amount > capacity:
			return {"ok":false, "reason":"%s已达到储备上限 %d。" % [catalog.display_name(id), capacity]}
		if inventory != null and current == 0:
			used += 1
			if used > inventory.backpack_capacity:
				return {"ok":false, "reason":"携带空间不足，请先整理背包。"}
		simulated_backpack[id] = current + amount
	return {"ok":true, "reason":"奖励可领取。"}

func can_collect_rewards(rewards: Dictionary) -> bool:
	return bool(collect_rewards_preflight(rewards).get("ok", false))

func collect_from_source(key: String, amount: int, source_id: String = "") -> Dictionary:
	if amount <= 0:
		return {"ok":false, "reason":"产出数量无效。", "added":{}}
	var preflight := collect_rewards_preflight({key: amount}, source_id)
	if not bool(preflight.get("ok", false)):
		return {"ok":false, "reason":str(preflight.get("reason", "奖励领取失败。")), "added":{}}
	var id := str(key)
	if inventory != null:
		amounts[id] = int(amounts.get(id, 0)) + amount
		inventory.adjust_backpack(id, amount)
	else:
		amounts[id] = int(amounts.get(id, 0)) + amount
	total_collected += amount
	return {"ok":true, "reason":"奖励已领取。", "added":{id: amount}}

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
			if inventory != null: inventory.adjust_storage(id, amount)
			total_collected += amount; stored[id] = amount
		return {"ok":true, "reason":"奖励已存入营地。", "changed":not stored.is_empty(), "data":stored, "added":stored}
	var preflight := collect_rewards_preflight(rewards, source_id)
	if not bool(preflight.get("ok", false)):
		return {"ok":false, "reason":str(preflight.get("reason", "携带空间不足，请先整理背包。")), "changed":false, "data":{}, "added":{}}
	var added := {}
	for key in rewards:
		var amount := int(rewards[key])
		if amount <= 0: continue
		var id := str(key)
		if inventory != null:
			amounts[id] = int(amounts.get(id, 0)) + amount
			inventory.adjust_backpack(id, amount)
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
