extends SceneTree

const ResourceCatalog = preload("res://scripts/domain/inventory/resource_catalog.gd")
const ResourceLedger = preload("res://scripts/domain/inventory/resource_ledger.gd")
const InventoryState = preload("res://scripts/domain/inventory/inventory_state.gd")

func _init() -> void:
	var catalog := ResourceCatalog.new()
	assert("fish_carp" in catalog.item_keys())
	assert(catalog.display_name("wood") != "wood")
	var ledger := ResourceLedger.new(catalog)
	assert(ledger.can_afford({"wood": 1}))
	var before := ledger.get_amount("wood")
	assert(ledger.spend({"wood": 1}))
	assert(ledger.get_amount("wood") == before - 1)
	var reward_before := ledger.get_amount("wood")
	var blocked := ledger.collect_rewards_atomic({"wood": 9999, "stone": 1}, "field_branch")
	assert(not bool(blocked.get("ok", false)))
	assert(not bool(blocked.get("changed", true)))
	assert(ledger.get_amount("wood") == reward_before)
	var inventory := InventoryState.new(catalog)
	inventory.backpack["wood"] = 1
	assert(inventory.backpack_slots_used() == 1)
	assert(inventory.move_to_storage("wood", 1)["ok"])
	assert(inventory.backpack.get("wood", 0) == 0)
	assert(inventory.storage.get("wood", 0) == 1)
	inventory.backpack_capacity = 1
	inventory.backpack["stone"] = 1
	inventory.storage["medicine"] = 1
	var slots_before := inventory.backpack_slots_used()
	var full := inventory.move_to_backpack("medicine", 1)
	assert(not bool(full.get("ok", false)))
	assert(inventory.backpack_slots_used() == slots_before)
	assert(inventory.storage.get("medicine", 0) == 1)
	print("INVENTORY_DOMAIN_REGRESSION_OK")
	quit()
