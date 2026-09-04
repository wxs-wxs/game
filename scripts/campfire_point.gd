class_name CampfirePoint
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const FIRE_SHEET := "res://assets/art/ninja_adventure/FX/Particle/Fire.png"
var ninja_fire: Texture2D

func _init() -> void:
	ninja_fire = Assets.region(FIRE_SHEET, Rect2(0, 0, 16, 12))
	unique_id = "campfire"
	display_name = "生火"
	action_id = "tend_fire"
	interaction_range = 30.0
	interaction_time = 1.5
	cooldown_time = 6.0
	required_resources = {"wood": 1}
	reward = {"fuel": 2}
	failure_text = "火星被风吹灭了。"
	failure_chance = 0.08
	art_texture = ninja_fire
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, -3)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
