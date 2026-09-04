class_name ForageSpot
extends InteractionPoint

const NINJA_GRASS := preload("res://assets/art/ninja_adventure/Items/Resource/Grass.png")

func _init() -> void:
	unique_id = "forest_berries"
	# Keep the established interaction label for save/HUD compatibility; the
	# wood reward represents the fallen branches bundled with the berries.
	display_name = "采集浆果"
	action_id = "gather"
	interaction_range = 28.0
	interaction_time = 2.0
	cooldown_time = 10.0
	# Raw berries can be eaten immediately or cooked from the backpack. Berry
	# bushes also yield a small bundle of fallen branches. Keeping the
	# pickup to two item types means it remains useful with the four-slot starter
	# carry limit even after a fish has been caught.
	reward = {"food": 2, "wood": 1}
	failure_text = "灌木里只有苦涩的叶子。"
	failure_chance = 0.12
	art_texture = NINJA_GRASS
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 2)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
