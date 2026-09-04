extends SceneTree

func _init() -> void:
	var game := GameManager.new(); game.start_exploration()
	assert(not game.craft_axe().get("ok", false))
	assert(game.craft_axe().get("reason", "").contains("工作台"))
	game.resources.amounts["stone"] = 10; game.resources.amounts["wood"] = 10; game.resources.amounts["scrap"] = 10
	game.buildings.complete("workbench"); game.apply_building_effect("workbench")
	assert(game.resources.workbench_available)
	assert(game.craft_axe().get("ok", false))
	assert(game.craft_pickaxe().get("ok", false))
	# Fire basin reduces cold indoor damage by two and cold fuel surcharge by one.
	var cold_plain := GameManager.new(); cold_plain.weather = "寒冷"; cold_plain.in_house = true; cold_plain.resources.amounts["food"] = 0; cold_plain.resources.amounts["fuel"] = 0
	cold_plain._night_settlement(); var plain_health := cold_plain.get_protagonist().health
	var cold_basin := GameManager.new(); cold_basin.weather = "寒冷"; cold_basin.in_house = true; cold_basin.resources.amounts["food"] = 0; cold_basin.resources.amounts["fuel"] = 0
	cold_basin.buildings.complete("fire_basin"); cold_basin.apply_building_effect("fire_basin"); cold_basin._night_settlement()
	assert(cold_basin.get_protagonist().health - plain_health == 2)
	# Collector yields only in heavy rain, once per settlement.
	var sunny := GameManager.new(); sunny.weather = "晴朗"; sunny.buildings.complete("rain_collector"); sunny.apply_building_effect("rain_collector"); sunny._night_settlement(); assert(sunny.resources.get_amount("water") == 0)
	var rainy := GameManager.new(); rainy.weather = "暴雨"; rainy.buildings.complete("rain_collector"); rainy.apply_building_effect("rain_collector"); rainy._night_settlement(); assert(rainy.resources.get_amount("water") == 3)
	var rain_saved := rainy.to_dict(); var rain_loaded := GameManager.new(); rain_loaded.from_dict(rain_saved); assert(rain_loaded.buildings.has("rain_collector")); assert(rain_loaded.resources.get_amount("water") == 3)
	var legacy := GameManager.new()
	legacy.from_dict({"version":5, "resources":{"amounts":{"food":2,"wood":1,"medicine":0,"fuel":0,"scrap":0},"tools":{"axe":true}}, "built_facilities":["workbench"]})
	assert(legacy.has_axe() and legacy.buildings.has("workbench") and legacy.resources.workbench_available)
	print("BLUEPRINT_EFFECTS_REGRESSION_OK workbench=%s cold_delta=%d water=%d" % [game.resources.workbench_available, cold_basin.get_protagonist().health - plain_health, rainy.resources.get_amount("water")])
	quit()
