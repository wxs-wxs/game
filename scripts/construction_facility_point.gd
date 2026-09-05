class_name ConstructionFacilityPoint
extends InteractionPoint

var facility_color := Color("84a98c")

var workbench_art: WorkbenchArt

func configure(id: String, label: String, color: Color = Color("84a98c")) -> void:
	unique_id = id
	display_name = label
	facility_color = color
	interaction_range = 24.0
	interaction_time = 0.2
	cooldown_time = 0.5
	reward = {}
	if id.begins_with("workbench"):
		facility_color = Color("b8a16b")

func _ready() -> void:
	super._ready()
	if unique_id.begins_with("workbench"):
		workbench_art = preload("res://scripts/workbench_art.gd").new()
		workbench_art.name = "WorkbenchArt"
		add_child(workbench_art)
		workbench_art.setup(true)
	queue_redraw()

func perform_interaction() -> Dictionary:
	if unique_id.begins_with("workbench"):
		return {"ok":true, "message":"工作台已准备好，可以制作石斧或石镐。", "open_tool_selection":true}
	return {"ok":true, "message":"%s 已启用。" % display_name}

func _draw() -> void:
	if unique_id.begins_with("workbench"):
		return
	draw_rect(Rect2(-8, -8, 16, 16), Color(facility_color, 0.35), true)
	draw_rect(Rect2(-8, -8, 16, 16), facility_color, false, 1.0)
