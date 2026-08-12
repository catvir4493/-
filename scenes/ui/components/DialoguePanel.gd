class_name DialoguePanel
extends PanelContainer

signal dialogue_started
signal dialogue_revealed
signal continue_requested

const BASE_CHARS_PER_SECOND := 36.0

@onready var _speaker_label: Label = $Margin/Layout/SpeakerLabel
@onready var _dialogue_text: RichTextLabel = $Margin/Layout/DialogueText
@onready var _continue_hint: Label = $Margin/Layout/ContinueHint

var _full_text := ""
var _revealing := false
var _finished := false
var _has_dialogue := false
var _continue_emitted := false
var _visible_progress := 0.0
var _text_speed := 1.0
var _last_input_frame := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(false)


func show_dialogue(speaker_name: String, text: String, instant: bool = false) -> void:
	_ensure_nodes()
	_full_text = text
	_speaker_label.text = speaker_name
	_speaker_label.visible = not speaker_name.is_empty()
	_dialogue_text.text = _full_text
	_dialogue_text.visible_characters = 0
	_continue_hint.visible = false
	_visible_progress = 0.0
	_text_speed = _read_text_speed()
	_has_dialogue = true
	_finished = false
	_continue_emitted = false
	_revealing = not instant and not _full_text.is_empty()
	set_process(_revealing)
	dialogue_started.emit()
	if instant or _full_text.is_empty():
		reveal_all()


func reveal_all() -> void:
	if not _has_dialogue:
		return
	_ensure_nodes()
	_dialogue_text.visible_characters = -1
	_visible_progress = float(_full_text.length())
	_revealing = false
	set_process(false)
	if not _finished:
		_finished = true
		_continue_hint.visible = true
		dialogue_revealed.emit()


func request_advance() -> bool:
	if not visible or not _has_dialogue:
		return false
	var current_frame := Engine.get_process_frames()
	if current_frame == _last_input_frame:
		return false
	_last_input_frame = current_frame
	if _revealing:
		reveal_all()
		return true
	if _finished and not _continue_emitted:
		_continue_emitted = true
		_continue_hint.visible = false
		continue_requested.emit()
		return true
	return false


func is_revealing() -> bool:
	return _revealing


func is_finished() -> bool:
	return _has_dialogue and _finished


func get_full_text() -> String:
	return _full_text


func get_visible_character_count() -> int:
	_ensure_nodes()
	return _dialogue_text.visible_characters


func get_effective_characters_per_second() -> float:
	return BASE_CHARS_PER_SECOND * _text_speed


func get_speaker_name() -> String:
	_ensure_nodes()
	return _speaker_label.text


func clear_dialogue() -> void:
	_ensure_nodes()
	_full_text = ""
	_speaker_label.text = ""
	_dialogue_text.text = ""
	_dialogue_text.visible_characters = -1
	_continue_hint.visible = false
	_visible_progress = 0.0
	_revealing = false
	_finished = false
	_has_dialogue = false
	_continue_emitted = false
	set_process(false)


func _process(delta: float) -> void:
	if not _revealing:
		return
	_visible_progress += get_effective_characters_per_second() * delta
	var target := mini(int(floor(_visible_progress)), _full_text.length())
	_dialogue_text.visible_characters = target
	if target >= _full_text.length():
		reveal_all()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if request_advance():
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER and event.keycode != KEY_SPACE:
		return
	if request_advance():
		get_viewport().set_input_as_handled()


func _read_text_speed() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("SettingsManager") if tree != null else null
	if settings != null and settings.has_method("get_text_speed"):
		return clampf(float(settings.get_text_speed()), 0.5, 2.0)
	return 1.0


func _ensure_nodes() -> void:
	if _speaker_label == null:
		_speaker_label = get_node("Margin/Layout/SpeakerLabel") as Label
	if _dialogue_text == null:
		_dialogue_text = get_node("Margin/Layout/DialogueText") as RichTextLabel
	if _continue_hint == null:
		_continue_hint = get_node("Margin/Layout/ContinueHint") as Label
