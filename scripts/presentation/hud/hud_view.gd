class_name HudView
extends RefCounted

## Persistent exploration HUD. It only consumes immutable presentation snapshots.

const UiFactory := preload("res://scripts/presentation/theme/ui_factory.gd")
const PixelTheme := preload("res://scripts/pixel_ui_theme.gd")
const Assets := preload("res://scripts/ninja_adventure_assets.gd")
const ICON_PLAYER := preload("res://assets/player_character_sheet.png")

const RESOURCE_KEYS := ["food", "wood", "medicine", "stone", "fiber", "cloth", "metal"]
const RESOURCE_ICON_TINTS := [Color("f2ca72"), Color("9dc77c"), Color("e58b6a"), Color("b6c6b5"), Color("7eb8b8"), Color("d8bb77"), Color("f2ca72")]
const TOP_LEFT_CHIP_POSITION := Vector2(12, 12)
const TOP_LEFT_CHIP_SIZE := Vector2(210, 30)
const RESOURCE_CHIP_POSITION := Vector2(702, 12)
const RESOURCE_CHIP_SIZE := Vector2(246, 42)

var factory: UiFactory
var root: Control
var day_label: Label
var clock_icon_label: Label
var clock_label: Label
var weather_icon_label: Label
var weather_label: Label
var temperature_label: Label
var survivor_panel: Panel
var survivor_name_label: Label
var survivor_status_label: Label
var survivor_avatar_sprite: TextureRect
var objective_panel: Panel
var objective_live_label: Label
var objective_reward_label: Label
var objective_log_label: Label
var objective_log_button: Button
var objective_shortcut_button: Button
var prompt_panel: Panel
var prompt_label: Label
var interact_button: Button
var feedback_panel: Panel
var message_label: Label
var interaction_panel: Panel
var interaction_name_label: Label
var interaction_progress_bar: ProgressBar
var shortcut_button: Button
var resource_badges: Array[Label] = []
var resource_icons: Array[TextureRect] = []
var survivor_meter_bars: Dictionary = {}

func setup(parent: Control, factory_argument: Object) -> void:
	root = parent
	factory = factory_argument as UiFactory
	if factory == null:
		factory = UiFactory.new()
		factory.setup(null)
	if root == null:
		return
	_build()

## Compatibility binding used while UIController's legacy constructor remains.
## New callers should use setup() so the view owns construction.
func bind_existing(parent: Control, refs: Dictionary) -> void:
	root = parent
	day_label = refs.get("day_label")
	clock_icon_label = refs.get("clock_icon_label")
	clock_label = refs.get("clock_label")
	weather_icon_label = refs.get("weather_icon_label")
	weather_label = refs.get("weather_label")
	temperature_label = refs.get("temperature_label")
	survivor_panel = refs.get("survivor_panel")
	survivor_name_label = refs.get("survivor_name_label")
	survivor_status_label = refs.get("survivor_status_label")
	survivor_avatar_sprite = refs.get("survivor_avatar_sprite")
	objective_panel = refs.get("objective_panel")
	objective_live_label = refs.get("objective_live_label")
	objective_reward_label = refs.get("objective_reward_label")
	objective_log_label = refs.get("objective_log_label")
	prompt_panel = refs.get("prompt_panel")
	prompt_label = refs.get("prompt_label")
	interact_button = refs.get("interact_button")
	feedback_panel = refs.get("feedback_panel")
	message_label = refs.get("message_label")
	interaction_panel = refs.get("interaction_panel")
	interaction_name_label = refs.get("interaction_name_label")
	interaction_progress_bar = refs.get("interaction_progress_bar")
	resource_badges = refs.get("resource_badges", [])
	resource_icons = refs.get("resource_icons", [])
	survivor_meter_bars = refs.get("survivor_meter_bars", {})
	shortcut_button = refs.get("shortcut_button")

func required_snapshot_keys() -> Array[String]:
	return ["day", "clock", "weather", "temperature", "resources", "survivor", "objective", "log", "interaction"]

func refresh(snapshot: Dictionary) -> void:
	if root == null:
		return
	var resources: Dictionary = snapshot.get("resources", {})
	var resource_chip := root.get_node_or_null("ResourceChip") as Panel
	if resource_chip != null: resource_chip.clip_contents = true
	for index in range(mini(resource_badges.size(), RESOURCE_KEYS.size())):
		var key: String = str(RESOURCE_KEYS[index])
		var data: Dictionary = resources.get(key, {}) if resources.get(key, {}) is Dictionary else {}
		var amount := int(data.get("amount", resources.get(key, 0)))
		var capacity := int(data.get("capacity", 0))
		var label := str(data.get("name", key))
		var tooltip := "%s：%d / %d" % [label, amount, capacity]
		resource_badges[index].text = str(amount)
		resource_badges[index].tooltip_text = tooltip
		resource_icons[index].tooltip_text = tooltip
	day_label.text = str(snapshot.get("day", ""))
	clock_label.text = str(snapshot.get("clock", ""))
	weather_label.text = str(snapshot.get("weather", ""))
	var temperature_value: Variant = snapshot.get("temperature", {})
	var temperature: Dictionary = temperature_value if temperature_value is Dictionary else {}
	temperature_label.text = str(temperature.get("text", temperature_value))
	temperature_label.tooltip_text = str(temperature.get("tooltip", ""))
	var survivor: Dictionary = snapshot.get("survivor", {})
	if survivor_panel != null: survivor_panel.clip_contents = true
	survivor_name_label.text = str(survivor.get("name", "无人"))
	survivor_status_label.text = str(survivor.get("status", "离队"))
	for key in ["health", "hunger", "energy", "morale"]:
		var row: Dictionary = survivor_meter_bars.get(key, {})
		var value := clampi(int(survivor.get(key, 0)), 0, 100)
		var bar: ProgressBar = row.get("bar")
		if bar != null:
			bar.value = value
			var tint: Color = row.get("color", Color("70a9a0"))
			if value <= 25:
				tint = Color("c86c67")
			elif value <= 50:
				tint = Color("d4a45e")
			factory.set_progress_fill(bar, tint)
		var value_label: Label = row.get("value")
		if value_label != null:
			value_label.text = str(value)
	var objective: Dictionary = snapshot.get("objective", {})
	if objective_panel != null: objective_panel.clip_contents = true
	objective_live_label.text = str(objective.get("live", ""))
	objective_reward_label.text = str(objective.get("reward", ""))
	objective_live_label.clip_text = true
	objective_reward_label.clip_text = true
	objective_log_label.clip_text = true
	var lines: Array = snapshot.get("log", [])
	objective_log_label.text = str(lines.back()) if not lines.is_empty() else ""
	var interaction: Dictionary = snapshot.get("interaction", {})
	prompt_label.text = str(interaction.get("prompt", ""))
	prompt_panel.visible = bool(interaction.get("prompt_visible", false))
	interaction_name_label.text = str(interaction.get("name", ""))
	interaction_progress_bar.value = float(interaction.get("progress", 0.0))
	interaction_panel.visible = not interaction_name_label.text.is_empty() and interaction_progress_bar.value < 1.0
	if feedback_panel != null: feedback_panel.visible = message_label != null and message_label.text != ""

func _build() -> void:
	var day_chip := factory.panel(root, TOP_LEFT_CHIP_POSITION, TOP_LEFT_CHIP_SIZE, PixelTheme.PANEL_DARK)
	day_chip.name = "StatusRail"
	day_chip.clip_contents = true
	day_label = factory.label(day_chip, Vector2(8, 6), Vector2(54, 18), "", 3, PixelTheme.TEXT_ACCENT)
	clock_icon_label = factory.label(day_chip, Vector2(70, 6), Vector2(30, 18), "时间", 3, PixelTheme.TEXT_MUTED)
	clock_label = factory.label(day_chip, Vector2(102, 6), Vector2(45, 18), "", 3, PixelTheme.TEXT_MAIN)
	weather_icon_label = factory.label(day_chip, Vector2(153, 6), Vector2(30, 18), "天气", 3, PixelTheme.TEXT_MUTED)
	weather_label = factory.label(day_chip, Vector2(186, 6), Vector2(24, 18), "", 3, PixelTheme.TEXT_WATER)
	var temperature_chip := factory.panel(root, Vector2(240, 12), Vector2(150, 30), PixelTheme.PANEL_DARK)
	temperature_chip.name = "TemperatureChip"
	temperature_label = factory.label(temperature_chip, Vector2(6, 6), Vector2(138, 18), "", 3, PixelTheme.TEXT_WATER)
	temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var resource_chip := factory.panel(root, RESOURCE_CHIP_POSITION, RESOURCE_CHIP_SIZE, PixelTheme.PANEL_DARK)
	resource_chip.name = "ResourceChip"
	resource_chip.clip_contents = true
	for index in range(RESOURCE_KEYS.size()):
		var slot_x := 15 + index * 32
		var badge := factory.label(resource_chip, Vector2(slot_x, 17), Vector2(32, 23), "", 3, RESOURCE_ICON_TINTS[index])
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.name = "ResourceBadge%d" % index
		resource_badges.append(badge)
		var icon := factory.icon(resource_chip, Vector2(slot_x + 8, 1), Vector2(16, 16), Assets.resource_icon(RESOURCE_KEYS[index]))
		icon.name = "ResourceIcon%d" % index
		icon.modulate = Color.WHITE
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		resource_icons.append(icon)
	shortcut_button = factory.button(root, Vector2(12, 57), Vector2(32, 32), "?")
	shortcut_button.name = "ShortcutButton"
	shortcut_button.tooltip_text = "查看快捷键"
	shortcut_button.add_theme_font_size_override("font_size", PixelTheme.FONT_SIZE_TITLE)
	shortcut_button.add_theme_stylebox_override("normal", factory.button_style(Color("122125", 0.94), PixelTheme.PANEL_TEXTURE))
	shortcut_button.add_theme_stylebox_override("hover", factory.button_style(Color("2c4a49", 0.98), PixelTheme.PANEL_TEXTURE))
	shortcut_button.add_theme_stylebox_override("pressed", factory.button_style(Color("152527", 0.98), PixelTheme.PANEL_TEXTURE))
	survivor_panel = factory.panel(root, Vector2(12, 468), Vector2(246, 60), PixelTheme.PANEL_DARK)
	survivor_panel.name = "SurvivorCard"
	var avatar_frame := factory.panel(survivor_panel, Vector2(12, 6), Vector2(36, 48), PixelTheme.PANEL_LIGHT)
	avatar_frame.name = "AvatarFrame"
	var avatar_texture := AtlasTexture.new()
	avatar_texture.atlas = ICON_PLAYER
	avatar_texture.region = Rect2(0, 0, 48, 72)
	survivor_avatar_sprite = factory.icon(avatar_frame, Vector2(6, 6), Vector2(24, 36), avatar_texture)
	survivor_avatar_sprite.name = "AvatarSprite"
	survivor_name_label = factory.label(survivor_panel, Vector2(54, 4), Vector2(84, 15), "阿禾", 4, PixelTheme.TEXT_ACCENT)
	survivor_status_label = factory.label(survivor_panel, Vector2(144, 4), Vector2(90, 15), "Lv.1", 3, PixelTheme.TEXT_MUTED)
	survivor_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rows := [["生命", "health", Color("d47768")], ["饱腹", "hunger", Color("d5a45d")], ["体力", "energy", Color("70a9a0")], ["士气", "morale", Color("b995c4")]]
	for index in range(rows.size()):
		var row: Array = rows[index]
		var x := 54 + (index % 2) * 90
		var y := 23 + (index / 2) * 16
		factory.label(survivor_panel, Vector2(x, y), Vector2(18, 12), str(row[0]), 3, PixelTheme.TEXT_MUTED)
		var bar := factory.progress_bar(survivor_panel, Vector2(x + 21, y + 3), Vector2(45, 6), row[2])
		var value := factory.label(survivor_panel, Vector2(x + 69, y), Vector2(21, 12), "0", 3, PixelTheme.TEXT_MAIN)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		survivor_meter_bars[str(row[1])] = {"bar": bar, "value": value, "color": row[2]}
	objective_panel = factory.panel(root, Vector2(702, 468), Vector2(246, 60), PixelTheme.PANEL_DARK)
	objective_panel.name = "ObjectiveCard"
	objective_panel.clip_contents = true
	factory.label(objective_panel, Vector2(12, 5), Vector2(72, 14), "当前目标", 4, PixelTheme.TEXT_MUTED)
	objective_live_label = factory.label(objective_panel, Vector2(90, 5), Vector2(144, 14), "", 3, PixelTheme.TEXT_ACCENT)
	objective_live_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_live_label.clip_text = true
	objective_reward_label = factory.label(objective_panel, Vector2(12, 24), Vector2(222, 13), "", 3, PixelTheme.TEXT_MUTED)
	objective_reward_label.clip_text = true
	objective_log_label = factory.label(objective_panel, Vector2(12, 40), Vector2(222, 14), "", 3, PixelTheme.TEXT_MAIN)
	objective_log_label.clip_text = true
	objective_log_button = factory.button(objective_panel, Vector2.ZERO, Vector2.ZERO, "日志")
	objective_log_button.visible = false
	objective_log_button.name = "ObjectiveLogButton"
	objective_log_button.tooltip_text = "查看最近日志"
	objective_shortcut_button = factory.button(objective_panel, Vector2.ZERO, Vector2.ZERO, "快捷")
	objective_shortcut_button.visible = false
	objective_shortcut_button.name = "ObjectiveShortcutButton"
	objective_shortcut_button.tooltip_text = "查看快捷键"
	prompt_panel = factory.panel(root, Vector2(300, 432), Vector2(360, 26), PixelTheme.PANEL_DARK)
	prompt_panel.name = "PromptPanel"
	prompt_label = factory.label(prompt_panel, Vector2(9, 4), Vector2(210, 18), "", 3, PixelTheme.TEXT_ACCENT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_button = factory.button(prompt_panel, Vector2(228, 4), Vector2(123, 18), "互动 E")
	interact_button.tooltip_text = "执行附近交互（E）"
	interact_button.visible = false
	prompt_panel.visible = false
	feedback_panel = factory.panel(root, Vector2(240, 390), Vector2(480, 28), PixelTheme.PANEL_DARK)
	feedback_panel.name = "FeedbackToast"
	message_label = factory.label(feedback_panel, Vector2(12, 5), Vector2(456, 18), "", 6, PixelTheme.TEXT_MAIN)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.clip_text = true
	feedback_panel.visible = false
	interaction_panel = factory.panel(root, Vector2(390, 407), Vector2(180, 18), PixelTheme.PANEL_DARK)
	interaction_panel.name = "InteractionPanel"
	interaction_name_label = factory.label(interaction_panel, Vector2(6, 2), Vector2(42, 14), "", 3, PixelTheme.TEXT_ACCENT)
	interaction_name_label.clip_text = true
	interaction_progress_bar = factory.progress_bar(interaction_panel, Vector2(48, 6), Vector2(126, 6))
	interaction_progress_bar.max_value = 1.0
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.visible = false
