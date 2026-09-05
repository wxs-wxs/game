extends SceneTree

const AudioServiceResource = preload("res://scripts/audio_service.gd")

const BUS_PARENTS := {
	"Master": "", "Music": "Master", "Ambience": "Master", "Environment": "Ambience",
	"Weather": "Ambience", "Fire": "Ambience", "SFX": "Master", "World": "SFX",
	"UI": "SFX", "Critical": "SFX", "Voice": "Master",
}

func _init() -> void:
	var service: AudioService = AudioServiceResource.new()
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
	assert(service.emit_event("does.not.exist") == "missing")
	assert(service.event_log.back().result == "missing")
	var fallback_result := service.emit_event("ui.open")
	assert(fallback_result == "headless")
	assert(service.event_log.back().fallback == true)
	assert(service.event_log.back().resolved_id == "ui.confirm")

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
	var music_log_size := service.event_log.size()
	service.set_world_state({"phase": "exploration", "weather": "rain", "location": "outdoor", "fire_lit": true})
	assert(service.event_log.size() == music_log_size, "state de-duplication must not emit events")

	service.apply_settings({"master": 0.5, "music": 0.25, "ambience": 0.75, "sfx": 1.2})
	var settings_data := service.to_settings_dict()
	assert(is_equal_approx(settings_data.master, 0.5))
	assert(is_equal_approx(settings_data.music, 0.25))
	assert(is_equal_approx(settings_data.ambience, 0.75))
	assert(is_equal_approx(settings_data.sfx, 1.0))
	var base_targets := service.last_snapshot_targets.duplicate(true)
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
	print("AUDIO_SERVICE_OK buses=%d events=%d music=%s layers=%d" % [BUS_PARENTS.size(), service.event_log.size(), service.active_music_id, service.active_ambience_layers.size()])
	quit()
