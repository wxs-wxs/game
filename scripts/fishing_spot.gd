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
	# Fish are added to the backpack first. The player chooses whether to eat the
	# catch raw or cook it into a much more restorative meal.
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
	var fish_name := game.resources.fish_name(fish_key) if game.resources.has_method("fish_name") else fish_key
	if not game.resources.can_collect_rewards({fish_key: 1}):
		return {"ok":false, "message":"背包没有空格。", "failed":true}
	return {"ok":true, "message":"钓到了%s！可以生吃，也可以在背包中烤熟。" % fish_name, "rewards":{fish_key:1}, "fish_key":fish_key, "fish_name":fish_name, "food_value":game.resources.fish_food_value(fish_key)}

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
