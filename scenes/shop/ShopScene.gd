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
var _confirm_button: Button

var selected_items: Array[String] = []
var _is_submitting := false
var _scene_transitioning := false


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

	_confirm_button = _make_button("Confirm")
	_confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(_confirm_button)

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

	if not GameManager.scene_change_started.is_connected(_on_scene_change_started):
		GameManager.scene_change_started.connect(_on_scene_change_started)


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

	var visible_items: Array = DataManager.get_all_items()
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
	_clear_button.disabled = selected_items.is_empty() or _is_submitting or _scene_transitioning
	_confirm_button.disabled = not can_confirm_selection()

	if selected_items.is_empty():
		_selected_label.text = "已选择：0 / %d" % MAX_SELECTED_ITEMS
		return

	var names: Array[String] = []
	for item_id in selected_items:
		var item: Dictionary = DataManager.get_item_by_id(item_id)
		names.append(str(item.get("name", item_id)))

	_selected_label.text = "已选择：%d / %d\n%s" % [
		selected_items.size(),
		MAX_SELECTED_ITEMS,
		_join_strings(names, "、")
	]


func _make_item_button(item: Dictionary, stock: int) -> Button:
	var item_id: String = str(item.get("id", ""))
	var item_name: String = str(item.get("name", item_id))
	var description: String = str(item.get("description", ""))
	var max_stock: int = int(item.get("max_stock", 0))
	var unlock_day := int(item.get("unlock_day", 1))
	var is_unlocked := unlock_day <= GameManager.current_night
	var is_selected: bool = selected_items.has(item_id)
	var state_text := "可选择"
	if not is_unlocked:
		state_text = "尚未解锁（第 %d 夜）" % unlock_day
	elif stock <= 0 and not is_selected:
		state_text = "库存为 0"
	elif is_selected:
		state_text = "已选择"
	elif selected_items.size() >= MAX_SELECTED_ITEMS:
		state_text = "已达选择上限"

	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = is_selected
	button.disabled = not is_unlocked or (stock <= 0 and not is_selected) or _is_submitting or _scene_transitioning
	button.text = "%s · %s\n库存：%d/%d\n%s" % [item_name, state_text, stock, max_stock, description]
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(290, 128)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_selected:
		button.modulate = Color(1.0, 0.9, 0.55)
	elif not is_unlocked or stock <= 0:
		button.modulate = Color(0.55, 0.55, 0.58)
	elif selected_items.size() >= MAX_SELECTED_ITEMS:
		button.modulate = Color(0.72, 0.72, 0.76)
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
	if _is_submitting or _scene_transitioning:
		return

	if selected_items.has(item_id):
		selected_items.erase(item_id)
		_set_feedback("")
		_refresh_item_cards()
		_refresh_selection()
		return

	if selected_items.size() >= MAX_SELECTED_ITEMS:
		_set_feedback("最多只能选择 %d 件商品。" % MAX_SELECTED_ITEMS)
		_refresh_item_cards()
		return

	if not InventorySystem.has_stock(item_id):
		_set_feedback("这个商品已经没有库存。")
		_refresh_item_cards()
		return

	var item := DataManager.get_item_by_id(item_id)
	if item.is_empty() or int(item.get("unlock_day", 1)) > GameManager.current_night:
		_set_feedback("这个商品尚未解锁。")
		_refresh_item_cards()
		return

	selected_items.append(item_id)
	_set_feedback("")
	_refresh_item_cards()
	_refresh_selection()


func _on_confirm_pressed() -> void:
	submit_selection()


func submit_selection(change_scene: bool = true) -> bool:
	if selected_items.is_empty():
		_set_feedback("请至少选择 1 件商品。")
		_refresh_selection()
		return false

	if _is_submitting or _scene_transitioning:
		return false

	var current_customer: Dictionary = CustomerSystem.get_current_customer()
	if current_customer.is_empty():
		_set_feedback("今晚已经没有顾客。")
		return false

	_is_submitting = true
	_refresh_selection()
	_refresh_item_cards()

	var selected_ids: Array[String] = selected_items.duplicate()
	var service_result: Dictionary = ScoreSystem.calculate_score(current_customer, selected_ids)
	service_result["service_id"] = _make_service_id(current_customer)

	if not _has_stock_for_item_ids(selected_ids):
		_is_submitting = false
		_set_feedback("库存不足，请重新选择商品。")
		_refresh_item_cards()
		_refresh_selection()
		return false

	NightStatsSystem.record_service_result(service_result)
	CustomerProgressSystem.record_customer_result(current_customer, service_result)
	GameManager.add_money(int(service_result.get("income", 0)))
	InventorySystem.consume_items(selected_ids)
	PlaytestLogger.log_service(service_result, current_customer)
	GameManager.show_result(service_result, change_scene)
	return true


func _on_clear_pressed() -> void:
	if _is_submitting or _scene_transitioning:
		return

	selected_items.clear()
	_set_feedback("")
	_refresh_item_cards()
	_refresh_selection()


func _on_main_menu_pressed() -> void:
	GameManager.go_to_main_menu()


func _make_service_id(customer: Dictionary) -> String:
	return "%d:%d:%s" % [
		GameManager.current_night,
		CustomerSystem.get_current_customer_number(),
		str(customer.get("id", ""))
	]


func _on_night_changed(_current_night: int) -> void:
	_refresh()


func _on_money_changed(_money: int) -> void:
	_refresh_header()


func _on_inventory_changed(_item_id: String, _stock: int) -> void:
	_refresh_item_cards()
	_refresh_selection()


func _on_inventory_reset() -> void:
	selected_items.clear()
	_refresh()


func _on_current_customer_changed(_customer: Dictionary, _customer_index: int) -> void:
	selected_items.clear()
	_is_submitting = false
	_set_feedback("")
	_refresh_customer()
	_refresh_item_cards()
	_refresh_selection()


func can_confirm_selection() -> bool:
	return (
		not selected_items.is_empty()
		and not _is_submitting
		and not _scene_transitioning
		and CustomerSystem.has_more_customers()
	)


func get_selected_item_ids() -> Array[String]:
	return selected_items.duplicate()


func clear_selection() -> void:
	selected_items.clear()
	if _feedback_label != null:
		_set_feedback("")
	if _items_grid != null:
		_refresh_item_cards()
	if _selected_label != null:
		_refresh_selection()


func _on_scene_change_started(_scene_path: String) -> void:
	_scene_transitioning = true
	if _confirm_button != null:
		_refresh_selection()
