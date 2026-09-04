class_name ConstructionFacilityPoint
extends InteractionPoint

var facility_color := Color("84a98c")

func configure(id: String, label: String, color: Color = Color("84a98c")) -> void:
	unique_id = id
	display_name = label
	facility_color = color
	interaction_range = 24.0
	interaction_time = 0.2
	cooldown_time = 0.5
	reward = {}

func perform_interaction() -> Dictionary:
	return {"ok":true, "message":"%s 已启用。" % display_name}

func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color(facility_color, 0.35), true)
	draw_rect(Rect2(-8, -8, 16, 16), facility_color, false, 1.0)
