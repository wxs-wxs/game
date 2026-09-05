extends SceneTree

## Characterization coverage for the current ExplorationWorld facade.  This
## deliberately exercises the real node tree and house transition so the
## modular extraction preserves the existing public behavior.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await physics_frame

	assert(ExplorationWorld.MAP_SIZE == Vector2(1920, 1080))
	assert(ExplorationWorld.INTERIOR_OFFSET.x > ExplorationWorld.MAP_SIZE.x)
	assert(ExplorationWorld.INTERIOR_ROOM_SIZE == Vector2(180, 180))
	assert(world.get_player_bounds().size.x > 0.0)
	assert(world.get_player_bounds().size.y > 0.0)
	assert(world.get_node_or_null("Player") != null)
	var outside_door: HouseDoor
	for point in world.interactions:
		if point is HouseDoor and point.unique_id == "house_door": outside_door = point
	assert(outside_door != null)
	# The current facade stores points in an array rather than an
	# InteractionPoints container node; require that real registered nodes exist.
	assert(world.interactions.size() > 0)
	assert(outside_door.get_parent() == world)

	var signal_names: Array[String] = []
	var expected_signal_args := {
		"interaction_changed": ["prompt"],
		"interaction_result": ["message"],
		"interaction_progress_changed": ["name", "progress"],
		"storage_open_requested": [],
		"tool_selection_requested": []
	}
	for signal_info in world.get_signal_list():
		var signal_name := str(signal_info.get("name", ""))
		signal_names.append(signal_name)
		if expected_signal_args.has(signal_name):
			var args: Array = signal_info.get("args", [])
			var expected_args: Array = expected_signal_args[signal_name]
			assert(args.size() == expected_args.size())
			for index in range(expected_args.size()):
				assert(str(args[index].get("name", "")) == expected_args[index])
	for expected_signal in ["interaction_changed", "interaction_result", "interaction_progress_changed", "storage_open_requested", "tool_selection_requested"]:
		assert(signal_names.has(expected_signal))

	var point_ids: Array[String] = []
	for point in world.interactions:
		point_ids.append(point.unique_id)
	assert(point_ids.has("campfire"))
	assert(point_ids.has("house_door"))
	assert(point_ids.has("river_fishing"))
	assert(point_ids.has("old_ruins"))
	assert(point_ids.has("forest_tree"))

	assert(outside_door.unique_id == "house_door")
	assert(not world.is_inside)
	var outdoor_bounds := world.get_player_bounds()
	assert(outdoor_bounds == Rect2(12, 12, 1896, 1056))
	assert(outdoor_bounds.has_point(world.player.global_position))

	world.player.global_position = ExplorationWorld.HOUSE_DOOR_OUTSIDE_POSITION
	world._process(0.1)
	assert(world.nearest == outside_door)
	world.try_interact()
	assert(world.is_interacting())
	world._process(outside_door.interaction_time + 0.1)
	assert(world.is_inside)
	assert(world.player.interior)
	assert(world.interior_manager.interior != null)
	var indoor_bounds := world.get_player_bounds()
	assert(indoor_bounds == Rect2(2416, 17, 148, 146))
	assert(indoor_bounds.has_point(world.player.global_position))
	var inside_door := world.interior_manager.interior.door as HouseDoor
	assert(inside_door != null)
	assert(inside_door.unique_id == "house_exit")

	world.exit_house()
	assert(not world.is_inside)
	assert(not world.player.interior)
	assert(world.player.global_position == ExplorationWorld.HOUSE_DOOR_OUTSIDE_POSITION)
	assert(world.get_player_bounds() == outdoor_bounds)

	print("WORLD_FACADE_REGRESSION_OK map=%s interior_offset=%s outside_bounds=%s points=%d signals=%d nodes=Player,HouseDoor(type),InteractionPoints(array)" % [ExplorationWorld.MAP_SIZE, ExplorationWorld.INTERIOR_OFFSET, outdoor_bounds, point_ids.size(), signal_names.size()])
	quit()
