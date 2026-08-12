class_name ItemCard
extends Button

signal item_pressed(item_id: String)

enum CardState {
	AVAILABLE,
	SELECTED,
	OUT_OF_STOCK,
	LOCKED,
	DISABLED
}

var item_id := ""
var card_state := CardState.AVAILABLE
var _icon: TextureRect
var _text_label: Label


func _ready() -> void:
	if _icon == null:
		_build_content()
	if not pressed.is_connected(_emit_item_pressed):
		pressed.connect(_emit_item_pressed)


func setup(item_data: Dictionary, stock: int) -> void:
	if _icon == null:
		_build_content()
	item_id = str(item_data.get("id", ""))
	var item_name := str(item_data.get("name", item_id))
	var description := str(item_data.get("description", ""))
	var max_stock := int(item_data.get("max_stock", 0))
	var tree := Engine.get_main_loop() as SceneTree
	var registry := tree.root.get_node_or_null("AssetRegistry") if tree != null else null
	_icon.texture = registry.get_texture("item_icons", item_id) if registry != null else null
	_text_label.text = "%s\nStock: %d/%d\n%s" % [item_name, stock, max_stock, description]
	tooltip_text = description


func set_state_text(state_text: String, item_data: Dictionary, stock: int) -> void:
	var item_name := str(item_data.get("name", item_id))
	var description := str(item_data.get("description", ""))
	var max_stock := int(item_data.get("max_stock", 0))
	_text_label.text = "%s · %s\nStock: %d/%d\n%s" % [item_name, state_text, stock, max_stock, description]


func set_state(state: CardState) -> void:
	card_state = state
	toggle_mode = true
	disabled = state == CardState.OUT_OF_STOCK or state == CardState.LOCKED or state == CardState.DISABLED
	button_pressed = state == CardState.SELECTED
	match state:
		CardState.SELECTED:
			modulate = Color(1.0, 0.9, 0.55)
		CardState.OUT_OF_STOCK, CardState.LOCKED:
			modulate = Color(0.55, 0.55, 0.58)
		CardState.DISABLED:
			modulate = Color(0.72, 0.72, 0.76)
		_:
			modulate = Color.WHITE


func set_selected(selected: bool) -> void:
	set_state(CardState.SELECTED if selected else CardState.AVAILABLE)


func get_icon_texture() -> Texture2D:
	return _icon.texture if _icon != null else null


func _emit_item_pressed() -> void:
	if not item_id.is_empty():
		item_pressed.emit(item_id)


func _build_content() -> void:
	text = ""
	custom_minimum_size = Vector2(290, 142)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	_icon = TextureRect.new()
	_icon.name = "ItemIcon"
	_icon.custom_minimum_size = Vector2(84, 84)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	_text_label = Label.new()
	_text_label.name = "ItemText"
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text_label)
