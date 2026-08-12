class_name RestockItemCard
extends PanelContainer

signal buy_pressed(item_id: String)

var item_id := ""

var _icon: TextureRect
var _name_label: Label
var _description_label: Label
var _stock_label: Label
var _price_label: Label
var _buy_button: Button


func _ready() -> void:
	_resolve_nodes()
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit(item_id))


func setup(item_data: Dictionary, stock: int, max_stock: int) -> void:
	_resolve_nodes()
	item_id = str(item_data.get("id", ""))
	_icon.texture = AssetRegistry.get_texture("item_icons", item_id)
	_name_label.text = str(item_data.get("name", item_id))
	_description_label.text = str(item_data.get("description", ""))
	set_stock(stock, max_stock)
	_price_label.text = "进货价：%d" % int(item_data.get("buy_price", 0))


func set_stock(stock: int, max_stock: int) -> void:
	_resolve_nodes()
	_stock_label.text = "库存：%d / %d" % [stock, max_stock]


func set_buy_enabled(enabled: bool) -> void:
	_resolve_nodes()
	_buy_button.disabled = not enabled


func get_buy_button() -> Button:
	_resolve_nodes()
	return _buy_button


func get_stock_label() -> Label:
	_resolve_nodes()
	return _stock_label


func get_icon_texture() -> Texture2D:
	_resolve_nodes()
	return _icon.texture


func _resolve_nodes() -> void:
	if _icon != null:
		return
	_icon = get_node("Margin/Row/ItemIcon") as TextureRect
	_name_label = get_node("Margin/Row/Text/ItemName") as Label
	_description_label = get_node("Margin/Row/Text/Description") as Label
	_stock_label = get_node("Margin/Row/Text/Stock") as Label
	_price_label = get_node("Margin/Row/Text/Price") as Label
	_buy_button = get_node("Margin/Row/BuyButton") as Button
