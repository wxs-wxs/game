class_name PauseOverlay
extends OverlayViewBase

var dim: Control
var _wired := false

func open(snapshot: Dictionary) -> void:
	super.open(snapshot)
	if dim != null: dim.visible = true

func refresh(snapshot: Dictionary) -> void:
	super.refresh(snapshot)
	if dim != null: dim.visible = _open

func close() -> void:
	super.close()
	if dim != null: dim.visible = false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var callback_dim := callbacks.get("dim") as Control
	if callback_dim != null: dim = callback_dim
	if _wired:
		return
	var resume := callbacks.get("resume_button") as Button
	if resume != null: resume.pressed.connect(func(): _emit_intent({"kind":"resume"}))
	var explore := callbacks.get("explore_button") as Button
	if explore != null: explore.pressed.connect(func(): _emit_intent({"kind":"resume"}))
	var save := callbacks.get("save_button") as Button
	if save != null: save.pressed.connect(func(): _emit_intent({"kind":"save_game"}))
	var load := callbacks.get("load_button") as Button
	if load != null: load.pressed.connect(func(): _emit_intent({"kind":"load_game"}))
	var exit := callbacks.get("exit_button") as Button
	if exit != null: exit.pressed.connect(func(): _emit_intent({"kind":"exit_game"}))
	_wired = true

func _build() -> void:
	dim = ColorRect.new()
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
	resume.pressed.connect(func(): _emit_intent({"kind":"resume"}))
	var save := factory.button(panel, Vector2(33, 153), Vector2(174, 42), "保存")
	save.pressed.connect(func(): _emit_intent({"kind":"save_game"}))
	var load := factory.button(panel, Vector2(219, 153), Vector2(174, 42), "读取")
	load.pressed.connect(func(): _emit_intent({"kind":"load_game"}))
	var exit := factory.button(panel, Vector2(33, 261), Vector2(360, 42), "退出游戏")
	exit.pressed.connect(func(): _emit_intent({"kind":"exit_game"}))
	dim.visible = false
	panel.visible = false
