extends Node

signal ending_unlocked(ending_id: String)

var unlocked_endings: Array[String] = []


func get_available_endings() -> Array:
	var available := []
	for ending in DataManager.get_all_endings():
		if ending is Dictionary and _conditions_met(ending.get("conditions", {})):
			available.append(ending.duplicate(true))

	return available


func has_unlocked_ending(ending_id: String) -> bool:
	return unlocked_endings.has(ending_id)


func unlock_ending(ending_id: String) -> bool:
	if ending_id.is_empty() or DataManager.get_ending_by_id(ending_id).is_empty():
		return false

	if unlocked_endings.has(ending_id):
		return false

	var ending := DataManager.get_ending_by_id(ending_id)
	if not _conditions_met(ending.get("conditions", {})):
		return false

	unlocked_endings.append(ending_id)
	ending_unlocked.emit(ending_id)
	return true


func get_unlocked_endings() -> Array:
	return unlocked_endings.duplicate()


func reset_endings() -> void:
	unlocked_endings.clear()


func export_ending_data() -> Dictionary:
	return {"unlocked_endings": get_unlocked_endings()}


func import_ending_data(data: Dictionary) -> bool:
	unlocked_endings.clear()
	var values = data.get("unlocked_endings", [])
	if not (values is Array):
		return false

	var imported_cleanly := true
	for value in values:
		var ending_id := str(value)
		if ending_id.is_empty() or DataManager.get_ending_by_id(ending_id).is_empty():
			imported_cleanly = false
			continue

		if not unlocked_endings.has(ending_id):
			unlocked_endings.append(ending_id)

	return imported_cleanly


func _conditions_met(value) -> bool:
	if not (value is Dictionary):
		return false

	var chapter_id := str(value.get("completed_chapter", ""))
	if not chapter_id.is_empty() and not ChapterSystem.is_chapter_completed(chapter_id):
		return false

	if GameManager.current_night < int(value.get("min_night", 1)):
		return false

	return true
