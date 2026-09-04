extends Node2D

var game: GameManager
var world: ExplorationWorld
var ui: UIController
var audio
var refresh_accumulator := 0.0

func _ready() -> void:
	game = GameManager.new()
	audio = preload("res://scripts/audio_manager.gd").new()
	audio.name = "AudioManager"
	add_child(audio)
	game.audio = audio
	world = ExplorationWorld.new()
	world.name = "ExplorationWorld"
	add_child(world)
	world.setup(game)
	ui = UIController.new()
	ui.name = "HUD"
	add_child(ui)
	ui.setup(game, world)
	game.begin_morning()

func _process(delta: float) -> void:
	game.advance(delta)
	refresh_accumulator += delta
	if refresh_accumulator >= 0.08:
		refresh_accumulator = 0.0
		ui.refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and ui != null and ui.close_overlay():
			return
		match event.keycode:
			KEY_SPACE:
				if ui.paused_by_menu: ui._on_resume()
				else: game.toggle_pause()
			KEY_ESCAPE:
				if world != null and (world.is_interacting() or (world.build_mode != null and world.build_mode.active)): world.cancel_interaction(); world.build_mode.active = false
				else: ui.toggle_pause_menu()
			KEY_F5: ui.save_game()
			KEY_F9: ui.load_game()
			KEY_B: ui.toggle_build_mode()
			KEY_U: ui.upgrade_house()
			KEY_P: ui.cycle_policy()
			KEY_K: ui.toggle_backpack()
			KEY_H: ui._toggle_shortcut_panel()
