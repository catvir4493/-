class_name CustomerHeader
extends VBoxContainer

var _portrait: TextureRect
var _name_label: Label
var _type_label: Label


func _ready() -> void:
	if _portrait == null:
		_build_content()


func setup(customer_data: Dictionary, profile_data: Dictionary = {}) -> void:
	if _portrait == null:
		_build_content()
	var portrait_id := str(profile_data.get("portrait_id", "default_portrait"))
	var tree := Engine.get_main_loop() as SceneTree
	var registry := tree.root.get_node_or_null("AssetRegistry") if tree != null else null
	_portrait.texture = registry.get_texture("portraits", portrait_id) if registry != null else null
	_name_label.text = str(customer_data.get("customer_name", profile_data.get("display_name", "Unknown Customer")))
	_type_label.text = str(profile_data.get("short_description", customer_data.get("customer_type", "")))
	_type_label.visible = not _type_label.text.is_empty()


func show_empty_state(name_text: String, body_text: String) -> void:
	if _portrait == null:
		_build_content()
	var tree := Engine.get_main_loop() as SceneTree
	var registry := tree.root.get_node_or_null("AssetRegistry") if tree != null else null
	_portrait.texture = registry.get_texture("portraits", "default_portrait") if registry != null else null
	_name_label.text = name_text
	_type_label.text = body_text
	_type_label.visible = not body_text.is_empty()


func get_portrait_texture() -> Texture2D:
	return _portrait.texture if _portrait != null else null


func _build_content() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(200, 250)
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	_name_label = Label.new()
	_name_label.name = "CustomerName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name_label)

	_type_label = Label.new()
	_type_label.name = "CustomerType"
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.add_theme_font_size_override("font_size", 14)
	_type_label.modulate = Color(0.78, 0.8, 0.86)
	_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_type_label)
