extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var audio = root.get_node_or_null("AudioService")
	if audio == null:
		audio = preload("res://scripts/audio_service.gd").new()
		audio.headless_mode = true
		root.add_child(audio)
	game.audio = audio
	game.audio.apply_settings({"sfx_enabled": true})
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var ui := UIController.new()
	root.add_child(ui)
	ui.setup(game, world)
	var audio_settings_button := ui.get_node_or_null("HUDRoot/PausePanel/AudioSettingsButton") as Button
	assert(audio_settings_button != null, "暂停菜单应有设置入口")
	assert(ui.get_node_or_null("HUDRoot/AudioSettingsPanel") != null, "应创建音频设置面板")
	assert(ui.has_method("_open_audio_settings"), "设置入口应打开音频设置面板")
	var bar := ui.interaction_progress_bar
	assert(bar != null)
	assert(bar.size.x <= 180.0)
	ui._on_interaction_progress("搜寻废墟", 0.45)
	assert(is_equal_approx(bar.value, 0.45))
	assert(bar.get_parent().visible)
	var before := game.time.paused
	ui._open_pause_overlay("backpack")
	assert(game.time.paused)
	ui._close_pause_overlay("backpack")
	assert(game.time.paused == before)
	audio_settings_button.pressed.emit()
	var audio_settings_panel := ui.get_node_or_null("HUDRoot/AudioSettingsPanel") as Panel
	assert(audio_settings_panel != null and audio_settings_panel.visible)
	var sfx_toggle := audio_settings_panel.get_node_or_null("SfxToggle") as CheckButton
	assert(sfx_toggle != null and sfx_toggle.button_pressed)
	sfx_toggle.button_pressed = false
	sfx_toggle.toggled.emit(false)
	assert(not bool(game.audio.to_settings_dict().get("sfx_enabled", true)))
	assert(float(game.audio.last_snapshot_targets["Music"]) <= -79.0)
	assert(float(game.audio.last_snapshot_targets["Ambience"]) <= -79.0)
	assert(float(game.audio.last_snapshot_targets["SFX"]) <= -79.0)
	sfx_toggle.button_pressed = true
	sfx_toggle.toggled.emit(true)
	assert(bool(game.audio.to_settings_dict().get("sfx_enabled", false)))
	assert(float(game.audio.last_snapshot_targets["Music"]) > -79.0)
	assert(float(game.audio.last_snapshot_targets["Ambience"]) > -79.0)
	ui._close_audio_settings()
	assert(not audio_settings_panel.visible)
	ui.show_event({"id":"test", "data":{"title":"夜间事件", "text":"测试", "choices":[{"label":"等待", "cost":{}}, {"label":"离开", "cost":{}}]}})
	assert(ui.has_pause_overlay())
	ui.toggle_backpack()
	assert(not ui._backpack_open)
	assert(ui.close_overlay())
	assert(ui._event_open)
	print("HUD_INTERACTION_OVERLAY_REGRESSION_OK")
	quit()
