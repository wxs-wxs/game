class_name BuildingSystem
extends RefCounted

## Canonical construction catalog and state. BlueprintSystem and the two UI
## flows are compatibility views over this object; they never own a second
## completion or material ledger.
const DATA_PATH := "res://data/buildings.json"

var definitions: Dictionary = {}
var unlocked: Array[String] = []
var built: Dictionary = {}
var active_project: Dictionary = {}
var world_projects: Dictionary = {}
var effect_applied: Dictionary = {}
var guard_power: int = 0
var last_completed_id: String = ""

func _init() -> void:
	definitions = _load_json(DATA_PATH)
	_normalize_definitions()

func _normalize_definitions() -> void:
	for key in definitions.keys():
		var id := str(key)
		var raw: Dictionary = definitions[key] if definitions[key] is Dictionary else {}
		raw["id"] = id
		if not raw.has("cost"): raw["cost"] = {}
		if not raw.has("build_time"): raw["build_time"] = float(raw.get("work", 1))
		if not raw.has("required_skill_level"): raw["required_skill_level"] = 1
		if not raw.has("context"): raw["context"] = "camp"
		if not raw.has("placement"): raw["placement"] = "camp"
		if not raw.has("effect_id"): raw["effect_id"] = id
		definitions[id] = raw

func catalog(group: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in definitions.keys():
		var definition: Dictionary = definitions[key]
		if group.is_empty() or str(definition.get("context", "camp")) == group:
			result.append(definition.duplicate(true))
	return result

func get_definition(building_id: String) -> Dictionary:
	var value = definitions.get(building_id, {})
	return value.duplicate(true) if value is Dictionary else {}

func unlock(building_id: String) -> bool:
	if not definitions.has(building_id) or building_id in unlocked: return false
	unlocked.append(building_id)
	return true

func is_unlocked(building_id: String, skill_level: int = 99) -> bool:
	if not definitions.has(building_id): return false
	if building_id in unlocked: return int(definitions[building_id].get("required_skill_level", 1)) <= skill_level
	return str(definitions[building_id].get("context", "camp")) == "camp"

func available(skill_level: int) -> Array[String]:
	var result: Array[String] = []
	for key in definitions.keys():
		if is_unlocked(str(key), skill_level) and int(definitions[key].get("required_skill_level", 1)) <= skill_level:
			result.append(str(key))
	return result

func start_project(building_id: String, resources: ResourceManager, skill_level: int = 99) -> Dictionary:
	if built.has(building_id): return {"ok":false, "reason":"设施已经建成"}
	if not active_project.is_empty() or not world_projects.is_empty(): return {"ok":false, "reason":"已有建造项目"}
	var definition := get_definition(building_id)
	if definition.is_empty(): return {"ok":false, "reason":"未知设施"}
	if not is_unlocked(building_id, skill_level): return {"ok":false, "reason":"技能等级不足或设施尚未解锁"}
	var cost: Dictionary = definition.get("cost", {})
	if not resources.can_afford(cost): return {"ok":false, "reason":resources.missing_cost_text(cost)}
	if not resources.spend(cost): return {"ok":false, "reason":"材料扣除失败"}
	active_project = {"id":building_id, "progress":0, "required":int(definition.get("work", definition.get("build_time", 1.0)))}
	return {"ok":true, "reason":"开始建造 %s" % str(definition.get("name", building_id))}

func add_work(amount: int) -> String:
	last_completed_id = ""
	if active_project.is_empty(): return ""
	active_project["progress"] = int(active_project.get("progress", 0)) + maxi(0, amount)
	if int(active_project["progress"]) < int(active_project.get("required", 1)): return ""
	var building_id := str(active_project.get("id", ""))
	active_project = {}
	return complete(building_id)

func start_world_project(building_id: String, position: Vector2, resources: ResourceManager, skill_level: int) -> Dictionary:
	if built.has(building_id) or world_projects.has(building_id): return {"ok":false, "reason":"设施已经建成或正在建造"}
	if not active_project.is_empty() or not world_projects.is_empty(): return {"ok":false, "reason":"已有建造项目"}
	var definition := get_definition(building_id)
	if definition.is_empty(): return {"ok":false, "reason":"未知设施"}
	if str(definition.get("placement", "camp")) != "world": return {"ok":false, "reason":"该设施必须在营地规划"}
	if not is_unlocked(building_id, skill_level): return {"ok":false, "reason":"技能等级不足或设施尚未解锁"}
	var cost: Dictionary = definition.get("cost", {})
	if not resources.can_afford(cost): return {"ok":false, "reason":resources.missing_cost_text(cost)}
	if not resources.spend(cost): return {"ok":false, "reason":"材料扣除失败"}
	world_projects[building_id] = {"id":building_id, "position":[position.x, position.y], "progress":0.0, "required":float(definition.get("build_time", 1.0))}
	return {"ok":true, "reason":"开始建造 %s" % str(definition.get("name", building_id)), "project":world_projects[building_id]}

func advance_world_project(building_id: String, delta: float) -> bool:
	if not world_projects.has(building_id): return false
	var project: Dictionary = world_projects[building_id]
	project["progress"] = minf(float(project.get("required", 1.0)), float(project.get("progress", 0.0)) + maxf(0.0, delta))
	world_projects[building_id] = project
	if float(project["progress"]) < float(project.get("required", 1.0)): return false
	world_projects.erase(building_id)
	complete(building_id)
	return true

func complete(building_id: String) -> String:
	last_completed_id = ""
	if building_id.is_empty() or built.has(building_id): return ""
	built[building_id] = 1
	last_completed_id = building_id
	return str(definitions.get(building_id, {}).get("name", building_id))

func has(building_id: String) -> bool: return int(built.get(building_id, 0)) > 0
func rest_bonus() -> int: return 4 if has("bed") else 0
func clinic_bonus() -> int: return 2 if has("clinic") else 0
func fuel_discount() -> int: return 1 if has("campfire") else 0
func cold_fuel_discount() -> int: return 1 if has("fire_basin") else 0
func indoor_cold_damage_reduction() -> int: return 2 if has("fire_basin") else 0
func attack_protection() -> int: return (2 if has("fence") else 0) + int(guard_power / 2)
func capacity_bonus() -> int: return 10 if has("shed") else 0
func has_workbench() -> bool: return has("workbench")
func rain_water_yield() -> int: return 3 if has("rain_collector") else 0

func built_names() -> Array[String]:
	var list: Array[String] = []
	for key in built:
		if definitions.has(key): list.append(str(definitions[key].get("name", key)))
	return list

func project_text() -> String:
	if not active_project.is_empty():
		var definition := get_definition(str(active_project.get("id", "")))
		return "%s %d/%d" % [definition.get("name", "设施"), int(active_project.get("progress", 0)), int(active_project.get("required", 1))]
	for key in world_projects:
		var project: Dictionary = world_projects[key]
		return "%s %.1f/%.1f" % [get_definition(str(key)).get("name", "设施"), float(project.get("progress", 0.0)), float(project.get("required", 1.0))]
	return "无建造项目"

func to_dict() -> Dictionary:
	return {"built":built, "unlocked":unlocked, "active_project":active_project, "world_projects":world_projects, "effect_applied":effect_applied, "guard_power":guard_power, "last_completed_id":last_completed_id}

func from_dict(data: Dictionary) -> void:
	built = {}
	var saved_built = data.get("built", {})
	if saved_built is Dictionary:
		for key in saved_built:
			if definitions.has(str(key)) and int(saved_built.get(key, 0)) > 0: built[str(key)] = 1
	unlocked = []
	var saved_unlocked = data.get("unlocked", data.get("blueprints", []))
	if saved_unlocked is Array:
		for key in saved_unlocked:
			if definitions.has(str(key)) and str(key) not in unlocked: unlocked.append(str(key))
	var saved_active = data.get("active_project", {})
	active_project = saved_active if saved_active is Dictionary else {}
	var saved_world = data.get("world_projects", {})
	world_projects = saved_world if saved_world is Dictionary else {}
	var saved_effects = data.get("effect_applied", {})
	effect_applied = saved_effects if saved_effects is Dictionary else {}
	guard_power = int(data.get("guard_power", 0)); last_completed_id = str(data.get("last_completed_id", ""))

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
