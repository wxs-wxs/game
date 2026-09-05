class_name AudioAmbienceController
extends Node

var active_layers: Dictionary = {}
var headless_mode: bool = false
var _players: Dictionary = {}

func initialize(headless: bool) -> void:
	headless_mode = headless

func set_layers(layers: Dictionary, streams: Dictionary = {}) -> bool:
	var changed := layers != active_layers
	active_layers = layers.duplicate()
	if headless_mode:
		return changed
	for layer_name in ["Environment", "Weather", "Fire"]:
		if not layers.has(layer_name):
			if _players.has(layer_name):
				_players[layer_name].stop()
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
		if player.stream != stream:
			player.stream = stream
			player.play()
	return changed

func stop_all() -> void:
	active_layers.clear()
	for player in _players.values():
		player.stop()
