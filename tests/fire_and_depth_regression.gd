extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await process_frame

	# The fire sheet is 6 frames wide; a lit campfire must animate it instead of
	# leaving the first frame permanently displayed.
	var campfire := world.interactions.filter(func(point): return point.unique_id == "campfire")[0] as CampfirePoint
	assert(campfire != null)
	assert(campfire.art_sprite != null)
	assert(not campfire.art_sprite.visible)
	for child in world.get_children():
		if child is Sprite2D and child.position.distance_to(Vector2(210, 148)) < 4.0:
			assert(false)
	assert(campfire.art_sprite.hframes == 6)
	assert(campfire.art_sprite.vframes == 1)
	game.resources.amounts["wood"] = 1
	assert(bool(game.add_fire_fuel("campfire", 1).get("ok", false)))
	var initial_frame := campfire.art_sprite.frame
	campfire._process(0.13)
	assert(campfire.art_sprite.frame != initial_frame)

	# Tree subtrees share one world layer so their screen-space Y determines
	# which one is in front; insertion order must not decide the overlap.
	assert(world.y_sort_enabled)
	var tree_points: Array[TreeSpot] = []
	for point in world.interactions:
		if point is TreeSpot:
			tree_points.append(point)
	assert(tree_points.size() > 1)
	for point in tree_points:
		assert(point.z_index == 0)

	print("FIRE_AND_DEPTH_REGRESSION_OK frames=%d trees=%d" % [campfire.art_sprite.hframes, tree_points.size()])
	quit()
