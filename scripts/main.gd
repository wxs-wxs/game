extends Node2D

const InputRouter = preload("res://scripts/presentation/input/input_router.gd")

var game: GameManager
var world: ExplorationWorld
var ui: UIController
var audio
var input_router = InputRouter.new()
var refresh_accumulator := 0.0

func _ready() -> void:
	game = GameManager.new()
	audio = get_node_or_null("/root/AudioService")
	game.audio = audio
	if audio != null:
		audio.load_user_settings()
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
	var result: Dictionary = input_router.route(event, _input_state())
	if not bool(result.get("handled", false)):
		return
	_apply_input_intent(result)

func _input_state() -> Dictionary:
	var build_active: bool = world != null and world.build_mode != null and world.build_mode.active
	var interaction_active: bool = world != null and world.is_interacting()
	var pause_overlay_open: bool = ui != null and ui.has_pause_overlay()
	var menu_paused: bool = ui != null and ui.paused_by_menu
	return {
		"overlay_open": pause_overlay_open or menu_paused,
		"pause_overlay_open": pause_overlay_open,
		"paused_by_menu": menu_paused,
		"build_active": build_active,
		"interaction_active": interaction_active,
	}

func _apply_input_intent(result: Dictionary) -> void:
	var kind := str(result.get("kind", ""))
	var payload_variant: Variant = result.get("payload", {})
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	match kind:
		"cancel":
			if str(payload.get("scope", "")) == "overlay":
				if ui != null: ui.close_overlay()
				return
			if world != null and (world.is_interacting() or (world.build_mode != null and world.build_mode.active)):
				world.cancel_interaction()
				if world.build_mode != null: world.build_mode.active = false
				_mark_input_handled()
		"pause":
			var action := str(payload.get("action", ""))
			if action == "blocked_by_overlay":
				return
			if action == "resume_menu":
				if ui != null: ui._on_resume()
			elif action == "toggle_menu":
				if ui != null: ui.toggle_pause_menu()
			elif action == "toggle_game" and game != null:
				game.toggle_pause()
		"build_mode":
			if ui != null: ui.toggle_build_mode()
		"backpack":
			if ui != null: ui.toggle_backpack()
		"shortcut_help":
			if ui != null: ui._toggle_shortcut_panel()
		"build_cycle":
			if world != null and world.build_mode != null and world.build_mode.active:
				world.build_mode.cycle_blueprint()
				_mark_input_handled()
		"save":
			if ui != null: ui.save_game()
		"load":
			if ui != null: ui.load_game()
		"upgrade":
			if ui != null: ui.upgrade_house()
		"policy":
			if ui != null: ui.cycle_policy()
		"interact":
			if bool(payload.get("blocked", false)):
				if not bool(payload.get("build_active", false)): _mark_input_handled()
				return
			if world != null:
				world.try_interact()
				_mark_input_handled()

func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
