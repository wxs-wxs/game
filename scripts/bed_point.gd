class_name BedPoint
extends InteractionPoint

const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const BED_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/tileset_bed.png"
var ninja_bed: Texture2D

func _init() -> void:
	ninja_bed = Assets.region(BED_ATLAS, Rect2(0, 0, 48, 32))
	unique_id = "camp_bed"
	display_name = "休息"
	interaction_range = 26.0
	interaction_time = 2.0
	cooldown_time = 8.0
	reward = {}
	art_texture = ninja_bed
	art_scale = Vector2(1, 1)

func configure_indoor(sleeping: bool) -> void:
	unique_id = "house_sleep" if sleeping else "house_rest"
	display_name = "睡觉" if sleeping else "休息"
	interaction_time = 2.0 if sleeping else 1.2
	cooldown_time = 3.0
	indoor_only = true
	sleep_mode = sleeping
	action_id = "sleep" if sleeping else "rest"

## The house has one physical bed. It can be used for a short rest and then
## for the end-of-day sleep interaction; the two actions deliberately share
## one point so the room never renders duplicate beds.
func configure_indoor_combined() -> void:
	unique_id = "house_bed"
	display_name = "床铺"
	interaction_range = 28.0
	interaction_time = 1.2
	cooldown_time = 0.0
	indoor_only = true
	sleep_mode = true
	action_id = "rest"
	rested_this_day = false
	rested_day = -1

var rested_this_day := false
var rested_day := -1

var indoor_only := false
var sleep_mode := false

func prompt_text() -> String:
	if sleep_mode and can_interact():
		return "[E] 睡觉（确认）" if rested_this_day else "[E] 休息"
	return super.prompt_text()

func _process(delta: float) -> void:
	if rested_this_day and game != null and rested_day != int(game.day):
		rested_this_day = false
		rested_day = -1
	super._process(delta)

func perform_interaction() -> Dictionary:
	var hero := game.get_protagonist() if game != null else null
	if hero == null: return {"ok":false, "message":"没有可休息的主角。", "failed":true}
	if sleep_mode:
		if game.phase != GameManager.PHASE_DAY: return {"ok":false, "message":"现在还不能睡觉。", "failed":true}
		if not rested_this_day:
			rested_this_day = true
			rested_day = int(game.day)
			hero.apply_change("energy", 20); hero.apply_change("health", 2)
			return {"ok":true, "message":"在床铺上稍作休整。再次交互即可睡觉。"}
		rested_this_day = false
		game._finish_exploration_day()
		return {"ok":true, "message":"进入夜间结算。"}
	hero.apply_change("energy", 20); hero.apply_change("health", 2)
	return {"ok":true, "message":"恢复了体力。"}

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
