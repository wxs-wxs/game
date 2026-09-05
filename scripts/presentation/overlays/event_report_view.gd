class_name EventReportView
extends OverlayViewBase

var title_label: Label
var body_label: Label
var content_label: Label
var choice_buttons: Array[Button] = []

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
	super.refresh(snapshot)
	if panel == null:
		return
	title_label.text = str(snapshot.get("title", "夜间事件"))
	body_label.text = str(snapshot.get("body", ""))
	content_label.text = str(snapshot.get("content", ""))
	var choices: Array = snapshot.get("choices", [])
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		var value := str(choices[index]) if index < choices.size() else ""
		button.text = value
		button.visible = not value.is_empty()
