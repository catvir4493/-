extends Node

const REQUIRED_TAG_SCORE := 20
const AVOID_TAG_SCORE := -20
const ITEM_SCORE := 5
const COMBO_SCORE := 0


func calculate_score(customer_data: Dictionary, selected_item_ids: Array) -> Dictionary:
	var selected_items: Array[Dictionary] = []
	var selected_item_names: Array[String] = []
	var selected_tags: Array[String] = []
	var normalized_item_ids: Array[String] = []
	var item_sell_total := 0

	for value in selected_item_ids:
		var item_id := str(value)
		if item_id.is_empty():
			continue

		normalized_item_ids.append(item_id)
		var item: Dictionary = DataManager.get_item_by_id(item_id)
		if item.is_empty():
			continue

		selected_items.append(item)
		selected_item_names.append(str(item.get("name", item_id)))
		item_sell_total += int(item.get("sell_price", 0))

		var tags = item.get("tags", [])
		if tags is Array:
			for tag in tags:
				selected_tags.append(str(tag))

	var required_tags: Array[String] = _to_string_array(customer_data.get("required_tags", []))
	var avoid_tags: Array[String] = _to_string_array(customer_data.get("avoid_tags", []))
	var matched_tags: Array[String] = []
	var bad_tags: Array[String] = []
	var missing_tags: Array[String] = []
	var score := selected_items.size() * ITEM_SCORE

	for tag in required_tags:
		if selected_tags.has(tag):
			score += REQUIRED_TAG_SCORE
			_append_unique(matched_tags, tag)
		else:
			missing_tags.append(tag)

	for tag in selected_tags:
		if avoid_tags.has(tag):
			score += AVOID_TAG_SCORE
			_append_unique(bad_tags, tag)

	score += COMBO_SCORE
	score = clampi(score, 0, 100)

	var grade := _get_grade(score)
	var income := _calculate_income(item_sell_total, int(customer_data.get("base_reward", 0)), grade)

	return {
		"score": score,
		"grade": grade,
		"matched_tags": matched_tags,
		"bad_tags": bad_tags,
		"missing_tags": missing_tags,
		"selected_item_ids": normalized_item_ids,
		"selected_item_names": selected_item_names,
		"customer_id": str(customer_data.get("id", "")),
		"customer_name": str(customer_data.get("customer_name", "")),
		"customer_dialogue": str(customer_data.get("dialogue", "")),
		"income": income,
		"customer_feedback": _get_customer_feedback(grade)
	}


func _get_grade(score: int) -> String:
	if score >= 90:
		return "perfect"

	if score >= 70:
		return "good"

	if score >= 40:
		return "normal"

	return "fail"


func _calculate_income(item_sell_total: int, base_reward: int, grade: String) -> int:
	var grade_bonus := 0

	match grade:
		"perfect":
			grade_bonus = 10
		"good":
			grade_bonus = 5
		"fail":
			grade_bonus = -2

	return maxi(0, item_sell_total + base_reward + grade_bonus)


func _get_customer_feedback(grade: String) -> String:
	match grade:
		"perfect":
			return "谢谢。我好像知道该怎么做了。"
		"good":
			return "这应该有用。至少今晚有用。"
		"normal":
			return "也许吧……我会试试。"
		"fail":
			return "你根本没听懂我在说什么。"

	return "也许吧……我会试试。"


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []

	if not (value is Array):
		return result

	for entry in value:
		var text := str(entry)
		if not text.is_empty():
			result.append(text)

	return result


func _append_unique(values: Array[String], value: String) -> void:
	if value.is_empty() or values.has(value):
		return

	values.append(value)
