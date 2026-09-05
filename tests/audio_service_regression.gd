extends SceneTree

const AudioServiceResource = preload("res://scripts/audio_service.gd")
const AudioSfxControllerResource = preload("res://scripts/audio_sfx_controller.gd")
const AudioMusicControllerResource = preload("res://scripts/audio_music_controller.gd")
const AudioAmbienceControllerResource = preload("res://scripts/audio_ambience_controller.gd")

const BUS_PARENTS := {
	"Master": "", "Music": "Master", "Ambience": "Master", "Environment": "Ambience",
	"Weather": "Ambience", "Fire": "Ambience", "SFX": "Master", "World": "SFX",
	"UI": "SFX", "Critical": "SFX", "Voice": "Master",
}

func _init() -> void:
	var service = AudioServiceResource.new()
	service.headless_mode = true
	service._music.headless_mode = true
	service._ambience.headless_mode = true
	service._sfx.headless_mode = true
	get_root().add_child(service)

	for bus_name in BUS_PARENTS:
		var bus_index := AudioServer.get_bus_index(bus_name)
		assert(bus_index >= 0, "missing bus: %s" % bus_name)
		assert(AudioServer.get_bus_send(bus_index) == BUS_PARENTS[bus_name], "wrong parent: %s" % bus_name)

	var first_result := service.emit_event("ui.confirm")
	assert(first_result == "headless", "headless event should be recorded")
	assert(service.event_log.size() == 1)
	assert(service.emit_event("interaction.blocked") == "headless")
	service.set_world_state({"phase": "exploration", "weather": "rain", "location": "interior", "fire_lit": false})
	assert(service.world_state.location == "interior")
	service.push_snapshot("pause")
	assert(service.last_snapshot_targets["Music"] < base_volume_db(service, "Music"))
	service.pop_snapshot("pause")
	assert(service.emit_event("does.not.exist") == "missing")
	assert(service.event_log.back().result == "missing")
	var fallback_result := service.emit_event("ui.open")
	assert(fallback_result == "headless")
	assert(service.event_log.back().fallback == true)
	assert(service.event_log.back().resolved_id == "ui.confirm")
	assert(service._sfx._players.is_empty(), "headless mode must not create players")
	assert(service._stream_for_cue(AudioCue.new()) is AudioStreamWAV, "missing streams use silent WAV fallback")

	var limited_cue: AudioCue = service.catalog.get_cue("ui.confirm")
	limited_cue.cooldown_ms = 0
	limited_cue.max_instances = 1
	assert(service.emit_event("ui.confirm") == "suppressed", "active max_instances must suppress")
	var critical_cue: AudioCue = service.catalog.get_cue("player.death")
	critical_cue.cooldown_ms = 0
	assert(service.emit_event("player.death") == "headless", "Critical must retain a reserved channel")
	service.clear_snapshots()

	service.set_world_state({"phase": "exploration", "weather": "rain", "location": "outdoor", "fire_lit": true})
	assert(service.active_music_id == "exploration_rain")
	assert(service.active_ambience_layers.has("Environment"))
	assert(service.active_ambience_layers.has("Weather"))
	assert(service.active_ambience_layers.has("Fire"))
	var music_log_size: int = service.event_log.size()
	service.set_world_state({"phase": "exploration", "weather": "rain", "location": "outdoor", "fire_lit": true})
	assert(service.event_log.size() == music_log_size, "state de-duplication must not emit events")
	service.set_world_state({"phase": "exploration", "weather": "rain", "threat": "high", "location": "outdoor", "fire_lit": true})
	assert(service.active_music_id == "exploration_threat", "high threat selects tense music state")
	assert(service.last_snapshot_targets["Music"] < base_volume_db(service, "Music"), "danger snapshot ducks music")
	service.set_world_state({"phase": "exploration", "weather": "rain", "threat": "low", "location": "outdoor", "fire_lit": true})
	assert(service.active_music_id == "exploration_rain")

	service.apply_settings({"master": 0.5, "music": 0.25, "ambience": 0.75, "sfx": 1.2})
	var settings_data := service.to_settings_dict()
	assert(is_equal_approx(settings_data.master, 0.5))
	assert(is_equal_approx(settings_data.music, 0.25))
	assert(is_equal_approx(settings_data.ambience, 0.75))
	assert(is_equal_approx(settings_data.sfx, 1.0))
	var base_targets: Dictionary = service.last_snapshot_targets.duplicate(true)
	service.push_snapshot("pause")
	assert(service.last_snapshot_targets["Music"] < base_targets["Music"])
	service.pop_snapshot("pause")
	assert(is_equal_approx(service.last_snapshot_targets["Music"], base_targets["Music"]))
	service.push_snapshot("modal")
	service.push_snapshot("pause")
	service.clear_snapshots()
	assert(is_equal_approx(service.last_snapshot_targets["World"], base_targets["World"]))

	service.set_listener_position(Vector2(12, 18))
	assert(service.listener_position == Vector2(12, 18))
	assert(service._rng != null, "service owns a private RNG")
	assert(service.save_user_settings() == OK, "settings should save through ConfigFile")
	var restored = AudioServiceResource.new()
	restored.headless_mode = true
	assert(restored.load_user_settings(), "settings should load through ConfigFile")
	assert(is_equal_approx(restored.to_settings_dict().music, 0.25))

	var routing: AudioSfxController = AudioSfxControllerResource.new()
	routing.initialize(false)
	get_root().add_child(routing)
	routing.set_listener_position(Vector2(40, 50))
	assert(routing._listener != null and routing._listener.position == Vector2(40, 50))
	if routing.is_inside_tree():
		assert(routing._listener.is_current(), "scene-tree listener should be current")
	var wav: AudioStream = service._silent()
	var world_cue := _cue("world.test", "World", "none", 10, "oldest")
	world_cue.max_instances = 1
	assert(routing.play_cue(world_cue, wav) == "played")
	var first_player: Node = routing._players[0]
	assert(routing.play_cue(world_cue, wav) == "suppressed", "oldest must reject equal priority")
	world_cue.priority = 20
	assert(routing.play_cue(world_cue, wav) == "played", "oldest may reclaim a lower-priority same-group player")
	assert(routing.active_count("World") == 1)
	assert(first_player.bus == "World")
	var spatial_cue := _cue("spatial.test", "World", "point", 30, "drop")
	spatial_cue.max_distance = 123.0
	assert(routing.play_cue(spatial_cue, wav, {"position": Vector2(7, 9)}) == "played")
	var spatial_player: AudioStreamPlayer2D = routing._players[1]
	assert(spatial_player is AudioStreamPlayer2D)
	assert(is_equal_approx(spatial_player.max_distance, 123.0))
	assert(spatial_player.position == Vector2(7, 9))
	var spatial_reset := _cue("spatial.reset", "World", "point", 30, "drop")
	assert(routing.play_cue(spatial_reset, wav) == "played")
	assert(is_equal_approx(float(spatial_player.get_meta("audio_max_distance")), 0.0), "reused spatial player resets logical max_distance")
	var ui_cue := _cue("ui.test", "UI", "none", 30, "drop")
	assert(routing.play_cue(ui_cue, wav) == "played")
	assert(routing._players.size() == 2, "spatial and non-spatial pools must not cross-reuse")

	var low_priority := _cue("priority.test", "Critical", "none", 10, "lowest_priority")
	low_priority.max_instances = 1
	assert(routing.play_cue(low_priority, wav) == "played")
	assert(routing.play_cue(low_priority, wav) == "suppressed", "equal priority is not eligible for stealing")
	low_priority.priority = 20
	assert(routing.play_cue(low_priority, wav) == "played", "higher priority may steal lower priority")

	var music: AudioMusicController = AudioMusicControllerResource.new()
	music.initialize(false)
	get_root().add_child(music)
	music.set_music("a", wav)
	music.set_music("b", wav)
	assert(music.active_music_id == "b" and music._players.size() == 2, "music uses double-buffer state")
	var ambience: AudioAmbienceController = AudioAmbienceControllerResource.new()
	ambience.initialize(false)
	get_root().add_child(ambience)
	ambience.set_layers({"Environment": "loop"}, {"Environment": wav})
	assert(ambience.fade_seconds > 0.0)
	assert(ambience.active_layers.has("Environment"))
	ambience.set_layers({}, {})
	ambience.set_layers({"Environment": "loop"}, {"Environment": wav})
	assert(ambience.active_layers.has("Environment"), "rapid ambience reactivation should remain active")
	print("AUDIO_SERVICE_OK buses=%d events=%d music=%s layers=%d" % [BUS_PARENTS.size(), service.event_log.size(), service.active_music_id, service.active_ambience_layers.size()])
	for node in [ambience, music, routing, restored, service]:
		if is_instance_valid(node):
			node.free()
	quit()

func _cue(id: String, bus: String, spatial: String, priority: int, steal: String) -> AudioCue:
	var cue := AudioCue.new()
	cue.id = id
	cue.output_bus = bus
	cue.spatial_mode = spatial
	cue.priority = priority
	cue.steal_policy = steal
	cue.cooldown_ms = 0
	cue.max_instances = 1
	return cue

func base_volume_db(service, bus_name: String) -> float:
	var data: Dictionary = service.to_settings_dict()
	var value := 1.0
	if bus_name == "Music":
		value = data.music
	elif bus_name in ["Ambience", "Environment", "Weather", "Fire"]:
		value = data.ambience
	elif bus_name in ["SFX", "World", "UI", "Critical"]:
		value = data.sfx
	return -80.0 if value <= 0.0001 else linear_to_db(value)
