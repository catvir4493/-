extends "res://scripts/ui/BaseScreen.gd"

const Config = preload("res://scripts/config/GameConfig.gd")
const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")
const PrimaryButtonScene = preload("res://scenes/ui/components/PrimaryButton.tscn")

var _title_label: Label
var _logo_rect: TextureRect
var _new_game_button: Button
var _continue_button: Button
var _archive_button: Button
var _settings_button: Button
var _status_label: Label
var _is_transitioning := false


func _ready() -> void:
	super._ready()
	GameManager.go_to_main_menu(false)
	_load_archive_progress_if_needed()
	_build_ui()
	if not GameManager.scene_change_failed.is_connected(_on_scene_change_failed):
		GameManager.scene_change_failed.connect(_on_scene_change_failed)
	_refresh_continue_button()


func _build_ui() -> void:
	var background: Control = ScreenBackgroundScene.instantiate()
	background.set_background("main_menu")
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(560, 0)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	center.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "MainLogo"
	_logo_rect.texture = AssetRegistry.get_texture("logos", "main")
	_logo_rect.custom_minimum_size = Vector2(420, 140)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_logo_rect)

	_title_label = _make_label(Config.GAME_TITLE, 36)
	layout.add_child(_title_label)

	var subtitle := _make_label("午夜开门，天亮前打烊。", 18)
	layout.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 12)
	layout.add_child(spacer)

	_new_game_button = _make_button("New Game")
	_new_game_button.pressed.connect(_on_new_game_pressed)
	layout.add_child(_new_game_button)

	_continue_button = _make_button("Continue")
	_continue_button.pressed.connect(_on_continue_pressed)
	layout.add_child(_continue_button)

	_archive_button = _make_button("Customer Archive")
	_archive_button.pressed.connect(_on_archive_pressed)
	layout.add_child(_archive_button)

	_settings_button = _make_button("Settings")
	_settings_button.pressed.connect(_on_settings_pressed)
	layout.add_child(_settings_button)

	var quit_button := _make_button("Quit")
	quit_button.pressed.connect(_on_quit_pressed)
	layout.add_child(quit_button)

	_status_label = _make_label("", 14)
	_status_label.custom_minimum_size = Vector2(480, 28)
	layout.add_child(_status_label)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(text: String) -> Button:
	var button: Button = PrimaryButtonScene.instantiate()
	button.set_text(text)
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _load_archive_progress_if_needed() -> void:
	if not CustomerProgressSystem.get_seen_customers().is_empty():
		return

	if SaveManager.has_valid_save():
		SaveManager.load_customer_progress_from_save()


func _refresh_continue_button() -> void:
	var can_continue := SaveManager.has_valid_save()
	_continue_button.disabled = not can_continue
	if can_continue:
		_status_label.text = ""
	else:
		_status_label.text = "暂无可继续的存档。"


func _on_new_game_pressed() -> void:
	if _new_game_button.disabled or _is_transitioning:
		return

	_begin_transition()
	GameManager.start_new_game()


func _on_continue_pressed() -> void:
	if _continue_button.disabled or _is_transitioning:
		return

	_begin_transition()
	if not SaveManager.continue_game():
		_is_transitioning = false
		_status_label.text = "存档读取失败。"
		_new_game_button.disabled = false
		_archive_button.disabled = false
		_settings_button.disabled = false
		_continue_button.disabled = not SaveManager.has_valid_save()


func _on_archive_pressed() -> void:
	if _archive_button.disabled or _is_transitioning:
		return

	_begin_transition()
	GameManager.go_to_archive()


func _on_settings_pressed() -> void:
	if _settings_button.disabled or _is_transitioning:
		return

	_begin_transition()
	GameManager.go_to_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _begin_transition() -> void:
	_is_transitioning = true
	_new_game_button.disabled = true
	_continue_button.disabled = true
	_archive_button.disabled = true
	_settings_button.disabled = true
	_status_label.text = ""


func _on_scene_change_failed(_scene_path: String, message: String) -> void:
	if not _is_transitioning:
		return

	_is_transitioning = false
	_new_game_button.disabled = false
	_archive_button.disabled = false
	_settings_button.disabled = false
	_continue_button.disabled = not SaveManager.has_valid_save()
	_status_label.text = "场景切换失败：%s" % message


func has_settings_entry() -> bool:
	return _settings_button != null


func has_text_title_fallback() -> bool:
	return _title_label != null and not _title_label.text.is_empty()
