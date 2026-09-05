class_name ExplorationWorld
extends Node2D

signal interaction_changed(prompt: String)
signal interaction_result(message: String)
signal interaction_progress_changed(name: String, progress: float)
signal storage_open_requested
signal tool_selection_requested

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
const WorldCollisionBuilder = preload("res://scripts/world/map/world_collision_builder.gd")
const WorldMapRenderer = preload("res://scripts/world/map/world_map_renderer.gd")
const WorldInteractionRegistry = preload("res://scripts/world/interaction/world_interaction_registry.gd")
const MAP_SIZE := WorldLayout.MAP_SIZE
# Keep the room outside the outdoor map's full draw and collision range.  The
# old x=1500 placement overlapped the eastern river and its collision polygon,
# which made those outdoor obstacles appear as indoor air walls.
const INTERIOR_OFFSET := WorldLayout.INTERIOR_OFFSET
const INTERIOR_ROOM_SIZE := WorldLayout.INTERIOR_ROOM_SIZE
const CAMERA_LOOK_AHEAD := Vector2(0, -48)
const DUSK_BLOCKED_ACTIONS := ["chop", "mine_stone", "fish", "gather", "search_ruins", "collect_branch", "pickup", "build", "construct"]
const OUTDOOR_CAMERA_ZOOM := Vector2(1.35, 1.35)
const INTERIOR_CAMERA_ZOOM := Vector2(2.2, 2.2)
const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const NATURE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png"
# The camp shelter is drawn with its doorway centered at (158, 124).  Keep the
# interaction point on that artwork instead of placing a second marker at the
# perimeter gate.  The outside threshold is where the player's 12x14 body can
# stand immediately below the visual door.
const HOUSE_DOOR_POSITION := WorldLayout.HOUSE_DOOR_POSITION
const HOUSE_DOOR_OUTSIDE_POSITION := WorldLayout.HOUSE_DOOR_OUTSIDE_POSITION
# The village atlas is tightly packed: the ruin is the first 4x3 tile block.
const RUIN_TEXTURE_REGION := Rect2(0, 0, 64, 48)
const HARVESTABLE_TREE_POSITIONS := WorldLayout.HARVESTABLE_TREE_POSITIONS
const GROVE_TREE_POSITIONS := WorldLayout.GROVE_TREE_POSITIONS
# The old water block was a closed 370x264 rectangle, which read as a pond and
# also created several invisible wall strips around it.  This is now a coastal
# river mouth: it runs beyond both map edges and occupies the far-east margin.
const RIVER_RECT := WorldLayout.RIVER_RECT
const RIVER_BANK_SWING := WorldLayout.RIVER_BANK_SWING
var world_layout: WorldLayout = WorldLayout.new()
var collision_builder: WorldCollisionBuilder = WorldCollisionBuilder.new()
var map_renderer: WorldMapRenderer
var interaction_registry: WorldInteractionRegistry = WorldInteractionRegistry.new()
var map_size := world_layout.MAP_SIZE
var game: GameManager
var player: ExplorerPlayer
var interactions: Array[InteractionPoint] = []
var nearest: InteractionPoint
var active_interaction: InteractionPoint
var is_inside := false
var outdoor_position := Vector2(180, 155)
var interior_manager
var build_mode
var last_weather := ""
var last_nearest_prompt := ""
var visual_clock := 0.0
var fish_school: Node2D
func _init() -> void:
	# Interaction props share one depth layer so their screen-space Y controls
	# overlap: objects farther down the map are closer to the camera.
	y_sort_enabled = true
	interaction_registry.setup(self, null)
	interactions = interaction_registry.points

func setup(manager: GameManager) -> void:
	game = manager
	game.exploration_world = self
	interaction_registry.setup(self, game)
	interaction_registry.set_availability(_is_point_available)
	_build_collisions()
	_build_points()
	if game != null and game.buildings != null:
		if game.buildings.has("storage_shelf"): register_outdoor_shelf()
		if game.buildings.has("workbench"): register_outdoor_workbench()
	map_renderer = WorldMapRenderer.new()
	map_renderer.name = "WorldMapRenderer"
	add_child(map_renderer)
	map_renderer.setup(game, world_layout)
	map_renderer.rebuild()
	fish_school = preload("res://scripts/river_fish_school.gd").new()
	fish_school.name = "RiverFishSchool"
	add_child(fish_school)
	player = ExplorerPlayer.new()
	player.name = "Player"
	player.position = Vector2(180, 155)
	add_child(player)
	player.setup(game, self)
	var camera := Camera2D.new()
	camera.position = CAMERA_LOOK_AHEAD
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	# Pull the camera back so exploration shows a wider, more useful slice of
	# the map while keeping the pixel-art scale crisp.
	camera.zoom = OUTDOOR_CAMERA_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	player.add_child(camera)
	interior_manager = preload("res://scripts/interior_manager.gd").new(); interior_manager.name = "InteriorManager"; add_child(interior_manager)
	build_mode = preload("res://scripts/build_mode_controller.gd").new(); build_mode.name = "BuildMode"; add_child(build_mode); build_mode.setup(self)
	interaction_registry.restore_construction_sites()
	last_weather = game.weather
	_refresh_audio_context()
	visual_clock = 0.0
	queue_redraw()

func _restore_construction_sites() -> void:
	interaction_registry.restore_construction_sites()

func _process(delta: float) -> void:
	# Keep the map atmosphere alive independently from the simulation clock. The
	# small multiplier while paused preserves a readable pause state without
	# making rain and marker pulses appear frozen in a screenshot.
	visual_clock = fmod(visual_clock + maxf(delta, 0.0) * (0.22 if game != null and game.time.paused else 1.0), 100000.0)
	queue_redraw()
	active_interaction = interaction_registry.active_interaction
	if map_renderer != null:
		map_renderer.set_visual_clock(visual_clock)
		map_renderer.set_marker_state(interactions, nearest, active_interaction, is_inside)
		if game != null and last_weather != game.weather:
			map_renderer.refresh_weather(game.weather)
	if player == null: return
	if game.audio != null and last_weather != game.weather:
		last_weather = game.weather
		_refresh_audio_context()
	elif game.audio != null and not is_inside and active_interaction == null:
		_refresh_audio_context()
	if active_interaction != null:
		if not active_interaction.interacting:
			active_interaction = null
			interaction_registry.active_interaction = null
		else:
			var result := active_interaction.tick_interaction(delta)
			interaction_progress_changed.emit(active_interaction.display_name, active_interaction.interaction_progress / maxf(0.01, active_interaction.interaction_time))
			if not active_interaction.interacting:
				active_interaction = null
				interaction_registry.active_interaction = null
				interaction_changed.emit("")
			return
	var candidate := interaction_registry.nearest(player.global_position, INF)
	if candidate != nearest:
		nearest = candidate
	var next_prompt := nearest.prompt_text() if nearest != null else ""
	if next_prompt != last_nearest_prompt:
		last_nearest_prompt = next_prompt
		interaction_changed.emit(next_prompt)

func try_interact() -> void:
	if build_mode != null and build_mode.active: return
	if game.time.paused and not game.day_return_required:
		interaction_result.emit("游戏已暂停。")
		return
	if nearest == null:
		interaction_result.emit("附近没有可交互的目标。")
		return
	if active_interaction != null:
		interaction_result.emit("交互进行中。")
		return
	if game.day_return_required and nearest.action_id in DUSK_BLOCKED_ACTIONS:
		interaction_result.emit("天色已晚，请先回到床边。")
		return
	var result := nearest.interact()
	interaction_result.emit(str(result.get("message", result.get("reason", ""))))
	interaction_changed.emit(nearest.prompt_text())
	if bool(result.get("started", false)):
		active_interaction = nearest
		interaction_registry.active_interaction = nearest

func cancel_interaction() -> void:
	if active_interaction != null:
		active_interaction.cancel_interaction()
		interaction_result.emit("已取消交互。")
		active_interaction = null
		interaction_registry.active_interaction = null
		interaction_changed.emit(nearest.prompt_text() if nearest != null else "")

func is_interacting() -> bool: return active_interaction != null and active_interaction.interacting

func _build_points() -> void:
	_add_point(CampfirePoint.new(), Vector2(210, 153))
	var door = preload("res://scripts/house_door.gd").new()
	door.configure(self, false)
	_add_point(door, HOUSE_DOOR_POSITION)
	_add_point(FishingSpot.new(), Vector2(1490, 236))
	_add_point(ForageSpot.new(), Vector2(190, 565))
	_add_point(ForageSpot.new(), Vector2(340, 610))
	# Place gatherable props in open grass clearings so each pickup is easy to
	# spot without prescribing a route through the map.
	for position in [Vector2(300, 125), Vector2(420, 300), Vector2(270, 520), Vector2(1270, 300), Vector2(1450, 470), Vector2(1500, 590)]:
		_add_point(PebbleSpot.new(), position)
	# Large boulders are separate mining sources. The small PebbleSpot points
	# above remain free pickups, while these points require a stone pickaxe.
	for position in [Vector2(364, 159), Vector2(446, 242), Vector2(295, 423), Vector2(450, 550), Vector2(826, 502), Vector2(883, 604), Vector2(1328, 402), Vector2(1480, 564), Vector2(1510, 746), Vector2(1480, 930)]:
		_add_point(RockPileSpot.new(), position)
	for position in [Vector2(260, 235), Vector2(280, 390), Vector2(320, 650), Vector2(1210, 670), Vector2(1380, 850), Vector2(1500, 840)]:
		_add_point(BranchSpot.new(), position)
	# Forest trees are present in the landmark layer and become harvestable once
	# the player crafts a stone axe.  Their interaction points are centered on
	# the same trunks used by the map art.
	for position in HARVESTABLE_TREE_POSITIONS:
		_add_point(TreeSpot.new(), position)
	var tree_variants: Array[Texture2D] = [
		Assets.region(NATURE_ATLAS, Rect2(0, 0, 32, 32)),
		Assets.region(NATURE_ATLAS, Rect2(32, 0, 32, 32)),
		Assets.region(NATURE_ATLAS, Rect2(96, 0, 32, 32))
	]
	for index in range(GROVE_TREE_POSITIONS.size()):
		var small_tree := TreeSpot.new()
		small_tree.configure_small_tree(tree_variants[index % tree_variants.size()], Vector2(1.28 + float(index % 3) * 0.10, 1.28 + float(index % 3) * 0.10))
		_add_point(small_tree, GROVE_TREE_POSITIONS[index])
	_add_point(RuinSpot.new(), Vector2(1040, 515))

func _add_point(point: InteractionPoint, at: Vector2) -> void:
	point.position = at
	add_child(point)
	point.setup(game)
	point.interaction_completed.connect(_on_point_completed)
	interaction_registry.register(point)

func register_outdoor_shelf() -> void:
	for point in interactions:
		if is_instance_valid(point) and point.unique_id == "storage_shelf_outdoor": return
	var shelf := preload("res://scripts/storage_shelf_point.gd").new()
	shelf.unique_id = "storage_shelf_outdoor"
	_add_point(shelf, game.outdoor_position + Vector2(26, 0))

func register_outdoor_workbench(at: Vector2 = Vector2(-99999, -99999)) -> void:
	for point in interactions:
		if is_instance_valid(point) and point.unique_id == "workbench_outdoor":
			if at.x > -90000.0: point.position = at
			return
	var workbench := preload("res://scripts/construction_facility_point.gd").new()
	workbench.configure("workbench_outdoor", "简易工作台", Color("b8a16b"))
	var position := at if at.x > -90000.0 else game.outdoor_position + Vector2(32, 0)
	_add_point(workbench, position)

func register_interior_point(point: InteractionPoint) -> void:
	if point == null or not is_instance_valid(point): return
	point.interaction_completed.connect(_on_point_completed)
	interaction_registry.register(point)

func toggle_house() -> void:
	if is_inside: exit_house()
	else: enter_house()

func enter_house() -> void:
	if is_inside or player == null: return
	# A door interaction can begin from any side within its radius.  Always keep
	# the return point on the walkable threshold so exiting cannot place the
	# player inside the tent collision or at the old perimeter gate.
	outdoor_position = HOUSE_DOOR_OUTSIDE_POSITION
	is_inside = true
	nearest = null
	for point in interactions:
		if is_instance_valid(point) and point.get_parent() == self: point.set_process(false); point.hide()
	var interior = interior_manager.enter(self)
	if player.has_method("set_interior_state"): player.set_interior_state(true)
	else: player.interior = true
	player.global_position = interior.player_spawn_global() if interior.has_method("player_spawn_global") else interior.global_position + Vector2(24, 90)
	_set_camera_limits(int(INTERIOR_OFFSET.x), int(INTERIOR_OFFSET.y), int(INTERIOR_OFFSET.x + INTERIOR_ROOM_SIZE.x), int(INTERIOR_OFFSET.y + INTERIOR_ROOM_SIZE.y))
	_set_camera_zoom(INTERIOR_CAMERA_ZOOM)
	game.in_house = true; game.outdoor_position = outdoor_position
	_refresh_audio_context()
	interaction_changed.emit("")

func exit_house() -> void:
	if not is_inside or player == null: return
	nearest = null
	interior_manager.exit()
	is_inside = false
	for point in interactions:
		if is_instance_valid(point) and point.get_parent() == self: point.set_process(true); point.show()
	player.global_position = _safe_outdoor_position(outdoor_position)
	if player.has_method("set_interior_state"): player.set_interior_state(false)
	else: player.interior = false
	_set_camera_limits(0, 0, int(map_size.x), int(map_size.y))
	_set_camera_zoom(OUTDOOR_CAMERA_ZOOM)
	game.in_house = false
	_refresh_audio_context()
	interaction_changed.emit("")

func _safe_outdoor_position(value: Vector2) -> Vector2:
	return world_layout.safe_outdoor_position(value)

func get_player_bounds() -> Rect2:
	if is_inside:
		if interior_manager != null and is_instance_valid(interior_manager.interior):
			if interior_manager.interior.has_method("player_bounds_global"):
				return interior_manager.interior.player_bounds_global()
		# Keep an indoor fallback while InteriorManager is creating/removing the
		# room; returning outdoor bounds here would snap an indoor player back into
		# the expanded outdoor field.
		return world_layout.interior_bounds()
	return world_layout.outdoor_playable_bounds()

func _is_point_available(point: InteractionPoint) -> bool:
	if not is_instance_valid(point): return false
	if not point.visible or point.respawn_remaining > 0.0: return false
	# Outdoor points are direct children of this world.  Indoor points must be
	# children of the currently active room, not merely any non-world parent:
	# InteriorManager frees rooms deferred, so the old points can briefly remain
	# in the interaction registry during a transition.
	if not is_inside:
		return point.get_parent() == self
	return interior_manager != null and is_instance_valid(interior_manager.interior) and point.get_parent() == interior_manager.interior

func respawn_point(point: InteractionPoint) -> void:
	if point == null or not is_instance_valid(point): return
	var candidate := _random_grass_position(point)
	if candidate != Vector2.ZERO:
		point.position = candidate
	point.show()
	point.respawn_remaining = 0.0
	point.cooldown_remaining = 0.0

func _random_grass_position(excluding: InteractionPoint) -> Vector2:
	for _attempt in range(90):
		var candidate := Vector2(game.rng.randf_range(36.0, map_size.x - 36.0), game.rng.randf_range(36.0, map_size.y - 36.0))
		# Keep respawns in visible grass, away from the river channel, camp and ruins.
		if candidate.x >= _river_bank_x(candidate.y) - 18.0: continue
		if Rect2(55, 55, 225, 175).has_point(candidate): continue
		if Rect2(945, 370, 225, 205).has_point(candidate): continue
		var blocked := false
		for point in interactions:
			if point == excluding or not is_instance_valid(point) or not point.visible: continue
			if candidate.distance_to(point.position) < 30.0:
				blocked = true
				break
		if blocked: continue
		return candidate
	return Vector2.ZERO

func serialize_state() -> Dictionary:
	return interaction_registry.serialize_state()

func restore_state(data: Dictionary) -> void:
	for child in get_children():
		if child is ConstructionSite: child.queue_free()
	interaction_registry.restore_construction_sites()
	var saved_position = data.get("outdoor_position", [180, 155])
	if saved_position is Array and saved_position.size() >= 2: outdoor_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	if game != null and game.buildings != null and game.buildings.has("workbench") and not _has_outdoor_workbench():
		register_outdoor_workbench()
	interaction_registry.restore_state(data)
	active_interaction = interaction_registry.active_interaction
	if bool(data.get("in_house", false)) and not is_inside: enter_house()
	elif not bool(data.get("in_house", false)) and is_inside: exit_house()
	_refresh_audio_context()

func _has_outdoor_workbench() -> bool:
	for point in interactions:
		if is_instance_valid(point) and point.unique_id == "workbench_outdoor" and point.get_parent() == self:
			return true
	return false

func _set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	for child in player.get_children():
		if child is Camera2D:
			child.limit_left = left; child.limit_top = top; child.limit_right = right; child.limit_bottom = bottom

func _set_camera_zoom(value: Vector2) -> void:
	if player == null:
		return
	for child in player.get_children():
		if child is Camera2D:
			child.zoom = value

func _refresh_audio_context() -> void:
	if game == null or game.audio == null:
		return
	if player != null and game.audio.has_method("set_listener_position"):
		game.audio.set_listener_position(player.global_position)
	if not game.audio.has_method("set_world_state"):
		return
	var phase := "exploration"
	match str(game.phase):
		GameManager.PHASE_EVENT, GameManager.PHASE_REPORT:
			phase = "night_report"
		GameManager.PHASE_ENDED:
			phase = "game_over"
	var near_fire := false
	if is_inside:
		near_fire = game.is_fire_active("house_fireplace")
	elif player != null:
		for point in interactions:
			if is_instance_valid(point) and point.unique_id == "campfire" and game.is_fire_active("campfire") and player.global_position.distance_to(point.global_position) < 90.0:
				near_fire = true
				break
	var location := "interior" if is_inside else "outdoor"
	var weather := str(game.weather)
	if phase == "game_over":
		location = "outdoor"
		weather = "clear"
		near_fire = false
	game.audio.set_world_state({
		"phase": phase,
		"location": location,
		"weather": weather,
		"threat": "low",
		"fire_lit": near_fire
	})

func is_near_active_campfire(radius: float = 110.0) -> bool:
	if is_inside or game == null or player == null or not game.is_fire_active("campfire"):
		return false
	for point in interactions:
		if not is_instance_valid(point) or point.unique_id != "campfire" or point.get_parent() != self:
			continue
		if player.global_position.distance_to(point.global_position) <= radius:
			return true
	return false

func _on_point_completed(point: InteractionPoint, result: Dictionary) -> void:
	interaction_result.emit("%s：%s" % [point.display_name, str(result.get("message", "完成"))])
	if bool(result.get("open_storage", false)):
		storage_open_requested.emit()
	if bool(result.get("open_tool_selection", false)):
		tool_selection_requested.emit()
	_refresh_audio_context()

func _build_collisions() -> void:
	collision_builder.build(self, world_layout)

func _add_wall(rect: Rect2, kind: String = "Landmark") -> void:
	collision_builder.add_wall(self, rect, kind)

func _river_bank_x(y: float) -> float:
	return world_layout.river_bank_x(y)

func _add_water_collision() -> void:
	collision_builder.add_water_collision(self, world_layout)

func _build_art_sprites() -> void:
	if map_renderer != null:
		map_renderer.rebuild()

func _build_ground_decorations() -> void:
	if map_renderer != null:
		map_renderer.rebuild()

func _add_world_sprite(texture: Texture2D, at: Vector2, scale_value := Vector2.ONE, layer := 1) -> Sprite2D:
	if map_renderer != null:
		return map_renderer._add_world_sprite(texture, at, scale_value, layer)
	return null

func _draw() -> void:
	# Map pixels are drawn by the child WorldMapRenderer.
	pass
