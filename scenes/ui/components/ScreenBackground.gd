class_name ScreenBackground
extends TextureRect

@export var background_asset_id := "default_background"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	show_behind_parent = true
	set_background(background_asset_id)


func set_background(asset_id: String) -> void:
	background_asset_id = asset_id if not asset_id.is_empty() else "default_background"
	var tree := Engine.get_main_loop() as SceneTree
	var registry := tree.root.get_node_or_null("AssetRegistry") if tree != null else null
	texture = registry.get_texture("backgrounds", background_asset_id) if registry != null else null


func get_background_asset_id() -> String:
	return background_asset_id
