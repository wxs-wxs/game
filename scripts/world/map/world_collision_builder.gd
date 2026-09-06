class_name WorldCollisionBuilder
extends RefCounted

const COLLISION_GROUP := "world_layout_collision"

func build(parent: Node2D, layout: WorldLayout) -> void:
	if parent == null or layout == null:
		return
	# There is intentionally no invisible perimeter body. The field is bounded
	# by the player's soft map clamp, while authored landmarks use solid bodies.
	_add_wall(parent, Rect2(75, 75, 125, 12), "CampFence")
	_add_wall(parent, Rect2(235, 75, 30, 12), "CampFence")
	_add_wall(parent, Rect2(75, 75, 12, 130), "CampFence")
	_add_wall(parent, Rect2(253, 75, 12, 130), "CampFence")
	_add_wall(parent, Rect2(75, 199, 112, 12), "CampFence")
	_add_wall(parent, Rect2(223, 199, 42, 12), "CampFence")
	_add_wall(parent, Rect2(132, 102, 19, 35), "HouseWall")
	_add_wall(parent, Rect2(165, 102, 19, 35), "HouseWall")
	_add_water_collision(parent, layout)

	_add_wall(parent, Rect2(950, 380, 210, 18), "RuinWall")
	_add_wall(parent, Rect2(950, 380, 18, 185), "RuinWall")
	_add_wall(parent, Rect2(1142, 380, 18, 185), "RuinWall")
	_add_wall(parent, Rect2(950, 547, 80, 18), "RuinWall")

	for rect in [
		Rect2(350, 145, 28, 28), Rect2(430, 230, 32, 24), Rect2(280, 410, 30, 26),
		Rect2(435, 535, 30, 30), Rect2(810, 490, 32, 24), Rect2(870, 590, 26, 28),
		Rect2(1328, 388, 30, 30), Rect2(1465, 550, 30, 30), Rect2(1495, 732, 30, 30),
		Rect2(1465, 916, 30, 30)
	]:
		_add_wall(parent, rect, "RockPile")
	for position in layout.harvestable_tree_positions():
		_add_wall(parent, Rect2(position - Vector2(11, 21), Vector2(22, 42)), "Tree")
	for position in layout.grove_tree_positions():
		_add_wall(parent, Rect2(position - Vector2(8, 14), Vector2(16, 28)), "SmallTree")

func clear(parent: Node2D) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		if child is StaticBody2D and child.is_in_group(COLLISION_GROUP):
			child.free()

func add_wall(parent: Node2D, rect: Rect2, kind: String = "Landmark") -> void:
	_add_wall(parent, rect, kind)

func add_water_collision(parent: Node2D, layout: WorldLayout) -> void:
	_add_water_collision(parent, layout)

func _add_wall(parent: Node2D, rect: Rect2, kind: String = "Landmark") -> void:
	var body := StaticBody2D.new()
	body.name = "%sCollision" % kind
	body.add_to_group(COLLISION_GROUP)
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	parent.add_child(body)

func _add_water_collision(parent: Node2D, layout: WorldLayout) -> void:
	var body := StaticBody2D.new()
	body.name = "RiverWaterCollision"
	body.add_to_group(COLLISION_GROUP)
	body.collision_layer = 1
	body.collision_mask = 1
	var polygon := CollisionPolygon2D.new()
	var points := PackedVector2Array()
	for y in range(int(layout.RIVER_RECT.position.y), int(layout.MAP_SIZE.y) + 33, 16):
		points.append(Vector2(layout.river_bank_x(float(y)), float(y)))
	points.append(Vector2(layout.MAP_SIZE.x + 24.0, layout.MAP_SIZE.y + 32.0))
	points.append(Vector2(layout.MAP_SIZE.x + 24.0, -32.0))
	polygon.polygon = points
	body.add_child(polygon)
	parent.add_child(body)
