class_name EventReportView
extends OverlayViewBase

var title_label: Label
var body_label: Label
var content_label: Label
var choice_buttons: Array[Button] = []
var report_panel: Control
var _report_open := false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	report_panel = callbacks.get("report_panel") as Control
	var choices: Array = callbacks.get("event_choices", []) if callbacks.get("event_choices", []) is Array else []
	for index in range(choices.size()):
		var choice := choices[index] as Button
		if choice != null:
			choice.pressed.connect(_choose_event.bind(index))
	var continue_button := callbacks.get("report_continue") as Button
	if continue_button != null:
		continue_button.pressed.connect(func(): _emit_intent({"kind":"report_continue"}))

func open(snapshot: Dictionary) -> void:
	_report_open = str(snapshot.get("mode", "event")) == "report"
	_open = not _report_open
	refresh(snapshot)

func close() -> void:
	_open = false
	_report_open = false
	if panel != null: panel.visible = false
	if report_panel != null: report_panel.visible = false

func is_open() -> bool:
	return _open or _report_open

func _build() -> void:
	panel = factory.panel(root, Vector2(177, 96), Vector2(606, 348), PixelTheme.PANEL_MID)
	panel.name = "EventReportPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 35
	title_label = factory.label(panel, Vector2(30, 24), Vector2(546, 30), "夜间事件", 9, PixelTheme.TEXT_ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label = factory.label(panel, Vector2(42, 72), Vector2(522, 66), "", 5, PixelTheme.TEXT_MAIN)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_label = factory.label(panel, Vector2(42, 72), Vector2(522, 220), "", 5, PixelTheme.TEXT_MAIN)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(2):
		var choice := factory.button(panel, Vector2(42, 166 + index * 72), Vector2(522, 54), "")
		choice.pressed.connect(_choose_event.bind(index))
		choice_buttons.append(choice)
	var continue_button := factory.button(panel, Vector2(192, 282), Vector2(222, 36), "继续")
	continue_button.pressed.connect(_emit_close)
	panel.visible = false

func _choose_event(index: int) -> void:
	_emit_intent({"kind":"choose_event", "index":index})

func refresh(snapshot: Dictionary) -> void:
	if panel == null and report_panel == null:
		return
	if _report_open:
		if panel != null: panel.visible = false
		if report_panel != null:
			report_panel.visible = true
			var report_label := report_panel.get_node_or_null("ReportContent") as Label
			if report_label != null: report_label.text = str(snapshot.get("content", ""))
		return
	if panel != null: panel.visible = _open
	title_label.text = str(snapshot.get("title", "夜间事件"))
	body_label.text = str(snapshot.get("body", ""))
	content_label.text = str(snapshot.get("content", ""))
	var choices: Array = snapshot.get("choices", [])
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		var value := str(choices[index]) if index < choices.size() else ""
		button.text = value
		button.visible = not value.is_empty()
