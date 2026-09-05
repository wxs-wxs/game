class_name WorldMapRenderer
extends Node2D

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
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
const NINJA_FLAG_SHEET := "res://assets/art/ninja_adventure/Backgrounds/Animated/Flag/FlagBrown16x16.png"
const RUIN_TEXTURE_REGION := Rect2(0, 0, 64, 48)

var game
var layout: WorldLayout
var map_size := WorldLayout.MAP_SIZE
var grass_tile: Texture2D
var floor_tile: Texture2D
var water_tile: Texture2D
var grass_tile_region := Rect2(16, 64, 16, 16)
var water_tile_region := Rect2(16, 16, 16, 16)
var interactions: Array[InteractionPoint] = []
var nearest: InteractionPoint
var active_interaction: InteractionPoint
var is_inside := false
var visual_clock := 0.0
var weather := ""
var zone_labels := [
	{"name":"营地", "position":Vector2(110, 74), "color":Color("e0b76c")},
	{"name":"西侧密林", "position":Vector2(96, 470), "color":Color("b4c88a")},
	{"name":"中央草甸", "position":Vector2(650, 108), "color":Color("d3cf8a")},
	{"name":"旧砖场", "position":Vector2(1030, 470), "color":Color("d5b17b")},
	{"name":"东岸浅滩", "position":Vector2(1450, 66), "color":Color("a5d0c3")},
	{"name":"东侧高地", "position":Vector2(1400, 250), "color":Color("c1cb88")},
	{"name":"南部湿地", "position":Vector2(1180, 900), "color":Color("a0c29a")}
]

func setup(state, world_layout: WorldLayout) -> void:
	game = state
	layout = world_layout if world_layout != null else WorldLayout.new()
	map_size = layout.MAP_SIZE
	grass_tile = Assets.texture(FIELD_ATLAS)
	floor_tile = Assets.texture(FLOOR_ATLAS)
	water_tile = Assets.texture(WATER_ATLAS)
	weather = str(state.weather) if state != null else ""
	y_sort_enabled = true

func rebuild() -> void:
	var host := get_parent()
	if host != null:
		for compatibility_name in ["HouseChimney", "RuinLandmark"]:
			var old_node := host.get_node_or_null(compatibility_name)
			if old_node != null and old_node != self:
				old_node.free()
	for child in get_children():
		child.free()
	_build_art_sprites()
	_build_ground_decorations()
	queue_redraw()

func refresh_weather(weather: String) -> void:
	self.weather = weather
	queue_redraw()

func set_marker_state(points: Array[InteractionPoint], nearest_point: InteractionPoint, active_point: InteractionPoint, inside: bool) -> void:
	interactions = points
	nearest = nearest_point
	active_interaction = active_point
	is_inside = inside
	queue_redraw()

func set_visual_clock(value: float) -> void:
	visual_clock = value
	queue_redraw()

func _build_art_sprites() -> void:
	var tree_texture: Texture2D = Assets.region(NATURE_ATLAS, Rect2(0, 0, 32, 32))
	for at in [Vector2(1020, 191), Vector2(1110, 271)]:
		_add_world_sprite(tree_texture, at + Vector2(0, -4), Vector2(1.5, 1.5), 1)
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
	var house_texture: Texture2D = Assets.region(HOUSE_ATLAS, Rect2(0, 0, 64, 64))
	_add_world_sprite(house_texture, Vector2(158, 101), Vector2.ONE, 3)
	var chimney := preload("res://scripts/chimney_art.gd").new()
	chimney.name = "HouseChimney"
	chimney.position = Vector2(174, 68)
	chimney.z_index = 4
	add_child(chimney)
	_promote_compatibility_node(chimney)
	chimney.setup(game)
	_add_world_sprite(NINJA_CRATE, Vector2(224, 148), Vector2(2, 2), 2)
	_add_world_sprite(Assets.region(NINJA_FLAG_SHEET, Rect2(0, 0, 16, 16)), Vector2(222, 82), Vector2.ONE, 2)
	_add_world_sprite(Assets.region(WATER_ATLAS, Rect2(0, 208, 96, 32)), Vector2(1518, 236), Vector2(0.75, 0.75), 2)
	var ruin_texture: Texture2D = Assets.region(VILLAGE_ATLAS, RUIN_TEXTURE_REGION)
	var ruin_sprite := _add_world_sprite(ruin_texture, Vector2(1055, 464), Vector2(2, 2), 1)
	ruin_sprite.name = "RuinLandmark"
	_promote_compatibility_node(ruin_sprite)

func _promote_compatibility_node(node: Node) -> void:
	var host := get_parent()
	if host == null or host == self: return
	remove_child(node)
	host.add_child(node)

func _build_ground_decorations() -> void:
	var grass_positions := [
		Vector2(58, 142), Vector2(96, 247), Vector2(132, 438), Vector2(183, 302), Vector2(226, 376), Vector2(275, 188), Vector2(314, 265), Vector2(365, 326),
		Vector2(404, 196), Vector2(471, 286), Vector2(514, 392), Vector2(565, 206), Vector2(606, 292), Vector2(671, 452), Vector2(731, 535), Vector2(782, 286),
		Vector2(846, 404), Vector2(902, 534), Vector2(961, 320), Vector2(1011, 641), Vector2(1078, 314), Vector2(1131, 675), Vector2(1190, 287), Vector2(1253, 438),
		Vector2(1310, 548), Vector2(1372, 706), Vector2(1432, 465), Vector2(1510, 692), Vector2(1566, 380), Vector2(1616, 610), Vector2(1710, 510), Vector2(1812, 410)
	]
	for index in range(grass_positions.size()):
		var at: Vector2 = grass_positions[index]
		if at.x >= _river_bank_x(at.y) - 16.0: continue
		var tuft := _add_world_sprite(NINJA_GRASS, at + Vector2(0, 1), Vector2(0.9 + float(index % 3) * 0.15, 0.9 + float(index % 2) * 0.15), 0)
		tuft.modulate = Color("d3d98d", 0.62 + float(index % 4) * 0.06)
	var pebble_positions := [Vector2(520, 118), Vector2(748, 186), Vector2(935, 254), Vector2(1220, 178), Vector2(1344, 620), Vector2(1458, 430), Vector2(1530, 515), Vector2(1750, 690)]
	for index in range(pebble_positions.size()):
		var at: Vector2 = pebble_positions[index]
		if at.x >= _river_bank_x(at.y) - 16.0: continue
		var pebble := _add_world_sprite(NINJA_ROCK, at + Vector2(0, 2), Vector2(0.72 + float(index % 2) * 0.18, 0.72 + float(index % 2) * 0.18), 0)
		pebble.modulate = Color("b8c0ad", 0.72)
	for at in [Vector2(387, 438), Vector2(590, 548), Vector2(735, 620), Vector2(1160, 738), Vector2(1280, 760), Vector2(1410, 580)]:
		if at.x < _river_bank_x(at.y) - 16.0:
			var branch := _add_world_sprite(NINJA_BRANCH, at, Vector2(0.9, 0.9), 0)
			branch.modulate = Color("d4a064", 0.72)
	var tuft_clusters := [Vector2(62, 238), Vector2(78, 242), Vector2(94, 236), Vector2(232, 224), Vector2(248, 230), Vector2(264, 222), Vector2(370, 300), Vector2(386, 306), Vector2(400, 298), Vector2(918, 360), Vector2(934, 366), Vector2(950, 358), Vector2(1180, 418), Vector2(1196, 424), Vector2(1212, 416), Vector2(1340, 270), Vector2(1356, 276), Vector2(1372, 268), Vector2(1450, 786), Vector2(1466, 792), Vector2(1482, 784)]
	for index in range(tuft_clusters.size()):
		var at: Vector2 = tuft_clusters[index]
		if at.x >= _river_bank_x(at.y) - 16.0: continue
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
	if grass_tile != null: _draw_varied_grass()
	else: draw_rect(Rect2(Vector2.ZERO, map_size), Color("263b35"), true)

func _draw_tiled_atlas(texture: Texture2D, source_region: Rect2, destination: Rect2) -> void:
	if texture == null or source_region.size.x <= 0.0 or source_region.size.y <= 0.0: return
	var y := destination.position.y
	while y < destination.end.y:
		var tile_height := minf(source_region.size.y, destination.end.y - y)
		var x := destination.position.x
		while x < destination.end.x:
			var tile_width := minf(source_region.size.x, destination.end.x - x)
			draw_texture_rect_region(texture, Rect2(x, y, tile_width, tile_height), Rect2(source_region.position, Vector2(tile_width, tile_height)))
			x += source_region.size.x
		y += source_region.size.y

func _draw_varied_grass() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("839653"), true)
	_draw_scene_plan()
	_draw_local_terrain_zones()

func _draw_scene_plan() -> void:
	_draw_organic_patch(Vector2(250, 410), Vector2(260, 325), Color("6f8a4d", 0.68), 11)
	_draw_organic_patch(Vector2(710, 310), Vector2(365, 255), Color("9aae61", 0.46), 17)
	_draw_organic_patch(Vector2(760, 760), Vector2(430, 300), Color("778e52", 0.48), 23)
	_draw_organic_patch(Vector2(1090, 485), Vector2(205, 155), Color("a18f62", 0.52), 31)
	_draw_organic_patch(Vector2(1370, 365), Vector2(185, 335), Color("91a35b", 0.52), 41)
	_draw_organic_patch(Vector2(1270, 850), Vector2(255, 215), Color("66845b", 0.58), 53)
	_draw_ellipse(Vector2(270, 630), Vector2(170, 54), Color("526f4b", 0.25))
	_draw_ellipse(Vector2(742, 168), Vector2(270, 44), Color("b7bd73", 0.18))
	_draw_ellipse(Vector2(1180, 735), Vector2(240, 46), Color("a9a06b", 0.16))

func _draw_local_terrain_zones() -> void:
	if floor_tile == null: return
	_draw_floor_patch(Rect2(96, 112, 128, 80), 0, 3)
	_draw_floor_patch(Rect2(248, 544, 128, 64), 0, 11)
	_draw_floor_patch(Rect2(944, 416, 192, 112), 1, 19)
	_draw_floor_patch(Rect2(1360, 176, 128, 80), 0, 29)

func _draw_floor_patch(rect: Rect2, style: int, seed_value: int) -> void:
	if floor_tile == null: return
	var columns := maxi(1, int(ceil(rect.size.x / 16.0)))
	var rows := maxi(1, int(ceil(rect.size.y / 16.0)))
	var atlas_x := 0.0 if style == 0 else 176.0
	for cell_y in range(rows):
		for cell_x in range(columns):
			var is_left := cell_x == 0; var is_right := cell_x == columns - 1; var is_top := cell_y == 0; var is_bottom := cell_y == rows - 1
			var source := Vector2(atlas_x + 16.0, 128.0)
			if is_top and is_left: source = Vector2(atlas_x, 112.0)
			elif is_top and is_right: source = Vector2(atlas_x + 32.0, 112.0)
			elif is_bottom and is_left: source = Vector2(atlas_x, 144.0)
			elif is_bottom and is_right: source = Vector2(atlas_x + 32.0, 144.0)
			elif is_top: source = Vector2(atlas_x + 16.0, 112.0)
			elif is_bottom: source = Vector2(atlas_x + 16.0, 144.0)
			elif is_left: source = Vector2(atlas_x, 128.0)
			elif is_right: source = Vector2(atlas_x + 32.0, 128.0)
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
	for at in layout.harvestable_tree_positions(): _draw_ellipse(at + Vector2(0, 15), Vector2(18, 5), Color("17241f", 0.30))
	for at in [Vector2(1020, 191), Vector2(1110, 271)]: _draw_ellipse(at + Vector2(0, 15), Vector2(18, 5), Color("17241f", 0.30))
	for at in [Vector2(364, 159), Vector2(446, 242), Vector2(295, 423), Vector2(450, 550), Vector2(826, 502), Vector2(883, 604), Vector2(1328, 402), Vector2(1480, 564), Vector2(1510, 746), Vector2(1480, 930)]: _draw_ellipse(at + Vector2(0, 10), Vector2(15, 4), Color("17241f", 0.34))
	for at in [Vector2(300, 125), Vector2(420, 300), Vector2(270, 520), Vector2(1270, 300), Vector2(1450, 470), Vector2(1500, 590), Vector2(260, 235), Vector2(280, 390), Vector2(320, 650), Vector2(1210, 670), Vector2(1380, 850), Vector2(1500, 840)]: _draw_ellipse(at + Vector2(0, 6), Vector2(8, 3), Color("17241f", 0.24))
	_draw_ellipse(Vector2(158, 139), Vector2(43, 9), Color("17241f", 0.36))
	_draw_ellipse(Vector2(210, 159), Vector2(16, 6), Color("17241f", 0.38))
	_draw_ellipse(Vector2(1055, 520), Vector2(54, 11), Color("17241f", 0.34))

func _draw_ground_details() -> void:
	for index in range(180):
		var at := Vector2(float((index * 173 + 29) % 1860 + 30), float((index * 97 + 47) % 1020 + 30))
		if at.x >= _river_bank_x(at.y) - 12.0: continue
		if Rect2(55, 55, 225, 175).has_point(at) or Rect2(945, 370, 225, 205).has_point(at): continue
		var tone := Color("a5bb67", 0.42) if index % 3 else Color("d2c878", 0.36)
		var height := 4.0 + float(index % 3)
		draw_line(at + Vector2(-3, 2), at + Vector2(-1, -height), tone, 1.0)
		draw_line(at + Vector2(0, 2), at + Vector2(1, -height - 2.0), tone, 1.0)
		draw_line(at + Vector2(3, 2), at + Vector2(4, -height + 1.0), tone, 1.0)
		if index % 7 == 0:
			var scar_color := Color("7f8b3d", 0.36) if index % 2 == 0 else Color("d1c45c", 0.30)
			draw_line(at + Vector2(-5, 5), at + Vector2(-1, 5), scar_color, 1.0); draw_line(at + Vector2(-1, 5), at + Vector2(2, 4), scar_color, 1.0)
		if index % 11 == 0: draw_circle(at + Vector2(5, -height), 1.2, Color("db9b70", 0.62))

func _draw_river() -> void:
	if water_tile == null: return
	var bank := PackedVector2Array()
	for y in range(int(layout.RIVER_RECT.position.y), int(layout.RIVER_RECT.end.y) + 1, 16):
		var bank_x := _river_bank_x(float(y)); bank.append(Vector2(bank_x, float(y))); _draw_tiled_atlas(water_tile, water_tile_region, Rect2(bank_x, float(y), map_size.x - bank_x, 16.0))
	var shore := PackedVector2Array()
	for point in bank: shore.append(point - Vector2(9, 0))
	draw_polyline(shore, Color("7d8d6c", 0.32), 8.0); draw_polyline(bank, Color("c4c08a", 0.52), 1.0)
	for index in range(26):
		var y := 18.0 + float(index * 43 % 1030); var x := _river_bank_x(y) + 24.0 + float((index * 17) % 190)
		draw_line(Vector2(x, y), Vector2(x + 9, y), Color("9bd2ca", 0.26), 1.0)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0; points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_interaction_markers() -> void:
	if is_inside: return
	for point in interactions:
		if not is_instance_valid(point) or not point.visible: continue
		var marker_pos := point.position
		var tint := _interaction_marker_color(point)
		var usable := point.can_interact()
		if point == nearest:
			var marker_alpha := 0.92 if usable else 0.42
			draw_line(marker_pos + Vector2(-7, 10), marker_pos + Vector2(0, 13), Color(tint, marker_alpha), 2.0)
			draw_line(marker_pos + Vector2(0, 13), marker_pos + Vector2(7, 10), Color(tint, marker_alpha), 2.0)
		if point == active_interaction: draw_circle(marker_pos + Vector2(0, -16), 2.0, Color("f4d27e", 0.9))
		if point == nearest: draw_string(MAP_FONT, marker_pos + Vector2(-24, -17), point.display_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("f4d27e", 0.90))

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
		draw_string(MAP_FONT, position + Vector2(1, 1), str(zone.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("081516", 0.55))
		draw_string(MAP_FONT, position, str(zone.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)

func _draw_atmosphere() -> void:
	if game == null or is_inside: return
	var progress := clampf(game.time.progress(), 0.0, 1.0)
	var dawn := clampf(1.0 - progress / 0.18, 0.0, 1.0)
	var dusk := clampf((progress - 0.46) / 0.24, 0.0, 1.0)
	var night := clampf((progress - 0.67) / 0.25, 0.0, 1.0)
	if dawn > 0.0: draw_rect(Rect2(Vector2.ZERO, map_size), Color("d89b68", 0.055 * dawn), true)
	if dusk > 0.0: draw_rect(Rect2(Vector2.ZERO, map_size), Color("a95e4f", 0.075 * dusk), true)
	if night > 0.0:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("081327", 0.34 * night), true)
		for index in range(30):
			var star := Vector2(float((index * 97 + 41) % int(map_size.x)), float((index * 53 + 19) % int(map_size.y)))
			draw_rect(Rect2(star, Vector2(1, 1)), Color("d6e4ca", 0.50 * night), true)
	var fire_glow := (0.020 + night * 0.045) if game.is_fire_active("campfire") else 0.0
	draw_circle(Vector2(210, 154), 96.0, Color("e9a55b", fire_glow)); draw_circle(Vector2(210, 154), 42.0, Color("f1b96b", fire_glow * 1.55))
	match weather:
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
		var x := float((index * 89 + 23) % int(map_size.x)); var y := fmod(float((index * 61 + 17) % int(map_size.y)) + visual_clock * 8.0, map_size.y)
		draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), Color("d3e1d3", 0.42), true)

func _draw_clouds() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("506b70", 0.055), true)
	for index in range(4):
		var x := fmod(float(index * 360) + visual_clock * 7.0, map_size.x + 300.0) - 150.0
		var y := 76.0 + float(index % 2) * 176.0
		draw_rect(Rect2(x, y, 250, 18), Color("8fa09a", 0.055), true)

func _river_bank_x(y: float) -> float:
	return layout.river_bank_x(y)
