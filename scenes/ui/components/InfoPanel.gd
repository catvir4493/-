class_name InfoPanel
extends PanelContainer

@export var title := "":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value
@export_multiline var content := "":
	set(value):
		content = value
		if _content_label != null:
			_content_label.text = value

var _title_label: Label
var _content_label: Label


func _ready() -> void:
	_resolve_nodes()
	_title_label.text = title
	_content_label.text = content
	_title_label.visible = not title.is_empty()


func set_title(value: String) -> void:
	title = value
	_resolve_nodes()
	_title_label.visible = not value.is_empty()


func set_content(value: String) -> void:
	content = value


func get_title_label() -> Label:
	_resolve_nodes()
	return _title_label


func get_content_label() -> Label:
	_resolve_nodes()
	return _content_label


func _resolve_nodes() -> void:
	if _title_label == null:
		_title_label = get_node("Margin/Layout/Title") as Label
	if _content_label == null:
		_content_label = get_node("Margin/Layout/ContentScroll/Content") as Label
