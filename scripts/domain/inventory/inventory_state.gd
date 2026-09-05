class_name InventoryState
extends RefCounted

var catalog: ResourceCatalog
var backpack: Dictionary = {}
var storage: Dictionary = {}
var backpack_capacity := ResourceCatalog.BACKPACK_BASE_CAPACITY

func _init(catalog_value = null) -> void:
	if catalog_value == null: catalog_value = ResourceCatalog.new()
	catalog = catalog_value
	for key in catalog.ITEM_KEYS: backpack[key] = 0; storage[key] = 0
func backpack_slots_used() -> int:
	var slots := 0
	for key in catalog.ITEM_KEYS:
		if int(backpack.get(key, 0)) > 0: slots += 1
	return slots
func can_carry_item(key: String, amount: int = 1) -> bool:
	if amount <= 0: return true
	if not catalog.ITEM_KEYS.has(key): return false
	var current := int(backpack.get(key, 0))
	if current + amount > catalog.STACK_MAX: return false
	return current > 0 or backpack_slots_used() < backpack_capacity
func move_to_backpack(key: String, amount: int = 1) -> Dictionary:
	var quantity := mini(maxi(0, amount), int(storage.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":"储物架中没有%s。" % catalog.display_name(key)}
	if not can_carry_item(key, quantity): return {"ok":false, "reason":"背包已满或该物品堆叠达到 %d。" % catalog.STACK_MAX}
	storage[key] -= quantity; backpack[key] = int(backpack.get(key, 0)) + quantity
	return {"ok":true, "amount":quantity, "reason":"已将 %s%d 放入背包。" % [catalog.display_name(key), quantity]}
func move_to_storage(key: String, amount: int = 1) -> Dictionary: return _move(key, amount, true)
func discard_from_backpack(key: String, amount: int = 1) -> Dictionary: return _discard(key, amount, true)
func discard_from_storage(key: String, amount: int = 1) -> Dictionary: return _discard(key, amount, false)
func _move(key: String, amount: int, to_storage: bool) -> Dictionary:
	var source := backpack if to_storage else storage; var target := storage if to_storage else backpack
	var quantity := mini(maxi(0, amount), int(source.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":("背包中没有" if to_storage else "储物架中没有") + catalog.display_name(key) + "。"}
	if not to_storage and not can_carry_item(key, quantity): return {"ok":false, "reason":"背包已满或该物品堆叠达到 %d。" % catalog.STACK_MAX}
	source[key] = int(source.get(key, 0)) - quantity; target[key] = int(target.get(key, 0)) + quantity
	return {"ok":true, "amount":quantity}
func _discard(key: String, amount: int, from_backpack: bool) -> Dictionary:
	var source := backpack if from_backpack else storage
	var quantity := mini(maxi(0, amount), int(source.get(key, 0)))
	if quantity <= 0: return {"ok":false, "reason":("背包中没有" if from_backpack else "储物架中没有") + catalog.display_name(key) + "。"}
	source[key] -= quantity
	return {"ok":true, "amount":quantity}
func to_dict() -> Dictionary: return {"backpack":backpack.duplicate(true), "storage":storage.duplicate(true), "backpack_capacity":backpack_capacity}
func from_dict(data: Dictionary) -> void:
	for key in catalog.ITEM_KEYS:
		backpack[key] = maxi(0, int(data.get("backpack", {}).get(key, 0)))
		storage[key] = maxi(0, int(data.get("storage", {}).get(key, 0)))
	backpack_capacity = ResourceCatalog.BACKPACK_BASE_CAPACITY
