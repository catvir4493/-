extends Control

var _night_label: Label
var _money_label: Label


func _ready() -> void:
	_build_ui()
	_connect_game_manager()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.08, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(620, 0)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	center.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title := _make_label("进货清单", 32)
	layout.add_child(title)

	_night_label = _make_label("", 20)
	layout.add_child(_night_label)

	_money_label = _make_label("", 20)
	layout.add_child(_money_label)

	var note := _make_label("进货单暂时空白，货架保持原样。\n下一阶段会在这里接入商品库存和购买按钮。", 18)
	note.custom_minimum_size = Vector2(540, 160)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(note)

	var next_button := _make_button("开始下一夜")
	next_button.pressed.connect(_on_next_night_pressed)
	layout.add_child(next_button)


func _connect_game_manager() -> void:
	if not GameManager.night_changed.is_connected(_on_night_changed):
		GameManager.night_changed.connect(_on_night_changed)

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)


func _refresh() -> void:
	_night_label.text = "刚结束：第 %d 夜" % GameManager.current_night
	_money_label.text = "当前资金：%d" % GameManager.money


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


func _on_next_night_pressed() -> void:
	GameManager.finish_restock()


func _on_night_changed(_current_night: int) -> void:
	_refresh()


func _on_money_changed(_money: int) -> void:
	_refresh()
