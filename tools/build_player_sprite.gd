extends SceneTree

const SOURCE_PATH := "res://assets/player_character_reference.png"
const OUTPUT_PATH := "res://assets/player_character_sheet.png"
const WALK_OUTPUT_PATH := "res://assets/player_character_walk_sheet.png"
const FRAME_SIZE := Vector2i(48, 72)
const WALK_FRAME_COUNT := 4
const LEG_SPLIT_Y := 43
const WALK_LEG_OFFSETS := [-2, 0, 2, 0]

# The supplied reference is a 2x2 presentation sheet: front, profile, back,
# and three-quarter views. These bounds keep the crop deterministic while the
# flood fill below removes only the connected white studio background.
const CROP_BOXES := [
	Rect2i(50, 70, 480, 1000),
	Rect2i(690, 70, 360, 1000),
	Rect2i(50, 1080, 500, 920),
	Rect2i(610, 1080, 500, 920)
]

func _init() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	assert(source != null, "player reference image could not be loaded")
	source.convert(Image.FORMAT_RGBA8)
	var sheet := Image.create(FRAME_SIZE.x * CROP_BOXES.size(), FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	var base_frames: Array[Image] = []
	for index in range(CROP_BOXES.size()):
		var frame := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
		frame.fill(Color(0.0, 0.0, 0.0, 0.0))
		var box: Rect2i = CROP_BOXES[index]
		var crop := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		crop.blit_rect(source, box, Vector2i.ZERO)
		_remove_studio_background(crop)
		var content := _alpha_bounds(crop)
		if content.size.x <= 0 or content.size.y <= 0:
			base_frames.append(frame)
			continue
		# A small transparent margin prevents the nearest-neighbour resize from
		# clipping hair or shoes at the edge of a frame.
		var padded := Rect2i(
			maxi(0, content.position.x - 5),
			maxi(0, content.position.y - 5),
			mini(crop.get_width(), content.end.x + 5) - maxi(0, content.position.x - 5),
			mini(crop.get_height(), content.end.y + 5) - maxi(0, content.position.y - 5)
		)
		var trimmed := Image.create(padded.size.x, padded.size.y, false, Image.FORMAT_RGBA8)
		trimmed.blit_rect(crop, padded, Vector2i.ZERO)
		var target_height := FRAME_SIZE.y - 2
		var target_width := maxi(1, roundi(float(trimmed.get_width()) * float(target_height) / float(trimmed.get_height())))
		if target_width > FRAME_SIZE.x - 2:
			target_width = FRAME_SIZE.x - 2
			target_height = maxi(1, roundi(float(trimmed.get_height()) * float(target_width) / float(trimmed.get_width())))
		trimmed.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
		var destination := Vector2i(
			(FRAME_SIZE.x - target_width) / 2,
			FRAME_SIZE.y - target_height
		)
		frame.blit_rect(trimmed, Rect2i(Vector2i.ZERO, Vector2i(target_width, target_height)), destination)
		base_frames.append(frame)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(index * FRAME_SIZE.x, 0))
	assert(sheet.save_png(OUTPUT_PATH) == OK, "player sprite sheet could not be saved")
	var walk_sheet := Image.create(FRAME_SIZE.x * CROP_BOXES.size() * WALK_FRAME_COUNT, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	walk_sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for direction in range(base_frames.size()):
		for phase in range(WALK_FRAME_COUNT):
			var walked := _make_walk_frame(base_frames[direction], phase)
			var frame_position := Vector2i((direction * WALK_FRAME_COUNT + phase) * FRAME_SIZE.x, 0)
			walk_sheet.blit_rect(walked, Rect2i(Vector2i.ZERO, FRAME_SIZE), frame_position)
	assert(walk_sheet.save_png(WALK_OUTPUT_PATH) == OK, "player walk sprite sheet could not be saved")
	print("PLAYER_SPRITE_OK path=%s frames=%d walk_frames=%d size=%dx%d" % [OUTPUT_PATH, CROP_BOXES.size(), CROP_BOXES.size() * WALK_FRAME_COUNT, sheet.get_width(), sheet.get_height()])
	quit()

func _make_walk_frame(base: Image, phase: int) -> Image:
	var walked := base.duplicate()
	var left_offset: int = WALK_LEG_OFFSETS[phase]
	var right_offset: int = -left_offset
	# Keep the torso and head stable, then offset each trouser leg in opposite
	# directions.  Four contact/passing poses are enough to read as a walk at
	# the game's small in-world scale while avoiding a second bespoke character.
	walked.fill_rect(Rect2i(0, LEG_SPLIT_Y, FRAME_SIZE.x, FRAME_SIZE.y - LEG_SPLIT_Y), Color(0.0, 0.0, 0.0, 0.0))
	_blit_shifted(walked, base, Rect2i(0, LEG_SPLIT_Y, FRAME_SIZE.x / 2, FRAME_SIZE.y - LEG_SPLIT_Y), Vector2i(left_offset, LEG_SPLIT_Y))
	_blit_shifted(walked, base, Rect2i(FRAME_SIZE.x / 2, LEG_SPLIT_Y, FRAME_SIZE.x / 2, FRAME_SIZE.y - LEG_SPLIT_Y), Vector2i(FRAME_SIZE.x / 2 + right_offset, LEG_SPLIT_Y))
	return walked

func _blit_shifted(target: Image, source: Image, source_rect: Rect2i, destination: Vector2i) -> void:
	var clipped_destination := Vector2i(maxi(0, destination.x), maxi(0, destination.y))
	var source_position := source_rect.position + (clipped_destination - destination)
	var width := mini(source_rect.size.x - (source_position.x - source_rect.position.x), target.get_width() - clipped_destination.x)
	var height := mini(source_rect.size.y - (source_position.y - source_rect.position.y), target.get_height() - clipped_destination.y)
	if width <= 0 or height <= 0:
		return
	target.blit_rect(source, Rect2i(source_position, Vector2i(width, height)), clipped_destination)

func _is_studio_white(color: Color) -> bool:
	var brightest := maxf(maxf(color.r, color.g), color.b)
	var darkest := minf(minf(color.r, color.g), color.b)
	return color.a > 0.0 and brightest > 0.965 and (brightest - darkest) < 0.045

func _remove_studio_background(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var queue: Array[Vector2i] = []
	for x in range(width):
		_enqueue_if_studio_white(image, Vector2i(x, 0), queue)
		_enqueue_if_studio_white(image, Vector2i(x, height - 1), queue)
	for y in range(height):
		_enqueue_if_studio_white(image, Vector2i(0, y), queue)
		_enqueue_if_studio_white(image, Vector2i(width - 1, y), queue)
	var head := 0
	while head < queue.size():
		var point: Vector2i = queue[head]
		head += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_enqueue_if_studio_white(image, point + offset, queue)

func _enqueue_if_studio_white(image: Image, point: Vector2i, queue: Array[Vector2i]) -> void:
	if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
		return
	var color := image.get_pixelv(point)
	if _is_studio_white(color):
		image.set_pixelv(point, Color(0.0, 0.0, 0.0, 0.0))
		queue.append(point)

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
