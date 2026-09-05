class_name PauseOverlay
extends OverlayViewBase

func _build() -> void:
	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(960, 540)
	dim.color = Color("081013", 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "PauseDim"
	root.add_child(dim)
	panel = factory.panel(root, Vector2(267, 84), Vector2(426, 375), PixelTheme.PANEL_MID)
	panel.name = "PausePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	factory.label(panel, Vector2(27, 21), Vector2(372, 36), "暂停菜单", 10, PixelTheme.TEXT_ACCENT)
	factory.label(panel, Vector2(27, 60), Vector2(372, 27), "进度已冻结", 6, PixelTheme.TEXT_MUTED)
	var resume := factory.button(panel, Vector2(33, 102), Vector2(360, 42), "继续游戏")
	resume.pressed.connect(_emit_close)
	var save := factory.button(panel, Vector2(33, 153), Vector2(174, 42), "保存")
	save.pressed.connect(func(): _emit_intent({"kind":"save_game"}))
	var load := factory.button(panel, Vector2(219, 153), Vector2(174, 42), "读取")
	load.pressed.connect(func(): _emit_intent({"kind":"load_game"}))
	var exit := factory.button(panel, Vector2(33, 261), Vector2(360, 42), "退出游戏")
	exit.pressed.connect(func(): _emit_intent({"kind":"exit_game"}))
	dim.visible = false
	panel.visible = false

