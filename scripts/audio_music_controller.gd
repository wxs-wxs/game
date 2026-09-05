class_name AudioMusicController
extends Node

var active_music_id: String = ""
var last_requested_id: String = ""
var crossfade_seconds: float = 1.0
var headless_mode: bool = false
var _players: Array[AudioStreamPlayer] = []
var _active_index := 0

func initialize(headless: bool) -> void:
	headless_mode = headless
	if not _players.is_empty() or headless_mode:
		return
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_players.append(player)

func set_music(id: String, stream: AudioStream, volume_db: float = 0.0) -> bool:
	last_requested_id = id
	if id == active_music_id:
		return false
	active_music_id = id
	if headless_mode or stream == null or _players.is_empty() or not is_inside_tree():
		return true
	var next_index := 1 - _active_index
	var next_player := _players[next_index]
	var old_player := _players[_active_index]
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	if is_inside_tree():
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(next_player, "volume_db", volume_db, crossfade_seconds)
		if old_player.playing:
			tween.tween_property(old_player, "volume_db", -80.0, crossfade_seconds)
			tween.chain().tween_callback(old_player.stop)
	else:
		next_player.volume_db = volume_db
		old_player.stop()
	_active_index = next_index
	return true

func stop() -> void:
	active_music_id = ""
	for player in _players:
		player.stop()
