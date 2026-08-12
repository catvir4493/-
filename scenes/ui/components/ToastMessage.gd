class_name ToastMessage
extends Control

var _generation := 0

@onready var _label: Label = %Message


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_message(text: String, duration: float = 2.0) -> void:
	_generation += 1
	var request_generation := _generation
	_label.text = text
	visible = not text.is_empty()
	if text.is_empty():
		return
	await get_tree().create_timer(maxf(duration, 0.01)).timeout
	if request_generation == _generation:
		visible = false
