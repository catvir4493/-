extends SceneTree

const ITEMS_PATH := "res://data/items.json"
const CUSTOMERS_PATH := "res://data/customers.json"
const COMBOS_PATH := "res://data/combos.json"
const CUSTOMER_PROFILES_PATH := "res://data/customer_profiles.json"

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

var _failures: Array[String] = []
var _item_ids: Array[String] = []
var _story_ids_from_customers: Array[String] = []
var _story_ids_from_profiles: Array[String] = []
var _available_tags: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var items := _load_json_array(ITEMS_PATH)
	var customers := _load_json_array(CUSTOMERS_PATH)
	var combos := _load_json_array(COMBOS_PATH)
	var profiles := _load_json_array(CUSTOMER_PROFILES_PATH)

	_validate_items(items)
	_validate_customer_profiles(profiles)
	_validate_customers(customers)
	_validate_combos(combos)
	_validate_story_links()
	_validate_customer_tags_are_answerable(customers, combos)

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
	if items.size() < 20:
		_fail(ITEMS_PATH, "", "item count must be at least 20")

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
	if customers.size() < 30:
		_fail(CUSTOMERS_PATH, "", "customer request count must be at least 30")

	var seen_ids := {}
	_story_ids_from_customers.clear()

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
		if story_stage < 1 or story_stage > 3:
			_fail(CUSTOMERS_PATH, request_id, "story_stage must be 1, 2, or 3")

		if _to_int(customer.get("min_night", 1), 1) < 1:
			_fail(CUSTOMERS_PATH, request_id, "min_night must be >= 1")

		if _to_int(customer.get("min_visit_count", 0), 0) < 0:
			_fail(CUSTOMERS_PATH, request_id, "min_visit_count must be >= 0")


func _validate_combos(combos: Array) -> void:
	if combos.size() < 8:
		_fail(COMBOS_PATH, "", "combo count must be at least 8")

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

		for stage in ["0", "1", "2", "3"]:
			if not stages.has(stage):
				_fail(CUSTOMER_PROFILES_PATH, profile_id, "archive_stages missing stage %s" % stage)

	for required_story_id in BASE_STORY_IDS:
		if not seen_story_ids.has(required_story_id):
			_fail(CUSTOMER_PROFILES_PATH, required_story_id, "missing base story profile")


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
