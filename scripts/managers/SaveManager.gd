extends Node

signal save_loaded(save_data: Dictionary)
signal save_written(save_data: Dictionary)
signal save_failed(message: String)

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
const DEFAULT_START_NIGHT := 1
const DEFAULT_START_MONEY := 0

var current_save: Dictionary = {}


func _ready() -> void:
	_ensure_current_save()


func create_default_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_night": DEFAULT_START_NIGHT,
		"money": DEFAULT_START_MONEY,
		"inventory": {},
		"unlocked_items": [],
		"seen_customers": [],
		"customer_story_progress": {},
		"discovered_combos": []
	}


func new_game(initial_night: int = DEFAULT_START_NIGHT, initial_money: int = DEFAULT_START_MONEY) -> Dictionary:
	current_save = create_default_save()
	current_save["current_night"] = max(initial_night, DEFAULT_START_NIGHT)
	current_save["money"] = max(initial_money, 0)
	return get_save_data()


func has_save(save_path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(save_path)


func save_game(data: Dictionary = {}, save_path: String = SAVE_PATH) -> bool:
	_ensure_current_save()

	if not data.is_empty():
		_merge_save_data(data)

	current_save["version"] = SAVE_VERSION
	_normalize_current_save()
	_ensure_save_directory(save_path)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_report_save_failure("Could not open save file. Error code: %s." % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(current_save, "\t"))
	save_written.emit(get_save_data())
	return true


func load_game(save_path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		_report_save_failure("No save file found at %s." % save_path)
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_report_save_failure("Could not open save file. Error code: %s." % FileAccess.get_open_error())
		return {}

	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		var message := "Invalid save JSON at line %d: %s." % [json.get_error_line(), json.get_error_message()]
		_report_save_failure(message)
		return {}

	if not (json.data is Dictionary):
		_report_save_failure("Save file root must be a Dictionary.")
		return {}

	current_save = _with_defaults(json.data)
	save_loaded.emit(get_save_data())
	return get_save_data()


func delete_save(save_path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(save_path):
		return true

	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if error != OK:
		_report_save_failure("Could not delete save file. Error code: %s." % error)
		return false

	current_save = create_default_save()
	return true


func get_save_data() -> Dictionary:
	_ensure_current_save()
	return current_save.duplicate(true)


func update_core_state(night: int, new_money: int) -> void:
	_ensure_current_save()
	current_save["current_night"] = max(night, DEFAULT_START_NIGHT)
	current_save["money"] = max(new_money, 0)


func get_inventory() -> Dictionary:
	_ensure_current_save()
	return current_save["inventory"].duplicate(true)


func set_inventory(inventory: Dictionary) -> void:
	_ensure_current_save()
	current_save["inventory"] = inventory.duplicate(true)


func add_inventory_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount == 0:
		return

	_ensure_current_save()
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

	_ensure_current_save()
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
	_ensure_current_save()
	return current_save["unlocked_items"].duplicate(true)


func set_unlocked_items(item_ids: Array) -> void:
	_ensure_current_save()
	current_save["unlocked_items"] = _unique_string_array(item_ids)


func unlock_item(item_id: String) -> void:
	if item_id.is_empty():
		return

	_ensure_current_save()
	var unlocked_items := get_unlocked_items()
	if not unlocked_items.has(item_id):
		unlocked_items.append(item_id)

	current_save["unlocked_items"] = unlocked_items


func is_item_unlocked(item_id: String) -> bool:
	return get_unlocked_items().has(item_id)


func get_seen_customers() -> Array:
	_ensure_current_save()
	return current_save["seen_customers"].duplicate(true)


func set_seen_customers(customer_ids: Array) -> void:
	_ensure_current_save()
	current_save["seen_customers"] = _unique_string_array(customer_ids)


func mark_customer_seen(customer_id: String) -> void:
	if customer_id.is_empty():
		return

	_ensure_current_save()
	var seen_customers := get_seen_customers()
	if not seen_customers.has(customer_id):
		seen_customers.append(customer_id)

	current_save["seen_customers"] = seen_customers


func has_seen_customer(customer_id: String) -> bool:
	return get_seen_customers().has(customer_id)


func get_discovered_combos() -> Array:
	_ensure_current_save()
	return current_save["discovered_combos"].duplicate(true)


func set_discovered_combos(combo_ids: Array) -> void:
	_ensure_current_save()
	current_save["discovered_combos"] = _unique_string_array(combo_ids)


func mark_combo_discovered(combo_id: String) -> void:
	if combo_id.is_empty():
		return

	_ensure_current_save()
	var discovered_combos := get_discovered_combos()
	if not discovered_combos.has(combo_id):
		discovered_combos.append(combo_id)

	current_save["discovered_combos"] = discovered_combos


func has_discovered_combo(combo_id: String) -> bool:
	return get_discovered_combos().has(combo_id)


func _ensure_current_save() -> void:
	if current_save.is_empty():
		current_save = create_default_save()

	_normalize_current_save()


func _with_defaults(save_data: Dictionary) -> Dictionary:
	var merged := create_default_save()

	for key in save_data.keys():
		merged[key] = _copy_value(save_data[key])

	current_save = merged
	_normalize_current_save()
	return current_save.duplicate(true)


func _merge_save_data(data: Dictionary) -> void:
	for key in data.keys():
		current_save[key] = _copy_value(data[key])


func _normalize_current_save() -> void:
	current_save["version"] = int(current_save.get("version", SAVE_VERSION))
	current_save["current_night"] = max(int(current_save.get("current_night", DEFAULT_START_NIGHT)), DEFAULT_START_NIGHT)
	current_save["money"] = max(int(current_save.get("money", DEFAULT_START_MONEY)), 0)

	if not (current_save.get("inventory", {}) is Dictionary):
		current_save["inventory"] = {}

	if not (current_save.get("unlocked_items", []) is Array):
		current_save["unlocked_items"] = []

	if not (current_save.get("seen_customers", []) is Array):
		current_save["seen_customers"] = []

	if not (current_save.get("customer_story_progress", {}) is Dictionary):
		current_save["customer_story_progress"] = {}

	if not (current_save.get("discovered_combos", []) is Array):
		current_save["discovered_combos"] = []

	current_save["unlocked_items"] = _unique_string_array(current_save["unlocked_items"])
	current_save["seen_customers"] = _unique_string_array(current_save["seen_customers"])
	current_save["discovered_combos"] = _unique_string_array(current_save["discovered_combos"])


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


func _ensure_save_directory(save_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(save_path)
	var save_directory := global_path.get_base_dir()

	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_recursive_absolute(save_directory)


func _report_save_failure(message: String) -> void:
	push_warning(message)
	save_failed.emit(message)
