class_name FireplacePoint
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const FIRE_SHEET := "res://assets/art/ninja_adventure/FX/Particle/Fire.png"

var ninja_fire: Texture2D
var lit := false
var fire_sprite: Sprite2D

func _init() -> void:
	ninja_fire = Assets.region(FIRE_SHEET, Rect2(0, 0, 16, 12))
	unique_id = "house_fireplace"
	display_name = "炉火"
	interaction_range = 28.0
	interaction_time = 1.2
	cooldown_time = 0.0
	required_resources = {"wood": 1}
	reward = {}
	action_id = "tend_fire"
	indoor_only = true

var indoor_only := true

func setup(manager: GameManager) -> void:
	super.setup(manager)
	if game != null and bool(game.house_fire_lit):
		lit = true
	_refresh_fire_visual()

func can_interact() -> bool:
	return not lit and super.can_interact()

func interact() -> Dictionary:
	if lit:
		return {"ok":false, "reason":"炉火已经点燃，烟囱正在冒烟。", "failed":true}
	return super.interact()

func perform_interaction() -> Dictionary:
	lit = true
	if game != null:
		game.house_fire_lit = true
		game.daily_log.append("屋内炉火已经点燃，烟囱开始冒烟。")
	_refresh_fire_visual()
	return {"ok":true, "message":"炉火点燃了，烟囱开始冒烟。"}

func prompt_text() -> String:
	if lit:
		return "炉火已燃（烟囱冒烟）"
	if game != null and not game.resources.can_afford(required_resources):
		return "炉火（需要木材）"
	return "[E] 添加木材并点燃炉火"

func _refresh_fire_visual() -> void:
	if lit:
		if fire_sprite == null:
			fire_sprite = Sprite2D.new()
			fire_sprite.name = "FireSprite"
			fire_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fire_sprite.z_index = 2
			add_child(fire_sprite)
		fire_sprite.texture = ninja_fire
		fire_sprite.position = Vector2(0, -7)
		fire_sprite.scale = Vector2(2, 2)
		fire_sprite.show()
	elif fire_sprite != null:
		fire_sprite.hide()
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	if fire_sprite != null and lit:
		fire_sprite.position = Vector2(0, -7.0 + sin(Time.get_ticks_msec() * 0.012) * 0.8)

func _draw() -> void:
	# The hearth remains visible while unlit; the pack fire sprite is layered on
	# top after wood has been consumed.
	draw_circle(Vector2(0, 1), 13.0, Color("101a1c", 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4), Vector2(-8, -4), Vector2(8, -4), Vector2(12, 4),
		Vector2(8, 8), Vector2(-8, 8)
	]), Color("5e4b3d"))
	draw_line(Vector2(-8, 4), Vector2(8, 4), Color("b58a5b", 0.85), 2.0)
	if not lit:
		draw_line(Vector2(-6, 1), Vector2(6, 6), Color("8b6244"), 2.0)
		draw_line(Vector2(6, 1), Vector2(-6, 6), Color("8b6244"), 2.0)
