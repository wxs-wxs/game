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
	required_resources = {}
	reward = {}
	failure_text = "火星被风吹灭了。"
	failure_chance = 0.08
	art_texture = ninja_fire
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, -3)

func perform_interaction() -> Dictionary:
	var result: Dictionary = game.add_fire_fuel("campfire")
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": str(result.get("reason", "无法添柴。")), "failed": true}
	_refresh_fire_visual()
	return {"ok": true, "message": "篝火重新燃旺。"}

func can_interact() -> bool:
	if game == null or not super.can_interact():
		return false
	var state := game.fire_state("campfire")
	return float(state.get("fuel_remaining", 0.0)) < float(state.get("fuel_capacity", 0.0))

func prompt_text() -> String:
	if game != null and game.is_fire_active("campfire"):
		return "[E] 添加木材（篝火燃烧中）" if can_interact() else "篝火燃料已满"
	return "[E] 添加木材并点燃篝火"

func setup(manager: GameManager) -> void:
	super.setup(manager)
	_refresh_fire_visual()

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_fire_visual()

func _refresh_fire_visual() -> void:
	if art_sprite != null:
		art_sprite.visible = game != null and game.is_fire_active("campfire")
	queue_redraw()

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
