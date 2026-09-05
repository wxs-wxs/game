class_name AudioCatalog
extends Resource

const AudioCueResource = preload("res://scripts/audio_cue.gd")

const VALID_EVENT_KINDS := ["oneshot", "loop", "stinger"]
const VALID_SPATIAL_MODES := ["none", "point"]
const VALID_STEAL_POLICIES := ["drop", "oldest", "lowest_priority"]
const BUS_NAMES := [
	"Master", "Music", "Ambience", "Environment", "Weather", "Fire",
	"SFX", "World", "UI", "Critical", "Voice"
]

var _cues: Dictionary = {}
var _load_errors: Array[String] = []

static func load_from_path(path: String) -> AudioCatalog:
	var catalog: AudioCatalog = AudioCatalog.new()
	if not FileAccess.file_exists(path):
		catalog._load_errors.append("catalog file does not exist: %s" % path)
		return catalog
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		catalog._load_errors.append("catalog file could not be opened: %s" % path)
		return catalog
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		catalog._load_errors.append("catalog root must be an object")
		return catalog
	var cue_entries = parsed.get("cues", [])
	if not (cue_entries is Array):
		catalog._load_errors.append("catalog cues must be an array")
		return catalog
	for entry in cue_entries:
		if not (entry is Dictionary):
			catalog._load_errors.append("catalog cue entries must be objects")
			continue
		var cue_id := str(entry.get("id", ""))
		if cue_id.is_empty():
			catalog._load_errors.append("cue id must not be empty")
			continue
		if catalog._cues.has(cue_id):
			push_error("duplicate cue id: %s" % cue_id)
			return null
		catalog._cues[cue_id] = _cue_from_dict(entry)
	return catalog

static func _cue_from_dict(data: Dictionary) -> AudioCue:
	var cue: AudioCue = AudioCueResource.new()
	cue.id = str(data.get("id", ""))
	cue.event_kind = str(data.get("event_kind", "oneshot"))
	cue.output_bus = str(data.get("output_bus", "SFX"))
	cue.fallback_id = str(data.get("fallback_id", ""))
	cue.base_volume_db = float(data.get("base_volume_db", 0.0))
	cue.pitch_min = float(data.get("pitch_min", 1.0))
	cue.pitch_max = float(data.get("pitch_max", 1.0))
	cue.priority = int(data.get("priority", 0))
	cue.cooldown_ms = int(data.get("cooldown_ms", 0))
	cue.max_instances = int(data.get("max_instances", 1))
	cue.spatial_mode = str(data.get("spatial_mode", "none"))
	cue.max_distance = float(data.get("max_distance", 0.0))
	cue.steal_policy = str(data.get("steal_policy", "drop"))
	var paths = data.get("stream_paths", [])
	if paths is String:
		paths = [paths]
	if paths is Array:
		for path in paths:
			cue.stream_paths.append(_normalize_path(str(path)))
	return cue

static func _normalize_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return "res://" + path.trim_prefix("/")

func get_cue(id: String) -> AudioCue:
	return _cues.get(id)

func has_cue(id: String) -> bool:
	return _cues.has(id)

func all_cues() -> Array[AudioCue]:
	var result: Array[AudioCue] = []
	for cue in _cues.values():
		result.append(cue)
	return result

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	for cue in _cues.values():
		if cue.id != cue.id.to_lower() or not cue.id.contains("."):
			errors.append("cue id must be lower-case dotted: %s" % cue.id)
		if cue.event_kind not in VALID_EVENT_KINDS:
			errors.append("invalid event kind for %s: %s" % [cue.id, cue.event_kind])
		if cue.output_bus not in BUS_NAMES:
			errors.append("unknown output bus for %s: %s" % [cue.id, cue.output_bus])
		if cue.pitch_min <= 0.0 or cue.pitch_max < cue.pitch_min:
			errors.append("invalid pitch range for %s" % cue.id)
		if cue.cooldown_ms < 0 or cue.max_instances < 1 or cue.max_distance < 0.0:
			errors.append("invalid playback limits for %s" % cue.id)
		if cue.spatial_mode not in VALID_SPATIAL_MODES:
			errors.append("invalid spatial mode for %s: %s" % [cue.id, cue.spatial_mode])
		if cue.steal_policy not in VALID_STEAL_POLICIES:
			errors.append("invalid steal policy for %s: %s" % [cue.id, cue.steal_policy])
		if not cue.has_available_stream() and fallback_for(cue) == null:
			errors.append("cue has no stream or resolvable fallback: %s" % cue.id)
		if not cue.fallback_id.is_empty() and not _cues.has(cue.fallback_id):
			errors.append("missing fallback cue for %s: %s" % [cue.id, cue.fallback_id])
	return errors

func fallback_for(cue: AudioCue) -> AudioCue:
	if cue == null:
		return null
	if cue.has_available_stream():
		return cue
	var visited := {}
	var candidate: AudioCue = cue
	while candidate != null and not candidate.fallback_id.is_empty():
		if visited.has(candidate.id):
			return null
		visited[candidate.id] = true
		candidate = _cues.get(candidate.fallback_id)
		if candidate != null and candidate.has_available_stream():
			return candidate
	return null
