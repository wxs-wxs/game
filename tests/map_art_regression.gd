extends SceneTree

## Visual-layout contracts for the outdoor map: one indoor bed, a continuous
## edge water body, a real camp gate, and no detached water wall strips.
func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	assert(ExplorationWorld.RIVER_RECT.end.x == ExplorationWorld.MAP_SIZE.x)
	assert(ExplorationWorld.RIVER_RECT.position.y < 0.0)
	assert(ExplorationWorld.RUIN_TEXTURE_REGION == Rect2(0, 0, 64, 48))
	for tree_position in world.HARVESTABLE_TREE_POSITIONS:
		assert(tree_position.x + 24.0 < world._river_bank_x(tree_position.y))
	for tree_position in world.GROVE_TREE_POSITIONS:
		assert(tree_position.x + 24.0 < world._river_bank_x(tree_position.y))
	var outdoor_beds := 0
	for point in world.interactions:
		if point is BedPoint and point.get_parent() == world:
			outdoor_beds += 1
	assert(outdoor_beds == 0)
	var water_body := world.get_node_or_null("RiverWaterCollision") as StaticBody2D
	assert(water_body != null)
	assert(water_body.get_child_count() == 1)
	assert(water_body.get_child(0) is CollisionPolygon2D)
	var water_polygon := water_body.get_child(0) as CollisionPolygon2D
	assert(water_polygon.polygon.size() > 10)
	# The camp-facing gate is the only gap in the lower fence collision.
	var bottom_fence_segments := 0
	for child in world.get_children():
		if child is StaticBody2D:
			var shape := child.get_child(0) as CollisionShape2D
			if shape != null and shape.shape is RectangleShape2D and is_equal_approx(child.position.y, 205.0):
				bottom_fence_segments += 1
	assert(bottom_fence_segments == 2)
	print("MAP_ART_REGRESSION_OK river=%s outdoor_beds=%d fence_segments=%d" % [ExplorationWorld.RIVER_RECT, outdoor_beds, bottom_fence_segments])
	quit()
