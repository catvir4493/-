extends Node


func find_triggered_combos(selected_item_ids: Array) -> Array:
	var selected_ids: Array[String] = _unique_string_array(selected_item_ids)
	var triggered_combos: Array = []
	var triggered_combo_ids: Array[String] = []

	for combo in DataManager.get_all_combos():
		if not (combo is Dictionary):
			continue

		var combo_data: Dictionary = combo
		var combo_id := _get_combo_id(combo_data)
		if not combo_id.is_empty() and triggered_combo_ids.has(combo_id):
			continue

		var required_items: Array[String] = _get_required_items(combo_data)
		if required_items.is_empty():
			continue

		if _has_all_required_items(selected_ids, required_items):
			var combo_result := _build_combo_result(combo_data, required_items)
			triggered_combos.append(combo_result)
			if not combo_id.is_empty():
				triggered_combo_ids.append(combo_id)

	return triggered_combos


func get_combo_score_bonus(triggered_combos: Array) -> int:
	var total_bonus := 0

	for combo in triggered_combos:
		if combo is Dictionary:
			total_bonus += int(combo.get("score_bonus", 0))

	return total_bonus


func get_bonus_tags(triggered_combos: Array) -> Array:
	var bonus_tags: Array[String] = []

	for combo in triggered_combos:
		if not (combo is Dictionary):
			continue

		for tag in _to_string_array(combo.get("bonus_tags", [])):
			_append_unique(bonus_tags, tag)

	return bonus_tags


func get_combo_names(triggered_combos: Array) -> Array:
	var combo_names: Array[String] = []

	for combo in triggered_combos:
		if combo is Dictionary:
			_append_unique(combo_names, str(combo.get("name", "")))

	return combo_names


func get_special_dialogues(triggered_combos: Array) -> Array:
	var special_dialogues: Array[String] = []

	for combo in triggered_combos:
		if combo is Dictionary:
			_append_unique(special_dialogues, str(combo.get("special_dialogue", "")))

	return special_dialogues


func check_combo(selected_item_ids: Array) -> Dictionary:
	var triggered_combos := find_triggered_combos(selected_item_ids)
	if triggered_combos.is_empty():
		return {}

	return triggered_combos[0].duplicate(true)


func _build_combo_result(combo_data: Dictionary, required_items: Array[String]) -> Dictionary:
	return {
		"id": _get_combo_id(combo_data),
		"name": _get_combo_name(combo_data),
		"required_items": required_items,
		"bonus_tags": _to_string_array(combo_data.get("bonus_tags", [])),
		"score_bonus": int(combo_data.get("score_bonus", 0)),
		"special_dialogue": str(combo_data.get("special_dialogue", ""))
	}


func _get_combo_id(combo_data: Dictionary) -> String:
	var combo_id := str(combo_data.get("id", ""))
	if combo_id.is_empty():
		combo_id = str(combo_data.get("combo_id", ""))

	return combo_id


func _get_combo_name(combo_data: Dictionary) -> String:
	var combo_name := str(combo_data.get("name", ""))
	if combo_name.is_empty():
		combo_name = str(combo_data.get("combo_name", ""))

	return combo_name


func _get_required_items(combo_data: Dictionary) -> Array[String]:
	var required_items = combo_data.get("required_items", [])
	if not (required_items is Array):
		required_items = combo_data.get("required_item_ids", [])

	return _to_string_array(required_items)


func _has_all_required_items(selected_ids: Array[String], required_items: Array[String]) -> bool:
	for item_id in required_items:
		if not selected_ids.has(item_id):
			return false

	return true


func _unique_string_array(value) -> Array[String]:
	var result: Array[String] = []

	if not (value is Array):
		return result

	for entry in value:
		_append_unique(result, str(entry))

	return result


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
