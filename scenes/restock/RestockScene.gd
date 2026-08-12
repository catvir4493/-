extends "res://scripts/ui/BaseScreen.gd"

const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")
const PrimaryButtonScene = preload("res://scenes/ui/components/PrimaryButton.tscn")
const RestockItemCardScene = preload("res://scenes/ui/components/RestockItemCard.tscn")

var _night_label: Label
var _money_label: Label
var _feedback_label: Label
var _item_list: VBoxContainer
var _next_night_button: Button

var _buy_buttons_by_item_id: Dictionary = {}
var _stock_labels_by_item_id: Dictionary = {}
var _purchase_in_progress := false


func _ready() -> void:
	super._ready()
	_build_ui()
	_connect_signals()
	_refresh()


func _build_ui() -> void:
	var background: Control = ScreenBackgroundScene.instantiate()
	background.set_background("restock_default")
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
	var buy_price := int(item.get("buy_price", 0))
	var stock := InventorySystem.get_stock(item_id)
	var max_stock := InventorySystem.get_max_stock(item_id)

	var panel: Control = RestockItemCardScene.instantiate()
	panel.setup(item, stock, max_stock)
	panel.set_buy_enabled(not _should_disable_buy_button(item_id, buy_price))
	panel.buy_pressed.connect(_on_buy_pressed)
	var stock_label: Label = panel.get_stock_label()
	_stock_labels_by_item_id[item_id] = stock_label
	var buy_button: Button = panel.get_buy_button()
	_buy_buttons_by_item_id[item_id] = buy_button

	return panel


func _get_unlocked_items() -> Array:
	var unlocked_items: Array = []

	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue

		if ContentUnlockSystem.is_item_unlocked(str(item.get("id", ""))):
			unlocked_items.append(item)

	return unlocked_items


func _should_disable_buy_button(item_id: String, buy_price: int) -> bool:
	return (
		_purchase_in_progress
		or InventorySystem.is_stock_full(item_id)
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
	var button: Button = PrimaryButtonScene.instantiate()
	button.set_text(text)
	button.custom_minimum_size = Vector2(180, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _on_buy_pressed(item_id: String) -> void:
	if _purchase_in_progress:
		return

	_purchase_in_progress = true
	_refresh_buy_states()
	var result: Dictionary = InventorySystem.buy_item(item_id, 1)
	if bool(result.get("success", false)):
		_feedback_label.text = "已补货：%s" % _get_item_name(item_id)
		if not SaveManager.save_game("restock"):
			push_warning("Failed to save restock checkpoint after purchase.")
	else:
		_feedback_label.text = _get_failure_message(str(result.get("reason", "")))
		show_message(_feedback_label.text)

	_purchase_in_progress = false
	_refresh_header()
	_refresh_buy_states()


func _on_next_night_pressed() -> void:
	start_next_night_once()


func start_next_night_once(change_scene: bool = true) -> bool:
	if _next_night_button.disabled:
		return false

	_next_night_button.disabled = true
	GameManager.start_next_night(change_scene)
	return true


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
