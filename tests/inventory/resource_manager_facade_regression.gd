extends SceneTree

func _init() -> void:
	var legacy := ResourceManager.new()
	var direct := ResourceManager.new()
	assert(legacy.catalog is ResourceCatalog)
	assert(legacy.ledger is ResourceLedger)
	assert(legacy.inventory_state is InventoryState)
	legacy.ledger.amounts["stone"] = 7
	assert(legacy.amounts["stone"] == 7)
	legacy.ledger.capacities["stone"] = 8
	assert(legacy.capacities["stone"] == 8)
	legacy.tool_state["axe"] = true
	assert(legacy.tools["axe"])
	legacy.inventory_state.backpack["fiber"] = 2
	assert(legacy.backpack["fiber"] == 2)
	legacy.backpack["fiber"] = 0
	var saved := legacy.to_dict()
	direct.from_dict(saved)
	assert(direct.to_dict() == saved)
	direct.amounts["wood"] = 6
	assert(direct.ledger.amounts["wood"] == 6)
	direct.backpack["fiber"] = 1
	assert(direct.inventory_state.backpack["fiber"] == 1)
	direct.tools["pickaxe"] = true
	assert(direct.tool_state["pickaxe"])
	legacy.backpack["wood"] = 1
	assert(legacy.backpack_slots_used() == 1)
	var reward := {"medicine": 1, "metal": 1}
	legacy.backpack_capacity = legacy.backpack_slots_used()
	var blocked := legacy.collect_rewards_atomic(reward, "facade_test")
	assert(not bool(blocked.get("ok", false)))
	assert(legacy.backpack.get("medicine", 0) == 0)
	print("RESOURCE_MANAGER_FACADE_REGRESSION_OK")
	quit()
