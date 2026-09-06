class_name ResourceCatalog
extends RefCounted

const RESOURCE_KEYS := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal", "water"]
const FISH_KEYS := ["fish_carp", "fish_bass", "fish_trout", "fish_eel"]
const COOKED_FISH_KEYS := ["cooked_fish_carp", "cooked_fish_bass", "cooked_fish_trout", "cooked_fish_eel"]
const CRAFTED_ITEM_KEYS := ["cooked_food", "bandage", "torch", "trap"]
const ITEM_KEYS := RESOURCE_KEYS + FISH_KEYS + COOKED_FISH_KEYS + CRAFTED_ITEM_KEYS
const TOOL_KEYS := ["axe", "pickaxe"]
const BACKPACK_BASE_CAPACITY := 12
const BACKPACK_UPGRADED_CAPACITY := BACKPACK_BASE_CAPACITY
const STACK_MAX := 999
const INITIAL_AMOUNTS := {"food":12, "wood":10, "medicine":3, "stone":4, "fiber":5, "cloth":2, "metal":2, "water":0, "cooked_food":0, "bandage":0, "torch":0, "trap":0, "fish_carp":0, "fish_bass":0, "fish_trout":0, "fish_eel":0, "cooked_fish_carp":0, "cooked_fish_bass":0, "cooked_fish_trout":0, "cooked_fish_eel":0}
const CAPACITIES := {"food":30, "wood":35, "medicine":15, "stone":20, "fiber":25, "cloth":15, "metal":15, "water":30, "cooked_food":30, "bandage":30, "torch":30, "trap":30, "fish_carp":30, "fish_bass":30, "fish_trout":30, "fish_eel":30, "cooked_fish_carp":30, "cooked_fish_bass":30, "cooked_fish_trout":30, "cooked_fish_eel":30}
const FISH_DEFINITIONS := {
	"fish_carp": {"label":"鲤鱼", "cooked_key":"cooked_fish_carp", "cooked_label":"熟鲤鱼", "food":2},
	"fish_bass": {"label":"鲈鱼", "cooked_key":"cooked_fish_bass", "cooked_label":"熟鲈鱼", "food":3},
	"fish_trout": {"label":"鳟鱼", "cooked_key":"cooked_fish_trout", "cooked_label":"熟鳟鱼", "food":4},
	"fish_eel": {"label":"鳗鱼", "cooked_key":"cooked_fish_eel", "cooked_label":"熟鳗鱼", "food":5}
}
const TOOL_DEFINITIONS := {
	"axe": {"id":"axe", "label":"石斧", "cost":{"stone":2, "wood":3}, "description":"砍伐森林中的树木，获得稳定木材。"},
	"pickaxe": {"id":"pickaxe", "label":"石镐", "cost":{"stone":3, "wood":2}, "description":"开采地图上的石堆，获得更多石料。"}
}
const SOURCE_RULES := {"stone":["field_pebble", "pebble", "rock_pile"], "wood":["field_branch", "branch", "forest_berries", "forest_tree"]}
const DISPLAY_NAMES := {"food":"浆果", "wood":"木材", "medicine":"药品", "stone":"石料", "fiber":"纤维", "cloth":"布料", "metal":"金属", "water":"水", "cooked_food":"熟浆果", "bandage":"绷带", "torch":"火把", "trap":"陷阱", "axe":"石斧", "pickaxe":"石镐"}

func item_keys() -> Array[String]: return ITEM_KEYS.duplicate()
func display_name(key: String) -> String:
	if FISH_DEFINITIONS.has(key): return fish_name(key)
	for fish_key in FISH_KEYS:
		if cooked_fish_key(fish_key) == key: return str(FISH_DEFINITIONS[fish_key].get("cooked_label", key))
	return str(DISPLAY_NAMES.get(key, key))
func fish_name(key: String) -> String: return str(FISH_DEFINITIONS.get(key, {}).get("label", key))
func fish_food_value(key: String) -> int: return int(FISH_DEFINITIONS.get(key, {}).get("food", 0))
func cooked_fish_key(key: String) -> String: return str(FISH_DEFINITIONS.get(key, {}).get("cooked_key", ""))
func tool_definition(tool_id: String) -> Dictionary:
	var definition = TOOL_DEFINITIONS.get(tool_id, {})
	return definition.duplicate(true) if definition is Dictionary else {}
