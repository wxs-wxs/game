extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var audio = preload("res://scripts/audio_manager.gd").new()
	root.add_child(audio)
	audio._initialize()
	audio.play_music("day"); audio.play_sfx("button_click"); audio.play_ambience("outdoor")
	assert(audio != null)
	assert(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0)
	game.audio = audio
	assert(game.survivors.size() == 1)
	assert(game.get_protagonist().display_name == "阿禾")
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	assert(world.player is CharacterBody2D)
	assert(world.interactions.size() >= 6)
	var by_id := {}
	for point in world.interactions: by_id[point.unique_id] = point

	var fishing = by_id["river_fishing"]
	world.player.position = fishing.position
	world._process(0.1)
	world.try_interact()
	assert(world.is_interacting())
	var before_fish := 0
	for fish_key in ResourceManager.FISH_KEYS: before_fish += int(game.resources.backpack.get(fish_key, 0))
	world.player.velocity = Vector2.RIGHT
	world.player._physics_process(0.2)
	assert(world.player.velocity == Vector2.ZERO)
	world._process(1.0)
	assert(world.is_interacting())
	world._process(2.2)
	assert(not world.is_interacting())
	var after_fish := 0
	for fish_key in ResourceManager.FISH_KEYS: after_fish += int(game.resources.backpack.get(fish_key, 0))
	assert(after_fish > before_fish)
	var forage = by_id["forest_berries"]
	world.player.position = forage.position; world._process(0.1); world.try_interact()
	var paused_progress: float = forage.interaction_progress
	game.time.paused = true; world._process(1.0); assert(is_equal_approx(forage.interaction_progress, paused_progress)); game.time.paused = false
	world.cancel_interaction(); assert(not forage.interacting)

	var door = by_id["house_door"]
	world.player.position = door.position
	world._process(0.1)
	world.try_interact(); world._process(0.8)
	assert(world.is_inside)
	assert(world.player.interior)
	assert(world.player.global_position.x > 1500.0)
	assert(world.interior_manager.interior != null)
	var rest = world.interior_manager.interior.rest_bed
	world.player.global_position = rest.global_position
	world._process(0.1)
	var before_energy := game.get_protagonist().energy
	world.try_interact(); world._process(1.3)
	assert(game.get_protagonist().energy > before_energy)

	var before_day := game.day
	var sleep = world.interior_manager.interior.sleep_bed
	world.player.global_position = sleep.global_position
	world._process(0.1); world.try_interact(); world._process(2.1)
	assert(game.day >= before_day)

	world.exit_house()
	assert(not world.is_inside)
	assert(not world.player.interior)
	assert(world.player.global_position.x < 1280.0)
	world.player.global_position = Vector2(500, 500)

	game.blueprints.unlock("storage_shelf")
	assert(game.blueprints.is_unlocked("storage_shelf"))
	var build = preload("res://scripts/build_mode_controller.gd").new()
	world.add_child(build); build.setup(world); build.selected_blueprint = "storage_shelf"; build.ghost_position = world.player.global_position + Vector2(16, 0)
	var before_wood := game.resources.get_amount("wood")
	assert(build.confirm_build())
	assert(game.resources.get_amount("wood") < before_wood)
	for i in range(7): build.site._process(1.0)
	assert("storage_shelf" in game.built_facilities)
	assert(game.construction_skill.experience > 0)
	var upgrade_before := game.resources.get_amount("wood")
	var upgrade_result := game.upgrade_house()
	assert(bool(upgrade_result.get("ok", false)))
	assert(game.house_level == 1)
	assert(game.resources.get_amount("wood") < upgrade_before)

	game.resources.add("stone", 3); game.resources.add("metal", 2); game.resources.add("fiber", 2); game.resources.add("cloth", 1)
	assert(game.save_state())
	var saved_food := game.resources.get_amount("food")
	assert(game.load_state())
	assert(game.resources.get_amount("food") == saved_food)
	assert("storage_shelf" in game.built_facilities)
	assert(game.house_level == 1)
	assert(game.resources.get_amount("stone") >= 0)
	var old_data := {"version":2, "resources":{"amounts":{"food":2,"wood":1,"medicine":0}}}
	game.from_dict(old_data)
	assert(game.resources.get_amount("stone") == 4)
	var doomed := GameManager.new(); doomed.start_exploration(); doomed.get_protagonist().health = 1; doomed.get_protagonist().hunger = 0; doomed.resources.amounts["food"] = 0; doomed.day_return_required = true; var doomed_result: Dictionary = doomed.finish_exploration_day(); assert(bool(doomed_result.get("ok", false))); assert(doomed.phase == GameManager.PHASE_ENDED and not doomed.won)
	var long_run := GameManager.new(); long_run.start_exploration()
	for expected_day in range(1, 4):
		long_run.day_return_required = true
		var long_result: Dictionary = long_run.finish_exploration_day()
		assert(bool(long_result.get("ok", false)))
		if long_run.phase == GameManager.PHASE_EVENT:
			var choice_index := _first_affordable_choice(long_run)
			assert(choice_index >= 0)
			var chosen: Dictionary = long_run.choose_event(choice_index)
			assert(bool(chosen.get("ok", false)))
		assert(long_run.phase == GameManager.PHASE_REPORT)
		assert(not long_run.won)
		long_run.continue_from_report()
		assert(long_run.day == expected_day + 1 and long_run.phase == GameManager.PHASE_MORNING)
		long_run.start_exploration()
	var zero_health := GameManager.new(); zero_health.start_exploration(); zero_health.get_protagonist().health = 0; zero_health.advance_exploration(0.1); assert(zero_health.phase == GameManager.PHASE_ENDED and not zero_health.won and zero_health.end_reason.contains("生命值归零"))
	print("SMOKE_OK audio=%s indoor=%s build_xp=%d" % [audio.current_music, world.is_inside, game.construction_skill.experience])
	quit()

func _first_affordable_choice(game: GameManager) -> int:
	for index in range(2):
		if game.resources.can_afford(game.events.choice_cost(index)):
			return index
	return -1
