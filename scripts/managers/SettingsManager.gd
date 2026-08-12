extends Node

signal settings_changed(settings: Dictionary)

const Config = preload("res://scripts/config/GameConfig.gd")
const CURRENT_SETTINGS_VERSION := 1

var _settings: Dictionary = {}
var _settings_path := Config.SETTINGS_PATH


func _ready() -> void:
	load_settings()
	apply_all_settings()


func load_settings() -> void:
	reset_to_defaults()
	if not FileAccess.file_exists(_settings_path):
		return

	var file := FileAccess.open(_settings_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open settings file. Error code: %s." % FileAccess.get_open_error())
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_warning("Invalid settings JSON at line %d: %s. Defaults were restored." % [json.get_error_line(), json.get_error_message()])
		return

	if not (json.data is Dictionary):
		push_warning("Settings file root must be a Dictionary. Defaults were restored.")
		return

	import_settings(json.data, false)


func save_settings() -> bool:
	_ensure_settings_directory()
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write settings file. Error code: %s." % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(export_settings(), "\t"))
	return true


func reset_to_defaults() -> void:
	_settings = {
		"settings_version": CURRENT_SETTINGS_VERSION,
		"master_volume": Config.DEFAULT_MASTER_VOLUME,
		"bgm_volume": Config.DEFAULT_BGM_VOLUME,
		"sfx_volume": Config.DEFAULT_SFX_VOLUME,
		"text_speed": Config.DEFAULT_TEXT_SPEED,
		"fullscreen": Config.DEFAULT_FULLSCREEN,
		"screen_shake": Config.DEFAULT_SCREEN_SHAKE
	}
	settings_changed.emit(export_settings())


func apply_all_settings() -> void:
	_apply_bus_volume("Master", get_master_volume())
	_apply_bus_volume("BGM", get_bgm_volume())
	_apply_bus_volume("SFX", get_sfx_volume())
	_apply_fullscreen(is_fullscreen())


func set_master_volume(value: float) -> void:
	_settings["master_volume"] = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Master", get_master_volume())
	_emit_settings_changed()


func set_bgm_volume(value: float) -> void:
	_settings["bgm_volume"] = clampf(value, 0.0, 1.0)
	_apply_bus_volume("BGM", get_bgm_volume())
	_emit_settings_changed()


func set_sfx_volume(value: float) -> void:
	_settings["sfx_volume"] = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", get_sfx_volume())
	_emit_settings_changed()


func set_text_speed(value: float) -> void:
	_settings["text_speed"] = clampf(value, Config.MIN_TEXT_SPEED, Config.MAX_TEXT_SPEED)
	_emit_settings_changed()


func set_fullscreen(enabled: bool) -> void:
	_settings["fullscreen"] = enabled
	_apply_fullscreen(enabled)
	_emit_settings_changed()


func set_screen_shake(enabled: bool) -> void:
	_settings["screen_shake"] = enabled
	_emit_settings_changed()


func get_master_volume() -> float:
	return clampf(float(_settings.get("master_volume", Config.DEFAULT_MASTER_VOLUME)), 0.0, 1.0)


func get_bgm_volume() -> float:
	return clampf(float(_settings.get("bgm_volume", Config.DEFAULT_BGM_VOLUME)), 0.0, 1.0)


func get_sfx_volume() -> float:
	return clampf(float(_settings.get("sfx_volume", Config.DEFAULT_SFX_VOLUME)), 0.0, 1.0)


func get_text_speed() -> float:
	return clampf(float(_settings.get("text_speed", Config.DEFAULT_TEXT_SPEED)), Config.MIN_TEXT_SPEED, Config.MAX_TEXT_SPEED)


func is_fullscreen() -> bool:
	return bool(_settings.get("fullscreen", Config.DEFAULT_FULLSCREEN))


func is_screen_shake_enabled() -> bool:
	return bool(_settings.get("screen_shake", Config.DEFAULT_SCREEN_SHAKE))


func export_settings() -> Dictionary:
	return _settings.duplicate(true)


func import_settings(data: Dictionary, apply_settings: bool = true) -> bool:
	var defaults := _default_settings()
	var imported_cleanly := true
	if data.has("settings_version") and _to_int(data.get("settings_version", CURRENT_SETTINGS_VERSION), CURRENT_SETTINGS_VERSION) > CURRENT_SETTINGS_VERSION:
		push_warning("Settings version is newer than supported; known fields will still be loaded.")
		imported_cleanly = false

	_settings = defaults
	_settings["master_volume"] = _number_or_default(data, "master_volume", defaults["master_volume"])
	_settings["bgm_volume"] = _number_or_default(data, "bgm_volume", defaults["bgm_volume"])
	_settings["sfx_volume"] = _number_or_default(data, "sfx_volume", defaults["sfx_volume"])
	_settings["text_speed"] = _number_or_default(data, "text_speed", defaults["text_speed"])
	_settings["fullscreen"] = _bool_or_default(data, "fullscreen", defaults["fullscreen"])
	_settings["screen_shake"] = _bool_or_default(data, "screen_shake", defaults["screen_shake"])
	_settings["master_volume"] = clampf(float(_settings["master_volume"]), 0.0, 1.0)
	_settings["bgm_volume"] = clampf(float(_settings["bgm_volume"]), 0.0, 1.0)
	_settings["sfx_volume"] = clampf(float(_settings["sfx_volume"]), 0.0, 1.0)
	_settings["text_speed"] = clampf(float(_settings["text_speed"]), Config.MIN_TEXT_SPEED, Config.MAX_TEXT_SPEED)
	if apply_settings:
		apply_all_settings()
	_emit_settings_changed()
	return imported_cleanly


func set_settings_path_for_testing(path: String) -> bool:
	if path.is_empty() or not OS.is_debug_build():
		return false
	_settings_path = path
	return true


func restore_default_settings_path_for_testing() -> void:
	if OS.is_debug_build():
		_settings_path = Config.SETTINGS_PATH


func get_settings_path() -> String:
	return _settings_path


func _default_settings() -> Dictionary:
	return {
		"settings_version": CURRENT_SETTINGS_VERSION,
		"master_volume": Config.DEFAULT_MASTER_VOLUME,
		"bgm_volume": Config.DEFAULT_BGM_VOLUME,
		"sfx_volume": Config.DEFAULT_SFX_VOLUME,
		"text_speed": Config.DEFAULT_TEXT_SPEED,
		"fullscreen": Config.DEFAULT_FULLSCREEN,
		"screen_shake": Config.DEFAULT_SCREEN_SHAKE
	}


func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Audio bus is missing: %s." % bus_name)
		return

	var value := clampf(linear_value, 0.0, 1.0)
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		return

	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))


func _apply_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return

	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _number_or_default(data: Dictionary, key: String, default_value: float) -> float:
	var value = data.get(key, default_value)
	if value is int or value is float:
		return float(value)
	return default_value


func _bool_or_default(data: Dictionary, key: String, default_value: bool) -> bool:
	var value = data.get(key, default_value)
	if value is bool:
		return value
	return default_value


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return default_value


func _ensure_settings_directory() -> void:
	var global_path := ProjectSettings.globalize_path(_settings_path)
	var directory := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)


func _emit_settings_changed() -> void:
	settings_changed.emit(export_settings())
