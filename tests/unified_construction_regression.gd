extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.begin_morning()
	var all := game.construction_catalog()
	assert(all.size() >= 9)
	var first_id := "storage_shelf"
	assert(game.buildings.get_definition(first_id).size() > 0)
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	world.player.position = Vector2(500, 500)
	var start: Dictionary = game.buildings.start_unified_project(first_id, Vector2(500, 500), game.resources, game.construction_skill.level)
	assert(bool(start.get("ok", false)))
	var second: Dictionary = game.buildings.start_unified_project(first_id, Vector2(520, 500), game.resources, game.construction_skill.level)
	assert(not bool(second.get("ok", false)))
	var cancelled: Dictionary = game.buildings.cancel_active_project(game.resources)
	assert(bool(cancelled.get("ok", false)))
	assert(game.buildings.active_construction().is_empty())
	# Both placement zones use the same map build flow and ledger.
	var build = world.build_mode
	world.player.position = Vector2(110, 150)
	build.selected_blueprint = "campfire"
	build.toggle()
	assert(build.can_place())
	assert(build.confirm_build())
	assert(game.buildings.active_construction().get("id", "") == "campfire")
	assert(not build.confirm_build())
	assert(bool(game.buildings.cancel_active_project(game.resources).get("ok", false)))
	build.selected_blueprint = first_id
	build.toggle()
	assert(build.can_place())
	assert(build.confirm_build())
	assert(game.buildings.active_construction().get("id", "") == first_id)
	assert(bool(game.buildings.cancel_active_project(game.resources).get("ok", false)))
	print("UNIFIED_CONSTRUCTION_REGRESSION_OK catalog=%d" % all.size())
	quit()
