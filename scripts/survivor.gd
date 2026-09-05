class_name Survivor
extends RefCounted

var id: String
var display_name: String
var role: String
var color: Color
var health: int = 100
## Core body temperature in degrees Celsius. A healthy resting body targets
## roughly 37 C; the value is persisted so loading a cold-weather save keeps
## the survival pressure intact.
var body_temperature: float = 37.0
var temperature_damage_accumulator: float = 0.0
var hunger: int = 80
var energy: int = 80
var morale: int = 70
var gather: int = 1
var build: int = 1
var medical: int = 1
var current_work: String = "休息"
var injured: bool = false
var sick: bool = false
var alive: bool = true
var xp: Dictionary = {"gather": 0, "build": 0, "medical": 0}
var same_work_days: int = 0
var last_work: String = ""
var relations: Dictionary = {"trust": 0, "conflict": 0, "inspire": 0}

static func create_profile(profile: Dictionary) -> Survivor:
	var unit := Survivor.new()
	unit.id = str(profile.id)
	unit.display_name = str(profile.name)
	unit.role = str(profile.role)
	unit.color = Color(str(profile.color))
	unit.gather = int(profile.gather)
	unit.build = int(profile.build)
	unit.medical = int(profile.medical)
	return unit

func skill_value(skill: String) -> int:
	match skill:
		"gather": return gather + int(xp.gather / 8)
		"build": return build + int(xp.build / 8)
		"medical": return medical + int(xp.medical / 8)
	return 0

func add_xp(skill: String, amount: int) -> bool:
	if not xp.has(skill):
		return false
	var old_level := int(xp[skill] / 8)
	xp[skill] = int(xp[skill]) + amount
	return int(xp[skill] / 8) > old_level

func apply_change(stat: String, amount: int) -> void:
	match stat:
		"health": health = clampi(health + amount, 0, 100)
		"hunger": hunger = clampi(hunger + amount, 0, 100)
		"energy": energy = clampi(energy + amount, 0, 100)
		"morale": morale = clampi(morale + amount, 0, 100)
	if health <= 0:
		alive = false
		current_work = "休息"

func next_day_work_streak() -> void:
	if current_work == last_work and current_work not in ["休息", "守卫营地"]:
		same_work_days += 1
	else:
		same_work_days = 0
	last_work = current_work

func status_text() -> String:
	var tags: Array[String] = []
	if injured: tags.append("伤")
	if sick: tags.append("病")
	if not alive: tags.append("死亡")
	return "/".join(tags) if not tags.is_empty() else "正常"

func to_dict() -> Dictionary:
	return {"id":id,"name":display_name,"role":role,"color":color.to_html(false),"health":health,"body_temperature":body_temperature,"temperature_damage_accumulator":temperature_damage_accumulator,"hunger":hunger,"energy":energy,"morale":morale,"gather":gather,"build":build,"medical":medical,"current_work":current_work,"injured":injured,"sick":sick,"alive":alive,"xp":xp,"same_work_days":same_work_days,"last_work":last_work,"relations":relations}

static func from_dict(data: Dictionary) -> Survivor:
	var unit := Survivor.create_profile(data)
	unit.health = int(data.get("health", 100)); unit.body_temperature = clampf(float(data.get("body_temperature", 37.0)), -50.0, 45.0)
	unit.temperature_damage_accumulator = maxf(0.0, float(data.get("temperature_damage_accumulator", 0.0))); unit.hunger = int(data.get("hunger", 80))
	unit.energy = int(data.get("energy", 80)); unit.morale = int(data.get("morale", 70))
	unit.current_work = str(data.get("current_work", "休息")); unit.injured = bool(data.get("injured", false))
	unit.sick = bool(data.get("sick", false)); unit.alive = bool(data.get("alive", true))
	unit.xp = data.get("xp", {"gather":0,"build":0,"medical":0})
	unit.same_work_days = int(data.get("same_work_days", 0)); unit.last_work = str(data.get("last_work", ""))
	unit.relations = data.get("relations", {"trust":0,"conflict":0,"inspire":0})
	return unit
