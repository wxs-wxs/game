extends SceneTree

const AudioCatalogResource = preload("res://scripts/audio_catalog.gd")
const AudioServiceResource = preload("res://scripts/audio_service.gd")

const MUSIC_PATHS := {
	"music.exploration_day": "res://assets/audio/music/exploration_day.ogg",
	"music.interior": "res://assets/audio/music/interior.ogg",
	"music.exploration_rain": "res://assets/audio/music/exploration_rain.ogg",
	"music.exploration_threat": "res://assets/audio/music/exploration_threat.ogg",
	"music.night_report": "res://assets/audio/music/exploration_threat.ogg",
	"music.menu": "res://assets/audio/music/interior.ogg",
	"music.game_over": "res://assets/audio/music/exploration_threat.ogg",
}

const AMBIENCE_PATH := "res://assets/audio/ambience/camp_night_loop.wav"

func _init() -> void:
	var catalog: AudioCatalog = AudioCatalogResource.load_from_path("res://data/audio_catalog.json")
	assert(catalog != null, "catalog should load")
	for cue_id in MUSIC_PATHS:
		var cue: AudioCue = catalog.get_cue(cue_id)
		assert(cue != null, "missing music cue: %s" % cue_id)
		assert(cue.stream_paths.has(MUSIC_PATHS[cue_id]), "music cue does not use selected asset: %s" % cue_id)
		assert(ResourceLoader.exists(MUSIC_PATHS[cue_id]), "missing music asset: %s" % MUSIC_PATHS[cue_id])
	for cue_id in ["fallback.ambience", "ambience.environment", "ambience.weather", "ambience.fire"]:
		var ambience: AudioCue = catalog.get_cue(cue_id)
		assert(ambience != null, "missing ambience cue: %s" % cue_id)
		assert(ambience.stream_paths.has(AMBIENCE_PATH), "ambience cue does not use selected asset: %s" % cue_id)
		assert(ResourceLoader.exists(AMBIENCE_PATH), "missing ambience asset")
	for cue in catalog.all_cues():
		if cue.id in MUSIC_PATHS or cue.id in ["fallback.music", "fallback.ambience", "ambience.environment", "ambience.weather", "ambience.fire"]:
			continue
		assert(not cue.stream_paths.is_empty(), "SFX cue has no stream: %s" % cue.id)
		for stream_path in cue.stream_paths:
			assert(stream_path.begins_with("res://assets/audio/sfx/"), "SFX cue is outside online SFX folder: %s" % cue.id)
			assert(not stream_path.contains("placeholder"), "SFX cue still uses placeholder: %s" % cue.id)
			assert(not stream_path.contains("audio_preview"), "SFX cue uses generated preview: %s" % cue.id)
	var service := AudioServiceResource.new()
	service.headless_mode = true
	service._sync_controller_modes()
	service.set_world_state({"phase":"exploration", "weather":"clear", "location":"outdoor", "fire_lit":true})
	assert(service._stream_cache.has(MUSIC_PATHS["music.exploration_day"]), "world state must load selected day music")
	assert(service._stream_cache.has(AMBIENCE_PATH), "world state must load selected ambience")
	print("AUDIO_ASSET_SELECTION_OK music=%d ambience=4 sfx=online-only" % MUSIC_PATHS.size())
	service.free()
	quit()
