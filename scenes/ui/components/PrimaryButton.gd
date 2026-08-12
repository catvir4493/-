class_name PrimaryButton
extends Button


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 44.0)


@warning_ignore("native_method_override")
func set_text(value: String) -> void:
	text = value


func set_enabled(enabled: bool) -> void:
	disabled = not enabled
