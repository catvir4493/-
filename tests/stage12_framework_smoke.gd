extends SceneTree

const SAVE_PATH := "user://save_data.json"

var _failures: Array[String] = []
var _save_existed := false
var _save_backup_text := ""
var DataManager
var GameManager
var SaveManager
var InventorySystem
var CustomerSystem
var CustomerProgressSystem
var NightStatsSystem
var ChapterSystem
var ContentUnlockSystem
var StoryEventSystem
var EndingSystem


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
	DataManager.reload_data()

	_test_data_manager()
	_test_chapter_system()
	_test_content_unlock_system()
	_test_story_event_system()
	_test_ending_system()
	_test_save_fields_and_continue()
	_test_new_game_and_next_night()
	_test_fixed_night_order()

	_restore_save()
	_finish()


func _bind_autoloads() -> void:
	DataManager = root.get_node_or_null("/root/DataManager")
	GameManager = root.get_node_or_null("/root/GameManager")
	SaveManager = root.get_node_or_null("/root/SaveManager")
	InventorySystem = root.get_node_or_null("/root/InventorySystem")
	CustomerSystem = root.get_node_or_null("/root/CustomerSystem")
	CustomerProgressSystem = root.get_node_or_null("/root/CustomerProgressSystem")
	NightStatsSystem = root.get_node_or_null("/root/NightStatsSystem")
	ChapterSystem = root.get_node_or_null("/root/ChapterSystem")
	ContentUnlockSystem = root.get_node_or_null("/root/ContentUnlockSystem")
	StoryEventSystem = root.get_node_or_null("/root/StoryEventSystem")
	EndingSystem = root.get_node_or_null("/root/EndingSystem")
	var autoloads := {
		"DataManager": DataManager,
		"GameManager": GameManager,
		"SaveManager": SaveManager,
		"InventorySystem": InventorySystem,
		"CustomerSystem": CustomerSystem,
		"CustomerProgressSystem": CustomerProgressSystem,
		"NightStatsSystem": NightStatsSystem,
		"ChapterSystem": ChapterSystem,
		"ContentUnlockSystem": ContentUnlockSystem,
		"StoryEventSystem": StoryEventSystem,
		"EndingSystem": EndingSystem
	}
	for autoload_name in autoloads.keys():
		_assert(autoloads[autoload_name] != null, "%s autoload must exist." % autoload_name)


func _test_data_manager() -> void:
	_assert_equal(DataManager.get_all_chapters().size(), 1, "DataManager must load chapters.json.")
	_assert_equal(DataManager.get_all_story_events().size(), 3, "DataManager must load story_events.json.")
	_assert_equal(DataManager.get_all_endings().size(), 1, "DataManager must load endings.json.")
	_assert_equal(DataManager.get_chapter_by_id("chapter_01").get("id", ""), "chapter_01", "Chapter lookup must work.")
	_assert_equal(DataManager.get_story_event_by_id("event_previous_clerk_final").get("id", ""), "event_previous_clerk_final", "Story event lookup must work.")
	_assert_equal(DataManager.get_ending_by_id("ending_mvp_placeholder").get("id", ""), "ending_mvp_placeholder", "Ending lookup must work.")


func _test_chapter_system() -> void:
	ChapterSystem.reset_chapter_progress()
	for night_number in [1, 2, 3, 4, 5]:
		_assert_equal(ChapterSystem.get_chapter_for_night(night_number).get("id", ""), "chapter_01", "Night %d must belong to chapter_01." % night_number)
	_assert(ChapterSystem.mark_chapter_completed("chapter_01"), "chapter_01 must be markable as completed.")
	_assert(ChapterSystem.is_chapter_completed("chapter_01"), "chapter_01 completion must be recorded.")


func _test_content_unlock_system() -> void:
	GameManager.set_current_night(1)
	CustomerProgressSystem.reset_progress()
	_assert(ContentUnlockSystem.is_item_unlocked("coffee"), "Night 1 item must be unlocked.")
	_assert(not ContentUnlockSystem.is_item_unlocked("coin"), "Night 5 item must remain locked on Night 1.")
	var request: Dictionary = DataManager.get_customer_by_id("student_exam_01")
	_assert(ContentUnlockSystem.is_customer_request_available(request), "Eligible customer request must be available.")
	CustomerProgressSystem.mark_request_completed("student_exam_01")
	_assert(not ContentUnlockSystem.is_customer_request_available(request), "Completed one-time request must be unavailable.")


func _test_story_event_system() -> void:
	StoryEventSystem.reset_events()
	var start_context := {"type": "night_start", "night": 1, "chapter_id": "chapter_01"}
	_assert_equal(StoryEventSystem.get_available_events(start_context).size(), 1, "chapter_start event must trigger.")
	_assert_equal(StoryEventSystem.get_available_events(start_context).size(), 0, "one_time chapter_start event must not repeat.")
	var final_context := {
		"type": "customer_result",
		"night": 5,
		"story_id": "previous_clerk_story",
		"story_stage": 3
	}
	_assert_equal(StoryEventSystem.get_available_events(final_context).size(), 1, "Previous clerk final event must trigger.")


func _test_ending_system() -> void:
	GameManager.set_current_night(5)
	ChapterSystem.reset_chapter_progress()
	EndingSystem.reset_endings()
	_assert_equal(EndingSystem.get_available_endings().size(), 0, "Ending must be unavailable before chapter completion.")
	_assert(not EndingSystem.unlock_ending("ending_mvp_placeholder"), "Ending must not unlock before chapter completion.")
	ChapterSystem.mark_chapter_completed("chapter_01")
	_assert_equal(EndingSystem.get_available_endings().size(), 1, "Placeholder ending must become available after chapter completion.")
	_assert(EndingSystem.unlock_ending("ending_mvp_placeholder"), "Placeholder ending must unlock after chapter completion.")


func _test_save_fields_and_continue() -> void:
	StoryEventSystem.mark_event_triggered("event_chapter_01_completed")
	CustomerProgressSystem.reset_progress()
	GameManager.set_current_night(1)
	var save_data: Dictionary = SaveManager.create_save_data("shop")
	_assert(save_data.has("completed_chapters"), "Save data must include completed_chapters.")
	_assert(save_data.has("triggered_story_events"), "Save data must include triggered_story_events.")
	_assert(save_data.has("unlocked_endings"), "Save data must include unlocked_endings.")
	_assert_equal(save_data.get("save_version", 0), 1, "save_version must remain 1.")

	ChapterSystem.reset_chapter_progress()
	StoryEventSystem.reset_events()
	EndingSystem.reset_endings()
	_assert(SaveManager.apply_save_data(save_data, false), "Continue data must apply without changing scene.")
	_assert(ChapterSystem.is_chapter_completed("chapter_01"), "Continue must restore completed chapters.")
	_assert(StoryEventSystem.has_triggered_event("event_chapter_01_completed"), "Continue must restore triggered story events.")
	_assert(EndingSystem.has_unlocked_ending("ending_mvp_placeholder"), "Continue must restore unlocked endings.")


func _test_new_game_and_next_night() -> void:
	GameManager.set_current_night(1)
	CustomerProgressSystem.import_progress_data({
		"seen_customers": ["student_story"],
		"customer_story_progress": {
			"student_story": {"current_stage": 1, "visit_count": 1}
		},
		"completed_request_ids": []
	})
	ChapterSystem.reset_chapter_progress()
	ChapterSystem.mark_chapter_completed("chapter_01")
	StoryEventSystem.reset_events()
	StoryEventSystem.mark_event_triggered("event_previous_clerk_final")
	EndingSystem.reset_endings()
	GameManager.set_current_night(5)
	EndingSystem.unlock_ending("ending_mvp_placeholder")
	GameManager.set_current_night(1)
	GameManager.start_next_night(false)
	_assert(ChapterSystem.is_chapter_completed("chapter_01"), "Start Next Night must keep chapter progress.")
	_assert(StoryEventSystem.has_triggered_event("event_previous_clerk_final"), "Start Next Night must keep event progress.")
	_assert(EndingSystem.has_unlocked_ending("ending_mvp_placeholder"), "Start Next Night must keep ending progress.")

	GameManager.start_new_game(false)
	_assert_equal(ChapterSystem.get_completed_chapters(), [], "New Game must clear chapter progress.")
	_assert_equal(EndingSystem.get_unlocked_endings(), [], "New Game must clear ending progress.")
	_assert(not StoryEventSystem.has_triggered_event("event_previous_clerk_final"), "New Game must clear old event progress.")
	_assert(StoryEventSystem.has_triggered_event("event_chapter_01_started"), "New Game may immediately record the Night 1 start event.")


func _test_fixed_night_order() -> void:
	var expected := {
		1: ["student_exam_01", "overtime_worker_01", "silent_old_man_01", "masked_boy_01", "insomnia_driver_01"],
		2: ["wet_man_01", "red_dress_woman_01", "lost_child_01", "nameless_guest_01", "previous_clerk_hint_01", "student_exam_02"],
		3: ["overtime_worker_02", "silent_old_man_02", "masked_boy_02", "insomnia_driver_02", "wet_man_02", "red_dress_woman_02", "student_exam_03"],
		4: ["lost_child_02", "nameless_guest_02", "previous_clerk_02", "overtime_worker_03", "silent_old_man_03", "masked_boy_03", "insomnia_driver_03", "wet_man_03"],
		5: ["red_dress_woman_03", "lost_child_03", "nameless_guest_03", "previous_clerk_01"]
	}
	for night_number in [1, 2, 3, 4, 5]:
		var actual := []
		for slot in DataManager.get_night_config(night_number).get("customer_slots", []):
			var request: Dictionary = DataManager.get_customer_request_by_story_stage(str(slot.get("story_id", "")), int(slot.get("story_stage", 0)))
			actual.append(str(request.get("id", "")))
		_assert_equal(actual, expected[night_number], "Night %d fixed order must not change." % night_number)


func _backup_save() -> void:
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if not _save_existed:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file != null:
		_save_backup_text = file.get_as_text()


func _restore_save() -> void:
	if _save_existed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_save_backup_text)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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
		print("Stage 12 framework smoke test passed.")
		quit(0)
		return

	print("Stage 12 framework smoke test failed.")
	for failure in _failures:
		print(" - %s" % failure)
	quit(1)
