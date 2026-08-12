extends "res://scripts/ui/BaseScreen.gd"

const ScreenBackgroundScene = preload("res://scenes/ui/components/ScreenBackground.tscn")
const PrimaryButtonScene = preload("res://scenes/ui/components/PrimaryButton.tscn")
const ScreenLayoutScene = preload("res://scenes/ui/layouts/ScreenLayout.tscn")
const InfoPanelScene = preload("res://scenes/ui/components/InfoPanel.tscn")
const StatRowScene = preload("res://scenes/ui/components/StatRow.tscn")
const ChapterCardScene = preload("res://scenes/ui/components/ChapterCard.tscn")

var _title_label: Label
var _summary_label: Label
var _restock_button: Button
var _stats: VBoxContainer
var _chapter_card: Control
var _completed_chapter_now: Dictionary = {}


func _ready() -> void:
	super._ready()
	_build_ui()
	_update_framework_progress()
	_refresh()
	_show_chapter_complete_if_needed()
	if not SaveManager.save_game("night_result"):
		push_warning("Failed to save night_result checkpoint.")


func _update_framework_progress() -> void:
	var chapter := ChapterSystem.get_chapter_for_night(GameManager.current_night)
	if chapter.is_empty() or GameManager.current_night != int(chapter.get("end_night", 0)):
		return

	var chapter_id := str(chapter.get("id", ""))
	var completed_now := ChapterSystem.mark_chapter_completed(chapter_id)
	if completed_now:
		_completed_chapter_now = chapter.duplicate(true)
	StoryEventSystem.get_available_events({
		"type": "night_result",
		"night": GameManager.current_night,
		"chapter_id": chapter_id
	})
	for ending in EndingSystem.get_available_endings():
		if ending is Dictionary:
			EndingSystem.unlock_ending(str(ending.get("id", "")))


func _build_ui() -> void:
	var background: Control = ScreenBackgroundScene.instantiate()
	background.set_background("night_result_default")
	add_child(background)

	var screen_layout: Control = ScreenLayoutScene.instantiate()
	add_child(screen_layout)
	var header: Control = screen_layout.get_header()
	var content: Control = screen_layout.get_content()
	var footer: Control = screen_layout.get_footer()

	_title_label = _make_label("", 32)
	header.add_child(_title_label)

	var panel: Control = InfoPanelScene.instantiate()
	panel.set_title("本夜统计")
	content.add_child(panel)
	var panel_layout := panel.get_node("Margin/Layout") as VBoxContainer
	_stats = VBoxContainer.new()
	_stats.name = "Stats"
	panel_layout.add_child(_stats)
	panel_layout.move_child(_stats, 1)
	_summary_label = panel.get_content_label()
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_restock_button = _make_button("进入进货")
	_restock_button.pressed.connect(_on_restock_pressed)
	footer.add_child(_restock_button)

	_chapter_card = ChapterCardScene.instantiate()
	_chapter_card.dismissed.connect(_on_chapter_card_dismissed)
	add_child(_chapter_card)


func _refresh() -> void:
	var summary: Dictionary = NightStatsSystem.get_night_summary()
	if not has_consistent_grade_total(summary):
		push_warning(
			"Night result grade totals do not match customers_served: %s." %
			JSON.stringify(summary)
		)
	_title_label.text = "第 %d 夜结束" % int(summary.get("night_number", GameManager.current_night))
	_refresh_stats(summary)
	_summary_label.text = "\n".join([
		"Perfect 次数：%d" % int(summary.get("perfect_count", 0)),
		"Good 次数：%d" % int(summary.get("good_count", 0)),
		"Normal 次数：%d" % int(summary.get("normal_count", 0)),
		"Fail 次数：%d" % int(summary.get("fail_count", 0)),
		"店铺评级文本：%s" % str(summary.get("shop_rating_text", "")),
		"触发组合总次数：%d" % int(summary.get("triggered_combo_count", 0)),
		"本夜组合：%s" % _format_combo_names(summary.get("triggered_combo_names", []))
	])


func _refresh_stats(summary: Dictionary) -> void:
	for child in _stats.get_children():
		child.queue_free()
	_add_stat("接待顾客", str(int(summary.get("customers_served", 0))))
	_add_stat("本夜总收入", str(int(summary.get("total_income", 0))))
	_add_stat("平均分", "%.1f" % float(summary.get("average_score", 0.0)))
	_add_stat("店铺评级", str(summary.get("shop_rating", "")))


func _add_stat(label_text: String, value_text: String) -> void:
	var row: Control = StatRowScene.instantiate()
	row.setup(label_text, value_text)
	_stats.add_child(row)


func has_consistent_grade_total(summary: Dictionary) -> bool:
	var grade_total := (
		int(summary.get("perfect_count", 0))
		+ int(summary.get("good_count", 0))
		+ int(summary.get("normal_count", 0))
		+ int(summary.get("fail_count", 0))
	)
	return grade_total == int(summary.get("customers_served", 0))


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
	var button: Button = PrimaryButtonScene.instantiate()
	button.set_text(text)
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


func _show_chapter_complete_if_needed() -> void:
	if _completed_chapter_now.is_empty():
		return
	var title_parts := _split_chapter_name(str(_completed_chapter_now.get("name", "")))
	_restock_button.disabled = true
	_chapter_card.show_chapter(title_parts[0], title_parts[1], "complete")


func _on_chapter_card_dismissed(_mode: String) -> void:
	_restock_button.disabled = false


func can_show_chapter_complete_for_night(night_number: int) -> bool:
	var chapter := ChapterSystem.get_chapter_for_night(night_number)
	return not chapter.is_empty() and int(chapter.get("end_night", 0)) == night_number


func get_chapter_card() -> Control:
	return _chapter_card


func _split_chapter_name(chapter_name: String) -> Array[String]:
	var result: Array[String] = [chapter_name, ""]
	var parts := chapter_name.split("：", true, 1)
	if parts.size() > 1:
		result[0] = parts[0]
		result[1] = parts[1]
	return result
