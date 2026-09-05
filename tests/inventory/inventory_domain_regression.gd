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
	var inventory := InventoryState.new(catalog)
	inventory.backpack["wood"] = 1
	assert(inventory.backpack_slots_used() == 1)
	assert(inventory.move_to_storage("wood", 1)["ok"])
	assert(inventory.backpack.get("wood", 0) == 0)
	assert(inventory.storage.get("wood", 0) == 1)
	print("INVENTORY_DOMAIN_REGRESSION_OK")
	quit()
