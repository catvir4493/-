extends SceneTree

const EXPECTED := {
	1: [["student_story",1],["worker_story",1],["old_man_story",1],["masked_boy_story",1],["driver_story",1]],
	2: [["wet_man_story",1],["red_dress_story",1],["lost_child_story",1],["nameless_story",1],["previous_clerk_story",1],["student_story",2]],
	3: [["worker_story",2],["old_man_story",2],["masked_boy_story",2],["driver_story",2],["wet_man_story",2],["red_dress_story",2],["student_story",3]],
	4: [["lost_child_story",2],["nameless_story",2],["previous_clerk_story",2],["worker_story",3],["old_man_story",3],["masked_boy_story",3],["driver_story",3],["wet_man_story",3]],
	5: [["red_dress_story",3],["lost_child_story",3],["nameless_story",3],["previous_clerk_story",3]],
	6: [["night_nurse_story",1],["divorced_father_story",1],["student_story",4],["worker_story",1],["driver_story",1]],
	7: [["previous_clerk_story",4],["night_nurse_story",1],["divorced_father_story",1],["worker_story",1],["driver_story",1]],
	8: [["night_nurse_story",2],["night_nurse_story",1],["divorced_father_story",1],["worker_story",1],["driver_story",1]],
	9: [["divorced_father_story",2],["driver_story",4],["night_nurse_story",1],["worker_story",1],["driver_story",1]],
	10: [["night_nurse_story",3],["divorced_father_story",3],["worker_story",1],["driver_story",1],["previous_clerk_story",5]]
}

var failures: Array[String] = []
var CustomerSystem
var CustomerProgressSystem


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	CustomerSystem = root.get_node_or_null("/root/CustomerSystem")
	CustomerProgressSystem = root.get_node_or_null("/root/CustomerProgressSystem")
	CustomerProgressSystem.reset_progress()
	for night_number in range(1, 11):
		var config: Dictionary = root.get_node("/root/DataManager").get_night_config(night_number)
		_assert(not config.is_empty(), "Night %d config must exist." % night_number)
		var actual := []
		for slot in config.get("customer_slots", []):
			actual.append([str(slot.get("story_id", "")), int(slot.get("story_stage", 0))])
		_assert_equal(actual, EXPECTED[night_number], "Night %d fixed order must remain exact." % night_number)
		var resolved: Array = CustomerSystem.resolve_night_customer_slots(config)
		_assert_equal(resolved.size(), actual.size(), "Night %d slots must all resolve." % night_number)
		_assert(CustomerSystem.build_queue_for_night(night_number), "Night %d must build a playable queue with sequential progress." % night_number)
		var runtime_pairs := []
		var runtime_queue: Array = CustomerSystem.get_current_customer_queue()
		for index in range(runtime_queue.size()):
			var customer: Dictionary = runtime_queue[index]
			runtime_pairs.append([str(customer.get("story_id", "")), int(customer.get("story_stage", 0))])
			CustomerProgressSystem.record_customer_result(customer, {"service_id":"stage16-schedule:%d:%d" % [night_number,index], "score":80, "grade":"good", "selected_item_ids":["coffee"]})
		_assert_equal(runtime_pairs, EXPECTED[night_number], "Night %d runtime queue must not fall back." % night_number)
	var final_slot: Dictionary = root.get_node("/root/DataManager").get_night_config(10).get("customer_slots", [])[-1]
	_assert(str(final_slot.get("story_id", "")) == "previous_clerk_story" and int(final_slot.get("story_stage", 0)) == 5, "Night 10 last customer must be previous_clerk_story Stage 5.")
	_finish()


func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected: failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("Stage 16 night schedule smoke test passed.")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)
