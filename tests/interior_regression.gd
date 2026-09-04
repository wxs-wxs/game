extends SceneTree

## Regression coverage for the complete house transition.  The player starts
## at the shelter's drawn doorway, moves with the CharacterBody2D physics path
## inside the room, then reaches the split-wall opening and exits.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await physics_frame

	var outside_door: HouseDoor
	for point in world.interactions:
		if point.unique_id == "house_door": outside_door = point
	assert(outside_door != null)
	assert(outside_door.position == ExplorationWorld.HOUSE_DOOR_POSITION)
	# The old point was at the camp fence gate, away from the shelter artwork.
	assert(outside_door.position.distance_to(Vector2(220, 82)) > 40.0)

	# Approach from the walkable threshold immediately below the drawn door.
	var outside_threshold := ExplorationWorld.HOUSE_DOOR_OUTSIDE_POSITION
	world.player.global_position = outside_threshold
	var threshold_y := world.player.global_position.y
	Input.action_press("move_up")
	for _step in range(3): world.player._physics_process(0.05)
	Input.action_release("move_up")
	assert(world.player.global_position.y < threshold_y)
	world._process(0.1)
	assert(world.nearest == outside_door)
	world.try_interact()
	assert(world.is_interacting())
	world._process(0.8)
	assert(world.is_inside)
	assert(world.player.interior)
	assert(world.interior_manager.interior != null)
	var interior: HouseInterior = world.interior_manager.interior
	var bounds: Rect2 = world.get_player_bounds()
	assert(bounds.has_point(world.player.global_position))
	assert(world.player.global_position == interior.player_spawn_global())

	# Exercise the real CharacterBody2D movement path.  A physics tick must move
	# horizontally inside the room and stay on the interior side of the map.
	var spawn := world.player.global_position
	Input.action_press("move_right")
	for _step in range(8): world.player._physics_process(0.1)
	Input.action_release("move_right")
	assert(world.player.global_position.x > spawn.x)
	assert(world.player.global_position.x > ExplorationWorld.INTERIOR_OFFSET.x)
	assert(world.get_player_bounds().has_point(world.player.global_position))

	# Walk back through the open left-wall span.  The door point must be
	# discoverable at the opening rather than behind an undifferentiated wall.
	Input.action_press("move_left")
	for _step in range(100): world.player._physics_process(0.05)
	Input.action_release("move_left")
	world._process(0.1)
	assert(world.player.global_position.x <= interior.door.global_position.x + 2.0)
	assert(world.nearest == interior.door)
	world.try_interact()
	world._process(0.8)
	assert(not world.is_inside)
	assert(not world.player.interior)
	assert(world.player.global_position == outside_threshold)
	print("INTERIOR_REGRESSION_OK door=%s spawn=%s exit=%s" % [outside_door.position, spawn, world.player.global_position])
	quit()
