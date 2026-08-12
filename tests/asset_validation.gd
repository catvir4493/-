extends SceneTree

const MANIFEST_PATH := "res://data/presentation_assets.json"
const CATEGORIES := ["backgrounds", "portraits", "item_icons", "ui_icons", "logos", "fonts", "bgm", "sfx"]
const TEXTURES := ["backgrounds", "portraits", "item_icons", "ui_icons", "logos"]
const ITEM_IDS := ["coffee", "milk", "mint_candy", "black_umbrella", "red_lighter", "bandage", "old_photo", "ticket", "sleep_mask", "tissue", "dark_chocolate", "disposable_camera", "blank_postcard", "battery", "flashlight", "cheap_perfume", "expired_magazine", "lucky_sticker", "rice_ball", "coin"]
const BACKGROUND_IDS := ["default_background", "main_menu", "shop_default", "result_default", "night_result_default", "restock_default", "archive_default", "settings_default", "shop_night_01", "shop_night_02", "shop_night_03", "shop_night_04", "shop_night_05", "shop_special"]
const UI_ICON_IDS := ["default_ui_icon", "lock", "check", "back", "coin", "warning", "combo", "archive", "settings"]

var failures: Array[String] = []
var DataManager


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	DataManager = root.get_node_or_null("/root/DataManager")
	_assert(DataManager != null, "DataManager autoload must exist.")
	var manifest := _load_json(MANIFEST_PATH)
	if manifest.is_empty():
		_finish()
		return
	_assert_equal(manifest.get("manifest_version", 0), 1, "manifest_version must be 1.")
	for category in CATEGORIES:
		_assert(manifest.get(category, null) is Dictionary, "%s must be a Dictionary." % category)
		_validate_entries(category, manifest.get(category, {}))
	for item_id in ITEM_IDS:
		_assert(manifest["item_icons"].has(item_id), "Missing item icon id: %s." % item_id)
	for asset_id in BACKGROUND_IDS:
		_assert(manifest["backgrounds"].has(asset_id), "Missing background id: %s." % asset_id)
	for asset_id in UI_ICON_IDS:
		_assert(manifest["ui_icons"].has(asset_id), "Missing UI icon id: %s." % asset_id)
	for profile in DataManager.get_all_customer_profiles():
		var portrait_id := str(profile.get("portrait_id", ""))
		_assert(not portrait_id.is_empty() and manifest["portraits"].has(portrait_id), "Unresolved profile portrait_id: %s." % portrait_id)
	_finish()


func _validate_entries(category: String, entries: Dictionary) -> void:
	var seen := {}
	for asset_id in entries:
		_assert(not seen.has(asset_id), "Duplicate asset id in %s: %s." % [category, asset_id])
		seen[asset_id] = true
		var entry = entries[asset_id]
		_assert(entry is Dictionary, "%s:%s entry must be a Dictionary." % [category, asset_id])
		if not (entry is Dictionary):
			continue
		var path = entry.get("path", null)
		_assert(path is String, "%s:%s path must be a String." % [category, asset_id])
		if not (path is String) or path.is_empty():
			continue
		_assert(path.begins_with("res://"), "%s:%s path must use res://." % [category, asset_id])
		_assert(ResourceLoader.exists(path), "%s:%s resource does not exist: %s." % [category, asset_id, path])
		if ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path)
			if TEXTURES.has(category):
				_assert(resource is Texture2D, "%s:%s must resolve to Texture2D." % [category, asset_id])
			elif category == "bgm" or category == "sfx":
				_assert(resource is AudioStream, "%s:%s must resolve to AudioStream." % [category, asset_id])
			elif category == "fonts":
				_assert(resource is Font, "fonts:%s must resolve to Font." % asset_id)


func _load_json(path: String) -> Dictionary:
	_assert(FileAccess.file_exists(path), "Manifest must exist.")
	var file := FileAccess.open(path, FileAccess.READ)
	_assert(file != null, "Manifest must be readable.")
	if file == null:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	_assert(error == OK, "Manifest JSON must parse: %s." % json.get_error_message())
	_assert(json.data is Dictionary, "Manifest root must be a Dictionary.")
	return json.data if json.data is Dictionary else {}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected %s, got %s." % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("Presentation asset validation passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("Presentation asset validation failed with %d issue(s)." % failures.size())
	quit(1)
