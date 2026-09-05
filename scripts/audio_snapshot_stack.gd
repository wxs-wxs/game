class_name AudioSnapshotStack
extends RefCounted

const BUS_NAMES := ["Master", "Music", "Ambience", "Environment", "Weather", "Fire", "SFX", "World", "UI", "Critical", "Voice"]

var base_volumes: Dictionary = {"master": 1.0, "music": 1.0, "ambience": 1.0, "sfx": 1.0}
var snapshots: Dictionary = {}

const SNAPSHOT_TARGETS := {
	"pause": {"Music": -8.0, "Environment": -18.0, "World": -24.0},
	"modal": {"Music": -5.0, "Environment": -12.0, "World": -18.0},
	"danger": {"Music": -2.0, "World": -6.0, "Critical": 0.0},
	"interior": {"World": -3.0},
	"game_over": {"Environment": -80.0, "World": -80.0},
}

func set_base_volumes(data: Dictionary) -> void:
	for key in base_volumes:
		if data.has(key):
			base_volumes[key] = clampf(float(data[key]), 0.0, 1.0)

func push(id: String) -> void:
	if SNAPSHOT_TARGETS.has(id):
		snapshots[id] = SNAPSHOT_TARGETS[id].duplicate()
	else:
		snapshots[id] = {}

func pop(id: String) -> void:
	snapshots.erase(id)

func clear() -> void:
	snapshots.clear()

func calculate() -> Dictionary:
	var targets: Dictionary = {}
	for bus_name in BUS_NAMES:
		var base_db := 0.0
		if bus_name == "Master":
			base_db = _linear_to_db(base_volumes.get("master", 1.0))
		elif bus_name == "Music":
			base_db = _linear_to_db(base_volumes.get("music", 1.0))
		elif bus_name in ["Ambience", "Environment", "Weather", "Fire"]:
			base_db = _linear_to_db(base_volumes.get("ambience", 1.0))
		elif bus_name in ["SFX", "World", "UI", "Critical"]:
			base_db = _linear_to_db(base_volumes.get("sfx", 1.0))
		var target := base_db
		for snapshot in snapshots.values():
			if snapshot.has(bus_name):
				# Multiple snapshots choose the strongest ducking target.
				target = minf(target, base_db + float(snapshot[bus_name]))
		targets[bus_name] = target
	return targets

func _linear_to_db(value: float) -> float:
	if value <= 0.0001:
		return -80.0
	return linear_to_db(value)
