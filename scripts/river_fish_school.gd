class_name RiverFishSchool
extends Node2D

const NINJA_FISH := preload("res://assets/art/ninja_adventure/Items/Food/Fish.png")

## Lightweight animated fish silhouettes for the river. They are visual-only;
## the FishingSpot remains the authoritative catch interaction.
var fish: Array[Dictionary] = []
var elapsed := 0.0
# Fish live in the east-edge river mouth, not the old enclosed pond.
const WATER_RECT := Rect2(1560, 24, 330, 1032)
const SPECIES := [
	{"color":Color("e3b866"), "size":1.0},
	{"color":Color("d98b67"), "size":0.85},
	{"color":Color("9fc4b2"), "size":1.2},
	{"color":Color("b8a5d1"), "size":0.72}
]

func _ready() -> void:
	for index in range(13):
		var species: Dictionary = SPECIES[index % SPECIES.size()]
		var sprite := Sprite2D.new()
		sprite.name = "Fish_%02d" % index
		sprite.texture = NINJA_FISH
		sprite.scale = Vector2(2, 2)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)
		sprite.z_index = 1
		add_child(sprite)
		fish.append({
			"position": Vector2(WATER_RECT.position.x + 12.0 + float((index * 71) % 300), WATER_RECT.position.y + 14.0 + float((index * 43) % 990)),
			"velocity": Vector2(10.0 + float(index % 4) * 3.0, sin(float(index)) * 2.0),
			"species": species,
			"phase": float(index) * 0.73,
			"sprite": sprite
		})
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	for entry in fish:
		var position: Vector2 = entry["position"]
		var velocity: Vector2 = entry["velocity"]
		var phase: float = entry["phase"]
		position += velocity * delta
		position.y += sin(elapsed * 1.7 + phase) * delta * 2.0
		if position.x > WATER_RECT.end.x + 12.0: position.x = WATER_RECT.position.x - 12.0
		if position.x < WATER_RECT.position.x - 12.0: position.x = WATER_RECT.end.x + 12.0
		if position.y < WATER_RECT.position.y + 8.0: position.y = WATER_RECT.end.y - 8.0
		if position.y > WATER_RECT.end.y - 8.0: position.y = WATER_RECT.position.y + 8.0
		entry["position"] = position
		var sprite := entry["sprite"] as Sprite2D
		if sprite != null:
			sprite.position = position
			sprite.flip_h = velocity.x < 0.0
	queue_redraw()

func _draw() -> void:
	pass
