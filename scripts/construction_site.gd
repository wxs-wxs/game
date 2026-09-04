class_name ConstructionSite
extends Node2D

const NINJA_CRATE := preload("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")

var game: GameManager
var blueprint_id := ""
var build_time := 1.0
var progress := 0.0
var completed := false
signal construction_completed(site: ConstructionSite)

func setup(manager: GameManager, id: String, duration: float) -> void:
	game = manager; blueprint_id = id; build_time = maxf(0.1, duration)
	if blueprint_id == "storage_shelf":
		var art := Sprite2D.new()
		art.name = "NinjaAdventureConstructionArt"
		art.texture = NINJA_CRATE
		art.scale = Vector2(2, 2)
		art.modulate = Color(1.0, 1.0, 1.0, 0.62)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.z_index = 1
		add_child(art)
	queue_redraw()

func _process(delta: float) -> void:
	if completed or game == null or game.time.paused: return
	var canonical_progress := false
	if game.buildings != null and game.buildings.world_projects.has(blueprint_id):
		canonical_progress = true
		game.buildings.advance_world_project(blueprint_id, delta)
		var project: Dictionary = game.buildings.world_projects.get(blueprint_id, {})
		progress = build_time if project.is_empty() and game.buildings.has(blueprint_id) else float(project.get("progress", progress))
	if not canonical_progress:
		progress = minf(build_time, progress + delta)
	if progress >= build_time or (canonical_progress and game.buildings.has(blueprint_id)):
		completed = true
		if game.construction_skill != null:
			game.construction_skill.completed_count += 1
			game.grant_construction_xp(10)
		var first_completion := not game.buildings.has(blueprint_id)
		game.complete_world_construction(blueprint_id)
		if first_completion and blueprint_id == "storage_shelf": _register_outdoor_shelf()
		if game.audio != null: game.audio.play_sfx("build_complete")
		construction_completed.emit(self)
	queue_redraw()

func _draw() -> void:
	if blueprint_id == "storage_shelf":
		var art := get_node_or_null("NinjaAdventureConstructionArt") as Sprite2D
		if art != null:
			art.modulate.a = 1.0 if completed else 0.62
		return
	var tint := Color("dca85e") if not completed else Color("84a98c")
	draw_rect(Rect2(-8, -8, 16, 16), Color(tint, 0.35), true)
	draw_rect(Rect2(-8, -8, 16, 16), tint, false, 1.0)

func _register_outdoor_shelf() -> void:
	var world = game.exploration_world if game != null else null
	if world == null or not world.has_method("_add_point"):
		return
	for point in world.interactions:
		if is_instance_valid(point) and point.unique_id == "storage_shelf_outdoor":
			return
	var shelf = preload("res://scripts/storage_shelf_point.gd").new()
	shelf.unique_id = "storage_shelf_outdoor"
	world._add_point(shelf, position)
