extends RefCounted

## Translates input events into application-facing intents.
## The router has no references to UI, world, or game objects.

const ACTION_PAUSE_GAME := StringName("pause_game")
const ACTION_PAUSE_MENU := StringName("pause_menu")
const ACTION_BUILD_MODE := StringName("build_mode")
const ACTION_BACKPACK := StringName("backpack_toggle")
const ACTION_SHORTCUT_HELP := StringName("shortcut_help")
const ACTION_BUILD_CYCLE := StringName("build_cycle")
const ACTION_CANCEL := StringName("cancel_action")
const ACTION_INTERACT := StringName("interact")

func route(event: InputEvent, state: Dictionary) -> Dictionary:

	if event == null or not _is_press(event):
		return _unhandled()

	var overlay_open := bool(state.get("overlay_open", false))
	var build_active := bool(state.get("build_active", false))
	var interaction_active := bool(state.get("interaction_active", false))
	var paused_by_menu := bool(state.get("paused_by_menu", false))
	var pause_overlay_open := bool(state.get("pause_overlay_open", state.get("has_pause_overlay", false)))

	# Escape first closes the active UI overlay, then cancels world work, and
	# finally opens the pause menu. This is the same precedence as Main._input.
	if _pressed(event, ACTION_PAUSE_MENU, KEY_ESCAPE):
		if overlay_open:
			return _result("cancel", true, ACTION_PAUSE_MENU, {"scope":"overlay"})
		if build_active or interaction_active:
			return _result("cancel", true, ACTION_PAUSE_MENU, {"scope":"world"})
		return _result("pause", true, ACTION_PAUSE_MENU, {"action":"toggle_menu"})

	if _pressed(event, ACTION_PAUSE_GAME, KEY_SPACE):
		if pause_overlay_open:
			return _result("pause", true, ACTION_PAUSE_GAME, {"action":"blocked_by_overlay"})
		if paused_by_menu:
			return _result("pause", true, ACTION_PAUSE_GAME, {"action":"resume_menu"})
		return _result("pause", true, ACTION_PAUSE_GAME, {"action":"toggle_game"})

	if _pressed(event, ACTION_BUILD_MODE, KEY_B):
		return _result("build_mode", true, ACTION_BUILD_MODE)
	if _pressed(event, ACTION_BACKPACK, KEY_K):
		return _result("backpack", true, ACTION_BACKPACK)
	if _pressed(event, ACTION_SHORTCUT_HELP, KEY_H):
		return _result("shortcut_help", true, ACTION_SHORTCUT_HELP)
	if _pressed(event, ACTION_BUILD_CYCLE, KEY_Q):
		if build_active:
			return _result("build_cycle", true, ACTION_BUILD_CYCLE)
		return _unhandled()

	if _pressed(event, ACTION_CANCEL, KEY_ESCAPE):
		if overlay_open:
			return _result("cancel", true, ACTION_CANCEL, {"scope":"overlay"})
		if build_active or interaction_active:
			return _result("cancel", true, ACTION_CANCEL, {"scope":"world"})
		return _unhandled()

	if _pressed(event, ACTION_INTERACT, KEY_E):
		return _result("interact", true, ACTION_INTERACT, {"blocked":overlay_open or paused_by_menu})

	if _matches_key(event, KEY_F5):
		return _result("save", true, StringName("save_game"))
	if _matches_key(event, KEY_F9):
		return _result("load", true, StringName("load_game"))
	if _matches_key(event, KEY_U):
		return _result("upgrade", true, StringName("upgrade_house"))
	if _matches_key(event, KEY_P):
		return _result("policy", true, StringName("cycle_policy"))

	return _unhandled()

func _result(kind: String, handled: bool, action: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"kind":kind, "handled":handled, "action":String(action)}
	if not payload.is_empty():
		result["payload"] = payload.duplicate(true)
	return result

func _unhandled() -> Dictionary:
	return {"kind":"", "handled":false}

func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false

func _pressed(event: InputEvent, action: StringName, fallback_key: Key) -> bool:
	if event.is_action_pressed(action):
		return true
	return _matches_key(event, fallback_key)

func _matches_key(event: InputEvent, fallback_key: Key) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.keycode == fallback_key or key_event.physical_keycode == fallback_key
