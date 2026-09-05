class_name UiFactory
extends RefCounted

## Native pixel-control construction shared by the presentation views.
## Geometry is authored directly in the 960x540 logical viewport.

const PixelUITheme := preload("res://scripts/pixel_ui_theme.gd")

var theme: Theme

func setup(theme_resource: Theme = null) -> void:
	theme = PixelUITheme.create_theme() if theme_resource == null else theme_resource
	if theme == null:
		theme = PixelUITheme.create_theme()
	theme.default_font = PixelUITheme.FONT
	theme.default_font_size = PixelUITheme.FONT_SIZE_BODY
	var fusion_font := PixelUITheme.FONT as FontFile
	if fusion_font != null:
		fusion_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fusion_font.hinting = TextServer.HINTING_NONE
		fusion_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

func label(parent: Control, position: Vector2, dimensions: Vector2, text_value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.position = position
	result.size = dimensions
	result.scale = Vector2.ONE
	result.text = text_value
	var resolved_font_size := PixelUITheme.FONT_SIZE_BODY
	if font_size >= 9:
		resolved_font_size = PixelUITheme.FONT_SIZE_TITLE
	elif font_size <= 3:
		resolved_font_size = PixelUITheme.FONT_SIZE_SMALL
	result.add_theme_font_size_override("font_size", resolved_font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color("081516", 0.86))
	result.add_theme_constant_override("outline_size", 2)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(result)
	return result

func button(parent: Control, position: Vector2, dimensions: Vector2, text_value: String) -> Button:
	var result := Button.new()
	result.position = position
	result.size = dimensions
	result.scale = Vector2.ONE
	result.text = text_value
	result.add_theme_font_size_override("font_size", PixelUITheme.FONT_SIZE_BODY)
	result.add_theme_color_override("font_color", PixelUITheme.TEXT_MAIN)
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_color_override("font_disabled_color", Color("687a76"))
	result.add_theme_color_override("font_outline_color", Color("081516", 0.92))
	result.add_theme_constant_override("outline_size", 2)
	result.add_theme_stylebox_override("normal", button_style(Color("1c3032"), PixelUITheme.PANEL_TEXTURE))
	result.add_theme_stylebox_override("hover", button_style(Color("2c4a49"), PixelUITheme.PANEL_INLAY_TEXTURE))
	result.add_theme_stylebox_override("pressed", button_style(Color("152527"), PixelUITheme.PANEL_INLAY_TEXTURE))
	result.add_theme_stylebox_override("disabled", button_style(Color("182325", 0.8), PixelUITheme.DISABLED_TEXTURE))
	result.add_theme_stylebox_override("focus", button_style(Color("3a534d"), PixelUITheme.PANEL_INLAY_TEXTURE))
	result.focus_mode = Control.FOCUS_ALL
	if parent != null:
		parent.add_child(result)
	return result

func panel(parent: Control, position: Vector2, dimensions: Vector2, color: Color) -> Panel:
	var result := Panel.new()
	result.position = position
	result.size = dimensions
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := PixelUITheme.PANEL_INLAY_TEXTURE if color == PixelUITheme.PANEL_LIGHT else PixelUITheme.PANEL_TEXTURE
	result.add_theme_stylebox_override("panel", PixelUITheme.panel_style(color, texture))
	if parent != null:
		parent.add_child(result)
	return result

func icon(parent: Control, position: Vector2, dimensions: Vector2, texture: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	result.position = position
	result.size = dimensions
	result.scale = Vector2.ONE
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(result)
	return result

func progress_bar(parent: Control, position: Vector2, dimensions: Vector2, fill_color: Color = Color("70a9a0")) -> ProgressBar:
	var result := ProgressBar.new()
	result.position = position
	result.size = dimensions
	result.custom_minimum_size = Vector2.ZERO
	result.min_value = 0.0
	result.max_value = 100.0
	result.value = 0.0
	result.show_percentage = false
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("background", bar_style(Color("101b1d", 0.94), PixelUITheme.BAR_TEXTURE))
	result.add_theme_stylebox_override("fill", bar_style(Color.WHITE, PixelUITheme.meter_texture(fill_color)))
	if parent != null:
		parent.add_child(result)
	return result

func set_progress_fill(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	bar.add_theme_stylebox_override("fill", bar_style(Color.WHITE, PixelUITheme.meter_texture(color)))

func bar_style(tint: Color, texture: Texture2D) -> StyleBoxTexture:
	return PixelUITheme.bar_style(tint, texture)

func button_style(tint: Color, texture: Texture2D = PixelUITheme.PANEL_TEXTURE) -> StyleBoxTexture:
	return PixelUITheme.button_style(tint, texture)

func add_button_icon(button: Button, texture: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	var icon_size := 16
	result.position = Vector2(floor((button.size.x - icon_size) * 0.5), 6)
	result.size = Vector2(icon_size, icon_size)
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if button != null:
		button.add_child(result)
	return result
