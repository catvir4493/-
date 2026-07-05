extends Node

signal night_changed(current_night: int)
signal money_changed(money: int)
signal game_state_changed(new_state: int, previous_state: int)
signal game_started
signal game_loaded
signal game_saved
signal night_started(current_night: int)
signal scene_change_started(scene_path: String)
signal scene_change_finished(scene_path: String)
signal scene_change_failed(scene_path: String, message: String)

enum GameState {
	BOOT,
	MAIN_MENU,
	SHOP,
	CUSTOMER,
	SCORING,
	RESULT,
	RESTOCK,
	NIGHT_COMPLETE,
	ARCHIVE,
	PAUSED
}

const DEFAULT_START_NIGHT := 1
const DEFAULT_START_MONEY := 0

const STATE_NAMES := {
	GameState.BOOT: "boot",
	GameState.MAIN_MENU: "main_menu",
	GameState.SHOP: "shop",
	GameState.CUSTOMER: "customer",
	GameState.SCORING: "scoring",
	GameState.RESULT: "result",
	GameState.RESTOCK: "restock",
	GameState.NIGHT_COMPLETE: "night_complete",
	GameState.ARCHIVE: "archive",
	GameState.PAUSED: "paused"
}

var scene_paths := {
	GameState.MAIN_MENU: "res://scenes/main_menu/MainMenu.tscn",
	GameState.SHOP: "res://scenes/shop/ShopScene.tscn",
	GameState.RESULT: "res://scenes/result/ResultScene.tscn",
	GameState.NIGHT_COMPLETE: "res://scenes/night_result/NightResultScene.tscn",
	GameState.RESTOCK: "res://scenes/restock/RestockScene.tscn",
	GameState.ARCHIVE: "res://scenes/archive/ArchiveScene.tscn"
}

var game_state: int = GameState.BOOT
var last_result: Dictionary = {}
var last_service_result: Dictionary = {}
var pending_customer_id := ""

var _current_night := DEFAULT_START_NIGHT
var _money := DEFAULT_START_MONEY

var current_night: int:
	get:
		return _current_night
	set(value):
		set_current_night(value)

var money: int:
	get:
		return _money
	set(value):
		set_money(value)


func _ready() -> void:
	_set_state(GameState.MAIN_MENU)


func start_new_game(change_scene: bool = true) -> void:
	current_night = DEFAULT_START_NIGHT
	money = DEFAULT_START_MONEY
	last_result = {}
	last_service_result = {}
	pending_customer_id = ""
	_reset_customer_progress()

	var inventory_system: Node = _get_inventory_system()
	if inventory_system != null and inventory_system.has_method("reset_to_default_stock"):
		inventory_system.reset_to_default_stock()

	_start_customer_queue()
	_start_night_stats()

	var save_manager = _get_save_manager()
	if save_manager != null:
		if save_manager.has_method("new_game"):
			save_manager.new_game(current_night, money)
		if save_manager.has_method("save_game"):
			save_manager.save_game("shop")

	_set_state(GameState.SHOP)
	game_started.emit()

	if change_scene:
		_change_scene_for_state(GameState.SHOP)


func load_game(change_scene: bool = true) -> bool:
	var save_manager = _get_save_manager()
	if save_manager == null or not save_manager.has_method("continue_game"):
		push_warning("SaveManager is not available.")
		return false

	var loaded: bool = save_manager.continue_game()
	if loaded:
		game_loaded.emit()
	return loaded


func save_game(checkpoint_scene: String = "shop") -> bool:
	var save_manager = _get_save_manager()
	if save_manager == null or not save_manager.has_method("save_game"):
		push_warning("SaveManager is not available.")
		return false

	var saved: bool = save_manager.save_game(checkpoint_scene)
	if saved:
		game_saved.emit()

	return saved


func go_to_main_menu(change_scene: bool = true) -> void:
	_set_state(GameState.MAIN_MENU)

	if change_scene:
		_change_scene_for_state(GameState.MAIN_MENU)


func start_night(night_id: int = -1, change_scene: bool = true) -> void:
	if night_id > 0:
		current_night = night_id

	last_result = {}
	last_service_result = {}
	pending_customer_id = ""
	_start_customer_queue()
	_start_night_stats()
	_set_state(GameState.SHOP)
	night_started.emit(current_night)

	if change_scene:
		_change_scene_for_state(GameState.SHOP)


func begin_customer(customer_id: String = "") -> void:
	pending_customer_id = customer_id
	_set_state(GameState.CUSTOMER)


func begin_scoring(customer_id: String = "") -> void:
	if not customer_id.is_empty():
		pending_customer_id = customer_id

	_set_state(GameState.SCORING)


func submit_customer_result(result: Dictionary) -> void:
	last_result = result.duplicate(true)

	if result.has("money_earned"):
		add_money(int(result["money_earned"]))
	elif result.has("reward_money"):
		add_money(int(result["reward_money"]))

	if not pending_customer_id.is_empty():
		var save_manager = _get_save_manager()
		if save_manager != null and save_manager.has_method("mark_customer_seen"):
			save_manager.mark_customer_seen(pending_customer_id)

	show_result(result)


func show_result(result: Dictionary = {}, change_scene: bool = true) -> void:
	if not result.is_empty():
		last_result = result.duplicate(true)
		set_last_service_result(result)

	_set_state(GameState.RESULT)

	if change_scene:
		_change_scene_for_state(GameState.RESULT)


func set_last_service_result(result: Dictionary) -> void:
	last_service_result = result.duplicate(true)
	last_result = last_service_result.duplicate(true)
	_mark_combo_discovered_from_result(last_service_result)


func get_last_service_result() -> Dictionary:
	return last_service_result.duplicate(true)


func continue_current_night(change_scene: bool = true) -> void:
	_set_state(GameState.SHOP)

	if change_scene:
		_change_scene_for_state(GameState.SHOP)


func go_to_restock(change_scene: bool = true, save_checkpoint: bool = true) -> void:
	if save_checkpoint:
		save_game("restock")
	_set_state(GameState.RESTOCK)

	if change_scene:
		_change_scene_for_state(GameState.RESTOCK)


func go_to_night_result(change_scene: bool = true) -> void:
	_set_state(GameState.NIGHT_COMPLETE)

	if change_scene:
		_change_scene_for_state(GameState.NIGHT_COMPLETE)


func go_to_archive(change_scene: bool = true) -> void:
	_set_state(GameState.ARCHIVE)

	if change_scene:
		_change_scene_for_state(GameState.ARCHIVE)


func finish_restock(change_scene: bool = true) -> void:
	start_next_night(change_scene)


func start_next_night(change_scene: bool = true) -> void:
	current_night = current_night + 1
	last_result = {}
	last_service_result = {}
	pending_customer_id = ""
	_start_customer_queue()
	_start_night_stats()
	_set_state(GameState.SHOP)
	night_started.emit(current_night)
	save_game("shop")

	if change_scene:
		_change_scene_for_state(GameState.SHOP)


func advance_night(save_after_advance: bool = true) -> void:
	current_night = current_night + 1
	_set_state(GameState.NIGHT_COMPLETE)

	if save_after_advance:
		save_game("night_result")


func set_current_night(value: int) -> void:
	var next_night: int = maxi(value, DEFAULT_START_NIGHT)
	if _current_night == next_night:
		return

	_current_night = next_night
	night_changed.emit(_current_night)


func set_money(value: int) -> void:
	var next_money: int = maxi(value, 0)
	if _money == next_money:
		return

	_money = next_money
	money_changed.emit(_money)


func add_money(amount: int) -> void:
	if amount == 0:
		return

	money = money + amount


func can_spend_money(amount: int) -> bool:
	return amount >= 0 and money >= amount


func spend_money(amount: int) -> bool:
	if not can_spend_money(amount):
		return false

	money = money - amount
	return true


func set_scene_path(state: int, scene_path: String) -> void:
	scene_paths[state] = scene_path


func get_scene_path(state: int) -> String:
	return str(scene_paths.get(state, ""))


func change_scene_to_path(scene_path: String) -> bool:
	if scene_path.is_empty():
		_report_scene_failure(scene_path, "Scene path is empty.")
		return false

	scene_change_started.emit(scene_path)

	if not ResourceLoader.exists(scene_path):
		_report_scene_failure(scene_path, "Scene file does not exist yet.")
		return false

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_report_scene_failure(scene_path, "Could not change scene. Error code: %s." % error)
		return false

	scene_change_finished.emit(scene_path)
	return true


func get_state_name(state: int = -1) -> String:
	if state < 0:
		state = game_state

	return str(STATE_NAMES.get(state, "unknown"))


func get_current_night_data() -> Dictionary:
	var data_manager = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_night"):
		return data_manager.get_night(current_night)

	return {}


func _change_scene_for_state(state: int) -> bool:
	return change_scene_to_path(get_scene_path(state))


func _set_state(new_state: int) -> void:
	if game_state == new_state:
		return

	var previous_state := game_state
	game_state = new_state
	game_state_changed.emit(game_state, previous_state)


func _build_save_data() -> Dictionary:
	var save_data := {}
	var save_manager = _get_save_manager()

	if save_manager != null and save_manager.has_method("get_save_data"):
		var existing_save = save_manager.get_save_data()
		if existing_save is Dictionary:
			save_data = existing_save.duplicate(true)

	save_data["current_night"] = current_night
	save_data["money"] = money

	var inventory_system: Node = _get_inventory_system()
	if inventory_system != null and inventory_system.has_method("get_inventory"):
		save_data["inventory"] = inventory_system.get_inventory()

	return save_data


func _apply_save_data(save_data: Dictionary) -> void:
	if save_data.has("current_night"):
		current_night = int(save_data["current_night"])

	if save_data.has("money"):
		money = int(save_data["money"])

	var inventory_system: Node = _get_inventory_system()
	if inventory_system != null:
		if save_data.has("inventory") and save_data["inventory"] is Dictionary and not save_data["inventory"].is_empty():
			inventory_system.set_inventory(save_data["inventory"])
		elif inventory_system.has_method("reset_to_default_stock"):
			inventory_system.reset_to_default_stock()


func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")


func _get_data_manager() -> Node:
	return get_node_or_null("/root/DataManager")


func _get_inventory_system() -> Node:
	return get_node_or_null("/root/InventorySystem")


func _get_customer_system() -> Node:
	return get_node_or_null("/root/CustomerSystem")


func _get_night_stats_system() -> Node:
	return get_node_or_null("/root/NightStatsSystem")


func _get_customer_progress_system() -> Node:
	return get_node_or_null("/root/CustomerProgressSystem")


func _start_customer_queue() -> void:
	var customer_system: Node = _get_customer_system()
	if customer_system != null and customer_system.has_method("generate_night_queue"):
		customer_system.generate_night_queue(current_night)


func _start_night_stats() -> void:
	var night_stats_system: Node = _get_night_stats_system()
	if night_stats_system != null and night_stats_system.has_method("start_night"):
		night_stats_system.start_night(current_night)


func _reset_customer_progress() -> void:
	var customer_progress_system: Node = _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("reset_progress"):
		customer_progress_system.reset_progress()


func _mark_combo_discovered_from_result(result: Dictionary) -> void:
	var save_manager: Node = _get_save_manager()
	if save_manager == null or not save_manager.has_method("mark_combo_discovered"):
		return

	var triggered_combos = result.get("triggered_combos", [])
	if triggered_combos is Array:
		if not triggered_combos.is_empty():
			for combo in triggered_combos:
				if combo is Dictionary:
					_mark_single_combo_discovered(save_manager, combo)
			return

	var combo_result = result.get("combo_result", {})
	if combo_result is Dictionary:
		_mark_single_combo_discovered(save_manager, combo_result)


func _mark_single_combo_discovered(save_manager: Node, combo_result: Dictionary) -> void:
	var combo_id := str(combo_result.get("id", ""))
	if combo_id.is_empty():
		return

	save_manager.mark_combo_discovered(combo_id)


func _report_scene_failure(scene_path: String, message: String) -> void:
	push_warning("%s %s" % [message, scene_path])
	scene_change_failed.emit(scene_path, message)
