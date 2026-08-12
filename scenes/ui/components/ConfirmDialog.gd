class_name MidnightConfirmDialog
extends Control

signal confirmed
signal cancelled

@onready var _title_label: Label = %Title
@onready var _message_label: Label = %Message
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	visible = false
	_confirm_button.pressed.connect(_on_confirmed)
	_cancel_button.pressed.connect(_on_cancelled)


func open(title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消") -> void:
	_title_label.text = title
	_message_label.text = message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	visible = true
	_confirm_button.grab_focus()


func _on_confirmed() -> void:
	visible = false
	confirmed.emit()


func _on_cancelled() -> void:
	visible = false
	cancelled.emit()
