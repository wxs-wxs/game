extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var hero := game.get_protagonist()
	game.outdoor_position = Vector2(600, 600)
	game.weather = "寒冷"
	game._update_temperature(120.0)
	assert(game.get_environment_temperature() < 10.0)
	assert(hero.body_temperature < GameManager.NORMAL_BODY_TEMPERATURE_C)
	assert(hero.health < 100)

	var warm := GameManager.new(); warm.start_exploration(); warm.weather = "寒冷"; warm.in_house = true; warm.house_fire_lit = true
	warm._update_temperature(120.0)
	assert(warm.get_environment_temperature() > game.get_environment_temperature())
	assert(warm.get_protagonist().body_temperature > hero.body_temperature)

	# Raw berries and raw fish restore only a little health.
	var resources := game.resources
	resources.backpack["food"] = 1; resources.amounts["food"] = 1
	hero.health = 50
	assert(game.use_item("food").get("ok", false)); assert(hero.health == 53)
	resources.backpack["fish_carp"] = 1; resources.amounts["fish_carp"] = 1
	assert(game.use_item("fish_carp").get("ok", false)); assert(hero.health == 56)

	# Cooking consumes the raw item and creates a species-specific cooked item.
	resources.backpack["food"] = 1; resources.amounts["food"] = 1
	assert(resources.cook_berries().get("ok", false))
	hero.health = 50
	assert(game.use_item("cooked_food").get("ok", false)); assert(hero.health == 78)
	resources.backpack["fish_bass"] = 1; resources.amounts["fish_bass"] = 1
	var cooked := resources.cook_fish("fish_bass")
	assert(cooked.get("ok", false))
	hero.health = 50
	assert(game.use_item(str(cooked.get("cooked_key"))).get("ok", false)); assert(hero.health == 82)

	resources.backpack["medicine"] = 1; resources.amounts["medicine"] = 1
	hero.health = 12; hero.injured = true
	assert(game.use_item("medicine").get("ok", false)); assert(hero.health == 100 and not hero.injured)

	var saved := game.to_dict()
	assert(not saved["resources"]["amounts"].has("fuel") and not saved["resources"]["amounts"].has("scrap"))
	var restored := GameManager.new(); restored.from_dict(saved)
	assert(is_equal_approx(restored.get_protagonist().body_temperature, hero.body_temperature))
	assert(restored.resources.get_amount("fuel") == 0 and restored.resources.get_amount("scrap") == 0)

	var fire_test := GameManager.new()
	fire_test.house_fire_lit = true
	var outside_fire_temperature := fire_test.get_environment_temperature()
	fire_test.in_house = true
	assert(fire_test.get_environment_temperature() > outside_fire_temperature)

	# Hunger alone is not a terminal condition; health reaching zero is.
	var hungry := GameManager.new(); hungry.start_exploration(); hungry.get_protagonist().hunger = 0
	hungry.advance_exploration(0.1)
	assert(hungry.phase == GameManager.PHASE_DAY)
	var doomed := GameManager.new(); doomed.start_exploration(); doomed.get_protagonist().health = 0
	doomed.advance_exploration(0.1)
	assert(doomed.phase == GameManager.PHASE_ENDED and doomed.end_reason.contains("生命值归零"))
	doomed.resources.backpack["medicine"] = 1
	assert(not doomed.use_item("medicine").get("ok", false))
	assert(doomed.get_protagonist().health == 0)
	print("TEMPERATURE_FOOD_REGRESSION_OK cold_body=%.1f cold_health=%d cooked=%s" % [hero.body_temperature, hero.health, str(cooked.get("cooked_key"))])
	quit()
