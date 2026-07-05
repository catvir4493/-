extends Control

var _profile_list: VBoxContainer
var _detail_title_label: Label
var _detail_body_label: Label
var _selected_profile_id := ""


func _ready() -> void:
	_load_archive_progress_if_needed()
	_build_ui()
	_select_first_profile()
	_refresh_profile_list()
	_refresh_detail()


func _load_archive_progress_if_needed() -> void:
	if not CustomerProgressSystem.get_seen_customers().is_empty():
		return

	if SaveManager.has_valid_save():
		SaveManager.load_customer_progress_from_save()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.06, 0.08)
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

	var title := _make_label("深夜顾客档案", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	layout.add_child(body)

	body.add_child(_build_profile_list_panel())
	body.add_child(_build_detail_panel())

	var back_button := _make_button("Back")
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)


func _build_profile_list_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_profile_list = VBoxContainer.new()
	_profile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_profile_list)

	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	_detail_title_label = _make_label("", 28)
	_detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(_detail_title_label)

	_detail_body_label = _make_label("", 18)
	_detail_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_detail_body_label)

	return panel


func _select_first_profile() -> void:
	var profiles := DataManager.get_all_customer_profiles()
	if profiles.is_empty():
		_selected_profile_id = ""
		return

	var first_profile: Dictionary = profiles[0]
	_selected_profile_id = str(first_profile.get("id", ""))


func _refresh_profile_list() -> void:
	for child in _profile_list.get_children():
		child.queue_free()

	var profiles := DataManager.get_all_customer_profiles()
	if profiles.is_empty():
		_profile_list.add_child(_make_label("暂无档案数据。", 16))
		return

	for profile in profiles:
		if not (profile is Dictionary):
			continue

		var button := _make_profile_button(profile)
		var captured_id := str(profile.get("id", ""))
		button.pressed.connect(func() -> void:
			_selected_profile_id = captured_id
			_refresh_profile_list()
			_refresh_detail()
		)
		_profile_list.add_child(button)


func _refresh_detail() -> void:
	if _selected_profile_id.is_empty():
		_detail_title_label.text = "暂无档案"
		_detail_body_label.text = "没有可显示的顾客档案。"
		return

	var profile := DataManager.get_customer_profile_by_id(_selected_profile_id)
	if profile.is_empty():
		_detail_title_label.text = "暂无档案"
		_detail_body_label.text = "无法找到这份顾客档案。"
		return

	var story_id := str(profile.get("story_id", ""))
	if not CustomerProgressSystem.has_seen_customer(story_id):
		_detail_title_label.text = "尚未遇见这位顾客。"
		_detail_body_label.text = str(profile.get("locked_description", "尚未遇见。"))
		return

	var progress := CustomerProgressSystem.get_story_progress(story_id)
	var stage := CustomerProgressSystem.get_archive_stage(story_id)
	_detail_title_label.text = str(profile.get("display_name", "未知顾客"))
	_detail_body_label.text = "\n".join([
		"类型：%s" % str(profile.get("customer_type", "")),
		"简介：%s" % str(profile.get("short_description", "")),
		"档案阶段：%d" % stage,
		_get_archive_stage_text(profile, stage),
		"到访次数：%d" % int(progress.get("visit_count", 0)),
		"最佳评价：%s" % _format_empty(str(progress.get("best_grade", ""))),
		"最高分：%d" % int(progress.get("best_score", 0)),
		"最近评价：%s" % _format_empty(str(progress.get("last_grade", ""))),
		"最近分数：%d" % int(progress.get("last_score", 0))
	])


func _make_profile_button(profile: Dictionary) -> Button:
	var profile_id := str(profile.get("id", ""))
	var story_id := str(profile.get("story_id", ""))
	var unlocked := CustomerProgressSystem.has_seen_customer(story_id)
	var stage := CustomerProgressSystem.get_archive_stage(story_id)

	var button := _make_button("")
	button.toggle_mode = true
	button.button_pressed = profile_id == _selected_profile_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if unlocked:
		button.text = "%s\n%s · Stage %d" % [
			str(profile.get("display_name", "")),
			str(profile.get("customer_type", "")),
			stage
		]
	else:
		button.text = "？？？\n尚未遇见"

	return button


func _get_archive_stage_text(profile: Dictionary, requested_stage: int) -> String:
	var stages = profile.get("archive_stages", {})
	if not (stages is Dictionary):
		return str(profile.get("locked_description", "尚未遇见。"))

	var selected_stage := clampi(requested_stage, 0, _get_highest_stage(stages))
	while selected_stage >= 0:
		var key := str(selected_stage)
		if stages.has(key):
			return str(stages[key])

		selected_stage -= 1

	return str(profile.get("locked_description", "尚未遇见。"))


func _get_highest_stage(stages: Dictionary) -> int:
	var highest := 0
	for key in stages.keys():
		var stage := _to_int(key, 0)
		highest = maxi(highest, stage)

	return highest


func _format_empty(value: String) -> String:
	if value.is_empty():
		return "无"

	return value


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
	button.custom_minimum_size = Vector2(220, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button


func _on_back_pressed() -> void:
	GameManager.go_to_main_menu()


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value
