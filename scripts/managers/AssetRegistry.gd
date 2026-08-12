extends Node

const MANIFEST_PATH := "res://data/presentation_assets.json"
const MANIFEST_VERSION := 1

const CATEGORY_FALLBACKS := {
	"backgrounds": "default_background",
	"portraits": "default_portrait",
	"item_icons": "default_item_icon",
	"ui_icons": "default_ui_icon",
	"logos": "default_logo"
}
const TEXTURE_CATEGORIES := ["backgrounds", "portraits", "item_icons", "ui_icons", "logos"]
const ALL_CATEGORIES := ["backgrounds", "portraits", "item_icons", "ui_icons", "logos", "fonts", "bgm", "sfx"]

var _manifest: Dictionary = {}
var _cache: Dictionary = {}
var _fallback_textures: Dictionary = {}
var _warned_asset_keys: Dictionary = {}
var _manifest_loaded := false


func _ready() -> void:
	_build_internal_fallbacks()
	reload_manifest()


func reload_manifest() -> bool:
	clear_cache()
	_manifest = {}
	_manifest_loaded = false
	if not FileAccess.file_exists(MANIFEST_PATH):
		_warn_once("manifest:missing", "Presentation asset manifest is missing: %s." % MANIFEST_PATH)
		return false

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_warn_once("manifest:open", "Could not open presentation asset manifest.")
		return false

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		_warn_once("manifest:parse", "Presentation asset manifest is invalid; internal fallbacks will be used.")
		return false

	var data: Dictionary = json.data
	if int(data.get("manifest_version", 0)) != MANIFEST_VERSION:
		_warn_once("manifest:version", "Unsupported presentation manifest_version: %s." % data.get("manifest_version", 0))
		return false
	for category in ALL_CATEGORIES:
		if not (data.get(category, {}) is Dictionary):
			_warn_once("manifest:category:%s" % category, "Presentation asset category must be a Dictionary: %s." % category)
			return false

	_manifest = data.duplicate(true)
	_manifest_loaded = true
	return true


func is_manifest_loaded() -> bool:
	return _manifest_loaded


func get_manifest_version() -> int:
	return int(_manifest.get("manifest_version", 0))


func has_asset(category: String, asset_id: String) -> bool:
	var category_data = _manifest.get(category, null)
	return category_data is Dictionary and category_data.has(asset_id)


func get_asset_path(category: String, asset_id: String) -> String:
	var entry := _get_entry(category, asset_id, true)
	if not entry.is_empty():
		return str(entry.get("path", ""))

	var fallback_id := str(CATEGORY_FALLBACKS.get(category, ""))
	if fallback_id.is_empty():
		return ""
	var fallback_entry := _get_entry(category, fallback_id, false)
	return str(fallback_entry.get("path", "")) if not fallback_entry.is_empty() else ""


func get_texture(category: String, asset_id: String) -> Texture2D:
	if not TEXTURE_CATEGORIES.has(category):
		_warn_once("category:texture:%s" % category, "Unknown texture category: %s." % category)
		return _fallback_textures.get("ui_icons") as Texture2D
	var resource := _load_asset(category, asset_id)
	if resource is Texture2D:
		return resource
	return _get_texture_fallback(category)


func get_audio(category: String, asset_id: String) -> AudioStream:
	if category != "bgm" and category != "sfx":
		_warn_once("category:audio:%s" % category, "Unknown audio category: %s." % category)
		return null
	var resource := _load_asset(category, asset_id)
	return resource as AudioStream if resource is AudioStream else null


func get_font(asset_id: String) -> Font:
	var resource := _load_asset("fonts", asset_id)
	return resource as Font if resource is Font else null


func clear_cache() -> void:
	_cache.clear()


func get_cache_size() -> int:
	return _cache.size()


func get_manifest_snapshot() -> Dictionary:
	return _manifest.duplicate(true)


func set_manifest_entry_for_testing(category: String, asset_id: String, path: String) -> bool:
	if not OS.is_debug_build() or not (_manifest.get(category, null) is Dictionary):
		return false
	_manifest[category][asset_id] = {"path": path}
	_cache.erase("%s:%s" % [category, asset_id])
	return true


func _load_asset(category: String, asset_id: String) -> Resource:
	var cache_key := "%s:%s" % [category, asset_id]
	if _cache.has(cache_key):
		return _cache[cache_key] as Resource

	var entry := _get_entry(category, asset_id, true)
	if entry.is_empty():
		return null
	var path := str(entry.get("path", ""))
	if path.is_empty():
		_warn_once("empty:%s" % cache_key, "Presentation asset has no resource yet: %s." % cache_key)
		return null
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		_warn_once("missing:%s" % cache_key, "Presentation asset path does not exist: %s." % path)
		return null

	var resource := ResourceLoader.load(path)
	if not _resource_matches_category(category, resource):
		_warn_once("type:%s" % cache_key, "Presentation asset has the wrong resource type: %s." % cache_key)
		return null
	_cache[cache_key] = resource
	return resource


func _get_entry(category: String, asset_id: String, warn: bool) -> Dictionary:
	var category_data = _manifest.get(category, null)
	if not (category_data is Dictionary):
		if warn:
			_warn_once("category:%s" % category, "Unknown presentation asset category: %s." % category)
		return {}
	var entry = category_data.get(asset_id, null)
	if entry is Dictionary:
		return entry
	if warn:
		_warn_once("id:%s:%s" % [category, asset_id], "Unknown presentation asset id: %s:%s." % [category, asset_id])
	return {}


func _resource_matches_category(category: String, resource: Resource) -> bool:
	if TEXTURE_CATEGORIES.has(category):
		return resource is Texture2D
	if category == "bgm" or category == "sfx":
		return resource is AudioStream
	if category == "fonts":
		return resource is Font
	return false


func _get_texture_fallback(category: String) -> Texture2D:
	var fallback_id := str(CATEGORY_FALLBACKS.get(category, ""))
	if not fallback_id.is_empty():
		var fallback_key := "%s:%s" % [category, fallback_id]
		if _cache.has(fallback_key):
			return _cache[fallback_key] as Texture2D
		var entry := _get_entry(category, fallback_id, false)
		var path := str(entry.get("path", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path)
			if resource is Texture2D:
				_cache[fallback_key] = resource
				return resource
	return _fallback_textures.get(category, _fallback_textures.get("ui_icons")) as Texture2D


func _build_internal_fallbacks() -> void:
	_fallback_textures["backgrounds"] = _make_gradient_texture(Color("101522"), Color("29334d"), 16, 9)
	_fallback_textures["portraits"] = _make_gradient_texture(Color("242a3a"), Color("596681"), 3, 4)
	_fallback_textures["item_icons"] = _make_gradient_texture(Color("272d3d"), Color("68738d"), 1, 1)
	_fallback_textures["ui_icons"] = _make_gradient_texture(Color("242b3c"), Color("8491ac"), 1, 1)
	_fallback_textures["logos"] = _make_gradient_texture(Color("171d2c"), Color("aa915c"), 3, 1)


func _make_gradient_texture(from_color: Color, to_color: Color, width_ratio: int, height_ratio: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([from_color, to_color])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = width_ratio * 64
	texture.height = height_ratio * 64
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture


func _warn_once(key: String, message: String) -> void:
	if _warned_asset_keys.has(key):
		return
	_warned_asset_keys[key] = true
	push_warning(message)
