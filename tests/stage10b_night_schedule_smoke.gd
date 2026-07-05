extends SceneTree

const SAVE_PATH := "user://save_data.json"
const EXPECTED_SCHEDULE := {
	1: [
		["student_story", 1],
		["worker_story", 1],
		["old_man_story", 1],
		["masked_boy_story", 1],
		["driver_story", 1]
	],
	2: [
		["wet_man_story", 1],
		["red_dress_story", 1],
		["lost_child_story", 1],
		["nameless_story", 1],
		["previous_clerk_story", 1],
		["student_story", 2]
	],
	3: [
		["worker_story", 2],
		["old_man_story", 2],
		["masked_boy_story", 2],
		["driver_story", 2],
		["wet_man_story", 2],
		["red_dress_story", 2],
		["student_story", 3]
	],
	4: [
		["lost_child_story", 2],
		["nameless_story", 2],
		["previous_clerk_story", 2],
		["worker_story", 3],
		["old_man_story", 3],
		["masked_boy_story", 3],
		["driver_story", 3],
		["wet_man_story", 3]
	],
	5: [
		["red_dress_story", 3],
		["lost_child_story", 3],
		["nameless_story", 3],
		["previous_clerk_story", 3]
	]
}

var _failures: Array[String] = []
var _save_existed := false
var _save_backup_text := ""
var _data_manager
var _save_manager
var _inventory_system
var _customer_system
var _customer_progress_system
var _game_manager
var _night_stats_system


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

	_data_manager.reload_data()

	_test_new_game_night_one()
	_test_five_night_fixed_schedule_and_completion()
	_test_completed_request_id_uniqueness()
	_test_start_next_night_keeps_completed_requests()
	_test_save_and_continue_completed_requests()
	await process_frame
	_test_old_save_without_completed_requests()
	await process_frame
	_test_post_fifth_night_fallback()

	_restore_save()
	_finish()


func _bind_autoloads() -> void:
	_data_manager = root.get_node_or_null("/root/DataManager")
	_save_manager = root.get_node_or_null("/root/SaveManager")
	_inventory_system = root.get_node_or_null("/root/InventorySystem")
	_customer_system = root.get_node_or_null("/root/CustomerSystem")
	_customer_progress_system = root.get_node_or_null("/root/CustomerProgressSystem")
	_game_manager = root.get_node_or_null("/root/GameManager")
	_night_stats_system = root.get_node_or_null("/root/NightStatsSystem")

	_assert(_data_manager != null, "DataManager autoload must exist.")
	_assert(_save_manager != null, "SaveManager autoload must exist.")
	_assert(_inventory_system != null, "InventorySystem autoload must exist.")
	_assert(_customer_system != null, "CustomerSystem autoload must exist.")
	_assert(_customer_progress_system != null, "CustomerProgressSystem autoload must exist.")
	_assert(_game_manager != null, "GameManager autoload must exist.")
	_assert(_night_stats_system != null, "NightStatsSystem autoload must exist.")


func _test_new_game_night_one() -> void:
	_reset_runtime()
	_game_manager.start_new_game(false)
	_assert_equal(_game_manager.current_night, 1, "New Game must start on Night 1.")
	_assert_queue_matches_expected(1, "New Game Night 1 queue")


func _test_five_night_fixed_schedule_and_completion() -> void:
	_reset_runtime()
	var first_run = {}
	var second_run = {}

	for night in [1, 2, 3, 4, 5]:
		_customer_system.build_queue_for_night(night)
		first_run[night] = _queue_story_stage_pairs()
		_assert_queue_matches_expected(night, "Night %d queue" % night)
		_record_current_queue_as_served(night)

	_reset_runtime()
	for night in [1, 2, 3, 4, 5]:
		_customer_system.build_queue_for_night(night)
		second_run[night] = _queue_story_stage_pairs()
		_assert_equal(second_run[night], first_run[night], "Night %d queue must be reproducible." % night)
		_record_current_queue_as_served(night)

	var completed_ids = _customer_progress_system.get_completed_request_ids()
	_assert_equal(completed_ids.size(), 30, "Five nights must complete exactly 30 requests.")
	_assert_equal(_unique_strings(completed_ids).size(), 30, "Each completed request id must be unique.")

	var final_customer = _customer_system.get_current_customer_queue()[3]
	_assert_equal(str(final_customer.get("story_id", "")), "previous_clerk_story", "Night 5 final story must be previous_clerk_story.")
	_assert_equal(int(final_customer.get("story_stage", 0)), 3, "Night 5 final stage must be Stage 3.")
	_assert(str(final_customer.get("dialogue", "")).contains("我想买回我离开这里的理由。"), "Night 5 final dialogue must keep the required line.")


func _test_completed_request_id_uniqueness() -> void:
	_reset_runtime()
	var request = _data_manager.get_customer_request_by_story_stage("student_story", 1)
	var first_marked = _customer_progress_system.mark_request_completed(str(request.get("id", "")))
	var second_marked = _customer_progress_system.mark_request_completed(str(request.get("id", "")))
	_assert(first_marked, "mark_request_completed should add a new request id.")
	_assert(not second_marked, "mark_request_completed should not add a duplicate request id.")
	_assert_equal(_customer_progress_system.get_completed_request_ids().count(str(request.get("id", ""))), 1, "Completed request id should appear only once.")


func _test_start_next_night_keeps_completed_requests() -> void:
	_reset_runtime()
	_game_manager.start_new_game(false)
	var customer = _customer_system.get_current_customer()
	_customer_progress_system.record_customer_result(customer, _make_service_result("next_night_keep", str(customer.get("id", ""))))
	var completed_before = _customer_progress_system.get_completed_request_ids()
	_game_manager.start_next_night(false)
	var completed_after = _customer_progress_system.get_completed_request_ids()
	_assert_equal(_game_manager.current_night, 2, "Start Next Night must advance current_night once.")
	_assert_equal(completed_after, completed_before, "Start Next Night must keep completed_request_ids.")


func _test_save_and_continue_completed_requests() -> void:
	_reset_runtime()
	_record_expected_night_as_served(1)
	_game_manager.set_current_night(2)
	_game_manager.set_money(42)
	_customer_system.build_queue_for_night(2)
	_night_stats_system.start_night(2)
	_save_manager.save_game("shop")
	var saved_completed = _customer_progress_system.get_completed_request_ids()

	_reset_runtime()
	var continued = _save_manager.continue_game()
	_assert(continued, "Continue should load the saved shop checkpoint.")
	_assert_equal(_game_manager.current_night, 2, "Continue must not increase current_night.")
	_assert_equal(_customer_system.current_customer_index, 0, "Continue from shop checkpoint must start at first customer.")
	_assert_equal(_customer_system.get_current_customer_number(), 1, "Continue must show the first customer number.")
	_assert_equal(_customer_progress_system.get_completed_request_ids(), saved_completed, "Continue must restore completed_request_ids.")


func _test_old_save_without_completed_requests() -> void:
	_reset_runtime()
	var old_save = _save_manager.create_default_save()
	old_save.erase("completed_request_ids")
	old_save["checkpoint_scene"] = "shop"
	old_save["current_night"] = 2
	old_save["money"] = 5
	old_save["inventory"] = _inventory_system.export_inventory_data()
	old_save["seen_customers"] = ["student_story"]
	old_save["customer_story_progress"] = {
		"student_story": {
			"current_stage": 1,
			"visit_count": 1,
			"best_grade": "good",
			"last_grade": "good",
			"best_score": 75,
			"last_score": 75,
			"total_score": 75,
			"last_customer_request_id": "student_exam_01"
		}
	}
	_write_runtime_save(old_save)

	var continued = _save_manager.continue_game()
	_assert(continued, "Old save without completed_request_ids must load.")
	_assert_equal(_game_manager.current_night, 2, "Old save Continue must not increase current_night.")
	_assert(_customer_system.get_customer_count_for_current_night() > 0, "Old save Continue must rebuild a playable queue.")
	_assert(_customer_progress_system.get_completed_request_ids().is_empty(), "Old save missing completed_request_ids defaults to an empty Array.")


func _test_post_fifth_night_fallback() -> void:
	_reset_runtime()
	for night in [1, 2, 3, 4, 5]:
		_record_expected_night_as_served(night)

	_customer_system.build_queue_for_night(6)
	var first_fallback_ids = _customer_system.get_current_queue_request_ids()
	_customer_system.build_queue_for_night(6)
	var second_fallback_ids = _customer_system.get_current_queue_request_ids()

	_assert(first_fallback_ids.size() > 0, "Night > 5 fallback queue must not be empty.")
	_assert(first_fallback_ids.size() <= 8, "Night > 5 fallback queue must have at most 8 customers.")
	_assert_equal(first_fallback_ids, second_fallback_ids, "Night > 5 fallback queue must be deterministic.")

	for customer in _customer_system.get_current_customer_queue():
		_assert(
			not (str(customer.get("story_id", "")) == "previous_clerk_story" and int(customer.get("story_stage", 0)) == 3),
			"Fallback queue must not include previous_clerk_story Stage 3."
		)
		if bool(customer.get("one_time", false)):
			_assert(not _customer_progress_system.has_completed_request(str(customer.get("id", ""))), "Fallback queue must not include completed one_time requests.")


func _assert_queue_matches_expected(night: int, context: String) -> void:
	var expected: Array = EXPECTED_SCHEDULE[night]
	var actual := _queue_story_stage_pairs()
	_assert_equal(actual.size(), expected.size(), "%s must have %d customers." % [context, expected.size()])
	for index in range(min(actual.size(), expected.size())):
		_assert_equal(actual[index], expected[index], "%s slot %d must match story_id + story_stage." % [context, index + 1])


func _queue_story_stage_pairs() -> Array:
	var result: Array = []
	for customer in _customer_system.get_current_customer_queue():
		result.append([str(customer.get("story_id", "")), int(customer.get("story_stage", 0))])

	return result


func _record_expected_night_as_served(night: int) -> void:
	_customer_system.build_queue_for_night(night)
	_record_current_queue_as_served(night)


func _record_current_queue_as_served(night: int) -> void:
	var queue = _customer_system.get_current_customer_queue()
	for index in range(queue.size()):
		var customer: Dictionary = queue[index]
		var request_id := str(customer.get("id", ""))
		var recorded = _customer_progress_system.record_customer_result(
			customer,
			_make_service_result("stage10b:%d:%d:%s" % [night, index, request_id], request_id)
		)
		_assert(recorded, "Request should record once: %s." % request_id)


func _make_service_result(service_id: String, request_id: String) -> Dictionary:
	return {
		"service_id": service_id,
		"customer_id": request_id,
		"grade": "good",
		"score": 75,
		"income": 0,
		"selected_item_ids": []
	}


func _reset_runtime() -> void:
	_customer_progress_system.reset_progress()
	_save_manager.current_save = _save_manager.create_default_save()
	_inventory_system.reset_to_default_stock()
	_customer_system.reset_queue()
	_game_manager.set_current_night(1)
	_game_manager.set_money(0)
	_game_manager.last_result = {}
	_game_manager.last_service_result = {}
	_game_manager.pending_customer_id = ""
	_night_stats_system.start_night(1)


func _unique_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := str(value)
		if not result.has(text):
			result.append(text)

	return result


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
		_fail("Could not write runtime save for smoke test.")
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


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Smoke test passed.")
		quit(0)
		return

	print("Smoke test failed.")
	for failure in _failures:
		print(" - %s" % failure)

	quit(1)
