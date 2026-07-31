extends Node

const LOG_DIRECTORY := "user://playtest_logs"

var _session_path := ""
var _recorded_service_ids: Dictionary = {}


func is_available(debug_build_override = null) -> bool:
	if debug_build_override is bool:
		return bool(debug_build_override)

	return OS.is_debug_build()


func log_service(service_result: Dictionary, customer_data: Dictionary) -> bool:
	if not is_available() or service_result.is_empty():
		return false

	var service_id := str(service_result.get("service_id", ""))
	if service_id.is_empty():
		push_warning("Playtest log skipped because service_id is empty.")
		return false

	if _recorded_service_ids.has(service_id):
		return false

	if not _ensure_session_path():
		return false

	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_session_path) else FileAccess.WRITE_READ
	var file := FileAccess.open(_session_path, mode)
	if file == null:
		push_warning("Could not open playtest log. Error code: %s." % FileAccess.get_open_error())
		return false

	file.seek_end()
	file.store_line(JSON.stringify(_build_log_entry(service_result, customer_data)))
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		push_warning("Could not write playtest log. Error code: %s." % write_error)
		return false

	_recorded_service_ids[service_id] = true
	return true


func has_recorded_service_id(service_id: String) -> bool:
	return _recorded_service_ids.has(service_id)


func get_session_path() -> String:
	return _session_path


func reset_runtime_state() -> void:
	_session_path = ""
	_recorded_service_ids.clear()


func _ensure_session_path() -> bool:
	if not _session_path.is_empty():
		return true

	var absolute_directory := ProjectSettings.globalize_path(LOG_DIRECTORY)
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		push_warning("Could not create playtest log directory. Error code: %s." % error)
		return false

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	_session_path = "%s/session_%s.jsonl" % [LOG_DIRECTORY, timestamp]
	return true


func _build_log_entry(service_result: Dictionary, customer_data: Dictionary) -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(true),
		"night": GameManager.current_night,
		"request_id": str(customer_data.get("id", service_result.get("customer_id", ""))),
		"story_id": str(customer_data.get("story_id", "")),
		"story_stage": int(customer_data.get("story_stage", 0)),
		"selected_item_ids": _duplicate_array(service_result.get("selected_item_ids", [])),
		"score": int(service_result.get("score", 0)),
		"grade": str(service_result.get("grade", "")),
		"matched_tags": _duplicate_array(service_result.get("matched_tags", [])),
		"missing_tags": _duplicate_array(service_result.get("missing_tags", [])),
		"bad_tags": _duplicate_array(service_result.get("bad_tags", [])),
		"combo_names": _duplicate_array(service_result.get("combo_names", [])),
		"income": int(service_result.get("income", 0)),
		"money_after": GameManager.money,
		"inventory_after": InventorySystem.export_inventory_data()
	}


func _duplicate_array(value) -> Array:
	if value is Array:
		return value.duplicate(true)

	return []
