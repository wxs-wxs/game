extends SceneTree

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
const WorldMapRenderer = preload("res://scripts/world/map/world_map_renderer.gd")

func _init() -> void:
	var renderer := WorldMapRenderer.new()
	root.add_child(renderer)
	renderer.setup(null, WorldLayout.new())
	renderer.rebuild()
	assert(renderer.get_child_count() > 0)
	for child in renderer.get_children():
		if child is Sprite2D:
			assert(child.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	print("WORLD_RENDERER_REGRESSION_OK")
	quit()
