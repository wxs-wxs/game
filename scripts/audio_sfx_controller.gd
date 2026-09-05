class_name AudioSfxController
extends Node

const GLOBAL_POOL_SIZE := 8
const CRITICAL_RESERVED := 1
const GROUP_LIMITS := {"World": 4, "UI": 4, "Critical": 2, "Fire": 2, "SFX": 4}

var headless_mode: bool = false
var listener_position := Vector2.ZERO
var _active: Array[Dictionary] = []
var _last_played_ms: Dictionary = {}
var _players: Array[Node] = []
var _now_override: int = -1

func initialize(headless: bool) -> void:
	headless_mode = headless

func set_listener_position(position: Vector2) -> void:
	listener_position = position

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
		return _steal_or_drop(cue, group, now)
	var noncritical_count := 0
	for item in _active:
		if item.get("group", "") != "Critical":
			noncritical_count += 1
	if group != "Critical" and noncritical_count >= GLOBAL_POOL_SIZE - CRITICAL_RESERVED:
		return _steal_or_drop(cue, group, now)
	var group_limit := int(GROUP_LIMITS.get(group, 4))
	var same_group_count := 0
	for item in _active:
		if item.get("group", "") == group:
			same_group_count += 1
	if same_group_count >= group_limit:
		return _steal_or_drop(cue, group, now)
	_last_played_ms[cue_id] = now
	_active.append({"cue_id": cue_id, "group": group, "priority": cue.priority, "started_ms": now})
	if headless_mode:
		return "headless"
	if stream == null:
		return "played"
	var player := _find_free_player()
	if player == null:
		player = AudioStreamPlayer2D.new() if cue.spatial_mode == "point" else AudioStreamPlayer.new()
		player.bus = group
		add_child(player)
		_players.append(player)
	player.stream = stream
	player.volume_db = cue.base_volume_db
	if (player is AudioStreamPlayer or player is AudioStreamPlayer2D) and params.has("pitch_scale"):
		player.pitch_scale = float(params["pitch_scale"])
	if player is AudioStreamPlayer2D and params.has("position"):
		player.position = params.position
	player.play()
	return "played"

func _steal_or_drop(cue: AudioCue, group: String, now: int) -> String:
	if cue.steal_policy == "drop":
		return "suppressed"
	var candidate_index := -1
	var candidate_priority := 2147483647
	var oldest := 2147483647
	for index in _active.size():
		var item := _active[index]
		if item.get("group", "") != group:
			continue
		if cue.steal_policy == "oldest" and int(item.get("started_ms", 0)) < oldest:
			oldest = int(item.get("started_ms", 0))
			candidate_index = index
		elif cue.steal_policy == "lowest_priority" and int(item.get("priority", 0)) < candidate_priority:
			candidate_priority = int(item.get("priority", 0))
			candidate_index = index
	if candidate_index < 0:
		return "suppressed"
	_active.remove_at(candidate_index)
	_last_played_ms[cue.id] = now
	_active.append({"cue_id": cue.id, "group": group, "priority": cue.priority, "started_ms": now})
	return "headless" if headless_mode else "played"

func _find_free_player() -> Node:
	for player in _players:
		if not player.playing:
			return player
	return null

func _cleanup(now: int) -> void:
	if headless_mode:
		# Keep decisions observable briefly so max_instances remains testable.
		_active = _active.filter(func(item: Dictionary) -> bool: return now - int(item.get("started_ms", 0)) < 1000)
	else:
		_active = _active.filter(func(item: Dictionary) -> bool: return now - int(item.get("started_ms", 0)) < 1000)

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
