extends Node

signal night_queue_generated(current_night: int, customer_count: int)
signal current_customer_changed(customer: Dictionary, customer_index: int)
signal night_queue_finished(current_night: int)

const FIRST_NIGHT_CUSTOMER_COUNT := 5
const DEFAULT_NIGHT_CUSTOMER_COUNTS := {
	1: 5,
	2: 6,
	3: 7,
	4: 8,
	5: 4
}
const DEFAULT_FINAL_CUSTOMERS := {
	5: "previous_clerk_01"
}

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
	current_customer_queue = _build_customer_queue_for_night(all_customers, customer_count, current_night)

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


func get_current_customer_queue() -> Array:
	return current_customer_queue.duplicate(true)


func get_current_queue_request_ids() -> Array:
	var request_ids: Array[String] = []

	for customer in current_customer_queue:
		request_ids.append(str(customer.get("id", "")))

	return request_ids


func get_served_customer_count() -> int:
	return clampi(current_customer_index, 0, current_customer_queue.size())


func get_current_customer_number() -> int:
	if not has_more_customers():
		return current_customer_queue.size()

	return current_customer_index + 1


func _get_customer_count_for_night(night: int, available_count: int) -> int:
	if available_count <= 0:
		return 0

	var night_config := DataManager.get_night(night)
	if not night_config.is_empty() and night_config.has("customer_count"):
		return clampi(_to_int(night_config.get("customer_count", FIRST_NIGHT_CUSTOMER_COUNT), FIRST_NIGHT_CUSTOMER_COUNT), 1, available_count)

	var target_count: int = int(DEFAULT_NIGHT_CUSTOMER_COUNTS.get(night, FIRST_NIGHT_CUSTOMER_COUNT + maxi(night - 1, 0)))
	return clampi(target_count, 1, available_count)


func _build_customer_queue_for_night(all_customers: Array, target_count: int, night: int) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	if target_count <= 0:
		return queue

	var completed_request_ids := _get_completed_request_ids()
	var story_progress := _get_story_progress_snapshot()
	var selected_story_ids: Array[String] = []
	var final_customer_id := _get_final_customer_id_for_night(night)
	var final_customer := DataManager.get_customer_by_id(final_customer_id)
	var has_reserved_final := not final_customer.is_empty() and not completed_request_ids.has(final_customer_id)
	var final_story_id := str(final_customer.get("story_id", ""))
	var normal_target_count := target_count
	if has_reserved_final:
		normal_target_count = maxi(target_count - 1, 0)

	for customer_value in all_customers:
		if queue.size() >= normal_target_count:
			break

		if not (customer_value is Dictionary):
			continue

		var customer: Dictionary = customer_value
		var request_id := str(customer.get("id", ""))
		if request_id.is_empty() or request_id == final_customer_id:
			continue

		var story_id := str(customer.get("story_id", ""))
		var can_chain_final_story := has_reserved_final and not final_story_id.is_empty() and story_id == final_story_id
		if selected_story_ids.has(story_id) and not can_chain_final_story:
			continue

		if not _is_customer_available_for_queue(customer, night, completed_request_ids, story_progress):
			continue

		queue.append(customer.duplicate(true))
		if not selected_story_ids.has(story_id):
			selected_story_ids.append(story_id)
		_simulate_customer_completion(customer, completed_request_ids, story_progress)

	if has_reserved_final and queue.size() < target_count:
		if _is_customer_available_for_queue(final_customer, night, completed_request_ids, story_progress):
			queue.append(final_customer.duplicate(true))
		else:
			push_warning("Final customer %s is configured for night %d but is not eligible yet." % [final_customer_id, night])

	return queue


func _is_customer_available_for_queue(customer: Dictionary, night: int, completed_request_ids: Array, story_progress: Dictionary) -> bool:
	var request_id := str(customer.get("id", ""))
	if request_id.is_empty() or completed_request_ids.has(request_id):
		return false

	var min_night := maxi(_to_int(customer.get("min_night", 1), 1), 1)
	if min_night > night:
		return false

	var story_id := str(customer.get("story_id", ""))
	var progress := _get_progress_for_story(story_progress, story_id)
	var visit_count := maxi(_to_int(progress.get("visit_count", 0), 0), 0)
	var current_stage := maxi(_to_int(progress.get("current_stage", 0), 0), 0)
	var story_stage := maxi(_to_int(customer.get("story_stage", 1), 1), 1)
	var min_visit_count := maxi(_to_int(customer.get("min_visit_count", 0), 0), 0)

	if visit_count < min_visit_count:
		return false

	if visit_count > 0 and story_stage <= current_stage:
		return false

	return true


func _simulate_customer_completion(customer: Dictionary, completed_request_ids: Array, story_progress: Dictionary) -> void:
	var request_id := str(customer.get("id", ""))
	if not request_id.is_empty() and not completed_request_ids.has(request_id):
		completed_request_ids.append(request_id)

	var story_id := str(customer.get("story_id", ""))
	if story_id.is_empty():
		return

	var progress := _get_progress_for_story(story_progress, story_id)
	var story_stage := maxi(_to_int(customer.get("story_stage", 1), 1), 1)
	progress["visit_count"] = maxi(_to_int(progress.get("visit_count", 0), 0), 0) + 1
	progress["current_stage"] = maxi(maxi(_to_int(progress.get("current_stage", 0), 0), 0), story_stage)
	progress["last_customer_request_id"] = request_id
	story_progress[story_id] = progress


func _get_progress_for_story(story_progress: Dictionary, story_id: String) -> Dictionary:
	if story_progress.has(story_id) and story_progress[story_id] is Dictionary:
		return story_progress[story_id].duplicate(true)

	return {
		"current_stage": 0,
		"visit_count": 0,
		"last_customer_request_id": ""
	}


func _get_story_progress_snapshot() -> Dictionary:
	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("export_progress_data"):
		var exported = customer_progress_system.export_progress_data()
		if exported is Dictionary:
			var progress = exported.get("customer_story_progress", {})
			if progress is Dictionary:
				return progress.duplicate(true)

	return {}


func _get_completed_request_ids() -> Array:
	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("get_completed_request_ids"):
		var request_ids = customer_progress_system.get_completed_request_ids()
		if request_ids is Array:
			return request_ids.duplicate()

	return []


func _get_final_customer_id_for_night(night: int) -> String:
	var night_config := DataManager.get_night(night)
	if not night_config.is_empty() and night_config.has("final_customer_id"):
		return str(night_config.get("final_customer_id", ""))

	return str(DEFAULT_FINAL_CUSTOMERS.get(night, ""))


func _get_customer_progress_system() -> Node:
	return get_node_or_null("/root/CustomerProgressSystem")


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value


func _on_data_loaded() -> void:
	if current_customer_queue.is_empty():
		generate_night_queue(current_night)
