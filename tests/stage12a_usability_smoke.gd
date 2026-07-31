extends SceneTree

const SAVE_PATH := "user://save_data.json"
const SHOP_SCENE_PATH := "res://scenes/shop/ShopScene.tscn"
const RESULT_SCENE_PATH := "res://scenes/result/ResultScene.tscn"
const RESTOCK_SCENE_PATH := "res://scenes/restock/RestockScene.tscn"
const NIGHT_RESULT_SCRIPT_PATH := "res://scenes/night_result/NightResultScene.gd"

var _failures: Array[String] = []
var _save_existed := false
var _save_backup_text := ""
var _data_manager
var _save_manager
var _inventory_system
var _customer_system
var _customer_progress_system
var _score_system
var _game_manager
var _night_stats_system
var _debug_manager
var _playtest_logger
var _created_log_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_save()
	await process_frame
	_bind_autoloads()
	if not _failures.is_empty():
		_restore_external_state()
		_finish()
		return

	_data_manager.reload_data()
	await _test_debug_overlay_visibility()
	await _test_shop_selection_states()
	await _test_confirm_only_once()
	await _test_continue_only_once()
	await _test_start_next_night_only_once()
	_test_buy_boundaries()
	_test_debug_next_customer_is_side_effect_free()
	_test_debug_refill_does_not_unlock_items()
	_test_debug_runtime_changes_do_not_save()
	_test_playtest_logger_deduplicates()
	_test_release_guards()
	_test_night_result_consistency()

	_restore_external_state()
	_finish()


func _bind_autoloads() -> void:
	_data_manager = root.get_node_or_null("/root/DataManager")
	_save_manager = root.get_node_or_null("/root/SaveManager")
	_inventory_system = root.get_node_or_null("/root/InventorySystem")
	_customer_system = root.get_node_or_null("/root/CustomerSystem")
	_customer_progress_system = root.get_node_or_null("/root/CustomerProgressSystem")
	_score_system = root.get_node_or_null("/root/ScoreSystem")
	_game_manager = root.get_node_or_null("/root/GameManager")
	_night_stats_system = root.get_node_or_null("/root/NightStatsSystem")
	_debug_manager = root.get_node_or_null("/root/DebugManager")
	_playtest_logger = root.get_node_or_null("/root/PlaytestLogger")

	_assert(_data_manager != null, "DataManager autoload must exist.")
	_assert(_save_manager != null, "SaveManager autoload must exist.")
	_assert(_inventory_system != null, "InventorySystem autoload must exist.")
	_assert(_customer_system != null, "CustomerSystem autoload must exist.")
	_assert(_customer_progress_system != null, "CustomerProgressSystem autoload must exist.")
	_assert(_score_system != null, "ScoreSystem autoload must exist.")
	_assert(_game_manager != null, "GameManager autoload must exist.")
	_assert(_night_stats_system != null, "NightStatsSystem autoload must exist.")
	_assert(_debug_manager != null, "DebugManager autoload must exist.")
	_assert(_playtest_logger != null, "PlaytestLogger autoload must exist.")


func _test_debug_overlay_visibility() -> void:
	var overlay = _debug_manager.get_node_or_null("DebugPlaytestOverlay")
	_assert(overlay != null, "Debug overlay must be instantiated in a debug build.")
	if overlay == null:
		return

	_assert(not overlay.is_overlay_visible(), "Debug overlay must be hidden by default.")
	overlay.toggle_overlay()
	await process_frame
	_assert(overlay.is_overlay_visible(), "Debug overlay must be able to open.")
	overlay.toggle_overlay()
	_assert(not overlay.is_overlay_visible(), "Debug overlay must be able to hide.")


func _test_shop_selection_states() -> void:
	_reset_runtime()
	var shop = load(SHOP_SCENE_PATH).instantiate()
	root.add_child(shop)
	await process_frame

	_assert_equal(shop.get_selected_item_ids(), [], "selected_items must start empty.")
	_assert(not shop.can_confirm_selection(), "Confirm must be unavailable with no selected item.")

	var unlocked_ids := _get_unlocked_item_ids(1)
	_assert(unlocked_ids.size() >= 4, "Night 1 needs at least four unlocked test items.")
	for index in range(mini(3, unlocked_ids.size())):
		shop.call("_on_item_pressed", unlocked_ids[index])

	_assert_equal(shop.get_selected_item_ids().size(), 3, "At most three items may be selected.")
	shop.call("_on_item_pressed", unlocked_ids[3])
	_assert_equal(shop.get_selected_item_ids().size(), 3, "The fourth item must not be added.")

	shop.call("_on_item_pressed", unlocked_ids[0])
	_assert(not shop.get_selected_item_ids().has(unlocked_ids[0]), "A selected item must be cancellable at the limit.")

	shop.clear_selection()
	_assert_equal(shop.get_selected_item_ids(), [], "Clear must empty selected_items.")

	var zero_stock_id: String = unlocked_ids[0]
	_inventory_system.consume_item(zero_stock_id, _inventory_system.get_stock(zero_stock_id))
	shop.call("_on_item_pressed", zero_stock_id)
	_assert(not shop.get_selected_item_ids().has(zero_stock_id), "An item with zero stock must not be selectable.")

	shop.queue_free()
	await process_frame


func _test_confirm_only_once() -> void:
	_reset_runtime()
	_playtest_logger.reset_runtime_state()
	var shop = load(SHOP_SCENE_PATH).instantiate()
	root.add_child(shop)
	await process_frame

	var item_id: String = _get_unlocked_item_ids(1)[0]
	var stock_before = _inventory_system.get_stock(item_id)
	shop.call("_on_item_pressed", item_id)
	var first_submit = shop.submit_selection(false)
	var money_after_first = _game_manager.money
	var stock_after_first = _inventory_system.get_stock(item_id)
	var second_submit = shop.submit_selection(false)

	_assert(first_submit, "The first valid Confirm must execute.")
	_assert(not second_submit, "Confirm must not execute twice.")
	_assert_equal(_night_stats_system.customers_served, 1, "Confirm must record NightStats once.")
	_assert_equal(stock_after_first, stock_before - 1, "Confirm must consume inventory once.")
	_assert_equal(_inventory_system.get_stock(item_id), stock_after_first, "Second Confirm must not consume inventory.")
	_assert_equal(_game_manager.money, money_after_first, "Second Confirm must not add money.")
	_assert_equal(_customer_progress_system.get_completed_request_ids().size(), 1, "Confirm must record customer progress once.")

	_remember_current_log_path()
	shop.queue_free()
	await process_frame


func _test_continue_only_once() -> void:
	_reset_runtime()
	var result_scene = load(RESULT_SCENE_PATH).instantiate()
	root.add_child(result_scene)
	await process_frame

	var first_continue = result_scene.continue_once(false)
	var index_after_first = _customer_system.current_customer_index
	var second_continue = result_scene.continue_once(false)
	_assert(first_continue, "The first Continue must execute.")
	_assert(not second_continue, "Continue must not execute twice.")
	_assert_equal(index_after_first, 1, "Continue must advance exactly one customer.")
	_assert_equal(_customer_system.current_customer_index, index_after_first, "Second Continue must not advance again.")

	result_scene.queue_free()
	await process_frame


func _test_start_next_night_only_once() -> void:
	_reset_runtime()
	for index in range(_customer_system.get_current_customer_queue().size()):
		var customer: Dictionary = _customer_system.get_current_customer_queue()[index]
		_customer_progress_system.record_customer_result(
			customer,
			{
				"service_id": "stage12a:night1:%d" % index,
				"customer_id": str(customer.get("id", "")),
				"grade": "good",
				"score": 75,
				"selected_item_ids": []
			}
		)
	var restock_scene = load(RESTOCK_SCENE_PATH).instantiate()
	root.add_child(restock_scene)
	await process_frame

	var first_start = restock_scene.start_next_night_once(false)
	var night_after_first = _game_manager.current_night
	var second_start = restock_scene.start_next_night_once(false)
	_assert(first_start, "The first Start Next Night must execute.")
	_assert(not second_start, "Start Next Night must not execute twice.")
	_assert_equal(night_after_first, 2, "Start Next Night must increase night once.")
	_assert_equal(_game_manager.current_night, night_after_first, "Second Start Next Night must not increase night.")

	restock_scene.queue_free()
	await process_frame


func _test_buy_boundaries() -> void:
	_reset_runtime()
	var item_id: String = _get_unlocked_item_ids(1)[0]
	var item: Dictionary = _data_manager.get_item_by_id(item_id)
	var max_stock = _inventory_system.get_max_stock(item_id)
	var buy_price := int(item.get("buy_price", 0))
	_inventory_system.consume_item(item_id, 1)
	_game_manager.set_money(0)

	var insufficient_result: Dictionary = _inventory_system.buy_item(item_id)
	if buy_price > 0:
		_assert(not bool(insufficient_result.get("success", false)), "Buy must fail when money is insufficient.")
	_assert(_game_manager.money >= 0, "Buy must never make money negative.")

	_game_manager.set_money(10000)
	while _inventory_system.can_buy_item(item_id):
		_inventory_system.buy_item(item_id)
	_assert_equal(_inventory_system.get_stock(item_id), max_stock, "Buy may fill stock to max_stock.")
	var full_result: Dictionary = _inventory_system.buy_item(item_id)
	_assert(not bool(full_result.get("success", false)), "Buy must fail when stock is full.")
	_assert(_inventory_system.get_stock(item_id) <= max_stock, "Buy must never exceed max_stock.")


func _test_debug_next_customer_is_side_effect_free() -> void:
	_reset_runtime()
	var money_before = _game_manager.money
	var inventory_before: Dictionary = _inventory_system.export_inventory_data()
	var progress_before: Dictionary = _customer_progress_system.export_progress_data()
	var moved = _debug_manager.next_customer()

	_assert(moved, "Debug Next Customer should move when another customer exists.")
	_assert_equal(_game_manager.money, money_before, "Debug Next Customer must not modify money.")
	_assert_equal(_inventory_system.export_inventory_data(), inventory_before, "Debug Next Customer must not modify inventory.")
	_assert_equal(_customer_progress_system.export_progress_data(), progress_before, "Debug Next Customer must not write customer progress.")
	_assert_equal(_night_stats_system.customers_served, 0, "Debug Next Customer must not record NightStats.")

	var last_index = _customer_system.get_customer_count_for_current_night() - 1
	_customer_system.current_customer_index = last_index
	var moved_past_end = _debug_manager.next_customer()
	_assert(not moved_past_end, "Debug Next Customer must stop at the last customer.")
	_assert_equal(_customer_system.current_customer_index, last_index, "Debug Next Customer must not move out of bounds.")


func _test_debug_refill_does_not_unlock_items() -> void:
	_reset_runtime()
	var unlocked_id: String = _get_unlocked_item_ids(1)[0]
	var locked_id := _get_first_locked_item_id(1)
	_assert(not locked_id.is_empty(), "A future locked item is required for refill testing.")
	_inventory_system.consume_item(unlocked_id, 1)
	_inventory_system.consume_item(locked_id, 1)
	var locked_stock_before = _inventory_system.get_stock(locked_id)
	var money_before = _game_manager.money

	_assert(_debug_manager.refill_inventory(), "Debug Refill Inventory should be available in a debug build.")
	_assert_equal(
		_inventory_system.get_stock(unlocked_id),
		_inventory_system.get_max_stock(unlocked_id),
		"Debug Refill must fill unlocked items."
	)
	_assert_equal(_inventory_system.get_stock(locked_id), locked_stock_before, "Debug Refill must not modify locked items.")
	_assert_equal(_game_manager.money, money_before, "Debug Refill must not modify money.")


func _test_debug_runtime_changes_do_not_save() -> void:
	_reset_runtime()
	_save_manager.save_game("shop")
	var save_before := _read_save_text()
	_debug_manager.add_debug_money()
	_debug_manager.next_customer()
	_debug_manager.refill_inventory()
	var save_after := _read_save_text()
	_assert_equal(save_after, save_before, "Runtime debug actions must not modify the save file.")


func _test_playtest_logger_deduplicates() -> void:
	_playtest_logger.reset_runtime_state()
	var customer: Dictionary = _customer_system.get_current_customer()
	var service_result := {
		"service_id": "stage12a:dedupe",
		"customer_id": str(customer.get("id", "")),
		"selected_item_ids": [],
		"score": 75,
		"grade": "good",
		"matched_tags": [],
		"missing_tags": [],
		"bad_tags": [],
		"combo_names": [],
		"income": 0
	}
	var first_write = _playtest_logger.log_service(service_result, customer)
	var second_write = _playtest_logger.log_service(service_result, customer)
	_assert(first_write, "PlaytestLogger must write a normal debug service.")
	_assert(not second_write, "PlaytestLogger must not write the same service_id twice.")
	_assert(_playtest_logger.has_recorded_service_id("stage12a:dedupe"), "PlaytestLogger must remember the service_id.")
	_remember_current_log_path()


func _test_release_guards() -> void:
	_assert(not _debug_manager.is_available(false), "Debug features must be unavailable for a Release state.")
	_assert(not _playtest_logger.is_available(false), "PlaytestLogger must be unavailable for a Release state.")


func _test_night_result_consistency() -> void:
	var night_result = load(NIGHT_RESULT_SCRIPT_PATH).new()
	var consistent := {
		"customers_served": 4,
		"perfect_count": 1,
		"good_count": 1,
		"normal_count": 1,
		"fail_count": 1
	}
	var inconsistent := consistent.duplicate()
	inconsistent["fail_count"] = 0
	_assert(night_result.has_consistent_grade_total(consistent), "NightResult grade total should accept consistent data.")
	_assert(not night_result.has_consistent_grade_total(inconsistent), "NightResult grade total should detect inconsistent data.")
	night_result.free()


func _reset_runtime() -> void:
	_debug_manager.reset_runtime_state()
	_customer_progress_system.reset_progress()
	_save_manager.current_save = _save_manager.create_default_save()
	_inventory_system.reset_to_default_stock()
	_customer_system.reset_queue()
	_game_manager.set_current_night(1)
	_game_manager.set_money(0)
	_game_manager.last_result = {}
	_game_manager.last_service_result = {}
	_game_manager.pending_customer_id = ""
	_customer_system.build_queue_for_night(1)
	_night_stats_system.start_night(1)


func _get_unlocked_item_ids(night: int) -> Array[String]:
	var result: Array[String] = []
	for item in _data_manager.get_all_items():
		if item is Dictionary and int(item.get("unlock_day", 1)) <= night:
			result.append(str(item.get("id", "")))
	return result


func _get_first_locked_item_id(night: int) -> String:
	for item in _data_manager.get_all_items():
		if item is Dictionary and int(item.get("unlock_day", 1)) > night:
			return str(item.get("id", ""))
	return ""


func _remember_current_log_path() -> void:
	var log_path := str(_playtest_logger.get_session_path())
	if not log_path.is_empty() and not _created_log_paths.has(log_path):
		_created_log_paths.append(log_path)


func _backup_save() -> void:
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if not _save_existed:
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not back up the existing save file.")
		return
	_save_backup_text = file.get_as_text()


func _restore_external_state() -> void:
	for log_path in _created_log_paths:
		if FileAccess.file_exists(log_path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))
			if error != OK:
				print("WARNING: Could not remove Stage 12A temporary log: %s" % log_path)

	_playtest_logger.reset_runtime_state()
	if _save_existed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			print("WARNING: Could not restore the existing save file.")
			return
		file.store_string(_save_backup_text)
	elif FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			print("WARNING: Could not remove the Stage 12A temporary save.")


func _read_save_text() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


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
		print("Stage 12A smoke test passed.")
		quit(0)
		return

	print("Stage 12A smoke test failed.")
	for failure in _failures:
		print(" - %s" % failure)
	quit(1)
