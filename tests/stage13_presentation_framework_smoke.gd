extends SceneTree

const Config = preload("res://scripts/config/GameConfig.gd")
const TEST_SETTINGS_PATH := "user://stage13_settings_test.json"

var _failures: Array[String] = []
var _test_file_existed := false
var _test_file_backup := ""
var _original_settings: Dictionary = {}
var _original_save: Dictionary = {}
var _original_inventory: Dictionary = {}
var _original_customer_progress: Dictionary = {}
var _original_chapter_progress: Dictionary = {}
var _original_story_events: Dictionary = {}
var _original_endings: Dictionary = {}
var _original_night := 1
var _original_money := 0

var DataManager
var GameManager
var SaveManager
var InventorySystem
var CustomerSystem
var CustomerProgressSystem
var ChapterSystem
var StoryEventSystem
var EndingSystem
var SettingsManager
var AudioManager
var SceneTransitionManager


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_test_file()
	await process_frame
	_bind_autoloads()
	if not _failures.is_empty():
		_cleanup()
		_finish()
		return

	_snapshot_runtime_state()
	if not SettingsManager.set_settings_path_for_testing(TEST_SETTINGS_PATH):
		_failures.append("SettingsManager must allow an isolated settings path in debug tests.")
		_cleanup()
		_finish()
		return

	_test_config_and_defaults()
	_test_setting_ranges_and_application()
	_test_settings_round_trip_and_recovery()
	_test_audio_framework()
	await _test_scenes_and_transitions()
	_test_gameplay_invariants()

	_cleanup()
	_finish()


func _bind_autoloads() -> void:
	DataManager = root.get_node_or_null("/root/DataManager")
	GameManager = root.get_node_or_null("/root/GameManager")
	SaveManager = root.get_node_or_null("/root/SaveManager")
	InventorySystem = root.get_node_or_null("/root/InventorySystem")
	CustomerSystem = root.get_node_or_null("/root/CustomerSystem")
	CustomerProgressSystem = root.get_node_or_null("/root/CustomerProgressSystem")
	ChapterSystem = root.get_node_or_null("/root/ChapterSystem")
	StoryEventSystem = root.get_node_or_null("/root/StoryEventSystem")
	EndingSystem = root.get_node_or_null("/root/EndingSystem")
	SettingsManager = root.get_node_or_null("/root/SettingsManager")
	AudioManager = root.get_node_or_null("/root/AudioManager")
	SceneTransitionManager = root.get_node_or_null("/root/SceneTransitionManager")
	var required := {
		"DataManager": DataManager,
		"GameManager": GameManager,
		"SaveManager": SaveManager,
		"InventorySystem": InventorySystem,
		"CustomerSystem": CustomerSystem,
		"CustomerProgressSystem": CustomerProgressSystem,
		"ChapterSystem": ChapterSystem,
		"StoryEventSystem": StoryEventSystem,
		"EndingSystem": EndingSystem,
		"SettingsManager": SettingsManager,
		"AudioManager": AudioManager,
		"SceneTransitionManager": SceneTransitionManager
	}
	for autoload_name in required:
		_assert(required[autoload_name] != null, "%s autoload must exist." % autoload_name)


func _snapshot_runtime_state() -> void:
	_original_settings = SettingsManager.export_settings()
	_original_save = SaveManager.get_save_data()
	_original_inventory = InventorySystem.export_inventory_data()
	_original_customer_progress = CustomerProgressSystem.export_progress_data()
	_original_chapter_progress = ChapterSystem.export_chapter_data()
	_original_story_events = StoryEventSystem.export_event_data()
	_original_endings = EndingSystem.export_ending_data()
	_original_night = GameManager.current_night
	_original_money = GameManager.money


func _test_config_and_defaults() -> void:
	_assert(not ProjectSettings.has_setting("autoload/GameConfig"), "GameConfig must remain a non-Autoload constants container.")
	_assert_equal(Config.GAME_VERSION, "0.1.0", "GameConfig must expose the current display version.")
	_assert_equal(Config.SETTINGS_PATH, "user://settings.json", "The production settings path must be stable.")
	SettingsManager.reset_to_defaults()
	var defaults: Dictionary = SettingsManager.export_settings()
	_assert_equal(defaults.get("settings_version", 0), 1, "settings_version must be 1.")
	_assert_approx(SettingsManager.get_master_volume(), 1.0, "Master default must be 1.0.")
	_assert_approx(SettingsManager.get_bgm_volume(), 0.8, "BGM default must be 0.8.")
	_assert_approx(SettingsManager.get_sfx_volume(), 0.8, "SFX default must be 0.8.")
	_assert_approx(SettingsManager.get_text_speed(), 1.0, "Text speed default must be 1.0.")
	_assert(not SettingsManager.is_fullscreen(), "Fullscreen must default to off.")
	_assert(SettingsManager.is_screen_shake_enabled(), "Screen shake must default to on.")


func _test_setting_ranges_and_application() -> void:
	SettingsManager.set_master_volume(-3.0)
	SettingsManager.set_bgm_volume(4.0)
	SettingsManager.set_sfx_volume(0.35)
	SettingsManager.set_text_speed(99.0)
	_assert_approx(SettingsManager.get_master_volume(), 0.0, "Master volume must clamp to 0.")
	_assert_approx(SettingsManager.get_bgm_volume(), 1.0, "BGM volume must clamp to 1.")
	_assert_approx(SettingsManager.get_sfx_volume(), 0.35, "SFX volume must retain a legal value.")
	_assert_approx(SettingsManager.get_text_speed(), Config.MAX_TEXT_SPEED, "Text speed must clamp to its maximum.")
	SettingsManager.set_text_speed(-1.0)
	_assert_approx(SettingsManager.get_text_speed(), Config.MIN_TEXT_SPEED, "Text speed must clamp to its minimum.")
	SettingsManager.set_fullscreen(true)
	SettingsManager.set_screen_shake(false)
	_assert(SettingsManager.is_fullscreen(), "Fullscreen value must be retained in headless mode.")
	_assert(not SettingsManager.is_screen_shake_enabled(), "Screen shake must be independently configurable.")

	var master_index := AudioServer.get_bus_index("Master")
	var bgm_index := AudioServer.get_bus_index("BGM")
	var sfx_index := AudioServer.get_bus_index("SFX")
	_assert(master_index >= 0, "Master audio bus must exist.")
	_assert(bgm_index >= 0, "BGM audio bus must exist.")
	_assert(sfx_index >= 0, "SFX audio bus must exist.")
	_assert(AudioServer.is_bus_mute(master_index), "A zero Master value must mute the Master bus.")
	SettingsManager.set_master_volume(0.5)
	_assert(not AudioServer.is_bus_mute(master_index), "A non-zero Master value must unmute the Master bus.")
	_assert_approx(db_to_linear(AudioServer.get_bus_volume_db(master_index)), 0.5, "Master bus gain must follow SettingsManager.", 0.001)


func _test_settings_round_trip_and_recovery() -> void:
	SettingsManager.import_settings({
		"settings_version": 1,
		"master_volume": 0.42,
		"bgm_volume": 0.31,
		"sfx_volume": 0.73,
		"text_speed": 1.45,
		"fullscreen": false,
		"screen_shake": false
	})
	var gameplay_before := _gameplay_snapshot()
	_assert(SettingsManager.save_settings(), "Settings must save to the isolated test path.")
	SettingsManager.reset_to_defaults()
	SettingsManager.load_settings()
	_assert_approx(SettingsManager.get_master_volume(), 0.42, "Saved Master volume must load.")
	_assert_approx(SettingsManager.get_bgm_volume(), 0.31, "Saved BGM volume must load.")
	_assert_approx(SettingsManager.get_sfx_volume(), 0.73, "Saved SFX volume must load.")
	_assert_approx(SettingsManager.get_text_speed(), 1.45, "Saved text speed must load.")
	_assert(not SettingsManager.is_screen_shake_enabled(), "Saved boolean settings must load.")
	_assert_equal(_gameplay_snapshot(), gameplay_before, "Saving settings must not alter night, money, inventory, or save data.")

	_write_test_file(JSON.stringify({"settings_version": 1, "master_volume": 0.25}))
	SettingsManager.load_settings()
	_assert_approx(SettingsManager.get_master_volume(), 0.25, "A present settings field must load.")
	_assert_approx(SettingsManager.get_bgm_volume(), Config.DEFAULT_BGM_VOLUME, "A missing field must use its default.")
	_assert(SettingsManager.is_screen_shake_enabled(), "A missing boolean field must use its default.")

	_write_test_file("{ definitely-not-json")
	SettingsManager.load_settings()
	_assert_approx(SettingsManager.get_master_volume(), Config.DEFAULT_MASTER_VOLUME, "Corrupt JSON must restore defaults.")
	_assert_approx(SettingsManager.get_text_speed(), Config.DEFAULT_TEXT_SPEED, "Corrupt JSON must not leave partial settings.")


func _test_audio_framework() -> void:
	_assert_equal(AudioManager.get_bgm_bus_name(), "BGM", "BGM player must route to the BGM bus.")
	var sfx_buses: Array = AudioManager.get_sfx_bus_names()
	_assert_equal(sfx_buses.size(), 4, "AudioManager must provide a small SFX player pool.")
	for bus_name in sfx_buses:
		_assert_equal(bus_name, "SFX", "Every SFX player must route to the SFX bus.")
	AudioManager.play_bgm(null)
	AudioManager.play_sfx(null)
	AudioManager.pause_bgm()
	AudioManager.resume_bgm()
	AudioManager.stop_bgm()
	AudioManager.stop_all_sfx()
	_assert(not AudioManager.is_bgm_playing(), "Null audio operations must be safe no-ops.")

	var generated_stream := AudioStreamGenerator.new()
	AudioManager.play_bgm(generated_stream)
	var bgm_player := AudioManager.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	_assert(bgm_player != null, "AudioManager must own a BGM player.")
	if bgm_player != null:
		_assert(bgm_player.stream == generated_stream, "AudioManager must accept an AudioStream.")
		AudioManager.play_bgm(generated_stream)
		_assert(bgm_player.stream == generated_stream, "Requesting the same BGM must retain the existing stream.")
	AudioManager.stop_bgm()


func _test_scenes_and_transitions() -> void:
	_assert(ResourceLoader.exists(Config.SETTINGS_SCENE), "SettingsScene must exist.")
	_assert(ResourceLoader.exists(Config.MAIN_MENU_SCENE), "MainMenu scene must exist.")
	var settings_scene_resource := load(Config.SETTINGS_SCENE) as PackedScene
	var state_before_settings: Dictionary = _gameplay_snapshot()
	var settings_scene := settings_scene_resource.instantiate()
	root.add_child(settings_scene)
	await process_frame
	_assert(settings_scene.get_node_or_null(".") != null, "SettingsScene must instantiate without a game save.")
	_assert_equal(_gameplay_snapshot(), state_before_settings, "Opening SettingsScene must not change gameplay or progression state.")
	settings_scene.queue_free()
	await process_frame

	var main_menu_resource := load(Config.MAIN_MENU_SCENE) as PackedScene
	var main_menu := main_menu_resource.instantiate()
	root.add_child(main_menu)
	await process_frame
	_assert(main_menu.has_method("has_settings_entry") and main_menu.has_settings_entry(), "MainMenu must expose a Settings entry.")
	main_menu.queue_free()
	await process_frame

	SceneTransitionManager.set_error_reporting_enabled_for_testing(false)
	_assert(not SceneTransitionManager.change_scene(""), "Transition manager must reject an empty path.")
	_assert(not SceneTransitionManager.is_transitioning(), "An invalid transition must restore the ready state.")
	_assert(not SceneTransitionManager.change_scene("res://missing/stage13_missing_scene.tscn"), "Transition manager must reject a missing scene.")
	_assert(not SceneTransitionManager.is_transitioning(), "A failed transition must not leave input locked.")
	SceneTransitionManager.set_error_reporting_enabled_for_testing(true)

	var transition_script := load("res://scripts/managers/SceneTransitionManager.gd")
	var transition_probe: Node = transition_script.new()
	root.add_child(transition_probe)
	await process_frame
	transition_probe.set("_transitioning", true)
	_assert(not transition_probe.change_scene(Config.MAIN_MENU_SCENE), "A transition already in progress must reject re-entry.")
	transition_probe.set("_transitioning", false)
	transition_probe.queue_free()
	await process_frame


func _test_gameplay_invariants() -> void:
	DataManager.reload_data()
	var expected_counts := {1: 5, 2: 6, 3: 7, 4: 8, 5: 4}
	for night_number in expected_counts:
		var night_config: Dictionary = DataManager.get_night_config(night_number)
		var slots: Array = night_config.get("customer_slots", [])
		_assert_equal(slots.size(), expected_counts[night_number], "Night %d customer count must remain unchanged." % night_number)
		var resolved: Array = CustomerSystem.resolve_night_customer_slots(night_config)
		_assert_equal(resolved.size(), expected_counts[night_number], "CustomerSystem must still resolve the Night %d schedule." % night_number)
	_assert_equal(DataManager.get_all_chapters().size(), 1, "Stage 12 chapter data must remain available.")
	_assert_equal(DataManager.get_all_story_events().size(), 3, "Stage 12 story event data must remain available.")
	_assert_equal(DataManager.get_all_endings().size(), 1, "Stage 12 ending data must remain available.")
	_assert_equal(SaveManager.create_default_save().get("save_version", 0), 1, "Game save_version must remain 1.")


func _gameplay_snapshot() -> Dictionary:
	return {
		"night": GameManager.current_night,
		"money": GameManager.money,
		"inventory": InventorySystem.export_inventory_data(),
		"save": SaveManager.get_save_data(),
		"customer_progress": CustomerProgressSystem.export_progress_data(),
		"chapter_progress": ChapterSystem.export_chapter_data(),
		"story_events": StoryEventSystem.export_event_data(),
		"endings": EndingSystem.export_ending_data()
	}


func _backup_test_file() -> void:
	_test_file_existed = FileAccess.file_exists(TEST_SETTINGS_PATH)
	if not _test_file_existed:
		return
	var file := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.READ)
	if file != null:
		_test_file_backup = file.get_as_text()


func _write_test_file(content: String) -> void:
	var file := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
	_assert(file != null, "The isolated settings file must be writable.")
	if file != null:
		file.store_string(content)


func _cleanup() -> void:
	if SettingsManager != null:
		if not _original_settings.is_empty():
			SettingsManager.import_settings(_original_settings)
		SettingsManager.restore_default_settings_path_for_testing()
	if GameManager != null:
		GameManager.set_current_night(_original_night)
		GameManager.set_money(_original_money)
	if InventorySystem != null and not _original_inventory.is_empty():
		InventorySystem.import_inventory_data(_original_inventory)
	if SaveManager != null and not _original_save.is_empty():
		SaveManager.current_save = _original_save.duplicate(true)
	if CustomerProgressSystem != null and not _original_customer_progress.is_empty():
		CustomerProgressSystem.import_progress_data(_original_customer_progress)
	if ChapterSystem != null:
		ChapterSystem.import_chapter_data(_original_chapter_progress)
	if StoryEventSystem != null:
		StoryEventSystem.import_event_data(_original_story_events)
	if EndingSystem != null:
		EndingSystem.import_ending_data(_original_endings)
	_restore_test_file()


func _restore_test_file() -> void:
	if _test_file_existed:
		var file := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_test_file_backup)
		return
	var absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _assert_approx(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if not is_equal_approx(actual, expected) and absf(actual - expected) > tolerance:
		_failures.append("%s Expected %.4f, got %.4f." % [message, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("Stage 13 presentation framework smoke test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("Stage 13 presentation framework smoke test failed with %d issue(s)." % _failures.size())
	quit(1)
