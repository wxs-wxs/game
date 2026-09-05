class_name AudioService
extends Node

const AudioCatalogResource = preload("res://scripts/audio_catalog.gd")
const AudioSettingsResource = preload("res://scripts/audio_settings.gd")
const AudioSnapshotStackResource = preload("res://scripts/audio_snapshot_stack.gd")
const AudioMusicControllerResource = preload("res://scripts/audio_music_controller.gd")
const AudioAmbienceControllerResource = preload("res://scripts/audio_ambience_controller.gd")
const AudioSfxControllerResource = preload("res://scripts/audio_sfx_controller.gd")

const BUS_NAMES := ["Master", "Music", "Ambience", "Environment", "Weather", "Fire", "SFX", "World", "UI", "Critical", "Voice"]
const DEFAULT_WORLD_STATE := {
	"phase": "exploration",
	"location": "outdoor",
	"weather": "clear",
	"threat": "low",
	"fire_lit": false,
	"fire_source": "",
	"paused": false,
}

var event_log: Array[Dictionary] = []
var active_music_id: String = ""
var active_ambience_layers: Dictionary = {}
var last_snapshot_targets: Dictionary = {}
var listener_position := Vector2.ZERO
var world_state: Dictionary = DEFAULT_WORLD_STATE.duplicate(true)
var settings: AudioSettings = AudioSettingsResource.new()
var catalog: AudioCatalog
var headless_mode: bool = false

var _music: AudioMusicController
var _ambience: AudioAmbienceController
var _sfx: AudioSfxController
var _snapshots: AudioSnapshotStack
var _stream_cache: Dictionary = {}
var _silent_stream: AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _initialized := false
var _missing_logged: Dictionary = {}
var _world_state_applied := false

func _init() -> void:
	_rng.randomize()
	headless_mode = _detect_headless()
	_initialize()

func _ready() -> void:
	_initialize()
	apply_settings(settings.to_dict())

func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	catalog = AudioCatalogResource.load_from_path("res://data/audio_catalog.json")
	_music = AudioMusicControllerResource.new()
	_ambience = AudioAmbienceControllerResource.new()
	_sfx = AudioSfxControllerResource.new()
	_snapshots = AudioSnapshotStackResource.new()
	add_child(_music)
	add_child(_ambience)
	add_child(_sfx)
	_music.initialize(headless_mode)
	_ambience.initialize(headless_mode)
	_sfx.initialize(headless_mode)
	_recompute_snapshots()

func emit_event(event_id: String, params: Dictionary = {}) -> String:
	_initialize()
	_sync_controller_modes()
	var result := "missing"
	var cue: AudioCue = catalog.get_cue(event_id) if catalog != null else null
	var resolved_id := event_id
	var fallback_used := false
	if cue == null:
		result = "missing"
	else:
		var resolved: AudioCue = catalog.fallback_for(cue)
		if resolved == null:
			resolved = cue
			fallback_used = true
		else:
			fallback_used = resolved.id != cue.id
		resolved_id = resolved.id
		var stream := _stream_for_cue(resolved)
		if stream == null:
			stream = _silent()
		var playback_params := params.duplicate(true)
		playback_params["pitch_scale"] = _rng.randf_range(cue.pitch_min, cue.pitch_max)
		result = _sfx.play_cue(cue, stream, playback_params)
		if headless_mode and result == "played":
			result = "headless"
	if event_id == "player.death":
		push_snapshot("game_over")
	var record := {
			"event_id": event_id,
			"params": params.duplicate(true),
			"result": result,
			"resolved_id": resolved_id,
			"fallback": fallback_used,
			"timestamp_ms": Time.get_ticks_msec(),
		}
	event_log.append(record)
	return result

func set_world_state(state: Dictionary) -> void:
	_initialize()
	var normalized := DEFAULT_WORLD_STATE.duplicate(true)
	for key in normalized:
		if state.has(key):
			normalized[key] = state[key]
	normalized["phase"] = str(normalized["phase"]).to_lower()
	normalized["location"] = str(normalized["location"]).to_lower()
	normalized["weather"] = str(normalized["weather"]).to_lower()
	normalized["threat"] = str(normalized["threat"]).to_lower()
	normalized["fire_lit"] = bool(normalized["fire_lit"])
	normalized["paused"] = bool(normalized["paused"])
	if normalized == world_state and _world_state_applied:
		return
	_sync_controller_modes()
	world_state = normalized
	var music_id := _music_id_for_state(world_state)
	var music_stream := _stream_for_id(music_id, "music")
	_music.set_music(music_id, music_stream)
	active_music_id = _music.active_music_id
	var layers := _ambience_layers_for_state(world_state)
	var streams: Dictionary = {}
	for layer_name in layers:
		streams[layer_name] = _stream_for_id(str(layers[layer_name]), "ambience")
	_ambience.set_layers(layers, streams)
	active_ambience_layers = _ambience.active_layers.duplicate(true)
	if world_state.paused:
		push_snapshot("pause")
	else:
		pop_snapshot("pause")
	if world_state.location == "interior":
		push_snapshot("interior")
	else:
		pop_snapshot("interior")
	if str(world_state.get("threat", "low")) in ["high", "critical", "danger"]:
		push_snapshot("danger")
	else:
		pop_snapshot("danger")
	_recompute_snapshots()
	_world_state_applied = true

func push_snapshot(id: String) -> void:
	_initialize()
	_snapshots.push(id)
	_recompute_snapshots()

func pop_snapshot(id: String) -> void:
	_initialize()
	_snapshots.pop(id)
	_recompute_snapshots()

func clear_snapshots() -> void:
	_initialize()
	_snapshots.clear()
	_recompute_snapshots()

func to_settings_dict() -> Dictionary:
	return settings.to_dict()

func apply_settings(data: Dictionary) -> void:
	_initialize()
	settings.apply_dict(data)
	_snapshots.set_base_volumes(settings.to_dict())
	_recompute_snapshots()

func load_user_settings() -> bool:
	_initialize()
	var loaded := settings.load_from_config()
	if loaded:
		_snapshots.set_base_volumes(settings.to_dict())
		_recompute_snapshots()
	return loaded

func save_user_settings() -> Error:
	_initialize()
	return settings.save_to_config()

func set_listener_position(position: Vector2) -> void:
	listener_position = position
	_initialize()
	_sfx.set_listener_position(position)

func _recompute_snapshots() -> void:
	if _snapshots == null:
		return
	last_snapshot_targets = _snapshots.calculate()
	for bus_name in last_snapshot_targets:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, float(last_snapshot_targets[bus_name]))

func _music_id_for_state(state: Dictionary) -> String:
	var phase := str(state.get("phase", "exploration"))
	var location := str(state.get("location", "outdoor"))
	var weather := str(state.get("weather", "clear"))
	if phase in ["game_over", "over", "ended"]:
		return "game_over"
	if phase in ["night_report", "report"]:
		return "night_report"
	if phase in ["menu", "main_menu"]:
		return "menu"
	if state.get("threat", "low") in ["high", "critical", "danger"]:
		return "exploration_threat"
	if location == "interior" or location == "inside":
		return "interior"
	if weather in ["rain", "storm", "heavy_rain", "暴雨", "小雨"]:
		return "exploration_rain"
	return "exploration_day"

func _ambience_layers_for_state(state: Dictionary) -> Dictionary:
	var result := {}
	var location := str(state.get("location", "outdoor"))
	var weather := str(state.get("weather", "clear"))
	if location == "interior" or location == "inside":
		result["Environment"] = "fallback.ambience"
	else:
		result["Environment"] = "fallback.ambience"
	if weather in ["rain", "storm", "heavy_rain", "暴雨", "小雨"]:
		result["Weather"] = "fallback.ambience"
	if bool(state.get("fire_lit", false)):
		result["Fire"] = "fallback.ambience"
	return result

func _stream_for_id(id: String, category: String) -> AudioStream:
	var cue: AudioCue = catalog.get_cue(id) if catalog != null else null
	if cue != null:
		return _stream_for_cue(cue)
	var fallback_id := "fallback.%s" % category
	cue = catalog.get_cue(fallback_id) if catalog != null else null
	return _stream_for_cue(cue)

func _stream_for_cue(cue: AudioCue) -> AudioStream:
	if cue == null:
		return _silent()
	for path in cue.stream_paths:
		if _stream_cache.has(path):
			return _stream_cache[path]
		if ResourceLoader.exists(path):
			var stream = ResourceLoader.load(path)
			if stream is AudioStream:
				_stream_cache[path] = stream
				return stream
	if not _missing_logged.has(cue.id):
		_missing_logged[cue.id] = true
	return _silent()

func _silent() -> AudioStreamWAV:
	if _silent_stream != null:
		return _silent_stream
	_silent_stream = AudioStreamWAV.new()
	_silent_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_silent_stream.mix_rate = 22050
	_silent_stream.stereo = false
	_silent_stream.data = PackedByteArray([0, 0])
	return _silent_stream

func _detect_headless() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("headless")

func _sync_controller_modes() -> void:
	if _music == null:
		return
	_music.headless_mode = headless_mode
	_ambience.headless_mode = headless_mode
	_sfx.headless_mode = headless_mode
