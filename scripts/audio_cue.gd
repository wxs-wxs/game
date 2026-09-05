class_name AudioCue
extends Resource

@export var id: String = ""
@export var event_kind: String = "oneshot"
@export var output_bus: String = "SFX"
@export var stream_paths: Array[String] = []
@export var fallback_id: String = ""
@export var base_volume_db: float = 0.0
@export var pitch_min: float = 1.0
@export var pitch_max: float = 1.0
@export var priority: int = 0
@export var cooldown_ms: int = 0
@export var max_instances: int = 1
@export var spatial_mode: String = "none"
@export var max_distance: float = 0.0
@export var steal_policy: String = "drop"

func has_available_stream() -> bool:
	for stream_path in stream_paths:
		if ResourceLoader.exists(stream_path):
			return true
	return false
