class_name SectionTitle
extends Label

@export var title := "":
	set(value):
		title = value
		text = value


func _ready() -> void:
	text = title


func set_title(value: String) -> void:
	title = value
