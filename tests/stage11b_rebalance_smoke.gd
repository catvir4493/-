extends SceneTree

const EXPECTED_NIGHT_REQUEST_IDS := {
	1: ["student_exam_01", "overtime_worker_01", "silent_old_man_01", "masked_boy_01", "insomnia_driver_01"],
	2: ["wet_man_01", "red_dress_woman_01", "lost_child_01", "nameless_guest_01", "previous_clerk_hint_01", "student_exam_02"],
	3: ["overtime_worker_02", "silent_old_man_02", "masked_boy_02", "insomnia_driver_02", "wet_man_02", "red_dress_woman_02", "student_exam_03"],
	4: ["lost_child_02", "nameless_guest_02", "previous_clerk_02", "overtime_worker_03", "silent_old_man_03", "masked_boy_03", "insomnia_driver_03", "wet_man_03"],
	5: ["red_dress_woman_03", "lost_child_03", "nameless_guest_03", "previous_clerk_01"]
}

var _failures: Array[String] = []
var _data_manager
var _score_system
var _chapter_system
var _content_unlock_system
var _story_event_system
var _ending_system


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_bind_autoloads()
	if not _failures.is_empty():
		_finish()
		return

	_data_manager.reload_data()
	_test_income_formula()
	_test_rebalanced_items()
	_test_customer_solvability()
	_test_combos()
	_test_fixed_night_order()
	_test_stage12_compatibility()
	_finish()


func _bind_autoloads() -> void:
	_data_manager = root.get_node_or_null("/root/DataManager")
	_score_system = root.get_node_or_null("/root/ScoreSystem")
	_chapter_system = root.get_node_or_null("/root/ChapterSystem")
	_content_unlock_system = root.get_node_or_null("/root/ContentUnlockSystem")
	_story_event_system = root.get_node_or_null("/root/StoryEventSystem")
	_ending_system = root.get_node_or_null("/root/EndingSystem")

	var required_autoloads := {
		"DataManager": _data_manager,
		"ScoreSystem": _score_system,
		"ChapterSystem": _chapter_system,
		"ContentUnlockSystem": _content_unlock_system,
		"StoryEventSystem": _story_event_system,
		"EndingSystem": _ending_system
	}
	for autoload_name in required_autoloads.keys():
		_assert(required_autoloads[autoload_name] != null, "%s autoload must exist." % autoload_name)


func _test_income_formula() -> void:
	_assert_equal(_score_system.call("_calculate_income", 10, 999, "perfect"), 20, "Perfect income must be sell total + 10 and ignore base_reward.")
	_assert_equal(_score_system.call("_calculate_income", 10, 999, "good"), 15, "Good income must be sell total + 5 and ignore base_reward.")
	_assert_equal(_score_system.call("_calculate_income", 10, 999, "normal"), 10, "Normal income must be sell total + 0 and ignore base_reward.")
	_assert_equal(_score_system.call("_calculate_income", 10, 999, "fail"), 8, "Fail income must be sell total - 2 and ignore base_reward.")
	_assert_equal(_score_system.call("_calculate_income", 0, 999, "fail"), 0, "Income must never be negative.")

	var customer := {
		"id": "stage11b_income_probe",
		"required_tags": [],
		"avoid_tags": [],
		"base_reward": 1000
	}
	var result: Dictionary = _score_system.calculate_score(customer, ["coffee"])
	_assert_equal(result.get("income", -1), 4, "Public score result must not include customer.base_reward.")


func _test_rebalanced_items() -> void:
	var milk: Dictionary = _data_manager.get_item_by_id("milk")
	var milk_tags := _string_array(milk.get("tags", []))
	_assert_equal(milk_tags, ["睡眠", "温和"], "milk tags must exactly match Stage 11B.")
	_assert(not milk_tags.has("安慰"), "milk must not contain 安慰.")

	var old_photo: Dictionary = _data_manager.get_item_by_id("old_photo")
	var old_photo_tags := _string_array(old_photo.get("tags", []))
	_assert_equal(int(old_photo.get("buy_price", -1)), 2, "old_photo buy_price must be 2.")
	_assert_equal(int(old_photo.get("max_stock", -1)), 1, "old_photo max_stock must remain 1.")
	_assert_equal(old_photo_tags, ["回忆", "悲伤"], "old_photo tags must exactly match Stage 11B.")
	_assert(not old_photo_tags.has("真实"), "old_photo must not contain 真实.")


func _test_customer_solvability() -> void:
	var customers: Array = _data_manager.get_all_customers()
	_assert_equal(customers.size(), 30, "Exactly 30 customer requests must remain.")
	var blocker_count := 0
	for customer in customers:
		if not (customer is Dictionary):
			blocker_count += 1
			continue

		if not _has_good_solution(customer):
			blocker_count += 1
			_fail("Customer %s must retain at least one legal score >= 70 solution." % str(customer.get("id", "")))

	_assert_equal(blocker_count, 0, "Stage 11B solvability blocker count must be 0.")


func _has_good_solution(customer: Dictionary) -> bool:
	var available_item_ids: Array[String] = []
	var scheduled_night := _get_scheduled_night(customer)
	for item in _data_manager.get_all_items():
		if item is Dictionary and int(item.get("unlock_day", 1)) <= scheduled_night:
			available_item_ids.append(str(item.get("id", "")))

	for first in range(available_item_ids.size()):
		if _score_for(customer, [available_item_ids[first]]) >= 70:
			return true
		for second in range(first + 1, available_item_ids.size()):
			if _score_for(customer, [available_item_ids[first], available_item_ids[second]]) >= 70:
				return true
			for third in range(second + 1, available_item_ids.size()):
				if _score_for(customer, [available_item_ids[first], available_item_ids[second], available_item_ids[third]]) >= 70:
					return true

	return false


func _get_scheduled_night(customer: Dictionary) -> int:
	var story_id := str(customer.get("story_id", ""))
	var story_stage := int(customer.get("story_stage", 0))
	for night_number in [1, 2, 3, 4, 5]:
		for slot in _data_manager.get_night_config(night_number).get("customer_slots", []):
			if not (slot is Dictionary):
				continue
			if str(slot.get("story_id", "")) == story_id and int(slot.get("story_stage", 0)) == story_stage:
				return night_number

	return int(customer.get("min_night", 1))


func _score_for(customer: Dictionary, item_ids: Array) -> int:
	return int(_score_system.calculate_score(customer, item_ids).get("score", 0))


func _test_combos() -> void:
	var combos: Array = _data_manager.get_all_combos()
	_assert_equal(combos.size(), 9, "Exactly 9 combos must remain.")
	var critical_count := 0
	var seen_ids := {}
	for combo in combos:
		if not (combo is Dictionary):
			critical_count += 1
			continue

		var combo_id := str(combo.get("id", combo.get("combo_id", "")))
		var required_items = combo.get("required_items", combo.get("required_item_ids", []))
		if combo_id.is_empty() or seen_ids.has(combo_id):
			critical_count += 1
		seen_ids[combo_id] = true
		if not (required_items is Array) or required_items.is_empty():
			critical_count += 1
			continue
		for item_id in required_items:
			if _data_manager.get_item_by_id(str(item_id)).is_empty():
				critical_count += 1

	_assert_equal(critical_count, 0, "Stage 11B combo critical count must be 0.")


func _test_fixed_night_order() -> void:
	for night_number in [1, 2, 3, 4, 5]:
		var actual_request_ids := []
		var night: Dictionary = _data_manager.get_night_config(night_number)
		for slot in night.get("customer_slots", []):
			if not (slot is Dictionary):
				continue
			var request: Dictionary = _data_manager.get_customer_request_by_story_stage(
				str(slot.get("story_id", "")),
				int(slot.get("story_stage", 0))
			)
			actual_request_ids.append(str(request.get("id", "")))

		_assert_equal(actual_request_ids, EXPECTED_NIGHT_REQUEST_IDS[night_number], "Night %d order must not change." % night_number)

	var night_five_slots: Array = _data_manager.get_night_config(5).get("customer_slots", [])
	var final_slot: Dictionary = night_five_slots[night_five_slots.size() - 1]
	_assert_equal(str(final_slot.get("story_id", "")), "previous_clerk_story", "Night 5 final story must remain previous_clerk_story.")
	_assert_equal(int(final_slot.get("story_stage", 0)), 3, "Night 5 final story stage must remain 3.")


func _test_stage12_compatibility() -> void:
	_assert_equal(_data_manager.get_chapter_by_id("chapter_01").get("id", ""), "chapter_01", "Stage 12 chapter data must remain available.")
	_assert_equal(_data_manager.get_story_event_by_id("event_previous_clerk_final").get("id", ""), "event_previous_clerk_final", "Stage 12 story event data must remain available.")
	_assert_equal(_data_manager.get_ending_by_id("ending_mvp_placeholder").get("id", ""), "ending_mvp_placeholder", "Stage 12 ending data must remain available.")
	_assert(_chapter_system.has_method("mark_chapter_completed"), "ChapterSystem API must remain intact.")
	_assert(_content_unlock_system.has_method("is_item_unlocked"), "ContentUnlockSystem API must remain intact.")
	_assert(_story_event_system.has_method("get_available_events"), "StoryEventSystem API must remain intact.")
	_assert(_ending_system.has_method("get_available_endings"), "EndingSystem API must remain intact.")


func _string_array(value) -> Array:
	var values := []
	if value is Array:
		for entry in value:
			values.append(str(entry))
	return values


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
		print("Stage 11B rebalance smoke test passed.")
		quit(0)
		return

	print("Stage 11B rebalance smoke test failed.")
	for failure in _failures:
		print(" - %s" % failure)
	quit(1)
