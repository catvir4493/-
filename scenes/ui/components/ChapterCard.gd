class_name ChapterCard
extends PanelContainer

signal dismissed(mode: String)

@onready var _mode_label: Label = $Center/Card/Margin/Layout/ModeLabel
@onready var _title_label: Label = $Center/Card/Margin/Layout/TitleLabel
@onready var _subtitle_label: Label = $Center/Card/Margin/Layout/SubtitleLabel

var _mode := "start"
var _dismissed := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func show_chapter(chapter_title: String, subtitle: String = "", mode: String = "start") -> void:
	_ensure_nodes()
	_mode = mode if mode == "complete" else "start"
	_mode_label.text = "CHAPTER COMPLETE" if _mode == "complete" else "CHAPTER START"
	_title_label.text = chapter_title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_dismissed = false
	visible = true
	call_deferred("grab_focus")


func dismiss() -> bool:
	if not visible or _dismissed:
		return false
	_dismissed = true
	visible = false
	dismissed.emit(_mode)
	return true


func get_chapter_title() -> String:
	_ensure_nodes()
	return _title_label.text


func get_subtitle() -> String:
	_ensure_nodes()
	return _subtitle_label.text


func get_mode() -> String:
	return _mode


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if dismiss():
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		if dismiss():
			get_viewport().set_input_as_handled()


func _ensure_nodes() -> void:
	if _mode_label == null:
		_mode_label = get_node("Center/Card/Margin/Layout/ModeLabel") as Label
	if _title_label == null:
		_title_label = get_node("Center/Card/Margin/Layout/TitleLabel") as Label
	if _subtitle_label == null:
		_subtitle_label = get_node("Center/Card/Margin/Layout/SubtitleLabel") as Label
