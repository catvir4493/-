extends Node

signal save_loaded(save_data: Dictionary)
signal save_written(save_data: Dictionary)
signal save_failed(message: String)

const SAVE_PATH := "user://save_data.json"
const CURRENT_SAVE_VERSION := 1
const DEFAULT_START_NIGHT := 1
const DEFAULT_START_MONEY := 0
const VALID_CHECKPOINTS := ["night_result", "restock", "shop"]

var current_save: Dictionary = {}


func _ready() -> void:
	current_save = create_default_save()


func create_default_save() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"checkpoint_scene": "shop",
		"current_night": DEFAULT_START_NIGHT,
		"money": DEFAULT_START_MONEY,
		"inventory": {},
		"unlocked_items": [],
		"seen_customers": [],
		"customer_story_progress": {},
		"discovered_combos": [],
		"night_stats": {}
	}


func create_save_data(checkpoint_scene: String) -> Dictionary:
	var normalized_checkpoint := _normalize_checkpoint(checkpoint_scene)
	var save_data := create_default_save()
	save_data["checkpoint_scene"] = normalized_checkpoint
	save_data["current_night"] = GameManager.current_night
	save_data["money"] = GameManager.money
	save_data["inventory"] = InventorySystem.export_inventory_data()
	save_data["unlocked_items"] = _get_unlocked_items_for_current_night()
	var progress_data := _export_customer_progress_data()
	save_data["seen_customers"] = progress_data["seen_customers"]
	save_data["customer_story_progress"] = progress_data["customer_story_progress"]
	save_data["discovered_combos"] = get_discovered_combos()
	save_data["night_stats"] = NightStatsSystem.export_night_stats()
	return save_data


func save_game(checkpoint_scene: String = "shop") -> bool:
	var save_data := create_save_data(checkpoint_scene)
	current_save = save_data.duplicate(true)
	_ensure_save_directory(SAVE_PATH)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_report_save_failure("Could not open save file for writing. Error code: %s." % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	save_written.emit(get_save_data())
	return true


func load_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file. Error code: %s." % FileAccess.get_open_error())
		return {}

	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_warning("Invalid save JSON at line %d: %s." % [json.get_error_line(), json.get_error_message()])
		return {}

	if not (json.data is Dictionary):
		push_warning("Save file root must be a Dictionary.")
		return {}

	var normalized := _normalize_save_data(json.data)
	if normalized.is_empty():
		return {}

	current_save = normalized.duplicate(true)
	save_loaded.emit(get_save_data())
	return get_save_data()


func apply_save_data(save_data: Dictionary) -> bool:
	var normalized := _normalize_save_data(save_data)
	if normalized.is_empty():
		return false

	current_save = normalized.duplicate(true)

	GameManager.set_current_night(int(normalized["current_night"]))
	GameManager.set_money(int(normalized["money"]))
	GameManager.last_result = {}
	GameManager.last_service_result = {}
	GameManager.pending_customer_id = ""

	if not InventorySystem.import_inventory_data(normalized["inventory"]):
		push_warning("Inventory data could not be fully restored; default inventory was used where needed.")

	set_discovered_combos(normalized["discovered_combos"])
	_import_customer_progress_from_save_data(normalized)

	var checkpoint := str(normalized["checkpoint_scene"])
	if checkpoint == "shop":
		CustomerSystem.generate_night_queue(GameManager.current_night)
		NightStatsSystem.start_night(GameManager.current_night)
		GameManager.continue_current_night()
	elif checkpoint == "night_result":
		NightStatsSystem.import_night_stats(normalized["night_stats"])
		GameManager.go_to_night_result()
	elif checkpoint == "restock":
		NightStatsSystem.import_night_stats(normalized["night_stats"])
		GameManager.go_to_restock(true, false)
	else:
		push_warning("Unsupported checkpoint_scene: %s." % checkpoint)
		return false

	return true


func continue_game() -> bool:
	var save_data := load_save_data()
	if save_data.is_empty():
		return false

	return apply_save_data(save_data)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func has_valid_save() -> bool:
	if not has_save():
		return false

	var save_data := load_save_data()
	return not save_data.is_empty()


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		current_save = create_default_save()
		return true

	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		_report_save_failure("Could not delete save file. Error code: %s." % error)
		return false

	current_save = create_default_save()
	return true


func get_saved_checkpoint() -> String:
	var save_data := load_save_data()
	if save_data.is_empty():
		return ""

	return str(save_data.get("checkpoint_scene", ""))


func load_customer_progress_from_save() -> bool:
	var save_data := load_save_data()
	if save_data.is_empty():
		return false

	return _import_customer_progress_from_save_data(save_data)


func load_game() -> Dictionary:
	return load_save_data()


func new_game(initial_night: int = DEFAULT_START_NIGHT, initial_money: int = DEFAULT_START_MONEY) -> Dictionary:
	current_save = create_default_save()
	current_save["current_night"] = max(initial_night, DEFAULT_START_NIGHT)
	current_save["money"] = max(initial_money, 0)
	return get_save_data()


func get_save_data() -> Dictionary:
	if current_save.is_empty():
		current_save = create_default_save()

	return current_save.duplicate(true)


func update_core_state(night: int, new_money: int) -> void:
	current_save = _with_defaults(current_save)
	current_save["current_night"] = max(night, DEFAULT_START_NIGHT)
	current_save["money"] = max(new_money, 0)


func get_inventory() -> Dictionary:
	current_save = _with_defaults(current_save)
	return current_save["inventory"].duplicate(true)


func set_inventory(inventory: Dictionary) -> void:
	current_save = _with_defaults(current_save)
	current_save["inventory"] = inventory.duplicate(true)


func add_inventory_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount == 0:
		return

	current_save = _with_defaults(current_save)
	var inventory: Dictionary = current_save["inventory"]
	var next_amount := int(inventory.get(item_id, 0)) + amount

	if next_amount <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next_amount

	current_save["inventory"] = inventory


func remove_inventory_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	current_save = _with_defaults(current_save)
	var inventory: Dictionary = current_save["inventory"]
	var current_amount := int(inventory.get(item_id, 0))
	if current_amount < amount:
		return false

	var next_amount := current_amount - amount
	if next_amount <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next_amount

	current_save["inventory"] = inventory
	return true


func get_unlocked_items() -> Array:
	current_save = _with_defaults(current_save)
	return current_save["unlocked_items"].duplicate(true)


func set_unlocked_items(item_ids: Array) -> void:
	current_save = _with_defaults(current_save)
	current_save["unlocked_items"] = _unique_string_array(item_ids)


func unlock_item(item_id: String) -> void:
	if item_id.is_empty():
		return

	current_save = _with_defaults(current_save)
	var unlocked_items := get_unlocked_items()
	if not unlocked_items.has(item_id):
		unlocked_items.append(item_id)

	current_save["unlocked_items"] = unlocked_items


func is_item_unlocked(item_id: String) -> bool:
	return get_unlocked_items().has(item_id)


func get_seen_customers() -> Array:
	return _export_customer_progress_data()["seen_customers"].duplicate(true)


func set_seen_customers(customer_ids: Array) -> void:
	var progress_data := _export_customer_progress_data()
	progress_data["seen_customers"] = _unique_string_array(customer_ids)
	_import_customer_progress_from_save_data(progress_data)


func mark_customer_seen(story_id: String) -> void:
	if story_id.is_empty():
		return

	var seen_customers := get_seen_customers()
	if not seen_customers.has(story_id):
		seen_customers.append(story_id)

	set_seen_customers(seen_customers)


func has_seen_customer(story_id: String) -> bool:
	return get_seen_customers().has(story_id)


func get_customer_story_progress() -> Dictionary:
	return _export_customer_progress_data()["customer_story_progress"].duplicate(true)


func set_customer_story_progress(progress: Dictionary) -> void:
	var progress_data := _export_customer_progress_data()
	progress_data["customer_story_progress"] = progress.duplicate(true)
	_import_customer_progress_from_save_data(progress_data)


func get_discovered_combos() -> Array:
	current_save = _with_defaults(current_save)
	return current_save["discovered_combos"].duplicate(true)


func set_discovered_combos(combo_ids: Array) -> void:
	current_save = _with_defaults(current_save)
	current_save["discovered_combos"] = _unique_string_array(combo_ids)


func mark_combo_discovered(combo_id: String) -> void:
	if combo_id.is_empty():
		return

	current_save = _with_defaults(current_save)
	var discovered_combos := get_discovered_combos()
	if not discovered_combos.has(combo_id):
		discovered_combos.append(combo_id)

	current_save["discovered_combos"] = discovered_combos


func has_discovered_combo(combo_id: String) -> bool:
	return get_discovered_combos().has(combo_id)


func _export_customer_progress_data() -> Dictionary:
	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("export_progress_data"):
		var exported = customer_progress_system.export_progress_data()
		if exported is Dictionary:
			return _normalize_progress_export(exported)

	current_save = _with_defaults(current_save)
	return {
		"seen_customers": current_save["seen_customers"].duplicate(true),
		"customer_story_progress": current_save["customer_story_progress"].duplicate(true)
	}


func _import_customer_progress_from_save_data(save_data: Dictionary) -> bool:
	var progress_data := {
		"seen_customers": save_data.get("seen_customers", []),
		"customer_story_progress": save_data.get("customer_story_progress", {})
	}

	var normalized := _normalize_progress_export(progress_data)
	current_save = _with_defaults(current_save)
	current_save["seen_customers"] = normalized["seen_customers"].duplicate(true)
	current_save["customer_story_progress"] = normalized["customer_story_progress"].duplicate(true)

	var customer_progress_system := _get_customer_progress_system()
	if customer_progress_system != null and customer_progress_system.has_method("import_progress_data"):
		return customer_progress_system.import_progress_data(normalized)

	return true


func _normalize_progress_export(progress_data: Dictionary) -> Dictionary:
	var seen = progress_data.get("seen_customers", [])
	if not (seen is Array):
		seen = []

	var progress = progress_data.get("customer_story_progress", {})
	if not (progress is Dictionary):
		progress = {}

	return {
		"seen_customers": _unique_string_array(seen),
		"customer_story_progress": progress.duplicate(true)
	}


func _get_customer_progress_system() -> Node:
	return get_node_or_null("/root/CustomerProgressSystem")


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var save_version := _read_save_version(raw_data)
	if save_version > CURRENT_SAVE_VERSION:
		push_warning("Save version %d is newer than supported version %d." % [save_version, CURRENT_SAVE_VERSION])
		return {}

	if raw_data.has("checkpoint_scene") and not VALID_CHECKPOINTS.has(str(raw_data["checkpoint_scene"])):
		push_warning("Save checkpoint_scene is unsupported: %s." % str(raw_data["checkpoint_scene"]))
		return {}

	var normalized := _with_defaults(raw_data)
	if int(normalized["current_night"]) < DEFAULT_START_NIGHT:
		push_warning("Save current_night is invalid.")
		return {}

	if int(normalized["money"]) < 0:
		push_warning("Save money is invalid.")
		return {}

	return normalized


func _with_defaults(save_data: Dictionary) -> Dictionary:
	var merged := create_default_save()

	for key in save_data.keys():
		merged[key] = _copy_value(save_data[key])

	merged["save_version"] = _read_save_version(merged)
	merged["checkpoint_scene"] = _normalize_checkpoint(str(merged.get("checkpoint_scene", "shop")))
	merged["current_night"] = max(_to_int(merged.get("current_night", DEFAULT_START_NIGHT), DEFAULT_START_NIGHT), DEFAULT_START_NIGHT)
	merged["money"] = max(_to_int(merged.get("money", DEFAULT_START_MONEY), DEFAULT_START_MONEY), 0)

	if not (merged.get("inventory", {}) is Dictionary):
		merged["inventory"] = {}

	if not (merged.get("unlocked_items", []) is Array):
		merged["unlocked_items"] = []

	if not (merged.get("seen_customers", []) is Array):
		merged["seen_customers"] = []

	if not (merged.get("customer_story_progress", {}) is Dictionary):
		merged["customer_story_progress"] = {}

	if not (merged.get("discovered_combos", []) is Array):
		merged["discovered_combos"] = []

	if not (merged.get("night_stats", {}) is Dictionary):
		merged["night_stats"] = {}

	merged["unlocked_items"] = _unique_string_array(merged["unlocked_items"])
	merged["seen_customers"] = _unique_string_array(merged["seen_customers"])
	merged["discovered_combos"] = _unique_string_array(merged["discovered_combos"])
	merged["inventory"] = merged["inventory"].duplicate(true)
	merged["customer_story_progress"] = merged["customer_story_progress"].duplicate(true)
	merged["night_stats"] = merged["night_stats"].duplicate(true)
	return merged


func _read_save_version(data: Dictionary) -> int:
	if data.has("save_version"):
		return _to_int(data.get("save_version", CURRENT_SAVE_VERSION), CURRENT_SAVE_VERSION)

	if data.has("version"):
		return _to_int(data.get("version", CURRENT_SAVE_VERSION), CURRENT_SAVE_VERSION)

	return CURRENT_SAVE_VERSION


func _normalize_checkpoint(checkpoint_scene: String) -> String:
	if VALID_CHECKPOINTS.has(checkpoint_scene):
		return checkpoint_scene

	return "shop"


func _get_unlocked_items_for_current_night() -> Array:
	var unlocked_items: Array[String] = []

	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue

		if int(item.get("unlock_day", 1)) <= GameManager.current_night:
			unlocked_items.append(item_id)

	return unlocked_items


func _copy_value(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)

	return value


func _unique_string_array(values: Array) -> Array:
	var result := []

	for value in values:
		var value_id := str(value)
		if value_id.is_empty():
			continue

		if not result.has(value_id):
			result.append(value_id)

	return result


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value


func _ensure_save_directory(save_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(save_path)
	var save_directory := global_path.get_base_dir()

	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_recursive_absolute(save_directory)


func _report_save_failure(message: String) -> void:
	push_error(message)
	save_failed.emit(message)
