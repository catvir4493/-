extends SceneTree

const Tokens = preload("res://scripts/ui/UIDesignTokens.gd")
const BaseScreenScript = preload("res://scripts/ui/BaseScreen.gd")

const COMPONENT_PATHS := [
	"res://scenes/ui/components/PrimaryButton.tscn",
	"res://scenes/ui/components/InfoPanel.tscn",
	"res://scenes/ui/components/ToastMessage.tscn",
	"res://scenes/ui/components/ConfirmDialog.tscn",
	"res://scenes/ui/components/ItemCard.tscn",
	"res://scenes/ui/components/CustomerHeader.tscn",
	"res://scenes/ui/components/StatRow.tscn",
	"res://scenes/ui/components/SectionTitle.tscn",
	"res://scenes/ui/components/ScreenBackground.tscn",
	"res://scenes/ui/components/RestockItemCard.tscn",
	"res://scenes/ui/components/DialoguePanel.tscn",
	"res://scenes/ui/components/ChapterCard.tscn",
	"res://scenes/ui/components/NarrativeOverlay.tscn"
]
const SCREEN_PATHS := [
	"res://scenes/main_menu/MainMenu.tscn",
	"res://scenes/settings/SettingsScene.tscn",
	"res://scenes/archive/ArchiveScene.tscn",
	"res://scenes/shop/ShopScene.tscn",
	"res://scenes/result/ResultScene.tscn",
	"res://scenes/night_result/NightResultScene.tscn",
	"res://scenes/restock/RestockScene.tscn"
]
const RESOLUTIONS := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var failures: Array[String] = []
var AssetRegistry
var DataManager
var SaveManager
var SettingsManager


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	AssetRegistry = root.get_node_or_null("/root/AssetRegistry")
	DataManager = root.get_node_or_null("/root/DataManager")
	SaveManager = root.get_node_or_null("/root/SaveManager")
	SettingsManager = root.get_node_or_null("/root/SettingsManager")
	await _test_foundation()
	await _test_components()
	_test_screen_instantiation()
	await _test_responsive_layout()
	_test_required_page_controls()
	_test_framework_invariants()
	await process_frame
	await process_frame
	_finish()


func _test_foundation() -> void:
	_assert(Tokens.DESIGN_WIDTH == 1152 and Tokens.DESIGN_HEIGHT == 648, "UIDesignTokens must define 1152x648.")
	var theme := load("res://assets/ui/themes/MidnightTheme.tres") as Theme
	_assert(theme != null, "MidnightTheme must load.")
	var manager = root.get_node_or_null("/root/UIThemeManager")
	_assert(manager != null, "UIThemeManager must exist.")
	if manager != null:
		_assert(manager.has_method("get_main_theme"), "UIThemeManager.get_main_theme must exist.")
		_assert(manager.has_method("apply_theme"), "UIThemeManager.apply_theme must exist.")
		_assert(manager.has_method("reload_theme"), "UIThemeManager.reload_theme must exist.")
		_assert(manager.has_method("apply_font_assets"), "Stage 15 font integration must remain available.")
		_assert(manager.get_main_theme() != null, "UIThemeManager must return a Theme.")
	var base: Control = BaseScreenScript.new()
	root.add_child(base)
	await process_frame
	_assert(base.theme != null, "BaseScreen must automatically apply the main theme.")
	_assert(base.begin_ui_action("probe"), "BaseScreen must begin a UI action once.")
	_assert(not base.begin_ui_action("probe"), "BaseScreen must prevent duplicate UI actions.")
	base.end_ui_action("probe")
	base.queue_free()


func _test_components() -> void:
	for path in COMPONENT_PATHS:
		var packed := load(path) as PackedScene
		_assert(packed != null, "Component must load: %s." % path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_assert(instance != null, "Component must instantiate: %s." % path)
		instance.free()

	var layout_packed := load("res://scenes/ui/layouts/ScreenLayout.tscn") as PackedScene
	_assert(layout_packed != null, "ScreenLayout must load.")
	var layout: Control = layout_packed.instantiate()
	_assert(layout.get_header() != null and layout.get_content() != null and layout.get_footer() != null, "ScreenLayout slots must be available.")
	layout.free()

	var button: Button = (load(COMPONENT_PATHS[0]) as PackedScene).instantiate()
	button.set_text("关键操作")
	button.set_enabled(true)
	_assert(button.text == "关键操作" and not button.disabled, "PrimaryButton text/enabled API must work.")
	_assert(button.focus_mode != Control.FOCUS_NONE, "PrimaryButton must be keyboard accessible.")
	button.free()

	var toast: Control = (load(COMPONENT_PATHS[2]) as PackedScene).instantiate()
	root.add_child(toast)
	await process_frame
	toast.show_message("first", 0.05)
	toast.show_message("replacement", 0.05)
	_assert(toast.visible, "Toast must safely show repeated messages.")
	await create_timer(0.06).timeout
	toast.free()

	var dialog: Control = (load(COMPONENT_PATHS[3]) as PackedScene).instantiate()
	root.add_child(dialog)
	await process_frame
	var signal_counts := {"confirmed": 0, "cancelled": 0}
	dialog.confirmed.connect(func() -> void: signal_counts["confirmed"] += 1)
	dialog.cancelled.connect(func() -> void: signal_counts["cancelled"] += 1)
	dialog.open("Test", "Message", "Yes", "No")
	dialog.get_node("Center/Panel/Margin/Layout/Actions/ConfirmButton").pressed.emit()
	dialog.open("Test", "Message", "Yes", "No")
	dialog.get_node("Center/Panel/Margin/Layout/Actions/CancelButton").pressed.emit()
	_assert(signal_counts["confirmed"] == 1 and signal_counts["cancelled"] == 1, "ConfirmDialog signals must work.")
	dialog.queue_free()

	var item: Button = (load(COMPONENT_PATHS[4]) as PackedScene).instantiate()
	root.add_child(item)
	item.setup(DataManager.get_item_by_id("coffee"), 3)
	item.set_state(ItemCard.CardState.SELECTED)
	await process_frame
	_assert(item.get_icon_texture() != null, "ItemCard Stage 15 icon loading must remain available.")
	_assert(item.button_pressed, "ItemCard selected state must work.")
	item.queue_free()

	var header: Control = (load(COMPONENT_PATHS[5]) as PackedScene).instantiate()
	root.add_child(header)
	var profile: Dictionary = DataManager.get_all_customer_profiles()[0]
	header.setup({"customer_name": "Test", "dialogue": "Public dialogue", "required_tags": ["secret"], "avoid_tags": ["secret"]}, profile)
	await process_frame
	_assert(header.get_portrait_texture() != null, "CustomerHeader Stage 15 portrait loading must remain available.")
	_assert(not _collect_label_text(header).contains("secret"), "CustomerHeader must not expose required/avoid tags.")
	_assert(not _collect_label_text(header).contains("Public dialogue"), "CustomerHeader must leave dialogue presentation to DialoguePanel.")
	header.queue_free()

	var background: TextureRect = (load(COMPONENT_PATHS[8]) as PackedScene).instantiate()
	root.add_child(background)
	background.set_background("shop_default")
	await process_frame
	_assert(background.texture != null and background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "ScreenBackground must load through Stage 15 with explicit stretch.")
	background.queue_free()


func _test_screen_instantiation() -> void:
	for path in SCREEN_PATHS:
		var packed := load(path) as PackedScene
		_assert(packed != null, "Screen must load: %s." % path)
		if packed == null:
			continue
		var screen: Control = packed.instantiate()
		_assert(screen != null, "Screen must instantiate: %s." % path)
		_assert(screen.anchor_right == 1.0 and screen.anchor_bottom == 1.0, "Screen root must be full rect: %s." % path)
		screen.free()


func _test_responsive_layout() -> void:
	var packed := load("res://scenes/ui/layouts/ScreenLayout.tscn") as PackedScene
	for resolution in RESOLUTIONS:
		var viewport := SubViewport.new()
		viewport.size = resolution
		root.add_child(viewport)
		var layout: Control = packed.instantiate()
		viewport.add_child(layout)
		await process_frame
		_assert(layout.size.x >= 0.0 and layout.size.y >= 0.0, "ScreenLayout size must be non-negative at %s." % resolution)
		_assert(layout.size == Vector2(resolution), "ScreenLayout must fill %s instead of staying in the top-left." % resolution)
		_assert(not _has_negative_size(layout), "Layout children must not have negative size at %s." % resolution)
		viewport.queue_free()
		await process_frame


func _test_required_page_controls() -> void:
	var main_menu := _build_screen_ui("res://scenes/main_menu/MainMenu.tscn")
	_assert(_count_buttons_with_text(main_menu, ["New Game", "Continue", "Customer Archive", "Settings", "Quit"]) == 5, "MainMenu must retain all five actions.")
	_assert(main_menu.has_method("has_text_title_fallback") and main_menu.has_text_title_fallback(), "MainMenu must retain text title fallback.")
	main_menu.free()

	var settings := _build_screen_ui("res://scenes/settings/SettingsScene.tscn")
	_assert(_find_first_of_type(settings, "HSlider") != null, "SettingsScene must contain sliders.")
	_assert(_collect_label_text(settings).contains("Master Volume") and _collect_label_text(settings).contains("Text Speed"), "SettingsScene must retain settings controls.")
	settings.free()

	var archive := _build_screen_ui("res://scenes/archive/ArchiveScene.tscn")
	_assert(_find_first_of_type(archive, "ScrollContainer") != null, "ArchiveScene must contain a ScrollContainer.")
	_assert(_find_first_of_type(archive, "InfoPanel") != null, "ArchiveScene must use InfoPanel.")
	archive.free()

	var shop := _build_screen_ui("res://scenes/shop/ShopScene.tscn")
	_assert(_find_button(shop, "Confirm") != null, "Shop Confirm must exist.")
	shop.free()

	for path in ["res://scenes/result/ResultScene.tscn", "res://scenes/night_result/NightResultScene.tscn"]:
		var result_screen := _build_screen_ui(path)
		_assert(_find_first_of_type(result_screen, "ScreenLayout") != null, "Result screens must use ScreenLayout: %s." % path)
		_assert(_find_first_of_type(result_screen, "InfoPanel") != null, "Result screens must use InfoPanel: %s." % path)
		result_screen.free()

	var restock := _build_screen_ui("res://scenes/restock/RestockScene.tscn")
	_assert(_find_first_of_type(restock, "ScrollContainer") != null, "RestockScene must retain a scrollable list.")
	restock.free()


func _test_framework_invariants() -> void:
	for autoload_name in ["AssetRegistry", "SceneTransitionManager", "SettingsManager", "SaveManager", "ContentUnlockSystem"]:
		_assert(root.get_node_or_null("/root/%s" % autoload_name) != null, "%s must remain available." % autoload_name)
	_assert(AssetRegistry.is_manifest_loaded(), "AssetRegistry manifest must remain loaded.")
	_assert(AssetRegistry.get_manifest_version() == 1, "manifest_version must remain 1.")
	_assert(SaveManager.create_default_save().get("save_version", 0) == 1, "save_version must remain 1.")
	_assert(SettingsManager.CURRENT_SETTINGS_VERSION == 1, "settings_version must remain 1.")
	_assert(DataManager.get_all_items().size() >= 20, "Stage 11B items must remain available after content expansion.")
	_assert(DataManager.get_all_customers().size() >= 30, "Stage 11B requests must remain available after content expansion.")
	_assert(DataManager.get_all_chapters().size() == 2, "Stage 12 chapter framework must support expanded data.")
	_assert(DataManager.get_all_story_events().size() == 7, "Stage 12 event framework must support expanded data.")


func _build_screen_ui(path: String) -> Control:
	var screen: Control = (load(path) as PackedScene).instantiate()
	screen.call("_build_ui")
	return screen


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _count_buttons_with_text(node: Node, texts: Array) -> int:
	var count := 0
	for text in texts:
		if _find_button(node, str(text)) != null:
			count += 1
	return count


func _find_first_of_type(node: Node, class_name_value: String) -> Node:
	if node.get_class() == class_name_value or node.name == class_name_value:
		return node
	for child in node.get_children():
		var found := _find_first_of_type(child, class_name_value)
		if found != null:
			return found
	return null


func _has_negative_size(node: Node) -> bool:
	if node is Control and (node.size.x < 0.0 or node.size.y < 0.0):
		return true
	for child in node.get_children():
		if _has_negative_size(child):
			return true
	return false


func _collect_label_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result = (node as Label).text
	elif node is Button:
		result = (node as Button).text
	for child in node.get_children():
		result += "\n" + _collect_label_text(child)
	return result


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Stage 14 UI framework smoke test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("Stage 14 UI framework smoke test failed with %d issue(s)." % failures.size())
	quit(1)
