extends SceneTree

const WorldInteractionRegistry = preload("res://scripts/world/interaction/world_interaction_registry.gd")

func _init() -> void:
	var registry := WorldInteractionRegistry.new()
	assert(registry.nearest(Vector2.ZERO, 40.0) == null)
	print("WORLD_INTERACTION_REGISTRY_REGRESSION_OK")
	quit()
