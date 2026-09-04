class_name NinjaAdventureAssets
extends RefCounted

## Small loader for the CC0 Ninja Adventure art pack.
## All regions stay in the original atlas so the project does not invent new
## artwork or introduce a second pixel-art palette.
static func texture(path: String) -> Texture2D:
	return load(path) as Texture2D

static func region(path: String, rectangle: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture(path)
	atlas.region = rectangle
	return atlas

## One cohesive 16px icon family for HUD rows and inventory slots.
static func resource_icon(key: String) -> Texture2D:
	match key:
		"food", "fish_carp", "fish_bass", "fish_trout", "fish_eel", "water":
			return texture("res://assets/art/ninja_adventure/Items/Food/Fish.png")
		"wood":
			return texture("res://assets/art/ninja_adventure/Items/Resource/Branch.png")
		"medicine", "bandage", "fiber":
			return texture("res://assets/art/ninja_adventure/Items/Resource/Grass.png")
		"fuel", "torch":
			return region("res://assets/art/ninja_adventure/FX/Particle/Fire.png", Rect2(0, 0, 16, 12))
		"stone":
			return texture("res://assets/art/ninja_adventure/Items/Resource/Rock.png")
		"scrap", "trap":
			return texture("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")
		"cloth":
			return texture("res://assets/art/ninja_adventure/Items/Object/Bag.png")
		"metal":
			return texture("res://assets/art/ninja_adventure/Items/Treasure/LittleTreasureChest.png")
		"cooked_food":
			return texture("res://assets/art/ninja_adventure/Items/Food/Fish.png")
	return texture("res://assets/art/ninja_adventure/Items/Treasure/BigTreasureChest.png")

static func tool_icon(key: String) -> Texture2D:
	return texture("res://assets/art/ninja_adventure/Items/Tool/Axe.png") if key == "axe" else texture("res://assets/art/ninja_adventure/Items/Tool/Pickaxe.png")

static func landmark_icon(key: String) -> Texture2D:
	match key:
		"bag": return texture("res://assets/art/ninja_adventure/Items/Object/Bag.png")
		"flag": return region("res://assets/art/ninja_adventure/Backgrounds/Animated/Flag/FlagBrown16x16.png", Rect2(0, 0, 16, 16))
		"chest": return texture("res://assets/art/ninja_adventure/Items/Treasure/BigTreasureChest.png")
		"fire": return region("res://assets/art/ninja_adventure/FX/Particle/Fire.png", Rect2(0, 0, 16, 12))
	return resource_icon(key)
