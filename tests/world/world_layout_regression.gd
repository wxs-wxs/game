extends SceneTree

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
const WorldCollisionBuilder = preload("res://scripts/world/map/world_collision_builder.gd")

func _init() -> void:
	var layout := WorldLayout.new()
	assert(layout.outdoor_bounds() == Rect2(Vector2.ZERO, Vector2(1920, 1080)))
	assert(not layout.outdoor_bounds().intersects(layout.interior_bounds()))
	assert(layout.interior_bounds().position.x > layout.outdoor_bounds().end.x)
	assert(layout.safe_outdoor_position(Vector2(-50, 200)).x >= 12.0)
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
	print("WORLD_LAYOUT_REGRESSION_OK")
	quit()
