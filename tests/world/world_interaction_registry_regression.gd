extends SceneTree

const WorldInteractionRegistry = preload("res://scripts/world/interaction/world_interaction_registry.gd")
const ExplorationWorld = preload("res://scripts/exploration_world.gd")

func _init() -> void:
	var registry := WorldInteractionRegistry.new()
	assert(registry.nearest(Vector2.ZERO, 40.0) == null)
	var point := CampfirePoint.new()
	registry.register(point)
	assert(registry.points.size() == 1)
	registry.unregister(point)
	assert(registry.points.is_empty())
	point.free()
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	await process_frame
	var outdoor_count := world.interaction_registry.points.size()
	world.enter_house()
	await process_frame
	world.exit_house()
	await process_frame
	assert(world.interaction_registry.points.size() == outdoor_count)
	for registered in world.interaction_registry.points:
		assert(registered.get_parent() == world)
	world.enter_house()
	await process_frame
	world.exit_house()
	await process_frame
	assert(world.interaction_registry.points.size() == outdoor_count)
	world.queue_free()
	print("WORLD_INTERACTION_REGISTRY_REGRESSION_OK")
	quit()
