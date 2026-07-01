extends Control

const MAX_SELECTED_ITEMS := 3

var _night_label: Label
var _money_label: Label
var _customer_progress_label: Label
var _customer_name_label: Label
var _customer_dialogue_label: Label
var _items_grid: GridContainer
var _selected_label: Label
var _feedback_label: Label
var _clear_button: Button

var _selected_item_ids: Array[String] = []


func _ready() -> void:
	CustomerSystem.ensure_night_queue(GameManager.current_night)
	_build_ui()
	_connect_signals()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.12)
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

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 24)
	layout.add_child(top_bar)

	_night_label = _make_label("", 20)
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_night_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_night_label)

	_money_label = _make_label("", 20)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_money_label)

	var main_area := HBoxContainer.new()
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 16)
	layout.add_child(main_area)

	main_area.add_child(_build_customer_panel())
	main_area.add_child(_build_shelf_panel())
	layout.add_child(_build_selection_panel())


func _build_customer_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	_customer_progress_label = _make_label("", 16)
	layout.add_child(_customer_progress_label)

	_customer_name_label = _make_label("", 28)
	layout.add_child(_customer_name_label)

	_customer_dialogue_label = _make_label("", 18)
	_customer_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_customer_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_customer_dialogue_label)

	return panel


func _build_shelf_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := _make_label("商品货架", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_items_grid = GridContainer.new()
	_items_grid.columns = 2
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_grid.add_theme_constant_override("h_separation", 10)
	_items_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_items_grid)

	return panel


func _build_selection_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 132)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	_selected_label = _make_label("", 17)
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(_selected_label)

	_feedback_label = _make_label("", 15)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(_feedback_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	_clear_button = _make_button("清空选择")
	_clear_button.pressed.connect(_on_clear_pressed)
	actions.add_child(_clear_button)

	var confirm_button := _make_button("Confirm")
	confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(confirm_button)

	var menu_button := _make_button("返回主菜单")
	menu_button.pressed.connect(_on_main_menu_pressed)
	actions.add_child(menu_button)

	return panel


func _connect_signals() -> void:
	if not GameManager.night_changed.is_connected(_on_night_changed):
		GameManager.night_changed.connect(_on_night_changed)

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)

	if not InventorySystem.inventory_changed.is_connected(_on_inventory_changed):
		InventorySystem.inventory_changed.connect(_on_inventory_changed)

	if not InventorySystem.inventory_reset.is_connected(_on_inventory_reset):
		InventorySystem.inventory_reset.connect(_on_inventory_reset)

	if not CustomerSystem.current_customer_changed.is_connected(_on_current_customer_changed):
		CustomerSystem.current_customer_changed.connect(_on_current_customer_changed)


func _refresh() -> void:
	_refresh_header()
	_refresh_customer()
	_refresh_item_cards()
	_refresh_selection()


func _refresh_header() -> void:
	_night_label.text = "第 %d 夜" % GameManager.current_night
	_money_label.text = "资金：%d" % GameManager.money


func _refresh_customer() -> void:
	var customer: Dictionary = CustomerSystem.get_current_customer()
	if customer.is_empty():
		_customer_progress_label.text = "今晚已无顾客"
		_customer_name_label.text = "打烊前的安静"
		_customer_dialogue_label.text = "今晚的队列已经结束。"
		return

	_customer_progress_label.text = "顾客 %d / %d" % [
		CustomerSystem.get_current_customer_number(),
		CustomerSystem.get_customer_count_for_current_night()
	]
	_customer_name_label.text = str(customer.get("customer_name", "陌生顾客"))
	_customer_dialogue_label.text = str(customer.get("dialogue", "……"))


func _refresh_item_cards() -> void:
	for child in _items_grid.get_children():
		child.queue_free()

	var visible_items: Array = _get_unlocked_items()
	if visible_items.is_empty():
		var empty_label := _make_label("货架暂时是空的。", 18)
		_items_grid.add_child(empty_label)
		return

	for item in visible_items:
		if not (item is Dictionary):
			continue

		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty():
			continue

		var stock: int = InventorySystem.get_stock(item_id)
		var button := _make_item_button(item, stock)
		var captured_id: String = item_id
		button.pressed.connect(func() -> void:
			_on_item_pressed(captured_id)
		)
		_items_grid.add_child(button)


func _refresh_selection() -> void:
	_clear_button.disabled = _selected_item_ids.is_empty()

	if _selected_item_ids.is_empty():
		_selected_label.text = "已选择：无"
		return

	var names: Array[String] = []
	for item_id in _selected_item_ids:
		var item: Dictionary = DataManager.get_item_by_id(item_id)
		names.append(str(item.get("name", item_id)))

	_selected_label.text = "已选择：%s" % _join_strings(names, "、")


func _make_item_button(item: Dictionary, stock: int) -> Button:
	var item_id: String = str(item.get("id", ""))
	var item_name: String = str(item.get("name", item_id))
	var description: String = str(item.get("description", ""))
	var max_stock: int = int(item.get("max_stock", 0))
	var is_selected: bool = _selected_item_ids.has(item_id)

	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = is_selected
	button.disabled = stock <= 0 and not is_selected
	button.text = "%s\n库存：%d/%d\n%s" % [item_name, stock, max_stock, description]
	button.custom_minimum_size = Vector2(290, 112)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button


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
	button.custom_minimum_size = Vector2(150, 40)
	return button


func _get_unlocked_items() -> Array:
	var unlocked_items: Array = []

	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		var unlock_day: int = int(item.get("unlock_day", 1))
		if unlock_day <= GameManager.current_night:
			unlocked_items.append(item)

	return unlocked_items


func _has_stock_for_item_ids(item_ids: Array[String]) -> bool:
	var requested_counts := {}

	for item_id in item_ids:
		requested_counts[item_id] = int(requested_counts.get(item_id, 0)) + 1

	for item_id in requested_counts.keys():
		if not InventorySystem.has_stock(str(item_id), int(requested_counts[item_id])):
			return false

	return true


func _join_strings(values: Array, separator: String) -> String:
	var result := ""

	for value in values:
		if not result.is_empty():
			result += separator

		result += str(value)

	return result


func _set_feedback(message: String) -> void:
	_feedback_label.text = message


func _on_item_pressed(item_id: String) -> void:
	if _selected_item_ids.has(item_id):
		_selected_item_ids.erase(item_id)
		_set_feedback("")
		_refresh_item_cards()
		_refresh_selection()
		return

	if _selected_item_ids.size() >= MAX_SELECTED_ITEMS:
		_set_feedback("最多只能选择 %d 件商品。" % MAX_SELECTED_ITEMS)
		_refresh_item_cards()
		return

	if not InventorySystem.has_stock(item_id):
		_set_feedback("这个商品已经没有库存。")
		_refresh_item_cards()
		return

	_selected_item_ids.append(item_id)
	_set_feedback("")
	_refresh_item_cards()
	_refresh_selection()


func _on_confirm_pressed() -> void:
	if _selected_item_ids.is_empty():
		_set_feedback("请至少选择 1 件商品。")
		return

	var current_customer: Dictionary = CustomerSystem.get_current_customer()
	if current_customer.is_empty():
		_set_feedback("今晚已经没有顾客。")
		return

	var selected_ids: Array[String] = _selected_item_ids.duplicate()
	var service_result: Dictionary = ScoreSystem.calculate_score(current_customer, selected_ids)

	if not _has_stock_for_item_ids(selected_ids):
		_set_feedback("库存不足，请重新选择商品。")
		_refresh_item_cards()
		_refresh_selection()
		return

	print("current_customer_id: ", str(current_customer.get("id", "")))
	print("current_customer_required_tags: ", JSON.stringify(current_customer.get("required_tags", [])))
	print("current_customer_avoid_tags: ", JSON.stringify(current_customer.get("avoid_tags", [])))
	print("selected_item_ids: ", JSON.stringify(selected_ids))
	print("score_result: ", JSON.stringify(service_result))

	GameManager.set_last_service_result(service_result)
	GameManager.add_money(int(service_result.get("income", 0)))
	InventorySystem.consume_items(selected_ids)
	GameManager.show_result(service_result)


func _on_clear_pressed() -> void:
	_selected_item_ids.clear()
	_set_feedback("")
	_refresh_item_cards()
	_refresh_selection()


func _on_main_menu_pressed() -> void:
	GameManager.go_to_main_menu()


func _on_night_changed(_current_night: int) -> void:
	_refresh()


func _on_money_changed(_money: int) -> void:
	_refresh_header()


func _on_inventory_changed(_item_id: String, _stock: int) -> void:
	_refresh_item_cards()
	_refresh_selection()


func _on_inventory_reset() -> void:
	_selected_item_ids.clear()
	_refresh()


func _on_current_customer_changed(_customer: Dictionary, _customer_index: int) -> void:
	_selected_item_ids.clear()
	_set_feedback("")
	_refresh_customer()
	_refresh_item_cards()
	_refresh_selection()
