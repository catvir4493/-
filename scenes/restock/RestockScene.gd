extends Control

var _night_label: Label
var _money_label: Label
var _feedback_label: Label
var _item_list: VBoxContainer
var _next_night_button: Button

var _buy_buttons_by_item_id: Dictionary = {}
var _stock_labels_by_item_id: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_connect_signals()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.08, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	layout.add_child(header)

	_night_label = _make_label("", 20)
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_night_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_night_label)

	_money_label = _make_label("", 20)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_money_label)

	var title := _make_label("营业结束 · 补充库存", 32)
	layout.add_child(title)

	_feedback_label = _make_label("", 16)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(_feedback_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_item_list)

	_next_night_button = _make_button("Start Next Night")
	_next_night_button.pressed.connect(_on_next_night_pressed)
	layout.add_child(_next_night_button)


func _connect_signals() -> void:
	if not GameManager.night_changed.is_connected(_on_night_changed):
		GameManager.night_changed.connect(_on_night_changed)

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)

	if not InventorySystem.inventory_changed.is_connected(_on_inventory_changed):
		InventorySystem.inventory_changed.connect(_on_inventory_changed)


func _refresh() -> void:
	_refresh_header()
	_refresh_item_list()


func _refresh_header() -> void:
	_night_label.text = "刚结束：第 %d 夜" % GameManager.current_night
	_money_label.text = "当前资金：%d" % GameManager.money


func _refresh_item_list() -> void:
	_buy_buttons_by_item_id.clear()
	_stock_labels_by_item_id.clear()

	for child in _item_list.get_children():
		child.queue_free()

	var items := _get_unlocked_items()
	if items.is_empty():
		_item_list.add_child(_make_label("当前没有已解锁商品。", 18))
		return

	for item in items:
		if item is Dictionary:
			_item_list.add_child(_make_item_row(item))


func _refresh_buy_states() -> void:
	for item_id in _buy_buttons_by_item_id.keys():
		var button: Button = _buy_buttons_by_item_id[item_id]
		var item: Dictionary = DataManager.get_item_by_id(str(item_id))
		var stock_label: Label = _stock_labels_by_item_id[item_id]
		var stock := InventorySystem.get_stock(str(item_id))
		var max_stock := InventorySystem.get_max_stock(str(item_id))
		var buy_price := int(item.get("buy_price", 0))

		stock_label.text = "库存：%d / %d" % [stock, max_stock]
		button.disabled = _should_disable_buy_button(str(item_id), buy_price)


func _make_item_row(item: Dictionary) -> Control:
	var item_id := str(item.get("id", ""))
	var item_name := str(item.get("name", item_id))
	var description := str(item.get("description", ""))
	var buy_price := int(item.get("buy_price", 0))
	var stock := InventorySystem.get_stock(item_id)
	var max_stock := InventorySystem.get_max_stock(item_id)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 6)
	row.add_child(text_column)

	var name_label := _make_label(item_name, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_column.add_child(name_label)

	var description_label := _make_label(description, 15)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_column.add_child(description_label)

	var stock_label := _make_label("库存：%d / %d" % [stock, max_stock], 15)
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_column.add_child(stock_label)
	_stock_labels_by_item_id[item_id] = stock_label

	var price_label := _make_label("进货价：%d" % buy_price, 15)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_column.add_child(price_label)

	var buy_button := _make_button("Buy")
	buy_button.disabled = _should_disable_buy_button(item_id, buy_price)
	buy_button.pressed.connect(func() -> void:
		_on_buy_pressed(item_id)
	)
	row.add_child(buy_button)
	_buy_buttons_by_item_id[item_id] = buy_button

	return panel


func _get_unlocked_items() -> Array:
	var unlocked_items: Array = []

	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		if int(item.get("unlock_day", 1)) <= GameManager.current_night:
			unlocked_items.append(item)

	return unlocked_items


func _should_disable_buy_button(item_id: String, buy_price: int) -> bool:
	return (
		InventorySystem.is_stock_full(item_id)
		or buy_price > GameManager.money
		or not InventorySystem.can_buy_item(item_id)
	)


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
	button.custom_minimum_size = Vector2(180, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _on_buy_pressed(item_id: String) -> void:
	var result: Dictionary = InventorySystem.buy_item(item_id, 1)
	if bool(result.get("success", false)):
		_feedback_label.text = "已补充：%s" % _get_item_name(item_id)
	else:
		_feedback_label.text = _get_failure_message(str(result.get("reason", "")))

	_refresh_header()
	_refresh_buy_states()


func _on_next_night_pressed() -> void:
	if _next_night_button.disabled:
		return

	_next_night_button.disabled = true
	GameManager.start_next_night()


func _on_night_changed(_current_night: int) -> void:
	_refresh()


func _on_money_changed(_money: int) -> void:
	_refresh_header()
	_refresh_buy_states()


func _on_inventory_changed(_item_id: String, _stock: int) -> void:
	_refresh_buy_states()


func _get_item_name(item_id: String) -> String:
	var item: Dictionary = DataManager.get_item_by_id(item_id)
	return str(item.get("name", item_id))


func _get_failure_message(reason: String) -> String:
	match reason:
		"not_enough_money":
			return "金钱不足。"
		"stock_full", "exceeds_max_stock":
			return "该商品库存已满。"
		"item_locked":
			return "该商品尚未解锁。"
		"item_not_found":
			return "无法找到该商品数据。"
		"invalid_quantity":
			return "购买数量无效。"

	return "购买失败。"
