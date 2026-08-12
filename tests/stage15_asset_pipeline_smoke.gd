extends SceneTree

const ItemCardScene = preload("res://scenes/ui/components/ItemCard.tscn")
const CustomerHeaderScene = preload("res://scenes/ui/components/CustomerHeader.tscn")
const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")

var failures: Array[String] = []
var AssetRegistry
var DataManager
var GameManager
var SaveManager
var InventorySystem
var SettingsManager
var AudioManager
var _state_before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_bind_autoloads()
	if not failures.is_empty():
		_finish()
		return
	_state_before = _gameplay_snapshot()
	_test_registry_and_fallbacks()
	_test_cache()
	await _test_ui_consumers()
	_test_audio_ids()
	_test_versions_and_frameworks()
	_assert_equal(_gameplay_snapshot(), _state_before, "Asset pipeline operations must not change gameplay, save, or inventory state.")
	_finish()


func _bind_autoloads() -> void:
	AssetRegistry = root.get_node_or_null("/root/AssetRegistry")
	DataManager = root.get_node_or_null("/root/DataManager")
	GameManager = root.get_node_or_null("/root/GameManager")
	SaveManager = root.get_node_or_null("/root/SaveManager")
	InventorySystem = root.get_node_or_null("/root/InventorySystem")
	SettingsManager = root.get_node_or_null("/root/SettingsManager")
	AudioManager = root.get_node_or_null("/root/AudioManager")
	var required := {"AssetRegistry": AssetRegistry, "DataManager": DataManager, "GameManager": GameManager, "SaveManager": SaveManager, "InventorySystem": InventorySystem, "SettingsManager": SettingsManager, "AudioManager": AudioManager}
	for autoload_name in required:
		_assert(required[autoload_name] != null, "%s autoload must exist." % autoload_name)


func _test_registry_and_fallbacks() -> void:
	_assert(AssetRegistry.is_manifest_loaded(), "Presentation manifest must load.")
	_assert_equal(AssetRegistry.get_manifest_version(), 1, "manifest_version must be 1.")
	_assert(AssetRegistry.get_texture("backgrounds", "default_background") != null, "Default background must resolve.")
	_assert(AssetRegistry.get_texture("portraits", "default_portrait") != null, "Default portrait must resolve.")
	_assert(AssetRegistry.get_texture("item_icons", "default_item_icon") != null, "Default item icon must resolve.")
	_assert(AssetRegistry.get_texture("item_icons", "missing_stage15_item") != null, "Unknown texture ID must return a fallback.")
	_assert(AssetRegistry.get_texture("missing_category", "anything") != null, "Unknown texture category must return a safe fallback.")
	_assert(AssetRegistry.set_manifest_entry_for_testing("item_icons", "wrong_type_probe", "res://default_bus_layout.tres"), "Debug tests must be able to inject a type probe.")
	_assert(AssetRegistry.get_texture("item_icons", "wrong_type_probe") != null, "A wrong resource type must return a texture fallback.")
	_assert(AssetRegistry.reload_manifest(), "Manifest must recover after a type probe.")
	_assert(AssetRegistry.get_audio("bgm", "main_menu") == null, "Empty BGM entry must be a safe null.")
	_assert(AssetRegistry.get_font("font_ui_default") == null, "Empty font entry must preserve the default font.")
	for item in DataManager.get_all_items():
		var item_id := str(item.get("id", ""))
		_assert(AssetRegistry.has_asset("item_icons", item_id), "Item icon manifest entry missing: %s." % item_id)
		_assert(AssetRegistry.get_texture("item_icons", item_id) != null, "Item icon must resolve: %s." % item_id)
	for profile in DataManager.get_all_customer_profiles():
		var portrait_id := str(profile.get("portrait_id", ""))
		_assert(AssetRegistry.has_asset("portraits", portrait_id), "Portrait entry missing: %s." % portrait_id)
		_assert(AssetRegistry.get_texture("portraits", portrait_id) != null, "Portrait must resolve: %s." % portrait_id)


func _test_cache() -> void:
	AssetRegistry.clear_cache()
	_assert_equal(AssetRegistry.get_cache_size(), 0, "clear_cache must empty dynamic resources.")
	var first = AssetRegistry.get_texture("item_icons", "coffee")
	var size_after_first: int = AssetRegistry.get_cache_size()
	var second = AssetRegistry.get_texture("item_icons", "coffee")
	_assert(first == second, "Repeated requests must return the cached resource.")
	_assert_equal(size_after_first, 1, "One resource request should create one cache entry.")
	_assert_equal(AssetRegistry.get_cache_size(), size_after_first, "Repeated requests must not grow the cache.")
	var state_before_reload := _gameplay_snapshot()
	_assert(AssetRegistry.reload_manifest(), "Development manifest reload must succeed.")
	_assert_equal(_gameplay_snapshot(), state_before_reload, "Manifest reload must not alter gameplay state.")


func _test_ui_consumers() -> void:
	var item_card: Button = ItemCardScene.instantiate()
	root.add_child(item_card)
	item_card.setup(DataManager.get_item_by_id("coffee"), 3)
	await process_frame
	_assert(item_card.get_icon_texture() != null, "ItemCard must display an item texture.")
	item_card.setup({"id": "missing_stage15_item", "name": "Missing", "max_stock": 1}, 0)
	_assert(item_card.get_icon_texture() != null, "ItemCard must display fallback for a missing icon.")
	item_card.queue_free()

	var header: Control = CustomerHeaderScene.instantiate()
	root.add_child(header)
	var profile: Dictionary = DataManager.get_all_customer_profiles()[0]
	header.setup({"customer_name": "Test", "dialogue": "Test", "story_id": profile.get("story_id", "")}, profile)
	await process_frame
	_assert(header.get_portrait_texture() != null, "CustomerHeader must display a portrait.")
	header.setup({"customer_name": "Missing", "dialogue": "Missing"}, {"portrait_id": "missing_stage15_portrait"})
	_assert(header.get_portrait_texture() != null, "CustomerHeader must display fallback for a missing portrait.")
	header.queue_free()

	var screen_background: Control = ScreenBackgroundScene.instantiate()
	root.add_child(screen_background)
	screen_background.set_background("shop_default")
	await process_frame
	_assert(screen_background.anchor_right == 1.0 and screen_background.anchor_bottom == 1.0, "ScreenBackground must be full rect.")
	_assert(screen_background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ScreenBackground must not block input.")
	screen_background.queue_free()

	var menu_resource := load("res://scenes/main_menu/MainMenu.tscn") as PackedScene
	_assert(menu_resource != null, "MainMenu scene must load.")
	if menu_resource == null:
		return
	var save_before_menu: Dictionary = SaveManager.current_save.duplicate(true)
	var menu: Control = menu_resource.instantiate()
	root.add_child(menu)
	await process_frame
	_assert(menu.has_method("has_text_title_fallback") and menu.has_text_title_fallback(), "MainMenu must retain its text title fallback.")
	menu.queue_free()
	await process_frame
	SaveManager.current_save = save_before_menu


func _test_audio_ids() -> void:
	AudioManager.play_bgm_by_id("main_menu")
	AudioManager.play_sfx_by_id("ui_click")
	AudioManager.play_bgm_by_id("missing_stage15_bgm")
	AudioManager.play_sfx_by_id("missing_stage15_sfx")
	_assert(not AudioManager.is_bgm_playing(), "Missing ID-based audio must remain a safe no-op.")


func _test_versions_and_frameworks() -> void:
	_assert_equal(DataManager.get_all_items().size(), 24, "Stage 16 item total must be 24 while Stage 15 loads all icons.")
	_assert_equal(DataManager.get_all_customers().size(), 40, "Stage 16 request total must be 40.")
	_assert_equal(DataManager.get_all_combos().size(), 12, "Stage 16 combo total must be 12.")
	_assert_equal(DataManager.get_all_chapters().size(), 2, "Stage 12 chapter framework must load both chapters.")
	_assert_equal(DataManager.get_all_story_events().size(), 7, "Stage 12 event framework must load Chapter 2 events.")
	_assert_equal(DataManager.get_all_endings().size(), 1, "Stage 12 endings must remain available.")
	_assert(root.get_node_or_null("/root/SceneTransitionManager") != null, "Stage 13 transition framework must remain available.")
	_assert(root.get_node_or_null("/root/UIThemeManager") != null, "Font asset application interface must exist.")
	_assert_equal(SaveManager.create_default_save().get("save_version", 0), 1, "save_version must remain 1.")
	_assert_equal(SettingsManager.CURRENT_SETTINGS_VERSION, 1, "settings_version must remain 1.")


func _gameplay_snapshot() -> Dictionary:
	return {"night": GameManager.current_night, "money": GameManager.money, "inventory": InventorySystem.export_inventory_data(), "save": SaveManager.get_save_data()}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("Stage 15 asset pipeline smoke test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("Stage 15 asset pipeline smoke test failed with %d issue(s)." % failures.size())
	quit(1)
