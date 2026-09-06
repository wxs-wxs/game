class_name WorldInteractionRegistry
extends RefCounted

var owner
var game
var points: Array[InteractionPoint] = []
var point_id_counts: Dictionary = {}
var active_interaction: InteractionPoint
var availability: Callable

func setup(world, manager) -> void:
	owner = world
	game = manager

func set_availability(callback: Callable) -> void:
	availability = callback

func register(point: InteractionPoint) -> void:
	if point == null or not is_instance_valid(point) or points.has(point): return
	var base_id := point.unique_id
	var count := int(point_id_counts.get(base_id, 0))
	point_id_counts[base_id] = count + 1
	if count > 0: point.unique_id = "%s_%d" % [base_id, count + 1]
	points.append(point)

func unregister(point: InteractionPoint) -> void:
	if point == null: return
	points.erase(point)
	if active_interaction == point: active_interaction = null

func nearest(position: Vector2, radius: float) -> InteractionPoint:
	var candidate: InteractionPoint
	var best := INF
	for point in points:
		if not is_instance_valid(point) or not _is_available(point): continue
		var distance := position.distance_to(point.global_position)
		if distance <= minf(radius, point.interaction_range + 12.0) and distance < best:
			candidate = point
			best = distance
	return candidate

func _is_available(point: InteractionPoint) -> bool:
	if availability.is_valid(): return bool(availability.call(point))
	return point.can_interact()

func serialize_state() -> Dictionary:
	var interaction_data: Array = []
	for point in points:
		if not is_instance_valid(point): continue
		var row := {"id":point.unique_id, "position":[point.position.x, point.position.y], "cooldown":point.cooldown_remaining, "uses_left":point.uses_left, "progress":point.interaction_progress if point.interacting else 0.0, "active":point.interacting, "visible":point.visible, "respawn":point.respawn_remaining}
		if point is TreeSpot:
			row["stump"] = point.is_stump
			row["regrow"] = point.regrow_remaining
		if point is FireplacePoint: row["lit"] = point.lit
		if point is BedPoint and point.unique_id == "house_bed": row["rested"] = point.rested_this_day
		interaction_data.append(row)
	var position: Vector2 = owner.outdoor_position if owner != null else Vector2(180, 155)
	var in_house := bool(owner.is_inside) if owner != null else false
	return {"in_house":in_house, "outdoor_position":[position.x, position.y], "interactions":interaction_data}

func restore_state(data: Dictionary) -> void:
	active_interaction = null
	var by_id := {}
	for row in data.get("interactions", []): by_id[str(row.get("id", ""))] = row
	for point in points:
		if not is_instance_valid(point) or not by_id.has(point.unique_id): continue
		var row: Dictionary = by_id[point.unique_id]
		var saved_position: Variant = row.get("position", [])
		if saved_position is Array and saved_position.size() >= 2: point.position = Vector2(float(saved_position[0]), float(saved_position[1]))
		point.cooldown_remaining = float(row.get("cooldown", 0.0)); point.uses_left = int(row.get("uses_left", -1)); point.interaction_progress = float(row.get("progress", 0.0)); point.interacting = bool(row.get("active", false)); point.respawn_remaining = float(row.get("respawn", 0.0))
		if point is TreeSpot:
			point.is_stump = bool(row.get("stump", false)); point.regrow_remaining = float(row.get("regrow", 0.0)); point.refresh_tree_art()
		if point is FireplacePoint: point._refresh_fire_visual()
		if point is BedPoint and point.unique_id == "house_bed": point.rested_this_day = bool(row.get("rested", false))
		if bool(row.get("visible", true)): point.show()
		else: point.hide()
		if point.interacting: active_interaction = point

func restore_construction_sites() -> void:
	if owner == null or game == null or game.buildings == null: return
	var project: Dictionary = game.buildings.active_construction()
	if project.is_empty(): return
	var id := str(project.get("id", ""))
	if id.is_empty(): return
	var site := preload("res://scripts/construction_site.gd").new()
	owner.add_child(site)
	var saved_position: Variant = project.get("position", [game.outdoor_position.x, game.outdoor_position.y])
	if saved_position is Array and saved_position.size() >= 2: site.position = Vector2(float(saved_position[0]), float(saved_position[1]))
	site.setup(game, id, float(project.get("required", 1.0)))
	site.progress = float(project.get("progress", 0.0))
