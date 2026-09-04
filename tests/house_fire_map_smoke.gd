extends SceneTree

## Acceptance coverage for the single-bed house, wood-fired hearth, chimney
## state, enlarged map and the absence of an outer air-wall body.
func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	assert(ExplorationWorld.MAP_SIZE == Vector2(1920, 1080))
	var interior_rect := Rect2(ExplorationWorld.INTERIOR_OFFSET, ExplorationWorld.INTERIOR_ROOM_SIZE)
	assert(not interior_rect.intersects(Rect2(Vector2.ZERO, ExplorationWorld.MAP_SIZE)))
	assert(ExplorationWorld.INTERIOR_OFFSET.x > ExplorationWorld.MAP_SIZE.x)
	var static_body_count := 0
	for child in world.get_children():
		if child is StaticBody2D:
			static_body_count += 1
			var body_position: Vector2 = child.position
			assert(body_position.x > -20.0 and body_position.x < ExplorationWorld.MAP_SIZE.x + 20.0)
			assert(body_position.y > -20.0 and body_position.y < ExplorationWorld.MAP_SIZE.y + 20.0)
	assert(static_body_count > 0)

	world.enter_house()
	var interior: HouseInterior = world.interior_manager.interior
	var beds := []
	for child in interior.get_children():
		if child is BedPoint:
			beds.append(child)
	assert(beds.size() == 1)
	assert(interior.rest_bed == interior.sleep_bed)
	assert(interior.fireplace is FireplacePoint)

	var fireplace: FireplacePoint = interior.fireplace
	assert(not fireplace.lit)
	var wood_before := game.resources.get_amount("wood")
	fireplace.interact()
	fireplace.tick_interaction(fireplace.interaction_time + 0.1)
	assert(fireplace.lit)
	assert(game.house_fire_lit)
	assert(game.resources.get_amount("wood") == wood_before - 1)
	assert(fireplace.prompt_text().contains("烟囱"))
	var snapshot: Dictionary = game.to_dict()
	var restored := GameManager.new()
	restored.from_dict(snapshot)
	assert(restored.house_fire_lit)

	world.exit_house()
	var chimney := world.get_node_or_null("HouseChimney") as ChimneyArt
	assert(chimney != null)
	assert(game.house_fire_lit)
	print("HOUSE_FIRE_MAP_SMOKE_OK beds=%d fire=%s map=%s" % [beds.size(), fireplace.lit, ExplorationWorld.MAP_SIZE])
	quit()
