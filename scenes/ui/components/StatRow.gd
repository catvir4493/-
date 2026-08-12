class_name StatRow
extends HBoxContainer

@export var label_text := "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value
@export var value_text := "":
	set(value):
		value_text = value
		if _value != null:
			_value.text = value

@onready var _label: Label = %Label
@onready var _value: Label = %Value


func _ready() -> void:
	_label.text = label_text
	_value.text = value_text


func setup(label_value: String, stat_value: String) -> void:
	label_text = label_value
	value_text = stat_value
