extends SceneTree

const NEW_ITEMS := ["canned_peach", "instant_noodles", "blue_pen", "paper_cup"]
const NEW_REQUESTS := ["night_nurse_01", "night_nurse_02", "night_nurse_03", "breakfast_man_01", "breakfast_man_02", "breakfast_man_03", "student_after_exam_04", "driver_rest_04", "previous_clerk_04", "previous_clerk_05"]
const NEW_COMBOS := ["combo_write_it_down", "combo_childhood_flavor", "combo_sit_for_a_while"]
const NEW_EVENTS := ["event_ch2_begin", "event_nurse_resignation", "event_breakfast_apology", "event_ch2_complete"]

var failures: Array[String] = []
var DataManager
var GameManager
var CustomerSystem
var CustomerProgressSystem
var ChapterSystem
var ContentUnlockSystem
var StoryEventSystem
var SaveManager
var SettingsManager
var AssetRegistry


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_bind()
	_test_data_and_unlocks()
	_test_progress_and_events()
	_test_old_save_compatibility()
	await _test_archive_and_ui()
	_test_versions_and_assets()
	_finish()


func _bind() -> void:
	for name in ["DataManager","GameManager","CustomerSystem","CustomerProgressSystem","ChapterSystem","ContentUnlockSystem","StoryEventSystem","SaveManager","SettingsManager","AssetRegistry"]:
		set(name, root.get_node_or_null("/root/%s" % name))
		_assert(get(name) != null, "%s must exist." % name)


func _test_data_and_unlocks() -> void:
	var chapter: Dictionary = DataManager.get_chapter_by_id("chapter_02")
	_assert(int(chapter.get("start_night", 0)) == 6 and int(chapter.get("end_night", 0)) == 10, "chapter_02 must cover Night 6-10.")
	for night_number in range(6, 11):
		var config: Dictionary = DataManager.get_night_config(night_number)
		_assert(not config.is_empty(), "Night %d must exist." % night_number)
		_assert(CustomerSystem.resolve_night_customer_slots(config).size() == config.get("customer_slots", []).size(), "Night %d queue must resolve." % night_number)
	for story_id in ["night_nurse_story", "divorced_father_story"]:
		_assert(not DataManager.get_customer_profile_by_story_id(story_id).is_empty(), "New story profile must resolve: %s." % story_id)
	for request_id in NEW_REQUESTS:
		_assert(not DataManager.get_customer_by_id(request_id).is_empty(), "New request must resolve: %s." % request_id)
	for item_id in NEW_ITEMS:
		_assert(not DataManager.get_item_by_id(item_id).is_empty(), "New item must resolve: %s." % item_id)
	for combo_id in NEW_COMBOS:
		_assert(not DataManager.get_combo_by_id(combo_id).is_empty(), "New combo must resolve: %s." % combo_id)
	GameManager.set_current_night(5)
	for item_id in NEW_ITEMS:
		_assert(not ContentUnlockSystem.is_item_unlocked(item_id), "New item must remain locked in Chapter 1: %s." % item_id)
	GameManager.set_current_night(6)
	_assert(ContentUnlockSystem.is_item_unlocked("canned_peach") and ContentUnlockSystem.is_item_unlocked("instant_noodles"), "Night 6 items must unlock.")
	_assert(not ContentUnlockSystem.is_item_unlocked("blue_pen"), "blue_pen must wait until Night 7.")
	GameManager.set_current_night(7)
	_assert(ContentUnlockSystem.is_item_unlocked("blue_pen"), "blue_pen must unlock on Night 7.")
	GameManager.set_current_night(8)
	_assert(ContentUnlockSystem.is_item_unlocked("paper_cup"), "paper_cup must unlock on Night 8.")
	var final_slot: Dictionary = DataManager.get_night_config(10).get("customer_slots", [])[-1]
	_assert(str(final_slot.get("story_id", "")) == "previous_clerk_story" and int(final_slot.get("story_stage", 0)) == 5, "Night 10 final customer must be previous clerk Stage 5.")


func _test_progress_and_events() -> void:
	CustomerProgressSystem.reset_progress()
	var stage_four: Dictionary = DataManager.get_customer_by_id("student_after_exam_04")
	var stage_five: Dictionary = DataManager.get_customer_by_id("previous_clerk_05")
	_assert(CustomerProgressSystem.record_customer_result(stage_four, _result("stage16-stage4")), "CustomerProgress must record Stage 4.")
	_assert(CustomerProgressSystem.get_archive_stage("student_story") == 4, "Archive progress must reach Stage 4.")
	_assert(CustomerProgressSystem.record_customer_result(stage_five, _result("stage16-stage5")), "CustomerProgress must record Stage 5.")
	_assert(CustomerProgressSystem.get_archive_stage("previous_clerk_story") == 5, "Archive progress must reach Stage 5 without a hardcoded cap.")
	ChapterSystem.reset_chapter_progress()
	_assert(ChapterSystem.mark_chapter_completed("chapter_01"), "Chapter 1 completion must remain recordable.")
	_assert(ChapterSystem.mark_chapter_completed("chapter_02"), "Chapter 2 completion must be recordable.")
	StoryEventSystem.reset_events()
	var contexts := [
		{"type":"night_start","night":6,"chapter_id":"chapter_02"},
		{"type":"customer_result","night":10,"story_id":"night_nurse_story","story_stage":3},
		{"type":"customer_result","night":10,"story_id":"divorced_father_story","story_stage":3},
		{"type":"night_result","night":10,"chapter_id":"chapter_02"}
	]
	for index in range(NEW_EVENTS.size()):
		var available: Array = StoryEventSystem.get_available_events(contexts[index])
		_assert(available.any(func(event): return str(event.get("id", "")) == NEW_EVENTS[index]), "Story event must trigger: %s." % NEW_EVENTS[index])
		_assert(StoryEventSystem.has_triggered_event(NEW_EVENTS[index]), "Story event must record: %s." % NEW_EVENTS[index])


func _test_old_save_compatibility() -> void:
	var old_save: Dictionary = SaveManager.create_default_save()
	old_save.erase("completed_chapters")
	old_save["customer_story_progress"] = {
		"student_story": {"current_stage": 3, "visit_count": 3},
		"driver_story": {"current_stage": 3, "visit_count": 3},
		"previous_clerk_story": {"current_stage": 3, "visit_count": 3}
	}
	old_save["seen_customers"] = ["student_story", "driver_story", "previous_clerk_story"]
	old_save["completed_request_ids"] = ["student_exam_01", "student_exam_02", "student_exam_03", "insomnia_driver_01", "insomnia_driver_02", "insomnia_driver_03", "previous_clerk_hint_01", "previous_clerk_02", "previous_clerk_01"]
	old_save["current_night"] = 6
	old_save["money"] = 123
	old_save["inventory"] = {"coffee": 4, "milk": 2}
	_assert(SaveManager.apply_save_data(old_save, false), "Old save without Chapter 2/story progress fields must load.")
	_assert(GameManager.current_night == 6 and GameManager.money == 123, "Old save night and money must be preserved.")
	_assert(CustomerProgressSystem.get_story_progress("night_nurse_story").get("current_stage", -1) == 0, "Missing new story progress must initialize safely.")
	_assert(CustomerSystem.get_customer_count_for_current_night() == 5, "Old save entering Night 6 must build a playable queue.")


func _test_archive_and_ui() -> void:
	var archive: Control = (load("res://scenes/archive/ArchiveScene.tscn") as PackedScene).instantiate()
	root.add_child(archive)
	await process_frame
	_assert(archive != null, "Archive must instantiate with Stage 4/5 profiles.")
	archive.queue_free()
	var item_card := (load("res://scenes/ui/components/ItemCard.tscn") as PackedScene).instantiate()
	root.add_child(item_card)
	item_card.setup(DataManager.get_item_by_id("canned_peach"), 5)
	await process_frame
	_assert(item_card.get_icon_texture() != null, "Stage 14 ItemCard must display a new Stage 15 icon.")
	item_card.queue_free()


func _test_versions_and_assets() -> void:
	_assert(SaveManager.CURRENT_SAVE_VERSION == 1, "save_version must remain 1.")
	_assert(SettingsManager.CURRENT_SETTINGS_VERSION == 1, "settings_version must remain 1.")
	_assert(AssetRegistry.get_manifest_version() == 1, "manifest_version must remain 1.")
	for item_id in NEW_ITEMS:
		_assert(AssetRegistry.has_asset("item_icons", item_id) and AssetRegistry.get_texture("item_icons", item_id) != null, "New icon ID must resolve: %s." % item_id)
	for portrait_id in ["portrait_night_nurse", "portrait_breakfast_man"]:
		_assert(AssetRegistry.has_asset("portraits", portrait_id) and AssetRegistry.get_texture("portraits", portrait_id) != null, "New portrait ID must resolve: %s." % portrait_id)


func _result(id: String) -> Dictionary:
	return {"service_id": id, "score": 80, "grade": "good", "selected_item_ids": ["coffee"]}


func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Stage 16 Chapter 2 smoke test passed.")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)
