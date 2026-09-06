class_name OverlayViewBase
extends RefCounted

## Small presentation-only overlay adapter. Views consume snapshots and emit
## intents; the UI facade remains responsible for game state and pause depth.
signal intent_requested(intent: Dictionary)
signal close_requested

const UiFactory := preload("res://scripts/presentation/theme/ui_factory.gd")
const PixelTheme := preload("res://scripts/pixel_ui_theme.gd")

var root: Control
var factory: UiFactory
var callbacks: Dictionary = {}
var panel: Control
var _open := false

func setup(parent: Control, factory_argument: Object, callback_map: Dictionary) -> void:
	root = parent
	factory = factory_argument as UiFactory
	if factory == null:
		factory = UiFactory.new()
		factory.setup(null)
	callbacks = callback_map.duplicate()
	var legacy_panel := callbacks.get("legacy_panel") as Control
	if legacy_panel != null:
		panel = legacy_panel
	if root != null and panel == null:
		_build()

func open(snapshot: Dictionary) -> void:
	_open = true
	refresh(snapshot)
	if panel != null:
		panel.visible = true

func refresh(snapshot: Dictionary) -> void:
	if panel != null:
		panel.visible = _open

func close() -> void:
	_open = false
	if panel != null:
		panel.visible = false

func is_open() -> bool:
	return _open

func _build() -> void:
	pass

func _emit_intent(value: Dictionary) -> void:
	intent_requested.emit(value)

func _emit_close() -> void:
	close_requested.emit()
