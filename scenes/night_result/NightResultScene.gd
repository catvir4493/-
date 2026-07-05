extends Control

var _title_label: Label
var _summary_label: Label
var _restock_button: Button


func _ready() -> void:
	_build_ui()
	_refresh()
	if not SaveManager.save_game("night_result"):
		push_warning("Failed to save night_result checkpoint.")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	_title_label = _make_label("", 32)
	layout.add_child(_title_label)

	_summary_label = _make_label("", 18)
	_summary_label.custom_minimum_size = Vector2(680, 340)
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(_summary_label)

	_restock_button = _make_button("进入进货")
	_restock_button.pressed.connect(_on_restock_pressed)
	layout.add_child(_restock_button)


func _refresh() -> void:
	var summary: Dictionary = NightStatsSystem.get_night_summary()
	_title_label.text = "第 %d 夜结束" % int(summary.get("night_number", GameManager.current_night))
	_summary_label.text = "\n".join([
		"接待顾客数量：%d" % int(summary.get("customers_served", 0)),
		"Perfect 次数：%d" % int(summary.get("perfect_count", 0)),
		"Good 次数：%d" % int(summary.get("good_count", 0)),
		"Normal 次数：%d" % int(summary.get("normal_count", 0)),
		"Fail 次数：%d" % int(summary.get("fail_count", 0)),
		"本夜总收入：%d" % int(summary.get("total_income", 0)),
		"平均分：%.1f" % float(summary.get("average_score", 0.0)),
		"店铺评级：%s" % str(summary.get("shop_rating", "")),
		"店铺评级文本：%s" % str(summary.get("shop_rating_text", "")),
		"触发组合总次数：%d" % int(summary.get("triggered_combo_count", 0)),
		"本夜组合：%s" % _format_combo_names(summary.get("triggered_combo_names", []))
	])


func _format_combo_names(value) -> String:
	if not (value is Array):
		return "本夜未触发特殊组合。"

	if value.is_empty():
		return "本夜未触发特殊组合。"

	var result := ""
	for combo_name in value:
		if not result.is_empty():
			result += "、"

		result += str(combo_name)

	return result


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _on_restock_pressed() -> void:
	if _restock_button.disabled:
		return

	_restock_button.disabled = true
	if not SaveManager.save_game("restock"):
		push_warning("Failed to save restock checkpoint.")

	GameManager.go_to_restock(true, false)
