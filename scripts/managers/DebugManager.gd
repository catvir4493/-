extends Node

const OVERLAY_SCENE_PATH := "res://scenes/debug/DebugPlaytestOverlay.tscn"
const DEBUG_MONEY_AMOUNT := 100

var _overlay: CanvasLayer
var _runtime_baseline: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_available():
		return

	var overlay_scene := load(OVERLAY_SCENE_PATH) as PackedScene
	if overlay_scene == null:
		push_warning("Debug playtest overlay could not be loaded.")
		return

	_overlay = overlay_scene.instantiate() as CanvasLayer
	if _overlay == null:
		push_warning("Debug playtest overlay root must be a CanvasLayer.")
		return

	add_child(_overlay)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_available() or _overlay == null:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_overlay.call("toggle_overlay")
		get_viewport().set_input_as_handled()


func is_available(debug_build_override = null) -> bool:
	if debug_build_override is bool:
		return bool(debug_build_override)

	return OS.is_debug_build()


func jump_to_night(night_number: int) -> bool:
	if not is_available() or night_number < 1 or night_number > 5:
		return false

	_capture_runtime_baseline_if_needed()
	GameManager.start_night(night_number)
	return true


func next_customer() -> bool:
	if not is_available() or not CustomerSystem.has_more_customers():
		return false

	var current_index := CustomerSystem.current_customer_index
	var customer_count := CustomerSystem.get_customer_count_for_current_night()
	if current_index >= customer_count - 1:
		return false

	_capture_runtime_baseline_if_needed()
	return CustomerSystem.move_to_next_customer()


func refill_inventory() -> bool:
	if not is_available():
		return false

	_capture_runtime_baseline_if_needed()
	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		if int(item.get("unlock_day", 1)) > GameManager.current_night:
			continue

		var item_id := str(item.get("id", ""))
		var missing_stock := InventorySystem.get_max_stock(item_id) - InventorySystem.get_stock(item_id)
		if missing_stock > 0:
			InventorySystem.add_stock(item_id, missing_stock)

	return true


func add_debug_money(amount: int = DEBUG_MONEY_AMOUNT) -> bool:
	if not is_available() or amount <= 0:
		return false

	_capture_runtime_baseline_if_needed()
	GameManager.add_money(amount)
	return true


func clear_runtime_debug_changes() -> bool:
	if not is_available():
		return false

	if SaveManager.has_valid_save():
		_runtime_baseline.clear()
		return SaveManager.continue_game()

	if _runtime_baseline.is_empty():
		InventorySystem.reset_to_default_stock()
		GameManager.set_money(GameManager.DEFAULT_START_MONEY)
		GameManager.start_night(GameManager.current_night)
		return true

	var baseline := _runtime_baseline.duplicate(true)
	_runtime_baseline.clear()
	CustomerProgressSystem.import_progress_data(baseline.get("customer_progress", {}))
	InventorySystem.import_inventory_data(baseline.get("inventory", {}))
	GameManager.set_money(int(baseline.get("money", GameManager.DEFAULT_START_MONEY)))
	GameManager.start_night(int(baseline.get("night", GameManager.current_night)))
	return true


func save_debug_state() -> bool:
	if not is_available():
		return false

	return GameManager.save_game(_get_safe_checkpoint())


func reset_runtime_state() -> void:
	_runtime_baseline.clear()


func _get_safe_checkpoint() -> String:
	match GameManager.game_state:
		GameManager.GameState.NIGHT_COMPLETE:
			return "night_result"
		GameManager.GameState.RESTOCK:
			return "restock"
		_:
			return "shop"


func _capture_runtime_baseline_if_needed() -> void:
	if not _runtime_baseline.is_empty():
		return

	_runtime_baseline = {
		"night": GameManager.current_night,
		"money": GameManager.money,
		"inventory": InventorySystem.export_inventory_data(),
		"customer_progress": CustomerProgressSystem.export_progress_data()
	}
