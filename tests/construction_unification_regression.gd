extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var ids := ["campfire", "bed", "shed", "clinic", "fence", "storage_shelf", "workbench", "fire_basin", "rain_collector"]
	assert(game.construction_catalog().size() == ids.size())
	for id in ids:
		var definition: Dictionary = game.buildings.get_definition(id)
		assert(definition.has("cost") and not definition.has("materials"), id + " uses unified cost")
		assert(definition.has("build_time") and definition.has("effect_id"))
	# Camp and free-placement flows share the same material/state ledger.
	var wood_before := game.resources.get_amount("wood")
	var camp_result := game.begin_construction("campfire")
	assert(camp_result.get("ok", false))
	assert(game.resources.get_amount("wood") == wood_before - 5)
	assert(not game.begin_construction("bed").get("ok", false))
	var active_saved := game.to_dict()
	var active_restored := GameManager.new(); active_restored.from_dict(active_saved)
	assert(active_restored.buildings.active_project.get("id", "") == "campfire")
	game.buildings.add_work(12)
	game.apply_building_effect("campfire")
	assert(game.buildings.has("campfire"))
	var saved := game.to_dict()
	var restored := GameManager.new(); restored.from_dict(saved)
	assert(restored.buildings.has("campfire"))
	var effect_cap: int = int(restored.resources.capacities["food"])
	restored.apply_building_effect("campfire")
	assert(restored.resources.capacities["food"] == effect_cap)

	var world := ExplorationWorld.new(); root.add_child(world); world.setup(game)
	var build = world.build_mode
	build.selected_blueprint = "storage_shelf"
	build.toggle()
	assert(build.active and build.can_place())
	var shelf_wood := game.resources.get_amount("wood")
	assert(build.confirm_build())
	assert(game.resources.get_amount("wood") == shelf_wood - 4)
	for _i in range(8): build.site.advance_build(1.0)
	assert(game.buildings.has("storage_shelf"))
	assert(game.built_facilities.has("storage_shelf"))
	var capacity: int = int(game.resources.capacities["food"])
	game.complete_world_construction("storage_shelf")
	assert(game.resources.capacities["food"] == capacity)
	var state := game.to_dict()
	var loaded := GameManager.new(); loaded.from_dict(state)
	assert(loaded.buildings.has("storage_shelf"))
	assert(loaded.buildings.world_projects.is_empty())
	print("CONSTRUCTION_UNIFICATION_REGRESSION_OK ids=%d built=%d" % [ids.size(), loaded.buildings.built.size()])
	quit()
