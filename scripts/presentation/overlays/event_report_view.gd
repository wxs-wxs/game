class_name EventReportView
extends OverlayViewBase

var title_label: Label
var body_label: Label
var content_label: Label
var choice_buttons: Array[Button] = []
var report_panel: Control
var report_content_label: Label
var report_continue_button: Button
var _report_open := false
var _wired := false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	super.setup(parent, factory_argument, callback_map)
	var callback_report_panel := callbacks.get("report_panel") as Control
	if callback_report_panel != null: report_panel = callback_report_panel
	var callback_title := callbacks.get("title_label") as Label
	if callback_title != null: title_label = callback_title
	var callback_body := callbacks.get("body_label") as Label
	if callback_body != null: body_label = callback_body
	var callback_content := callbacks.get("content_label") as Label
	if callback_content != null: content_label = callback_content
	var callback_report_content := callbacks.get("report_content_label") as Label
	if callback_report_content != null: report_content_label = callback_report_content
	var callback_report_continue := callbacks.get("report_continue") as Button
	if callback_report_continue != null: report_continue_button = callback_report_continue
	if _wired:
		return
	var choices_variant: Variant = callbacks.get("event_choices", callbacks.get("choice_buttons", []))
	var choices: Array = choices_variant if choices_variant is Array else []
	if not choices.is_empty():
		choice_buttons.clear()
		for index in range(choices.size()):
			var choice := choices[index] as Button
			if choice != null:
				choice_buttons.append(choice)
				choice.pressed.connect(_choose_event.bind(index))
	if callback_report_continue != null and report_continue_button != null:
		report_continue_button.pressed.connect(func(): _emit_intent({"kind":"report_continue"}))
	_wired = true

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
	report_panel = factory.panel(root, Vector2(177, 96), Vector2(606, 348), PixelTheme.PANEL_MID)
	report_panel.name = "ReportPanel"
	report_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	report_panel.z_index = 36
	factory.label(report_panel, Vector2(30, 24), Vector2(546, 30), "夜间报告", 9, PixelTheme.TEXT_ACCENT)
	report_content_label = factory.label(report_panel, Vector2(42, 72), Vector2(522, 210), "", 5, PixelTheme.TEXT_MAIN)
	report_content_label.name = "ReportContent"
	report_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	report_continue_button = factory.button(report_panel, Vector2(177, 294), Vector2(252, 36), "进入清晨")
	report_continue_button.pressed.connect(func(): _emit_intent({"kind":"report_continue"}))
	panel.visible = false
	report_panel.visible = false

func _choose_event(index: int) -> void:
	_emit_intent({"kind":"choose_event", "index":index})

func refresh(snapshot: Dictionary) -> void:
	if panel == null and report_panel == null:
		return
	if _report_open:
		if panel != null: panel.visible = false
		if report_panel != null:
			report_panel.visible = true
			var report_label := report_content_label
			if report_label == null:
				report_label = report_panel.get_node_or_null("ReportContent") as Label
			if report_label != null: report_label.text = str(snapshot.get("content", ""))
			if report_continue_button != null:
				report_continue_button.text = str(snapshot.get("continue_text", report_continue_button.text))
				report_continue_button.disabled = bool(snapshot.get("terminal", report_continue_button.disabled))
		return
	if panel != null: panel.visible = _open
	if report_panel != null: report_panel.visible = false
	if title_label != null: title_label.text = str(snapshot.get("title", "夜间事件"))
	if body_label != null: body_label.text = str(snapshot.get("body", ""))
	if content_label != null: content_label.text = str(snapshot.get("content", ""))
	var choices: Array = snapshot.get("choices", [])
	var enabled_values: Array = snapshot.get("choice_enabled", [])
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		var value := str(choices[index]) if index < choices.size() else ""
		button.text = value
		button.visible = not value.is_empty()
		button.disabled = not bool(enabled_values[index]) if index < enabled_values.size() else value.is_empty()
