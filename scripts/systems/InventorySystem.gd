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


func set_inventory(inventory: Dictionary) -> void:
	stock_by_item_id.clear()

	for item_id in inventory.keys():
		var normalized_id: String = str(item_id)
		if normalized_id.is_empty():
			continue

		var max_stock: int = get_max_stock(normalized_id)
		var stock: int = clampi(int(inventory[item_id]), 0, max_stock)
		stock_by_item_id[normalized_id] = stock
		inventory_changed.emit(normalized_id, stock)

	_initialized = true


func get_stock(item_id: String) -> int:
	_ensure_initialized()
	return int(stock_by_item_id.get(item_id, 0))


func get_max_stock(item_id: String) -> int:
	var item: Dictionary = DataManager.get_item_by_id(item_id)
	return maxi(int(item.get("max_stock", 0)), 0)


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
	if current_stock >= max_stock:
		return false

	var next_stock: int = mini(current_stock + amount, max_stock)
	stock_by_item_id[item_id] = next_stock
	inventory_changed.emit(item_id, next_stock)
	return true


func can_add_stock(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	return get_stock(item_id) < get_max_stock(item_id)


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
	initialize_default_stock()
