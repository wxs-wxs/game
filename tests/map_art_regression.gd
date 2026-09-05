extends SceneTree

## Visual-layout contracts for the outdoor map: one indoor bed, a continuous
## edge water body, a real camp gate, and no detached water wall strips.
func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await process_frame

	assert(ExplorationWorld.RIVER_RECT.end.x == ExplorationWorld.MAP_SIZE.x)
	assert(ExplorationWorld.RIVER_RECT.position.y < 0.0)
	assert(ExplorationWorld.RUIN_TEXTURE_REGION == Rect2(0, 0, 64, 48))
	# Small grove trees are real harvest points, and authored centers leave
	# enough room for their pixel-art crowns and trunk collision.
	var tree_points_by_position := {}
	for point in world.interactions:
		if point is TreeSpot:
			tree_points_by_position[point.position] = point
	assert(tree_points_by_position.size() == world.HARVESTABLE_TREE_POSITIONS.size() + world.GROVE_TREE_POSITIONS.size())
	var small_tree := tree_points_by_position.get(world.GROVE_TREE_POSITIONS[0]) as TreeSpot
	assert(small_tree != null)
	assert(small_tree.is_small_tree)
	assert(int(small_tree.reward.get("wood", 0)) == 2)
	assert(small_tree.required_tools.has("axe"))
	game.resources.axe = true
	game.resources.amounts["wood"] = 0
	small_tree.failure_chance = 0.0
	assert(small_tree.interact().get("started", false))
	small_tree.tick_interaction(small_tree.interaction_time + 0.1)
	assert(game.resources.get_amount("wood") == 2)
	var small_tree_scale := small_tree.art_scale
	small_tree.regrow_remaining = 0.1
	small_tree._process(0.2)
	assert(small_tree.art_sprite.scale == small_tree_scale)
	var all_tree_positions: Array[Vector2] = []
	all_tree_positions.append_array(world.HARVESTABLE_TREE_POSITIONS)
	all_tree_positions.append_array(world.GROVE_TREE_POSITIONS)
	var tree_points: Array[TreeSpot] = []
	for point in world.interactions:
		if point is TreeSpot:
			tree_points.append(point)
	for i in range(all_tree_positions.size()):
		for j in range(i + 1, all_tree_positions.size()):
			assert(all_tree_positions[i].distance_to(all_tree_positions[j]) >= 56.0)
			assert(all_tree_positions[i].distance_to(all_tree_positions[j]) >= 68.0)
			var first_sprite := tree_points[i].art_sprite
			var second_sprite := tree_points[j].art_sprite
			assert(first_sprite != null and second_sprite != null)
			var first_size: Vector2 = first_sprite.texture.get_size() * first_sprite.scale
			var second_size: Vector2 = second_sprite.texture.get_size() * second_sprite.scale
			var first_rect := Rect2(tree_points[i].position + first_sprite.position - first_size * 0.5, first_size)
			var second_rect := Rect2(tree_points[j].position + second_sprite.position - second_size * 0.5, second_size)
			assert(not first_rect.intersects(second_rect))
	# A harvestable tree must not also have a second direct world sprite at its
	# authored center; the interaction point owns the visible tree art.
	for child in world.get_children():
		if not child is Sprite2D:
			continue
		for tree_position in world.HARVESTABLE_TREE_POSITIONS:
			assert(child.position.distance_to(tree_position + Vector2(0, -4)) > 8.0)
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
