class_name AudioAmbienceController
extends Node

var active_layers: Dictionary = {}
var headless_mode: bool = false
var _players: Dictionary = {}
var _fades: Dictionary = {}
var fade_seconds: float = 0.25

func initialize(headless: bool) -> void:
	headless_mode = headless

func set_layers(layers: Dictionary, streams: Dictionary = {}) -> bool:
	var previous_layers := active_layers.duplicate()
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
		var reactivated := previous_layers.has(layer_name) == false or _fades.has(layer_name)
		if reactivated:
			_cancel_fade(layer_name)
			player.volume_db = -80.0
		if player.stream != stream or not player.playing or reactivated:
			player.stream = stream
			player.play()
			_fade_in(player)
	return changed

func _fade_in(player: AudioStreamPlayer) -> void:
	if not is_inside_tree():
		player.volume_db = 0.0
		return
	var layer_name := _layer_for_player(player)
	if not layer_name.is_empty():
		_cancel_fade(layer_name)
	var tween := create_tween()
	if not layer_name.is_empty():
		_fades[layer_name] = tween
	tween.tween_property(player, "volume_db", 0.0, fade_seconds)

func _fade_out(player: AudioStreamPlayer) -> void:
	if not is_inside_tree():
		player.stop()
		return
	var layer_name := _layer_for_player(player)
	if not layer_name.is_empty():
		_cancel_fade(layer_name)
	var tween := create_tween()
	if not layer_name.is_empty():
		_fades[layer_name] = tween
	tween.tween_property(player, "volume_db", -80.0, fade_seconds)
	tween.tween_callback(Callable(self, "_finish_fade_out").bind(layer_name, player))

func _finish_fade_out(layer_name: String, player: AudioStreamPlayer) -> void:
	if not active_layers.has(layer_name) and _players.get(layer_name) == player:
		player.stop()
	_fades.erase(layer_name)

func _cancel_fade(layer_name: String) -> void:
	var tween: Tween = _fades.get(layer_name)
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(layer_name)

func _layer_for_player(player: AudioStreamPlayer) -> String:
	for layer_name in _players:
		if _players[layer_name] == player:
			return layer_name
	return ""

func stop_all() -> void:
	active_layers.clear()
	for player in _players.values():
		player.stop()
