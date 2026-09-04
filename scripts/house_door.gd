class_name HouseDoor
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const HOUSE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetHouse.png"
var ninja_door: Texture2D

var interior := false
var world

func configure(manager, inside: bool) -> void:
	world = manager; interior = inside
	display_name = "离开小屋" if interior else "进入小屋"
	action_id = "close_door" if interior else "open_door"
	unique_id = "house_exit" if interior else "house_door"
	interaction_time = 0.7
	cooldown_time = 0.0
	interaction_range = 22.0
	# Keep the shape in sync even for callers that configure after setup().
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			child.shape.radius = interaction_range
	if ninja_door == null:
		ninja_door = Assets.region(HOUSE_ATLAS, Rect2(16, 48, 16, 16))
	art_texture = ninja_door
	art_scale = Vector2(2, 2)

func perform_interaction() -> Dictionary:
	if world == null: return {"ok":false, "message":"房门未连接。"}
	var was_inside := bool(world.is_inside)
	# Use the door's configured direction instead of toggling blindly.  This
	# keeps a stale interaction point from reopening the room during a deferred
	# transition and makes the interior exit deterministic.
	if interior:
		if not was_inside: return {"ok":false, "message":"小屋已经关闭。", "failed":true}
		world.exit_house()
	else:
		if was_inside: return {"ok":false, "message":"已经在小屋内。", "failed":true}
		world.enter_house()
	if was_inside == bool(world.is_inside):
		return {"ok":false, "message":"房门暂时无法使用。", "failed":true}
	if world.game.audio != null: world.game.audio.play_sfx("door_open" if not interior else "door_close")
	return {"ok":true, "message":"已%s。" % ("离开小屋" if interior else "进入小屋")}

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
