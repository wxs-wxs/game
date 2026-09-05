class_name AudioSfxController
extends Node

const GLOBAL_POOL_SIZE := 8
const CRITICAL_RESERVED := 1
const GROUP_LIMITS := {"World": 4, "UI": 4, "Critical": 2, "Fire": 2, "SFX": 4}
const UNLIMITED_MAX_DISTANCE := 1000000.0

var headless_mode: bool = false
var listener_position := Vector2.ZERO
var _active: Array[Dictionary] = []
var _last_played_ms: Dictionary = {}
var _players: Array[Node] = []
var _now_override: int = -1
var _listener: AudioListener2D

func initialize(headless: bool) -> void:
	headless_mode = headless
	if not headless_mode and _listener == null:
		_listener = AudioListener2D.new()
		_listener.position = listener_position
		add_child(_listener)
		_listener.make_current()

func _ready() -> void:
	if not headless_mode and _listener != null:
		_listener.make_current()

func set_listener_position(position: Vector2) -> void:
	listener_position = position
	if _listener != null:
		_listener.position = position
		_listener.make_current()

func play_cue(cue: AudioCue, stream: AudioStream, params: Dictionary = {}) -> String:
	if cue == null:
		return "missing"
	var now := _now_ms()
	_cleanup(now)
	var cue_id := cue.id
	if _last_played_ms.has(cue_id) and now - int(_last_played_ms[cue_id]) < cue.cooldown_ms:
		return "suppressed"
	var group := cue.output_bus
	var group_count := 0
	for item in _active:
		if item.get("group", "") == group and item.get("cue_id", "") == cue_id:
			group_count += 1
	if group_count >= cue.max_instances:
		return _steal_or_drop(cue, group, now, stream, params)
	var noncritical_count := 0
	for item in _active:
		if item.get("group", "") != "Critical":
			noncritical_count += 1
	if group != "Critical" and noncritical_count >= GLOBAL_POOL_SIZE - CRITICAL_RESERVED:
		return _steal_or_drop(cue, group, now, stream, params)
	var group_limit := int(GROUP_LIMITS.get(group, 4))
	var same_group_count := 0
	for item in _active:
		if item.get("group", "") == group:
			same_group_count += 1
	if same_group_count >= group_limit:
		return _steal_or_drop(cue, group, now, stream, params)
	var player: Node = null
	if not headless_mode:
		player = _find_free_player(cue)
		if player == null:
			player = _create_player(cue)
	var started := false
	if player != null:
		started = _start_player(player, cue, stream, params)
	_last_played_ms[cue_id] = now
	_active.append({"cue_id": cue_id, "group": group, "priority": cue.priority, "started_ms": now, "player": player, "started": started})
	if headless_mode:
		return "headless"
	return "played"

func _steal_or_drop(cue: AudioCue, group: String, now: int, stream: AudioStream, params: Dictionary) -> String:
	if cue.steal_policy == "drop":
		return "suppressed"
	var candidate_index := -1
	var candidate_priority := 2147483647
	var oldest := 2147483647
	for index in _active.size():
		var item := _active[index]
		if item.get("group", "") != group:
			continue
		if cue.steal_policy == "oldest" and int(item.get("priority", 0)) < cue.priority and int(item.get("started_ms", 0)) < oldest:
			oldest = int(item.get("started_ms", 0))
			candidate_index = index
		elif cue.steal_policy == "lowest_priority" and int(item.get("priority", 0)) < cue.priority and int(item.get("priority", 0)) < candidate_priority:
			candidate_priority = int(item.get("priority", 0))
			candidate_index = index
	if candidate_index < 0:
		return "suppressed"
	var old_player: Node = _active[candidate_index].get("player")
	if old_player != null and is_instance_valid(old_player):
		old_player.stop()
	_active.remove_at(candidate_index)
	_last_played_ms[cue.id] = now
	var player: Node = null
	if not headless_mode:
		player = _find_free_player(cue)
		if player == null:
			player = _create_player(cue)
	var started := false
	if player != null:
		started = _start_player(player, cue, stream, params)
	_active.append({"cue_id": cue.id, "group": group, "priority": cue.priority, "started_ms": now, "player": player, "started": started})
	return "headless" if headless_mode else "played"

func _find_free_player(cue: AudioCue) -> Node:
	for player in _players:
		if player.playing:
			continue
		if cue.spatial_mode == "point" and player is AudioStreamPlayer2D:
			return player
		if cue.spatial_mode != "point" and player is AudioStreamPlayer and not player is AudioStreamPlayer2D:
			return player
	return null

func _create_player(cue: AudioCue) -> Node:
	var player: Node = AudioStreamPlayer2D.new() if cue.spatial_mode == "point" else AudioStreamPlayer.new()
	add_child(player)
	_players.append(player)
	return player

func _start_player(player: Node, cue: AudioCue, stream: AudioStream, params: Dictionary) -> bool:
	player.stop()
	player.bus = cue.output_bus
	player.stream = stream
	player.volume_db = cue.base_volume_db
	if player is AudioStreamPlayer or player is AudioStreamPlayer2D:
		if params.has("pitch_scale"):
			player.pitch_scale = float(params["pitch_scale"])
	if player is AudioStreamPlayer2D:
		player.position = params.get("position", listener_position)
		# Godot rejects zero on AudioStreamPlayer2D; retain the logical zero and
		# use a far bound for cues without a distance limit.
		player.set_meta("audio_max_distance", cue.max_distance)
		player.max_distance = cue.max_distance if cue.max_distance > 0.0 else UNLIMITED_MAX_DISTANCE
	if not player.is_inside_tree():
		return false
	player.play()
	return true

func _cleanup(now: int) -> void:
	var remaining: Array[Dictionary] = []
	for item in _active:
		var player: Node = item.get("player")
		if item.get("started", false) and player != null and is_instance_valid(player) and not player.playing:
			continue
		if now - int(item.get("started_ms", 0)) < 1000:
			remaining.append(item)
	_active = remaining

func _now_ms() -> int:
	return _now_override if _now_override >= 0 else Time.get_ticks_msec()

func active_count(group: String = "") -> int:
	_cleanup(_now_ms())
	if group.is_empty():
		return _active.size()
	var count := 0
	for item in _active:
		if item.get("group", "") == group:
			count += 1
	return count
