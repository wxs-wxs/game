class_name FireStateService
extends RefCounted

const SOURCE_IDS := ["campfire", "house_fireplace"]

func default_states(config: Dictionary = {}) -> Dictionary:
	var capacity := maxf(0.1, float(config.get("fuel_capacity", 360.0)))
	var per_wood := maxf(0.1, float(config.get("fuel_per_wood", 120.0)))
	var result := {}
	for source_id in SOURCE_IDS:
		result[source_id] = {"lit": false, "fuel_remaining": 0.0, "fuel_capacity": capacity, "fuel_per_wood": per_wood}
	return result

func add_fuel(states: Dictionary, source_id: String, wood: int, resources: Object, config: Dictionary) -> Dictionary:
	if wood <= 0 or not states.has(source_id):
		return {"ok": false, "reason": "无法添加燃料。"}
	var state: Dictionary = states[source_id]
	if not resources.can_afford({"wood": wood}):
		return {"ok": false, "reason": resources.missing_cost_text({"wood": wood})}
	var per_wood := maxf(0.1, float(config.get("wood_seconds", state.get("fuel_per_wood", config.get("fuel_per_wood", 120.0)))))
	var capacity := maxf(0.1, float(state.get("fuel_capacity", config.get("fuel_capacity", 360.0))))
	var available := maxf(0.0, capacity - float(state.get("fuel_remaining", 0.0)))
	var accepted_wood := mini(wood, int(ceil(available / per_wood)))
	var added := minf(float(accepted_wood) * per_wood, available)
	if accepted_wood <= 0 or added <= 0.0:
		return {"ok": false, "reason": "燃料已经满了。"}
	if not resources.spend({"wood": accepted_wood}):
		return {"ok": false, "reason": resources.missing_cost_text({"wood": accepted_wood})}
	state["fuel_remaining"] = float(state.get("fuel_remaining", 0.0)) + added
	state["lit"] = true
	states[source_id] = state
	return {"ok": true, "reason": "火焰重新燃旺。", "state": state.duplicate(true)}

func tick(states: Dictionary, delta: float) -> Array[String]:
	var extinguished: Array[String] = []
	if delta <= 0.0:
		return extinguished
	for source_id in states.keys():
		var state: Dictionary = states[source_id]
		var was_lit := bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0
		var remaining := maxf(0.0, float(state.get("fuel_remaining", 0.0)) - delta)
		state["fuel_remaining"] = remaining
		if remaining <= 0.0:
			state["lit"] = false
			if was_lit:
				extinguished.append(str(source_id))
		states[source_id] = state
	return extinguished

func is_active(states: Dictionary, source_id: String) -> bool:
	var state: Dictionary = states.get(source_id, {})
	return bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0

func to_dict(states: Dictionary) -> Dictionary:
	return states.duplicate(true)

func from_dict(states: Dictionary, data: Dictionary) -> Dictionary:
	for source_id in SOURCE_IDS:
		var saved: Variant = data.get(source_id, {})
		if not saved is Dictionary or not states.has(source_id):
			continue
		var merged: Dictionary = states[source_id].duplicate(true)
		for key in saved:
			merged[key] = saved[key]
		merged["fuel_remaining"] = clampf(float(merged.get("fuel_remaining", 0.0)), 0.0, float(merged.get("fuel_capacity", 360.0)))
		merged["lit"] = bool(merged.get("lit", false)) and float(merged.get("fuel_remaining", 0.0)) > 0.0
		states[source_id] = merged
	return states
