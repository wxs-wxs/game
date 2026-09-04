extends SceneTree

func _init() -> void:
	var main := preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: UIController = main.ui
	assert(ui != null and ui.hud != null)
	assert(ui.hud.scale == Vector2.ONE)
	assert(ui.VIEW_SIZE == Vector2(960, 540))
	assert(ui.hud.get_node("StatusRail") != null)
	assert(ui.hud.get_node("ThreatChip") != null)
	assert(ui.hud.get_node("TemperatureChip") != null)
	assert(ui.hud.get_node("ResourceChip") != null)
	assert(ui.hud.get_node("StatusRail").size == Vector2(210, 30))
	assert(ui.hud.get_node("ThreatChip").size == Vector2(150, 30))
	assert(ui.hud.get_node("ResourceChip").size == Vector2(318, 42))
	assert(ui.threat_progress_bar == null)
	assert(ui.day_label.get_parent() == ui.hud.get_node("StatusRail"))
	assert(ui.clock_label.get_parent() == ui.hud.get_node("StatusRail"))
	assert(ui.weather_label.get_parent() == ui.hud.get_node("StatusRail"))
	assert(ui.threat_label.get_parent() == ui.hud.get_node("ThreatChip"))
	assert(ui.temperature_label.get_parent() == ui.hud.get_node("TemperatureChip"))
	for control in [ui.day_label, ui.clock_icon_label, ui.clock_label, ui.weather_icon_label, ui.weather_label, ui.temperature_label, ui.threat_label]:
		_assert_inside_parent(control)
	for control in ui._resource_icons + ui._resource_badges:
		assert(control.get_parent() == ui.hud.get_node("ResourceChip"))
		_assert_inside_parent(control)
	assert(ui.hud.get_node("SurvivorCard") != null)
	assert(ui.hud.get_node("ObjectiveCard") != null)
	assert(ui.hud.get_node("BuildSelectionPanel") != null)
	assert(ui.hud.get_node("BuildSelectionDim") != null)
	assert(ui.tool_bar == null)
	assert(ui.axe_action_button == null)
	assert(ui.pickaxe_action_button == null)
	assert(ui.hud.get_node_or_null("DetailsDrawer") == null)
	assert(ui.survivor_panel.position == Vector2(12, 468))
	assert(ui.survivor_panel.size == Vector2(246, 60))
	var health_bar: ProgressBar = ui._survivor_meter_bars["health"]["bar"]
	var morale_bar: ProgressBar = ui._survivor_meter_bars["morale"]["bar"]
	assert(health_bar.get_theme_stylebox("background") is StyleBoxTexture)
	assert(health_bar.get_theme_stylebox("fill") is StyleBoxTexture)
	assert((health_bar.get_theme_stylebox("background") as StyleBoxTexture).texture == PixelUITheme.BAR_TEXTURE)
	assert((health_bar.get_theme_stylebox("fill") as StyleBoxTexture).texture == PixelUITheme.BAR_RED_TEXTURE)
	assert(morale_bar.position.y - health_bar.position.y >= 10.0)
	assert(ui.objective_panel.position == Vector2(702, 468))
	assert(ui.objective_panel.size == Vector2(246, 60))
	assert(ui.build_selection_panel.position == Vector2(168, 30))
	assert(ui.build_selection_panel.size == Vector2(624, 480))
	for tool_id in ["axe", "pickaxe"]:
		var tool_button := ui.build_tool_buttons[tool_id] as Button
		assert(tool_button != null)
		assert(tool_button.position.x >= 0 and tool_button.position.y >= 0)
		assert(tool_button.position.x + tool_button.size.x <= ui.build_selection_panel.size.x)
		assert(tool_button.position.y + tool_button.size.y <= ui.build_selection_panel.size.y)
	for facility_id in ui.facility_buttons:
		var facility_card: Button = ui.facility_buttons[facility_id]
		assert(facility_card.position.x + facility_card.size.x <= ui.build_selection_panel.size.x)
		assert(facility_card.position.y + facility_card.size.y <= ui.build_selection_panel.size.y)
	for panel in [ui.backpack_panel, ui.fish_process_panel, ui.storage_panel, ui.shortcut_panel, ui.log_panel]:
		assert(panel != null)
		assert(panel.scale == Vector2.ONE)
		assert(panel.position.x >= 0 and panel.position.y >= 0)
		assert(panel.position.x + panel.size.x <= ui.VIEW_SIZE.x)
		assert(panel.position.y + panel.size.y <= ui.VIEW_SIZE.y)
	assert(ui.backpack_craft_button.position.y + ui.backpack_craft_button.size.y <= ui.backpack_panel.size.y)
	assert(ui.backpack_process_fish_button.position.y + ui.backpack_process_fish_button.size.y <= ui.backpack_panel.size.y)
	assert(ui.backpack_cook_berries_button.position.y + ui.backpack_cook_berries_button.size.y <= ui.backpack_panel.size.y)
	for recipe_id in ui.recipe_buttons:
		var recipe: Button = ui.recipe_buttons[recipe_id]
		assert(recipe.scale == Vector2.ONE)
		assert(recipe.position.y + recipe.size.y <= ui.backpack_panel.size.y)
	_assert_pixel_controls(ui.hud)
	for index in range(7):
		assert(ui.hud.get_node_or_null("ActionRailButton%d" % index) == null)
	assert(PixelUITheme.FONT_SIZE_SMALL == 9)
	assert(PixelUITheme.FONT_SIZE_BODY == 11)
	assert(PixelUITheme.FONT_SIZE_TITLE == 18)
	print("HUD_LAYOUT_OK")
	quit()

func _assert_pixel_controls(node: Node) -> void:
	if node is Control:
		var control := node as Control
		assert(control.scale == Vector2.ONE)
		assert(is_equal_approx(control.position.x, round(control.position.x)))
		assert(is_equal_approx(control.position.y, round(control.position.y)))
		assert(is_equal_approx(control.size.x, round(control.size.x)))
		assert(is_equal_approx(control.size.y, round(control.size.y)))
	for child in node.get_children():
		_assert_pixel_controls(child)

func _assert_inside_parent(control: Control) -> void:
	var parent := control.get_parent() as Control
	assert(parent != null)
	assert(control.position.x >= 0 and control.position.y >= 0)
	assert(control.position.x + control.size.x <= parent.size.x)
	assert(control.position.y + control.size.y <= parent.size.y)
