extends Control

var _continue_button: Button
var _status_label: Label


func _ready() -> void:
	GameManager.go_to_main_menu(false)
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

	var new_game_button := _make_button("开始新游戏")
	new_game_button.pressed.connect(_on_new_game_pressed)
	layout.add_child(new_game_button)

	_continue_button = _make_button("继续游戏")
	_continue_button.pressed.connect(_on_continue_pressed)
	layout.add_child(_continue_button)

	var quit_button := _make_button("退出")
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


func _refresh_continue_button() -> void:
	var can_continue := SaveManager.has_save()
	_continue_button.disabled = not can_continue
	if can_continue:
		_status_label.text = ""
	else:
		_status_label.text = "暂无存档。"


func _on_new_game_pressed() -> void:
	GameManager.start_new_game()


func _on_continue_pressed() -> void:
	if not GameManager.load_game():
		_status_label.text = "没有找到可继续的存档。"
		_refresh_continue_button()


func _on_quit_pressed() -> void:
	get_tree().quit()
