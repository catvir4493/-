extends SceneTree

const DialoguePanelScene = preload("res://scenes/ui/components/DialoguePanel.tscn")
const ChapterCardScene = preload("res://scenes/ui/components/ChapterCard.tscn")
const NarrativeOverlayScene = preload("res://scenes/ui/components/NarrativeOverlay.tscn")

var failures: Array[String] = []
var DataManager
var GameManager
var SaveManager
var InventorySystem
var CustomerSystem
var CustomerProgressSystem
var NightStatsSystem
var ChapterSystem
var StoryEventSystem
var EndingSystem
var SettingsManager
var AssetRegistry
var _snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_bind_autoloads()
	if not failures.is_empty():
		_finish()
		return
	_snapshot = _runtime_snapshot()

	_test_component_resources()
	await _test_shop_integration()
	await _test_result_and_story_event_presentation()
	_test_chapter_and_night_result_support()
	await _test_framework_invariants()

	_restore_runtime()
	_finish()


func _bind_autoloads() -> void:
	for autoload_name in ["DataManager", "GameManager", "SaveManager", "InventorySystem", "CustomerSystem", "CustomerProgressSystem", "NightStatsSystem", "ChapterSystem", "StoryEventSystem", "EndingSystem", "SettingsManager", "AssetRegistry"]:
		set(autoload_name, root.get_node_or_null("/root/%s" % autoload_name))
		_assert(get(autoload_name) != null, "%s must exist." % autoload_name)


func _test_component_resources() -> void:
	for path in [
		"res://scenes/ui/components/DialoguePanel.tscn",
		"res://scenes/ui/components/ChapterCard.tscn",
		"res://scenes/ui/components/NarrativeOverlay.tscn"
	]:
		var packed := load(path) as PackedScene
		var instance = packed.instantiate() if packed != null else null
		_assert(packed != null and instance != null, "Narrative component must load: %s." % path)
		if instance != null:
			instance.free()
	_assert(not ProjectSettings.has_setting("autoload/DialogueManager"), "Stage 17 must not add DialogueManager.")
	_assert(not ProjectSettings.has_setting("autoload/NarrativeManager"), "Stage 17 must not add NarrativeManager.")
	_assert(not ProjectSettings.has_setting("autoload/CutsceneManager"), "Stage 17 must not add CutsceneManager.")


func _test_shop_integration() -> void:
	GameManager.set_current_night(1)
	GameManager.set_money(37)
	CustomerProgressSystem.reset_progress()
	CustomerSystem.build_queue_for_night(1)
	NightStatsSystem.start_night(1)
	StoryEventSystem.reset_events()
	var first_start: Array = StoryEventSystem.get_available_events({"type": "night_start", "night": 1, "chapter_id": "chapter_01"})
	_assert(first_start.size() == 1, "Night 1 chapter start must be controlled by StoryEventSystem.")

	var shop: Control = (load("res://scenes/shop/ShopScene.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	await process_frame
	_assert(shop.find_child("CustomerHeader", true, false) != null, "ShopScene must retain CustomerHeader.")
	_assert(shop.find_child("DialoguePanel", true, false) != null, "ShopScene must contain DialoguePanel.")
	_assert(shop.find_child("ItemCard", true, false) != null, "ShopScene must retain ItemCard controls.")
	_assert(shop.get_chapter_presentation_for_night(1).get("chapter_id", "") == "chapter_01", "ShopScene must support Chapter 1 start presentation.")
	_assert(shop.get_chapter_presentation_for_night(6).get("chapter_id", "") == "chapter_02", "ShopScene must support Chapter 2 start presentation.")
	_assert(shop.get_night_transition_text() == "第 1 夜", "ShopScene must expose the current night transition label.")

	shop.skip_narrative_intro()
	await process_frame
	var chapter_card: Control = shop.find_child("ChapterCard", true, false)
	_assert(chapter_card != null and chapter_card.visible, "A newly triggered Chapter 1 start must show ChapterCard after the night label.")
	if chapter_card != null:
		_assert(chapter_card.get_chapter_title() == "第一章", "ChapterCard must use the chapter data title.")
		chapter_card.dismiss()
	await process_frame

	var dialogue_panel: Control = shop.get_dialogue_panel()
	var gameplay_before := _gameplay_state_only()
	var selected_before: Array = shop.get_selected_item_ids()
	_assert(dialogue_panel.is_revealing(), "Customer dialogue must begin with typewriter reveal.")
	dialogue_panel.reveal_all()
	await process_frame
	_assert(dialogue_panel.request_advance(), "Finished Shop dialogue must accept a second-stage continue.")
	await process_frame
	_assert(shop.is_dialogue_interaction_ready(), "Shop item interaction must unlock only after dialogue continue.")
	_assert(shop.get_selected_item_ids() == selected_before, "Dialogue must not modify selected_items.")
	_assert(_gameplay_state_only() == gameplay_before, "Dialogue presentation must not change money, inventory, or customer progress.")
	_assert(StoryEventSystem.get_available_events({"type": "night_start", "night": 1, "chapter_id": "chapter_01"}).is_empty(), "Chapter start must not repeat after its one-time event is recorded.")
	shop.queue_free()
	await process_frame


func _test_result_and_story_event_presentation() -> void:
	StoryEventSystem.reset_events()
	var triggered: Array = StoryEventSystem.get_available_events({
		"type": "customer_result",
		"night": 10,
		"story_id": "night_nurse_story",
		"story_stage": 3
	})
	_assert(triggered.size() == 1 and str(triggered[0].get("id", "")) == "event_nurse_resignation", "StoryEventSystem must decide whether the nurse event triggers.")
	GameManager.last_service_result = {
		"customer_name": "夜班护士",
		"customer_feedback": "我会再想想，但至少这次是我自己做的决定。",
		"grade": "good",
		"score": 85,
		"income": 12,
		"combo_score_bonus": 15,
		"selected_item_names": ["蓝色圆珠笔"],
		"matched_tags": ["真实"],
		"missing_tags": ["希望"],
		"bad_tags": [],
		"combo_names": ["终于写下来了"]
	}
	var result_scene: Control = (load("res://scenes/result/ResultScene.tscn") as PackedScene).instantiate()
	root.add_child(result_scene)
	await process_frame
	var dialogue_panel: Control = result_scene.get_dialogue_panel()
	_assert(dialogue_panel.get_full_text().contains("我会再想想"), "ResultScene customer feedback must use DialoguePanel.")
	var visible_text := _collect_text(result_scene)
	_assert(visible_text.contains("85"), "ResultScene score must remain visible.")
	_assert(visible_text.contains("12"), "ResultScene income must remain visible.")
	_assert(visible_text.contains("终于写下来了"), "ResultScene combo details must remain visible.")
	_assert(result_scene.can_present_story_event("event_nurse_resignation"), "Nurse event must map to narrative presentation.")
	_assert(result_scene.can_present_story_event("event_breakfast_apology"), "Breakfast apology event must map to narrative presentation.")

	dialogue_panel.reveal_all()
	await process_frame
	dialogue_panel.request_advance()
	await process_frame
	var overlay: Control = result_scene.get_narrative_overlay()
	_assert(overlay.is_open() and overlay.get_title() == "辞职申请", "ResultScene must present the triggered event text after customer feedback.")
	var event_state_before: Dictionary = StoryEventSystem.export_event_data()
	_assert(StoryEventSystem.export_event_data() == event_state_before, "NarrativeOverlay must not record or modify story event state.")
	result_scene.queue_free()
	await process_frame

	var standalone_overlay: Control = NarrativeOverlayScene.instantiate()
	root.add_child(standalone_overlay)
	standalone_overlay.show_text("只负责显示", "Logic → UI")
	_assert(StoryEventSystem.export_event_data() == event_state_before, "Standalone NarrativeOverlay must remain presentation-only.")
	standalone_overlay.close()
	standalone_overlay.queue_free()
	await process_frame


func _test_chapter_and_night_result_support() -> void:
	var night_result = load("res://scenes/night_result/NightResultScene.gd").new()
	_assert(night_result.can_show_chapter_complete_for_night(5), "Night 5 must support Chapter Complete presentation.")
	_assert(night_result.can_show_chapter_complete_for_night(10), "Night 10 must support Chapter Complete presentation.")
	_assert(not night_result.can_show_chapter_complete_for_night(9), "Non-final chapter nights must not show Chapter Complete.")
	night_result.free()
	var ending: Dictionary = DataManager.get_ending_by_id("ending_mvp_placeholder")
	_assert(DataManager.get_all_endings().size() == 1 and not ending.is_empty(), "Night 10 must not introduce a formal new ending.")


func _test_framework_invariants() -> void:
	SettingsManager.set_text_speed(2.0)
	var dialogue: Control = DialoguePanelScene.instantiate()
	root.add_child(dialogue)
	await process_frame
	dialogue.show_dialogue("速度", "下一段立即读取设置")
	_assert(absf(dialogue.get_effective_characters_per_second() - 72.0) < 0.001, "Stage 13 Text Speed must now be read by DialoguePanel.")
	_assert(dialogue.theme == null or root.get_node_or_null("/root/UIThemeManager") != null, "Stage 14 theme framework must remain available.")
	dialogue.queue_free()
	_assert(AssetRegistry.is_manifest_loaded() and AssetRegistry.get_manifest_version() == 1, "Stage 15 AssetRegistry and manifest_version must remain valid.")
	_assert(DataManager.get_all_items().size() == 24 and DataManager.get_all_customers().size() == 40 and DataManager.get_all_combos().size() == 12, "Stage 16 content totals must remain unchanged.")
	_assert(DataManager.get_chapter_by_id("chapter_02").get("end_night", 0) == 10, "Stage 16 Chapter 2 must remain intact.")
	_assert(SaveManager.CURRENT_SAVE_VERSION == 1, "save_version must remain 1.")
	_assert(SettingsManager.CURRENT_SETTINGS_VERSION == 1, "settings_version must remain 1.")


func _runtime_snapshot() -> Dictionary:
	return {
		"night": GameManager.current_night,
		"money": GameManager.money,
		"inventory": InventorySystem.export_inventory_data(),
		"save": SaveManager.get_save_data(),
		"progress": CustomerProgressSystem.export_progress_data(),
		"chapter": ChapterSystem.export_chapter_data(),
		"events": StoryEventSystem.export_event_data(),
		"endings": EndingSystem.export_ending_data(),
		"settings": SettingsManager.export_settings(),
		"last_result": GameManager.last_service_result.duplicate(true)
	}


func _gameplay_state_only() -> Dictionary:
	return {
		"money": GameManager.money,
		"inventory": InventorySystem.export_inventory_data(),
		"progress": CustomerProgressSystem.export_progress_data()
	}


func _restore_runtime() -> void:
	GameManager.set_current_night(int(_snapshot.get("night", 1)))
	GameManager.set_money(int(_snapshot.get("money", 0)))
	InventorySystem.import_inventory_data(_snapshot.get("inventory", {}))
	SaveManager.current_save = _snapshot.get("save", {}).duplicate(true)
	CustomerProgressSystem.import_progress_data(_snapshot.get("progress", {}))
	ChapterSystem.import_chapter_data(_snapshot.get("chapter", {}))
	StoryEventSystem.import_event_data(_snapshot.get("events", {}))
	EndingSystem.import_ending_data(_snapshot.get("endings", {}))
	SettingsManager.import_settings(_snapshot.get("settings", {}))
	GameManager.last_service_result = _snapshot.get("last_result", {}).duplicate(true)
	CustomerSystem.ensure_night_queue(GameManager.current_night)


func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result = node.text
	elif node is RichTextLabel:
		result = node.text
	elif node is Button:
		result = node.text
	for child in node.get_children():
		result += "\n" + _collect_text(child)
	return result


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Stage 17 narrative presentation smoke test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("Stage 17 narrative presentation smoke test failed with %d issue(s)." % failures.size())
	quit(1)
