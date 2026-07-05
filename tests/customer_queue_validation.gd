extends SceneTree

const SAVE_PATH := "user://save_data.json"
const NIGHT_ONE_IDS := [
	"student_exam_01",
	"overtime_worker_01",
	"silent_old_man_01",
	"masked_boy_01",
	"insomnia_driver_01"
]

var _failures: Array[String] = []
var _save_existed := false
var _save_backup_text := ""
var _data_manager
var _save_manager
var _inventory_system
var _customer_system
var _customer_progress_system
var _game_manager


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	await process_frame
	_bind_autoloads()
	if not _failures.is_empty():
		_restore_save()
		_finish()
		return

	if _data_manager != null and _data_manager.has_method("reload_data"):
		_data_manager.reload_data()

	_test_night_queues_and_coverage()
	_test_continue_starts_current_night_at_first_customer()
	_test_new_game_clears_completed_requests()
	_test_old_save_without_completed_requests_does_not_crash()

	_restore_save()
	_finish()


func _bind_autoloads() -> void:
	_data_manager = root.get_node_or_null("/root/DataManager")
	_save_manager = root.get_node_or_null("/root/SaveManager")
	_inventory_system = root.get_node_or_null("/root/InventorySystem")
	_customer_system = root.get_node_or_null("/root/CustomerSystem")
	_customer_progress_system = root.get_node_or_null("/root/CustomerProgressSystem")
	_game_manager = root.get_node_or_null("/root/GameManager")

	_assert(_data_manager != null, "DataManager autoload must exist.")
	_assert(_save_manager != null, "SaveManager autoload must exist.")
	_assert(_inventory_system != null, "InventorySystem autoload must exist.")
	_assert(_customer_system != null, "CustomerSystem autoload must exist.")
	_assert(_customer_progress_system != null, "CustomerProgressSystem autoload must exist.")
	_assert(_game_manager != null, "GameManager autoload must exist.")


func _test_night_queues_and_coverage() -> void:
	_reset_progress_only()

	_customer_system.generate_night_queue(1)
	var first_night_ids = _customer_system.get_current_queue_request_ids()
	_customer_system.generate_night_queue(1)
	var repeated_first_night_ids = _customer_system.get_current_queue_request_ids()
	_assert_array_equals(first_night_ids, NIGHT_ONE_IDS, "Night 1 queue must be the fixed five opening customers.")
	_assert_array_equals(repeated_first_night_ids, NIGHT_ONE_IDS, "Night 1 queue must stay deterministic when regenerated.")

	var served_ids: Array[String] = []
	_record_current_queue_as_served(1, served_ids)

	_customer_system.generate_night_queue(2)
	var second_night_ids = _customer_system.get_current_queue_request_ids()
	_assert_equal(second_night_ids.size(), 6, "Night 2 must have 6 customers.")
	_assert_has(second_night_ids, "student_exam_02", "Night 2 must include student Stage 2.")
	_assert_not_has(second_night_ids, "student_exam_01", "Night 2 must not repeat student Stage 1.")
	_assert_student_dialogue_changed_on_stage_two()
	_record_current_queue_as_served(2, served_ids)

	_customer_system.generate_night_queue(3)
	_assert_equal(_customer_system.get_current_queue_request_ids().size(), 7, "Night 3 must have 7 customers.")
	_record_current_queue_as_served(3, served_ids)

	_customer_system.generate_night_queue(4)
	_assert_equal(_customer_system.get_current_queue_request_ids().size(), 8, "Night 4 must have 8 customers.")
	_record_current_queue_as_served(4, served_ids)

	_customer_system.generate_night_queue(5)
	var fifth_night_ids = _customer_system.get_current_queue_request_ids()
	_assert_equal(fifth_night_ids.size(), 4, "Night 5 must have exactly 4 customers.")
	if not fifth_night_ids.is_empty():
		_assert_equal(fifth_night_ids[fifth_night_ids.size() - 1], "previous_clerk_01", "Night 5 final customer must be previous_clerk_01.")
	_record_current_queue_as_served(5, served_ids)

	var unique_served = _unique_strings(served_ids)
	var all_customer_ids = _get_all_customer_ids()
	unique_served.sort()
	all_customer_ids.sort()
	_assert_equal(served_ids.size(), 30, "Five nights must serve exactly 30 requests.")
	_assert_array_equals(unique_served, all_customer_ids, "Five nights must cover every customer request exactly once.")


func _test_continue_starts_current_night_at_first_customer() -> void:
	_reset_progress_only()
	var save_data = _make_save_after_night_one()
	_write_runtime_save(save_data)

	var continued = _save_manager.continue_game()
	_assert(continued, "Continue should load a valid shop checkpoint save.")
	_assert_equal(_game_manager.current_night, 2, "Continue should restore current night.")
	_assert_equal(_customer_system.current_customer_index, 0, "Continue should reset to the current night's first queue index.")
	_assert_equal(_customer_system.get_current_customer_number(), 1, "Continue should show customer number 1 for the current night.")
	_assert_equal(_customer_system.get_customer_count_for_current_night(), 6, "Continue should rebuild Night 2 queue.")


func _test_new_game_clears_completed_requests() -> void:
	_reset_progress_only()
	var customer = _data_manager.get_customer_by_id("student_exam_01")
	_customer_progress_system.record_customer_result(customer, _make_service_result("new_game_seed", "student_exam_01"))
	_assert(_customer_progress_system.has_completed_request_id("student_exam_01"), "Test setup should mark a completed request.")

	_game_manager.start_new_game(false)
	_assert(_customer_progress_system.get_completed_request_ids().is_empty(), "New Game must clear completed request ids.")
	_assert(_customer_progress_system.get_seen_customers().is_empty(), "New Game must clear seen customers.")


func _test_old_save_without_completed_requests_does_not_crash() -> void:
	_reset_progress_only()
	var old_save = {
		"checkpoint_scene": "shop",
		"current_night": 2,
		"money": 12,
		"inventory": {},
		"unlocked_items": [],
		"seen_customers": ["student_story"],
		"customer_story_progress": {
			"student_story": 1
		},
		"discovered_combos": [],
		"night_stats": {}
	}
	_write_runtime_save(old_save)

	var continued = _save_manager.continue_game()
	_assert(continued, "Old save without completed request ids should still load.")
	var queue_ids = _customer_system.get_current_queue_request_ids()
	_assert(queue_ids.size() > 0, "Old save should rebuild a playable customer queue.")
	_assert_not_has(queue_ids, "student_exam_01", "Old save progress should not repeat student Stage 1.")


func _record_current_queue_as_served(night: int, served_ids: Array[String]) -> void:
	var queue = _customer_system.get_current_customer_queue()
	for index in range(queue.size()):
		var customer: Dictionary = queue[index]
		var request_id := str(customer.get("id", ""))
		served_ids.append(request_id)
		var recorded = _customer_progress_system.record_customer_result(
			customer,
			_make_service_result("queue_validation:%d:%d:%s" % [night, index, request_id], request_id)
		)
		_assert(recorded, "Request should be recorded once: %s." % request_id)


func _assert_student_dialogue_changed_on_stage_two() -> void:
	var stage_one = _data_manager.get_customer_by_id("student_exam_01")
	var stage_two = _data_manager.get_customer_by_id("student_exam_02")
	_assert(
		str(stage_one.get("dialogue", "")) != str(stage_two.get("dialogue", "")),
		"Student Stage 2 dialogue must differ from Stage 1 dialogue."
	)

	var queued_student = _find_customer_in_current_queue("student_exam_02")
	_assert(
		str(queued_student.get("dialogue", "")) == str(stage_two.get("dialogue", "")),
		"Queued student Stage 2 must use the Stage 2 dialogue."
	)


func _make_save_after_night_one() -> Dictionary:
	var save_data = _save_manager.create_default_save()
	save_data["checkpoint_scene"] = "shop"
	save_data["current_night"] = 2
	save_data["money"] = 30
	save_data["inventory"] = _inventory_system.export_inventory_data()
	save_data["completed_request_ids"] = NIGHT_ONE_IDS.duplicate()

	var seen_customers: Array[String] = []
	var progress = {}
	for request_id in NIGHT_ONE_IDS:
		var customer = _data_manager.get_customer_by_id(request_id)
		var story_id := str(customer.get("story_id", ""))
		if not seen_customers.has(story_id):
			seen_customers.append(story_id)
		progress[story_id] = {
			"current_stage": 1,
			"visit_count": 1,
			"best_grade": "good",
			"last_grade": "good",
			"best_score": 75,
			"last_score": 75,
			"total_score": 75,
			"last_customer_request_id": request_id
		}

	save_data["seen_customers"] = seen_customers
	save_data["customer_story_progress"] = progress
	return save_data


func _make_service_result(service_id: String, request_id: String) -> Dictionary:
	return {
		"service_id": service_id,
		"customer_id": request_id,
		"grade": "good",
		"score": 75,
		"income": 0,
		"selected_item_ids": []
	}


func _find_customer_in_current_queue(request_id: String) -> Dictionary:
	for customer in _customer_system.get_current_customer_queue():
		if customer is Dictionary and str(customer.get("id", "")) == request_id:
			return customer.duplicate(true)

	return {}


func _get_all_customer_ids() -> Array[String]:
	var result: Array[String] = []
	for customer in _data_manager.get_all_customers():
		if customer is Dictionary:
			result.append(str(customer.get("id", "")))

	return result


func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)

	return result


func _reset_progress_only() -> void:
	_customer_progress_system.reset_progress()
	_save_manager.current_save = _save_manager.create_default_save()
	_game_manager.set_current_night(1)
	_game_manager.set_money(0)
	_game_manager.last_result = {}
	_game_manager.last_service_result = {}
	_game_manager.pending_customer_id = ""


func _backup_save() -> void:
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if not _save_existed:
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not back up existing save file.")
		return

	_save_backup_text = file.get_as_text()


func _restore_save() -> void:
	if _save_existed:
		_ensure_save_directory()
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			print("WARNING: Could not restore existing save file.")
			return

		file.store_string(_save_backup_text)
		return

	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			print("WARNING: Could not remove temporary save file. Error: %s" % error)


func _write_runtime_save(save_data: Dictionary) -> void:
	_ensure_save_directory()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write runtime save for validation.")
		return

	file.store_string(JSON.stringify(save_data, "\t"))


func _ensure_save_directory() -> void:
	var global_path := ProjectSettings.globalize_path(SAVE_PATH)
	var save_directory := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_recursive_absolute(save_directory)


func _assert(value: bool, message: String) -> void:
	if not value:
		_fail(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_fail("%s Expected: %s Actual: %s" % [message, str(expected), str(actual)])


func _assert_has(values: Array, expected_value: String, message: String) -> void:
	if not values.has(expected_value):
		_fail("%s Missing: %s In: %s" % [message, expected_value, str(values)])


func _assert_not_has(values: Array, unexpected_value: String, message: String) -> void:
	if values.has(unexpected_value):
		_fail("%s Unexpected: %s In: %s" % [message, unexpected_value, str(values)])


func _assert_array_equals(actual: Array, expected: Array, message: String) -> void:
	if actual.size() != expected.size():
		_fail("%s Expected: %s Actual: %s" % [message, str(expected), str(actual)])
		return

	for index in range(expected.size()):
		if actual[index] != expected[index]:
			_fail("%s Expected: %s Actual: %s" % [message, str(expected), str(actual)])
			return


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Customer queue validation passed.")
		quit(0)
		return

	print("Customer queue validation failed.")
	for failure in _failures:
		print(" - %s" % failure)

	quit(1)
