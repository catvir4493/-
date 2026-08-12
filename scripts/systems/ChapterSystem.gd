extends Node

signal chapter_completed(chapter_id: String)

var completed_chapters: Array[String] = []


func get_current_chapter() -> Dictionary:
	return get_chapter_for_night(GameManager.current_night)


func get_chapter_for_night(night_number: int) -> Dictionary:
	return DataManager.get_chapter_for_night(night_number)


func is_chapter_started(chapter_id: String) -> bool:
	var chapter := DataManager.get_chapter_by_id(chapter_id)
	if chapter.is_empty():
		return false

	return (
		GameManager.current_night >= int(chapter.get("start_night", 1))
		or is_chapter_completed(chapter_id)
	)


func is_chapter_completed(chapter_id: String) -> bool:
	return completed_chapters.has(chapter_id)


func mark_chapter_completed(chapter_id: String) -> bool:
	if chapter_id.is_empty() or DataManager.get_chapter_by_id(chapter_id).is_empty():
		return false

	if completed_chapters.has(chapter_id):
		return false

	completed_chapters.append(chapter_id)
	chapter_completed.emit(chapter_id)
	return true


func get_completed_chapters() -> Array:
	return completed_chapters.duplicate()


func reset_chapter_progress() -> void:
	completed_chapters.clear()


func export_chapter_data() -> Dictionary:
	return {"completed_chapters": get_completed_chapters()}


func import_chapter_data(data: Dictionary) -> bool:
	completed_chapters.clear()
	var values = data.get("completed_chapters", [])
	if not (values is Array):
		return false

	var imported_cleanly := true
	for value in values:
		var chapter_id := str(value)
		if chapter_id.is_empty() or DataManager.get_chapter_by_id(chapter_id).is_empty():
			imported_cleanly = false
			continue

		if not completed_chapters.has(chapter_id):
			completed_chapters.append(chapter_id)

	return imported_cleanly
