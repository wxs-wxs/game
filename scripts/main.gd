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
		if _input_action_pressed(event, "pause_menu", KEY_ESCAPE) and ui != null and ui.close_overlay():
			return
		if _input_action_pressed(event, "pause_game", KEY_SPACE):
			if ui.has_pause_overlay():
				return
			if ui.paused_by_menu: ui._on_resume()
			else: game.toggle_pause()
		elif _input_action_pressed(event, "pause_menu", KEY_ESCAPE):
			if world != null and (world.is_interacting() or (world.build_mode != null and world.build_mode.active)):
				world.cancel_interaction()
				world.build_mode.active = false
			else:
				ui.toggle_pause_menu()
		elif _input_action_pressed(event, "build_mode", KEY_B):
			ui.toggle_build_mode()
		elif _input_action_pressed(event, "backpack_toggle", KEY_K):
			ui.toggle_backpack()
		elif _input_action_pressed(event, "shortcut_help", KEY_H):
			ui._toggle_shortcut_panel()
		elif _input_action_pressed(event, "build_cycle", KEY_Q):
			if world != null and world.build_mode != null and world.build_mode.active:
				world.build_mode.cycle_blueprint()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			ui.save_game()
		elif event.keycode == KEY_F9 or event.physical_keycode == KEY_F9:
			ui.load_game()
		elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
			ui.upgrade_house()
		elif event.keycode == KEY_P or event.physical_keycode == KEY_P:
			ui.cycle_policy()

func _input_action_pressed(event: InputEvent, action: StringName, fallback_key: Key) -> bool:
	if event.is_action_pressed(action):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and (key_event.keycode == fallback_key or key_event.physical_keycode == fallback_key)
	return false
