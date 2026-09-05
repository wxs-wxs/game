class_name AudioAmbienceController
extends Node

var active_layers: Dictionary = {}
var headless_mode: bool = false
var _players: Dictionary = {}
var fade_seconds: float = 0.25

func initialize(headless: bool) -> void:
	headless_mode = headless

func set_layers(layers: Dictionary, streams: Dictionary = {}) -> bool:
	var changed := layers != active_layers
	active_layers = layers.duplicate()
	if headless_mode or not is_inside_tree():
		return changed
	for layer_name in ["Environment", "Weather", "Fire"]:
		if not layers.has(layer_name):
			if _players.has(layer_name):
				_fade_out(_players[layer_name])
			continue
		var stream: AudioStream = streams.get(layer_name)
		if stream == null:
			continue
		var player: AudioStreamPlayer = _players.get(layer_name)
		if player == null:
			player = AudioStreamPlayer.new()
			player.bus = layer_name
			add_child(player)
			_players[layer_name] = player
		if player.stream != stream or not player.playing:
			player.stream = stream
			player.volume_db = -80.0
			player.play()
			_fade_in(player)
	return changed

func _fade_in(player: AudioStreamPlayer) -> void:
	if not is_inside_tree():
		player.volume_db = 0.0
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, fade_seconds)

func _fade_out(player: AudioStreamPlayer) -> void:
	if not is_inside_tree():
		player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_seconds)
	tween.tween_callback(player.stop)

func stop_all() -> void:
	active_layers.clear()
	for player in _players.values():
		player.stop()
