class_name BuildModeController
extends Node2D

var world
var active := false
var selected_blueprint := "storage_shelf"
var ghost_position := Vector2.ZERO
var site

# Keep the preview close to the player, but do not leave the default camp
# spawn stuck on top of the campfire. The first entry is the preferred facing
# position; the remaining offsets form a small clockwise search ring.
const PLACEMENT_OFFSETS := [
	Vector2(18, 0), Vector2(24, 8), Vector2(16, 16), Vector2(8, 24),
	Vector2(-8, 24), Vector2(-16, 16), Vector2(-24, 8), Vector2(-24, 0),
	Vector2(-16, -16), Vector2(-8, -24), Vector2(8, -24), Vector2(16, -16),
	Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)
]

func setup(manager) -> void: world = manager; set_process(true)

func toggle() -> void:
	active = not active
	if active: _update_ghost_position()
	queue_redraw()

func _process(_delta: float) -> void:
	if not active or world == null or world.player == null: return
	_update_ghost_position()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey:
		var selection_key := event as InputEventKey
		if selection_key.pressed and not selection_key.echo and selection_key.keycode == KEY_Q:
			cycle_blueprint()
			_mark_input_handled()
			return
	var cancel_pressed: bool = event.is_action_pressed("cancel_action") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		# Physical-key fallback keeps E working when the action map is incomplete
		# or the active keyboard layout reports a different keycode.
		cancel_pressed = cancel_pressed or (key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE))
	var confirm_pressed: bool = event.is_action_pressed("interact")
	if event is InputEventKey:
		var key_event := event as InputEventKey
		confirm_pressed = confirm_pressed or (key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E))
		if cancel_pressed:
			active = false
			queue_redraw()
			_mark_input_handled()
		elif confirm_pressed:
			confirm_build()
			_mark_input_handled()

func cycle_blueprint() -> void:
	if world == null or world.game == null or world.game.buildings == null: return
	var choices: Array[String] = []
	for definition in world.game.buildings.catalog("exploration"):
		var id := str(definition.get("id", ""))
		if world.game.buildings.is_unlocked(id, world.game.construction_skill.level) and not world.game.buildings.has(id): choices.append(id)
	if choices.is_empty(): return
	var index := choices.find(selected_blueprint)
	selected_blueprint = choices[(index + 1) % choices.size()]
	_update_ghost_position()
	world.interaction_result.emit("已选择建造：%s" % str(world.game.buildings.get_definition(selected_blueprint).get("name", selected_blueprint)))
	queue_redraw()

func can_place() -> bool:
	if world == null or world.is_inside or world.game.construction_skill == null: return false
	var defs: Dictionary = world.game.buildings.definitions
	if not defs.has(selected_blueprint) or not world.game.buildings.is_unlocked(selected_blueprint, world.game.construction_skill.level): return false
	var definition: Dictionary = defs[selected_blueprint]
	if int(definition.get("required_skill_level", 1)) > world.game.construction_skill.level: return false
	if not world.game.resources.can_afford(definition.get("cost", {})): return false
	if world.player.global_position.distance_to(ghost_position) > 34.0: return false
	for point in world.interactions:
		if point.global_position.distance_to(ghost_position) < 18.0: return false
	if world.is_inside_tree():
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := RectangleShape2D.new(); shape.size = Vector2(16, 16); query.shape = shape; query.transform = Transform2D(0.0, ghost_position); query.collide_with_bodies = true
		for hit in world.get_world_2d().direct_space_state.intersect_shape(query, 8):
			if hit.get("collider") is StaticBody2D: return false
	return true

func confirm_build() -> bool:
	if world != null and world.game != null and world.game.day_return_required:
		world.game.daily_log.append("建造失败：天色已晚，请先回到床边。")
		world.interaction_result.emit("天色已晚，请先回到床边。")
		return false
	if not can_place():
		if world != null and world.game.audio != null: world.game.audio.play_sfx("resource_shortage")
		if world != null: world.interaction_result.emit("无法建造：材料、技能或位置不满足。")
		return false
	var definition: Dictionary = world.game.buildings.definitions[selected_blueprint]
	var started: Dictionary = world.game.buildings.start_world_project(selected_blueprint, ghost_position, world.game.resources, world.game.construction_skill.level)
	if not bool(started.get("ok", false)):
		world.game.daily_log.append("建造失败：%s" % str(started.get("reason", "无法建造")))
		world.interaction_result.emit(str(started.get("reason", "无法建造")))
		return false
	site = preload("res://scripts/construction_site.gd").new(); world.add_child(site); site.position = ghost_position; site.setup(world.game, selected_blueprint, world.game.construction_skill.build_time(float(definition.get("build_time", 5.0))))
	world.game.daily_log.append("建造开始：%s。" % str(definition.get("name", selected_blueprint)))
	world.interaction_result.emit("开始建造 %s" % str(definition.get("name", selected_blueprint)))
	active = false; queue_redraw(); return true

func _update_ghost_position() -> void:
	if world == null or world.player == null:
		return
	var preferred := _snap(world.player.global_position + PLACEMENT_OFFSETS[0])
	ghost_position = preferred
	if can_place():
		return
	for offset in PLACEMENT_OFFSETS.slice(1):
		var candidate := _snap(world.player.global_position + offset)
		ghost_position = candidate
		if can_place():
			return
	# Preserve the preferred position when every nearby tile is blocked. This
	# keeps the red preview meaningful and lets the player walk to open ground.
	ghost_position = preferred

func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _snap(value: Vector2) -> Vector2: return Vector2(round(value.x / 8.0) * 8.0, round(value.y / 8.0) * 8.0)

func _draw() -> void:
	if not active: return
	var tint := Color("76c88b") if can_place() else Color("c76d67")
	draw_rect(Rect2(ghost_position - Vector2(8, 8), Vector2(16, 16)), Color(tint, 0.35), true)
	draw_rect(Rect2(ghost_position - Vector2(8, 8), Vector2(16, 16)), tint, false, 1.0)
