extends SceneTree

const InputRouter = preload("res://scripts/presentation/input/input_router.gd")

func _init() -> void:
	var router := InputRouter.new()
	var closed := {"overlay_open": false, "build_active": false, "interaction_active": false}

	var backpack := router.route(_key(KEY_K), closed)
	assert(backpack.get("kind", "") == "backpack")
	assert(bool(backpack.get("handled", false)))

	var physical_backpack := _key(0, KEY_K)
	var physical_result := router.route(physical_backpack, closed)
	assert(physical_result.get("kind", "") == "backpack")

	assert(router.route(_key(KEY_H), closed).get("kind", "") == "shortcut_help")
	assert(router.route(_key(KEY_B), closed).get("kind", "") == "build_mode")
	assert(router.route(_key(KEY_F5), closed).get("kind", "") == "save")
	assert(router.route(_key(KEY_F9), closed).get("kind", "") == "load")
	assert(router.route(_key(KEY_U), closed).get("kind", "") == "upgrade")
	assert(router.route(_key(KEY_P), closed).get("kind", "") == "policy")
	assert(router.route(_key(KEY_E), closed).get("kind", "") == "interact")

	var q_idle := router.route(_key(KEY_Q), closed)
	assert(q_idle.get("kind", "") == "" and not bool(q_idle.get("handled", false)))
	var q_build := router.route(_key(KEY_Q), {"build_active":true})
	assert(q_build.get("kind", "") == "build_cycle" and bool(q_build.get("handled", false)))

	var escape_overlay := router.route(_key(KEY_ESCAPE), {"overlay_open":true})
	assert(escape_overlay.get("kind", "") == "cancel")
	assert(escape_overlay.get("payload", {}).get("scope", "") == "overlay")
	var escape_world := router.route(_key(KEY_ESCAPE), {"interaction_active":true})
	assert(escape_world.get("kind", "") == "cancel")
	assert(escape_world.get("payload", {}).get("scope", "") == "world")
	var escape_pause := router.route(_key(KEY_ESCAPE), closed)
	assert(escape_pause.get("kind", "") == "pause")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	assert(not bool(router.route(right_click, {"overlay_open":true}).get("handled", false)))

	var space := router.route(_key(KEY_SPACE), closed)
	assert(space.get("kind", "") == "pause")
	assert(space.get("payload", {}).get("action", "") == "toggle_game")
	var menu_space := router.route(_key(KEY_SPACE), {"paused_by_menu":true})
	assert(menu_space.get("payload", {}).get("action", "") == "resume_menu")

	var echo := _key(KEY_K)
	echo.echo = true
	assert(not bool(router.route(echo, closed).get("handled", false)))

	print("INPUT_ROUTER_REGRESSION_OK")
	quit()

func _key(keycode: Key, physical_keycode: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = true
	return event
