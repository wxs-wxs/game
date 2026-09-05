extends SceneTree

func _init() -> void:
	var game := GameManager.new(); game.start_exploration()
	assert(not game.craft_axe().get("ok", false))
	assert(game.craft_axe().get("reason", "").contains("工作台"))
	game.resources.amounts["stone"] = 10; game.resources.amounts["wood"] = 10; game.resources.amounts["metal"] = 10
	game.buildings.complete("workbench"); game.apply_building_effect("workbench")
	assert(game.resources.workbench_available)
	assert(game.craft_axe().get("ok", false))
	assert(game.craft_pickaxe().get("ok", false))
	# A fire basin raises the effective indoor environment temperature.
	var cold_plain := GameManager.new(); cold_plain.weather = "寒冷"; cold_plain.in_house = true
	cold_plain._update_temperature(60.0); var plain_body := cold_plain.get_protagonist().body_temperature
	var cold_basin := GameManager.new(); cold_basin.weather = "寒冷"; cold_basin.in_house = true
	cold_basin.buildings.complete("fire_basin"); cold_basin.apply_building_effect("fire_basin"); cold_basin._update_temperature(60.0)
	assert(cold_basin.get_protagonist().body_temperature > plain_body)
	# Collector yields only in heavy rain, once per settlement.
	var sunny := GameManager.new(); sunny.weather = "晴朗"; sunny.buildings.complete("rain_collector"); sunny.apply_building_effect("rain_collector"); sunny._night_settlement(); assert(sunny.resources.get_amount("water") == 0)
	var rainy := GameManager.new(); rainy.weather = "暴雨"; rainy.buildings.complete("rain_collector"); rainy.apply_building_effect("rain_collector"); rainy._night_settlement(); assert(rainy.resources.get_amount("water") == 3)
	var rain_saved := rainy.to_dict(); var rain_loaded := GameManager.new(); rain_loaded.from_dict(rain_saved); assert(rain_loaded.buildings.has("rain_collector")); assert(rain_loaded.resources.get_amount("water") == 3)
	var legacy := GameManager.new()
	legacy.from_dict({"version":5, "resources":{"amounts":{"food":2,"wood":1,"medicine":0},"tools":{"axe":true}}, "built_facilities":["workbench"]})
	assert(legacy.has_axe() and legacy.buildings.has("workbench") and legacy.resources.workbench_available)
	print("BLUEPRINT_EFFECTS_REGRESSION_OK workbench=%s body_plain=%.1f body_basin=%.1f water=%d" % [game.resources.workbench_available, plain_body, cold_basin.get_protagonist().body_temperature, rainy.resources.get_amount("water")])
	quit()
