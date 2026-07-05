extends Node

const RATING_TEXTS := {
	"S": "今晚的店像一个奇迹。",
	"A": "顾客们记住了这家店。",
	"B": "还算不错的一晚。",
	"C": "有些人失望地离开了。",
	"D": "这家店今晚像个错误。"
}

var night_number := 0
var customers_served := 0
var perfect_count := 0
var good_count := 0
var normal_count := 0
var fail_count := 0
var total_income := 0
var total_score := 0
var triggered_combo_count := 0
var triggered_combo_ids: Array[String] = []
var triggered_combo_names: Array[String] = []

var _recorded_service_ids: Array[String] = []


func start_night(new_night_number: int) -> void:
	night_number = maxi(new_night_number, 1)
	reset_night_stats()


func record_service_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	var service_id := _get_service_id(result)
	if not service_id.is_empty() and _recorded_service_ids.has(service_id):
		return

	if bool(result.get("service_recorded", false)):
		return

	if not service_id.is_empty():
		_recorded_service_ids.append(service_id)
		result["service_id"] = service_id

	result["service_recorded"] = true

	customers_served += 1
	total_income += int(result.get("income", 0))
	total_score += int(result.get("score", 0))
	_record_grade(str(result.get("grade", "")))
	_record_triggered_combos(result)


func get_night_summary() -> Dictionary:
	return {
		"night_number": night_number,
		"customers_served": customers_served,
		"perfect_count": perfect_count,
		"good_count": good_count,
		"normal_count": normal_count,
		"fail_count": fail_count,
		"total_income": total_income,
		"total_score": total_score,
		"average_score": get_average_score(),
		"shop_rating": get_shop_rating(),
		"shop_rating_text": get_shop_rating_text(),
		"triggered_combo_count": triggered_combo_count,
		"triggered_combo_ids": triggered_combo_ids.duplicate(),
		"triggered_combo_names": triggered_combo_names.duplicate()
	}


func export_night_stats() -> Dictionary:
	return {
		"night_number": night_number,
		"customers_served": customers_served,
		"perfect_count": perfect_count,
		"good_count": good_count,
		"normal_count": normal_count,
		"fail_count": fail_count,
		"total_income": total_income,
		"total_score": total_score,
		"triggered_combo_count": triggered_combo_count,
		"triggered_combo_ids": triggered_combo_ids.duplicate(),
		"triggered_combo_names": triggered_combo_names.duplicate()
	}


func import_night_stats(data: Dictionary) -> bool:
	night_number = maxi(_to_int(data.get("night_number", night_number), night_number), 1)
	customers_served = maxi(_to_int(data.get("customers_served", 0), 0), 0)
	perfect_count = maxi(_to_int(data.get("perfect_count", 0), 0), 0)
	good_count = maxi(_to_int(data.get("good_count", 0), 0), 0)
	normal_count = maxi(_to_int(data.get("normal_count", 0), 0), 0)
	fail_count = maxi(_to_int(data.get("fail_count", 0), 0), 0)
	total_income = maxi(_to_int(data.get("total_income", 0), 0), 0)
	total_score = maxi(_to_int(data.get("total_score", 0), 0), 0)
	triggered_combo_count = maxi(_to_int(data.get("triggered_combo_count", 0), 0), 0)
	triggered_combo_ids = _to_unique_string_array(data.get("triggered_combo_ids", []))
	triggered_combo_names = _to_unique_string_array(data.get("triggered_combo_names", []))
	_recorded_service_ids.clear()
	return true


func get_average_score() -> float:
	if customers_served <= 0:
		return 0.0

	return float(total_score) / float(customers_served)


func get_shop_rating() -> String:
	var average_score := get_average_score()

	if average_score >= 90.0:
		return "S"

	if average_score >= 75.0:
		return "A"

	if average_score >= 60.0:
		return "B"

	if average_score >= 40.0:
		return "C"

	return "D"


func get_shop_rating_text() -> String:
	return str(RATING_TEXTS.get(get_shop_rating(), RATING_TEXTS["D"]))


func reset_night_stats() -> void:
	customers_served = 0
	perfect_count = 0
	good_count = 0
	normal_count = 0
	fail_count = 0
	total_income = 0
	total_score = 0
	triggered_combo_count = 0
	triggered_combo_ids.clear()
	triggered_combo_names.clear()
	_recorded_service_ids.clear()


func _get_service_id(result: Dictionary) -> String:
	var service_id := str(result.get("service_id", ""))
	if not service_id.is_empty():
		return service_id

	var customer_id := str(result.get("customer_id", ""))
	if customer_id.is_empty():
		return ""

	return "%d:%s:%s:%s" % [
		night_number,
		customer_id,
		str(result.get("score", 0)),
		JSON.stringify(result.get("selected_item_ids", []))
	]


func _record_grade(grade: String) -> void:
	match grade:
		"perfect":
			perfect_count += 1
		"good":
			good_count += 1
		"normal":
			normal_count += 1
		"fail":
			fail_count += 1


func _record_triggered_combos(result: Dictionary) -> void:
	var triggered_combos = result.get("triggered_combos", [])
	if triggered_combos is Array and not triggered_combos.is_empty():
		for combo in triggered_combos:
			if combo is Dictionary:
				_record_combo(combo)
		return

	var combo_result = result.get("combo_result", {})
	if combo_result is Dictionary and not combo_result.is_empty():
		_record_combo(combo_result)


func _record_combo(combo: Dictionary) -> void:
	triggered_combo_count += 1
	_append_unique(triggered_combo_ids, str(combo.get("id", "")))
	_append_unique(triggered_combo_names, str(combo.get("name", "")))


func _append_unique(values: Array[String], value: String) -> void:
	if value.is_empty() or values.has(value):
		return

	values.append(value)


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value


func _to_unique_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for entry in value:
		_append_unique(result, str(entry))

	return result
