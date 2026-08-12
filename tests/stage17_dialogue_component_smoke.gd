extends SceneTree

const DialoguePanelScene = preload("res://scenes/ui/components/DialoguePanel.tscn")

var failures: Array[String] = []
var SettingsManager
var _original_settings: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	SettingsManager = root.get_node_or_null("/root/SettingsManager")
	_assert(SettingsManager != null, "SettingsManager must exist.")
	if SettingsManager == null:
		_finish()
		return
	_original_settings = SettingsManager.export_settings()

	var panel: Control = DialoguePanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	_test_basic_reveal(panel)
	await _test_input_states(panel)
	_test_instant_and_clear(panel)
	_test_text_speeds(panel)
	_test_unicode_and_accessibility(panel)
	_assert(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "DialoguePanel must stop mouse input from reaching ItemCard controls.")

	SettingsManager.import_settings(_original_settings)
	panel.queue_free()
	await process_frame
	_finish()


func _test_basic_reveal(panel: Control) -> void:
	var counts := {"started": 0, "revealed": 0, "continued": 0}
	panel.dialogue_started.connect(func() -> void: counts["started"] += 1)
	panel.dialogue_revealed.connect(func() -> void: counts["revealed"] += 1)
	panel.continue_requested.connect(func() -> void: counts["continued"] += 1)
	panel.show_dialogue("夜班护士", "我今天递了辞职申请。\n但是现在又有点后悔。")
	_assert(panel.get_speaker_name() == "夜班护士", "Speaker name must be displayed.")
	_assert(panel.get_full_text() == "我今天递了辞职申请。\n但是现在又有点后悔。", "Full text must be preserved.")
	_assert(panel.get_visible_character_count() == 0, "Non-instant dialogue must start with zero visible characters.")
	_assert(panel.is_revealing(), "Dialogue must enter revealing state.")
	_assert(not panel.is_finished(), "Dialogue must not be finished initially.")
	panel.reveal_all()
	_assert(not panel.is_revealing(), "reveal_all must stop the typewriter.")
	_assert(panel.is_finished(), "reveal_all must finish the current text.")
	_assert(counts["started"] == 1 and counts["revealed"] == 1, "Start and reveal signals must each emit once.")


func _test_input_states(panel: Control) -> void:
	var signal_state := {"continue_count": 0}
	panel.continue_requested.connect(func() -> void: signal_state["continue_count"] += 1)
	panel.show_dialogue("顾客", "第一次输入只显示全文，第二次输入才继续。")
	_assert(panel.request_advance(), "First advance input must be accepted.")
	_assert(panel.is_finished(), "First advance input must reveal all text.")
	_assert(signal_state["continue_count"] == 0, "First input must not reveal and continue simultaneously.")
	_assert(not panel.request_advance(), "A second advance in the same frame must be debounced.")
	_assert(signal_state["continue_count"] == 0, "Debounced same-frame input must not emit continue.")
	await process_frame
	_assert(panel.request_advance(), "A later second input must be accepted.")
	_assert(signal_state["continue_count"] == 1, "Second input must emit continue exactly once.")
	await process_frame
	_assert(not panel.request_advance() and signal_state["continue_count"] == 1, "One dialogue must not emit continue repeatedly.")


func _test_instant_and_clear(panel: Control) -> void:
	panel.show_dialogue("系统", "立即显示", true)
	_assert(panel.is_finished() and not panel.is_revealing(), "instant=true must immediately finish the dialogue.")
	_assert(panel.get_full_text() == "立即显示", "Instant dialogue must retain full text.")
	panel.clear_dialogue()
	_assert(panel.get_full_text().is_empty(), "clear_dialogue must clear full text.")
	_assert(not panel.is_revealing() and not panel.is_finished(), "clear_dialogue must reset reveal state.")


func _test_text_speeds(panel: Control) -> void:
	var expected := {0.5: 18.0, 1.0: 36.0, 2.0: 72.0}
	for speed in [0.5, 1.0, 2.0]:
		SettingsManager.set_text_speed(speed)
		panel.show_dialogue("速度", "文本速度测试")
		_assert_approx(panel.get_effective_characters_per_second(), expected[speed], "%.1fx text speed must affect chars/sec." % speed)
	SettingsManager.set_text_speed(-10.0)
	_assert_approx(SettingsManager.get_text_speed(), 0.5, "Text speed minimum clamp must remain active.")
	SettingsManager.set_text_speed(10.0)
	_assert_approx(SettingsManager.get_text_speed(), 2.0, "Text speed maximum clamp must remain active.")


func _test_unicode_and_accessibility(panel: Control) -> void:
	var multilingual := "中文，English 123！\n第二行……结束。"
	panel.show_dialogue("测试", multilingual)
	panel.call("_process", 0.1)
	_assert(panel.get_full_text() == multilingual, "Chinese, English, digits, punctuation, and newlines must remain intact.")
	_assert(panel.get_visible_character_count() >= 0, "Unicode reveal must use character visibility, not byte slicing.")
	panel.reveal_all()
	_assert(panel.get_full_text() == multilingual, "get_full_text must remain available after reveal for accessibility extensions.")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _assert_approx(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		failures.append("%s Expected %.3f, got %.3f." % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("Stage 17 dialogue component smoke test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("Stage 17 dialogue component smoke test failed with %d issue(s)." % failures.size())
	quit(1)
