class_name StorageTransferSlot
extends Panel

## A reusable inventory cell for storage-device transfers.
## The owning UI supplies the transfer callback so the cell stays independent
## from ResourceManager and can be reused by future storage devices.

var source_kind := ""
var item_key := ""
var amount := 0
var unlocked := true
var transfer_owner: Object
var item_icon: TextureRect
var item_label: Label
var count_label: Label

func configure(kind: String, key: String, quantity: int, can_use: bool, owner: Object) -> void:
	source_kind = kind
	item_key = key
	amount = maxi(0, quantity)
	unlocked = can_use
	transfer_owner = owner

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not unlocked or item_key.is_empty() or amount <= 0:
		return null
	var preview := Label.new()
	preview.text = item_label.text if item_label != null and not item_label.text.is_empty() else item_key
	preview.add_theme_font_size_override("font_size", 11)
	preview.add_theme_color_override("font_color", Color("f2ca72"))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Regression tests can call this virtual method directly without an active
	# viewport drag; Godot rejects set_drag_preview() in that situation.
	if get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	return {
		"source_kind": source_kind,
		"key": item_key,
		"amount": 1,
		"source_slot": self
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not unlocked or not data is Dictionary:
		return false
	var payload: Dictionary = data
	var payload_kind := str(payload.get("source_kind", ""))
	var payload_key := str(payload.get("key", ""))
	if payload_kind.is_empty() or payload_kind == source_kind or payload_key.is_empty():
		return false
	if transfer_owner != null and transfer_owner.has_method("_can_storage_drop"):
		return bool(transfer_owner.call("_can_storage_drop", payload, source_kind, item_key))
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if transfer_owner != null and transfer_owner.has_method("_handle_storage_drop"):
		transfer_owner.call("_handle_storage_drop", data, source_kind, item_key)
