extends Node

const MAIN_THEME_PATH := "res://assets/ui/themes/MidnightTheme.tres"

var _main_theme: Theme


func _ready() -> void:
	reload_theme()


func get_main_theme() -> Theme:
	if _main_theme == null:
		reload_theme()
	return _main_theme


func apply_theme(control: Control) -> void:
	if control == null:
		return
	control.theme = get_main_theme()


func reload_theme() -> void:
	var loaded := ResourceLoader.load(MAIN_THEME_PATH) as Theme
	if loaded == null:
		push_warning("Could not load the main UI theme: %s." % MAIN_THEME_PATH)
		_main_theme = Theme.new()
	else:
		_main_theme = loaded.duplicate(true) as Theme
	apply_font_assets(_main_theme)


func apply_font_assets(target_theme: Theme = null) -> bool:
	if AssetRegistry.get_asset_path("fonts", "font_ui_default").is_empty():
		return false
	var font := AssetRegistry.get_font("font_ui_default")
	if font == null:
		return false
	var theme_to_update := target_theme if target_theme != null else _main_theme
	if theme_to_update != null:
		theme_to_update.default_font = font
	return true
