extends Node

signal inventory_initialized
signal inventory_changed(item_id: String, stock: int)
signal inventory_reset

var stock_by_item_id: Dictionary = {}
var _initialized := false


func _ready() -> void:
	if DataManager.is_loaded():
		initialize_default_stock()
	else:
		DataManager.data_loaded.connect(_on_data_loaded)


func initialize_default_stock(item_data: Array = []) -> void:
	var source_items: Array = item_data
	if source_items.is_empty():
		source_items = DataManager.get_all_items()

	stock_by_item_id.clear()

	for item in source_items:
		if not (item is Dictionary):
			continue

		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty():
			continue

		var max_stock: int = maxi(int(item.get("max_stock", 0)), 0)
		stock_by_item_id[item_id] = max_stock

	_initialized = true
	inventory_initialized.emit()
	inventory_reset.emit()


func reset_to_default_stock() -> void:
	initialize_default_stock()


func is_initialized() -> bool:
	return _initialized


func get_inventory() -> Dictionary:
	_ensure_initialized()
	return stock_by_item_id.duplicate(true)


func export_inventory_data() -> Dictionary:
	return get_inventory()


func import_inventory_data(data: Dictionary) -> bool:
	if not (data is Dictionary):
		reset_to_default_stock()
		return false

	stock_by_item_id.clear()
	var imported_cleanly := true

	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue

		var max_stock := maxi(int(item.get("max_stock", 0)), 0)
		var stock := max_stock
		if data.has(item_id):
			stock = clampi(_to_int(data[item_id], max_stock), 0, max_stock)

		stock_by_item_id[item_id] = stock
		inventory_changed.emit(item_id, stock)

	for saved_item_id in data.keys():
		var normalized_id := str(saved_item_id)
		if normalized_id.is_empty():
			continue

		if DataManager.get_item_by_id(normalized_id).is_empty():
			imported_cleanly = false
			push_warning("Ignoring unknown inventory item from save: %s." % normalized_id)

	_initialized = true
	inventory_reset.emit()
	return imported_cleanly


func set_inventory(inventory: Dictionary) -> void:
	import_inventory_data(inventory)


func get_stock(item_id: String) -> int:
	_ensure_initialized()
	return int(stock_by_item_id.get(item_id, 0))


func get_max_stock(item_id: String) -> int:
	var item: Dictionary = DataManager.get_item_by_id(item_id)
	return maxi(int(item.get("max_stock", 0)), 0)


func can_buy_item(item_id: String, quantity: int = 1) -> bool:
	return _get_buy_failure_reason(item_id, quantity).is_empty()


func buy_item(item_id: String, quantity: int = 1) -> Dictionary:
	var result := _make_buy_result(false, "", item_id, quantity, 0, get_stock(item_id), GameManager.money)
	var reason := _get_buy_failure_reason(item_id, quantity)
	if not reason.is_empty():
		result["reason"] = reason
		return result

	var item: Dictionary = DataManager.get_item_by_id(item_id)
	var cost := int(item.get("buy_price", 0)) * quantity
	if cost > 0 and not GameManager.spend_money(cost):
		result["reason"] = "not_enough_money"
		result["remaining_money"] = GameManager.money
		return result

	if not add_stock(item_id, quantity):
		if cost > 0:
			GameManager.add_money(cost)

		result["reason"] = "exceeds_max_stock"
		result["remaining_money"] = GameManager.money
		return result

	return _make_buy_result(true, "", item_id, quantity, cost, get_stock(item_id), GameManager.money)


func is_stock_full(item_id: String) -> bool:
	var item: Dictionary = DataManager.get_item_by_id(item_id)
	if item.is_empty():
		return false

	return get_stock(item_id) >= get_max_stock(item_id)


func has_stock(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true

	return get_stock(item_id) >= amount


func consume_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	if not has_stock(item_id, amount):
		return false

	var next_stock: int = get_stock(item_id) - amount
	stock_by_item_id[item_id] = next_stock
	inventory_changed.emit(item_id, next_stock)
	return true


func consume_items(item_ids: Array) -> bool:
	var requested_counts := _count_item_ids(item_ids)

	for item_id in requested_counts.keys():
		var amount: int = int(requested_counts[item_id])
		if not has_stock(str(item_id), amount):
			return false

	for item_id in requested_counts.keys():
		consume_item(str(item_id), int(requested_counts[item_id]))

	return true


func add_stock(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	var max_stock: int = get_max_stock(item_id)
	var current_stock: int = get_stock(item_id)
	if current_stock >= max_stock or current_stock + amount > max_stock:
		return false

	var next_stock: int = current_stock + amount
	stock_by_item_id[item_id] = next_stock
	inventory_changed.emit(item_id, next_stock)
	return true


func can_add_stock(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var max_stock := get_max_stock(item_id)
	var current_stock := get_stock(item_id)
	return current_stock < max_stock and current_stock + amount <= max_stock


func _count_item_ids(item_ids: Array) -> Dictionary:
	var counts := {}

	for value in item_ids:
		var item_id: String = str(value)
		if item_id.is_empty():
			continue

		counts[item_id] = int(counts.get(item_id, 0)) + 1

	return counts


func _ensure_initialized() -> void:
	if _initialized:
		return

	initialize_default_stock()


func _on_data_loaded() -> void:
	if stock_by_item_id.is_empty():
		initialize_default_stock()


func _get_buy_failure_reason(item_id: String, quantity: int) -> String:
	if quantity <= 0:
		return "invalid_quantity"

	var item: Dictionary = DataManager.get_item_by_id(item_id)
	if item.is_empty():
		return "item_not_found"

	if not _is_item_unlocked(item):
		return "item_locked"

	var current_stock := get_stock(item_id)
	var max_stock := get_max_stock(item_id)
	if current_stock >= max_stock:
		return "stock_full"

	if current_stock + quantity > max_stock:
		return "exceeds_max_stock"

	var cost := int(item.get("buy_price", 0)) * quantity
	if cost > GameManager.money:
		return "not_enough_money"

	return ""


func _is_item_unlocked(item: Dictionary) -> bool:
	return int(item.get("unlock_day", 1)) <= GameManager.current_night


func _make_buy_result(success: bool, reason: String, item_id: String, quantity: int, cost: int, new_stock: int, remaining_money: int) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"item_id": item_id,
		"quantity": quantity,
		"cost": cost,
		"new_stock": new_stock,
		"remaining_money": remaining_money
	}


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value
