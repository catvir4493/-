extends CanvasLayer

var _panel: PanelContainer
var _info_label: Label
var _night_selector: OptionButton
var _status_label: Label
var _save_confirmation: ConfirmationDialog


func _ready() -> void:
	if not DebugManager.is_available():
		queue_free()
		return

	_build_ui()
	_panel.visible = false


func _process(_delta: float) -> void:
	if _panel != null and _panel.visible:
		_refresh_info()


func toggle_overlay() -> void:
	if not DebugManager.is_available() or _panel == null:
		return

	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_info()


func is_overlay_visible() -> bool:
	return _panel != null and _panel.visible


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 18)
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := _make_label("Debug Playtest Overlay · F3", 20)
	layout.add_child(title)

	_info_label = _make_label("", 13)
	_info_label.custom_minimum_size = Vector2(580, 260)
	layout.add_child(_info_label)

	var jump_row := HBoxContainer.new()
	jump_row.add_theme_constant_override("separation", 8)
	layout.add_child(jump_row)

	_night_selector = OptionButton.new()
	for night_number in range(1, 6):
		_night_selector.add_item("Night %d" % night_number, night_number)
	jump_row.add_child(_night_selector)

	var jump_button := _make_button("Jump to Night")
	jump_button.pressed.connect(_on_jump_pressed)
	jump_row.add_child(jump_button)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	layout.add_child(actions)

	_add_action_button(actions, "Next Customer", _on_next_customer_pressed)
	_add_action_button(actions, "Refill Inventory", _on_refill_pressed)
	_add_action_button(actions, "Add Money +100", _on_add_money_pressed)
	_add_action_button(actions, "Clear Runtime Debug Changes", _on_clear_runtime_pressed)
	_add_action_button(actions, "Save Debug State", _on_save_debug_pressed)

	var warning := _make_label(
		"Debug jump does not modify the current save unless Save Debug State is pressed.",
		12
	)
	warning.modulate = Color(1.0, 0.82, 0.45)
	layout.add_child(warning)

	_status_label = _make_label("", 12)
	layout.add_child(_status_label)

	_save_confirmation = ConfirmationDialog.new()
	_save_confirmation.title = "Save Debug State"
	_save_confirmation.dialog_text = "这会覆盖当前单槽存档。"
	_save_confirmation.confirmed.connect(_on_save_confirmed)
	add_child(_save_confirmation)


func _refresh_info() -> void:
	var customer := CustomerSystem.get_current_customer()
	var result := GameManager.get_last_service_result()
	var save_data := SaveManager.get_save_data()
	var inventory_summary: Array[String] = []
	for item in DataManager.get_all_items():
		if not (item is Dictionary):
			continue
		var item_id := str(item.get("id", ""))
		if int(item.get("unlock_day", 1)) <= GameManager.current_night:
			inventory_summary.append(
				"%s:%d/%d" % [
					item_id,
					InventorySystem.get_stock(item_id),
					InventorySystem.get_max_stock(item_id)
				]
			)

	_info_label.text = "\n".join([
		"current_night: %d    checkpoint_scene: %s    money: %d" % [
			GameManager.current_night,
			str(save_data.get("checkpoint_scene", "none")),
			GameManager.money
		],
		"customer: %d / %d    request_id: %s" % [
			CustomerSystem.get_current_customer_number(),
			CustomerSystem.get_customer_count_for_current_night(),
			str(customer.get("id", "none"))
		],
		"story_id: %s    story_stage: %s" % [
			str(customer.get("story_id", "none")),
			str(customer.get("story_stage", "none"))
		],
		"required_tags: %s" % JSON.stringify(customer.get("required_tags", [])),
		"avoid_tags: %s" % JSON.stringify(customer.get("avoid_tags", [])),
		"inventory: %s" % ", ".join(inventory_summary),
		"last_service_result: score=%s grade=%s" % [
			str(result.get("score", "none")),
			str(result.get("grade", "none"))
		],
		"NightStatsSystem: %s" % JSON.stringify(NightStatsSystem.get_night_summary())
	])


func _add_action_button(parent: Control, text: String, callback: Callable) -> void:
	var button := _make_button(text)
	button.pressed.connect(callback)
	parent.add_child(button)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 34)
	return button


func _set_status(message: String) -> void:
	_status_label.text = message
	_refresh_info()


func _on_jump_pressed() -> void:
	var night_number := _night_selector.get_selected_id()
	_set_status("Jumped to Night %d." % night_number if DebugManager.jump_to_night(night_number) else "Jump failed.")


func _on_next_customer_pressed() -> void:
	_set_status("Moved to the next customer." if DebugManager.next_customer() else "No next customer is available.")


func _on_refill_pressed() -> void:
	_set_status("Unlocked inventory refilled." if DebugManager.refill_inventory() else "Refill is unavailable.")


func _on_add_money_pressed() -> void:
	_set_status("Added 100 debug money." if DebugManager.add_debug_money() else "Add Money is unavailable.")


func _on_clear_runtime_pressed() -> void:
	_set_status("Runtime debug changes cleared." if DebugManager.clear_runtime_debug_changes() else "Could not restore runtime state.")


func _on_save_debug_pressed() -> void:
	_save_confirmation.popup_centered()


func _on_save_confirmed() -> void:
	_set_status("Debug state saved." if DebugManager.save_debug_state() else "Debug state could not be saved.")
