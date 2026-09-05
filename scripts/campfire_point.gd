class_name CampfirePoint
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const FIRE_SHEET := "res://assets/art/ninja_adventure/FX/Particle/Fire.png"
const FIRE_FRAME_COUNT := 6
const FIRE_FRAME_DURATION := 0.12
var ninja_fire: Texture2D
var fire_frame_elapsed := 0.0

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

func _ready() -> void:
	super._ready()
	_configure_fire_animation()
	_refresh_fire_visual()

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
	_configure_fire_animation()
	_refresh_fire_visual()

func _process(delta: float) -> void:
	super._process(delta)
	_refresh_fire_visual()
	if game == null or not game.is_fire_active("campfire") or art_sprite == null:
		return
	fire_frame_elapsed += maxf(0.0, delta)
	while fire_frame_elapsed >= FIRE_FRAME_DURATION:
		fire_frame_elapsed -= FIRE_FRAME_DURATION
		art_sprite.frame = (art_sprite.frame + 1) % FIRE_FRAME_COUNT

func _configure_fire_animation() -> void:
	if art_sprite == null:
		return
	if art_sprite.texture == ninja_fire or art_sprite.hframes != FIRE_FRAME_COUNT or art_sprite.vframes != 1:
		art_sprite.texture = Assets.texture(FIRE_SHEET)
		art_sprite.hframes = FIRE_FRAME_COUNT
		art_sprite.vframes = 1
		art_sprite.frame = 0
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _refresh_fire_visual() -> void:
	if art_sprite == null:
		return
	_configure_fire_animation()
	var active := game != null and game.is_fire_active("campfire")
	art_sprite.visible = active
	if not active:
		art_sprite.frame = 0
		fire_frame_elapsed = 0.0
	queue_redraw()

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
