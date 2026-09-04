class_name RuinSpot
extends InteractionPoint

const NINJA_CHEST := preload("res://assets/art/ninja_adventure/Items/Treasure/LittleTreasureChest.png")

func _init() -> void:
	unique_id = "old_ruins"
	display_name = "搜寻废墟"
	action_id = "search_ruins"
	interaction_range = 30.0
	interaction_time = 3.5
	cooldown_time = 16.0
	# Ruins provide medical and metal supplies; stone remains restricted to pebble
	# interactions so fishing/salvage cannot bypass the gathering chain.
	reward = {"medicine": 1, "metal": 2}
	failure_text = "碎玻璃划伤了手，废墟里没有更多东西。"
	failure_chance = 0.25
	# Use the pack's existing chest as the salvage marker.
	art_texture = NINJA_CHEST
	art_scale = Vector2(2, 2)

func perform_interaction() -> Dictionary:
	var original_chance := failure_chance
	if game != null and game.torch_bonus_pending: failure_chance = maxf(0.0, failure_chance - 0.20)
	var result := super.perform_interaction()
	failure_chance = original_chance
	if game != null and game.torch_bonus_pending:
		game.torch_bonus_pending = false
		if bool(result.get("failed", false)): result["message"] = "火把照亮了碎石，但仍未找到完整补给。"
	if bool(result.get("failed", false)) and game != null:
		var hero := game.get_protagonist()
		if hero != null:
			hero.apply_change("health", -5)
			hero.injured = true
	return result


func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
