class_name ExplorationWorld
extends Node2D

signal interaction_changed(prompt: String)
signal interaction_result(message: String)
signal interaction_progress_changed(name: String, progress: float)
signal storage_open_requested
signal fish_processing_requested(fish_key: String)
signal tool_selection_requested

const MAP_SIZE := Vector2(1920, 1080)
# Keep the room outside the outdoor map's full draw and collision range.  The
# old x=1500 placement overlapped the eastern river and its collision polygon,
# which made those outdoor obstacles appear as indoor air walls.
const INTERIOR_OFFSET := Vector2(2400, 0)
const INTERIOR_ROOM_SIZE := Vector2(180, 180)
const CAMERA_LOOK_AHEAD := Vector2(0, -48)
const OUTDOOR_CAMERA_ZOOM := Vector2(1.35, 1.35)
const INTERIOR_CAMERA_ZOOM := Vector2(2.2, 2.2)
const Assets = preload("res://scripts/ninja_adventure_assets.gd")
const MAP_FONT := preload("res://assets/fonts/fusion_pixel/fusion-pixel-10px-monospaced-zh_hans.ttf")
const NATURE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png"
const FIELD_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetField.png"
const FLOOR_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetFloor.png"
const WATER_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetWater.png"
const HOUSE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetHouse.png"
const VILLAGE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetVillageAbandoned.png"
const WATER_RIPPLE_SHEET := "res://assets/art/ninja_adventure/Backgrounds/Animated/WaterRipples/SpriteSheet16x16.png"
const NINJA_CRATE := preload("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")
const NINJA_GRASS := preload("res://assets/art/ninja_adventure/Items/Resource/Grass.png")
const NINJA_ROCK := preload("res://assets/art/ninja_adventure/Items/Resource/Rock.png")
const NINJA_BRANCH := preload("res://assets/art/ninja_adventure/Items/Resource/Branch.png")
const NINJA_FIRE_SHEET := "res://assets/art/ninja_adventure/FX/Particle/Fire.png"
const NINJA_FLAG_SHEET := "res://assets/art/ninja_adventure/Backgrounds/Animated/Flag/FlagBrown16x16.png"
# The camp shelter is drawn with its doorway centered at (158, 124).  Keep the
# interaction point on that artwork instead of placing a second marker at the
# perimeter gate.  The outside threshold is where the player's 12x14 body can
# stand immediately below the visual door.
const HOUSE_DOOR_POSITION := Vector2(158, 124)
const HOUSE_DOOR_OUTSIDE_POSITION := Vector2(158, 145)
# The village atlas is tightly packed: the ruin is the first 4x3 tile block.
const RUIN_TEXTURE_REGION := Rect2(0, 0, 64, 48)
const HARVESTABLE_TREE_POSITIONS := [
	Vector2(81, 291), Vector2(146, 341), Vector2(256, 281), Vector2(341, 351),
	Vector2(1390, 238), Vector2(1490, 180), Vector2(1470, 871), Vector2(1470, 920)
]
const GROVE_TREE_POSITIONS := [
	Vector2(48, 254), Vector2(110, 246), Vector2(192, 254), Vector2(278, 246),
	Vector2(60, 386), Vector2(116, 428), Vector2(210, 406), Vector2(286, 438),
	Vector2(955, 344), Vector2(1012, 332), Vector2(1138, 350), Vector2(1190, 392),
	Vector2(1340, 186), Vector2(1430, 152), Vector2(1450, 306), Vector2(1470, 330),
	Vector2(1350, 834), Vector2(1415, 902), Vector2(1490, 878)
]
# The old water block was a closed 370x264 rectangle, which read as a pond and
# also created several invisible wall strips around it.  This is now a coastal
# river mouth: it runs beyond both map edges and occupies the far-east margin.
const RIVER_RECT := Rect2(1532, -32, 388, 1144)
const RIVER_BANK_SWING := 34.0
var map_size := MAP_SIZE
var game: GameManager
var player: ExplorerPlayer
var interactions: Array[InteractionPoint] = []
var nearest: InteractionPoint
var active_interaction: InteractionPoint
var point_id_counts: Dictionary = {}
var is_inside := false
var outdoor_position := Vector2(180, 155)
var interior_manager
var build_mode
var last_weather := ""
var visual_clock := 0.0
var fish_school: Node2D
var grass_tile: Texture2D
var floor_tile: Texture2D
var water_tile: Texture2D
var grass_tile_region := Rect2(16, 64, 16, 16)
var water_tile_region := Rect2(16, 16, 16, 16)
var zone_labels := [
	{"name":"营地", "position":Vector2(110, 74), "color":Color("e0b76c")},
	{"name":"西侧密林", "position":Vector2(96, 470), "color":Color("b4c88a")},
	{"name":"中央草甸", "position":Vector2(650, 108), "color":Color("d3cf8a")},
	{"name":"旧砖场", "position":Vector2(1030, 470), "color":Color("d5b17b")},
	{"name":"东岸浅滩", "position":Vector2(1450, 66), "color":Color("a5d0c3")},
	{"name":"东侧高地", "position":Vector2(1400, 250), "color":Color("c1cb88")},
	{"name":"南部湿地", "position":Vector2(1180, 900), "color":Color("a0c29a")}
]

func setup(manager: GameManager) -> void:
	game = manager
	game.exploration_world = self
	# Keep the atlas as a regular Texture2D for background rendering. Drawing an
	# AtlasTexture directly can resolve the full source atlas in a repeated draw,
	# which turns the field/water sheet into large unrelated color blocks.
	grass_tile = Assets.texture(FIELD_ATLAS)
	floor_tile = Assets.texture(FLOOR_ATLAS)
	water_tile = Assets.texture(WATER_ATLAS)
	_build_collisions()
	_build_points()
	if game != null and game.buildings != null:
		if game.buildings.has("storage_shelf"): register_outdoor_shelf()
		if game.buildings.has("workbench"): register_outdoor_workbench()
	_build_art_sprites()
	_build_ground_decorations()
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
	_restore_construction_sites()
	if game.audio != null:
		game.audio.play_music("day"); _refresh_audio_context()
	last_weather = game.weather
	visual_clock = 0.0
	queue_redraw()

func _restore_construction_sites() -> void:
	if game == null or game.buildings == null: return
	for id in game.buildings.world_projects:
		var project: Dictionary = game.buildings.world_projects[id]
		var site := preload("res://scripts/construction_site.gd").new()
		add_child(site)
		var saved_position: Variant = project.get("position", [game.outdoor_position.x, game.outdoor_position.y])
		if saved_position is Array and saved_position.size() >= 2: site.position = Vector2(float(saved_position[0]), float(saved_position[1]))
		site.setup(game, str(id), float(project.get("required", 1.0)))
		site.progress = float(project.get("progress", 0.0))

func _process(delta: float) -> void:
	# Keep the map atmosphere alive independently from the simulation clock. The
	# small multiplier while paused preserves a readable pause state without
	# making rain and marker pulses appear frozen in a screenshot.
	visual_clock = fmod(visual_clock + maxf(delta, 0.0) * (0.22 if game != null and game.time.paused else 1.0), 100000.0)
	queue_redraw()
	if player == null: return
	if game.audio != null and last_weather != game.weather:
		last_weather = game.weather
		_refresh_audio_context()
	elif game.audio != null and not is_inside and active_interaction == null:
		_refresh_audio_context()
	if active_interaction != null:
		if not active_interaction.interacting: active_interaction = null
		else:
			var result := active_interaction.tick_interaction(delta)
			interaction_progress_changed.emit(active_interaction.display_name, active_interaction.interaction_progress / maxf(0.01, active_interaction.interaction_time))
			if not active_interaction.interacting:
				active_interaction = null
				interaction_changed.emit("")
			return
	var candidate: InteractionPoint
	var best := INF
	for point in interactions:
		if not is_instance_valid(point): continue
		if not _is_point_available(point): continue
		var distance := player.global_position.distance_to(point.global_position)
		if distance <= point.interaction_range + 12.0 and distance < best:
			candidate = point
			best = distance
	if candidate != nearest:
		nearest = candidate
		interaction_changed.emit(nearest.prompt_text() if nearest != null else "")

func try_interact() -> void:
	if build_mode != null and build_mode.active: return
	if game.time.paused:
		interaction_result.emit("游戏已暂停。")
		return
	if nearest == null:
		interaction_result.emit("附近没有可交互的目标。")
		return
	if active_interaction != null:
		interaction_result.emit("交互进行中。")
		return
	if game.day_return_required and not (nearest is BedPoint):
		interaction_result.emit("天色已晚，请先回到床边。")
		return
	var result := nearest.interact()
	interaction_result.emit(str(result.get("message", result.get("reason", ""))))
	interaction_changed.emit(nearest.prompt_text())
	if bool(result.get("started", false)): active_interaction = nearest

func cancel_interaction() -> void:
	if active_interaction != null:
		active_interaction.cancel_interaction()
		interaction_result.emit("已取消交互。")
		active_interaction = null
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
	_add_point(RuinSpot.new(), Vector2(1040, 515))

func _add_point(point: InteractionPoint, at: Vector2) -> void:
	var base_id := point.unique_id
	var count := int(point_id_counts.get(base_id, 0))
	point_id_counts[base_id] = count + 1
	if count > 0: point.unique_id = "%s_%d" % [base_id, count + 1]
	point.position = at
	add_child(point)
	point.setup(game)
	point.interaction_completed.connect(_on_point_completed)
	interactions.append(point)

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
	interactions.append(point)

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
	if game.audio != null:
		game.audio.play_music("interior"); game.audio.play_ambience("indoor_rain" if game.weather == "暴雨" else "indoor")
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
	if game.audio != null:
		game.audio.play_music("day"); _refresh_audio_context()
	interaction_changed.emit("")

func _safe_outdoor_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 20.0, map_size.x - 20.0), clampf(value.y, 20.0, map_size.y - 20.0))

func get_player_bounds() -> Rect2:
	if is_inside:
		if interior_manager != null and is_instance_valid(interior_manager.interior):
			if interior_manager.interior.has_method("player_bounds_global"):
				return interior_manager.interior.player_bounds_global()
		# Keep an indoor fallback while InteriorManager is creating/removing the
		# room; returning outdoor bounds here would snap an indoor player back into
		# the expanded outdoor field.
		return Rect2(INTERIOR_OFFSET + Vector2(16.0, 17.0), Vector2(148.0, 146.0))
	return Rect2(Vector2(12.0, 12.0), Vector2(map_size.x - 24.0, map_size.y - 24.0))

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
	var interaction_data: Array = []
	for point in interactions:
		if not is_instance_valid(point): continue
		var row := {"id":point.unique_id, "position":[point.position.x, point.position.y], "cooldown":point.cooldown_remaining, "uses_left":point.uses_left, "progress":point.interaction_progress if point.interacting else 0.0, "active":point.interacting, "visible":point.visible, "respawn":point.respawn_remaining}
		if point is TreeSpot:
			row["stump"] = point.is_stump
			row["regrow"] = point.regrow_remaining
		if point is FireplacePoint:
			row["lit"] = point.lit
		if point is BedPoint and point.unique_id == "house_bed":
			row["rested"] = point.rested_this_day
		interaction_data.append(row)
	return {"in_house":is_inside, "outdoor_position":[outdoor_position.x, outdoor_position.y], "interactions":interaction_data}

func restore_state(data: Dictionary) -> void:
	for child in get_children():
		if child is ConstructionSite: child.queue_free()
	_restore_construction_sites()
	var saved_position = data.get("outdoor_position", [180, 155])
	if saved_position is Array and saved_position.size() >= 2: outdoor_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	var by_id := {}
	active_interaction = null
	for row in data.get("interactions", []): by_id[str(row.get("id", ""))] = row
	if game != null and game.buildings != null and game.buildings.has("workbench") and not _has_outdoor_workbench():
		register_outdoor_workbench()
	for point in interactions:
		if not is_instance_valid(point) or not by_id.has(point.unique_id): continue
		var row: Dictionary = by_id[point.unique_id]
		var saved_point_position: Variant = row.get("position", [])
		if saved_point_position is Array and saved_point_position.size() >= 2:
			point.position = Vector2(float(saved_point_position[0]), float(saved_point_position[1]))
		point.cooldown_remaining = float(row.get("cooldown", 0.0)); point.uses_left = int(row.get("uses_left", -1)); point.interaction_progress = float(row.get("progress", 0.0)); point.interacting = bool(row.get("active", false)); point.respawn_remaining = float(row.get("respawn", 0.0))
		if point is TreeSpot:
			point.is_stump = bool(row.get("stump", false))
			point.regrow_remaining = float(row.get("regrow", 0.0))
			point.refresh_tree_art()
		if point is FireplacePoint:
			point.lit = bool(row.get("lit", game.house_fire_lit))
			if point.lit: game.house_fire_lit = true
			point._refresh_fire_visual()
		if point is BedPoint and point.unique_id == "house_bed":
			point.rested_this_day = bool(row.get("rested", false))
		if bool(row.get("visible", true)): point.show()
		else: point.hide()
		if point.interacting: active_interaction = point
	if bool(data.get("in_house", false)) and not is_inside: enter_house()
	elif not bool(data.get("in_house", false)) and is_inside: exit_house()

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
	if is_inside:
		game.audio.play_ambience("indoor_rain" if game.weather == "暴雨" else "indoor")
	else:
		var near_fire := false
		for point in interactions:
			if is_instance_valid(point) and point.unique_id == "campfire" and player.global_position.distance_to(point.global_position) < 90.0: near_fire = true
		var context := "rain_campfire" if game.weather == "暴雨" and near_fire else ("campfire" if near_fire else ("rain" if game.weather == "暴雨" else "outdoor"))
		game.audio.play_ambience(context)

func _on_point_completed(point: InteractionPoint, result: Dictionary) -> void:
	interaction_result.emit("%s：%s" % [point.display_name, str(result.get("message", "完成"))])
	if bool(result.get("open_storage", false)):
		storage_open_requested.emit()
	if result.has("fish_key"):
		fish_processing_requested.emit(str(result.get("fish_key", "")))
	if bool(result.get("open_tool_selection", false)):
		tool_selection_requested.emit()

func _build_collisions() -> void:
	# There is intentionally no invisible perimeter body. The expanded field is
	# bounded only by the player's soft map clamp, so the old air-wall snag is
	# gone while the camera still keeps the world in frame.
	# camp fence / house. The shelter body is split around the drawn doorway
	# (x=151..165), leaving enough clearance for the player's 12 px width.
	_add_wall(Rect2(75, 75, 125, 12), "CampFence"); _add_wall(Rect2(235, 75, 30, 12), "CampFence"); _add_wall(Rect2(75, 75, 12, 130), "CampFence"); _add_wall(Rect2(253, 75, 12, 130), "CampFence")
	# The lower fence is solid except for a 36px gate aligned to the camp opening.
	_add_wall(Rect2(75, 199, 112, 12), "CampFence"); _add_wall(Rect2(223, 199, 42, 12), "CampFence")
	_add_wall(Rect2(132, 102, 19, 35), "HouseWall"); _add_wall(Rect2(165, 102, 19, 35), "HouseWall")
	# The water is a single solid polygon.  Keeping one curved shoreline body
	# removes the old detached strips that felt like invisible air walls.
	_add_water_collision()
	# ruins building
	_add_wall(Rect2(950, 380, 210, 18), "RuinWall"); _add_wall(Rect2(950, 380, 18, 185), "RuinWall"); _add_wall(Rect2(1142, 380, 18, 185), "RuinWall"); _add_wall(Rect2(950, 547, 80, 18), "RuinWall")
	# rock piles and trees
	for rect in [Rect2(350, 145, 28, 28), Rect2(430, 230, 32, 24), Rect2(280, 410, 30, 26), Rect2(435, 535, 30, 30), Rect2(810, 490, 32, 24), Rect2(870, 590, 26, 28), Rect2(1328, 388, 30, 30), Rect2(1465, 550, 30, 30), Rect2(1495, 732, 30, 30), Rect2(1465, 916, 30, 30)]: _add_wall(rect, "RockPile")
	for position in HARVESTABLE_TREE_POSITIONS:
		_add_wall(Rect2(position - Vector2(11, 21), Vector2(22, 42)), "Tree")

func _add_wall(rect: Rect2, kind: String = "Landmark") -> void:
	var body := StaticBody2D.new()
	body.name = "%sCollision" % kind
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)

func _river_bank_x(y: float) -> float:
	var wave := sin(y * 0.0105 + 0.45) * RIVER_BANK_SWING
	wave += sin(y * 0.027 + 1.7) * 9.0
	return clampf(RIVER_RECT.position.x + wave, RIVER_RECT.position.x - RIVER_BANK_SWING, RIVER_RECT.position.x + RIVER_BANK_SWING)

func _add_water_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "RiverWaterCollision"
	var polygon := CollisionPolygon2D.new()
	var points := PackedVector2Array()
	for y in range(-32, int(map_size.y) + 33, 16):
		points.append(Vector2(_river_bank_x(float(y)), float(y)))
	points.append(Vector2(map_size.x + 24.0, map_size.y + 32.0))
	points.append(Vector2(map_size.x + 24.0, -32.0))
	polygon.polygon = points
	body.add_child(polygon)
	add_child(body)

func _build_art_sprites() -> void:
	# Every landmark below comes directly from Ninja Adventure PNGs. Collision
	# rectangles and interaction coordinates remain authored gameplay data.
	var tree_texture: Texture2D = Assets.region(NATURE_ATLAS, Rect2(0, 0, 32, 32))
	for at in [Vector2(1020, 191), Vector2(1110, 271), Vector2(1390, 239), Vector2(1490, 181), Vector2(1470, 871), Vector2(1470, 921)]:
		_add_world_sprite(tree_texture, at + Vector2(0, -4), Vector2(1.5, 1.5), 1)
	# The reference map composes small groves from several authored tree shapes.
	# These dressing trees have no interaction or collision; the harvestable trees
	# remain the separate TreeSpot nodes created above.
	var tree_variants: Array[Texture2D] = [
		tree_texture,
		Assets.region(NATURE_ATLAS, Rect2(32, 0, 32, 32)),
		Assets.region(NATURE_ATLAS, Rect2(96, 0, 32, 32))
	]
	for index in range(GROVE_TREE_POSITIONS.size()):
		var at: Vector2 = GROVE_TREE_POSITIONS[index]
		var grove_tree := _add_world_sprite(tree_variants[index % tree_variants.size()], at + Vector2(0, -4), Vector2(1.28 + float(index % 3) * 0.10, 1.28 + float(index % 3) * 0.10), 1)
		grove_tree.modulate = Color(0.92, 0.98, 0.84, 1.0) if index % 4 else Color(0.84, 0.92, 0.78, 1.0)
	var ripple_texture: Texture2D = Assets.region(WATER_RIPPLE_SHEET, Rect2(0, 0, 16, 16))
	for at in [Vector2(1630, 84), Vector2(1740, 140), Vector2(1840, 96), Vector2(1680, 224), Vector2(1810, 252), Vector2(1605, 480), Vector2(1780, 760)]:
		_add_world_sprite(ripple_texture, at, Vector2.ONE, 1)
	var fence_texture: Texture2D = Assets.region(HOUSE_ATLAS, Rect2(160, 80, 64, 16))
	for at in [Vector2(107, 75), Vector2(171, 75), Vector2(235, 75), Vector2(107, 205), Vector2(157, 205), Vector2(253, 205)]:
		var fence_scale := Vector2(1, 1)
		if at.y > 200.0 and at.x != 107.0: fence_scale.x = 0.5
		_add_world_sprite(fence_texture, at, fence_scale, 2)
	for at in [Vector2(75, 107), Vector2(75, 171), Vector2(265, 107), Vector2(265, 171)]:
		var fence_side := _add_world_sprite(fence_texture, at, Vector2.ONE, 2)
		fence_side.rotation = PI * 0.5
	# Use a complete house prop from the Ninja Adventure house atlas. The
	# chimney node above the roof adds the requested smoke state without
	# inventing a second building asset.
	var house_texture: Texture2D = Assets.region(HOUSE_ATLAS, Rect2(0, 0, 64, 64))
	_add_world_sprite(house_texture, Vector2(158, 101), Vector2.ONE, 3)
	var chimney := preload("res://scripts/chimney_art.gd").new()
	chimney.name = "HouseChimney"
	chimney.position = Vector2(174, 68)
	chimney.z_index = 4
	add_child(chimney)
	chimney.setup(game)
	# A small flame, crate and flag use the pack's own object/FX sheets.
	_add_world_sprite(Assets.region(NINJA_FIRE_SHEET, Rect2(0, 0, 16, 12)), Vector2(210, 148), Vector2(2, 2), 2)
	_add_world_sprite(NINJA_CRATE, Vector2(224, 148), Vector2(2, 2), 2)
	_add_world_sprite(Assets.region(NINJA_FLAG_SHEET, Rect2(0, 0, 16, 16)), Vector2(222, 82), Vector2.ONE, 2)
	# A complete 96x32 dock from the water tileset sits on the curved bank.
	_add_world_sprite(Assets.region(WATER_ATLAS, Rect2(0, 208, 96, 32)), Vector2(1518, 236), Vector2(0.75, 0.75), 2)
	# A broken abandoned-house facade supplies the ruin landmark in one atlas
	# region instead of a repeated Kenney floor/column assembly.
	var ruin_texture: Texture2D = Assets.region(VILLAGE_ATLAS, RUIN_TEXTURE_REGION)
	var ruin_sprite := _add_world_sprite(ruin_texture, Vector2(1055, 464), Vector2(2, 2), 1)
	ruin_sprite.name = "RuinLandmark"

func _build_ground_decorations() -> void:
	# These are non-interactive dressing props. Their positions are authored once
	# with a deterministic pattern, keeping the scene readable and avoiding a
	# different map every time a save is loaded.
	var grass_positions := [
		Vector2(58, 142), Vector2(96, 247), Vector2(132, 438), Vector2(183, 302),
		Vector2(226, 376), Vector2(275, 188), Vector2(314, 265), Vector2(365, 326),
		Vector2(404, 196), Vector2(471, 286), Vector2(514, 392), Vector2(565, 206),
		Vector2(606, 292), Vector2(671, 452), Vector2(731, 535), Vector2(782, 286),
		Vector2(846, 404), Vector2(902, 534), Vector2(961, 320), Vector2(1011, 641),
		Vector2(1078, 314), Vector2(1131, 675), Vector2(1190, 287), Vector2(1253, 438),
		Vector2(1310, 548), Vector2(1372, 706), Vector2(1432, 465), Vector2(1510, 692),
		Vector2(1566, 380), Vector2(1616, 610), Vector2(1710, 510), Vector2(1812, 410)
	]
	for index in range(grass_positions.size()):
		var at: Vector2 = grass_positions[index]
		if at.x >= _river_bank_x(at.y) - 16.0:
			continue
		var tuft := _add_world_sprite(NINJA_GRASS, at + Vector2(0, 1), Vector2(0.9 + float(index % 3) * 0.15, 0.9 + float(index % 2) * 0.15), 0)
		tuft.modulate = Color("d3d98d", 0.62 + float(index % 4) * 0.06)
	# A handful of small, non-collectable stones and branches break up the open
	# field while keeping the actual interaction props visually prominent.
	var pebble_positions := [Vector2(520, 118), Vector2(748, 186), Vector2(935, 254), Vector2(1220, 178), Vector2(1344, 620), Vector2(1458, 430), Vector2(1530, 515), Vector2(1750, 690)]
	for index in range(pebble_positions.size()):
		var at: Vector2 = pebble_positions[index]
		if at.x >= _river_bank_x(at.y) - 16.0:
			continue
		var pebble := _add_world_sprite(NINJA_ROCK, at + Vector2(0, 2), Vector2(0.72 + float(index % 2) * 0.18, 0.72 + float(index % 2) * 0.18), 0)
		pebble.modulate = Color("b8c0ad", 0.72)
	for at in [Vector2(387, 438), Vector2(590, 548), Vector2(735, 620), Vector2(1160, 738), Vector2(1280, 760), Vector2(1410, 580)]:
		if at.x < _river_bank_x(at.y) - 16.0:
			var branch := _add_world_sprite(NINJA_BRANCH, at, Vector2(0.9, 0.9), 0)
			branch.modulate = Color("d4a064", 0.72)
	# Place a few tufts in threes and fours around landmarks.  Grouping them is
	# more natural than increasing the density everywhere and keeps the player
	# path visually open.
	var tuft_clusters := [
		Vector2(62, 238), Vector2(78, 242), Vector2(94, 236),
		Vector2(232, 224), Vector2(248, 230), Vector2(264, 222),
		Vector2(370, 300), Vector2(386, 306), Vector2(400, 298),
		Vector2(918, 360), Vector2(934, 366), Vector2(950, 358),
		Vector2(1180, 418), Vector2(1196, 424), Vector2(1212, 416),
		Vector2(1340, 270), Vector2(1356, 276), Vector2(1372, 268),
		Vector2(1450, 786), Vector2(1466, 792), Vector2(1482, 784)
	]
	for index in range(tuft_clusters.size()):
		var at: Vector2 = tuft_clusters[index]
		if at.x >= _river_bank_x(at.y) - 16.0:
			continue
		var tuft := _add_world_sprite(NINJA_GRASS, at + Vector2(0, 1), Vector2(0.78 + float(index % 3) * 0.10, 0.78 + float(index % 2) * 0.08), 0)
		tuft.modulate = Color("d3d98d", 0.72 + float(index % 3) * 0.06)

func _add_world_sprite(texture: Texture2D, at: Vector2, scale_value := Vector2.ONE, layer := 1) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = scale_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = layer
	add_child(sprite)
	return sprite

func _draw() -> void:
	_draw_base_terrain()
	_draw_river()
	_draw_ground_shadows()
	_draw_ground_details()
	_draw_interaction_markers()
	_draw_zone_labels()
	_draw_atmosphere()

func _draw_base_terrain() -> void:
	if grass_tile != null:
		_draw_varied_grass()
	else:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("263b35"), true)

func _draw_tiled_atlas(texture: Texture2D, source_region: Rect2, destination: Rect2) -> void:
	if texture == null or source_region.size.x <= 0.0 or source_region.size.y <= 0.0: return
	var y := destination.position.y
	while y < destination.end.y:
		var tile_height := minf(source_region.size.y, destination.end.y - y)
		var x := destination.position.x
		while x < destination.end.x:
			var tile_width := minf(source_region.size.x, destination.end.x - x)
			var target := Rect2(x, y, tile_width, tile_height)
			var source := Rect2(source_region.position, Vector2(tile_width, tile_height))
			draw_texture_rect_region(texture, target, source)
			x += source_region.size.x
		y += source_region.size.y

func _draw_varied_grass() -> void:
	# Open terrain is intentionally unmarked.  The scene plan is communicated by
	# large, low-contrast terrain fields and landmarks, never by road ribbons or
	# invisible route boundaries.
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("839653"), true)
	_draw_scene_plan()
	_draw_local_terrain_zones()

func _draw_scene_plan() -> void:
	# Six connected outdoor scenes.  Their edges overlap softly so the player can
	# walk between them without hitting a visual or collision seam.
	_draw_organic_patch(Vector2(250, 410), Vector2(260, 325), Color("6f8a4d", 0.68), 11)
	_draw_organic_patch(Vector2(710, 310), Vector2(365, 255), Color("9aae61", 0.46), 17)
	_draw_organic_patch(Vector2(760, 760), Vector2(430, 300), Color("778e52", 0.48), 23)
	_draw_organic_patch(Vector2(1090, 485), Vector2(205, 155), Color("a18f62", 0.52), 31)
	_draw_organic_patch(Vector2(1370, 365), Vector2(185, 335), Color("91a35b", 0.52), 41)
	_draw_organic_patch(Vector2(1270, 850), Vector2(255, 215), Color("66845b", 0.58), 53)
	# Natural scene accents make each area legible at the camera's zoom without
	# drawing a border that could be mistaken for a wall.
	_draw_ellipse(Vector2(270, 630), Vector2(170, 54), Color("526f4b", 0.25))
	_draw_ellipse(Vector2(742, 168), Vector2(270, 44), Color("b7bd73", 0.18))
	_draw_ellipse(Vector2(1180, 735), Vector2(240, 46), Color("a9a06b", 0.16))

func _draw_local_terrain_zones() -> void:
	if floor_tile == null:
		return
	# These are semantic clearings, not a global noise pass: camp yard, a small
	# forage patch, the abandoned masonry approach, and the river landing.
	_draw_floor_patch(Rect2(96, 112, 128, 80), 0, 3)
	_draw_floor_patch(Rect2(248, 544, 128, 64), 0, 11)
	_draw_floor_patch(Rect2(944, 416, 192, 112), 1, 19)
	_draw_floor_patch(Rect2(1360, 176, 128, 80), 0, 29)

func _draw_floor_patch(rect: Rect2, style: int, seed_value: int) -> void:
	if floor_tile == null:
		return
	var columns := maxi(1, int(ceil(rect.size.x / 16.0)))
	var rows := maxi(1, int(ceil(rect.size.y / 16.0)))
	var atlas_x := 0.0 if style == 0 else 176.0
	for cell_y in range(rows):
		for cell_x in range(columns):
			var is_left := cell_x == 0
			var is_right := cell_x == columns - 1
			var is_top := cell_y == 0
			var is_bottom := cell_y == rows - 1
			var source := Vector2(atlas_x + 16.0, 128.0)
			if is_top and is_left:
				source = Vector2(atlas_x, 112.0)
			elif is_top and is_right:
				source = Vector2(atlas_x + 32.0, 112.0)
			elif is_bottom and is_left:
				source = Vector2(atlas_x, 144.0)
			elif is_bottom and is_right:
				source = Vector2(atlas_x + 32.0, 144.0)
			elif is_top:
				source = Vector2(atlas_x + 16.0, 112.0)
			elif is_bottom:
				source = Vector2(atlas_x + 16.0, 144.0)
			elif is_left:
				source = Vector2(atlas_x, 128.0)
			elif is_right:
				source = Vector2(atlas_x + 32.0, 128.0)
			else:
				# Keep one clean center cell inside the patch.  Other cells in this
				# atlas row are edge pieces; mixing them internally creates a false
				# green grid even though the outer contour is correct.
				source = Vector2(atlas_x + 16.0, 128.0)
			var target := Rect2(rect.position + Vector2(cell_x * 16.0, cell_y * 16.0), Vector2(16.0, 16.0))
			draw_texture_rect_region(floor_tile, target, Rect2(source, Vector2(16.0, 16.0)), Color(1.0, 1.0, 1.0, 0.94))

func _draw_organic_patch(center: Vector2, radii: Vector2, color: Color, seed_value: int) -> void:
	var points := PackedVector2Array()
	for index in range(22):
		var angle := TAU * float(index) / 22.0
		var jitter := 0.92 + float((seed_value * 13 + index * 17) % 17) / 100.0
		points.append(center + Vector2(cos(angle) * radii.x * jitter, sin(angle) * radii.y * jitter))
	draw_colored_polygon(points, color)

func _draw_ground_shadows() -> void:
	# Contact shadows are deliberately soft and flattened so they read as painted
	# pixel-art grounding, not as a global drop-shadow effect.
	for at in HARVESTABLE_TREE_POSITIONS:
		_draw_ellipse(at + Vector2(0, 15), Vector2(18, 5), Color("17241f", 0.30))
	for at in [Vector2(1020, 191), Vector2(1110, 271)]:
		_draw_ellipse(at + Vector2(0, 15), Vector2(18, 5), Color("17241f", 0.30))
	for at in [Vector2(364, 159), Vector2(446, 242), Vector2(295, 423), Vector2(450, 550), Vector2(826, 502), Vector2(883, 604), Vector2(1328, 402), Vector2(1480, 564), Vector2(1510, 746), Vector2(1480, 930)]:
		_draw_ellipse(at + Vector2(0, 10), Vector2(15, 4), Color("17241f", 0.34))
	for at in [Vector2(300, 125), Vector2(420, 300), Vector2(270, 520), Vector2(1270, 300), Vector2(1450, 470), Vector2(1500, 590), Vector2(260, 235), Vector2(280, 390), Vector2(320, 650), Vector2(1210, 670), Vector2(1380, 850), Vector2(1500, 840)]:
		_draw_ellipse(at + Vector2(0, 6), Vector2(8, 3), Color("17241f", 0.24))
	_draw_ellipse(Vector2(158, 139), Vector2(43, 9), Color("17241f", 0.36))
	_draw_ellipse(Vector2(210, 159), Vector2(16, 6), Color("17241f", 0.38))
	_draw_ellipse(Vector2(1055, 520), Vector2(54, 11), Color("17241f", 0.34))

func _draw_ground_details() -> void:
	# Painted grass blades sit between the terrain and prop sprites. Their density
	# is intentionally restrained around landmarks for visual hierarchy.
	for index in range(180):
		var at := Vector2(float((index * 173 + 29) % 1860 + 30), float((index * 97 + 47) % 1020 + 30))
		if at.x >= _river_bank_x(at.y) - 12.0:
			continue
		if Rect2(55, 55, 225, 175).has_point(at) or Rect2(945, 370, 225, 205).has_point(at):
			continue
		var tone := Color("a5bb67", 0.42) if index % 3 else Color("d2c878", 0.36)
		var height := 4.0 + float(index % 3)
		draw_line(at + Vector2(-3, 2), at + Vector2(-1, -height), tone, 1.0)
		draw_line(at + Vector2(0, 2), at + Vector2(1, -height - 2.0), tone, 1.0)
		draw_line(at + Vector2(3, 2), at + Vector2(4, -height + 1.0), tone, 1.0)
		if index % 7 == 0:
			var scar_color := Color("7f8b3d", 0.36) if index % 2 == 0 else Color("d1c45c", 0.30)
			draw_line(at + Vector2(-5, 5), at + Vector2(-1, 5), scar_color, 1.0)
			draw_line(at + Vector2(-1, 5), at + Vector2(2, 4), scar_color, 1.0)
		if index % 11 == 0:
			draw_circle(at + Vector2(5, -height), 1.2, Color("db9b70", 0.62))

func _draw_river() -> void:
	# Fill the coastal channel to the map edge. The same sampled bank is used by
	# collision generation, so the visible shoreline and walkable boundary agree.
	if water_tile == null: return
	var bank := PackedVector2Array()
	for y in range(int(RIVER_RECT.position.y), int(RIVER_RECT.end.y) + 1, 16):
		var bank_x := _river_bank_x(float(y))
		bank.append(Vector2(bank_x, float(y)))
		var row_width := map_size.x - bank_x
		_draw_tiled_atlas(water_tile, water_tile_region, Rect2(bank_x, float(y), row_width, 16.0))
	# A narrow wet-grass shelf and a broken foam line sell this as a shoreline,
	# rather than a hard-edged pond rectangle.
	var shore := PackedVector2Array()
	for point in bank:
		shore.append(point - Vector2(9, 0))
	draw_polyline(shore, Color("7d8d6c", 0.32), 8.0)
	draw_polyline(bank, Color("c4c08a", 0.52), 1.0)
	for index in range(26):
		var y := 18.0 + float(index * 43 % 1030)
		var x := _river_bank_x(y) + 24.0 + float((index * 17) % 190)
		draw_line(Vector2(x, y), Vector2(x + 9, y), Color("9bd2ca", 0.26), 1.0)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_interaction_markers() -> void:
	if is_inside: return
	for point in interactions:
		if not is_instance_valid(point) or point.get_parent() != self or not point.visible: continue
		var marker_pos := point.position
		var tint := _interaction_marker_color(point)
		var usable := point.can_interact()
		# Cooldown is communicated by the object itself: usable props stay bright,
		# unavailable props are dimmed. Avoid circular clock-like markers.
		if point == nearest:
			var marker_alpha := 0.92 if usable else 0.42
			draw_line(marker_pos + Vector2(-7, 10), marker_pos + Vector2(0, 13), Color(tint, marker_alpha), 2.0)
			draw_line(marker_pos + Vector2(0, 13), marker_pos + Vector2(7, 10), Color(tint, marker_alpha), 2.0)
		if point == active_interaction:
			draw_circle(marker_pos + Vector2(0, -16), 2.0, Color("f4d27e", 0.9))
		if point == nearest:
			draw_string(MAP_FONT, marker_pos + Vector2(-24, -17), point.display_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("f4d27e", 0.90))

func _interaction_marker_color(point: InteractionPoint) -> Color:
	var id := point.unique_id
	if id == "campfire": return Color("f0a34f")
	if id == "camp_bed" or id.begins_with("house_"): return Color("d8bb77")
	if id.begins_with("river_"): return Color("70c0b4")
	if id.begins_with("forest_"): return Color("9ec479")
	if id.begins_with("old_"): return Color("c6a576")
	return Color("d9c17e")

func _draw_zone_labels() -> void:
	for zone in zone_labels:
		var position: Vector2 = zone.position
		var label_color: Color = zone.color
		# Plain labels keep orientation without turning each biome into a boxed
		# panel or an artificial map boundary.
		draw_string(MAP_FONT, position + Vector2(1, 1), str(zone.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("081516", 0.55))
		draw_string(MAP_FONT, position, str(zone.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)

func _draw_atmosphere() -> void:
	if game == null or is_inside: return
	var progress := clampf(game.time.progress(), 0.0, 1.0)
	var dawn := clampf(1.0 - progress / 0.18, 0.0, 1.0)
	var dusk := clampf((progress - 0.46) / 0.24, 0.0, 1.0)
	var night := clampf((progress - 0.67) / 0.25, 0.0, 1.0)
	if dawn > 0.0:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("d89b68", 0.055 * dawn), true)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("a95e4f", 0.075 * dusk), true)
	if night > 0.0:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("081327", 0.34 * night), true)
		for index in range(30):
			var star := Vector2(float((index * 97 + 41) % int(map_size.x)), float((index * 53 + 19) % int(map_size.y)))
			draw_rect(Rect2(star, Vector2(1, 1)), Color("d6e4ca", 0.50 * night), true)
	# The campfire is the map's visual anchor. Concentric, low-alpha washes give
	# it a small warm pool without requiring a blurry light texture or flattening
	# the whole scene with CanvasModulate.
	var fire_glow := 0.020 + night * 0.045
	draw_circle(Vector2(210, 154), 96.0, Color("e9a55b", fire_glow))
	draw_circle(Vector2(210, 154), 42.0, Color("f1b96b", fire_glow * 1.55))
	match game.weather:
		"暴雨": _draw_rain()
		"浓雾": _draw_fog()
		"寒冷": _draw_cold()
		"多云": _draw_clouds()

func _draw_rain() -> void:
	for index in range(72):
		var x := fmod(float((index * 73) % int(map_size.x + 80)) + visual_clock * (105.0 + float(index % 5) * 9.0), map_size.x + 80.0) - 40.0
		var y := fmod(float((index * 47) % int(map_size.y + 50)) + visual_clock * (165.0 + float(index % 7) * 5.0), map_size.y + 50.0) - 25.0
		draw_line(Vector2(x, y), Vector2(x - 5.0, y + 14.0), Color("9fc3c0", 0.25), 1.0)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("2b5961", 0.045), true)

func _draw_fog() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("b7c5bd", 0.10), true)
	for index in range(5):
		var y := 78.0 + float(index) * 122.0 + sin(visual_clock * 0.35 + float(index)) * 12.0
		draw_rect(Rect2(-40, y, map_size.x + 80, 24), Color("d0d8cb", 0.035), true)

func _draw_cold() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("a8c5c5", 0.065), true)
	for index in range(38):
		var x := float((index * 89 + 23) % int(map_size.x))
		var y := fmod(float((index * 61 + 17) % int(map_size.y)) + visual_clock * 8.0, map_size.y)
		draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), Color("d3e1d3", 0.42), true)

func _draw_clouds() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("506b70", 0.055), true)
	for index in range(4):
		var x := fmod(float(index * 360) + visual_clock * 7.0, map_size.x + 300.0) - 150.0
		var y := 76.0 + float(index % 2) * 176.0
		draw_rect(Rect2(x, y, 250, 18), Color("8fa09a", 0.055), true)
