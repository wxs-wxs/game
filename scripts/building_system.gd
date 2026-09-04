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
# Kept as a read-only compatibility surface for older save/tests. New projects
# are always represented by active_project.
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

func construction_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in definitions.keys():
		result.append(definitions[key].duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func active_construction() -> Dictionary:
	return active_project.duplicate(true)

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
	return start_unified_project(building_id, Vector2.ZERO, resources, skill_level)

func start_unified_project(building_id: String, position: Vector2, resources: ResourceManager, skill_level: int) -> Dictionary:
	if built.has(building_id): return {"ok":false, "reason":"设施已经建成"}
	if not active_project.is_empty(): return {"ok":false, "reason":"已有建造项目"}
	var definition := get_definition(building_id)
	if definition.is_empty(): return {"ok":false, "reason":"未知设施"}
	if not is_unlocked(building_id, skill_level): return {"ok":false, "reason":"技能等级不足或设施尚未解锁"}
	var cost: Dictionary = definition.get("cost", {}).duplicate(true)
	if not resources.can_afford(cost): return {"ok":false, "reason":resources.missing_cost_text(cost)}
	if not resources.spend(cost): return {"ok":false, "reason":"材料扣除失败"}
	var duration := maxf(0.5, float(definition.get("build_time", definition.get("work", 1.0))))
	var required := duration * (1.0 - 0.05 * float(maxi(1, skill_level) - 1))
	active_project = {"id":building_id, "position":[position.x, position.y], "progress":0.0, "required":maxf(0.5, required), "cost":cost, "duration":duration}
	return {"ok":true, "reason":"开始建造 %s" % str(definition.get("name", building_id)), "project":active_project.duplicate(true)}

func add_work(amount: int) -> String:
	last_completed_id = ""
	if active_project.is_empty(): return ""
	var building_id := str(active_project.get("id", ""))
	if not advance_active_project(float(maxi(0, amount))): return ""
	return building_id

func start_world_project(building_id: String, position: Vector2, resources: ResourceManager, skill_level: int) -> Dictionary:
	return start_unified_project(building_id, position, resources, skill_level)

func advance_world_project(building_id: String, delta: float) -> bool:
	if active_project.is_empty() or str(active_project.get("id", "")) != building_id: return false
	return advance_active_project(delta)

func advance_active_project(delta: float) -> bool:
	if active_project.is_empty(): return false
	active_project["progress"] = minf(float(active_project.get("required", 1.0)), float(active_project.get("progress", 0.0)) + maxf(0.0, delta))
	if float(active_project["progress"]) < float(active_project.get("required", 1.0)): return false
	var completed_id := str(active_project.get("id", ""))
	active_project = {}
	world_projects = {}
	complete(completed_id)
	return true

func cancel_active_project(resources: ResourceManager) -> Dictionary:
	if active_project.is_empty(): return {"ok":false, "reason":"当前没有施工项目。"}
	var project := active_project.duplicate(true)
	var cost: Dictionary = project.get("cost", {})
	if cost.is_empty(): cost = get_definition(str(project.get("id", ""))).get("cost", {})
	for key in cost:
		resources.add(str(key), int(cost[key]))
	active_project = {}
	world_projects = {}
	return {"ok":true, "reason":"已取消建造并返还材料。", "project":project}

func complete(building_id: String) -> String:
	last_completed_id = ""
	if building_id.is_empty() or built.has(building_id): return ""
	built[building_id] = 1
	last_completed_id = building_id
	return str(definitions.get(building_id, {}).get("name", building_id))

func has(building_id: String) -> bool: return int(built.get(building_id, 0)) > 0
func rest_bonus() -> int: return 4 if has("bed") else 0
func clinic_bonus() -> int: return 2 if has("clinic") else 0
func warmth_bonus() -> float: return 4.0 if has("fire_basin") else 0.0
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
	active_project = {}
	if saved_active is Dictionary:
		var active_id := str(saved_active.get("id", ""))
		if definitions.has(active_id):
			active_project = saved_active.duplicate(true)
	var saved_world = data.get("world_projects", {})
	world_projects = {}
	if active_project.is_empty() and saved_world is Dictionary and not saved_world.is_empty():
		for legacy_value in saved_world.values():
			if not legacy_value is Dictionary:
				continue
			var legacy_id := str(legacy_value.get("id", ""))
			if definitions.has(legacy_id):
				active_project = legacy_value.duplicate(true)
				break
	var saved_effects = data.get("effect_applied", {})
	effect_applied = saved_effects if saved_effects is Dictionary else {}
	guard_power = int(data.get("guard_power", 0)); last_completed_id = str(data.get("last_completed_id", ""))

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
