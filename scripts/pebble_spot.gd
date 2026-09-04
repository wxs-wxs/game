class_name PebbleSpot
extends InteractionPoint

const NINJA_ROCK := preload("res://assets/art/ninja_adventure/Items/Resource/Rock.png")

## A small field stone pickup. Keeping a dedicated point type makes the
## stone source explicit and gives future respawn/biome systems a safe hook.
func _init() -> void:
	unique_id = "field_pebble"
	display_name = "拾取小石子"
	action_id = "pickup"
	interaction_range = 24.0
	interaction_time = 0.8
	cooldown_time = 14.0
	respawn_delay = 22.0
	reward = {"stone": 1}
	failure_text = "这片草地没有能用的石子。"
	art_texture = NINJA_ROCK
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 2)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
