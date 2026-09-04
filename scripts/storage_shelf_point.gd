class_name StorageShelfPoint
extends InteractionPoint

const NINJA_CRATE := preload("res://assets/art/ninja_adventure/Items/Object/CrateEmpty.png")

func _init() -> void:
	unique_id = "storage_shelf"
	display_name = "储物架"
	action_id = "sort_storage"
	interaction_range = 28.0
	interaction_time = 0.6
	cooldown_time = 1.5
	reward = {}
	art_texture = NINJA_CRATE
	art_scale = Vector2(2, 2)
	art_offset = Vector2(0, 1)

func perform_interaction() -> Dictionary:
	if game == null or game.resources == null:
		return {"ok":false, "message":"储物架暂时无法使用。", "failed":true}
	var capacity := int(game.resources.capacities.get("food", 0))
	return {"ok":true, "message":"物资已整理，储物容量为 %d。" % capacity, "open_storage":true}

func _draw() -> void:
	if art_sprite != null:
		return
	super._draw()
