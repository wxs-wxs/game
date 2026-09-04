class_name RockPileSpot
extends InteractionPoint

const ROCK_TEXTURE := preload("res://assets/art/ninja_adventure/Items/Resource/Rock.png")
var rock_pile_art: Texture2D

func _init() -> void:
	# Use the standalone 16px rock three times instead of cropping a 48px atlas
	# region, which previously included the neighboring boulder and cut it off.
	rock_pile_art = ROCK_TEXTURE
	unique_id = "rock_pile"
	display_name = "开采石堆"
	action_id = "mine_stone"
	interaction_range = 34.0
	interaction_time = 3.0
	cooldown_time = 30.0
	required_tools = ["pickaxe"]
	reward = {"stone": 3}
	failure_text = "石堆太坚硬，镐头只留下了一道浅痕。"
	failure_chance = 0.08
	art_texture = rock_pile_art
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 2)

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()

func _refresh_art_sprite() -> void:
	if art_texture == null:
		return
	if art_sprite != null:
		return
	var offsets := [Vector2(-10, 3), Vector2(0, -4), Vector2(10, 3)]
	for index in range(offsets.size()):
		var rock := Sprite2D.new()
		rock.name = "Rock_%d" % index
		rock.texture = ROCK_TEXTURE
		rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rock.position = offsets[index]
		rock.scale = Vector2(2, 2)
		rock.z_index = 1 + index
		add_child(rock)
		if index == 0:
			art_sprite = rock
