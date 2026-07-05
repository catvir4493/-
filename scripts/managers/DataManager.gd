extends Node

signal data_loaded
signal data_load_failed(data_type: String, path: String, message: String)

const ITEMS_PATH := "res://data/items.json"
const CUSTOMERS_PATH := "res://data/customers.json"
const COMBOS_PATH := "res://data/combos.json"
const CUSTOMER_PROFILES_PATH := "res://data/customer_profiles.json"
const NIGHTS_PATH := "res://data/nights.json"

var items = {}
var customers = {}
var combos = {}
var customer_profiles = {}
var nights = {}

var _loaded := false


func _ready() -> void:
	load_all_data()


func load_all_data() -> bool:
	var all_loaded := true

	var loaded_items = _load_dataset("items", ITEMS_PATH, "items")
	if loaded_items == null:
		items = {}
		all_loaded = false
	else:
		items = loaded_items

	var loaded_customers = _load_dataset("customers", CUSTOMERS_PATH, "customers")
	if loaded_customers == null:
		customers = {}
		all_loaded = false
	else:
		customers = loaded_customers

	var loaded_combos = _load_dataset("combos", COMBOS_PATH, "combos")
	if loaded_combos == null:
		combos = {}
		all_loaded = false
	else:
		combos = loaded_combos

	var loaded_customer_profiles = _load_dataset("customer_profiles", CUSTOMER_PROFILES_PATH, "customer_profiles")
	if loaded_customer_profiles == null:
		customer_profiles = {}
		all_loaded = false
	else:
		customer_profiles = loaded_customer_profiles

	var loaded_nights = _load_dataset("nights", NIGHTS_PATH, "nights")
	if loaded_nights == null:
		nights = {}
		all_loaded = false
	else:
		nights = loaded_nights

	_loaded = all_loaded
	if all_loaded:
		data_loaded.emit()

	return all_loaded


func reload_data() -> bool:
	return load_all_data()


func is_loaded() -> bool:
	return _loaded


func get_items() -> Array:
	return _collection_to_array(items)


func get_all_items() -> Array:
	return get_items()


func get_customers() -> Array:
	return _collection_to_array(customers)


func get_all_customers() -> Array:
	return get_customers()


func get_combos() -> Array:
	return _collection_to_array(combos)


func get_all_combos() -> Array:
	return get_combos()


func get_customer_profiles() -> Array:
	return _collection_to_array(customer_profiles)


func get_all_customer_profiles() -> Array:
	return get_customer_profiles()


func get_nights() -> Array:
	return _collection_to_array(nights)


func get_item(item_id: String) -> Dictionary:
	return _get_record(items, item_id)


func get_item_by_id(item_id: String) -> Dictionary:
	return get_item(item_id)


func get_customer(customer_id: String) -> Dictionary:
	return _get_record(customers, customer_id)


func get_customer_by_id(customer_id: String) -> Dictionary:
	return get_customer(customer_id)


func get_combo(combo_id: String) -> Dictionary:
	return _get_record(combos, combo_id)


func get_combo_by_id(combo_id: String) -> Dictionary:
	return get_combo(combo_id)


func get_customer_profile_by_id(profile_id: String) -> Dictionary:
	return _get_record(customer_profiles, profile_id)


func get_customer_profile_by_story_id(story_id: String) -> Dictionary:
	var story_key := str(story_id)
	if story_key.is_empty():
		return {}

	for profile in get_customer_profiles():
		if profile is Dictionary and str(profile.get("story_id", "")) == story_key:
			return profile.duplicate(true)

	return {}


func get_night(night_id: int) -> Dictionary:
	return _get_record(nights, night_id)


func find_items_by_tag(tag: String) -> Array:
	var matches := []

	for item in get_items():
		if not item.has("tags"):
			continue

		var tags = item["tags"]
		if tags is Array and tags.has(tag):
			matches.append(item)

	return matches


func _load_dataset(data_type: String, path: String, root_key: String):
	var raw_data = _load_json(path, data_type)
	if raw_data == null:
		return null

	if raw_data is Dictionary and raw_data.has(root_key):
		return raw_data[root_key]

	if raw_data is Array:
		return raw_data

	_report_load_failure(data_type, path, "Expected a JSON Array or a Dictionary with '%s'." % root_key)
	return null


func _load_json(path: String, data_type: String):
	if not FileAccess.file_exists(path):
		_report_load_failure(data_type, path, "File does not exist.")
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report_load_failure(data_type, path, "Could not open file. Error code: %s." % FileAccess.get_open_error())
		return null

	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		var message := "Invalid JSON at line %d: %s." % [json.get_error_line(), json.get_error_message()]
		_report_load_failure(data_type, path, message)
		return null

	return json.data


func _collection_to_array(collection) -> Array:
	if collection is Array:
		return collection.duplicate(true)

	if collection is Dictionary:
		return collection.values().duplicate(true)

	return []


func _get_record(collection, record_id) -> Dictionary:
	var record_key := str(record_id)

	if collection is Dictionary:
		if collection.has(record_id):
			return _as_dictionary(collection[record_id])

		if collection.has(record_key):
			return _as_dictionary(collection[record_key])

		for value in collection.values():
			var record := _as_dictionary(value)
			if _record_matches_id(record, record_key):
				return record

	if collection is Array:
		for value in collection:
			var record := _as_dictionary(value)
			if _record_matches_id(record, record_key):
				return record

	return {}


func _record_matches_id(record: Dictionary, record_key: String) -> bool:
	if record.is_empty():
		return false

	return (
		str(record.get("id", "")) == record_key
		or str(record.get("combo_id", "")) == record_key
		or str(record.get("story_id", "")) == record_key
		or str(record.get("night", "")) == record_key
		or str(record.get("number", "")) == record_key
	)


func _as_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)

	return {}


func _report_load_failure(data_type: String, path: String, message: String) -> void:
	push_error("%s data failed to load from %s: %s" % [data_type, path, message])
	data_load_failed.emit(data_type, path, message)
