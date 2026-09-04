class_name AudioManager
extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var music_volume: float = 0.65
var sfx_volume: float = 0.8
var ambience_volume: float = 0.55
var pause_ducked := false
var current_music := ""
var current_ambience := ""
var _streams: Dictionary = {}
var _initialized := false

func _ready() -> void:
	_initialize()

func _exit_tree() -> void:
	stop_all()
	for player in sfx_players:
		if is_instance_valid(player): player.stream = null; player.free()
	if is_instance_valid(music_player): music_player.stream = null; music_player.free()
	if is_instance_valid(ambience_player): ambience_player.stream = null; ambience_player.free()
	_streams.clear()
	for bus_name in ["Ambience", "SFX", "Music"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0: AudioServer.remove_bus(index)

func _initialize() -> void:
	if _initialized: return
	_ensure_bus("Master")
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Ambience")
	music_player = _make_player("Music")
	ambience_player = _make_player("Ambience")
	for index in range(4): sfx_players.append(_make_player("SFX"))
	_initialized = true

func _ensure_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)

func _make_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player

func play_music(context: String) -> void:
	_initialize()
	current_music = context
	if DisplayServer.get_name() == "headless": return
	if music_player == null: return
	if not music_player.is_inside_tree(): return
	var key := "music_" + context
	var stream := _stream_for(key, 180.0, 0.16, true)
	if stream == null: return
	if current_music == context and music_player.playing: return
	music_player.volume_db = -40.0
	music_player.stream = stream
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(maxf(0.01, music_volume * (0.35 if pause_ducked else 1.0))), 0.8)

func play_ambience(context: String) -> void:
	_initialize()
	current_ambience = context
	if DisplayServer.get_name() == "headless": return
	if ambience_player == null: return
	if not ambience_player.is_inside_tree(): return
	var key := "ambience_" + context
	var stream := _stream_for(key, 90.0, 0.08, true)
	if stream == null: return
	if current_ambience == context and ambience_player.playing: return
	ambience_player.stream = stream
	ambience_player.volume_db = linear_to_db(maxf(0.01, ambience_volume))
	ambience_player.play()

func play_sfx(sound_id: String) -> void:
	_initialize()
	if DisplayServer.get_name() == "headless": return
	if sfx_players.is_empty(): return
	var stream := _stream_for("sfx_" + sound_id, 440.0 + float(abs(sound_id.hash()) % 240), 0.12, false)
	if stream == null: return
	for player in sfx_players:
		if not player.playing:
			if not player.is_inside_tree(): continue
			player.stream = stream
			player.volume_db = linear_to_db(maxf(0.01, sfx_volume))
			player.play()
			return

func set_music_volume(value: float) -> void:
	_initialize()
	music_volume = clampf(value, 0.0, 1.0)
	if music_player != null: music_player.volume_db = linear_to_db(maxf(0.01, music_volume * (0.35 if pause_ducked else 1.0)))

func set_sfx_volume(value: float) -> void:
	_initialize()
	sfx_volume = clampf(value, 0.0, 1.0)

func set_ambience_volume(value: float) -> void:
	_initialize()
	ambience_volume = clampf(value, 0.0, 1.0)
	if ambience_player != null: ambience_player.volume_db = linear_to_db(maxf(0.01, ambience_volume))

func stop_all() -> void:
	if music_player != null: music_player.stop()
	if ambience_player != null: ambience_player.stop()
	for player in sfx_players: player.stop()

func set_pause_ducked(value: bool) -> void:
	pause_ducked = value
	if music_player != null:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", linear_to_db(maxf(0.01, music_volume * (0.35 if pause_ducked else 1.0))), 0.25)

func to_dict() -> Dictionary:
	return {"music":music_volume, "sfx":sfx_volume, "ambience":ambience_volume}

func from_dict(data: Dictionary) -> void:
	set_music_volume(float(data.get("music", music_volume)))
	set_sfx_volume(float(data.get("sfx", sfx_volume)))
	set_ambience_volume(float(data.get("ambience", ambience_volume)))

func _stream_for(key: String, frequency: float, duration: float, looped: bool) -> AudioStreamWAV:
	if _streams.has(key): return _streams[key]
	var folder := "music" if key.begins_with("music_") else ("ambience" if key.begins_with("ambience_") else "sfx")
	var local_path := "res://assets/audio/%s/placeholder.wav" % folder
	if FileAccess.file_exists(local_path):
		var local_stream := AudioStreamWAV.load_from_file(local_path)
		if local_stream != null:
			if looped: local_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_streams[key] = local_stream
			return local_stream
	var sample_rate := 22050
	var count := maxi(1, int(sample_rate * duration))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var envelope := 1.0 - float(i) / float(count)
		var sample := int(sin(TAU * frequency * float(i) / float(sample_rate)) * 12000.0 * envelope)
		bytes[i * 2] = sample & 0xff
		bytes[i * 2 + 1] = (sample >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	_streams[key] = wav
	return wav
