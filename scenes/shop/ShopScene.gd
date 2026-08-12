extends "res://scripts/ui/BaseScreen.gd"

const MAX_SELECTED_ITEMS := 3
const ItemCardScene = preload("res://scenes/ui/components/ItemCard.tscn")
const CustomerHeaderScene = preload("res://scenes/ui/components/CustomerHeader.tscn")
const DialoguePanelScene = preload("res://scenes/ui/components/DialoguePanel.tscn")
const ChapterCardScene = preload("res://scenes/ui/components/ChapterCard.tscn")
const NarrativeOverlayScene = preload("res://scenes/ui/components/NarrativeOverlay.tscn")
const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")
const PrimaryButtonScene = preload("res://scenes/ui/components/PrimaryButton.tscn")

var _night_label: Label
var _money_label: Label
var _customer_progress_label: Label
var _customer_header: Control
var _dialogue_panel: Control
var _items_grid: GridContainer
var _selected_label: Label
var _feedback_label: Label
var _clear_button: Button
var _confirm_button: Button
var _chapter_card: Control
var _narrative_overlay: Control

var selected_items: Array[String] = []
var _is_submitting := false
var _scene_transitioning := false
var _dialogue_interaction_ready := false
var _intro_active := true


func _ready() -> void:
	super._ready()
	CustomerSystem.ensure_night_queue(GameManager.current_night)
	_build_ui()
	_connect_signals()
	_refresh()
	call_deferred("_begin_customer_presentation")


func _build_ui() -> void:
	var background: Control = ScreenBackgroundScene.instantiate()
	background.set_background("shop_default")
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

	_narrative_overlay = NarrativeOverlayScene.instantiate()
	add_child(_narrative_overlay)
	_chapter_card = ChapterCardScene.instantiate()
	add_child(_chapter_card)


func _build_customer_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
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

	var customer_content := HBoxContainer.new()
	customer_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	customer_content.add_theme_constant_override("separation", 12)
	layout.add_child(customer_content)

	_customer_header = CustomerHeaderScene.instantiate()
	_customer_header.custom_minimum_size = Vector2(200, 0)
	_customer_header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_customer_header.size_flags_vertical = Control.SIZE_EXPAND_FILL
	customer_content.add_child(_customer_header)

	_dialogue_panel = DialoguePanelScene.instantiate()
	_dialogue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	customer_content.add_child(_dialogue_panel)

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

	if not _dialogue_panel.continue_requested.is_connected(_on_dialogue_continue_requested):
		_dialogue_panel.continue_requested.connect(_on_dialogue_continue_requested)


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
		_dialogue_interaction_ready = false
		_customer_progress_label.text = "今晚已无顾客"
		_customer_header.show_empty_state("打烊前的安静", "今晚的队列已经结束。")
		_dialogue_panel.clear_dialogue()
		return

	_customer_progress_label.text = "顾客 %d / %d" % [
		CustomerSystem.get_current_customer_number(),
		CustomerSystem.get_customer_count_for_current_night()
	]
	var profile := DataManager.get_customer_profile_by_story_id(str(customer.get("story_id", "")))
	_customer_header.setup(customer, profile)
	_dialogue_interaction_ready = false
	if _intro_active:
		_dialogue_panel.clear_dialogue()
	else:
		_show_customer_dialogue(customer)


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
		button.item_pressed.connect(_on_item_pressed)
		_items_grid.add_child(button)


func _refresh_selection() -> void:
	_clear_button.disabled = selected_items.is_empty() or _is_submitting or _scene_transitioning or not _dialogue_interaction_ready
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
	var description: String = str(item.get("description", ""))
	var unlock_day := int(item.get("unlock_day", 1))
	var is_unlocked := ContentUnlockSystem.is_item_unlocked(item_id)
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

	var button: Button = ItemCardScene.instantiate()
	button.setup(item, stock)
	button.toggle_mode = true
	button.set_state_text(state_text, item, stock)
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(290, 128)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _dialogue_interaction_ready or _is_submitting or _scene_transitioning or (selected_items.size() >= MAX_SELECTED_ITEMS and not is_selected):
		button.set_state(ItemCard.CardState.DISABLED)
	elif not is_unlocked:
		button.set_state(ItemCard.CardState.LOCKED)
	elif stock <= 0 and not is_selected:
		button.set_state(ItemCard.CardState.OUT_OF_STOCK)
	elif is_selected:
		button.set_state(ItemCard.CardState.SELECTED)
	else:
		button.set_state(ItemCard.CardState.AVAILABLE)
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
	var button: Button = PrimaryButtonScene.instantiate()
	button.set_text(text)
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
	if not message.is_empty():
		show_message(message)


func _on_item_pressed(item_id: String) -> void:
	if not _dialogue_interaction_ready or _is_submitting or _scene_transitioning:
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
	if item.is_empty() or not ContentUnlockSystem.is_item_unlocked(item_id):
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
	if not _dialogue_interaction_ready:
		_set_feedback("请先读完顾客的话。")
		return false

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
	StoryEventSystem.get_available_events({
		"type": "customer_result",
		"night": GameManager.current_night,
		"story_id": str(current_customer.get("story_id", "")),
		"story_stage": int(current_customer.get("story_stage", 1))
	})
	GameManager.add_money(int(service_result.get("income", 0)))
	InventorySystem.consume_items(selected_ids)
	PlaytestLogger.log_service(service_result, current_customer)
	GameManager.show_result(service_result, change_scene)
	return true


func _on_clear_pressed() -> void:
	if not _dialogue_interaction_ready or _is_submitting or _scene_transitioning:
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
	_intro_active = false
	_dialogue_interaction_ready = false
	_set_feedback("")
	_refresh_customer()
	_refresh_item_cards()
	_refresh_selection()


func can_confirm_selection() -> bool:
	return (
		not selected_items.is_empty()
		and _dialogue_interaction_ready
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


func _begin_customer_presentation() -> void:
	var customer: Dictionary = CustomerSystem.get_current_customer()
	if customer.is_empty():
		_intro_active = false
		return

	if CustomerSystem.get_current_customer_number() == 1:
		_narrative_overlay.show_text(get_night_transition_text(), "", 1.0)
		await _narrative_overlay.dismissed
		if not is_inside_tree():
			return

	var chapter_event := _get_new_chapter_start_event()
	if not chapter_event.is_empty():
		var chapter := ChapterSystem.get_chapter_for_night(GameManager.current_night)
		var title_parts := _split_chapter_name(str(chapter.get("name", "")))
		_chapter_card.show_chapter(title_parts[0], title_parts[1], "start")
		await _chapter_card.dismissed
		if not is_inside_tree():
			return

	_intro_active = false
	_show_customer_dialogue(customer)
	_refresh_item_cards()
	_refresh_selection()


func _show_customer_dialogue(customer: Dictionary) -> void:
	_dialogue_interaction_ready = false
	_dialogue_panel.show_dialogue(
		str(customer.get("customer_name", "顾客")),
		str(customer.get("dialogue", "…"))
	)


func _on_dialogue_continue_requested() -> void:
	_dialogue_interaction_ready = true
	_refresh_item_cards()
	_refresh_selection()


func _get_new_chapter_start_event() -> Dictionary:
	for event in StoryEventSystem.get_last_triggered_events():
		if not (event is Dictionary) or str(event.get("type", "")) != "chapter_start":
			continue
		var trigger = event.get("trigger", {})
		if trigger is Dictionary and int(trigger.get("night", 0)) == GameManager.current_night:
			return event.duplicate(true)
	return {}


func _split_chapter_name(chapter_name: String) -> Array[String]:
	var result: Array[String] = [chapter_name, ""]
	var parts := chapter_name.split("：", true, 1)
	if parts.size() > 1:
		result[0] = parts[0]
		result[1] = parts[1]
	return result


func get_dialogue_panel() -> Control:
	return _dialogue_panel


func is_dialogue_interaction_ready() -> bool:
	return _dialogue_interaction_ready


func has_active_narrative_intro() -> bool:
	return _intro_active


func skip_narrative_intro() -> bool:
	if _narrative_overlay != null and _narrative_overlay.is_open():
		return _narrative_overlay.close()
	if _chapter_card != null and _chapter_card.visible:
		return _chapter_card.dismiss()
	return false


func get_night_transition_text() -> String:
	return "第 %d 夜" % GameManager.current_night


func get_chapter_presentation_for_night(night_number: int) -> Dictionary:
	var chapter := ChapterSystem.get_chapter_for_night(night_number)
	if chapter.is_empty() or int(chapter.get("start_night", 0)) != night_number:
		return {}
	var title_parts := _split_chapter_name(str(chapter.get("name", "")))
	return {
		"chapter_id": str(chapter.get("id", "")),
		"title": title_parts[0],
		"subtitle": title_parts[1]
	}
