class_name BaseScreen
extends Control

const Tokens = preload("res://scripts/ui/UIDesignTokens.gd")
const ToastMessageScene = preload("res://scenes/ui/components/ToastMessage.tscn")

var _active_actions: Dictionary = {}
var _toast_message: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tree := Engine.get_main_loop() as SceneTree
	var theme_manager := tree.root.get_node_or_null("UIThemeManager") if tree != null else null
	if theme_manager != null:
		theme_manager.apply_theme(self)


func create_page_root(parent: Control = self) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "PageRoot"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Tokens.SPACE_XL)
	margin.add_theme_constant_override("margin_top", Tokens.SPACE_LG)
	margin.add_theme_constant_override("margin_right", Tokens.SPACE_XL)
	margin.add_theme_constant_override("margin_bottom", Tokens.SPACE_LG)
	parent.add_child(margin)
	return margin


func begin_ui_action(action_id: String) -> bool:
	if action_id.is_empty() or _active_actions.has(action_id):
		return false
	_active_actions[action_id] = true
	return true


func end_ui_action(action_id: String) -> void:
	_active_actions.erase(action_id)


func is_ui_action_active(action_id: String) -> bool:
	return _active_actions.has(action_id)


func show_message(text: String, duration: float = 2.0) -> void:
	if _toast_message == null or not is_instance_valid(_toast_message):
		_toast_message = ToastMessageScene.instantiate()
		add_child(_toast_message)
	_toast_message.show_message(text, duration)
