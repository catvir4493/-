extends SceneTree

const ITEMS_PATH := "res://data/items.json"
const CUSTOMERS_PATH := "res://data/customers.json"
const COMBOS_PATH := "res://data/combos.json"
const CUSTOMER_PROFILES_PATH := "res://data/customer_profiles.json"
const NIGHTS_PATH := "res://data/nights.json"
const CHAPTERS_PATH := "res://data/chapters.json"
const STORY_EVENTS_PATH := "res://data/story_events.json"
const ENDINGS_PATH := "res://data/endings.json"

const ALLOWED_TAGS := [
	"清醒",
	"睡眠",
	"冷静",
	"勇气",
	"安慰",
	"隐藏",
	"保护",
	"回忆",
	"悲伤",
	"真实",
	"冲动",
	"危险",
	"温和",
	"短效",
	"长期",
	"孤独",
	"希望",
	"逃避",
	"遗忘",
	"连接"
]

const BASE_STORY_IDS := [
	"student_story",
	"worker_story",
	"wet_man_story",
	"red_dress_story",
	"old_man_story",
	"masked_boy_story",
	"lost_child_story",
	"driver_story",
	"nameless_story",
	"previous_clerk_story"
]
const CHAPTER2_STORY_IDS := ["night_nurse_story", "divorced_father_story"]
const EXPECTED_TOTAL_ITEMS := 24
const EXPECTED_TOTAL_REQUESTS := 40
const EXPECTED_TOTAL_COMBOS := 12
const EXPECTED_TOTAL_STORIES := 12

var _failures: Array[String] = []
var _item_ids: Array[String] = []
var _story_ids_from_customers: Array[String] = []
var _story_ids_from_profiles: Array[String] = []
var _available_tags: Array[String] = []
var _max_story_stage_by_story: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var items := _load_json_array(ITEMS_PATH)
	var customers := _load_json_array(CUSTOMERS_PATH)
	var combos := _load_json_array(COMBOS_PATH)
	var profiles := _load_json_array(CUSTOMER_PROFILES_PATH)
	var nights := _load_json_array(NIGHTS_PATH)
	var chapters := _load_json_array(CHAPTERS_PATH)
	var story_events := _load_json_array(STORY_EVENTS_PATH)
	var endings := _load_json_array(ENDINGS_PATH)

	_validate_items(items)
	_validate_customers(customers)
	_validate_customer_profiles(profiles)
	_validate_combos(combos)
	_validate_story_links()
	_validate_customer_tags_are_answerable(customers, combos)
	_validate_nights(nights, customers)
	_validate_chapters(chapters, nights)
	_validate_story_events(story_events, chapters, nights, customers)
	_validate_endings(endings, chapters)
	_validate_stage16_totals(items, customers, combos, profiles, nights, chapters)

	if _failures.is_empty():
		print("Content validation passed.")
		quit(0)
		return

	print("Content validation failed.")
	for failure in _failures:
		print(" - %s" % failure)

	quit(1)


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		_fail(path, "", "file does not exist")
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail(path, "", "could not open file: %s" % FileAccess.get_open_error())
		return []

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		_fail(path, "", "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return []

	if not (json.data is Array):
		_fail(path, "", "root must be a JSON Array")
		return []

	return json.data


func _validate_items(items: Array) -> void:
	if items.size() != EXPECTED_TOTAL_ITEMS:
		_fail(ITEMS_PATH, "", "Stage 16 item count must be %d" % EXPECTED_TOTAL_ITEMS)

	var seen_ids := {}
	_item_ids.clear()
	_available_tags.clear()

	for item in items:
		if not (item is Dictionary):
			_fail(ITEMS_PATH, "", "item entry must be a Dictionary")
			continue

		var item_id := str(item.get("id", ""))
		_require_fields(ITEMS_PATH, item_id, item, ["id", "name", "description", "buy_price", "sell_price", "tags", "rarity", "unlock_day", "max_stock"])
		if item_id.is_empty():
			_fail(ITEMS_PATH, item_id, "item id must not be empty")
			continue

		if seen_ids.has(item_id):
			_fail(ITEMS_PATH, item_id, "duplicate item id")
		seen_ids[item_id] = true
		_item_ids.append(item_id)

		if _to_int(item.get("buy_price", -1), -1) < 0:
			_fail(ITEMS_PATH, item_id, "buy_price must be >= 0")

		if _to_int(item.get("sell_price", -1), -1) < 0:
			_fail(ITEMS_PATH, item_id, "sell_price must be >= 0")

		if _to_int(item.get("max_stock", 0), 0) <= 0:
			_fail(ITEMS_PATH, item_id, "max_stock must be > 0")

		if _to_int(item.get("unlock_day", 0), 0) < 1:
			_fail(ITEMS_PATH, item_id, "unlock_day must be >= 1")

		var tags := _as_array(item.get("tags", []))
		if tags.is_empty():
			_fail(ITEMS_PATH, item_id, "tags must not be empty")

		for tag_value in tags:
			var tag := str(tag_value)
			if not ALLOWED_TAGS.has(tag):
				_fail(ITEMS_PATH, item_id, "unknown tag: %s" % tag)
			elif not _available_tags.has(tag):
				_available_tags.append(tag)


func _validate_customers(customers: Array) -> void:
	if customers.size() != EXPECTED_TOTAL_REQUESTS:
		_fail(CUSTOMERS_PATH, "", "Stage 16 request count must be %d" % EXPECTED_TOTAL_REQUESTS)

	var seen_ids := {}
	_story_ids_from_customers.clear()
	_max_story_stage_by_story.clear()

	for customer in customers:
		if not (customer is Dictionary):
			_fail(CUSTOMERS_PATH, "", "customer entry must be a Dictionary")
			continue

		var request_id := str(customer.get("id", ""))
		_require_fields(CUSTOMERS_PATH, request_id, customer, ["id", "customer_name", "customer_type", "dialogue", "required_tags", "avoid_tags", "difficulty", "base_reward", "story_id", "repeatable"])
		if request_id.is_empty():
			_fail(CUSTOMERS_PATH, request_id, "request id must not be empty")
			continue

		if seen_ids.has(request_id):
			_fail(CUSTOMERS_PATH, request_id, "duplicate request id")
		seen_ids[request_id] = true

		var story_id := str(customer.get("story_id", ""))
		if story_id.is_empty():
			_fail(CUSTOMERS_PATH, request_id, "story_id must not be empty")
		elif not _story_ids_from_customers.has(story_id):
			_story_ids_from_customers.append(story_id)

		if str(customer.get("customer_name", "")).is_empty():
			_fail(CUSTOMERS_PATH, request_id, "customer_name must not be empty")

		if str(customer.get("dialogue", "")).is_empty():
			_fail(CUSTOMERS_PATH, request_id, "dialogue must not be empty")

		var required_tags := _as_array(customer.get("required_tags", []))
		var avoid_tags := _as_array(customer.get("avoid_tags", []))
		if required_tags.is_empty():
			_fail(CUSTOMERS_PATH, request_id, "required_tags must not be empty")

		_validate_tags(CUSTOMERS_PATH, request_id, required_tags, "required_tags")
		_validate_tags(CUSTOMERS_PATH, request_id, avoid_tags, "avoid_tags")

		for tag_value in required_tags:
			if avoid_tags.has(tag_value):
				_fail(CUSTOMERS_PATH, request_id, "required_tags and avoid_tags overlap: %s" % str(tag_value))

		var story_stage := _to_int(customer.get("story_stage", 1), 1)
		if story_stage < 1:
			_fail(CUSTOMERS_PATH, request_id, "story_stage must be >= 1")
		else:
			_max_story_stage_by_story[story_id] = maxi(_to_int(_max_story_stage_by_story.get(story_id, 0), 0), story_stage)

		if _to_int(customer.get("min_night", 1), 1) < 1:
			_fail(CUSTOMERS_PATH, request_id, "min_night must be >= 1")

		if _to_int(customer.get("min_visit_count", 0), 0) < 0:
			_fail(CUSTOMERS_PATH, request_id, "min_visit_count must be >= 0")


func _validate_combos(combos: Array) -> void:
	if combos.size() != EXPECTED_TOTAL_COMBOS:
		_fail(COMBOS_PATH, "", "Stage 16 combo count must be %d" % EXPECTED_TOTAL_COMBOS)

	var seen_ids := {}

	for combo in combos:
		if not (combo is Dictionary):
			_fail(COMBOS_PATH, "", "combo entry must be a Dictionary")
			continue

		var combo_id := str(combo.get("id", ""))
		_require_fields(COMBOS_PATH, combo_id, combo, ["id", "name", "required_items", "bonus_tags", "score_bonus", "special_dialogue"])
		if combo_id.is_empty():
			_fail(COMBOS_PATH, combo_id, "combo id must not be empty")
			continue

		if seen_ids.has(combo_id):
			_fail(COMBOS_PATH, combo_id, "duplicate combo id")
		seen_ids[combo_id] = true

		var required_items := _as_array(combo.get("required_items", []))
		if required_items.size() < 2:
			_fail(COMBOS_PATH, combo_id, "required_items must contain at least 2 items")
		if required_items.size() > 3:
			_fail(COMBOS_PATH, combo_id, "required_items must not exceed 3 items")

		for item_id_value in required_items:
			var item_id := str(item_id_value)
			if not _item_ids.has(item_id):
				_fail(COMBOS_PATH, combo_id, "required item does not exist: %s" % item_id)

		_validate_tags(COMBOS_PATH, combo_id, _as_array(combo.get("bonus_tags", [])), "bonus_tags")

		var score_bonus := _to_int(combo.get("score_bonus", 0), 0)
		if score_bonus < 10 or score_bonus > 20:
			_fail(COMBOS_PATH, combo_id, "score_bonus should be between 10 and 20")


func _validate_customer_profiles(profiles: Array) -> void:
	var seen_profile_ids := {}
	var seen_story_ids := {}
	_story_ids_from_profiles.clear()

	for profile in profiles:
		if not (profile is Dictionary):
			_fail(CUSTOMER_PROFILES_PATH, "", "profile entry must be a Dictionary")
			continue

		var profile_id := str(profile.get("id", ""))
		_require_fields(CUSTOMER_PROFILES_PATH, profile_id, profile, ["id", "story_id", "display_name", "customer_type", "short_description", "locked_description", "archive_stages", "portrait_id"])
		if profile_id.is_empty():
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "profile id must not be empty")
			continue

		if seen_profile_ids.has(profile_id):
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "duplicate profile id")
		seen_profile_ids[profile_id] = true

		var story_id := str(profile.get("story_id", ""))
		if story_id.is_empty():
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "story_id must not be empty")
		elif seen_story_ids.has(story_id):
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "duplicate story_id: %s" % story_id)
		else:
			seen_story_ids[story_id] = true
			_story_ids_from_profiles.append(story_id)

		if str(profile.get("display_name", "")).is_empty():
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "display_name must not be empty")

		var stages = profile.get("archive_stages", {})
		if not (stages is Dictionary):
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "archive_stages must be a Dictionary")
			continue

		if not stages.has("0"):
			_fail(CUSTOMER_PROFILES_PATH, profile_id, "archive_stages missing stage 0")
		var max_story_stage := _to_int(_max_story_stage_by_story.get(story_id, 0), 0)
		for stage_number in range(1, max_story_stage + 1):
			if not stages.has(str(stage_number)):
				_fail(CUSTOMER_PROFILES_PATH, profile_id, "archive_stages missing request-backed stage %d" % stage_number)

	for required_story_id in BASE_STORY_IDS:
		if not seen_story_ids.has(required_story_id):
			_fail(CUSTOMER_PROFILES_PATH, required_story_id, "missing base story profile")
	for required_story_id in CHAPTER2_STORY_IDS:
		if not seen_story_ids.has(required_story_id):
			_fail(CUSTOMER_PROFILES_PATH, required_story_id, "missing Chapter 2 story profile")


func _validate_story_links() -> void:
	for story_id in _story_ids_from_customers:
		if not _story_ids_from_profiles.has(story_id):
			_fail(CUSTOMERS_PATH, story_id, "story_id has no customer profile")

	for story_id in _story_ids_from_profiles:
		if not _story_ids_from_customers.has(story_id):
			_fail(CUSTOMER_PROFILES_PATH, story_id, "profile story_id has no customer request")


func _validate_customer_tags_are_answerable(customers: Array, combos: Array) -> void:
	var answerable_tags := _available_tags.duplicate()
	for combo in combos:
		if combo is Dictionary:
			for tag_value in _as_array(combo.get("bonus_tags", [])):
				var tag := str(tag_value)
				if not answerable_tags.has(tag):
					answerable_tags.append(tag)

	for customer in customers:
		if not (customer is Dictionary):
			continue

		var request_id := str(customer.get("id", ""))
		for tag_value in _as_array(customer.get("required_tags", [])):
			var tag := str(tag_value)
			if not answerable_tags.has(tag):
				_fail(CUSTOMERS_PATH, request_id, "required tag is not available from items or combos: %s" % tag)


func _validate_nights(nights: Array, customers: Array) -> void:
	if nights.is_empty():
		_fail(NIGHTS_PATH, "", "nights.json must contain night configs")
		return

	var expected_counts := {
		1: 5,
		2: 6,
		3: 7,
		4: 8,
		5: 4,
		6: 5,
		7: 5,
		8: 5,
		9: 5,
		10: 5
	}
	var nights_by_number := {}
	var seen_night_numbers := {}

	for night_config in nights:
		if not (night_config is Dictionary):
			_fail(NIGHTS_PATH, "", "night entry must be a Dictionary")
			continue

		var night_number := _to_int(night_config.get("night", 0), 0)
		if night_number <= 0:
			_fail(NIGHTS_PATH, "", "night must be a positive number")
			continue

		if seen_night_numbers.has(night_number):
			_fail(NIGHTS_PATH, str(night_number), "duplicate night number")
		seen_night_numbers[night_number] = true
		nights_by_number[night_number] = night_config

		_require_fields(NIGHTS_PATH, str(night_number), night_config, ["night", "title", "is_special_night", "customer_slots"])
		var slots = night_config.get("customer_slots", [])
		if not (slots is Array) or slots.is_empty():
			_fail(NIGHTS_PATH, str(night_number), "customer_slots must be a non-empty Array")

	for required_night in range(1, 11):
		if not nights_by_number.has(required_night):
			_fail(NIGHTS_PATH, str(required_night), "missing required night config")

	var lookup := _build_customer_story_stage_lookup(customers)
	var scheduled_request_ids: Array[String] = []
	var story_stage_seen := {}
	var story_visit_counts := {}

	for night_number in range(1, 11):
		if not nights_by_number.has(night_number):
			continue

		var night_config: Dictionary = nights_by_number[night_number]
		var slots = _as_array(night_config.get("customer_slots", []))
		var expected_count := int(expected_counts[night_number])
		if slots.size() != expected_count:
			_fail(NIGHTS_PATH, str(night_number), "Night %d must have %d customer slots, got %d" % [night_number, expected_count, slots.size()])

		if night_number == 5 and not bool(night_config.get("is_special_night", false)):
			_fail(NIGHTS_PATH, "Night 5", "Night 5 is_special_night must be true")

		for slot_index in range(slots.size()):
			var slot = slots[slot_index]
			if not (slot is Dictionary):
				_fail_night_slot(night_number, slot_index, "", 0, "slot must be a Dictionary")
				continue

			var story_id := str(slot.get("story_id", ""))
			var story_stage := _to_int(slot.get("story_stage", 0), 0)
			if story_id.is_empty():
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "story_id must not be empty")
				continue

			if not _story_ids_from_customers.has(story_id):
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "story_id has no customer request")
				continue

			if story_stage < 1:
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "story_stage must be >= 1")
				continue

			var key := _story_stage_key(story_id, story_stage)
			if not lookup.has(key):
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "story_id + story_stage does not resolve to exactly one request")
				continue

			var request: Dictionary = lookup[key]
			var request_id := str(request.get("id", ""))
			if scheduled_request_ids.has(request_id) and not bool(request.get("repeatable", false)):
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "non-repeatable request is scheduled more than once: %s" % request_id)

			var min_night := _to_int(request.get("min_night", 1), 1)
			if min_night > night_number:
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "request min_night %d is after scheduled night" % min_night)

			var current_visits := _to_int(story_visit_counts.get(story_id, 0), 0)
			var min_visit_count := _to_int(request.get("min_visit_count", 0), 0)
			if min_visit_count > current_visits:
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "request min_visit_count %d exceeds prior visits %d" % [min_visit_count, current_visits])

			var previous_stage := _to_int(story_stage_seen.get(story_id, 0), 0)
			if story_stage > previous_stage and story_stage > 1 and previous_stage != story_stage - 1:
				_fail_night_slot(night_number, slot_index, story_id, story_stage, "Stage %d must appear after Stage %d" % [story_stage, story_stage - 1])

			if not scheduled_request_ids.has(request_id):
				scheduled_request_ids.append(request_id)
			story_stage_seen[story_id] = maxi(previous_stage, story_stage)
			story_visit_counts[story_id] = current_visits + 1

	_validate_night_five_final_customer(nights_by_number)
	_validate_night_ten_final_customer(nights_by_number)
	_validate_night_schedule_coverage(scheduled_request_ids, customers)


func _build_customer_story_stage_lookup(customers: Array) -> Dictionary:
	var lookup := {}
	var duplicate_keys := {}

	for customer in customers:
		if not (customer is Dictionary):
			continue

		var story_id := str(customer.get("story_id", ""))
		var story_stage := _to_int(customer.get("story_stage", 0), 0)
		var key := _story_stage_key(story_id, story_stage)
		if lookup.has(key):
			duplicate_keys[key] = true
			continue

		lookup[key] = customer

	for key in duplicate_keys.keys():
		_fail(CUSTOMERS_PATH, str(key), "duplicate story_id + story_stage")
		lookup.erase(key)

	return lookup


func _validate_chapters(chapters: Array, nights: Array) -> void:
	var seen_ids := {}
	var known_nights := {}
	for night in nights:
		if night is Dictionary:
			known_nights[_to_int(night.get("night", 0), 0)] = true

	for chapter in chapters:
		if not (chapter is Dictionary):
			_fail(CHAPTERS_PATH, "", "chapter entry must be a Dictionary")
			continue

		var chapter_id := str(chapter.get("id", ""))
		if chapter_id.is_empty():
			_fail(CHAPTERS_PATH, "", "chapter id must not be empty")
		elif seen_ids.has(chapter_id):
			_fail(CHAPTERS_PATH, chapter_id, "duplicate chapter id")
		seen_ids[chapter_id] = true

		var start_night := _to_int(chapter.get("start_night", 0), 0)
		var end_night := _to_int(chapter.get("end_night", 0), 0)
		if start_night > end_night:
			_fail(CHAPTERS_PATH, chapter_id, "start_night must be <= end_night")

		var required_nights = chapter.get("required_nights", [])
		if not (required_nights is Array):
			_fail(CHAPTERS_PATH, chapter_id, "required_nights must be an Array")
		else:
			for night_number in required_nights:
				if not known_nights.has(_to_int(night_number, 0)):
					_fail(CHAPTERS_PATH, chapter_id, "required night does not exist: %s" % str(night_number))

	if not seen_ids.has("chapter_01"):
		_fail(CHAPTERS_PATH, "chapter_01", "required MVP chapter is missing")
	else:
		var chapter_one := _find_record_by_id(chapters, "chapter_01")
		if _to_int(chapter_one.get("start_night", 0), 0) != 1 or _to_int(chapter_one.get("end_night", 0), 0) != 5:
			_fail(CHAPTERS_PATH, "chapter_01", "chapter_01 must cover Night 1 through Night 5")
	if not seen_ids.has("chapter_02"):
		_fail(CHAPTERS_PATH, "chapter_02", "Stage 16 chapter is missing")
	else:
		var chapter_two := _find_record_by_id(chapters, "chapter_02")
		if _to_int(chapter_two.get("start_night", 0), 0) != 6 or _to_int(chapter_two.get("end_night", 0), 0) != 10:
			_fail(CHAPTERS_PATH, "chapter_02", "chapter_02 must cover Night 6 through Night 10")


func _validate_story_events(events: Array, chapters: Array, nights: Array, customers: Array) -> void:
	var seen_ids := {}
	var chapter_ids := _record_ids(chapters)
	var night_ids := {}
	for night in nights:
		if night is Dictionary:
			night_ids[_to_int(night.get("night", 0), 0)] = true
	var story_lookup := _build_customer_story_stage_lookup(customers)

	for event in events:
		if not (event is Dictionary):
			_fail(STORY_EVENTS_PATH, "", "event entry must be a Dictionary")
			continue

		var event_id := str(event.get("id", ""))
		if event_id.is_empty():
			_fail(STORY_EVENTS_PATH, "", "event id must not be empty")
		elif seen_ids.has(event_id):
			_fail(STORY_EVENTS_PATH, event_id, "duplicate event id")
		seen_ids[event_id] = true

		if str(event.get("type", "")).is_empty():
			_fail(STORY_EVENTS_PATH, event_id, "type must not be empty")
		if not (event.get("trigger", {}) is Dictionary):
			_fail(STORY_EVENTS_PATH, event_id, "trigger must be a Dictionary")
			continue
		if typeof(event.get("one_time")) != TYPE_BOOL:
			_fail(STORY_EVENTS_PATH, event_id, "one_time must be a bool")

		var trigger: Dictionary = event.get("trigger", {})
		var chapter_id := str(trigger.get("chapter_id", ""))
		if not chapter_id.is_empty() and not chapter_ids.has(chapter_id):
			_fail(STORY_EVENTS_PATH, event_id, "referenced chapter_id does not exist: %s" % chapter_id)
		var night_number := _to_int(trigger.get("night", 0), 0)
		if night_number > 0 and not night_ids.has(night_number):
			_fail(STORY_EVENTS_PATH, event_id, "referenced night does not exist: %d" % night_number)
		var story_id := str(trigger.get("story_id", ""))
		if not story_id.is_empty():
			var story_stage := _to_int(trigger.get("story_stage", 0), 0)
			if not story_lookup.has(_story_stage_key(story_id, story_stage)):
				_fail(STORY_EVENTS_PATH, event_id, "referenced story_id + story_stage does not exist")


func _validate_endings(endings: Array, chapters: Array) -> void:
	var seen_ids := {}
	var chapter_ids := _record_ids(chapters)
	for ending in endings:
		if not (ending is Dictionary):
			_fail(ENDINGS_PATH, "", "ending entry must be a Dictionary")
			continue

		var ending_id := str(ending.get("id", ""))
		if ending_id.is_empty():
			_fail(ENDINGS_PATH, "", "ending id must not be empty")
		elif seen_ids.has(ending_id):
			_fail(ENDINGS_PATH, ending_id, "duplicate ending id")
		seen_ids[ending_id] = true

		var conditions = ending.get("conditions", {})
		if not (conditions is Dictionary):
			_fail(ENDINGS_PATH, ending_id, "conditions must be a Dictionary")
			continue
		var chapter_id := str(conditions.get("completed_chapter", ""))
		if chapter_id.is_empty() or not chapter_ids.has(chapter_id):
			_fail(ENDINGS_PATH, ending_id, "completed_chapter must reference an existing chapter")

	if not seen_ids.has("ending_mvp_placeholder"):
		_fail(ENDINGS_PATH, "ending_mvp_placeholder", "required placeholder ending is missing")


func _record_ids(records: Array) -> Dictionary:
	var ids := {}
	for record in records:
		if record is Dictionary:
			var record_id := str(record.get("id", ""))
			if not record_id.is_empty():
				ids[record_id] = true
	return ids


func _find_record_by_id(records: Array, record_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and str(record.get("id", "")) == record_id:
			return record
	return {}


func _validate_night_five_final_customer(nights_by_number: Dictionary) -> void:
	if not nights_by_number.has(5):
		return

	var night_five: Dictionary = nights_by_number[5]
	var slots := _as_array(night_five.get("customer_slots", []))
	if slots.is_empty():
		return

	var final_slot = slots[slots.size() - 1]
	if not (final_slot is Dictionary):
		_fail_night_slot(5, slots.size() - 1, "", 0, "final slot must be a Dictionary")
		return

	var story_id := str(final_slot.get("story_id", ""))
	var story_stage := _to_int(final_slot.get("story_stage", 0), 0)
	if story_id != "previous_clerk_story" or story_stage != 3:
		_fail_night_slot(5, slots.size() - 1, story_id, story_stage, "Night 5 final customer must be previous_clerk_story Stage 3")
		return

	var request := _find_customer_by_story_stage(story_id, story_stage)
	if request.is_empty():
		_fail_night_slot(5, slots.size() - 1, story_id, story_stage, "final request could not be found")
		return

	if not str(request.get("dialogue", "")).contains("我想买回我离开这里的理由。"):
		_fail_night_slot(5, slots.size() - 1, story_id, story_stage, "final dialogue must contain the required previous clerk line")


func _validate_night_schedule_coverage(scheduled_request_ids: Array[String], customers: Array) -> void:
	var all_request_ids: Array[String] = []
	for customer in customers:
		if customer is Dictionary:
			all_request_ids.append(str(customer.get("id", "")))

	if scheduled_request_ids.size() != EXPECTED_TOTAL_REQUESTS:
		_fail(NIGHTS_PATH, "", "Night 1-10 must cover exactly %d unique requests, got %d" % [EXPECTED_TOTAL_REQUESTS, scheduled_request_ids.size()])

	for request_id in all_request_ids:
		if not scheduled_request_ids.has(request_id):
			_fail(NIGHTS_PATH, request_id, "request is missing from first five nights")

	for request_id in scheduled_request_ids:
		if not all_request_ids.has(request_id):
			_fail(NIGHTS_PATH, request_id, "scheduled request does not exist in customers.json")


func _validate_night_ten_final_customer(nights_by_number: Dictionary) -> void:
	if not nights_by_number.has(10):
		return
	var slots := _as_array((nights_by_number[10] as Dictionary).get("customer_slots", []))
	if slots.is_empty():
		return
	var final_slot = slots[-1]
	if not (final_slot is Dictionary) or str(final_slot.get("story_id", "")) != "previous_clerk_story" or _to_int(final_slot.get("story_stage", 0), 0) != 5:
		_fail(NIGHTS_PATH, "Night 10", "Night 10 final customer must be previous_clerk_story Stage 5")


func _validate_stage16_totals(items: Array, customers: Array, combos: Array, profiles: Array, nights: Array, chapters: Array) -> void:
	if _story_ids_from_customers.size() != EXPECTED_TOTAL_STORIES:
		_fail(CUSTOMERS_PATH, "", "Stage 16 story_id count must be %d" % EXPECTED_TOTAL_STORIES)
	var chapter_one_items := items.filter(func(item): return item is Dictionary and _to_int(item.get("unlock_day", 99), 99) <= 5)
	var chapter_one_requests := customers.filter(func(request): return request is Dictionary and _to_int(request.get("min_night", 99), 99) <= 5)
	var chapter_one_combos := combos.filter(func(combo):
		if not (combo is Dictionary): return false
		for item_id in _as_array(combo.get("required_items", [])):
			var item := _find_record_by_id(items, str(item_id))
			if item.is_empty() or _to_int(item.get("unlock_day", 99), 99) > 5: return false
		return true
	)
	if chapter_one_items.size() != 20:
		_fail(ITEMS_PATH, "", "Chapter 1 baseline must retain exactly 20 items")
	if chapter_one_requests.size() != 30:
		_fail(CUSTOMERS_PATH, "", "Chapter 1 baseline must retain exactly 30 requests")
	if chapter_one_combos.size() != 9:
		_fail(COMBOS_PATH, "", "Chapter 1 baseline must retain exactly 9 combos")


func _find_customer_by_story_stage(story_id: String, story_stage: int) -> Dictionary:
	for customer in _load_json_array(CUSTOMERS_PATH):
		if not (customer is Dictionary):
			continue

		if str(customer.get("story_id", "")) == story_id and _to_int(customer.get("story_stage", 0), 0) == story_stage:
			return customer

	return {}


func _story_stage_key(story_id: String, story_stage: int) -> String:
	return "%s::%d" % [story_id, story_stage]


func _require_fields(path: String, record_id: String, record: Dictionary, fields: Array) -> void:
	for field in fields:
		if not record.has(field):
			_fail(path, record_id, "missing required field: %s" % str(field))


func _validate_tags(path: String, record_id: String, tags: Array, field_name: String) -> void:
	for tag_value in tags:
		var tag := str(tag_value)
		if not ALLOWED_TAGS.has(tag):
			_fail(path, record_id, "%s contains unknown tag: %s" % [field_name, tag])


func _as_array(value) -> Array:
	if value is Array:
		return value

	return []


func _to_int(value, default_value: int) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String and value.is_valid_int():
		return int(value)

	return default_value


func _fail(path: String, record_id: String, reason: String) -> void:
	var message := "%s" % path
	if not record_id.is_empty():
		message += " [%s]" % record_id
	message += ": %s" % reason
	push_error(message)
	_failures.append(message)


func _fail_night_slot(night_number: int, slot_index: int, story_id: String, story_stage: int, reason: String) -> void:
	var record_id := "night=%d slot=%d story_id=%s story_stage=%d" % [
		night_number,
		slot_index + 1,
		story_id,
		story_stage
	]
	_fail(NIGHTS_PATH, record_id, reason)
