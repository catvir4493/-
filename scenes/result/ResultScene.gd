extends Control

var _title_label: Label
var _summary_label: Label


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.07, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(720, 0)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	center.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	_title_label = _make_label("", 32)
	layout.add_child(_title_label)

	_summary_label = _make_label("", 17)
	_summary_label.custom_minimum_size = Vector2(640, 360)
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(_summary_label)

	var continue_button := _make_button("Continue")
	continue_button.pressed.connect(_on_continue_pressed)
	layout.add_child(continue_button)


func _refresh() -> void:
	var result: Dictionary = GameManager.get_last_service_result()
	if result.is_empty():
		_title_label.text = "顾客已接待"
		_summary_label.text = "评分结果暂时为空。"
		return

	_title_label.text = "%s 已接待" % str(result.get("customer_name", "顾客"))
	_summary_label.text = "\n".join([
		"顾客：%s" % str(result.get("customer_name", "")),
		"台词：%s" % str(result.get("customer_dialogue", "")),
		"已选择商品：%s" % _format_array(result.get("selected_item_names", [])),
		"score：%d" % int(result.get("score", 0)),
		"grade：%s" % str(result.get("grade", "")),
		"matched_tags：%s" % _format_array(result.get("matched_tags", [])),
		"bad_tags：%s" % _format_array(result.get("bad_tags", [])),
		"missing_tags：%s" % _format_array(result.get("missing_tags", [])),
		"income：%d" % int(result.get("income", 0)),
		"反馈：%s" % str(result.get("customer_feedback", ""))
	])


func _format_array(value) -> String:
	if not (value is Array):
		return "无"

	if value.is_empty():
		return "无"

	var result := ""
	for entry in value:
		if not result.is_empty():
			result += "、"

		result += str(entry)

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


func _on_continue_pressed() -> void:
	CustomerSystem.move_to_next_customer()

	if CustomerSystem.has_more_customers():
		GameManager.continue_current_night()
	else:
		GameManager.go_to_restock()
