class_name WorkbenchArt
extends Node2D

## The Ninja Adventure pack has separate crate/tool sprites but no workbench
## sprite. Compose those CC0 assets with a small pixel-built table so the
## finished facility is recognizable without introducing a new art family.
const NINJA_CRATE := preload("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")
const NINJA_AXE := preload("res://assets/art/ninja_adventure/Items/Tool/Axe.png")
const NINJA_PICKAXE := preload("res://assets/art/ninja_adventure/Items/Tool/Pickaxe.png")

var completed := true
var _sprites: Array[Sprite2D] = []

func setup(is_completed: bool = true) -> void:
	completed = is_completed
	_refresh_sprite_modulate()
	queue_redraw()

func set_completed(is_completed: bool) -> void:
	if completed == is_completed:
		return
	completed = is_completed
	_refresh_sprite_modulate()
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_sprite(NINJA_CRATE, Vector2(0, 8), Vector2(2, 2), 1)
	_add_sprite(NINJA_AXE, Vector2(-14, -13), Vector2.ONE, 2)
	_add_sprite(NINJA_PICKAXE, Vector2(14, -13), Vector2.ONE, 2)
	_refresh_sprite_modulate()
	queue_redraw()

func _add_sprite(texture: Texture2D, at: Vector2, sprite_scale: Vector2, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = sprite_scale
	sprite.z_index = layer
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_sprites.append(sprite)

func _refresh_sprite_modulate() -> void:
	var tint := Color(1.0, 1.0, 1.0, 1.0 if completed else 0.62)
	for sprite in _sprites:
		if is_instance_valid(sprite): sprite.modulate = tint

func _draw() -> void:
	var alpha := 1.0 if completed else 0.62
	# The table uses the same warm wood and dark outline palette as the crate.
	draw_rect(Rect2(-18, -3, 36, 5), Color("9b6745", alpha), true)
	draw_rect(Rect2(-18, -3, 36, 2), Color("d0a06a", alpha), true)
	draw_rect(Rect2(-15, 2, 4, 14), Color("69463a", alpha), true)
	draw_rect(Rect2(11, 2, 4, 14), Color("69463a", alpha), true)
	draw_rect(Rect2(-16, 15, 32, 3), Color("3b3030", alpha), true)
	draw_line(Vector2(-18, -3), Vector2(18, -3), Color("3b3030", alpha), 1.0)
