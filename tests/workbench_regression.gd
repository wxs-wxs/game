extends SceneTree

## The finished world workbench must be a visible, persistent interaction
## point, and using it should enter the existing tool-selection UI.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var game: GameManager = main.game
	var world: ExplorationWorld = main.world
	var ui: UIController = main.ui
	var build = world.build_mode
	build.selected_blueprint = "workbench"
	build.toggle()
	assert(build.confirm_build())
	var site: ConstructionSite = build.site
	assert(site.get_node_or_null("WorkbenchArt") != null)
	for _step in range(8):
		site.advance_build(1.0)
	await process_frame
	assert(game.buildings.has("workbench"))
	assert(game.resources.workbench_available)
	var workbench: InteractionPoint
	for point in world.interactions:
		if point.unique_id == "workbench_outdoor": workbench = point
	assert(workbench != null)
	assert(workbench.get_node_or_null("WorkbenchArt") != null)
	assert(not is_instance_valid(site) or not site.visible)

	world.player.global_position = workbench.global_position
	world._process(0.1)
	assert(world.nearest == workbench)
	world.try_interact()
	assert(world.is_interacting())
	world._process(0.3)
	assert(not world.is_interacting())
	assert(ui.build_selection_panel.visible)
	assert(ui.build_selection_dim.visible)
	assert(game.time.paused)
	var state := world.serialize_state()
	var found_position := false
	for row in state.get("interactions", []):
		if str(row.get("id", "")) == "workbench_outdoor":
			found_position = row.get("position", []).size() >= 2
	assert(found_position)
	print("WORKBENCH_REGRESSION_OK point=%s panel=%s" % [workbench.global_position, ui.build_selection_panel.visible])
	quit()
