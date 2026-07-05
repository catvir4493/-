extends SceneTree

const REPORT_PATH := "res://docs/BALANCE_AUDIT.md"
const AUDITED_NIGHTS := [1, 2, 3, 4, 5]
const GOOD_SCORE := 70
const NORMAL_SCORE := 40
const PERFECT_SCORE := 90
const DOMINANT_BEST_USAGE_THRESHOLD := 15
const DEFAULT_START_MONEY := 0

var items_by_id := {}
var customers_by_id := {}
var combos_by_id := {}
var schedule_entries := []
var solutions_by_request_id := {}
var customer_audits := {}
var item_usage := {}
var combo_audits := {}
var unlock_audits := {}
var difficulty_audits := {}
var economy_audits := {}
var findings := {
	"BLOCKER": [],
	"CRITICAL": [],
	"WARNING": [],
	"INFO": []
}
var generated_report_path := REPORT_PATH
var _data_manager
var _customer_system
var _score_system
var _inventory_system


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	if not _bind_autoloads():
		quit(1)
		return

	if not _data_manager.is_loaded():
		_data_manager.load_all_data()

	_build_indexes()
	_collect_schedule()
	_audit_customer_solvability()
	_audit_item_usage()
	_audit_combo_balance()
	_audit_unlock_progression()
	_audit_difficulty_curve()
	_audit_economy_simulation()
	_write_report()

	print("Stage 11 balance audit completed.")
	print("Report written to res://docs/BALANCE_AUDIT.md")
	print("Blockers: %d Critical: %d Warnings: %d Info: %d" % [
		findings["BLOCKER"].size(),
		findings["CRITICAL"].size(),
		findings["WARNING"].size(),
		findings["INFO"].size()
	])

	if not findings["BLOCKER"].is_empty():
		push_error("Stage 11 balance audit found %d blocker(s)." % findings["BLOCKER"].size())
		quit(1)
		return

	quit()


func _bind_autoloads() -> bool:
	var root := get_root()
	_data_manager = root.get_node_or_null("DataManager")
	_customer_system = root.get_node_or_null("CustomerSystem")
	_score_system = root.get_node_or_null("ScoreSystem")
	_inventory_system = root.get_node_or_null("InventorySystem")

	var missing := []
	if _data_manager == null:
		missing.append("DataManager")
	if _customer_system == null:
		missing.append("CustomerSystem")
	if _score_system == null:
		missing.append("ScoreSystem")
	if _inventory_system == null:
		missing.append("InventorySystem")

	if missing.is_empty():
		return true

	push_error("Stage 11 audit could not bind autoloads: %s." % _join_ids(missing))
	return false


func _build_indexes() -> void:
	for item in _data_manager.get_all_items():
		if not (item is Dictionary):
			continue

		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue

		items_by_id[item_id] = item.duplicate(true)
		item_usage[item_id] = {
			"item_id": item_id,
			"unlock_day": _to_int(item.get("unlock_day", 1), 1),
			"good_solution_usage": 0,
			"best_solution_usage": 0,
			"combo_count": 0,
			"unlock_night_good_usage": 0,
			"avoid_hit_count": 0,
			"single_score_total": 0,
			"single_score_count": 0,
			"average_single_item_score": 0.0,
			"classification": "Normal",
			"notes": []
		}

	for customer in _data_manager.get_all_customers():
		if not (customer is Dictionary):
			continue

		var request_id := str(customer.get("id", ""))
		if not request_id.is_empty():
			customers_by_id[request_id] = customer.duplicate(true)

	for combo in _data_manager.get_all_combos():
		if not (combo is Dictionary):
			continue

		var combo_id := _get_combo_id(combo)
		if combo_id.is_empty():
			continue

		combos_by_id[combo_id] = combo.duplicate(true)
		for item_id in _get_combo_required_items(combo):
			if item_usage.has(item_id):
				item_usage[item_id]["combo_count"] = int(item_usage[item_id]["combo_count"]) + 1


func _collect_schedule() -> void:
	schedule_entries.clear()

	for night in AUDITED_NIGHTS:
		var night_config: Dictionary = _data_manager.get_night_config(night)
		if night_config.is_empty():
			_add_finding("BLOCKER", "data/nights.json", "night_%d", "Night %d config is missing." % night)
			continue

		var resolved_by_customer_system: Array = _customer_system.resolve_night_customer_slots(night_config)
		var slots = night_config.get("customer_slots", [])
		if not (slots is Array):
			_add_finding("BLOCKER", "data/nights.json", "night_%d", "Night %d customer_slots is not an Array." % night)
			continue

		if resolved_by_customer_system.size() != slots.size():
			_add_finding("CRITICAL", "data/nights.json", "night_%d", "Night %d resolved %d of %d slots." % [
				night,
				resolved_by_customer_system.size(),
				slots.size()
			])

		for slot_index in range(slots.size()):
			var slot = slots[slot_index]
			if not (slot is Dictionary):
				_add_finding("BLOCKER", "data/nights.json", "night_%d_slot_%d" % [night, slot_index + 1], "Slot is not a Dictionary.")
				continue

			var story_id := str(slot.get("story_id", ""))
			var story_stage := _to_int(slot.get("story_stage", 0), 0)
			var request: Dictionary = _data_manager.get_customer_request_by_story_stage(story_id, story_stage)
			if request.is_empty():
				_add_finding(
					"BLOCKER",
					"data/nights.json",
					"night_%d_slot_%d" % [night, slot_index + 1],
					"Missing request for story_id=%s story_stage=%d." % [story_id, story_stage]
				)
				continue

			var request_id := str(request.get("id", ""))
			schedule_entries.append({
				"night": night,
				"slot_index": slot_index + 1,
				"story_id": story_id,
				"story_stage": story_stage,
				"request_id": request_id,
				"request": request.duplicate(true)
			})

			var min_night := _to_int(request.get("min_night", 1), 1)
			if min_night > night:
				_add_finding(
					"CRITICAL",
					"data/customers.json",
					request_id,
					"Request is scheduled on night %d but min_night is %d." % [night, min_night]
				)

	if schedule_entries.size() != customers_by_id.size():
		_add_finding(
			"CRITICAL",
			"data/nights.json",
			"five_night_schedule",
			"Schedule contains %d entries but customers.json contains %d requests." % [schedule_entries.size(), customers_by_id.size()]
		)


func _audit_customer_solvability() -> void:
	for entry in schedule_entries:
		var night := _to_int(entry.get("night", 1), 1)
		var request_id := str(entry.get("request_id", ""))
		var request: Dictionary = entry.get("request", {})
		var available_item_ids := _get_unlocked_item_ids(night)
		var item_combinations := _generate_item_combinations(available_item_ids)
		var solutions := []
		var best_solution := {}
		var worst_solution := {}
		var max_score := -1
		var min_score := 101
		var good_solution_count := 0
		var perfect_solution_count := 0
		var normal_solution_count := 0
		var combo_solution_count := 0
		var non_combo_good_count := 0

		for item_ids in item_combinations:
			var result: Dictionary = _score_system.calculate_score(request, item_ids)
			var solution := _make_solution(request_id, night, item_ids, result)
			solutions.append(solution)

			var score := int(solution.get("score", 0))
			max_score = maxi(max_score, score)
			min_score = mini(min_score, score)

			if score >= NORMAL_SCORE:
				normal_solution_count += 1
			if score >= GOOD_SCORE:
				good_solution_count += 1
				if _to_string_array(solution.get("triggered_combo_ids", [])).is_empty():
					non_combo_good_count += 1
			if score >= PERFECT_SCORE:
				perfect_solution_count += 1

			if not _to_string_array(solution.get("triggered_combo_ids", [])).is_empty():
				combo_solution_count += 1

			if _is_better_best_solution(solution, best_solution):
				best_solution = solution
			if worst_solution.is_empty() or score < int(worst_solution.get("score", 0)):
				worst_solution = solution

		var combo_required := good_solution_count > 0 and non_combo_good_count == 0
		var severity := _classify_customer_severity(max_score, good_solution_count)
		var notes := []
		if max_score < GOOD_SCORE:
			notes.append("No legal good solution with currently unlocked items.")
		if combo_required:
			notes.append("Good result requires a special combo.")
		if good_solution_count == 1:
			notes.append("Only one good-or-better solution.")
		if normal_solution_count == 0:
			notes.append("No normal-or-better solution.")

		customer_audits[request_id] = {
			"night": night,
			"slot_index": _to_int(entry.get("slot_index", 0), 0),
			"request_id": request_id,
			"customer_name": str(request.get("customer_name", "")),
			"story_id": str(request.get("story_id", "")),
			"story_stage": _to_int(request.get("story_stage", 1), 1),
			"difficulty": _to_int(request.get("difficulty", 1), 1),
			"max_score": max_score,
			"min_score": min_score,
			"good_solution_count": good_solution_count,
			"perfect_solution_count": perfect_solution_count,
			"normal_solution_count": normal_solution_count,
			"combo_solution_count": combo_solution_count,
			"best_solution": best_solution,
			"worst_solution": worst_solution,
			"combo_required": combo_required,
			"severity": severity,
			"notes": notes
		}
		solutions_by_request_id[request_id] = solutions

		match severity:
			"BLOCKER":
				_add_finding("BLOCKER", "data/customers.json", request_id, "Highest score is %d, below normal." % max_score)
			"CRITICAL":
				_add_finding("CRITICAL", "data/customers.json", request_id, "Highest score is %d, below good." % max_score)
			"WARNING":
				_add_finding("WARNING", "data/customers.json", request_id, "Only one good-or-better solution.")
			_:
				_add_finding("INFO", "data/customers.json", request_id, "Multiple reasonable solutions are available.")


func _audit_item_usage() -> void:
	for entry in schedule_entries:
		var night := _to_int(entry.get("night", 1), 1)
		var request_id := str(entry.get("request_id", ""))
		var request: Dictionary = entry.get("request", {})
		var solutions: Array = solutions_by_request_id.get(request_id, [])
		var good_items_for_customer := []
		var best_solution: Dictionary = customer_audits.get(request_id, {}).get("best_solution", {})

		for solution in solutions:
			if int(solution.get("score", 0)) < GOOD_SCORE:
				continue

			for item_id in _to_string_array(solution.get("item_ids", [])):
				_append_unique(good_items_for_customer, item_id)

		for item_id in good_items_for_customer:
			if not item_usage.has(item_id):
				continue

			item_usage[item_id]["good_solution_usage"] = int(item_usage[item_id]["good_solution_usage"]) + 1
			if _to_int(item_usage[item_id].get("unlock_day", 1), 1) == night:
				item_usage[item_id]["unlock_night_good_usage"] = int(item_usage[item_id]["unlock_night_good_usage"]) + 1

		for item_id in _to_string_array(best_solution.get("item_ids", [])):
			if item_usage.has(item_id):
				item_usage[item_id]["best_solution_usage"] = int(item_usage[item_id]["best_solution_usage"]) + 1

		var avoid_tags := _to_string_array(request.get("avoid_tags", []))
		for item_id in _get_unlocked_item_ids(night):
			var item: Dictionary = items_by_id.get(item_id, {})
			var item_tags := _to_string_array(item.get("tags", []))
			if _has_any_overlap(item_tags, avoid_tags):
				item_usage[item_id]["avoid_hit_count"] = int(item_usage[item_id]["avoid_hit_count"]) + 1

			var single_result: Dictionary = _score_system.calculate_score(request, [item_id])
			item_usage[item_id]["single_score_total"] = int(item_usage[item_id]["single_score_total"]) + int(single_result.get("score", 0))
			item_usage[item_id]["single_score_count"] = int(item_usage[item_id]["single_score_count"]) + 1

	for item_id in item_usage.keys():
		var usage: Dictionary = item_usage[item_id]
		var score_count := int(usage.get("single_score_count", 0))
		if score_count > 0:
			usage["average_single_item_score"] = float(int(usage.get("single_score_total", 0))) / float(score_count)

		var notes := []
		var classification := "Normal"
		var best_usage := int(usage.get("best_solution_usage", 0))
		var good_usage := int(usage.get("good_solution_usage", 0))
		var combo_count := int(usage.get("combo_count", 0))
		var unlock_night_usage := int(usage.get("unlock_night_good_usage", 0))

		if best_usage > DOMINANT_BEST_USAGE_THRESHOLD:
			classification = "Dominant Item"
			notes.append("Appears in more than 50% of deterministic best solutions.")
			_add_finding("WARNING", "data/items.json", item_id, "Dominant item candidate: used in %d best solutions." % best_usage)
		elif good_usage == 0 and combo_count == 0 and unlock_night_usage == 0:
			classification = "Underused Item"
			notes.append("No good/perfect solution usage and no combo membership.")
			_add_finding("WARNING", "data/items.json", item_id, "Underused item candidate.")
		elif good_usage == 0:
			classification = "Low Usage"
			notes.append("Not used by any good/perfect solution, but has combo or unlock context.")
		elif int(usage.get("avoid_hit_count", 0)) >= 10:
			notes.append("Frequently overlaps customer avoid tags.")

		usage["classification"] = classification
		usage["notes"] = notes
		item_usage[item_id] = usage


func _audit_combo_balance() -> void:
	for combo_id in combos_by_id.keys():
		var combo: Dictionary = combos_by_id[combo_id]
		var required_items := _get_combo_required_items(combo)
		var missing_items := []
		var earliest_night := 1
		for item_id in required_items:
			if not items_by_id.has(item_id):
				missing_items.append(item_id)
				continue

			var item: Dictionary = items_by_id[item_id]
			earliest_night = maxi(earliest_night, _to_int(item.get("unlock_day", 1), 1))

		var audit := {
			"combo_id": combo_id,
			"earliest_available_night": earliest_night,
			"required_items": required_items,
			"missing_items": missing_items,
			"suitable_customer_ids": [],
			"triggered_solution_count": 0,
			"max_score_with_combo": -1,
			"max_score_without_combo": -1,
			"bonus_tag_effect_count": 0,
			"multi_combo_solution_count": 0,
			"max_multi_combo_score": 0,
			"classification": "Normal",
			"notes": []
		}
		combo_audits[combo_id] = audit

	for entry in schedule_entries:
		var request_id := str(entry.get("request_id", ""))
		for solution in solutions_by_request_id.get(request_id, []):
			var triggered_ids := _to_string_array(solution.get("triggered_combo_ids", []))
			for combo_id in combos_by_id.keys():
				var audit: Dictionary = combo_audits[combo_id]
				if triggered_ids.has(combo_id):
					audit["triggered_solution_count"] = int(audit["triggered_solution_count"]) + 1
					audit["max_score_with_combo"] = maxi(int(audit["max_score_with_combo"]), int(solution.get("score", 0)))
					if int(solution.get("score", 0)) >= GOOD_SCORE:
						_append_unique(audit["suitable_customer_ids"], request_id)
					if _has_any_overlap(_to_string_array(solution.get("matched_tags", [])), _to_string_array(solution.get("combo_bonus_tags", []))):
						audit["bonus_tag_effect_count"] = int(audit["bonus_tag_effect_count"]) + 1
					if triggered_ids.size() > 1:
						audit["multi_combo_solution_count"] = int(audit["multi_combo_solution_count"]) + 1
						audit["max_multi_combo_score"] = maxi(int(audit["max_multi_combo_score"]), int(solution.get("score", 0)))
				else:
					audit["max_score_without_combo"] = maxi(int(audit["max_score_without_combo"]), int(solution.get("score", 0)))

				combo_audits[combo_id] = audit

	for combo_id in combo_audits.keys():
		var audit: Dictionary = combo_audits[combo_id]
		var notes := []
		var classification := "Normal"
		var max_with := int(audit.get("max_score_with_combo", -1))
		var max_without := int(audit.get("max_score_without_combo", -1))
		var suitable_count := _to_string_array(audit.get("suitable_customer_ids", [])).size()

		if not _to_string_array(audit.get("missing_items", [])).is_empty():
			classification = "Invalid Reference"
			notes.append("Missing required item ids: %s." % _join_ids(audit.get("missing_items", [])))
			_add_finding("CRITICAL", "data/combos.json", combo_id, "Combo references missing item ids.")
		elif int(audit.get("earliest_available_night", 1)) > 5:
			classification = "Unavailable In MVP"
			notes.append("Required items unlock after the five-night MVP.")
			_add_finding("WARNING", "data/combos.json", combo_id, "Combo cannot be triggered during the five-night MVP.")
		elif int(audit.get("triggered_solution_count", 0)) == 0:
			classification = "Never Triggered"
			notes.append("No legal audited solution triggers this combo.")
			_add_finding("WARNING", "data/combos.json", combo_id, "Combo is never triggered in audited solutions.")
		elif suitable_count == 0:
			classification = "No Good Use"
			notes.append("Triggered, but no good-or-better solution uses it.")
			_add_finding("WARNING", "data/combos.json", combo_id, "Combo never helps reach good.")
		elif max_with >= 100 and max_without >= GOOD_SCORE:
			notes.append("Can hit the score cap while non-combo solutions are already viable.")

		if int(audit.get("bonus_tag_effect_count", 0)) == 0 and int(audit.get("triggered_solution_count", 0)) > 0:
			notes.append("Bonus tags did not appear in matched_tags during audited solutions.")

		if int(audit.get("multi_combo_solution_count", 0)) > 0:
			notes.append("Can be part of multi-combo three-item selections; max multi-combo score %d." % int(audit.get("max_multi_combo_score", 0)))

		var overlaps := _find_combo_bonus_overlaps(combo_id)
		if not overlaps.is_empty():
			notes.append("Bonus tags overlap with: %s." % _join_ids(overlaps))

		if max_with >= 0 and max_without >= 0 and max_with < max_without:
			notes.append("Best score with this combo is lower than the best score without it.")

		audit["classification"] = classification
		audit["notes"] = notes
		combo_audits[combo_id] = audit


func _audit_unlock_progression() -> void:
	for night in AUDITED_NIGHTS:
		var unlocked_item_ids := _get_unlocked_item_ids(night)
		var newly_unlocked_item_ids := _get_newly_unlocked_item_ids(night)
		var available_combo_ids := []
		var customer_count := 0
		var solvable_customer_count := 0
		var critical_customer_ids := []
		var notes := []

		for combo_id in combo_audits.keys():
			var audit: Dictionary = combo_audits[combo_id]
			if int(audit.get("earliest_available_night", 99)) <= night:
				available_combo_ids.append(combo_id)

		for entry in schedule_entries:
			if _to_int(entry.get("night", 0), 0) != night:
				continue

			customer_count += 1
			var request_id := str(entry.get("request_id", ""))
			var customer_audit: Dictionary = customer_audits.get(request_id, {})
			var max_score := int(customer_audit.get("max_score", 0))
			if max_score >= GOOD_SCORE:
				solvable_customer_count += 1
			if ["BLOCKER", "CRITICAL"].has(str(customer_audit.get("severity", ""))):
				critical_customer_ids.append(request_id)

		if night == 1 and unlocked_item_ids.size() < 5:
			notes.append("Night 1 has a very small item pool.")
		if not critical_customer_ids.is_empty():
			notes.append("Customers below good threshold: %s." % _join_ids(critical_customer_ids))

		unlock_audits[night] = {
			"night": night,
			"unlocked_item_ids": unlocked_item_ids,
			"newly_unlocked_item_ids": newly_unlocked_item_ids,
			"available_combo_ids": available_combo_ids,
			"customer_count": customer_count,
			"solvable_customer_count": solvable_customer_count,
			"critical_customer_ids": critical_customer_ids,
			"notes": notes
		}


func _audit_difficulty_curve() -> void:
	var previous_average_max_score := -1.0

	for night in AUDITED_NIGHTS:
		var request_count := 0
		var difficulty_total := 0
		var max_score_total := 0
		var good_solution_total := 0
		var perfect_solution_total := 0
		var required_tag_total := 0
		var avoid_tag_total := 0
		var notes := []

		for entry in schedule_entries:
			if _to_int(entry.get("night", 0), 0) != night:
				continue

			var request_id := str(entry.get("request_id", ""))
			var request: Dictionary = entry.get("request", {})
			var audit: Dictionary = customer_audits.get(request_id, {})
			request_count += 1
			difficulty_total += _to_int(request.get("difficulty", 1), 1)
			max_score_total += int(audit.get("max_score", 0))
			good_solution_total += int(audit.get("good_solution_count", 0))
			perfect_solution_total += int(audit.get("perfect_solution_count", 0))
			required_tag_total += _to_string_array(request.get("required_tags", [])).size()
			avoid_tag_total += _to_string_array(request.get("avoid_tags", [])).size()

		var average_difficulty := _safe_div(difficulty_total, request_count)
		var average_max_score := _safe_div(max_score_total, request_count)
		var average_good_solutions := _safe_div(good_solution_total, request_count)
		var average_perfect_solutions := _safe_div(perfect_solution_total, request_count)
		var theoretical_rating := _rating_for_average_score(average_max_score)
		var lowest_reasonable_rating := "D"
		if average_good_solutions > 0.0:
			lowest_reasonable_rating = "A/B"

		if previous_average_max_score >= 0.0 and average_max_score > previous_average_max_score + 8.0:
			notes.append("Average max score jumps above the previous night.")
		if night == 1:
			var combo_required_count := 0
			for entry in schedule_entries:
				if _to_int(entry.get("night", 0), 0) != 1:
					continue
				if bool(customer_audits.get(str(entry.get("request_id", "")), {}).get("combo_required", false)):
					combo_required_count += 1
			if combo_required_count >= 3:
				notes.append("Night 1 has many combo-dependent customers.")
		if average_perfect_solutions > 100.0:
			notes.append("Many perfect solutions may flatten puzzle difficulty.")
		if average_good_solutions <= 1.0:
			notes.append("Most customers are near unique-solution territory.")

		difficulty_audits[night] = {
			"night": night,
			"customer_count": request_count,
			"average_difficulty": average_difficulty,
			"average_max_score": average_max_score,
			"average_good_solutions": average_good_solutions,
			"average_perfect_solutions": average_perfect_solutions,
			"theoretical_rating": theoretical_rating,
			"lowest_reasonable_rating": lowest_reasonable_rating,
			"average_required_tags": _safe_div(required_tag_total, request_count),
			"average_avoid_tags": _safe_div(avoid_tag_total, request_count),
			"notes": notes
		}

		previous_average_max_score = average_max_score


func _audit_economy_simulation() -> void:
	for strategy_id in ["A", "B", "C"]:
		economy_audits[strategy_id] = _simulate_strategy(strategy_id)


func _simulate_strategy(strategy_id: String) -> Dictionary:
	var money := DEFAULT_START_MONEY
	var stock := _get_default_stock()
	var night_records := []
	var consumed_total := {}
	var purchased_total := {}
	var can_complete := true
	var failure_reasons := []
	var pressure_reasons := []

	for night in AUDITED_NIGHTS:
		var start_money := money
		var night_income := 0
		var restock_spend := 0
		var consumed_this_night := {}
		var purchased_this_night := {}
		var unable_customers := []
		var zero_stock_items := []

		for entry in schedule_entries:
			if _to_int(entry.get("night", 0), 0) != night:
				continue

			var request_id := str(entry.get("request_id", ""))
			var solution := _select_solution_for_strategy(strategy_id, request_id, stock, false)
			if solution.is_empty():
				can_complete = false
				unable_customers.append(request_id)
				failure_reasons.append("Night %d %s has no in-stock good solution." % [night, request_id])
				solution = _select_solution_for_strategy("B", request_id, stock, false)
				if solution.is_empty():
					continue

			if int(solution.get("score", 0)) < GOOD_SCORE:
				can_complete = false
				failure_reasons.append("Night %d %s served below good with score %d." % [
					night,
					request_id,
					int(solution.get("score", 0))
				])

			for item_id in _to_string_array(solution.get("item_ids", [])):
				stock[item_id] = int(stock.get(item_id, 0)) - 1
				consumed_this_night[item_id] = int(consumed_this_night.get(item_id, 0)) + 1
				consumed_total[item_id] = int(consumed_total.get(item_id, 0)) + 1
				if int(stock.get(item_id, 0)) == 0:
					_append_unique(zero_stock_items, item_id)

			var income := int(solution.get("income", 0))
			night_income += income
			money += income

		if night < 5:
			var needed_next_night := _plan_next_night_needs(strategy_id, night + 1)
			var purchase_order := _sorted_item_ids_from_counts(needed_next_night)
			for item_id in purchase_order:
				var needed := int(needed_next_night.get(item_id, 0))
				var current_stock := int(stock.get(item_id, 0))
				if current_stock >= needed:
					continue

				var item: Dictionary = items_by_id.get(item_id, {})
				var max_stock := maxi(_to_int(item.get("max_stock", 0), 0), 0)
				var buy_price := maxi(_to_int(item.get("buy_price", 0), 0), 0)
				var wanted := mini(needed - current_stock, max_stock - current_stock)
				var bought := 0
				for _i in range(wanted):
					if buy_price > money:
						break

					money -= buy_price
					restock_spend += buy_price
					stock[item_id] = int(stock.get(item_id, 0)) + 1
					bought += 1

				if bought > 0:
					purchased_this_night[item_id] = int(purchased_this_night.get(item_id, 0)) + bought
					purchased_total[item_id] = int(purchased_total.get(item_id, 0)) + bought

				if int(stock.get(item_id, 0)) < needed:
					pressure_reasons.append("Night %d restock could not fully pre-stock %s for night %d; alternate in-stock solutions may still exist." % [night, item_id, night + 1])

		if money < 0:
			can_complete = false
			failure_reasons.append("Night %d ended with negative money." % night)

		night_records.append({
			"night": night,
			"start_money": start_money,
			"income": night_income,
			"restock_spend": restock_spend,
			"end_money": money,
			"consumed": consumed_this_night,
			"purchased": purchased_this_night,
			"zero_stock_items": zero_stock_items,
			"unable_customers": unable_customers,
			"negative_money": money < 0
		})

	var severity := "INFO"
	if not can_complete:
		severity = "BLOCKER"
		_add_finding("BLOCKER", "tests/stage11_balance_audit.gd", "strategy_%s" % strategy_id, "Strategy %s cannot complete all five nights." % strategy_id)
	elif not pressure_reasons.is_empty():
		severity = "WARNING"
		_add_finding("WARNING", "data/items.json", "strategy_%s_restock_pressure" % strategy_id, "Strategy %s has restock pressure: %s" % [
			strategy_id,
			_join_ids(pressure_reasons)
		])
	elif strategy_id != "B" and money < 30:
		severity = "WARNING"
		_add_finding("WARNING", "data/items.json", "strategy_%s_economy" % strategy_id, "Strategy %s ends with low money: %d." % [strategy_id, money])

	return {
		"strategy_id": strategy_id,
		"name": _get_strategy_name(strategy_id),
		"can_complete": can_complete,
		"severity": severity,
		"final_money": money,
		"night_records": night_records,
		"consumed_total": consumed_total,
		"purchased_total": purchased_total,
		"failure_reasons": failure_reasons,
		"pressure_reasons": pressure_reasons
	}


func _select_solution_for_strategy(strategy_id: String, request_id: String, stock: Dictionary, ignore_stock: bool) -> Dictionary:
	var solutions: Array = solutions_by_request_id.get(request_id, [])
	var selected := {}

	for solution in solutions:
		if not ignore_stock and not _solution_has_stock(solution, stock):
			continue

		match strategy_id:
			"A":
				if int(solution.get("score", 0)) < GOOD_SCORE:
					continue
				if _is_better_low_consumption_solution(solution, selected):
					selected = solution
			"B":
				if _is_better_best_solution(solution, selected):
					selected = solution
			"C":
				if int(solution.get("score", 0)) < GOOD_SCORE:
					continue
				if not _to_string_array(solution.get("triggered_combo_ids", [])).is_empty():
					if selected.is_empty() or _to_string_array(selected.get("triggered_combo_ids", [])).is_empty() or _is_better_low_consumption_solution(solution, selected):
						selected = solution
				elif selected.is_empty() or (_to_string_array(selected.get("triggered_combo_ids", [])).is_empty() and _is_better_low_consumption_solution(solution, selected)):
					selected = solution

	if selected.is_empty() and strategy_id != "B":
		return _select_solution_for_strategy("B", request_id, stock, ignore_stock)

	return selected.duplicate(true)


func _plan_next_night_needs(strategy_id: String, night: int) -> Dictionary:
	var needed := {}
	for entry in schedule_entries:
		if _to_int(entry.get("night", 0), 0) != night:
			continue

		var request_id := str(entry.get("request_id", ""))
		var solution := _select_solution_for_strategy(strategy_id, request_id, {}, true)
		for item_id in _to_string_array(solution.get("item_ids", [])):
			needed[item_id] = int(needed.get(item_id, 0)) + 1

	return needed


func _write_report() -> void:
	var docs_path := ProjectSettings.globalize_path("res://docs")
	if not DirAccess.dir_exists_absolute(docs_path):
		DirAccess.make_dir_recursive_absolute(docs_path)

	var lines := []
	lines.append("# Balance Audit")
	lines.append("")
	_append_executive_summary(lines)
	_append_customer_solvability(lines)
	_append_item_usage(lines)
	_append_combo_balance(lines)
	_append_economy_simulation(lines)
	_append_unlock_progression(lines)
	_append_difficulty_curve(lines)
	_append_findings(lines)
	_append_stage11b_recommendations(lines)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write balance audit report. Error code: %s." % FileAccess.get_open_error())
		return

	file.store_string("\n".join(lines))


func _append_executive_summary(lines: Array) -> void:
	lines.append("## Executive Summary")
	lines.append("")
	lines.append("- Five-night completion: Strategy A %s, Strategy B %s, Strategy C %s." % [
		_completion_text("A"),
		_completion_text("B"),
		_completion_text("C")
	])
	lines.append("- Blockers: %d. Critical issues: %d. Warnings: %d." % [
		findings["BLOCKER"].size(),
		findings["CRITICAL"].size(),
		findings["WARNING"].size()
	])
	lines.append("- Recommended next step: %s" % _recommended_next_step())
	lines.append("")
	lines.append("Most severe issues:")
	var severe := _top_findings(5)
	if severe.is_empty():
		lines.append("- No blocker or critical issue found.")
	else:
		for finding in severe:
			lines.append("- %s `%s`: %s" % [
				str(finding.get("severity", "")),
				str(finding.get("id", "")),
				str(finding.get("message", ""))
			])
	lines.append("")


func _append_customer_solvability(lines: Array) -> void:
	lines.append("## Customer Solvability")
	lines.append("")
	lines.append("| night | request_id | customer_name | story_stage | difficulty | max_score | good_solution_count | perfect_solution_count | best_item_ids | combo_required | severity | notes |")
	lines.append("|---:|---|---|---:|---:|---:|---:|---:|---|---|---|---|")
	for entry in schedule_entries:
		var request_id := str(entry.get("request_id", ""))
		var audit: Dictionary = customer_audits.get(request_id, {})
		var best_solution: Dictionary = audit.get("best_solution", {})
		lines.append(_table_row([
			audit.get("night", ""),
			request_id,
			audit.get("customer_name", ""),
			audit.get("story_stage", ""),
			audit.get("difficulty", ""),
			audit.get("max_score", ""),
			audit.get("good_solution_count", ""),
			audit.get("perfect_solution_count", ""),
			_join_ids(best_solution.get("item_ids", [])),
			str(audit.get("combo_required", false)),
			audit.get("severity", ""),
			_join_ids(audit.get("notes", []))
		]))
	lines.append("")


func _append_item_usage(lines: Array) -> void:
	lines.append("## Item Usage")
	lines.append("")
	lines.append("| item_id | unlock_day | best_solution_usage | good_solution_usage | combo_count | classification | notes |")
	lines.append("|---|---:|---:|---:|---:|---|---|")
	for item_id in _sorted_item_ids(items_by_id.keys()):
		var usage: Dictionary = item_usage.get(item_id, {})
		lines.append(_table_row([
			item_id,
			usage.get("unlock_day", ""),
			usage.get("best_solution_usage", ""),
			usage.get("good_solution_usage", ""),
			usage.get("combo_count", ""),
			usage.get("classification", ""),
			_join_ids(usage.get("notes", []))
		]))
	lines.append("")


func _append_combo_balance(lines: Array) -> void:
	lines.append("## Combo Balance")
	lines.append("")
	lines.append("| combo_id | earliest_night | suitable_customer_count | triggered_solution_count | max_score_gain | classification | notes |")
	lines.append("|---|---:|---:|---:|---:|---|---|")
	for combo_id in _sorted_string_array(combo_audits.keys()):
		var audit: Dictionary = combo_audits[combo_id]
		var max_with := int(audit.get("max_score_with_combo", -1))
		var max_without := int(audit.get("max_score_without_combo", -1))
		var gain := 0
		if max_with >= 0 and max_without >= 0:
			gain = max_with - max_without
		lines.append(_table_row([
			combo_id,
			audit.get("earliest_available_night", ""),
			_to_string_array(audit.get("suitable_customer_ids", [])).size(),
			audit.get("triggered_solution_count", ""),
			gain,
			audit.get("classification", ""),
			_join_ids(audit.get("notes", []))
		]))
	lines.append("")


func _append_economy_simulation(lines: Array) -> void:
	lines.append("## Economy Simulation")
	lines.append("")
	lines.append("| strategy | night | income | restock_spend | end_money | stuck | zero_stock_items |")
	lines.append("|---|---:|---:|---:|---:|---|---|")
	for strategy_id in ["A", "B", "C"]:
		var audit: Dictionary = economy_audits.get(strategy_id, {})
		for night_record in audit.get("night_records", []):
			lines.append(_table_row([
				"%s - %s" % [strategy_id, audit.get("name", "")],
				night_record.get("night", ""),
				night_record.get("income", ""),
				night_record.get("restock_spend", ""),
				night_record.get("end_money", ""),
				str(not _to_string_array(night_record.get("unable_customers", [])).is_empty()),
				_join_ids(night_record.get("zero_stock_items", []))
			]))
		var strategy_notes := _to_string_array(audit.get("failure_reasons", []))
		for pressure_reason in _to_string_array(audit.get("pressure_reasons", [])):
			strategy_notes.append(pressure_reason)
		lines.append(_table_row([
			"%s final" % strategy_id,
			"",
			"",
			"",
			audit.get("final_money", ""),
			str(not bool(audit.get("can_complete", false))),
			_join_ids(strategy_notes)
		]))
	lines.append("")


func _append_unlock_progression(lines: Array) -> void:
	lines.append("## Unlock Progression")
	lines.append("")
	lines.append("| night | newly_unlocked_item_ids | unlocked_item_ids | available_combo_ids | customer_count | solvable_customer_count | critical_customer_ids |")
	lines.append("|---:|---|---|---|---:|---:|---|")
	for night in AUDITED_NIGHTS:
		var audit: Dictionary = unlock_audits.get(night, {})
		lines.append(_table_row([
			night,
			_join_ids(audit.get("newly_unlocked_item_ids", [])),
			_join_ids(audit.get("unlocked_item_ids", [])),
			_join_ids(audit.get("available_combo_ids", [])),
			audit.get("customer_count", ""),
			audit.get("solvable_customer_count", ""),
			_join_ids(audit.get("critical_customer_ids", []))
		]))
	lines.append("")


func _append_difficulty_curve(lines: Array) -> void:
	lines.append("## Difficulty Curve")
	lines.append("")
	lines.append("| night | customer_count | average_difficulty | average_max_score | average_good_solutions | average_perfect_solutions | theoretical_rating | risk |")
	lines.append("|---:|---:|---:|---:|---:|---:|---|---|")
	for night in AUDITED_NIGHTS:
		var audit: Dictionary = difficulty_audits.get(night, {})
		lines.append(_table_row([
			night,
			audit.get("customer_count", ""),
			_format_float(audit.get("average_difficulty", 0.0)),
			_format_float(audit.get("average_max_score", 0.0)),
			_format_float(audit.get("average_good_solutions", 0.0)),
			_format_float(audit.get("average_perfect_solutions", 0.0)),
			audit.get("theoretical_rating", ""),
			_join_ids(audit.get("notes", []))
		]))
	lines.append("")


func _append_findings(lines: Array) -> void:
	lines.append("## Findings by Severity")
	lines.append("")
	for severity in ["BLOCKER", "CRITICAL", "WARNING", "INFO"]:
		lines.append("### %s" % severity)
		if findings[severity].is_empty():
			lines.append("- None.")
		else:
			for finding in findings[severity]:
				lines.append("- `%s` (%s): %s" % [
					str(finding.get("id", "")),
					str(finding.get("file", "")),
					str(finding.get("message", ""))
				])
		lines.append("")


func _append_stage11b_recommendations(lines: Array) -> void:
	lines.append("## Recommended Stage 11B Changes")
	lines.append("")
	lines.append("1. Must fix")
	var must_fix := []
	for finding in findings["BLOCKER"] + findings["CRITICAL"]:
		must_fix.append("- `%s` in `%s`: %s Recommended adjustment: tune the referenced data or unlock timing until the request has at least one score >= 70 solution. Expected impact: removes completion risk. Risk: may make related combos stronger." % [
			str(finding.get("id", "")),
			str(finding.get("file", "")),
			str(finding.get("message", ""))
		])
	if must_fix.is_empty():
		lines.append("- None currently required.")
	else:
		lines.append_array(must_fix)

	lines.append("")
	lines.append("2. Should adjust")
	var should_adjust := []
	for item_id in _sorted_item_ids(items_by_id.keys()):
		var usage: Dictionary = item_usage[item_id]
		if ["Dominant Item", "Underused Item", "Low Usage"].has(str(usage.get("classification", ""))):
			should_adjust.append("- `%s` in `data/items.json`: %s. Recommended adjustment: review tags, price, unlock day, or combo support in Stage 11B. Expected impact: broader viable choices. Risk: can disturb current good solutions." % [
				item_id,
				str(usage.get("classification", ""))
			])
	for combo_id in _sorted_string_array(combo_audits.keys()):
		var audit: Dictionary = combo_audits[combo_id]
		if ["Never Triggered", "No Good Use", "Unavailable In MVP"].has(str(audit.get("classification", ""))):
			should_adjust.append("- `%s` in `data/combos.json`: %s. Recommended adjustment: review required_items, bonus_tags, or score_bonus. Expected impact: makes combo discovery meaningful. Risk: may create easier perfect solutions." % [
				combo_id,
				str(audit.get("classification", ""))
			])
	if should_adjust.is_empty():
		lines.append("- No broad balance adjustment is urgent.")
	else:
		lines.append_array(should_adjust)

	lines.append("")
	lines.append("3. Optional optimization")
	lines.append("- `tests/stage11_balance_audit.gd`: keep this audit as a regression check before future content tuning. Expected impact: catches unlock, score, and economy regressions early. Risk: report thresholds may need tuning as design goals mature.")
	lines.append("")


func _make_solution(request_id: String, night: int, item_ids: Array, score_result: Dictionary) -> Dictionary:
	return {
		"request_id": request_id,
		"night": night,
		"item_ids": _to_string_array(item_ids),
		"score": int(score_result.get("score", 0)),
		"grade": str(score_result.get("grade", "")),
		"matched_tags": _to_string_array(score_result.get("matched_tags", [])),
		"bad_tags": _to_string_array(score_result.get("bad_tags", [])),
		"missing_tags": _to_string_array(score_result.get("missing_tags", [])),
		"income": int(score_result.get("income", 0)),
		"triggered_combo_ids": _extract_combo_ids(score_result.get("triggered_combos", [])),
		"combo_bonus_tags": _to_string_array(score_result.get("combo_bonus_tags", [])),
		"buy_cost": _get_item_buy_cost(item_ids),
		"item_count": _to_string_array(item_ids).size()
	}


func _classify_customer_severity(max_score: int, good_solution_count: int) -> String:
	if max_score < NORMAL_SCORE:
		return "BLOCKER"
	if max_score < GOOD_SCORE:
		return "CRITICAL"
	if good_solution_count == 1:
		return "WARNING"
	return "INFO"


func _get_unlocked_item_ids(night: int) -> Array:
	var result := []
	for item_id in items_by_id.keys():
		var item: Dictionary = items_by_id[item_id]
		if _to_int(item.get("unlock_day", 1), 1) <= night:
			result.append(str(item_id))

	return _sorted_item_ids(result)


func _get_newly_unlocked_item_ids(night: int) -> Array:
	var result := []
	for item_id in items_by_id.keys():
		var item: Dictionary = items_by_id[item_id]
		if _to_int(item.get("unlock_day", 1), 1) == night:
			result.append(str(item_id))

	return _sorted_item_ids(result)


func _generate_item_combinations(item_ids: Array) -> Array:
	var ids := _to_string_array(item_ids)
	var combinations := []

	for i in range(ids.size()):
		combinations.append([ids[i]])

	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			combinations.append([ids[i], ids[j]])

	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			for k in range(j + 1, ids.size()):
				combinations.append([ids[i], ids[j], ids[k]])

	return combinations


func _is_better_best_solution(candidate: Dictionary, current: Dictionary) -> bool:
	if current.is_empty():
		return true

	var candidate_score := int(candidate.get("score", 0))
	var current_score := int(current.get("score", 0))
	if candidate_score != current_score:
		return candidate_score > current_score

	return _is_better_low_consumption_solution(candidate, current)


func _is_better_low_consumption_solution(candidate: Dictionary, current: Dictionary) -> bool:
	if current.is_empty():
		return true

	var candidate_count := int(candidate.get("item_count", _to_string_array(candidate.get("item_ids", [])).size()))
	var current_count := int(current.get("item_count", _to_string_array(current.get("item_ids", [])).size()))
	if candidate_count != current_count:
		return candidate_count < current_count

	var candidate_cost := int(candidate.get("buy_cost", 0))
	var current_cost := int(current.get("buy_cost", 0))
	if candidate_cost != current_cost:
		return candidate_cost < current_cost

	return _join_ids(candidate.get("item_ids", [])) < _join_ids(current.get("item_ids", []))


func _solution_has_stock(solution: Dictionary, stock: Dictionary) -> bool:
	var needed := {}
	for item_id in _to_string_array(solution.get("item_ids", [])):
		needed[item_id] = int(needed.get(item_id, 0)) + 1

	for item_id in needed.keys():
		if int(stock.get(item_id, 0)) < int(needed[item_id]):
			return false

	return true


func _get_default_stock() -> Dictionary:
	var stock := {}
	var exported = _inventory_system.export_inventory_data()
	if exported is Dictionary and not exported.is_empty():
		for item_id in exported.keys():
			stock[str(item_id)] = int(exported[item_id])
	else:
		for item_id in items_by_id.keys():
			var item: Dictionary = items_by_id[item_id]
			stock[str(item_id)] = maxi(_to_int(item.get("max_stock", 0), 0), 0)

	return stock


func _sorted_item_ids_from_counts(counts: Dictionary) -> Array:
	return _sorted_item_ids(counts.keys())


func _sorted_item_ids(raw_ids) -> Array:
	var ids := _to_string_array(raw_ids)
	ids.sort_custom(_sort_item_ids)
	return ids


func _sort_item_ids(a: String, b: String) -> bool:
	var item_a: Dictionary = items_by_id.get(a, {})
	var item_b: Dictionary = items_by_id.get(b, {})
	var unlock_a := _to_int(item_a.get("unlock_day", 1), 1)
	var unlock_b := _to_int(item_b.get("unlock_day", 1), 1)
	if unlock_a != unlock_b:
		return unlock_a < unlock_b

	return a < b


func _get_item_buy_cost(item_ids: Array) -> int:
	var total := 0
	for item_id in _to_string_array(item_ids):
		var item: Dictionary = items_by_id.get(item_id, {})
		total += maxi(_to_int(item.get("buy_price", 0), 0), 0)

	return total


func _get_combo_id(combo: Dictionary) -> String:
	var combo_id := str(combo.get("id", ""))
	if combo_id.is_empty():
		combo_id = str(combo.get("combo_id", ""))

	return combo_id


func _get_combo_required_items(combo: Dictionary) -> Array:
	var required_items = combo.get("required_items", [])
	if not (required_items is Array):
		required_items = combo.get("required_item_ids", [])

	return _to_string_array(required_items)


func _extract_combo_ids(triggered_combos) -> Array:
	var result := []
	if not (triggered_combos is Array):
		return result

	for combo in triggered_combos:
		if combo is Dictionary:
			_append_unique(result, _get_combo_id(combo))

	return result


func _find_combo_bonus_overlaps(combo_id: String) -> Array:
	var result := []
	var combo: Dictionary = combos_by_id.get(combo_id, {})
	var tags := _to_string_array(combo.get("bonus_tags", []))
	if tags.is_empty():
		return result

	for other_id in combos_by_id.keys():
		var normalized_other_id := str(other_id)
		if normalized_other_id == combo_id:
			continue

		var other: Dictionary = combos_by_id[other_id]
		if _has_any_overlap(tags, _to_string_array(other.get("bonus_tags", []))):
			_append_unique(result, normalized_other_id)

	return result


func _completion_text(strategy_id: String) -> String:
	var audit: Dictionary = economy_audits.get(strategy_id, {})
	if bool(audit.get("can_complete", false)):
		return "complete"

	return "blocked"


func _recommended_next_step() -> String:
	if not findings["BLOCKER"].is_empty() or not findings["CRITICAL"].is_empty():
		return "enter Stage 11B with targeted data fixes before adding content."
	if not findings["WARNING"].is_empty():
		return "enter Stage 11B for balance tuning, with no system rewrite needed."

	return "safe to proceed, keeping this audit as a regression test."


func _top_findings(limit: int) -> Array:
	var result := []
	for severity in ["BLOCKER", "CRITICAL", "WARNING"]:
		for finding in findings[severity]:
			if result.size() >= limit:
				return result
			result.append(finding)

	return result


func _rating_for_average_score(score: float) -> String:
	if score >= 90.0:
		return "S"
	if score >= 75.0:
		return "A"
	if score >= 60.0:
		return "B"
	if score >= 40.0:
		return "C"
	return "D"


func _get_strategy_name(strategy_id: String) -> String:
	match strategy_id:
		"A":
			return "Minimum Consumption"
		"B":
			return "Highest Score"
		"C":
			return "Combo First"

	return "Unknown"


func _add_finding(severity: String, file_path: String, finding_id: String, message: String) -> void:
	if not findings.has(severity):
		severity = "INFO"

	findings[severity].append({
		"severity": severity,
		"file": file_path,
		"id": finding_id,
		"message": message
	})


func _has_any_overlap(left: Array, right: Array) -> bool:
	for value in left:
		if right.has(value):
			return true

	return false


func _append_unique(values: Array, value: String) -> void:
	if value.is_empty() or values.has(value):
		return

	values.append(value)


func _to_string_array(value) -> Array:
	var result := []
	if not (value is Array):
		return result

	for entry in value:
		var text := str(entry)
		if not text.is_empty():
			result.append(text)

	return result


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)

	return default_value


func _safe_div(total: int, count: int) -> float:
	if count <= 0:
		return 0.0

	return float(total) / float(count)


func _format_float(value) -> String:
	return "%.2f" % float(value)


func _join_ids(value) -> String:
	if value is Dictionary:
		var pairs := []
		for key in _sorted_string_array(value.keys()):
			pairs.append("%s:%s" % [str(key), str(value[key])])
		return ", ".join(pairs)

	var ids := _to_string_array(value)
	if ids.is_empty():
		return "-"

	return ", ".join(ids)


func _sorted_string_array(raw_values) -> Array:
	var values := _to_string_array(raw_values)
	values.sort()
	return values


func _table_row(values: Array) -> String:
	var cells := []
	for value in values:
		cells.append(_escape_table_cell(str(value)))

	return "| %s |" % " | ".join(cells)


func _escape_table_cell(value: String) -> String:
	return value.replace("|", "\\|").replace("\n", " ").replace("\r", " ")
