class_name ExplorerPlayer
extends CharacterBody2D

@export var move_speed: float = 105.0
var game: GameManager
var world: ExplorationWorld
var facing := Vector2.DOWN
var interior := false
var _footstep_accumulator := 0.0
var art_sprite: Sprite2D
var action_id := ""
var action_elapsed := 0.0
var action_duration := 0.0
var action_active := false
var walk_phase := 0.0

# The player is normally constrained to the outdoor map.  The house is a
# separate room placed outside that map so the camera can frame it without
# changing the outdoor layout.  Keep a fallback here for the one frame during
# which the interior node is being created or removed.
const DEFAULT_INTERIOR_BOUNDS := Rect2(2416.0, 17.0, 148.0, 146.0)
const PLAYER_COLLISION_SIZE := Vector2(12, 14)
const WALK_FRAME_COUNT := 4
const WALK_CYCLE_SPEED := 12.0
const VIEW_FRONT := 0
const VIEW_PROFILE := 1
const VIEW_BACK := 2
const VIEW_THREE_QUARTER := 3
const PLAYER_FONT := preload("res://assets/fonts/fusion_pixel/fusion-pixel-10px-monospaced-zh_hans.ttf")

var body_view := VIEW_FRONT
var walk_frame := 0

func setup(manager: GameManager, map: ExplorationWorld) -> void:
	game = manager
	world = map
	# The interior is added after the player in the scene tree and paints its
	# floor/background as a sibling.  Keep the player in a stable foreground
	# layer so movement remains visible after entering the room.
	z_index = 4
	var shape := CollisionShape2D.new()
	var capsule := RectangleShape2D.new()
	capsule.size = PLAYER_COLLISION_SIZE
	shape.shape = capsule
	add_child(shape)
	# Use the supplied Minecraft-style character sheet for the body while
	# retaining the procedural overlays used by gathering and tool actions.
	art_sprite = Sprite2D.new()
	art_sprite.name = "CharacterSprite"
	art_sprite.texture = preload("res://assets/player_character_walk_sheet.png")
	art_sprite.hframes = WALK_FRAME_COUNT * 4
	art_sprite.frame = 0
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The larger source frame preserves more shading/detail while this scale
	# keeps the character's in-world footprint consistent with the old sprite.
	art_sprite.scale = Vector2(0.65, 0.65)
	# The sheet's frame is taller than the collision body; align its shoes with
	# the same foot baseline used by the previous procedural silhouette.
	art_sprite.position = Vector2(0, -5)
	# Keep procedural hands/tools and the contact shadow above the body sprite.
	art_sprite.z_index = -1
	add_child(art_sprite)
	_update_art_direction()
	queue_redraw()

func start_action(next_action_id: String, duration: float) -> void:
	action_id = next_action_id
	action_elapsed = 0.0
	action_duration = maxf(0.1, duration)
	action_active = true
	velocity = Vector2.ZERO
	walk_phase = 0.0
	walk_frame = 0
	_update_art_direction()
	queue_redraw()

func stop_action() -> void:
	action_active = false
	action_id = ""
	action_elapsed = 0.0
	action_duration = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not action_active:
		return
	if game != null and game.time != null and game.time.paused:
		return
	action_elapsed = minf(action_duration, action_elapsed + maxf(0.0, delta))
	queue_redraw()

func set_interior_state(value: bool) -> void:
	interior = value
	z_index = 6 if interior else 4
	velocity = Vector2.ZERO
	_footstep_accumulator = 0.0

func _physics_process(_delta: float) -> void:
	if game == null or game.time.paused or game.phase == GameManager.PHASE_ENDED or (world != null and world.is_interacting()):
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Keep direct key polling as a fallback for imported projects whose InputMap predates these actions.
	if direction == Vector2.ZERO:
		direction = Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		facing = direction
		_advance_walk_animation(_delta)
	else:
		if walk_frame != 0 or walk_phase != 0.0:
			walk_phase = 0.0
			walk_frame = 0
			_update_art_direction()
	# Outdoor movement is uniform across the open terrain; no hidden surface
	# modifier changes the player's speed.
	velocity = direction * move_speed
	move_and_slide()
	if direction.length_squared() > 0.0:
		_footstep_accumulator += _delta
		var interval := 0.34 if not interior else 0.42
		if _footstep_accumulator >= interval:
			_footstep_accumulator = 0.0
			if game.audio != null: game.audio.play_sfx("footstep_indoor" if interior else "footstep_outdoor")
	else:
		_footstep_accumulator = 0.0
	if world != null:
		var bounds := _movement_bounds()
		global_position.x = clampf(global_position.x, bounds.position.x, bounds.end.x)
		global_position.y = clampf(global_position.y, bounds.position.y, bounds.end.y)
	queue_redraw()

func _advance_walk_animation(delta: float) -> void:
	walk_phase = fmod(walk_phase + maxf(0.0, delta) * WALK_CYCLE_SPEED, TAU)
	walk_frame = int(floor(walk_phase / TAU * float(WALK_FRAME_COUNT))) % WALK_FRAME_COUNT
	_update_art_direction()

func _movement_bounds() -> Rect2:
	# During a room transition the old/new interior node can be invalid for one
	# frame.  Do not let the outdoor bounds override the indoor fallback (that
	# would snap a player back onto the outdoor map and look like a
	# movement lock).  The world bounds are used only when their state agrees
	# with the player's current interior flag.
	if interior:
		if world != null and world.is_inside and world.has_method("get_player_bounds"):
			var indoor_bounds: Rect2 = world.get_player_bounds()
			if indoor_bounds.size.x > 0.0 and indoor_bounds.size.y > 0.0:
				return indoor_bounds
		return DEFAULT_INTERIOR_BOUNDS
	if world != null and not world.is_inside and world.has_method("get_player_bounds"):
		var outdoor_bounds: Rect2 = world.get_player_bounds()
		if outdoor_bounds.size.x > 0.0 and outdoor_bounds.size.y > 0.0:
			return outdoor_bounds
	return Rect2(Vector2(12.0, 12.0), Vector2(1908.0, 1068.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if world != null and (world.build_mode == null or not world.build_mode.active): world.try_interact()
	if world != null and (event.is_action_pressed("cancel_action") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)):
		world.cancel_interaction()

func _draw() -> void:
	var walking := velocity.length_squared() > 1.0 and not action_active
	var step := sin(walk_phase) if walking else 0.0
	var bob := step * 0.7
	var shadow_width := 9.0 + absf(step) * 0.7
	var shadow_height := 3.0 - absf(step) * 0.25
	_draw_ellipse_shape(Vector2(0, 11), Vector2(shadow_width, shadow_height), Color("071012", 0.42))
	if art_sprite != null:
		art_sprite.position = Vector2(0, -5 + bob)
		# A small squash and sway keeps the four generated leg poses readable at
		# the game's zoom without changing the collision body's footprint.
		var squash := absf(step) * 0.018
		art_sprite.scale = Vector2(0.65 + squash, 0.65 - squash)
	if action_active:
		_draw_action(bob)
	if _has_axe() and not (action_active and action_id == "chop"):
		_draw_carried_axe()

func _update_art_direction() -> void:
	if art_sprite == null:
		return
	var horizontal := absf(facing.x)
	var vertical := absf(facing.y)
	if horizontal > 0.35 and vertical > 0.35:
		if facing.y < 0.0:
			# The supplied sheet has a front three-quarter view but no rear
			# diagonal. Use the back view for upward diagonals so the character
			# visibly travels away from the camera instead of looking forward.
			body_view = VIEW_BACK
			art_sprite.flip_h = false
		else:
			# The source three-quarter pose faces left, so rightward movement
			# needs a horizontal mirror. This fixes the former orientation
			# inversion while keeping the front-facing silhouette.
			body_view = VIEW_THREE_QUARTER
			art_sprite.flip_h = facing.x > 0.0
	elif horizontal > vertical:
		# The supplied profile faces left, so mirror it while walking right.
		body_view = VIEW_PROFILE
		art_sprite.flip_h = facing.x > 0.0
	elif facing.y < 0.0:
		body_view = VIEW_BACK
		art_sprite.flip_h = false
	else:
		body_view = VIEW_FRONT
		art_sprite.flip_h = false
	art_sprite.frame = body_view * WALK_FRAME_COUNT + walk_frame

func _draw_action(bob: float) -> void:
	var phase := action_elapsed / maxf(0.1, action_duration)
	var cycle := (sin(phase * TAU * 2.0) + 1.0) * 0.5
	match action_id:
		"pickup":
			draw_line(Vector2(-6, 0), Vector2(-10, 6 + cycle * 3.0), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(10, 6 + cycle * 3.0), Color("c68c68"), 3.0)
			draw_circle(Vector2(0, 9), 2.0, Color("b7aa91"))
		"collect_branch":
			draw_line(Vector2(-6, 0), Vector2(-11 + cycle * 3.0, 5), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(11 - cycle * 3.0, 5), Color("c68c68"), 3.0)
			draw_line(Vector2(-4, 8), Vector2(6, 4), Color("b88a5c"), 2.0)
		"gather":
			draw_line(Vector2(-6, 0), Vector2(-4, 7 + cycle * 2.0), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(4, 7 + cycle * 2.0), Color("c68c68"), 3.0)
			draw_circle(Vector2(-4, 9), 2.0, Color("c87861"))
			draw_circle(Vector2(4, 9), 2.0, Color("c87861"))
		"fish":
			draw_line(Vector2(5, 0), Vector2(11, -8 + cycle * 3.0), Color("c68c68"), 3.0)
			draw_line(Vector2(11, -8 + cycle * 3.0), Vector2(17, 7), Color("d8bd83"), 1.0)
			draw_circle(Vector2(17, 8), 2.0 + cycle, Color("8eb6a8"))
		"search_ruins":
			draw_line(Vector2(-6, 0), Vector2(-10, 7), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(10, 7), Color("c68c68"), 3.0)
			draw_rect(Rect2(-14, 7, 28, 4), Color("8b6244"), false, 1.0)
		"chop":
			var swing := lerpf(-0.9, 1.3, cycle)
			draw_set_transform(Vector2(6, -1), swing, Vector2.ONE)
			draw_line(Vector2(0, 0), Vector2(0, 15), Color("8b6244"), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 12), Vector2(1, 8), Vector2(5, 12), Vector2(1, 17)]), Color("bfc7bc"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tend_fire":
			draw_line(Vector2(-6, 0), Vector2(-3, 8), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(3, 8), Color("c68c68"), 3.0)
			draw_circle(Vector2(0, 11), 3.0 + cycle * 2.0, Color("efaa55", 0.55))
		"rest", "sleep":
			draw_line(Vector2(-6, 0), Vector2(-3, 7), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(3, 7), Color("c68c68"), 3.0)
			draw_string(PLAYER_FONT, Vector2(8, -14 - cycle * 3.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("d6c8a8", 0.8))
		"open_door", "close_door":
			draw_line(Vector2(6, 0), Vector2(13, 1 + cycle * 6.0), Color("c68c68"), 3.0)
		"sort_storage":
			draw_line(Vector2(-6, 0), Vector2(-10, 5 + cycle * 4.0), Color("c68c68"), 3.0)
			draw_line(Vector2(6, 0), Vector2(10, 5 + (1.0 - cycle) * 4.0), Color("c68c68"), 3.0)
			draw_rect(Rect2(-2, 6, 4, 4), Color("d4b06d"), true)

func _draw_carried_axe() -> void:
	draw_set_transform(Vector2(8, 1), -0.35, Vector2.ONE)
	draw_line(Vector2(0, -1), Vector2(0, 13), Color("8b6244"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(3, 1), Vector2(3, 5), Vector2(-3, 4)]), Color("bfc7bc"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _has_axe() -> bool:
	return game != null and game.resources != null and game.resources.has_method("has_axe") and game.resources.has_axe()

func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
