class_name HouseInterior
extends Node2D

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const INTERIOR_FLOOR_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png"
const ROOM_SIZE := Vector2(180, 180)
const ROOM_BACKDROP := Rect2(-240, -80, 660, 340)
const PLAYER_BOUNDS := Rect2(Vector2(16, 17), Vector2(148, 146))
const SPAWN_POSITION := Vector2(24, 90)
const DOOR_POSITION := Vector2(20, 90)
const DOORWAY_Y_MIN := 75.0
const DOORWAY_Y_MAX := 105.0

var world
var offset := Vector2.ZERO
var door
var bed
var fireplace
## Compatibility aliases kept for old callers; both refer to the same one bed.
var rest_bed
var sleep_bed
var storage_shelf
var workbench_point
var fire_basin_point
var floor_texture: Texture2D

func setup(manager, at: Vector2) -> void:
	world = manager; offset = at; position = at
	floor_texture = Assets.texture(INTERIOR_FLOOR_ATLAS)
	_build_walls()
	door = preload("res://scripts/house_door.gd").new(); door.configure(world, true); add_child(door); door.position = DOOR_POSITION; door.setup(world.game); world.register_interior_point(door)
	bed = preload("res://scripts/bed_point.gd").new()
	bed.configure_indoor_combined()
	add_child(bed)
	bed.position = Vector2(94, 92)
	bed.setup(world.game)
	world.register_interior_point(bed)
	rest_bed = bed
	sleep_bed = bed
	fireplace = preload("res://scripts/fireplace_point.gd").new()
	add_child(fireplace)
	fireplace.position = Vector2(137, 57)
	fireplace.setup(world.game)
	world.register_interior_point(fireplace)
	if world.game != null and "storage_shelf" in world.game.built_facilities:
		storage_shelf = preload("res://scripts/storage_shelf_point.gd").new()
		storage_shelf.unique_id = "storage_shelf_indoor"
		add_child(storage_shelf)
		storage_shelf.position = Vector2(33, 47)
		storage_shelf.setup(world.game)
		world.register_interior_point(storage_shelf)
	if world.game != null and world.game.buildings.has("workbench"):
		workbench_point = preload("res://scripts/construction_facility_point.gd").new()
		workbench_point.configure("workbench_indoor", "简易工作台", Color("b8a16b"))
		add_child(workbench_point); workbench_point.position = Vector2(42, 128); workbench_point.setup(world.game); world.register_interior_point(workbench_point)
	if world.game != null and world.game.buildings.has("fire_basin"):
		fire_basin_point = preload("res://scripts/construction_facility_point.gd").new()
		fire_basin_point.configure("fire_basin_indoor", "火盆", Color("e9994b"))
		add_child(fire_basin_point); fire_basin_point.position = Vector2(137, 76); fire_basin_point.setup(world.game); world.register_interior_point(fire_basin_point)
	queue_redraw()

func player_spawn_global() -> Vector2:
	return global_position + SPAWN_POSITION

func player_bounds_global() -> Rect2:
	return Rect2(global_position + PLAYER_BOUNDS.position, PLAYER_BOUNDS.size)

func _build_walls() -> void:
	# The left wall is split around the doorway.  The 30 px opening is wider
	# than the player's collision body, so the door remains reachable from the
	# room and the exit transition cannot trap the player against a wall.
	for rect in [Rect2(0, 0, ROOM_SIZE.x, 10), Rect2(0, ROOM_SIZE.y - 10, ROOM_SIZE.x, 10), Rect2(0, 0, 10, DOORWAY_Y_MIN), Rect2(0, DOORWAY_Y_MAX, 10, ROOM_SIZE.y - DOORWAY_Y_MAX), Rect2(ROOM_SIZE.x - 10, 0, 10, ROOM_SIZE.y)]:
		var body := StaticBody2D.new(); var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = rect.size; shape.shape = box; body.position = rect.position + rect.size * 0.5; add_child(body); body.add_child(shape)

func _draw() -> void:
	# The room is staged outside the outdoor map. Paint a neutral surround so
	# the camera never reveals the river or an unrendered map edge around it.
	draw_rect(ROOM_BACKDROP, Color("172427"), true)
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("202c2d"), true)
	# Tile the dark stone floor from Ninja Adventure instead of drawing a new
	# furniture/floor pattern. The 16px source tile remains crisp at room scale.
	for y in range(16, 168, 16):
		for x in range(16, 168, 16):
			draw_texture_rect_region(floor_texture, Rect2(x, y, 16, 16), Rect2(208, 208, 16, 16))
	draw_rect(Rect2(12, 12, 156, 156), Color("866d58"), false, 3.0)
	# The interior flue lines up with the fireplace and the outside chimney.
	draw_rect(Rect2(130, 12, 16, 44), Color("303334"), true)
	draw_rect(Rect2(133, 12, 10, 42), Color("725044"), true)
	draw_rect(Rect2(129, 10, 18, 5), Color("1b2021"), true)
	draw_line(Vector2(136, 16), Vector2(136, 48), Color("9a6a4e", 0.7), 1.0)
	# Make the physical opening legible in the room art.  The interaction point
	# sits on this threshold, so the player can walk to it instead of targeting
	# an invisible wall segment.
	draw_rect(Rect2(0, DOORWAY_Y_MIN, 12, DOORWAY_Y_MAX - DOORWAY_Y_MIN), Color("2d3432"), true)
	draw_line(Vector2(0, DOORWAY_Y_MIN), Vector2(12, DOORWAY_Y_MIN), Color("866d58"), 2.0)
	draw_line(Vector2(0, DOORWAY_Y_MAX), Vector2(12, DOORWAY_Y_MAX), Color("866d58"), 2.0)
	# The bed, crate and door are Sprite2D children created by their existing
	# interaction points, so the room contains only authored Ninja Adventure art.
	if world != null and world.game.house_level >= 1:
		draw_texture_rect_region(floor_texture, Rect2(148, 28, 16, 16), Rect2(176, 0, 16, 16))
	if world != null and world.game.house_level >= 3:
		draw_line(Vector2(126, 12), Vector2(126, 168), Color("8d7962"), 2.0)
