class_name FishingSpot
extends InteractionPoint

const NINJA_FISHING_ROD := preload("res://assets/art/ninja_adventure/Items/Weapons/FishingRod/Sprite.png")

func _init() -> void:
	unique_id = "river_fishing"
	display_name = "钓鱼"
	action_id = "fish"
	interaction_range = 30.0
	interaction_time = 3.0
	cooldown_time = 12.0
	# Fish are added to the backpack first. The player chooses when and how to
	# process each catch into food.
	reward = {}
	failure_text = "鱼线断了，只捞到一把湿草。"
	failure_chance = 0.18
	art_texture = NINJA_FISHING_ROD
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 1)

func perform_interaction() -> Dictionary:
	if failure_chance > 0.0 and game.rng.randf() < failure_chance:
		return {"ok":true, "message":failure_text, "failed":true}
	var fish_keys: Array = game.resources.fish_items() if game.resources.has_method("fish_items") else ["fish_carp"]
	var fish_key := str(fish_keys[game.rng.randi_range(0, fish_keys.size() - 1)])
	var result: Dictionary = game.resources.catch_fish(fish_key)
	if not bool(result.get("ok", false)):
		return {"ok":false, "message":str(result.get("reason", "背包没有空格。")), "failed":true}
	return {"ok":true, "message":"钓到了%s！可在背包中处理成食物（+%d）。" % [result.get("fish_name", fish_key), int(result.get("food_value", 0))], "fish_key":fish_key, "fish_name":result.get("fish_name", fish_key), "food_value":result.get("food_value", 0)}

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
