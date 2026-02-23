extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var shop_grid: GridContainer = $Panel/MarginContainer/VBox/HBox/ShopPanel/ShopGrid
@onready var sell_grid: GridContainer = $Panel/MarginContainer/VBox/HBox/SellPanel/SellGrid
@onready var gold_label: Label = $Panel/MarginContainer/VBox/TopBar/GoldLabel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton

var _player: Node2D = null
var _shop_items: Array[String] = []
var _is_visible: bool = false
var _is_mobile: bool = false

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)

func setup(player: Node2D) -> void:
	_player = player

func open(shop_items: Array[String]) -> void:
	_shop_items = shop_items
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)
	if _is_mobile:
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 56)
		gold_label.add_theme_font_size_override("font_size", 44)
		close_button.add_theme_font_size_override("font_size", 38)
		close_button.custom_minimum_size = Vector2(220, 68)
		$Panel/MarginContainer/VBox/HBox/ShopPanel/Label.add_theme_font_size_override("font_size", 42)
		$Panel/MarginContainer/VBox/HBox/SellPanel/Label.add_theme_font_size_override("font_size", 42)

func close() -> void:
	_is_visible = false
	panel.visible = false
	closed.emit()

func _refresh() -> void:
	_refresh_shop()
	_refresh_sell()
	gold_label.text = "Gold: %d" % GameManager.gold

func _refresh_shop() -> void:
	for child in shop_grid.get_children():
		child.queue_free()

	for item_id in _shop_items:
		var item = ItemData.get_item(item_id)
		if item.is_empty():
			continue
		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item.get("name", "?")
		name_label.custom_minimum_size = Vector2(360 if _is_mobile else 140, 0)
		var rarity = item.get("rarity", 0)
		name_label.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
		name_label.add_theme_font_size_override("font_size", 36 if _is_mobile else 13)
		hbox.add_child(name_label)

		var price_label = Label.new()
		price_label.text = "%dg" % item.get("buy_price", 0)
		price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		price_label.add_theme_font_size_override("font_size", 36 if _is_mobile else 13)
		hbox.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(140, 64) if _is_mobile else Vector2(50, 28)
		if _is_mobile:
			buy_btn.add_theme_font_size_override("font_size", 32)
		var id = item_id
		buy_btn.pressed.connect(func(): _buy_item(id))
		hbox.add_child(buy_btn)

		shop_grid.add_child(hbox)

func _refresh_sell() -> void:
	for child in sell_grid.get_children():
		child.queue_free()

	if not _player:
		return

	var inv = _player.inventory
	for i in range(inv.bag.size()):
		var item = inv.bag[i]
		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item.get("name", "?")
		name_label.custom_minimum_size = Vector2(360 if _is_mobile else 140, 0)
		name_label.add_theme_font_size_override("font_size", 36 if _is_mobile else 13)
		hbox.add_child(name_label)

		var sell_price = ItemData.get_sell_price(item.get("id", ""))
		var price_label = Label.new()
		price_label.text = "%dg" % sell_price
		price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		price_label.add_theme_font_size_override("font_size", 36 if _is_mobile else 13)
		hbox.add_child(price_label)

		var sell_btn = Button.new()
		sell_btn.text = "Sell"
		sell_btn.custom_minimum_size = Vector2(140, 64) if _is_mobile else Vector2(50, 28)
		if _is_mobile:
			sell_btn.add_theme_font_size_override("font_size", 32)
		var idx = i
		sell_btn.pressed.connect(func(): _sell_item(idx))
		hbox.add_child(sell_btn)

		sell_grid.add_child(hbox)

func _buy_item(item_id: String) -> void:
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		return
	var price = item.get("buy_price", 0)
	if not GameManager.spend_gold(price):
		return  # Not enough gold
	if not _player.inventory.add_item(item):
		# Bag full, refund
		GameManager.add_gold(price)
		return
	AudioManager.play_sfx("shop_buy")
	_refresh()

func _sell_item(bag_index: int) -> void:
	if not _player:
		return
	var item = _player.inventory.bag[bag_index]
	var sell_price = ItemData.get_sell_price(item.get("id", ""))
	_player.inventory.remove_item_from_bag(bag_index)
	GameManager.add_gold(sell_price)
	AudioManager.play_sfx("shop_sell")
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
