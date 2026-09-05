extends SceneTree

const Assets = preload("res://scripts/ninja_adventure_assets.gd")

const FIRE_SHEET := "res://assets/art/ninja_adventure/FX/Particle/Fire.png"
const BED_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/tileset_bed.png"
const HOUSE_ATLAS := "res://assets/art/ninja_adventure/Backgrounds/Tilesets/TilesetHouse.png"

func _init() -> void:
	var expected := {
		"campfire": {"path": FIRE_SHEET, "region": Rect2(0, 0, 16, 12)},
		"bed": {"path": BED_ATLAS, "region": Rect2(0, 0, 48, 32)},
		"shed": {"path": HOUSE_ATLAS, "region": Rect2(0, 0, 64, 64)},
		"clinic": {"path": HOUSE_ATLAS, "region": Rect2(336, 192, 16, 16)},
		"fence": {"path": HOUSE_ATLAS, "region": Rect2(160, 80, 16, 16)},
		"storage_shelf": {"path": HOUSE_ATLAS, "region": Rect2(352, 160, 48, 32)},
		"workbench": {"path": HOUSE_ATLAS, "region": Rect2(224, 160, 48, 32)},
		"fire_basin": {"path": FIRE_SHEET, "region": Rect2(48, 0, 16, 12)},
		"rain_collector": {"path": HOUSE_ATLAS, "region": Rect2(464, 192, 32, 48)}
	}
	for building_id in expected:
		var icon := Assets.building_icon(building_id)
		assert(icon is AtlasTexture, building_id)
		var atlas := icon as AtlasTexture
		assert(atlas.atlas != null, building_id)
		assert(atlas.atlas.resource_path == expected[building_id]["path"], building_id)
		assert(atlas.region == expected[building_id]["region"], building_id)
	assert((Assets.building_icon("rain_collector") as AtlasTexture).atlas.resource_path != FIRE_SHEET)
	print("BUILDING_ICON_SOURCES_OK count=%d" % expected.size())
	quit()
