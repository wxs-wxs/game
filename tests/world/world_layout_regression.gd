extends SceneTree

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
const WorldCollisionBuilder = preload("res://scripts/world/map/world_collision_builder.gd")
const ExplorationWorld = preload("res://scripts/exploration_world.gd")

func _init() -> void:
	var layout := WorldLayout.new()
	assert(layout.outdoor_bounds() == Rect2(Vector2.ZERO, Vector2(1920, 1080)))
	assert(not layout.outdoor_bounds().intersects(layout.interior_bounds()))
	assert(layout.interior_bounds().position.x > layout.outdoor_bounds().end.x)
	assert(layout.interior_bounds() == Rect2(2416, 17, 148, 146))
	assert(layout.safe_outdoor_position(Vector2(-50, -50)) == Vector2(20, 20))
	assert(layout.safe_outdoor_position(Vector2(2000, 1200)) == Vector2(1900, 1060))
	assert(layout.river_bank_x(540.0) < 1920.0)
	var parent := Node2D.new()
	var builder := WorldCollisionBuilder.new()
	builder.build(parent, layout)
	assert(parent.get_child_count() == 50)
	var fence := parent.get_node_or_null("CampFenceCollision") as StaticBody2D
	assert(fence != null)
	assert(fence.collision_layer == 1 and fence.collision_mask == 1)
	var fence_shape := fence.get_child(0) as CollisionShape2D
	assert(fence_shape.shape is RectangleShape2D)
	assert((fence_shape.shape as RectangleShape2D).size == Vector2(125, 12))
	var river := parent.get_node_or_null("RiverWaterCollision") as StaticBody2D
	assert(river != null)
	var river_polygon := river.get_child(0) as CollisionPolygon2D
	assert(river_polygon.polygon.size() == 74)
	builder.clear(parent)
	assert(parent.get_child_count() == 0)
	parent.free()
	var world := ExplorationWorld.new()
	assert(world.world_layout != null)
	assert(world.collision_builder != null)
	world._build_collisions()
	assert(world.get_child_count() == 50)
	var world_fence := world.get_node_or_null("CampFenceCollision") as StaticBody2D
	assert(world_fence != null and world_fence.collision_layer == 1 and world_fence.collision_mask == 1)
	var found_rock := false
	for child in world.get_children():
		if child is StaticBody2D and child.is_in_group(WorldCollisionBuilder.COLLISION_GROUP):
			var shape := child.get_child(0) as CollisionShape2D
			if shape != null and shape.shape is RectangleShape2D and (shape.shape as RectangleShape2D).size == Vector2(26, 28):
				found_rock = true
	assert(found_rock)
	assert(world.get_node_or_null("RiverWaterCollision") != null)
	assert(world.get_node_or_null("Player") == null)
	world.free()
	print("WORLD_LAYOUT_REGRESSION_OK")
	quit()
