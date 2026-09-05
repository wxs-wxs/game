class_name WorldLayout
extends RefCounted

## Shared authored geometry for the outdoor map and the staged house interior.
## Keep these values in logical world pixels; renderers and facades consume them.
const MAP_SIZE := Vector2(1920, 1080)
const INTERIOR_OFFSET := Vector2(2400, 0)
const INTERIOR_ROOM_SIZE := Vector2(180, 180)
const INTERIOR_PLAYER_BOUNDS := Rect2(Vector2(16, 17), Vector2(148, 146))
const OUTDOOR_PLAYABLE_BOUNDS := Rect2(Vector2(12, 12), Vector2(1896, 1056))
const HOUSE_DOOR_POSITION := Vector2(158, 124)
const HOUSE_DOOR_OUTSIDE_POSITION := Vector2(158, 145)
const RIVER_RECT := Rect2(1532, -32, 388, 1144)
const RIVER_BANK_SWING := 34.0

const HARVESTABLE_TREE_POSITIONS := [
	Vector2(81, 291), Vector2(146, 341), Vector2(256, 281), Vector2(341, 351),
	Vector2(1390, 238), Vector2(1490, 180), Vector2(1470, 871), Vector2(1420, 940)
]
const GROVE_TREE_POSITIONS := [
	Vector2(24, 234), Vector2(118, 230), Vector2(192, 254), Vector2(308, 228),
	Vector2(60, 386), Vector2(116, 428), Vector2(210, 406), Vector2(286, 438),
	Vector2(955, 344), Vector2(1030, 320), Vector2(1138, 350), Vector2(1205, 410),
	Vector2(1340, 186), Vector2(1425, 120), Vector2(1390, 330), Vector2(1470, 330),
	Vector2(1350, 834), Vector2(1348, 930), Vector2(1485, 790)
]

func outdoor_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, MAP_SIZE)

func interior_bounds() -> Rect2:
	return Rect2(INTERIOR_OFFSET + INTERIOR_PLAYER_BOUNDS.position, INTERIOR_PLAYER_BOUNDS.size)

func outdoor_playable_bounds() -> Rect2:
	return OUTDOOR_PLAYABLE_BOUNDS

func river_bank_x(y: float) -> float:
	var wave := sin(y * 0.0105 + 0.45) * RIVER_BANK_SWING
	wave += sin(y * 0.027 + 1.7) * 9.0
	return clampf(RIVER_RECT.position.x + wave, RIVER_RECT.position.x - RIVER_BANK_SWING, RIVER_RECT.position.x + RIVER_BANK_SWING)

func safe_outdoor_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 20.0, MAP_SIZE.x - 20.0), clampf(value.y, 20.0, MAP_SIZE.y - 20.0))

func harvestable_tree_positions() -> Array[Vector2]:
	return HARVESTABLE_TREE_POSITIONS.duplicate()

func grove_tree_positions() -> Array[Vector2]:
	return GROVE_TREE_POSITIONS.duplicate()
