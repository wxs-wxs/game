extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var player: ExplorerPlayer = world.player
	assert(player.art_sprite != null)
	assert(player.art_sprite.hframes == 16)
	assert(player.art_sprite.texture.get_width() == 768)

	# Upward diagonals use the rear view so a right-up walk does not show the
	# forward-facing three-quarter pose. The rear view is symmetrical.
	player.facing = Vector2(1, -1).normalized()
	player.walk_frame = 0
	player._update_art_direction()
	assert(player.body_view == 2)
	assert(not player.art_sprite.flip_h)
	assert(player.art_sprite.frame == 8)

	# The source three-quarter pose faces left, so right-down mirrors it.
	player.facing = Vector2(1, 1).normalized()
	player.walk_frame = 2
	player._update_art_direction()
	assert(player.body_view == 3)
	assert(player.art_sprite.flip_h)
	assert(player.art_sprite.frame == 14)
	var down_right_frame := player.art_sprite.frame

	player.facing = Vector2(-1, 0)
	player.walk_frame = 1
	player._update_art_direction()
	assert(player.body_view == 1)
	assert(not player.art_sprite.flip_h)
	assert(player.art_sprite.frame == 5)

	player.facing = Vector2(1, 0)
	player._update_art_direction()
	assert(player.art_sprite.flip_h)
	assert(player.art_sprite.frame == 5)

	# The animation advances through the generated walk poses instead of
	# remaining on the idle frame while movement is held.
	player.facing = Vector2.DOWN
	player.walk_phase = 0.0
	player.walk_frame = 0
	player._update_art_direction()
	player._advance_walk_animation(0.2)
	assert(player.walk_frame == 1)
	assert(player.art_sprite.frame == 1)

	print("PLAYER_MOTION_REGRESSION_OK sheet=%dx%d up_right_view=%d down_right_frame=%d" % [player.art_sprite.texture.get_width(), player.art_sprite.texture.get_height(), 2, down_right_frame])
	quit()
