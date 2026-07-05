extends Control

var _new_game_button: Button
var _continue_button: Button
var _archive_button: Button
var _status_label: Label


func _ready() -> void:
	GameManager.go_to_main_menu(false)
	_load_archive_progress_if_needed()
	_build_ui()
	_refresh_continue_button()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	var title := _make_label("深夜愿望便利店", 36)
	layout.add_child(title)

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
	var button := Button.new()
	button.text = text
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
	if _new_game_button.disabled:
		return

	_new_game_button.disabled = true
	_continue_button.disabled = true
	_archive_button.disabled = true
	GameManager.start_new_game()


func _on_continue_pressed() -> void:
	if _continue_button.disabled:
		return

	_continue_button.disabled = true
	if not SaveManager.continue_game():
		_status_label.text = "存档读取失败。"
		_new_game_button.disabled = false
		_archive_button.disabled = false
		_refresh_continue_button()


func _on_archive_pressed() -> void:
	if _archive_button.disabled:
		return

	_archive_button.disabled = true
	GameManager.go_to_archive()


func _on_quit_pressed() -> void:
	get_tree().quit()
