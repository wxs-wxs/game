class_name PixelUITheme
extends RefCounted

## Shared visual system for every native Godot HUD control.
## Authoring and runtime geometry both use the 960x540 logical viewport.

const FONT := preload("res://assets/fonts/fusion_pixel/fusion-pixel-10px-monospaced-zh_hans.ttf")
const PANEL_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/space.png")
const PANEL_INLAY_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/space_inlay.png")
const DISABLED_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Ancient/grey.png")
const BAR_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Ancient/grey.png")
const BAR_FILL_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Colored/green.png")
const BAR_RED_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Colored/red.png")
const BAR_YELLOW_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Colored/yellow.png")
const BAR_BLUE_TEXTURE := preload("res://assets/art/open_ui/kenney_pixel_ui/9-Slice/Colored/blue.png")
const NINE_SLICE_MARGIN := 2.0

const PANEL_DARK := Color("101b1d", 0.95)
const PANEL_MID := Color("18282a", 0.98)
const PANEL_LIGHT := Color("2b4140", 0.98)
const TEXT_MAIN := Color("f3f1d6")
const TEXT_MUTED := Color("b6c6b5")
const TEXT_ACCENT := Color("f2ca72")
const TEXT_WARN := Color("e58b6a")
const TEXT_WATER := Color("7eb8b8")

# Compact pixel type keeps the permanent HUD subordinate to the world at the
# 2x 1920x1080 output while preserving the same imported font family.
const FONT_SIZE_SMALL := 9
const FONT_SIZE_BODY := 11
const FONT_SIZE_TITLE := 18

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = FONT_SIZE_BODY
	return theme

static func panel_style(tint: Color = PANEL_DARK, texture: Texture2D = PANEL_TEXTURE) -> StyleBoxTexture:
	return texture_style(texture, panel_tint(tint), NINE_SLICE_MARGIN, 12.0)

static func button_style(tint: Color, texture: Texture2D = PANEL_TEXTURE) -> StyleBoxTexture:
	# Buttons use a tighter content inset than panels so compact two-line action
	# controls can stay on the same integer grid without inflating their minimum
	# size around the text.
	return texture_style(texture, panel_tint(tint), NINE_SLICE_MARGIN, 4.0)

static func texture_style(texture: Texture2D, tint: Color, margin: float, padding: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = tint
	return style

static func bar_style(tint: Color, texture: Texture2D = BAR_TEXTURE) -> StyleBoxTexture:
	# Progress meters use the same nine-slice family as panels and buttons.
	var style := texture_style(texture, Color.WHITE, NINE_SLICE_MARGIN, 0.0)
	style.modulate_color = tint
	return style

static func meter_texture(color: Color) -> Texture2D:
	if color.r > color.b * 1.20 and color.g > color.r * 0.65:
		return BAR_YELLOW_TEXTURE
	if color.r > color.g * 1.10 and color.r > color.b * 1.10:
		return BAR_RED_TEXTURE
	if color.b > color.r * 1.10:
		return BAR_BLUE_TEXTURE
	return BAR_FILL_TEXTURE

static func panel_tint(color: Color) -> Color:
	return Color(
		clampf(0.20 + color.r * 0.58, 0.0, 1.0),
		clampf(0.28 + color.g * 0.66, 0.0, 1.0),
		clampf(0.28 + color.b * 0.62, 0.0, 1.0),
		color.a
	)
