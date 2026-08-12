extends Node

signal story_event_triggered(event_data: Dictionary)

var triggered_event_ids: Array[String] = []
var _last_triggered_events: Array[Dictionary] = []


func get_triggered_event_ids() -> Array:
	return triggered_event_ids.duplicate()


func has_triggered_event(event_id: String) -> bool:
	return triggered_event_ids.has(event_id)


func get_last_triggered_events() -> Array:
	return _last_triggered_events.duplicate(true)


func mark_event_triggered(event_id: String) -> bool:
	if event_id.is_empty() or DataManager.get_story_event_by_id(event_id).is_empty():
		return false

	if triggered_event_ids.has(event_id):
		return false

	triggered_event_ids.append(event_id)
	return true


func get_available_events(context: Dictionary) -> Array:
	var available := []
	_last_triggered_events.clear()
	for event in DataManager.get_all_story_events():
		if not (event is Dictionary) or not _matches_context(event, context):
			continue

		var event_id := str(event.get("id", ""))
		if bool(event.get("one_time", false)) and has_triggered_event(event_id):
			continue

		available.append(event.duplicate(true))
		_last_triggered_events.append(event.duplicate(true))
		if bool(event.get("one_time", false)):
			mark_event_triggered(event_id)

		print("Story event triggered: %s" % event_id)
		story_event_triggered.emit(event.duplicate(true))

	return available


func reset_events() -> void:
	triggered_event_ids.clear()
	_last_triggered_events.clear()


func export_event_data() -> Dictionary:
	return {"triggered_story_events": get_triggered_event_ids()}


func import_event_data(data: Dictionary) -> bool:
	triggered_event_ids.clear()
	_last_triggered_events.clear()
	var values = data.get("triggered_story_events", data.get("triggered_event_ids", []))
	if not (values is Array):
		return false

	var imported_cleanly := true
	for value in values:
		var event_id := str(value)
		if event_id.is_empty() or DataManager.get_story_event_by_id(event_id).is_empty():
			imported_cleanly = false
			continue

		if not triggered_event_ids.has(event_id):
			triggered_event_ids.append(event_id)

	return imported_cleanly


func _matches_context(event: Dictionary, context: Dictionary) -> bool:
	if context.is_empty() or not _type_matches(str(event.get("type", "")), str(context.get("type", ""))):
		return false

	var trigger = event.get("trigger", {})
	if not (trigger is Dictionary):
		return false

	for key in trigger.keys():
		if not context.has(key) or not _values_match(context.get(key), trigger.get(key)):
			return false

	return true


func _type_matches(event_type: String, context_type: String) -> bool:
	if event_type == context_type:
		return true

	return (
		(context_type == "night_start" and event_type == "chapter_start")
		or (context_type == "customer_result" and event_type == "special_customer")
		or (context_type == "night_result" and event_type == "chapter_complete")
	)


func _values_match(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)

	return str(left) == str(right)
