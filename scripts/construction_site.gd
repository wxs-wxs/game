class_name ConstructionSite
extends Node2D

const NINJA_CRATE := preload("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")

var game: GameManager
var blueprint_id := ""
var build_time := 1.0
var progress := 0.0
var completed := false
var workbench_art: WorkbenchArt
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
	elif blueprint_id == "workbench":
		workbench_art = preload("res://scripts/workbench_art.gd").new()
		workbench_art.name = "WorkbenchArt"
		add_child(workbench_art)
		workbench_art.setup(false)
	queue_redraw()

func _process(delta: float) -> void:
	if completed or game == null or game.time.paused: return
	if game.buildings != null and not game.buildings.active_project.is_empty() and str(game.buildings.active_project.get("id", "")) == blueprint_id:
		game.buildings.advance_active_project(delta)
		var project: Dictionary = game.buildings.active_project
		if project.is_empty() and game.buildings.has(blueprint_id): progress = build_time
		else: progress = float(project.get("progress", progress))
	if progress >= build_time or (game.buildings != null and game.buildings.has(blueprint_id) and game.buildings.active_project.is_empty()):
		_complete_once()
	queue_redraw()

func _complete_once() -> void:
	if completed or game == null: return
	completed = true
	if game.construction_skill != null:
		game.construction_skill.completed_count += 1
		game.grant_construction_xp(10)
	game.complete_world_construction(blueprint_id)
	if blueprint_id == "storage_shelf": _register_outdoor_shelf()
	if blueprint_id == "workbench": _register_outdoor_workbench()
	if game.audio != null: game.audio.play_sfx("build_complete")
	visible = false
	construction_completed.emit(self)
	queue_free()

func _draw() -> void:
	if blueprint_id == "storage_shelf":
		var art := get_node_or_null("NinjaAdventureConstructionArt") as Sprite2D
		if art != null:
			art.modulate.a = 1.0 if completed else 0.62
		return
	if blueprint_id == "workbench":
		if workbench_art != null: workbench_art.set_completed(completed)
		if not completed:
			draw_rect(Rect2(-20, -20, 40, 40), Color("b8a16b", 0.18), false, 1.0)
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
			point.position = position
			return
	var shelf = preload("res://scripts/storage_shelf_point.gd").new()
	shelf.unique_id = "storage_shelf_outdoor"
	world._add_point(shelf, position)

func _register_outdoor_workbench() -> void:
	var world = game.exploration_world if game != null else null
	if world == null or not world.has_method("register_outdoor_workbench"):
		return
	world.register_outdoor_workbench(position)
