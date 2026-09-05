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
	_assert_collision_geometry(parent, layout)
	builder.clear(parent)
	assert(parent.get_child_count() == 0)
	parent.free()
	var world := ExplorationWorld.new()
	assert(world.world_layout != null)
	assert(world.collision_builder != null)
	world._build_collisions()
	_assert_collision_geometry(world, world.world_layout)
	assert(world.get_node_or_null("Player") == null)
	assert(world.get_node_or_null("UIController") == null)
	for child in world.get_children():
		assert(child is StaticBody2D)
	world.free()
	print("WORLD_LAYOUT_REGRESSION_OK")
	quit()

func _assert_collision_geometry(parent: Node2D, layout: WorldLayout) -> void:
	var expected_rects: Array[Rect2] = [
		Rect2(75, 75, 125, 12), Rect2(235, 75, 30, 12), Rect2(75, 75, 12, 130),
		Rect2(253, 75, 12, 130), Rect2(75, 199, 112, 12), Rect2(223, 199, 42, 12),
		Rect2(132, 102, 19, 35), Rect2(165, 102, 19, 35),
		Rect2(950, 380, 210, 18), Rect2(950, 380, 18, 185), Rect2(1142, 380, 18, 185),
		Rect2(950, 547, 80, 18), Rect2(350, 145, 28, 28), Rect2(430, 230, 32, 24),
		Rect2(280, 410, 30, 26), Rect2(435, 535, 30, 30), Rect2(810, 490, 32, 24),
		Rect2(870, 590, 26, 28), Rect2(1328, 388, 30, 30), Rect2(1465, 550, 30, 30),
		Rect2(1495, 732, 30, 30), Rect2(1465, 916, 30, 30)
	]
	var harvestable = layout.harvestable_tree_positions()
	for position in harvestable:
		expected_rects.append(Rect2(position - Vector2(11, 21), Vector2(22, 42)))
	for position in layout.grove_tree_positions():
		expected_rects.append(Rect2(position - Vector2(8, 14), Vector2(16, 28)))
	assert(expected_rects.size() == 49)
	assert(parent.get_child_count() == 50)
	var rectangle_index := 0
	for child in parent.get_children():
		assert(child is StaticBody2D)
		var body := child as StaticBody2D
		assert(body.is_in_group(WorldCollisionBuilder.COLLISION_GROUP))
		assert(body.collision_layer == 1 and body.collision_mask == 1)
		if body.name == "RiverWaterCollision":
			var polygon := body.get_child(0) as CollisionPolygon2D
			assert(polygon != null and polygon.polygon.size() == 74)
			assert(polygon.polygon[0] == Vector2(layout.river_bank_x(-32.0), -32.0))
			assert(polygon.polygon[72] == Vector2(1944, 1112))
			assert(polygon.polygon[73] == Vector2(1944, -32))
			continue
		assert(rectangle_index < expected_rects.size())
		var shape := body.get_child(0) as CollisionShape2D
		assert(shape != null and shape.shape is RectangleShape2D)
		var expected := expected_rects[rectangle_index]
		assert(body.position == expected.position + expected.size * 0.5)
		assert((shape.shape as RectangleShape2D).size == expected.size)
		var expected_names := {0: "CampFenceCollision", 6: "HouseWallCollision", 8: "RuinWallCollision", 12: "RockPileCollision", 22: "TreeCollision", 30: "SmallTreeCollision"}
		if expected_names.has(rectangle_index):
			assert(body.name == expected_names[rectangle_index])
		else:
			assert(body.name.begins_with("@StaticBody2D@"))
		rectangle_index += 1
	assert(rectangle_index == expected_rects.size())
