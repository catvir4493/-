extends Node

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, message: String)

const Config = preload("res://scripts/config/GameConfig.gd")

var fade_duration := Config.DEFAULT_FADE_DURATION
var _transitioning := false
var _canvas_layer: CanvasLayer
var _fade_rect: ColorRect
var _report_errors := true


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "TransitionLayer"
	_canvas_layer.layer = 1000
	add_child(_canvas_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.visible = false
	_canvas_layer.add_child(_fade_rect)


func change_scene(scene_path: String) -> bool:
	if _transitioning:
		return false
	if scene_path.is_empty():
		return _fail_transition(scene_path, "Scene path is empty.")
	if not ResourceLoader.exists(scene_path):
		return _fail_transition(scene_path, "Scene file does not exist: %s." % scene_path)

	_transitioning = true
	transition_started.emit(scene_path)
	if DisplayServer.get_name() == "headless" or fade_duration <= 0.0:
		return _change_scene_now(scene_path)

	_perform_fade_transition(scene_path)
	return true


func reload_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path.is_empty():
		return _fail_transition("", "Current scene has no reloadable scene path.")
	return change_scene(current_scene.scene_file_path)


func is_transitioning() -> bool:
	return _transitioning


func set_error_reporting_enabled_for_testing(enabled: bool) -> void:
	if OS.is_debug_build():
		_report_errors = enabled


func _perform_fade_transition(scene_path: String) -> void:
	_fade_rect.visible = true
	_fade_rect.color.a = 0.0
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	await fade_out.finished

	if not _change_scene_file(scene_path):
		return

	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, fade_duration)
	await fade_in.finished
	_fade_rect.visible = false
	_transitioning = false
	transition_finished.emit(scene_path)


func _change_scene_now(scene_path: String) -> bool:
	if not _change_scene_file(scene_path):
		return false
	_transitioning = false
	transition_finished.emit(scene_path)
	return true


func _change_scene_file(scene_path: String) -> bool:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_fail_transition(scene_path, "Could not change scene. Error code: %s." % error)
		return false
	return true


func _fail_transition(scene_path: String, message: String) -> bool:
	_transitioning = false
	if _fade_rect != null:
		_fade_rect.visible = false
		_fade_rect.color.a = 0.0
	if _report_errors:
		push_error(message)
	transition_failed.emit(scene_path, message)
	return false
