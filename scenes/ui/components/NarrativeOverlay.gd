class_name NarrativeOverlay
extends PanelContainer

signal dismissed

@onready var _title_label: Label = $Center/Content/TitleLabel
@onready var _body_text: RichTextLabel = $Center/Content/BodyText
@onready var _hint_label: Label = $Center/Content/HintLabel

var _auto_close_remaining := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(false)


func show_text(title: String, body: String, auto_close_seconds: float = 0.0) -> void:
	_ensure_nodes()
	_title_label.text = title
	_body_text.text = body
	_body_text.visible = not body.is_empty()
	_hint_label.text = "点击跳过" if auto_close_seconds > 0.0 else "点击或按 Enter 继续"
	visible = true
	_auto_close_remaining = maxf(auto_close_seconds, 0.0)
	set_process(_auto_close_remaining > 0.0)
	call_deferred("grab_focus")


func close() -> bool:
	if not visible:
		return false
	_auto_close_remaining = 0.0
	set_process(false)
	visible = false
	dismissed.emit()
	return true


func is_open() -> bool:
	return visible


func get_title() -> String:
	_ensure_nodes()
	return _title_label.text


func get_body() -> String:
	_ensure_nodes()
	return _body_text.text


func _process(delta: float) -> void:
	if _auto_close_remaining <= 0.0:
		set_process(false)
		return
	_auto_close_remaining -= delta
	if _auto_close_remaining <= 0.0:
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if close():
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
		if close():
			get_viewport().set_input_as_handled()


func _ensure_nodes() -> void:
	if _title_label == null:
		_title_label = get_node("Center/Content/TitleLabel") as Label
	if _body_text == null:
		_body_text = get_node("Center/Content/BodyText") as RichTextLabel
	if _hint_label == null:
		_hint_label = get_node("Center/Content/HintLabel") as Label
