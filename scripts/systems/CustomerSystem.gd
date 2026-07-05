extends Node

signal night_queue_generated(current_night: int, customer_count: int)
signal current_customer_changed(customer: Dictionary, customer_index: int)
signal night_queue_finished(current_night: int)

const FALLBACK_CUSTOMER_LIMIT := 8
const FINAL_STORY_ID := "previous_clerk_story"
const FINAL_STORY_STAGE := 3

var current_night := 1
var current_customer_index := 0
var current_customer_queue: Array[Dictionary] = []


func _ready() -> void:
	if not DataManager.data_loaded.is_connected(_on_data_loaded):
		DataManager.data_loaded.connect(_on_data_loaded)

	if DataManager.is_loaded():
		build_queue_for_night(current_night)


func build_queue_for_night(night_number: int) -> bool:
	var normalized_night := maxi(night_number, 1)
	reset_queue()
	current_night = normalized_night

	var night_config := DataManager.get_night_config(normalized_night)
	if night_config.is_empty():
		if normalized_night <= 5:
			push_warning("Night %d has no nights.json config; using fallback queue." % normalized_night)
		current_customer_queue = _build_fallback_queue(normalized_night, FALLBACK_CUSTOMER_LIMIT)
	else:
		current_customer_queue = _build_configured_queue(night_config, normalized_night)

	night_queue_generated.emit(normalized_night, current_customer_queue.size())

	if has_more_customers():
		current_customer_changed.emit(get_current_customer(), current_customer_index)
	else:
		night_queue_finished.emit(normalized_night)

	return not current_customer_queue.is_empty()


func generate_night_queue(night: int) -> void:
	build_queue_for_night(night)


func ensure_night_queue(night: int) -> void:
	var normalized_night := maxi(night, 1)
	if current_customer_queue.is_empty() or current_night != normalized_night:
		build_queue_for_night(normalized_night)


func reset_queue() -> void:
	current_customer_index = 0
	current_customer_queue.clear()


func resolve_night_customer_slots(night_config: Dictionary) -> Array:
	var requests: Array[Dictionary] = []
	var slots = night_config.get("customer_slots", [])
	if not (slots is Array):
		return requests

	for slot in slots:
		if not (slot is Dictionary):
			continue

		var request := DataManager.get_customer_request_by_story_stage(
			str(slot.get("story_id", "")),
			_to_int(slot.get("story_stage", 0), 0)
		)
		if not request.is_empty():
			requests.append(request)

	return requests


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


func _build_configured_queue(night_config: Dictionary, night_number: int) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var slots = night_config.get("customer_slots", [])
	if not (slots is Array) or slots.is_empty():
		push_warning("Night %d has no customer_slots; using fallback queue." % night_number)
		return _build_fallback_queue(night_number, FALLBACK_CUSTOMER_LIMIT)

	for index in range(slots.size()):
		var slot = slots[index]
		if not (slot is Dictionary):
			_warn_slot_unavailable(night_number, index, "", 0, "", "slot is not a Dictionary")
			_append_fallback_customer(queue, night_number)
			continue

		var story_id := str(slot.get("story_id", ""))
		var story_stage := _to_int(slot.get("story_stage", 0), 0)
		var request := _lookup_customer_request(story_id, story_stage)
		var request_id := str(request.get("id", ""))
		var unavailable_reason := _get_request_unavailable_reason(request, night_number, queue)

		if not unavailable_reason.is_empty():
			_warn_slot_unavailable(night_number, index, story_id, story_stage, request_id, unavailable_reason)
			_append_fallback_customer(queue, night_number)
			continue

		queue.append(request.duplicate(true))

	return queue


func _build_fallback_queue(night_number: int, limit: int) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var candidates: Array[Dictionary] = []

	for customer in DataManager.get_all_customers():
		if not (customer is Dictionary):
			continue

		if _is_final_story_request(customer):
			continue

		if not _get_request_unavailable_reason(customer, night_number, queue).is_empty():
			continue

		candidates.append(customer.duplicate(true))

	candidates.sort_custom(_sort_fallback_candidates)

	var target_count := clampi(limit, 1, FALLBACK_CUSTOMER_LIMIT)
	for candidate in candidates:
		if queue.size() >= target_count:
			break

		queue.append(candidate.duplicate(true))

	if queue.is_empty():
		push_warning("Fallback queue for night %d is empty." % night_number)

	return queue


func _append_fallback_customer(queue: Array[Dictionary], night_number: int) -> void:
	var candidates := _build_fallback_queue(night_number, FALLBACK_CUSTOMER_LIMIT)
	for candidate in candidates:
		var request_id := str(candidate.get("id", ""))
		if request_id.is_empty() or _queue_has_request_id(queue, request_id):
			continue

		queue.append(candidate.duplicate(true))
		return

	push_warning("Night %d could not find a fallback customer for an invalid slot." % night_number)


func _lookup_customer_request(story_id: String, story_stage: int) -> Dictionary:
	var matches: Array[Dictionary] = []
	for customer in DataManager.get_all_customers():
		if not (customer is Dictionary):
			continue

		if str(customer.get("story_id", "")) != story_id:
			continue

		if _to_int(customer.get("story_stage", 1), 1) != story_stage:
			continue

		matches.append(customer.duplicate(true))

	if matches.size() == 1:
		return matches[0].duplicate(true)

	return {}


func _get_request_unavailable_reason(request: Dictionary, night_number: int, queue: Array[Dictionary]) -> String:
	if request.is_empty():
		return "request not found"

	var request_id := str(request.get("id", ""))
	if request_id.is_empty():
		return "request id is empty"

	if _queue_has_request_id(queue, request_id):
		return "request already exists in current queue"

	var story_stage := _to_int(request.get("story_stage", 0), 0)
	if story_stage < 1 or story_stage > 3:
		return "story_stage is invalid"

	var min_night := maxi(_to_int(request.get("min_night", 1), 1), 1)
	if min_night > night_number:
		return "min_night %d is greater than current night %d" % [min_night, night_number]

	var story_id := str(request.get("story_id", ""))
	var progress := _get_story_progress(story_id)
	var visit_count := maxi(_to_int(progress.get("visit_count", 0), 0), 0)
	var current_stage := maxi(_to_int(progress.get("current_stage", 0), 0), 0)
	var min_visit_count := maxi(_to_int(request.get("min_visit_count", 0), 0), 0)
	if min_visit_count > visit_count:
		return "min_visit_count %d is greater than current visit_count %d" % [min_visit_count, visit_count]

	if bool(request.get("one_time", false)) and _has_completed_request(request_id):
		return "one_time request is already completed"

	if bool(request.get("one_time", false)) and visit_count > 0 and story_stage <= current_stage:
		return "story_stage has already been passed"

	if not _passes_story_sequence(story_stage, visit_count, current_stage):
		return "story_stage would skip previous stages"

	return ""


func _passes_story_sequence(story_stage: int, visit_count: int, current_stage: int) -> bool:
	if story_stage <= 1:
		return true

	return current_stage >= story_stage - 1 or visit_count >= story_stage - 1


func _sort_fallback_candidates(a: Dictionary, b: Dictionary) -> bool:
	var a_repeatable := bool(a.get("repeatable", false))
	var b_repeatable := bool(b.get("repeatable", false))
	if a_repeatable != b_repeatable:
		return a_repeatable

	return str(a.get("id", "")) < str(b.get("id", ""))


func _queue_has_request_id(queue: Array[Dictionary], request_id: String) -> bool:
	if request_id.is_empty():
		return false

	for customer in queue:
		if str(customer.get("id", "")) == request_id:
			return true

	return false


func _is_final_story_request(request: Dictionary) -> bool:
	return (
		str(request.get("story_id", "")) == FINAL_STORY_ID
		and _to_int(request.get("story_stage", 0), 0) == FINAL_STORY_STAGE
	)


func _warn_slot_unavailable(night_number: int, slot_index: int, story_id: String, story_stage: int, request_id: String, reason: String) -> void:
	push_warning(
		"Night %d slot %d story_id=%s story_stage=%d request_id=%s unavailable: %s" %
		[night_number, slot_index + 1, story_id, story_stage, request_id, reason]
	)


func _get_story_progress(story_id: String) -> Dictionary:
	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("get_story_progress"):
		var progress = customer_progress_system.get_story_progress(story_id)
		if progress is Dictionary:
			return progress.duplicate(true)

	return {
		"current_stage": 0,
		"visit_count": 0,
		"last_customer_request_id": ""
	}


func _has_completed_request(request_id: String) -> bool:
	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("has_completed_request"):
		return bool(customer_progress_system.has_completed_request(request_id))

	if customer_progress_system != null and customer_progress_system.has_method("has_completed_request_id"):
		return bool(customer_progress_system.has_completed_request_id(request_id))

	return false


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
		build_queue_for_night(current_night)
