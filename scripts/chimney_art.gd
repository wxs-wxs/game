class_name ChimneyArt
extends Node2D

var game: GameManager
var elapsed := 0.0

func setup(manager: GameManager) -> void:
	game = manager
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	# A compact pixel chimney sits on the authored house roof. Smoke is only
	# drawn after the indoor fireplace has consumed wood and been lit.
	draw_rect(Rect2(-6, -10, 12, 17), Color("2a292a"), true)
	draw_rect(Rect2(-8, -11, 16, 4), Color("171b1d"), true)
	draw_rect(Rect2(-3, -9, 3, 14), Color("765447", 0.85), true)
	if game == null or not bool(game.house_fire_lit):
		return
	var drift := sin(elapsed * 1.7) * 2.5
	for puff in range(4):
		var rise := float(puff) * 11.0
		var wobble := sin(elapsed * 1.25 + float(puff) * 1.4) * (1.5 + float(puff))
		var alpha := 0.42 - float(puff) * 0.075
		var radius := 4.0 - float(puff) * 0.45
		draw_circle(Vector2(drift + wobble, -15.0 - rise), radius, Color("b9c0b5", alpha))

