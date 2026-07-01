extends Node

signal night_queue_generated(current_night: int, customer_count: int)
signal current_customer_changed(customer: Dictionary, customer_index: int)
signal night_queue_finished(current_night: int)

const FIRST_NIGHT_CUSTOMER_COUNT := 5

var current_night := 1
var current_customer_index := 0
var current_customer_queue: Array[Dictionary] = []


func _ready() -> void:
	if not DataManager.data_loaded.is_connected(_on_data_loaded):
		DataManager.data_loaded.connect(_on_data_loaded)

	if DataManager.is_loaded():
		generate_night_queue(current_night)


func generate_night_queue(night: int) -> void:
	current_night = maxi(night, 1)
	current_customer_index = 0
	current_customer_queue.clear()

	var all_customers: Array = DataManager.get_all_customers()
	var customer_count: int = _get_customer_count_for_night(current_night, all_customers.size())

	for index in range(customer_count):
		var customer = all_customers[index]
		if customer is Dictionary:
			current_customer_queue.append(customer.duplicate(true))

	night_queue_generated.emit(current_night, current_customer_queue.size())

	if has_more_customers():
		current_customer_changed.emit(get_current_customer(), current_customer_index)
	else:
		night_queue_finished.emit(current_night)


func ensure_night_queue(night: int) -> void:
	var normalized_night: int = maxi(night, 1)
	if current_customer_queue.is_empty() or current_night != normalized_night:
		generate_night_queue(normalized_night)


func get_current_customer() -> Dictionary:
	if not has_more_customers():
		return {}

	return current_customer_queue[current_customer_index].duplicate(true)


func move_to_next_customer() -> bool:
	if current_customer_queue.is_empty():
		return false

	current_customer_index += 1

	if has_more_customers():
		current_customer_changed.emit(get_current_customer(), current_customer_index)
		return true

	night_queue_finished.emit(current_night)
	return false


func has_more_customers() -> bool:
	return current_customer_index >= 0 and current_customer_index < current_customer_queue.size()


func get_customer_count_for_current_night() -> int:
	return current_customer_queue.size()


func get_served_customer_count() -> int:
	return clampi(current_customer_index, 0, current_customer_queue.size())


func get_current_customer_number() -> int:
	if not has_more_customers():
		return current_customer_queue.size()

	return current_customer_index + 1


func _get_customer_count_for_night(night: int, available_count: int) -> int:
	if available_count <= 0:
		return 0

	var target_count: int = FIRST_NIGHT_CUSTOMER_COUNT + maxi(night - 1, 0)
	return clampi(target_count, 1, available_count)


func _on_data_loaded() -> void:
	if current_customer_queue.is_empty():
		generate_night_queue(current_night)
