class_name UIController
extends CanvasLayer

## Runtime HUD for the 960x540 exploration view.
## Every position and size is authored directly in the logical viewport.

var game: GameManager
var world: ExplorationWorld
var hud: Control
var prompt_label: Label
var message_label: Label
var interaction_progress_bar: ProgressBar
var interaction_name_label: Label
var upgrade_button: Button
var build_button: Button
var pause_panel: Panel
var exit_button: Button

var paused_by_menu := false
var message_until := 0.0

# Additional controls are kept as fields so refresh() can be called safely by
# the main loop and by tests before/after a scene has been fully populated.
var day_label: Label
var clock_icon_label: Label
var clock_label: Label
var weather_icon_label: Label
var weather_label: Label
var temperature_label: Label
var threat_label: Label
var threat_icon_label: Label
var threat_progress_bar: ProgressBar
var interaction_detail_label: Label
var save_button: Button
var load_button: Button
var pause_button: Button
var policy_button: Button
var interact_button: Button
var backpack_button: Button
var backpack_panel: Panel
var backpack_content_label: Label
var backpack_close_button: Button
var backpack_craft_button: Button
var backpack_process_fish_button: Button
var backpack_cook_berries_button: Button
var backpack_slots: Array[Dictionary] = []
var fish_process_panel: Panel
var fish_process_close_button: Button
var fish_process_rows: Dictionary = {}
var storage_panel: Panel
var storage_close_button: Button
var storage_capacity_label: Label
var storage_rows: Dictionary = {}
var pause_dim: ColorRect
var recipe_buttons: Dictionary = {}
var feedback_panel: Panel
var survivor_panel: Panel
var survivor_name_label: Label
var survivor_status_label: Label
var survivor_avatar_sprite: TextureRect
var objective_panel: Panel
var objective_live_label: Label
var objective_reward_label: Label
var objective_log_label: Label
var tool_bar: Panel
var axe_action_button: Button
var pickaxe_action_button: Button
var axe_icon: TextureRect
var pickaxe_icon: TextureRect
var build_selection_panel: Panel
var build_selection_dim: ColorRect
var build_selection_hint: Label
var facility_catalog_label: Label
var facility_buttons: Dictionary = {}
var build_tool_buttons: Dictionary = {}
var build_tool_status_labels: Dictionary = {}
var shortcut_button: Button
var shortcut_panel: Panel
var shortcut_dim: ColorRect
var _shortcut_open := false
var log_panel: Panel
var log_content_label: Label
var log_close_button: Button
var _log_open := false
var _survivor_meter_bars: Dictionary = {}
var _resource_badges: Array[Label] = []
var _resource_icons: Array[TextureRect] = []
var _rail_icons: Array[TextureRect] = []
var _last_prompt := ""
var _backpack_open := false
var _storage_open := false
var _fish_process_open := false
var _build_selection_open := false
var _build_selection_was_paused := false
var _overlay_pause_depth := 0
var _overlay_pause_was_paused := false
var _overlay_pause_kinds: Dictionary = {}
var event_panel: Panel
var event_title_label: Label
var event_body_label: Label
var event_choice_buttons: Array[Button] = []
var report_panel: Panel
var report_content_label: Label
var report_continue_button: Button
var _event_open := false
var _report_open := false
var _pixel_theme: Theme
const PixelTheme := preload("res://scripts/pixel_ui_theme.gd")
const Assets := preload("res://scripts/ninja_adventure_assets.gd")

# All values below are authored directly in the 960x540 logical viewport.
const VIEW_SIZE := Vector2(960, 540)
const PANEL_DARK := PixelTheme.PANEL_DARK
const PANEL_MID := PixelTheme.PANEL_MID
const PANEL_LIGHT := PixelTheme.PANEL_LIGHT
const TEXT_MAIN := PixelTheme.TEXT_MAIN
const TEXT_MUTED := PixelTheme.TEXT_MUTED
const TEXT_ACCENT := PixelTheme.TEXT_ACCENT
const TEXT_WARN := PixelTheme.TEXT_WARN
const FONT_FUSION := PixelTheme.FONT
const UI_PANEL_TEXTURE := PixelTheme.PANEL_TEXTURE
const UI_PANEL_PRESSED_TEXTURE := PixelTheme.PANEL_INLAY_TEXTURE
const UI_PANEL_LIGHT_TEXTURE := PixelTheme.PANEL_INLAY_TEXTURE
const UI_DISABLED_TEXTURE := PixelTheme.DISABLED_TEXTURE
const ICON_PLAYER := preload("res://assets/player_character_sheet.png")
const ICON_FOOD := preload("res://assets/art/ninja_adventure/Items/Food/Fish.png")
const ICON_AXE := preload("res://assets/art/ninja_adventure/Items/Tool/Axe.png")
const ICON_PICKAXE := preload("res://assets/art/ninja_adventure/Items/Tool/Pickaxe.png")
const ICON_CHEST := preload("res://assets/art/ninja_adventure/Items/Treasure/BigTreasureChest.png")
const RESOURCE_ICON_TINTS := [Color("f2ca72"), Color("9dc77c"), Color("e58b6a"), Color("b6c6b5"), Color("7eb8b8"), Color("d8bb77"), Color("f2ca72")]
const TOP_LEFT_CHIP_POSITION := Vector2(12, 12)
const TOP_LEFT_CHIP_SIZE := Vector2(210, 30)
const THREAT_CHIP_POSITION := Vector2(405, 12)
const THREAT_CHIP_SIZE := Vector2(150, 30)
const RESOURCE_CHIP_POSITION := Vector2(630, 12)
const RESOURCE_CHIP_SIZE := Vector2(318, 42)

func setup(manager: GameManager, map: ExplorationWorld) -> void:
	game = manager
	world = map
	paused_by_menu = false
	_backpack_open = false
	_storage_open = false
	_fish_process_open = false
	_build_selection_open = false
	_build_selection_was_paused = false
	_overlay_pause_depth = 0
	_overlay_pause_was_paused = false
	_overlay_pause_kinds.clear()
	_shortcut_open = false
	_log_open = false
	_event_open = false
	_report_open = false
	message_until = 0.0
	_last_prompt = ""
	_clear_hud()
	_configure_pixel_font()
	hud = Control.new()
	hud.name = "HUDRoot"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.scale = Vector2.ONE
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.theme = _pixel_theme
	add_child(hud)
	_build_hud()

	# setup() can be called again by a scene reload or a test. Avoid duplicate
	# signal callbacks when the same world instance is reused.
	if world != null:
		if not world.interaction_changed.is_connected(_on_interaction_hint):
			world.interaction_changed.connect(_on_interaction_hint)
		if not world.interaction_result.is_connected(_on_interaction_result):
			world.interaction_result.connect(_on_interaction_result)
		if not world.interaction_progress_changed.is_connected(_on_interaction_progress):
			world.interaction_progress_changed.connect(_on_interaction_progress)
		if not world.storage_open_requested.is_connected(_on_storage_open_requested):
			world.storage_open_requested.connect(_on_storage_open_requested)
		if not world.fish_processing_requested.is_connected(_on_fish_processing_requested):
			world.fish_processing_requested.connect(_on_fish_processing_requested)
		if not world.tool_selection_requested.is_connected(_on_tool_selection_requested):
			world.tool_selection_requested.connect(_on_tool_selection_requested)
	refresh()

func _configure_pixel_font() -> void:
	# Use one imported Fusion Pixel face at a fixed size. Controls stay on the
	# logical pixel grid, so no secondary text scale or fractional transform is
	# needed for crisp CJK, Latin, and numeric labels.
	_pixel_theme = PixelTheme.create_theme()
	_pixel_theme.default_font = FONT_FUSION
	_pixel_theme.default_font_size = PixelTheme.FONT_SIZE_BODY
	var fusion_font := FONT_FUSION as FontFile
	if fusion_font != null:
		fusion_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fusion_font.hinting = TextServer.HINTING_NONE
		fusion_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

func _clear_hud() -> void:
	if is_instance_valid(hud):
		hud.free()
	hud = null
	pause_panel = null
	exit_button = null
	feedback_panel = null
	threat_progress_bar = null
	survivor_panel = null
	survivor_name_label = null
	survivor_status_label = null
	objective_panel = null
	objective_live_label = null
	objective_reward_label = null
	objective_log_label = null
	tool_bar = null
	axe_action_button = null
	pickaxe_action_button = null
	axe_icon = null
	pickaxe_icon = null
	build_selection_panel = null
	build_selection_dim = null
	build_selection_hint = null
	build_tool_buttons.clear()
	build_tool_status_labels.clear()
	_survivor_meter_bars.clear()
	_resource_badges.clear()
	recipe_buttons.clear()
	backpack_button = null
	backpack_panel = null
	backpack_content_label = null
	backpack_close_button = null
	backpack_craft_button = null
	backpack_process_fish_button = null
	backpack_cook_berries_button = null
	backpack_slots.clear()
	fish_process_panel = null
	fish_process_close_button = null
	fish_process_rows.clear()
	storage_panel = null
	storage_close_button = null
	storage_capacity_label = null
	storage_rows.clear()
	clock_icon_label = null
	weather_icon_label = null
	temperature_label = null
	threat_icon_label = null
	survivor_avatar_sprite = null
	shortcut_button = null
	shortcut_panel = null
	shortcut_dim = null
	event_panel = null
	event_title_label = null
	event_body_label = null
	event_choice_buttons.clear()
	report_panel = null
	report_content_label = null
	report_continue_button = null
	log_panel = null
	log_content_label = null
	log_close_button = null
	_resource_icons.clear()
	_rail_icons.clear()

func craft_axe() -> void:
	if game == null or game.resources == null:
		_show_message("制作系统未就绪", 2.0)
		return
	if _has_axe(game.resources):
		_show_message("已经有斧头了", 2.0)
		return
	if not _can_craft_axe():
		_show_message("需要简易工作台" if not game.resources.workbench_available else "制作斧头需要石料 2、木材 3", 2.5)
		return
	var result: Dictionary = game.resources.craft_axe()
	var ok := bool(result.get("ok", false))
	var reason := str(result.get("reason", "斧头制作完成。"))
	_show_message(reason if ok else "制作失败：" + reason, 2.5)
	refresh()

func craft_pickaxe() -> void:
	if game == null or game.resources == null:
		_show_message("制作系统未就绪", 2.0)
		return
	if _has_pickaxe(game.resources):
		_show_message("已经有石镐了", 2.0)
		return
	if not _can_craft_pickaxe():
		_show_message("需要简易工作台" if not game.resources.workbench_available else "制作石镐需要石料 3、木材 2", 2.5)
		return
	var result: Dictionary = game.resources.craft_pickaxe()
	var ok := bool(result.get("ok", false))
	var reason := str(result.get("reason", "石镐制作完成。"))
	_show_message(reason if ok else "制作失败：" + reason, 2.5)
	refresh()

func _has_axe(resources) -> bool:
	return resources != null and bool(resources.has_axe())

func _can_craft_axe() -> bool:
	if game == null or game.resources == null:
		return false
	return bool(game.resources.can_craft_axe())

func _has_pickaxe(resources) -> bool:
	return resources != null and bool(resources.has_pickaxe())

func _can_craft_pickaxe() -> bool:
	if game == null or game.resources == null:
		return false
	return bool(game.resources.can_craft_pickaxe())

func _build_hud() -> void:
	if hud == null:
		return
	# The map is the primary surface. Permanent information is split into small
	# edge chips so no single bar steals the center of the exploration view.
	var day_chip := _panel(TOP_LEFT_CHIP_POSITION, TOP_LEFT_CHIP_SIZE, PANEL_DARK, hud)
	day_chip.name = "StatusRail"
	day_chip.clip_contents = true
	day_label = _label_in(day_chip, Vector2(8, 6), Vector2(54, 18), "", 3, TEXT_ACCENT)
	clock_icon_label = _label_in(day_chip, Vector2(70, 6), Vector2(30, 18), "时间", 3, TEXT_MUTED)
	clock_label = _label_in(day_chip, Vector2(102, 6), Vector2(45, 18), "", 3, TEXT_MAIN)
	weather_icon_label = _label_in(day_chip, Vector2(153, 6), Vector2(30, 18), "天气", 3, TEXT_MUTED)
	weather_label = _label_in(day_chip, Vector2(186, 6), Vector2(24, 18), "", 3, PixelTheme.TEXT_WATER)

	var threat_chip := _panel(THREAT_CHIP_POSITION, THREAT_CHIP_SIZE, PANEL_DARK, hud)
	threat_chip.name = "ThreatChip"
	threat_chip.clip_contents = true
	threat_icon_label = null
	threat_progress_bar = null
	threat_label = _label_in(threat_chip, Vector2(6, 6), Vector2(138, 18), "", 3, TEXT_WARN)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var temperature_chip := _panel(Vector2(240, 12), Vector2(150, 30), PANEL_DARK, hud)
	temperature_chip.name = "TemperatureChip"
	temperature_chip.clip_contents = true
	temperature_label = _label_in(temperature_chip, Vector2(6, 6), Vector2(138, 18), "", 3, PixelTheme.TEXT_WATER)
	temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var resource_chip := _panel(RESOURCE_CHIP_POSITION, RESOURCE_CHIP_SIZE, PANEL_DARK, hud)
	resource_chip.name = "ResourceChip"
	resource_chip.clip_contents = true
	var resource_keys := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal"]
	for index in range(resource_keys.size()):
		var slot_x := 15 + index * 32
		var badge := _label_in(resource_chip, Vector2(slot_x, 17), Vector2(32, 23), "", 3, RESOURCE_ICON_TINTS[index])
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.name = "ResourceBadge%d" % index
		_resource_badges.append(badge)
		var icon_texture: Texture2D = _item_icon_texture(resource_keys[index])
		var icon := _icon(Vector2(slot_x + 8, 1), Vector2(16, 16), icon_texture, resource_chip)
		icon.name = "ResourceIcon%d" % index
		icon.modulate = Color.WHITE
		_resource_icons.append(icon)

	# A small question-mark chip is always available without taking space from
	# the exploration view. It opens the shortcut overlay only on demand.
	shortcut_button = _button(Vector2(12, 57), Vector2(32, 32), "?", hud)
	shortcut_button.name = "ShortcutButton"
	shortcut_button.tooltip_text = "查看快捷键"
	shortcut_button.add_theme_font_size_override("font_size", PixelTheme.FONT_SIZE_TITLE)
	shortcut_button.add_theme_stylebox_override("normal", _button_style(Color("122125", 0.94), UI_PANEL_TEXTURE))
	shortcut_button.add_theme_stylebox_override("hover", _button_style(Color("2c4a49", 0.98), UI_PANEL_TEXTURE))
	shortcut_button.add_theme_stylebox_override("pressed", _button_style(Color("152527", 0.98), UI_PANEL_TEXTURE))
	shortcut_button.pressed.connect(_toggle_shortcut_panel)

	# Exploration actions are keyboard-first. Keep these fields available for
	# compatibility with older callers, but do not create a permanent right rail.
	backpack_button = null
	build_button = null
	upgrade_button = null
	policy_button = null
	save_button = null
	load_button = null
	pause_button = null

	# The survivor card uses a two-column meter grid: identity stays on one clean
	# header line and the four changing values remain aligned beneath it.
	survivor_panel = _panel(Vector2(12, 468), Vector2(246, 60), PANEL_DARK, hud)
	survivor_panel.name = "SurvivorCard"
	survivor_panel.clip_contents = true
	var avatar_frame := _panel(Vector2(12, 6), Vector2(36, 48), PANEL_LIGHT, survivor_panel)
	avatar_frame.name = "AvatarFrame"
	var avatar_texture := AtlasTexture.new()
	avatar_texture.atlas = ICON_PLAYER
	avatar_texture.region = Rect2(0, 0, 48, 72)
	# The compact HUD uses a half-size nearest-neighbor avatar so the status card
	# does not dominate the map at the configured 2x output scale.
	survivor_avatar_sprite = _icon(Vector2(6, 6), Vector2(24, 36), avatar_texture, avatar_frame)
	survivor_avatar_sprite.name = "AvatarSprite"
	survivor_name_label = _label_in(survivor_panel, Vector2(54, 4), Vector2(84, 15), "阿禾", 4, TEXT_ACCENT)
	survivor_status_label = _label_in(survivor_panel, Vector2(144, 4), Vector2(90, 15), "Lv.1", 3, TEXT_MUTED)
	survivor_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var meter_rows := [["生命", "health", Color("d47768")], ["饱腹", "hunger", Color("d5a45d")], ["体力", "energy", Color("70a9a0")], ["士气", "morale", Color("b995c4")]]
	for row_index in range(meter_rows.size()):
		var row: Array = meter_rows[row_index]
		var column := row_index % 2
		var line := row_index / 2
		var x := 54 + column * 90
		var y := 23 + line * 16
		_label_in(survivor_panel, Vector2(x, y), Vector2(18, 12), str(row[0]), 3, TEXT_MUTED)
		var bar := _progress_bar(Vector2(x + 21, y + 3), Vector2(45, 6), survivor_panel, row[2])
		var value := _label_in(survivor_panel, Vector2(x + 69, y), Vector2(21, 12), "0", 3, TEXT_MAIN)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_survivor_meter_bars[str(row[1])] = {"bar":bar, "value":value, "color":row[2]}

	# Bottom-right objective card carries the next actionable objective and its
	# latest reward/log line directly on the map.
	objective_panel = _panel(Vector2(702, 468), Vector2(246, 60), PANEL_DARK, hud)
	objective_panel.name = "ObjectiveCard"
	objective_panel.clip_contents = true
	_label_in(objective_panel, Vector2(12, 5), Vector2(72, 14), "当前目标", 4, TEXT_MUTED)
	objective_live_label = _label_in(objective_panel, Vector2(90, 5), Vector2(144, 14), "", 3, TEXT_ACCENT)
	objective_live_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_live_label.clip_text = true
	objective_reward_label = _label_in(objective_panel, Vector2(12, 24), Vector2(222, 13), "", 3, TEXT_MUTED)
	objective_reward_label.clip_text = true
	objective_log_label = _label_in(objective_panel, Vector2(12, 40), Vector2(222, 14), "", 3, TEXT_MAIN)
	objective_log_label.clip_text = true
	var objective_log_button := _button_in(objective_panel, Vector2(0, 0), Vector2(0, 0), "日志")
	objective_log_button.visible = false
	objective_log_button.name = "ObjectiveLogButton"
	objective_log_button.tooltip_text = "查看最近日志"
	objective_log_button.pressed.connect(toggle_log_panel)
	var objective_shortcut_button := _button_in(objective_panel, Vector2(0, 0), Vector2(0, 0), "快捷")
	objective_shortcut_button.visible = false
	objective_shortcut_button.name = "ObjectiveShortcutButton"
	objective_shortcut_button.tooltip_text = "查看快捷键"
	objective_shortcut_button.pressed.connect(_toggle_shortcut_panel)

	# Tool construction is selected explicitly after pressing B. The old
	# bottom-center icon buttons were ambiguous and duplicated the build flow.
	tool_bar = null
	axe_action_button = null
	pickaxe_action_button = null
	axe_icon = null
	pickaxe_icon = null
	_build_tool_selection_panel()

	# Context prompt is created once and only shown when a point is nearby.
	var prompt_panel := _panel(Vector2(300, 432), Vector2(360, 26), PANEL_DARK, hud)
	prompt_panel.name = "PromptPanel"
	prompt_label = _label(Vector2(9, 4), Vector2(210, 18), "", 3, TEXT_ACCENT, prompt_panel)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_button = _button(Vector2(228, 4), Vector2(123, 18), "互动 E", prompt_panel)
	interact_button.tooltip_text = "执行附近交互（E）"
	interact_button.pressed.connect(_on_interact_pressed)
	interact_button.visible = false
	prompt_panel.visible = false

	# Context prompts still appear above the tool bar when an interaction is near.
	feedback_panel = _panel(Vector2(240, 390), Vector2(480, 28), PANEL_DARK, hud)
	feedback_panel.name = "FeedbackToast"
	message_label = _label(Vector2(12, 5), Vector2(456, 18), "", 6, TEXT_MAIN, feedback_panel)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.clip_text = true
	feedback_panel.visible = false

	# Timed actions use a compact bottom indicator so the map stays readable.
	var interaction_panel := _panel(Vector2(390, 407), Vector2(180, 18), PANEL_DARK, hud)
	interaction_name_label = _label(Vector2(6, 2), Vector2(42, 14), "", 3, TEXT_ACCENT, interaction_panel)
	interaction_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	interaction_name_label.clip_text = true
	interaction_progress_bar = _progress_bar(Vector2(48, 6), Vector2(126, 6), interaction_panel)
	interaction_progress_bar.max_value = 1.0
	interaction_detail_label = null
	interaction_panel.name = "InteractionPanel"
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.visible = false

	_build_pause_panel()
	_build_backpack_panel()
	_build_storage_panel()
	_build_shortcut_panel()
	_build_log_panel()
	_build_event_panel()
	_build_report_panel()

func _build_tool_selection_panel() -> void:
	build_selection_dim = ColorRect.new()
	build_selection_dim.position = Vector2.ZERO
	build_selection_dim.size = VIEW_SIZE
	build_selection_dim.color = Color("081013", 0.58)
	build_selection_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	build_selection_dim.name = "BuildSelectionDim"
	build_selection_dim.z_index = 40
	hud.add_child(build_selection_dim)

	build_selection_panel = _panel(Vector2(168, 30), Vector2(624, 480), PANEL_MID, hud)
	build_selection_panel.name = "BuildSelectionPanel"
	build_selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	build_selection_panel.z_index = 41
	_label_in(build_selection_panel, Vector2(30, 20), Vector2(300, 24), "选择建造内容", 9, TEXT_ACCENT)
	build_selection_hint = _label_in(build_selection_panel, Vector2(30, 50), Vector2(444, 18), "选择工具后即可制作", 4, TEXT_MUTED)
	build_selection_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_tool_card("axe", "石斧", ICON_AXE, "石料 2  ·  木材 3", Vector2(30, 80))
	_build_tool_card("pickaxe", "石镐", ICON_PICKAXE, "石料 3  ·  木材 2", Vector2(264, 80))
	if game != null and game.buildings != null:
		for index in range(game.buildings.construction_catalog().size()):
			var definition: Dictionary = game.buildings.construction_catalog()[index]
			var card := _button_in(build_selection_panel, Vector2(30 + (index % 3) * 174, 226 + (index / 3) * 54), Vector2(164, 48), "")
			card.name = "FacilityBuildCard_%s" % str(definition.get("id", ""))
			card.pressed.connect(_select_facility_for_build.bind(str(definition.get("id", ""))))
			facility_buttons[str(definition.get("id", ""))] = card

	var facility_button := _button_in(build_selection_panel, Vector2(30, 400), Vector2(290, 32), "进入设施建造")
	facility_button.name = "FacilityBuildButton"
	facility_button.tooltip_text = "选择并放置营地设施"
	facility_button.pressed.connect(_enter_facility_build_mode)
	var close := _button_in(build_selection_panel, Vector2(338, 400), Vector2(196, 32), "关闭")
	close.name = "BuildSelectionCloseButton"
	close.tooltip_text = "关闭建造选择"
	close.pressed.connect(_close_build_selection)
	build_selection_dim.visible = false
	build_selection_panel.visible = false

func _build_tool_card(tool_id: String, label_text: String, icon_texture: Texture2D, cost_text: String, pos: Vector2) -> void:
	var card := _button_in(build_selection_panel, pos, Vector2(210, 138), "")
	card.name = "BuildToolButton_%s" % tool_id
	card.tooltip_text = "制作%s" % label_text
	card.pressed.connect(_select_tool_and_craft.bind(tool_id))
	var icon := _icon(Vector2(97, 10), Vector2(16, 16), icon_texture, card)
	icon.name = "Icon"
	var name_label := _label_in(card, Vector2(12, 38), Vector2(186, 20), label_text, 6, TEXT_ACCENT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost_label := _label_in(card, Vector2(12, 65), Vector2(186, 18), cost_text, 3, TEXT_MUTED)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_label := _label_in(card, Vector2(12, 94), Vector2(186, 18), "", 3, TEXT_MAIN)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_tool_buttons[tool_id] = card
	build_tool_status_labels[tool_id] = status_label

func _refresh_build_selection() -> void:
	if build_selection_panel == null or game == null or game.resources == null:
		return
	var resources = game.resources
	var workbench_ready := bool(resources.workbench_available)
	for tool_id in ["axe", "pickaxe"]:
		var button: Button = build_tool_buttons.get(tool_id)
		var status_label: Label = build_tool_status_labels.get(tool_id)
		if button == null or status_label == null:
			continue
		var status: Dictionary = resources.tool_status(tool_id) if resources.has_method("tool_status") else {}
		var owned := bool(status.get("owned", resources.has_tool(tool_id) if resources.has_method("has_tool") else false))
		var can_craft := bool(status.get("can_craft", false))
		button.disabled = owned or not can_craft
		if owned:
			status_label.text = "已拥有"
			status_label.add_theme_color_override("font_color", TEXT_ACCENT)
		elif not workbench_ready:
			status_label.text = "需要简易工作台"
			status_label.add_theme_color_override("font_color", TEXT_WARN)
		elif can_craft:
			status_label.text = "可制作"
			status_label.add_theme_color_override("font_color", TEXT_ACCENT)
		else:
			status_label.text = "材料不足"
			status_label.add_theme_color_override("font_color", TEXT_WARN)
	if build_selection_hint != null:
		build_selection_hint.text = "先建造简易工作台" if not workbench_ready else "选择工具后即可制作，或进入设施建造"
	if game.buildings != null:
		for definition: Dictionary in game.buildings.construction_catalog():
			var id := str(definition.get("id", ""))
			var status: Dictionary = game.construction_status(id)
			var state := str(status.get("state", "locked"))
			var state_text: String = str({"completed":"已完成", "building":"建造中", "locked":"锁定", "materials":"缺材料", "available":"可建造"}.get(state, state))
			var card: Button = facility_buttons.get(id)
			if card != null:
				card.text = "%s\n%s  %.1fs  Lv.%d  %s" % [str(definition.get("name", id)), _cost_text(definition.get("cost", {})), float(definition.get("build_time", 0.0)), int(definition.get("required_skill_level", 1)), state_text]
				card.disabled = state in ["completed", "building", "locked", "materials"]

func _select_facility_for_build(building_id: String) -> void:
	if world == null or world.build_mode == null: return
	world.build_mode.selected_blueprint = building_id
	_enter_facility_build_mode()

func _open_build_selection() -> void:
	if _build_selection_open:
		return
	if world != null and world.build_mode != null and world.build_mode.active:
		world.build_mode.active = false
	_build_selection_open = true
	_open_pause_overlay("build_selection")
	_refresh_build_selection()
	refresh()

func _close_build_selection() -> void:
	if not _build_selection_open:
		return
	_build_selection_open = false
	_close_pause_overlay("build_selection")
	refresh()

func _select_tool_and_craft(tool_id: String) -> void:
	if game == null or game.resources == null:
		return
	var result: Dictionary
	if tool_id == "axe":
		result = game.craft_axe()
	else:
		result = game.craft_pickaxe()
	var ok := bool(result.get("ok", false))
	var reason := str(result.get("reason", "制作失败。"))
	if ok:
		_close_build_selection()
		_show_message(reason, 2.5)
	else:
		_show_message(reason, 2.5)
	_refresh_build_selection()
	refresh()

func _enter_facility_build_mode() -> void:
	_close_build_selection()
	if world == null or world.build_mode == null:
		return
	world.build_mode.toggle()
	if world.build_mode.active:
		_update_build_prompt()
	refresh()

func _build_pause_panel() -> void:
	pause_dim = ColorRect.new()
	pause_dim.position = Vector2.ZERO
	pause_dim.size = VIEW_SIZE
	pause_dim.color = Color("081013", 0.58)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dim.name = "PauseDim"
	hud.add_child(pause_dim)
	pause_panel = _panel(Vector2(267, 84), Vector2(426, 375), PANEL_MID, hud)
	pause_panel.name = "PausePanel"
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label_in(pause_panel, Vector2(27, 21), Vector2(372, 36), "暂停菜单", 10, TEXT_ACCENT)
	var hint := _label_in(pause_panel, Vector2(27, 60), Vector2(372, 27), "进度已冻结", 6, TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var resume := _button_in(pause_panel, Vector2(33, 102), Vector2(360, 42), "继续游戏")
	resume.pressed.connect(_on_resume)
	var save := _button_in(pause_panel, Vector2(33, 153), Vector2(174, 42), "保存")
	save.pressed.connect(save_game)
	var load := _button_in(pause_panel, Vector2(219, 153), Vector2(174, 42), "读取")
	load.pressed.connect(load_game)
	var build := _button_in(pause_panel, Vector2(33, 207), Vector2(360, 42), "返回探索")
	build.pressed.connect(_on_resume)
	exit_button = _button_in(pause_panel, Vector2(33, 261), Vector2(360, 42), "退出游戏")
	exit_button.tooltip_text = "退出游戏"
	exit_button.pressed.connect(exit_game)
	var close := _label_in(pause_panel, Vector2(27, 324), Vector2(372, 27), "Esc 关闭 · F5 保存 · F9 读取", 5, TEXT_MUTED)
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_dim.visible = false
	pause_panel.hide()

func _build_backpack_panel() -> void:
	backpack_panel = _panel(Vector2(171, 42), Vector2(618, 462), PANEL_MID, hud)
	backpack_panel.name = "BackpackPanel"
	backpack_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_panel.z_index = 20
	_label_in(backpack_panel, Vector2(30, 21), Vector2(390, 33), "背包", 10, TEXT_ACCENT)
	backpack_close_button = _button_in(backpack_panel, Vector2(489, 18), Vector2(102, 36), "关闭")
	backpack_close_button.pressed.connect(close_backpack)
	backpack_content_label = _label_in(backpack_panel, Vector2(30, 57), Vector2(552, 24), "", 6, TEXT_MUTED)
	backpack_content_label.clip_text = true
	for index in range(ResourceManager.BACKPACK_UPGRADED_CAPACITY):
		var column := index % 4
		var row := index / 4
		var cell := _panel(Vector2(30 + column * 144, 90 + row * 78), Vector2(132, 66), PANEL_LIGHT, backpack_panel)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_icon := _icon(Vector2(50, 6), Vector2(32, 32), ICON_CHEST, cell)
		item_icon.visible = false
		var item_label := _label_in(cell, Vector2(9, 42), Vector2(80, 18), "空", 5, TEXT_MAIN)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.clip_text = true
		var count_label := _label_in(cell, Vector2(93, 6), Vector2(30, 18), "", 6, TEXT_ACCENT)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var use_button := _button_in(cell, Vector2(94, 39), Vector2(30, 20), "用")
		use_button.name = "UseItemButton"
		use_button.tooltip_text = "食用或使用当前物品"
		use_button.pressed.connect(_use_backpack_slot.bind(index))
		use_button.visible = false
		backpack_slots.append({"cell":cell, "item":item_label, "count":count_label, "icon":item_icon, "use":use_button, "key":""})
	# Keep the action and recipe rows inside the 462px panel in design space.
	backpack_craft_button = _button_in(backpack_panel, Vector2(30, 360), Vector2(198, 36), "制作背包")
	backpack_craft_button.tooltip_text = "布料 2 + 纤维 4 + 金属 1"
	backpack_craft_button.pressed.connect(craft_backpack)
	backpack_process_fish_button = _button_in(backpack_panel, Vector2(240, 360), Vector2(165, 36), "处理鱼")
	backpack_process_fish_button.tooltip_text = "选择鱼类烤成熟鱼"
	backpack_process_fish_button.pressed.connect(_open_fish_processing_from_backpack)
	backpack_cook_berries_button = _button_in(backpack_panel, Vector2(414, 360), Vector2(150, 36), "烤浆果")
	backpack_cook_berries_button.tooltip_text = "把 1 个浆果烤成熟浆果"
	backpack_cook_berries_button.pressed.connect(_cook_berries)
	var recipe_ids := ["bandage", "torch", "trap"]
	for index in range(recipe_ids.size()):
		var recipe_id: String = recipe_ids[index]
		var craft_button := _button_in(backpack_panel, Vector2(30 + index * 144, 408), Vector2(132, 30), recipe_id)
		craft_button.tooltip_text = "工作台配方"
		craft_button.pressed.connect(_craft_recipe.bind(recipe_id))
		recipe_buttons[recipe_id] = craft_button
	backpack_panel.visible = false
	_build_fish_process_panel()

func _build_fish_process_panel() -> void:
	fish_process_panel = _panel(Vector2(174, 90), Vector2(612, 360), PANEL_MID, hud)
	fish_process_panel.name = "FishProcessPanel"
	fish_process_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	fish_process_panel.z_index = 23
	_label_in(fish_process_panel, Vector2(30, 21), Vector2(435, 33), "处理鱼类", 10, TEXT_ACCENT)
	fish_process_close_button = _button_in(fish_process_panel, Vector2(489, 18), Vector2(102, 36), "关闭")
	fish_process_close_button.pressed.connect(close_fish_processing)
	_label_in(fish_process_panel, Vector2(30, 60), Vector2(552, 27), "选择一种鱼烤成熟鱼，也可以在背包中生吃", 6, TEXT_MUTED)
	var keys := ResourceManager.FISH_KEYS
	for index in range(keys.size()):
		var key: String = keys[index]
		var y := 105 + index * 54
		var icon := _icon(Vector2(30, y + 9), Vector2(16, 16), ICON_FOOD, fish_process_panel)
		icon.modulate = Color("70a9c4")
		var label := _label_in(fish_process_panel, Vector2(66, y), Vector2(318, 30), "", 7, TEXT_MAIN)
		var process := _button_in(fish_process_panel, Vector2(420, y - 3), Vector2(162, 36), "烤熟")
		process.pressed.connect(_process_fish.bind(key))
		fish_process_rows[key] = {"label":label, "icon":icon, "process":process}
	fish_process_panel.visible = false

func _build_storage_panel() -> void:
	storage_panel = _panel(Vector2(72, 18), Vector2(816, 504), PANEL_MID, hud)
	storage_panel.name = "StoragePanel"
	storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	storage_panel.z_index = 21
	_label_in(storage_panel, Vector2(30, 21), Vector2(450, 36), "储物架整理", 10, TEXT_ACCENT)
	storage_capacity_label = _label_in(storage_panel, Vector2(30, 60), Vector2(570, 27), "", 6, TEXT_MUTED)
	storage_close_button = _button_in(storage_panel, Vector2(678, 18), Vector2(102, 36), "关闭")
	storage_close_button.pressed.connect(close_storage)
	var keys := ResourceManager.ITEM_KEYS
	for index in range(keys.size()):
		var key: String = keys[index]
		var column := index % 2
		var row_index := index / 2
		var base_x := 30 + column * 384
		var y := 96 + row_index * 29
		var icon := _icon(Vector2(base_x, y + 4), Vector2(16, 16), _item_icon_texture(key), storage_panel)
		icon.modulate = _item_icon_tint(key)
		var label := _label_in(storage_panel, Vector2(base_x + 36, y), Vector2(138, 24), "", 5, TEXT_MAIN)
		var take := _button_in(storage_panel, Vector2(base_x + 180, y - 3), Vector2(54, 27), "取")
		var put := _button_in(storage_panel, Vector2(base_x + 240, y - 3), Vector2(54, 27), "放")
		var discard := _button_in(storage_panel, Vector2(base_x + 300, y - 3), Vector2(54, 27), "丢")
		take.tooltip_text = "从储物架取 1 个到背包"
		put.tooltip_text = "将背包中的 1 个放回储物架"
		discard.tooltip_text = "从储物架丢弃 1 个"
		take.pressed.connect(_storage_take.bind(key))
		put.pressed.connect(_storage_put.bind(key))
		discard.pressed.connect(_storage_discard.bind(key))
		storage_rows[key] = {"label":label, "icon":icon, "take":take, "put":put, "discard":discard}
	storage_panel.visible = false

func _build_shortcut_panel() -> void:
	shortcut_dim = ColorRect.new()
	shortcut_dim.position = Vector2.ZERO
	shortcut_dim.size = VIEW_SIZE
	shortcut_dim.color = Color("081013", 0.46)
	shortcut_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	shortcut_dim.name = "ShortcutDim"
	shortcut_dim.z_index = 30
	hud.add_child(shortcut_dim)
	shortcut_panel = _panel(Vector2(237, 75), Vector2(486, 390), PANEL_MID, hud)
	shortcut_panel.name = "ShortcutPanel"
	shortcut_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shortcut_panel.z_index = 31
	_label_in(shortcut_panel, Vector2(30, 24), Vector2(336, 33), "快捷键", 9, TEXT_ACCENT)
	var close := _button_in(shortcut_panel, Vector2(396, 21), Vector2(60, 30), "关闭")
	close.name = "ShortcutCloseButton"
	close.tooltip_text = "关闭快捷键"
	close.pressed.connect(_toggle_shortcut_panel)
	var rows := [
		["移动", "WASD / 方向键"],
		["互动", "E"],
		["建造选择", "B"],
		["暂停", "Esc / Space"],
		["背包", "K"],
		["保存 / 读取", "F5 / F9"],
		["政策 / 升级", "P / U"]
	]
	for index in range(rows.size()):
		var row: Array = rows[index]
		var y := 81 + index * 39
		var key_label := _label_in(shortcut_panel, Vector2(36, y), Vector2(162, 24), str(row[0]), 5, TEXT_MUTED)
		var value_label := _label_in(shortcut_panel, Vector2(204, y), Vector2(240, 24), str(row[1]), 5, TEXT_MAIN)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _label_in(shortcut_panel, Vector2(36, 360), Vector2(414, 21), "探索中按 ? 随时查看", 5, TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut_dim.visible = false
	shortcut_panel.visible = false

func _toggle_shortcut_panel() -> void:
	if _build_selection_open:
		_close_build_selection()
	if _shortcut_open:
		_shortcut_open = false
		_close_pause_overlay("shortcut")
	else:
		_close_standard_overlays()
		_shortcut_open = true
		_open_pause_overlay("shortcut")
	refresh()

func _build_log_panel() -> void:
	log_panel = _panel(Vector2(135, 72), Vector2(690, 396), PANEL_MID, hud)
	log_panel.name = "LogPanel"
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	log_panel.z_index = 25
	_label_in(log_panel, Vector2(30, 24), Vector2(390, 33), "探索日志", 9, TEXT_ACCENT)
	log_close_button = _button_in(log_panel, Vector2(582, 21), Vector2(78, 30), "关闭")
	log_close_button.tooltip_text = "关闭日志"
	log_close_button.pressed.connect(close_log_panel)
	log_content_label = _label_in(log_panel, Vector2(30, 69), Vector2(630, 300), "", 5, TEXT_MAIN)
	log_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_content_label.clip_text = true
	log_panel.visible = false

func _build_event_panel() -> void:
	event_panel = _panel(Vector2(177, 96), Vector2(606, 348), PANEL_MID, hud)
	event_panel.name = "EventPanel"
	event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	event_panel.z_index = 35
	event_title_label = _label_in(event_panel, Vector2(30, 24), Vector2(546, 30), "夜间事件", 9, TEXT_ACCENT)
	event_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_body_label = _label_in(event_panel, Vector2(42, 72), Vector2(522, 66), "", 5, TEXT_MAIN)
	event_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for index in range(2):
		var choice := _button_in(event_panel, Vector2(42, 166 + index * 72), Vector2(522, 54), "")
		choice.name = "EventChoice%d" % index
		choice.pressed.connect(_on_event_choice.bind(index))
		event_choice_buttons.append(choice)
	event_panel.visible = false

func _build_report_panel() -> void:
	report_panel = _panel(Vector2(177, 96), Vector2(606, 348), PANEL_MID, hud)
	report_panel.name = "ReportPanel"
	report_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	report_panel.z_index = 36
	_label_in(report_panel, Vector2(30, 24), Vector2(546, 30), "夜间报告", 9, TEXT_ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_content_label = _label_in(report_panel, Vector2(42, 72), Vector2(522, 210), "", 5, TEXT_MAIN)
	report_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	report_content_label.clip_text = true
	report_continue_button = _button_in(report_panel, Vector2(177, 294), Vector2(252, 36), "进入清晨")
	report_continue_button.pressed.connect(_on_report_continue)
	report_panel.visible = false

func _open_pause_overlay(kind: String) -> void:
	if _overlay_pause_kinds.has(kind):
		return
	if _overlay_pause_depth == 0 and game != null and game.time != null:
		_overlay_pause_was_paused = bool(game.time.paused)
		game.time.paused = true
	_overlay_pause_kinds[kind] = true
	_overlay_pause_depth += 1

func _close_pause_overlay(kind: String) -> void:
	if not _overlay_pause_kinds.has(kind):
		return
	_overlay_pause_kinds.erase(kind)
	_overlay_pause_depth = maxi(0, _overlay_pause_depth - 1)
	if _overlay_pause_depth == 0 and game != null and game.time != null:
		game.time.paused = _overlay_pause_was_paused

func has_pause_overlay() -> bool:
	return _overlay_pause_depth > 0

func _on_event_choice(index: int) -> void:
	if game == null:
		return
	var result: Dictionary = game.choose_event(index)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("reason", "选择未执行。")), 2.5)
		refresh()
		return
	_event_open = false
	_close_pause_overlay("event")
	if game.phase == GameManager.PHASE_REPORT:
		show_report(game.report_lines)
	elif game.phase == GameManager.PHASE_ENDED:
		show_report(game.report_lines, true)
	refresh()

func _on_report_continue() -> void:
	if game == null:
		return
	if game.phase == GameManager.PHASE_REPORT:
		game.continue_from_report()
	_report_open = false
	_close_pause_overlay("report")
	refresh()

func show_event(event: Dictionary) -> void:
	if event_panel == null or event.is_empty():
		return
	_event_open = true
	_report_open = false
	_close_pause_overlay("report")
	_open_pause_overlay("event")
	var data: Dictionary = event.get("data", {}) if event.get("data", {}) is Dictionary else {}
	event_title_label.text = str(data.get("title", "夜间事件"))
	event_body_label.text = str(data.get("text", "夜里发生了一些事情。"))
	var choices: Array = data.get("choices", [])
	for index in range(event_choice_buttons.size()):
		var button: Button = event_choice_buttons[index]
		if index >= choices.size():
			button.visible = false
			continue
		var choice: Dictionary = choices[index] if choices[index] is Dictionary else {}
		var cost: Dictionary = choice.get("cost", {}) if choice.get("cost", {}) is Dictionary else {}
		button.visible = true
		button.text = "%s\n%s" % [str(choice.get("label", "选择")), _cost_text(cost) if not cost.is_empty() else "不消耗资源"]
		button.disabled = not game.resources.can_afford(cost)
	event_panel.visible = true
	report_panel.visible = false

func show_report(lines: Array[String], terminal: bool = false) -> void:
	if report_panel == null:
		return
	_report_open = true
	_event_open = false
	_close_pause_overlay("event")
	_open_pause_overlay("report")
	report_content_label.text = "\n".join(lines) if not lines.is_empty() else "这一天平安过去了。"
	report_continue_button.text = "结束游戏" if terminal else "进入清晨"
	report_continue_button.disabled = terminal
	report_panel.visible = true
	event_panel.visible = false

func toggle_log_panel() -> void:
	if _build_selection_open:
		_close_build_selection()
	if _log_open:
		_log_open = false
		_close_pause_overlay("log")
	else:
		_close_standard_overlays()
		_log_open = true
		_open_pause_overlay("log")
	refresh()

func close_log_panel() -> void:
	_log_open = false
	_close_pause_overlay("log")
	refresh()

func _close_standard_overlays() -> void:
	if _backpack_open:
		_backpack_open = false
		_close_pause_overlay("backpack")
	if _storage_open:
		_storage_open = false
		_close_pause_overlay("storage")
	if _fish_process_open:
		_fish_process_open = false
		_close_pause_overlay("fish_process")
	if _shortcut_open:
		_shortcut_open = false
		_close_pause_overlay("shortcut")
	if _log_open:
		_log_open = false
		_close_pause_overlay("log")

func refresh() -> void:
	if game == null:
		return
	var resources = game.resources
	var hero: Survivor = game.get_protagonist() if game.has_method("get_protagonist") else null
	var current_time := Time.get_ticks_msec() / 1000.0

	if resources != null:
		var badge_keys := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal"]
		for index in range(mini(_resource_badges.size(), badge_keys.size())):
			var badge: Label = _resource_badges[index]
			var key := str(badge_keys[index])
			var amount := _resource_amount(resources, key)
			# The capacity stays in the tooltip; a single compact quantity keeps
			# every 16px icon slot readable at the native HUD scale.
			badge.text = str(amount)
			badge.tooltip_text = "%s：%d / %d" % [resources.display_name(key), _resource_amount(resources, key), _resource_capacity(resources, key)]
	if day_label != null:
		day_label.text = "第%d天" % int(game.day)
	if clock_label != null:
		clock_label.text = _clock_text()
	if weather_label != null:
		weather_label.text = _weather_text(str(game.weather))
	if temperature_label != null:
		var temperature_status: Dictionary = game.get_temperature_status() if game.has_method("get_temperature_status") else {}
		temperature_label.text = "环%.0f° 身%.1f°" % [float(temperature_status.get("environment", 0.0)), float(temperature_status.get("body", 0.0))]
		temperature_label.tooltip_text = "环境温度与主角身体温度；低于 %.0f° 会持续损失生命" % float(temperature_status.get("threshold", 35.0))
	if threat_label != null:
		threat_label.text = _threat_text()
	if threat_progress_bar != null:
		var threat_status: Dictionary = game.get_survival_status()
		threat_progress_bar.value = int(threat_status.get("threat", 0))

	if hero != null:
		var health := _stat_value(hero, "health")
		var hunger := _stat_value(hero, "hunger")
		var energy := _stat_value(hero, "energy")
		var morale := _stat_value(hero, "morale")
		_update_survivor_card(hero)
	else:
		_update_survivor_card(null)

	_update_target(hero)
	_update_log()
	_refresh_phase_overlay()
	_update_buttons()
	_refresh_backpack_panel()
	_refresh_fish_process_panel()
	_refresh_storage_panel()
	if pause_panel != null:
		pause_panel.visible = paused_by_menu
	if pause_dim != null:
		pause_dim.visible = paused_by_menu
	if message_label != null and message_until > 0.0 and message_until <= current_time:
		message_label.text = ""
		message_until = 0.0
		_update_log()

	# Keep context prompt and progress state coherent when a save/load operation
	# restores a world while the HUD is already visible.
	if world != null and world.build_mode != null and world.build_mode.active:
		_update_build_prompt()
	elif _last_prompt.begins_with("建造模式"):
		# Main input can close build mode directly (B/Esc). Clear the old
		# build prompt and cost toast on the next HUD refresh.
		_last_prompt = ""
		if prompt_label != null:
			prompt_label.text = ""
		_set_prompt_visible(false)
		if message_label != null and message_until <= 0.0:
			message_label.text = ""
	elif _last_prompt != "" and prompt_label != null:
		prompt_label.text = _last_prompt
		_set_prompt_visible(true)

func _update_buttons() -> void:
	var inside := bool(game.in_house) if game != null else false
	var paused := _is_paused()
	var overlay_open := _backpack_open or _storage_open or _fish_process_open or _shortcut_open or _log_open or _build_selection_open or _event_open or _report_open
	if backpack_button != null:
		backpack_button.visible = not overlay_open
	if backpack_panel != null:
		backpack_panel.visible = _backpack_open
	if storage_panel != null:
		storage_panel.visible = _storage_open
	if fish_process_panel != null:
		fish_process_panel.visible = _fish_process_open and not _backpack_open and not _storage_open
	if build_button != null:
		build_button.disabled = inside or world == null or world.build_mode == null
		build_button.text = ""
		build_button.tooltip_text = "退出建造模式" if world != null and world.build_mode != null and world.build_mode.active else "建造模式"
		build_button.visible = not overlay_open
	if upgrade_button != null:
		upgrade_button.disabled = inside or int(game.house_level) >= 3
		upgrade_button.visible = not overlay_open
	if policy_button != null:
		policy_button.disabled = not _policy_available()
		policy_button.visible = not overlay_open
	if save_button != null:
		save_button.disabled = false
		save_button.visible = not overlay_open
	if load_button != null:
		load_button.disabled = false
		load_button.visible = not overlay_open
	if pause_button != null:
		pause_button.text = "▶" if paused else "Ⅱ"
		pause_button.disabled = str(game.phase) == "ended"
		pause_button.visible = not overlay_open
	if build_selection_panel != null:
		build_selection_panel.visible = _build_selection_open
	if build_selection_dim != null:
		build_selection_dim.visible = _build_selection_open
	_refresh_build_selection()
	if shortcut_button != null:
		shortcut_button.visible = not overlay_open
	if shortcut_panel != null:
		shortcut_panel.visible = _shortcut_open
	if shortcut_dim != null:
		shortcut_dim.visible = _shortcut_open
	if log_panel != null:
		log_panel.visible = _log_open
	if log_content_label != null and _log_open:
		_refresh_log_panel()
	if event_panel != null:
		event_panel.visible = _event_open
	if report_panel != null:
		report_panel.visible = _report_open
	for recipe_id in recipe_buttons:
		var button: Button = recipe_buttons[recipe_id]
		var status: Dictionary = game.crafting.recipe_status(str(recipe_id)) if game != null and game.crafting != null else {"can_craft":false}
		button.disabled = not bool(status.get("can_craft", false))
		button.text = str(game.resources.display_name(str(recipe_id))) if game != null else str(recipe_id)
	if interact_button != null:
		var nearby := world != null and world.nearest != null and not inside
		var can_interact := nearby and not paused
		interact_button.visible = nearby and not overlay_open
		interact_button.disabled = not can_interact

func _refresh_phase_overlay() -> void:
	if game == null:
		return
	match str(game.phase):
		GameManager.PHASE_EVENT:
			if not game.events.current_event.is_empty():
				show_event(game.events.current_event)
		GameManager.PHASE_REPORT:
			show_report(game.report_lines)
		GameManager.PHASE_ENDED:
			show_report(game.report_lines, true)
		_:
			if _event_open:
				_event_open = false
				_close_pause_overlay("event")
			if _report_open:
				_report_open = false
				_close_pause_overlay("report")

func toggle_backpack() -> void:
	if _build_selection_open:
		_close_build_selection()
	if _backpack_open:
		close_backpack()
		return
	_close_standard_overlays()
	_backpack_open = true
	_open_pause_overlay("backpack")
	refresh()

func close_backpack() -> void:
	_backpack_open = false
	_close_pause_overlay("backpack")
	refresh()

func close_storage() -> void:
	_storage_open = false
	_close_pause_overlay("storage")
	refresh()

func close_overlay() -> bool:
	if _build_selection_open:
		_close_build_selection()
		return true
	if _log_open:
		close_log_panel()
		return true
	if _shortcut_open:
		_toggle_shortcut_panel()
		return true
	if _storage_open:
		close_storage()
		return true
	if _backpack_open:
		close_backpack()
		return true
	if _fish_process_open:
		close_fish_processing()
		return true
	return false

func _on_storage_open_requested() -> void:
	if _build_selection_open:
		_close_build_selection()
	_close_standard_overlays()
	_storage_open = true
	_open_pause_overlay("storage")
	refresh()

func _on_fish_processing_requested(_fish_key: String) -> void:
	if _build_selection_open:
		_close_build_selection()
	# A catch is already in the backpack. Open that view first so the player
	# can inspect the fish slot and choose whether to process it.
	_close_standard_overlays()
	_backpack_open = true
	_open_pause_overlay("backpack")
	refresh()

func _open_fish_processing_from_backpack() -> void:
	_backpack_open = false
	_close_pause_overlay("backpack")
	_fish_process_open = true
	_open_pause_overlay("fish_process")
	refresh()

func close_fish_processing() -> void:
	_fish_process_open = false
	_close_pause_overlay("fish_process")
	refresh()

func _refresh_backpack_panel() -> void:
	if backpack_content_label == null or game == null or game.resources == null:
		return
	var resources = game.resources
	var capacity := int(resources.backpack_capacity)
	var slots_used := int(resources.backpack_slots_used()) if resources.has_method("backpack_slots_used") else 0
	var carried := int(resources.carried_count()) if resources.has_method("carried_count") else 0
	backpack_content_label.text = "格子 %d/%d · 物品 %d · 每格上限 %d" % [slots_used, capacity, carried, ResourceManager.STACK_MAX]
	# Keep occupied item types packed into the visible slots. This prevents a
	# fish caught before the backpack upgrade from being hidden in a locked slot.
	var keys: Array[String] = []
	for key in ResourceManager.ITEM_KEYS:
		if int(resources.backpack.get(str(key), 0)) > 0: keys.append(str(key))
	for key in ResourceManager.ITEM_KEYS:
		if str(key) not in keys: keys.append(str(key))
	for index in range(backpack_slots.size()):
		var slot: Dictionary = backpack_slots[index]
		var cell: Panel = slot.get("cell")
		var item_label: Label = slot.get("item")
		var count_label: Label = slot.get("count")
		var item_icon: TextureRect = slot.get("icon")
		var unlocked := index < capacity
		var key := keys[index] if index < keys.size() else ""
		var amount := int(resources.backpack.get(key, 0)) if unlocked and not key.is_empty() else 0
		slot["key"] = key
		backpack_slots[index] = slot
		if item_label != null:
			item_label.text = resources.display_name(key) if amount > 0 else ("空" if unlocked else "锁定")
			item_label.add_theme_color_override("font_color", TEXT_MAIN if unlocked else TEXT_MUTED)
		if count_label != null:
			count_label.text = str(amount) if amount > 0 else ""
		if item_icon != null:
			item_icon.texture = _item_icon_texture(key) if amount > 0 else ICON_CHEST
			item_icon.modulate = _item_icon_tint(key)
			item_icon.visible = amount > 0
		var use_button: Button = slot.get("use")
		if use_button != null:
			use_button.visible = amount > 0 and _is_usable_item(key)
			use_button.disabled = not use_button.visible
		if cell != null:
			var style := _button_style(Color("203638", 0.96) if unlocked else Color("101b1d", 0.96), UI_PANEL_TEXTURE)
			cell.add_theme_stylebox_override("panel", style)
	if backpack_craft_button != null:
		var owned := resources.has_method("has_backpack") and resources.has_backpack()
		backpack_craft_button.text = "已制作" if owned else "制作背包"
		backpack_craft_button.disabled = owned or not resources.can_afford(ResourceManager.BACKPACK_COST)
	if backpack_process_fish_button != null:
		var has_fish := false
		for fish_key in ResourceManager.FISH_KEYS:
			if int(resources.backpack.get(str(fish_key), 0)) > 0:
				has_fish = true
				break
		backpack_process_fish_button.visible = has_fish
		backpack_process_fish_button.disabled = not has_fish
	if backpack_cook_berries_button != null:
		var has_berries := int(resources.backpack.get("food", 0)) > 0
		backpack_cook_berries_button.visible = true
		backpack_cook_berries_button.disabled = not has_berries

func _refresh_fish_process_panel() -> void:
	if fish_process_panel == null or game == null or game.resources == null: return
	var resources = game.resources
	for key in fish_process_rows:
		var row: Dictionary = fish_process_rows[key]
		var amount := int(resources.backpack.get(str(key), 0))
		var label: Label = row.get("label")
		var process: Button = row.get("process")
		if label != null: label.text = "%s  ×%d  → %s" % [resources.display_name(str(key)), amount, resources.cooked_fish_name(str(key))]
		if process != null:
			process.disabled = amount <= 0
			process.text = "烤熟" if amount <= 0 else "烤熟 1 条"

func _process_fish(key: String) -> void:
	if game == null or game.resources == null: return
	var result: Dictionary = game.resources.cook_fish(key)
	_show_message(str(result.get("reason", "")), 2.0)
	refresh()

func craft_backpack() -> void:
	if game == null or game.resources == null or not game.resources.has_method("craft_backpack"):
		_show_message("背包制作系统未就绪", 2.0)
		return
	var result: Dictionary = game.resources.craft_backpack()
	_show_message(str(result.get("reason", "")), 2.5)
	refresh()

func _craft_recipe(recipe_id: String) -> void:
	if game == null: return
	var result: Dictionary = game.craft_item(recipe_id)
	_show_message(str(result.get("reason", "制作失败")), 2.5)
	refresh()

func _refresh_storage_panel() -> void:
	if storage_panel == null or game == null or game.resources == null:
		return
	var resources = game.resources
	var carried := int(resources.carried_count()) if resources.has_method("carried_count") else 0
	var capacity := int(resources.backpack_capacity)
	var slots_used := int(resources.backpack_slots_used()) if resources.has_method("backpack_slots_used") else 0
	storage_capacity_label.text = "背包格子 %d/%d · 物品 %d · 取出后可携带" % [slots_used, capacity, carried]
	for key in storage_rows:
		var row: Dictionary = storage_rows[key]
		var stored := int(resources.storage.get(key, 0))
		var carried_amount := int(resources.backpack.get(key, 0))
		var label: Label = row.get("label")
		if label != null:
			label.text = "%s  架上 %d  背包 %d" % [resources.display_name(str(key)), stored, carried_amount]
		var take: Button = row.get("take")
		var put: Button = row.get("put")
		var discard: Button = row.get("discard")
		if take != null: take.disabled = stored <= 0 or not resources.can_carry_item(str(key), 1)
		if put != null: put.disabled = carried_amount <= 0
		if discard != null: discard.disabled = stored <= 0

func _storage_take(key: String) -> void:
	var result: Dictionary = game.resources.move_to_backpack(str(key), 1)
	_show_message(str(result.get("reason", "")), 1.5)
	refresh()

func _storage_put(key: String) -> void:
	var result: Dictionary = game.resources.move_to_storage(str(key), 1)
	_show_message(str(result.get("reason", "")), 1.5)
	refresh()

func _storage_discard(key: String) -> void:
	var result: Dictionary = game.resources.discard_from_storage(str(key), 1)
	_show_message(str(result.get("reason", "")), 1.5)
	refresh()

func _update_target(hero: Survivor) -> void:
	if objective_live_label == null and objective_reward_label == null:
		return
	var goal_text := _director_goal_text()
	var text := goal_text
	if text.is_empty():
		text = "探索荒野，带回物资"
	if _build_selection_open:
		text = "选择工具或设施"
	elif world != null and world.build_mode != null and world.build_mode.active:
		text = "放置设施 · E 确认"
	elif world != null and world.nearest != null:
		var point = world.nearest
		text = str(point.display_name)
		if point.cooldown_remaining > 0.0:
			text += " · 冷却 %.0fs" % point.cooldown_remaining
		if not goal_text.is_empty():
			text += "\n" + goal_text
	elif bool(game.in_house):
		text = "屋内休整 · 找到床铺"
	elif _is_paused():
		text = "游戏暂停 · 选择操作"
	if hero != null and not hero.alive:
		text = "阿禾已倒下 · 尽快结束今天"
	var target_lines := text.split("\n")
	if objective_live_label != null:
		objective_live_label.text = _ellipsize(str(target_lines[0]) if not target_lines.is_empty() else "", 10)
	if objective_reward_label != null:
		var reward_text := _goal_reward_text()
		objective_reward_label.text = _ellipsize(reward_text if not reward_text.is_empty() else (str(target_lines[1]) if target_lines.size() > 1 else "准备出发"), 12)

func _update_log() -> void:
	if game == null:
		return
	var latest := ""
	if game.daily_log is Array and not game.daily_log.is_empty():
		latest = str(game.daily_log[game.daily_log.size() - 1])
	if objective_log_label != null:
		objective_log_label.text = _ellipsize(latest, 17)
	if feedback_panel != null:
		feedback_panel.visible = message_label != null and message_label.text != ""

func _refresh_log_panel() -> void:
	if log_content_label == null or game == null:
		return
	var lines: Array[String] = []
	for line_variant in game.daily_log:
		lines.append(str(line_variant))
	var start := maxi(0, lines.size() - 12)
	var visible_lines := lines.slice(start)
	log_content_label.text = "\n".join(visible_lines) if not visible_lines.is_empty() else "暂无日志"

func _update_survivor_card(hero: Survivor) -> void:
	if survivor_name_label == null:
		return
	if hero == null:
		survivor_name_label.text = "无人"
		survivor_status_label.text = "离队"
	else:
		survivor_name_label.text = str(hero.display_name)
		var status := hero.status_text() if hero.has_method("status_text") else "正常"
		survivor_status_label.text = "Lv.%d %s" % [int(hero.skill_value("build")) if hero.has_method("skill_value") else 1, status]
	for key in ["health", "hunger", "energy", "morale"]:
		var value := _stat_value(hero, key) if hero != null else 0
		var row: Dictionary = _survivor_meter_bars.get(key, {})
		var bar: ProgressBar = row.get("bar")
		var value_label: Label = row.get("value")
		if bar != null:
			bar.value = value
			var tint: Color = row.get("color", Color("70a9a0"))
			if value <= 25: tint = Color("c86c67")
			elif value <= 50: tint = Color("d4a45e")
			_set_progress_fill(bar, tint)
		if value_label != null:
			value_label.text = str(value)

func _update_build_prompt() -> void:
	if prompt_label == null or world == null or world.build_mode == null:
		return
	prompt_label.text = "建造模式  ·  Q 切换  ·  E 放置  ·  Esc 退出"
	_last_prompt = prompt_label.text
	_set_prompt_visible(true)
	if message_label != null:
		var defs: Dictionary = game.blueprints.definitions if game != null and game.blueprints != null else {}
		var selected := str(world.build_mode.selected_blueprint)
		if defs.has(selected):
			var definition: Dictionary = defs[selected]
			message_label.text = "%s  %s  %.1fs" % [str(definition.get("name", "设施")), _cost_text(definition.get("cost", {})), float(definition.get("build_time", 0.0))]
			message_until = 0.0

func _on_interaction_hint(prompt: String) -> void:
	_last_prompt = prompt
	if prompt_label != null:
		prompt_label.text = prompt
	_set_prompt_visible(prompt != "")
	if prompt.contains("睡觉"):
		_show_message("准备休息：夜间会消耗食物，注意保持身体温度。", 4.0)
	if prompt == "":
		_on_interaction_progress("", 0.0)
	_update_target(game.get_protagonist() if game != null else null)

func _on_interaction_result(message: String) -> void:
	_show_message(message, 3.0)
	refresh()

func _on_interaction_progress(name: String, progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	if interaction_name_label != null:
		interaction_name_label.text = name
	if interaction_progress_bar != null:
		interaction_progress_bar.value = clamped
	var panel := interaction_progress_bar.get_parent() if interaction_progress_bar != null else null
	if panel != null:
		panel.visible = not name.is_empty() and clamped >= 0.0 and clamped < 1.0
	if interaction_detail_label != null:
		interaction_detail_label.text = "动作进行中" if clamped > 0.0 and clamped < 1.0 else ""

func toggle_pause_menu() -> void:
	if game == null or game.time == null:
		return
	if _build_selection_open:
		_close_build_selection()
	paused_by_menu = not paused_by_menu
	game.time.paused = paused_by_menu
	if game.audio != null and game.audio.has_method("set_pause_ducked"):
		game.audio.set_pause_ducked(paused_by_menu)
	refresh()

func _on_resume() -> void:
	if game == null or game.time == null:
		paused_by_menu = false
		return
	paused_by_menu = false
	game.time.paused = false
	if game.audio != null and game.audio.has_method("set_pause_ducked"):
		game.audio.set_pause_ducked(false)
	refresh()

func exit_game() -> void:
	# Release the pause state before leaving so a future embedded/restarted run
	# cannot inherit a frozen simulation from this scene tree.
	if game != null and game.time != null:
		game.time.paused = false
	get_tree().quit()

func save_game() -> void:
	if game == null or not game.has_method("save_state"):
		_show_message("保存不可用", 3.0)
		return
	var ok: bool = bool(game.save_state())
	if ok and game.audio != null and game.audio.has_method("play_sfx"):
		game.audio.play_sfx("save_success")
	_show_message("游戏已保存" if ok else "保存失败", 3.0)
	refresh()

func load_game() -> void:
	if game == null or not game.has_method("load_state"):
		_show_message("读取不可用", 3.0)
		return
	var ok: bool = bool(game.load_state())
	if ok and game.audio != null and game.audio.has_method("play_sfx"):
		game.audio.play_sfx("load_success")
	_show_message("存档已读取" if ok else "没有找到存档", 3.0)
	paused_by_menu = false
	if game.time != null:
		game.time.paused = false
	if game.audio != null and game.audio.has_method("set_pause_ducked"):
		game.audio.set_pause_ducked(false)
	refresh()

func upgrade_house() -> void:
	if game == null or not game.has_method("upgrade_house"):
		_show_message("升级不可用", 3.0)
		return
	var result: Dictionary = game.upgrade_house()
	_show_message(str(result.get("reason", "")), 3.0)
	refresh()

func toggle_build_mode() -> void:
	if world == null or world.build_mode == null:
		_show_message("建造系统未就绪", 3.0)
		return
	if game == null or bool(game.in_house):
		_show_message("请先离开小屋", 3.0)
		return
	if str(game.phase) != GameManager.PHASE_MORNING and not world.build_mode.active:
		_show_message("只能在清晨规划建造", 3.0)
		return
	if _build_selection_open:
		_close_build_selection()
		return
	if world.build_mode.active:
		world.build_mode.toggle()
		_last_prompt = ""
		_set_prompt_visible(false)
		message_until = 0.0
		if message_label != null:
			message_label.text = ""
	else:
		_open_build_selection()
	if world.build_mode.active:
		_update_build_prompt()
	refresh()

func _cook_berries() -> void:
	if game == null or game.resources == null: return
	var result: Dictionary = game.resources.cook_berries()
	_show_message(str(result.get("reason", "")), 2.0)
	refresh()

func _use_backpack_slot(index: int) -> void:
	if game == null or index < 0 or index >= backpack_slots.size(): return
	var key := str(backpack_slots[index].get("key", ""))
	if key.is_empty(): return
	var result: Dictionary = game.use_item(key)
	_show_message(str(result.get("reason", "")), 2.5)
	refresh()

func _is_usable_item(key: String) -> bool:
	return key in ["food", "medicine", "cooked_food", "bandage", "torch", "trap"] or ResourceManager.FISH_KEYS.has(key) or ResourceManager.COOKED_FISH_KEYS.has(key)

func _on_tool_selection_requested() -> void:
	_close_standard_overlays()
	_open_build_selection()

func cycle_policy() -> void:
	if game == null or not game.has_method("set_camp_policy"):
		_show_message("营地政策系统未就绪", 2.0)
		return
	if not _policy_available():
		_show_message("政策只能在每天出发时调整", 2.0)
		return
	var options: Array[Dictionary] = game.survival.get_policy_options()
	if options.is_empty():
		_show_message("当前没有可用政策", 2.0)
		return
	var status_variant: Variant = game.get_survival_status() if game.has_method("get_survival_status") else {}
	var current_id := "balanced"
	if status_variant is Dictionary:
		var policy_variant: Variant = status_variant.get("policy", {})
		if policy_variant is Dictionary:
			current_id = str(policy_variant.get("id", current_id))
	var next_index := 0
	for index in range(options.size()):
		var option: Dictionary = options[index]
		if str(option.get("id", "")) == current_id:
			next_index = (index + 1) % options.size()
			break
	var next_option: Dictionary = options[next_index]
	var result: Dictionary = game.set_camp_policy(str(next_option.get("id", current_id)))
	_show_message(str(result.get("reason", "政策未改变")), 2.5)
	refresh()

func _policy_available() -> bool:
	if game == null or game.in_house:
		return false
	if str(game.phase) == "morning":
		return true
	return bool(game.exploration_mode) and str(game.phase) == "day"

func _on_interact_pressed() -> void:
	if world == null or not world.has_method("try_interact"):
		_show_message("交互系统未就绪", 2.0)
		return
	world.try_interact()

func _show_message(text: String, duration: float = 3.0) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_until = Time.get_ticks_msec() / 1000.0 + maxf(0.1, duration)

func _set_prompt_visible(visible: bool) -> void:
	if prompt_label == null:
		return
	var panel := prompt_label.get_parent()
	if panel != null:
		panel.visible = visible
	if interact_button != null:
		interact_button.visible = not _build_selection_open and (visible or (world != null and world.nearest != null))

func _is_paused() -> bool:
	return game != null and game.time != null and bool(game.time.paused)

func _clock_text() -> String:
	if game == null or game.time == null:
		return "--:--"
	if game.time.has_method("clock_text"):
		return str(game.time.clock_text())
	return "--:--"

func _weather_text(weather: String) -> String:
	var marker: String = str({
		"晴朗": "晴",
		"多云": "云",
		"浓雾": "雾",
		"暴雨": "雨",
		"寒冷": "冷"
	}.get(weather, weather))
	return marker

func _threat_text() -> String:
	if game != null:
		var status: Dictionary = game.get_survival_status()
		var label := str(status.get("threat_label", ""))
		if not label.is_empty():
			return "威胁·" + label
		var safety := clampi(int(status.get("safety", game.safety)), 0, 100)
		return "威胁 %d" % (100 - safety)
	return "威胁 --"

func _director_goal_text() -> String:
	if game == null:
		return ""
	var summary: Dictionary = game.get_daily_goal()
	var label := str(summary.get("label", summary.get("name", "")))
	return _goal_progress_text(label, summary) if not label.is_empty() else ""

func _goal_reward_text() -> String:
	if game == null or not game.has_method("get_daily_goal"):
		return ""
	var goal_variant: Variant = game.get_daily_goal()
	if not goal_variant is Dictionary:
		return ""
	var reward_variant: Variant = goal_variant.get("reward", {})
	if not reward_variant is Dictionary or reward_variant.is_empty():
		return ""
	var parts: Array[String] = []
	for key in reward_variant:
		var amount := int(reward_variant[key])
		if amount <= 0:
			continue
		var label := game.resources.display_name(str(key)) if game.resources != null and game.resources.has_method("display_name") else str(key)
		parts.append("%s+%d" % [label, amount])
	return "奖励 " + ",".join(parts)

func _goal_progress_text(label: String, goal: Dictionary) -> String:
	var progress := int(goal.get("progress", 0))
	var target := int(goal.get("target", 0))
	if target > 0:
		return _ellipsize("%s %d/%d" % [label, progress, target], 17)
	return _ellipsize(label, 17)

func _stat_value(hero: Survivor, key: String) -> int:
	if hero == null:
		return 0
	return clampi(int(hero.get(key)), 0, 100)

func _item_icon_texture(key: String) -> Texture2D:
	return Assets.resource_icon(key)

func _item_icon_tint(key: String) -> Color:
	match key:
		"fish_carp", "fish_bass", "fish_trout", "fish_eel":
			return Color("70a9c4")
		"wood":
			return Color("9ec479")
		"stone":
			return Color("aebfb4")
	return TEXT_MAIN

func _resource_amount(resources, key: String) -> int:
	if resources == null or not resources.has_method("get_amount"):
		return 0
	return int(resources.get_amount(key))

func _resource_capacity(resources, key: String) -> int:
	if resources == null:
		return 0
	return int(resources.capacities.get(key, 0))

func _ellipsize(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.left(maxi(1, max_chars - 1)) + "…"

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if game == null or game.resources == null:
		return ""
	for key in cost:
		var name := game.resources.display_name(str(key)) if game.resources.has_method("display_name") else str(key)
		parts.append("%s%d" % [name, int(cost[key])])
	return "/".join(parts)

func _progress_bar(pos: Vector2, dimensions: Vector2, parent: Control, fill_color: Color = Color("70a9a0")) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = dimensions
	bar.custom_minimum_size = Vector2.ZERO
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _bar_style(Color("101b1d", 0.94), PixelTheme.BAR_TEXTURE)
	var fill := _bar_style(Color.WHITE, PixelTheme.meter_texture(fill_color))
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _set_progress_fill(bar: ProgressBar, color: Color) -> void:
	var fill := _bar_style(Color.WHITE, PixelTheme.meter_texture(color))
	bar.add_theme_stylebox_override("fill", fill)

func _bar_style(tint: Color, texture: Texture2D) -> StyleBoxTexture:
	return PixelTheme.bar_style(tint, texture)

func _icon(pos: Vector2, dimensions: Vector2, texture: Texture2D, parent: Control = null) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = pos
	icon.size = dimensions
	icon.scale = Vector2.ONE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target_parent: Control = parent if parent != null else hud
	if target_parent != null:
		target_parent.add_child(icon)
	return icon

func _add_button_icon(button: Button, texture: Texture2D) -> TextureRect:
	# Icons stay at an integer 16px destination inside every button.
	var icon_size := 16
	var icon := TextureRect.new()
	icon.position = Vector2(floor((button.size.x - icon_size) * 0.5), 6)
	icon.size = Vector2(icon_size, icon_size)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return icon

func _label(pos: Vector2, dimensions: Vector2, text: String, font_size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.scale = Vector2.ONE
	label.text = text
	var resolved_font_size := PixelTheme.FONT_SIZE_BODY
	if font_size >= 9:
		resolved_font_size = PixelTheme.FONT_SIZE_TITLE
	elif font_size <= 3:
		resolved_font_size = PixelTheme.FONT_SIZE_SMALL
	label.add_theme_font_size_override("font_size", resolved_font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("081516", 0.86))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target_parent: Control = parent if parent != null else hud
	if target_parent != null:
		target_parent.add_child(label)
	return label

func _label_in(parent: Control, pos: Vector2, dimensions: Vector2, text: String, font_size: int, color: Color) -> Label:
	return _label(pos, dimensions, text, font_size, color, parent)

func _button(pos: Vector2, dimensions: Vector2, text: String, parent: Control) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = dimensions
	button.scale = Vector2.ONE
	button.text = text
	button.add_theme_font_size_override("font_size", PixelTheme.FONT_SIZE_BODY)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("687a76"))
	button.add_theme_color_override("font_outline_color", Color("081516", 0.92))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", _button_style(Color("1c3032"), UI_PANEL_TEXTURE))
	button.add_theme_stylebox_override("hover", _button_style(Color("2c4a49"), UI_PANEL_LIGHT_TEXTURE))
	button.add_theme_stylebox_override("pressed", _button_style(Color("152527"), UI_PANEL_PRESSED_TEXTURE))
	button.add_theme_stylebox_override("disabled", _button_style(Color("182325", 0.8), UI_DISABLED_TEXTURE))
	button.add_theme_stylebox_override("focus", _button_style(Color("3a534d"), UI_PANEL_LIGHT_TEXTURE))
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button

func _button_in(parent: Control, pos: Vector2, dimensions: Vector2, text: String) -> Button:
	var button := _button(pos, dimensions, text, parent)
	button.add_theme_font_size_override("font_size", PixelTheme.FONT_SIZE_BODY)
	return button

func _button_style(tint: Color, texture: Texture2D = UI_PANEL_TEXTURE) -> StyleBoxTexture:
	return PixelTheme.button_style(tint, texture)

func _panel(pos: Vector2, dimensions: Vector2, color: Color, parent: Control = null) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := UI_PANEL_LIGHT_TEXTURE if color == PANEL_LIGHT else UI_PANEL_TEXTURE
	var style := PixelTheme.panel_style(color, texture)
	panel.add_theme_stylebox_override("panel", style)
	(parent if parent != null else hud).add_child(panel)
	return panel

