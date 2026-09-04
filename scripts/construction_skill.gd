class_name ConstructionSkill
extends RefCounted

var level: int = 1
var experience: int = 0
var completed_count: int = 0
var repaired_count: int = 0
var read_manuals: Array[String] = []

func add_experience(amount: int) -> bool:
	var old_level := level
	experience = maxi(0, experience + maxi(0, amount))
	level = clampi(1 + int(experience / 30), 1, 5)
	return level > old_level

func xp_to_next() -> int:
	return level * 30

func build_time(base: float) -> float:
	return maxf(0.5, base * (1.0 - 0.05 * float(level - 1)))

func to_dict() -> Dictionary:
	return {"level":level, "experience":experience, "completed_count":completed_count, "repaired_count":repaired_count, "read_manuals":read_manuals}

func from_dict(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, 5)
	experience = maxi(0, int(data.get("experience", 0)))
	completed_count = maxi(0, int(data.get("completed_count", 0)))
	repaired_count = maxi(0, int(data.get("repaired_count", 0)))
	read_manuals = []
	for item in data.get("read_manuals", []): read_manuals.append(str(item))
