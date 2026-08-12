extends Node


func is_item_unlocked(item_id: String) -> bool:
	var item := DataManager.get_item_by_id(item_id)
	if item.is_empty():
		return false

	return int(item.get("unlock_day", 1)) <= GameManager.current_night


func is_customer_request_available(request_data: Dictionary) -> bool:
	if request_data.is_empty():
		return false

	if int(request_data.get("min_night", 1)) > GameManager.current_night:
		return false

	var story_id := str(request_data.get("story_id", ""))
	var progress := CustomerProgressSystem.get_story_progress(story_id)
	if int(request_data.get("min_visit_count", 0)) > int(progress.get("visit_count", 0)):
		return false

	var request_id := str(request_data.get("id", ""))
	if bool(request_data.get("one_time", false)) and CustomerProgressSystem.has_completed_request(request_id):
		return false

	return true


func is_combo_discoverable(combo_id: String) -> bool:
	var combo := DataManager.get_combo_by_id(combo_id)
	if combo.is_empty():
		return false

	var required_items = combo.get("required_items", combo.get("required_item_ids", []))
	if not (required_items is Array) or required_items.is_empty():
		return false

	for item_id in required_items:
		if not is_item_unlocked(str(item_id)):
			return false

	return true


func is_profile_visible(story_id: String) -> bool:
	if DataManager.get_customer_profile_by_story_id(story_id).is_empty():
		return false

	return CustomerProgressSystem.has_seen_customer(story_id)


func is_chapter_available(chapter_id: String) -> bool:
	var chapter := DataManager.get_chapter_by_id(chapter_id)
	if chapter.is_empty():
		return false

	if chapter_id == "chapter_01":
		return true

	return GameManager.current_night >= int(chapter.get("start_night", 1))
