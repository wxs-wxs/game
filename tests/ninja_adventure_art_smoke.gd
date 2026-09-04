extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await process_frame

	var expected := [
		"campfire", "house_door", "river_fishing", "forest_berries",
		"field_pebble", "field_branch", "forest_tree", "old_ruins", "rock_pile"
	]
	for point in world.interactions:
		if point.unique_id in expected:
			assert(point.art_sprite != null)
			assert(point.art_sprite.texture != null)
			assert(point.art_sprite.scale.x == round(point.art_sprite.scale.x))
			assert(point.art_sprite.scale.y == round(point.art_sprite.scale.y))
		assert(point.unique_id != "camp_bed")
	var ruin_sprite := world.get_node_or_null("RuinLandmark") as Sprite2D
	assert(ruin_sprite != null)
	assert(ruin_sprite.texture is AtlasTexture)
	assert((ruin_sprite.texture as AtlasTexture).region == world.RUIN_TEXTURE_REGION)

	var school := world.fish_school as RiverFishSchool
	assert(school != null)
	assert(school.get_node_or_null("Fish_00") is Sprite2D)
	assert((school.get_node("Fish_00") as Sprite2D).texture != null)
	assert((school.get_node("Fish_00") as Sprite2D).scale == Vector2(2, 2))

	world.enter_house()
	await process_frame
	assert(world.interior_manager.interior.rest_bed.art_sprite != null)
	assert(world.interior_manager.interior.sleep_bed.art_sprite != null)
	world.exit_house()
	print("NINJA_ART_OK points=%d fish=%d" % [world.interactions.size(), school.fish.size()])
	quit()
