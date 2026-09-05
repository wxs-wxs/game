extends SceneTree

const AudioServiceResource = preload("res://scripts/audio_service.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := _ensure_audio_service()
	var game := GameManager.new()
	game.audio = audio
	game.weather = "暴雨"
	game.start_exploration()

	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)

	var ui := UIController.new()
	root.add_child(ui)
	ui.setup(game, world)

	await process_frame
	await process_frame

	assert(_has_event(audio, "day.dawn"))
	assert(audio.active_music_id == "exploration_rain")
	assert(audio.active_ambience_layers.has("Environment"))
	assert(audio.active_ambience_layers.has("Weather"))
	assert(not audio.active_ambience_layers.has("Fire"))

	var door := _point(world, "house_door")
	world.player.global_position = door.global_position
	world._process(0.1)
	world.try_interact()
	world._process(0.8)
	assert(_has_event(audio, "door.open"))
	assert(world.is_inside)
	assert(world.player.interior)
	assert(audio.active_music_id == "interior")
	assert(audio.active_ambience_layers.has("Weather"))
	assert(not audio.active_ambience_layers.has("Fire"))

	var interior: HouseInterior = world.interior_manager.interior
	var fireplace: FireplacePoint = interior.fireplace
	world.player.global_position = fireplace.global_position
	world._process(0.1)
	world.try_interact()
	world._process(1.3)
	assert(_has_event(audio, "fire.ignite"))
	assert(game.is_fire_active("house_fireplace"))
	assert(audio.active_ambience_layers.has("Fire"))

	game.tick_fire(110.0)
	assert(_has_event(audio, "fire.fuel_low"))
	game.tick_fire(20.0)
	assert(_has_event(audio, "fire.extinguish"))
	assert(not audio.active_ambience_layers.has("Fire"))

	var exit_door := _point(world, "house_exit")
	world.player.global_position = exit_door.global_position
	world._process(0.1)
	world.try_interact()
	world._process(0.8)
	assert(_has_event(audio, "door.close"))
	assert(not world.is_inside)
	assert(not world.player.interior)
	ui._on_resume()

	var tree := _point(world, "forest_tree")
	world.player.global_position = tree.global_position
	world._process(0.1)
	world.try_interact()
	assert(_last_event_id(audio) == "interaction.blocked")

	var forage := _point(world, "forest_berries")
	world.player.global_position = forage.global_position
	world._process(0.1)
	forage.failure_chance = 0.0
	world.try_interact()
	assert(_last_event_id(audio) == "interaction.start")
	world.cancel_interaction()
	assert(_last_event_id(audio) == "interaction.cancel")

	forage.failure_chance = 1.0
	world.try_interact()
	world._process(2.2)
	assert(_has_event(audio, "interaction.failed"))
	assert(not forage.interacting)

	forage.failure_chance = 0.0
	world.try_interact()
	world._process(2.2)
	assert(_has_event(audio, "interaction.complete"))

	var fishing := _point(world, "river_fishing")
	fishing.failure_chance = 0.0
	world.player.global_position = fishing.global_position
	world._process(0.1)
	world.try_interact()
	assert(_has_event(audio, "fishing.cast"))
	world._process(3.2)
	assert(_has_event(audio, "interaction.complete"))

	world.player.global_position = Vector2(180, 155)
	world._process(0.1)
	var build: BuildModeController = world.build_mode
	build.selected_blueprint = "storage_shelf"
	build.active = true
	build.ghost_position = Vector2.ZERO
	assert(not build.confirm_build())
	assert(_has_event(audio, "build.invalid"))

	build.active = true
	build.selected_blueprint = "storage_shelf"
	build._update_ghost_position()
	assert(build.can_place())
	assert(build.confirm_build())
	assert(_has_event(audio, "build.place"))
	game.time.paused = false
	for _step in range(10):
		if build.site == null or not is_instance_valid(build.site) or build.site.completed:
			break
		build.site.advance_build(1.0)
	assert(_has_event(audio, "build.complete"))

	ui.toggle_pause_menu()
	assert(_has_snapshot_duck(audio, "Music"))
	ui.toggle_backpack()
	assert(_has_snapshot_duck(audio, "World"))
	ui._open_fish_processing_from_backpack()
	assert(_has_snapshot_duck(audio, "World"))
	ui.close_fish_processing()
	ui._on_resume()
	assert(not game.time.paused)
	assert(_snapshot_target_equals_base(audio, "Music"))

	ui._on_storage_open_requested()
	assert(_has_snapshot_duck(audio, "World"))
	ui.close_storage()
	ui.toggle_log_panel()
	assert(_has_snapshot_duck(audio, "World"))
	ui.close_log_panel()

	ui.save_game()
	assert(_has_event(audio, "ui.save_complete"))
	ui.load_game()
	assert(_has_event(audio, "ui.load_complete"))

	game.day_return_required = true
	game.events.definitions = {}
	var night := game.finish_exploration_day()
	assert(bool(night.get("ok", false)))
	assert(game.phase == GameManager.PHASE_REPORT)
	assert(_has_event(audio, "night.report"))
	ui.refresh()
	assert(ui._report_open)
	assert(_has_snapshot_duck(audio, "World"))
	ui._on_report_continue()
	assert(game.phase == GameManager.PHASE_MORNING)
	assert(_has_event(audio, "day.dawn"))

	var doom_audio := AudioServiceResource.new()
	doom_audio.name = "AudioServiceDoom"
	doom_audio.headless_mode = true
	root.add_child(doom_audio)
	var doomed := GameManager.new()
	doomed.audio = doom_audio
	doomed.start_exploration()
	var doom_world := ExplorationWorld.new()
	root.add_child(doom_world)
	doom_world.setup(doomed)
	await process_frame
	doomed.get_protagonist().health = 0
	doomed.advance_exploration(0.1)
	assert(_has_event(doom_audio, "player.death"))
	assert(_has_event(doom_audio, "game.over"))
	assert(doom_audio.active_music_id == "game_over")

	print("AUDIO_GAMEPLAY_REGRESSION_OK")
	quit()

func _ensure_audio_service() -> Node:
	var audio := root.get_node_or_null("AudioService")
	if audio == null:
		audio = AudioServiceResource.new()
		audio.name = "AudioService"
		root.add_child(audio)
	audio.headless_mode = true
	audio._sync_controller_modes()
	return audio

func _point(world: ExplorationWorld, id: String) -> InteractionPoint:
	for point in world.interactions:
		if is_instance_valid(point) and point.unique_id == id:
			return point
	assert(false, "missing interaction point: %s" % id)
	return null

func _event_ids(audio: Node) -> Array[String]:
	var ids: Array[String] = []
	for row in audio.event_log:
		ids.append(str(row.get("event_id", "")))
	return ids

func _has_event(audio: Node, event_id: String) -> bool:
	return _event_ids(audio).has(event_id)

func _last_event_id(audio: Node) -> String:
	if audio.event_log.is_empty():
		return ""
	return str(audio.event_log.back().get("event_id", ""))

func _base_volume_db(audio: Node, bus_name: String) -> float:
	var settings: Dictionary = audio.to_settings_dict()
	var value := 1.0
	if bus_name == "Music":
		value = float(settings.get("music", 1.0))
	elif bus_name in ["Ambience", "Environment", "Weather", "Fire"]:
		value = float(settings.get("ambience", 1.0))
	elif bus_name in ["SFX", "World", "UI", "Critical"]:
		value = float(settings.get("sfx", 1.0))
	return -80.0 if value <= 0.0001 else linear_to_db(value)

func _has_snapshot_duck(audio: Node, bus_name: String) -> bool:
	return float(audio.last_snapshot_targets.get(bus_name, _base_volume_db(audio, bus_name))) < _base_volume_db(audio, bus_name)

func _snapshot_target_equals_base(audio: Node, bus_name: String) -> bool:
	return is_equal_approx(float(audio.last_snapshot_targets.get(bus_name, 0.0)), _base_volume_db(audio, bus_name))
