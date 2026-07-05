extends Node

signal customer_progress_changed(story_id: String, progress: Dictionary)
signal customer_seen(story_id: String)

const GRADE_RANKS := {
	"fail": 0,
	"normal": 1,
	"good": 2,
	"perfect": 3
}

var seen_customers: Array[String] = []
var customer_story_progress: Dictionary = {}
var completed_request_ids: Array[String] = []

var _recorded_service_ids: Array[String] = []


func reset_progress() -> void:
	seen_customers.clear()
	customer_story_progress.clear()
	completed_request_ids.clear()
	_recorded_service_ids.clear()


func record_customer_result(customer_data: Dictionary, service_result: Dictionary) -> bool:
	if customer_data.is_empty() or service_result.is_empty():
		return false

	var story_id := str(customer_data.get("story_id", ""))
	if story_id.is_empty():
		push_warning("Customer result has no story_id.")
		return false

	var service_id := _get_service_id(customer_data, service_result)
	if service_id.is_empty():
		push_warning("Customer result has no service_id.")
		return false

	if _recorded_service_ids.has(service_id):
		return false

	_recorded_service_ids.append(service_id)

	var request_id := str(customer_data.get("id", ""))
	if not request_id.is_empty():
		mark_request_completed(request_id)

	var was_seen := has_seen_customer(story_id)
	if not was_seen:
		seen_customers.append(story_id)
		customer_seen.emit(story_id)

	var progress := _get_or_create_progress(story_id)
	var grade := _normalize_grade(str(service_result.get("grade", "")))
	var score := maxi(_to_int(service_result.get("score", 0), 0), 0)
	var request_stage := maxi(_to_int(customer_data.get("story_stage", 1), 1), 1)

	progress["visit_count"] = maxi(_to_int(progress.get("visit_count", 0), 0), 0) + 1
	progress["last_grade"] = grade
	progress["last_score"] = score
	progress["best_score"] = maxi(_to_int(progress.get("best_score", 0), 0), score)
	progress["total_score"] = maxi(_to_int(progress.get("total_score", 0), 0), 0) + score
	progress["last_customer_request_id"] = request_id

	var best_grade := _normalize_grade(str(progress.get("best_grade", "")))
	if best_grade.is_empty() or _grade_rank(grade) > _grade_rank(best_grade):
		progress["best_grade"] = grade

	var current_stage := maxi(_to_int(progress.get("current_stage", 0), 0), 0)
	current_stage = maxi(current_stage, 1)
	if int(progress["visit_count"]) >= 2:
		current_stage = maxi(current_stage, 2)
	if int(progress["visit_count"]) >= 3:
		current_stage = maxi(current_stage, 3)
	current_stage = maxi(current_stage, request_stage)
	progress["current_stage"] = current_stage

	customer_story_progress[story_id] = progress
	customer_progress_changed.emit(story_id, progress.duplicate(true))
	return true


func has_seen_customer(story_id: String) -> bool:
	return seen_customers.has(story_id)


func get_story_progress(story_id: String) -> Dictionary:
	var story_key := str(story_id)
	if customer_story_progress.has(story_key) and customer_story_progress[story_key] is Dictionary:
		return customer_story_progress[story_key].duplicate(true)

	return _make_default_progress()


func get_archive_stage(story_id: String) -> int:
	if not has_seen_customer(story_id):
		return 0

	var progress := get_story_progress(story_id)
	return maxi(_to_int(progress.get("current_stage", 0), 0), 0)


func get_seen_customers() -> Array:
	return seen_customers.duplicate()


func get_completed_request_ids() -> Array:
	return completed_request_ids.duplicate()


func has_completed_request(request_id: String) -> bool:
	return completed_request_ids.has(request_id)


func mark_request_completed(request_id: String) -> bool:
	if request_id.is_empty() or completed_request_ids.has(request_id):
		return false

	completed_request_ids.append(request_id)
	return true


func has_completed_request_id(request_id: String) -> bool:
	return has_completed_request(request_id)


func export_progress_data() -> Dictionary:
	return {
		"seen_customers": seen_customers.duplicate(),
		"customer_story_progress": customer_story_progress.duplicate(true),
		"completed_request_ids": completed_request_ids.duplicate()
	}


func import_progress_data(data: Dictionary) -> bool:
	var imported_cleanly := true
	seen_customers.clear()
	customer_story_progress.clear()
	completed_request_ids.clear()
	_recorded_service_ids.clear()

	var imported_seen = data.get("seen_customers", [])
	if imported_seen is Array:
		for value in imported_seen:
			var story_id := str(value)
			if story_id.is_empty():
				continue

			if not _is_known_story_id(story_id):
				imported_cleanly = false
				push_warning("Ignoring unknown seen customer story_id from save: %s." % story_id)
				continue

			_append_unique_seen(story_id)
	else:
		imported_cleanly = false

	var imported_progress = data.get("customer_story_progress", {})
	if imported_progress is Dictionary:
		for raw_story_id in imported_progress.keys():
			var story_id := str(raw_story_id)
			if story_id.is_empty():
				continue

			if not _is_known_story_id(story_id):
				imported_cleanly = false
				push_warning("Ignoring unknown customer progress story_id from save: %s." % story_id)
				continue

			var progress := _normalize_progress(imported_progress[raw_story_id])
			customer_story_progress[story_id] = progress
			if int(progress.get("visit_count", 0)) > 0 or int(progress.get("current_stage", 0)) > 0:
				_append_unique_seen(story_id)
	else:
		imported_cleanly = false

	if data.has("completed_request_ids") or data.has("completed_customer_request_ids"):
		var imported_completed = data.get("completed_request_ids", data.get("completed_customer_request_ids", []))
		if imported_completed is Array:
			for value in imported_completed:
				var request_id := str(value)
				if request_id.is_empty():
					continue

				if not _is_known_request_id(request_id):
					imported_cleanly = false
					push_warning("Ignoring unknown completed customer request id from save: %s." % request_id)
					continue

				mark_request_completed(request_id)
		else:
			imported_cleanly = false

	return imported_cleanly


func _get_service_id(customer_data: Dictionary, service_result: Dictionary) -> String:
	var service_id := str(service_result.get("service_id", ""))
	if not service_id.is_empty():
		return service_id

	var customer_id := str(customer_data.get("id", ""))
	if customer_id.is_empty():
		return ""

	return "%s:%s:%s" % [
		customer_id,
		str(service_result.get("score", 0)),
		JSON.stringify(service_result.get("selected_item_ids", []))
	]


func _get_or_create_progress(story_id: String) -> Dictionary:
	if customer_story_progress.has(story_id) and customer_story_progress[story_id] is Dictionary:
		return customer_story_progress[story_id].duplicate(true)

	return _make_default_progress()


func _make_default_progress() -> Dictionary:
	return {
		"current_stage": 0,
		"visit_count": 0,
		"best_grade": "",
		"last_grade": "",
		"best_score": 0,
		"last_score": 0,
		"total_score": 0,
		"last_customer_request_id": ""
	}


func _normalize_progress(value) -> Dictionary:
	var progress := _make_default_progress()
	if value is Dictionary:
		progress["current_stage"] = maxi(_to_int(value.get("current_stage", 0), 0), 0)
		progress["visit_count"] = maxi(_to_int(value.get("visit_count", 0), 0), 0)
		progress["best_grade"] = _normalize_grade(str(value.get("best_grade", "")))
		progress["last_grade"] = _normalize_grade(str(value.get("last_grade", "")))
		progress["best_score"] = maxi(_to_int(value.get("best_score", 0), 0), 0)
		progress["last_score"] = maxi(_to_int(value.get("last_score", 0), 0), 0)
		progress["total_score"] = maxi(_to_int(value.get("total_score", 0), 0), 0)
		progress["last_customer_request_id"] = str(value.get("last_customer_request_id", ""))
		return progress

	var stage := maxi(_to_int(value, 0), 0)
	progress["current_stage"] = stage
	progress["visit_count"] = stage
	return progress


func _normalize_grade(grade: String) -> String:
	if GRADE_RANKS.has(grade):
		return grade

	return ""


func _grade_rank(grade: String) -> int:
	return int(GRADE_RANKS.get(grade, -1))


func _append_unique_seen(story_id: String) -> void:
	if story_id.is_empty() or seen_customers.has(story_id):
		return

	seen_customers.append(story_id)


func _is_known_story_id(story_id: String) -> bool:
	if story_id.is_empty():
		return false

	if DataManager.get_customer_profile_by_story_id(story_id).is_empty():
		for customer in DataManager.get_all_customers():
			if customer is Dictionary and str(customer.get("story_id", "")) == story_id:
				return true

		return false

	return true


func _is_known_request_id(request_id: String) -> bool:
	if request_id.is_empty():
		return false

	return not DataManager.get_customer_by_id(request_id).is_empty()


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value
