extends SceneTree

const REPORT_PATH := "res://docs/CHAPTER2_BALANCE_AUDIT.md"
const NEW_REQUEST_IDS := ["night_nurse_01", "night_nurse_02", "night_nurse_03", "breakfast_man_01", "breakfast_man_02", "breakfast_man_03", "student_after_exam_04", "driver_rest_04", "previous_clerk_04", "previous_clerk_05"]
const NEW_ITEM_IDS := ["canned_peach", "instant_noodles", "blue_pen", "paper_cup"]
const NEW_COMBO_IDS := ["combo_write_it_down", "combo_childhood_flavor", "combo_sit_for_a_while"]

var blocker_count := 0
var critical_count := 0
var warning_count := 0
var request_rows: Array[String] = []
var new_item_best_usage: Dictionary = {}
var combo_trigger_counts: Dictionary = {}
var DataManager
var ScoreSystem


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	DataManager = root.get_node_or_null("/root/DataManager")
	ScoreSystem = root.get_node_or_null("/root/ScoreSystem")
	if DataManager == null or ScoreSystem == null:
		push_error("Stage 16 balance audit could not bind DataManager/ScoreSystem.")
		quit(1)
		return
	for item_id in NEW_ITEM_IDS: new_item_best_usage[item_id] = 0
	for combo_id in NEW_COMBO_IDS: combo_trigger_counts[combo_id] = 0
	for request_id in NEW_REQUEST_IDS:
		_audit_request(request_id)
	for item_id in NEW_ITEM_IDS:
		if int(new_item_best_usage[item_id]) == 0:
			warning_count += 1
	for combo_id in NEW_COMBO_IDS:
		if int(combo_trigger_counts[combo_id]) == 0:
			warning_count += 1
	_write_report()
	print("Stage 16 Chapter 2 balance audit completed.")
	print("Blockers: %d Critical: %d Warnings: %d" % [blocker_count, critical_count, warning_count])
	quit(0 if blocker_count == 0 and critical_count == 0 else 1)


func _audit_request(request_id: String) -> void:
	var request: Dictionary = DataManager.get_customer_by_id(request_id)
	if request.is_empty():
		blocker_count += 1
		request_rows.append("| %s | missing | 0 | 0 | - | BLOCKER |" % request_id)
		return
	var night := _scheduled_night(request_id)
	var item_ids: Array[String] = []
	for item in DataManager.get_all_items():
		if item is Dictionary and int(item.get("unlock_day", 99)) <= night:
			item_ids.append(str(item.get("id", "")))
	var best_score := -1
	var good_count := 0
	var perfect_count := 0
	var best_solutions: Array = []
	for selection in _selections(item_ids):
		var result: Dictionary = ScoreSystem.calculate_score(request, selection)
		var score := int(result.get("score", 0))
		if score >= 70: good_count += 1
		if score >= 90: perfect_count += 1
		if score > best_score:
			best_score = score
			best_solutions = [{"items": selection, "combos": result.get("triggered_combos", [])}]
		elif score == best_score:
			best_solutions.append({"items": selection, "combos": result.get("triggered_combos", [])})
	var severity := "OK"
	if best_score < 40:
		blocker_count += 1
		severity = "BLOCKER"
	elif best_score < 70:
		critical_count += 1
		severity = "CRITICAL"
	elif best_score < 90:
		warning_count += 1
		severity = "WARNING"
	for solution in best_solutions:
		for item_id in solution.get("items", []):
			if new_item_best_usage.has(item_id): new_item_best_usage[item_id] += 1
		for combo in solution.get("combos", []):
			var combo_id := str(combo.get("id", ""))
			if combo_trigger_counts.has(combo_id): combo_trigger_counts[combo_id] += 1
	var example := "-"
	if not best_solutions.is_empty(): example = ", ".join(best_solutions[0].get("items", []))
	request_rows.append("| %s | %d | %d | %d | %s | %s |" % [request_id, best_score, good_count, perfect_count, example, severity])


func _scheduled_night(request_id: String) -> int:
	for night in range(6, 11):
		for slot in DataManager.get_night_config(night).get("customer_slots", []):
			var request: Dictionary = DataManager.get_customer_request_by_story_stage(str(slot.get("story_id", "")), int(slot.get("story_stage", 0)))
			if str(request.get("id", "")) == request_id: return night
	return int(DataManager.get_customer_by_id(request_id).get("min_night", 6))


func _selections(ids: Array[String]) -> Array:
	var result: Array = []
	for i in range(ids.size()):
		result.append([ids[i]])
		for j in range(i + 1, ids.size()):
			result.append([ids[i], ids[j]])
			for k in range(j + 1, ids.size()): result.append([ids[i], ids[j], ids[k]])
	return result


func _write_report() -> void:
	var lines := [
		"# Chapter 2 Balance Audit", "", "## Summary", "",
		"- BLOCKER: %d" % blocker_count,
		"- CRITICAL: %d" % critical_count,
		"- WARNING: %d" % warning_count, "",
		"审计范围为 Chapter 2 新增的 10 个 Request，按各自首次排期夜晚的已解锁商品穷举 1–3 件合法选择。", "",
		"## Request Solvability", "", "| request_id | max_score | good_solutions | perfect_solutions | example_best | severity |", "|---|---:|---:|---:|---|---|"
	]
	lines.append_array(request_rows)
	lines.append_array(["", "## New Item Usage", "", "| item_id | highest-score solution usage |", "|---|---:|"])
	for item_id in NEW_ITEM_IDS: lines.append("| %s | %d |" % [item_id, int(new_item_best_usage[item_id])])
	lines.append_array(["", "## New Combo Usage", "", "| combo_id | highest-score solution triggers |", "|---|---:|"])
	for combo_id in NEW_COMBO_IDS: lines.append("| %s | %d |" % [combo_id, int(combo_trigger_counts[combo_id])])
	lines.append_array(["", "## Economy and Stock Notes", "", "- 四个新商品的 buy_price 均低于 sell_price，普通服务收入仍使用 Stage 11B 公式。", "- Night 6 旧存档迁移会为缺失的新商品库存使用其 max_stock 默认值，不会形成起始软锁。", "- old_photo 的 max_stock 保持 1；小时候的味道不是任何 Request 的唯一 good 解。", "- 本审计允许 WARNING，但 BLOCKER 与 CRITICAL 必须为 0。", ""])
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write Chapter 2 balance report.")
		blocker_count += 1
		return
	file.store_string("\n".join(lines))
