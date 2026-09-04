class_name BranchSpot
extends InteractionPoint

const NINJA_BRANCH := preload("res://assets/art/ninja_adventure/Items/Resource/Branch.png")

## Fallen branches in the open grass provide the first reliable wood source.
func _init() -> void:
	unique_id = "field_branch"
	display_name = "拾取树枝"
	action_id = "collect_branch"
	interaction_range = 24.0
	interaction_time = 0.9
	cooldown_time = 12.0
	respawn_delay = 25.0
	reward = {"wood": 1}
	failure_text = "草地上只剩下潮湿的碎枝。"
	art_texture = NINJA_BRANCH
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 1)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
