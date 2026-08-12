extends "res://scripts/ui/BaseScreen.gd"

const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")
const PrimaryButtonScene = preload("res://scenes/ui/components/PrimaryButton.tscn")

var _master_slider: HSlider
var _bgm_slider: HSlider
var _sfx_slider: HSlider
var _text_speed_slider: HSlider
var _text_speed_value_label: Label
var _fullscreen_checkbox: CheckBox
var _screen_shake_checkbox: CheckBox
var _status_label: Label
var _back_button: Button
var _refreshing := false


func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_controls()


func _build_ui() -> void:
	var background: Control = ScreenBackgroundScene.instantiate()
	background.set_background("settings_default")
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 620)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title := _make_label("设置", 34)
	layout.add_child(title)

	_master_slider = _add_slider_row(layout, "Master Volume", 0.0, 1.0, 0.01, _on_master_volume_changed)
	_bgm_slider = _add_slider_row(layout, "BGM Volume", 0.0, 1.0, 0.01, _on_bgm_volume_changed)
	_sfx_slider = _add_slider_row(layout, "SFX Volume", 0.0, 1.0, 0.01, _on_sfx_volume_changed)
	_text_speed_slider = _add_slider_row(layout, "Text Speed", 0.5, 2.0, 0.05, _on_text_speed_changed)
	_text_speed_value_label = _make_label("", 14)
	_text_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout.add_child(_text_speed_value_label)

	_fullscreen_checkbox = CheckBox.new()
	_fullscreen_checkbox.text = "Fullscreen"
	_fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	layout.add_child(_fullscreen_checkbox)

	_screen_shake_checkbox = CheckBox.new()
	_screen_shake_checkbox.text = "Screen Shake"
	_screen_shake_checkbox.toggled.connect(_on_screen_shake_toggled)
	layout.add_child(_screen_shake_checkbox)

	_status_label = _make_label("", 14)
	layout.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)

	var reset_button := _make_button("Reset to Default")
	reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_button)

	_back_button = _make_button("Back")
	_back_button.pressed.connect(_on_back_pressed)
	actions.add_child(_back_button)


func _add_slider_row(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float, callback: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var label := _make_label(label_text, 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider


func _refresh_controls() -> void:
	_refreshing = true
	_master_slider.value = SettingsManager.get_master_volume()
	_bgm_slider.value = SettingsManager.get_bgm_volume()
	_sfx_slider.value = SettingsManager.get_sfx_volume()
	_text_speed_slider.value = SettingsManager.get_text_speed()
	_refresh_text_speed_value()
	_fullscreen_checkbox.button_pressed = SettingsManager.is_fullscreen()
	_screen_shake_checkbox.button_pressed = SettingsManager.is_screen_shake_enabled()
	_refreshing = false


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(text: String) -> Button:
	var button: Button = PrimaryButtonScene.instantiate()
	button.set_text(text)
	button.custom_minimum_size = Vector2(220, 44)
	return button


func _on_master_volume_changed(value: float) -> void:
	if not _refreshing:
		SettingsManager.set_master_volume(value)


func _on_bgm_volume_changed(value: float) -> void:
	if not _refreshing:
		SettingsManager.set_bgm_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	if not _refreshing:
		SettingsManager.set_sfx_volume(value)


func _on_text_speed_changed(value: float) -> void:
	if not _refreshing:
		SettingsManager.set_text_speed(value)
	_refresh_text_speed_value()


func _refresh_text_speed_value() -> void:
	if _text_speed_value_label != null:
		_text_speed_value_label.text = "%.1fx" % SettingsManager.get_text_speed()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if not _refreshing:
		SettingsManager.set_fullscreen(enabled)


func _on_screen_shake_toggled(enabled: bool) -> void:
	if not _refreshing:
		SettingsManager.set_screen_shake(enabled)


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	SettingsManager.apply_all_settings()
	_refresh_controls()
	_status_label.text = "已恢复默认设置。"


func _on_back_pressed() -> void:
	if _back_button.disabled:
		return

	if not SettingsManager.save_settings():
		_status_label.text = "设置保存失败。"
		return

	_back_button.disabled = true
	GameManager.go_to_main_menu()
