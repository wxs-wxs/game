class_name TreeSpot
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const NATURE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png"
var tree_art: Texture2D
var stump_art: Texture2D
var stump_scale := Vector2(2, 2)
var is_stump := false
var is_small_tree := false
var regrow_remaining := 0.0
const REGROW_DELAY := 45.0

## Forest trees are locked behind the stone axe. The requirement lives on the
## point itself so prompts, markers, saves, and future interaction consumers all
## observe the same rule.
func _init() -> void:
	tree_art = Assets.region(NATURE_ATLAS, Rect2(0, 0, 32, 32))
	stump_art = Assets.region(NATURE_ATLAS, Rect2(0, 144, 32, 16))
	unique_id = "forest_tree"
	display_name = "砍伐树木"
	action_id = "chop"
	interaction_range = 34.0
	interaction_time = 3.2
	cooldown_time = 32.0
	required_tools = ["axe"]
	reward = {"wood": 4}
	failure_text = "树干太硬，斧刃崩出了缺口。"
	failure_chance = 0.06
	art_texture = tree_art
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, -3)

func configure_small_tree(texture: Texture2D, scale_value: Vector2) -> void:
	is_small_tree = true
	tree_art = texture
	display_name = "砍伐小树"
	reward = {"wood": 2}
	art_texture = tree_art
	art_scale = scale_value
	stump_scale = scale_value
	art_offset = Vector2(0, -4)

func _process(delta: float) -> void:
	super._process(delta)
	if is_stump and (game == null or not game.time.paused):
		regrow_remaining = maxf(0.0, regrow_remaining - delta)
		if regrow_remaining <= 0.0:
			is_stump = false
			cooldown_remaining = 0.0
			set_art(tree_art, art_scale, art_offset)
			queue_redraw()

func perform_interaction() -> Dictionary:
	if failure_chance > 0.0 and game.rng.randf() < failure_chance:
		return {"ok":true, "message":failure_text, "failed":true}
	is_stump = true
	regrow_remaining = REGROW_DELAY
	set_art(stump_art, stump_scale, Vector2(0, 4))
	var amount := int(reward.get("wood", 0))
	var kind := "小树" if is_small_tree else "树木"
	return {"ok":true, "message":"砍下木材 +%d，%s变成树桩；约 %d 秒后重新长成。" % [amount, kind, int(REGROW_DELAY)], "stump":true}

func refresh_tree_art() -> void:
	if is_stump:
		set_art(stump_art, stump_scale, Vector2(0, 4))
	else:
		set_art(tree_art, art_scale, art_offset)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
