extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _shop_items: Array[String] = []
var _is_visible: bool = false
var _is_mobile: bool = false
var _current_tab: int = 0  # 0 = Buy, 1 = Sell
var _selected_item: Dictionary = {}
var _selected_item_id: String = ""
var _selected_bag_index: int = -1

# Double-click quick-sell tracking
var _last_click_index: int = -1
var _last_click_time: int = 0
const DOUBLE_CLICK_MS: int = 400
var _pending_detail_timer: SceneTreeTimer = null
var _pending_detail_item: Dictionary = {}
var _pending_detail_id: String = ""
var _pending_detail_idx: int = -1

# UI references built in code
var _title_label: Label
var _gold_label: Label
var _close_btn: Button
var _buy_tab_btn: Button
var _sell_tab_btn: Button
var _item_scroll: ScrollContainer
var _item_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_rarity: Label
var _detail_desc: Label
var _detail_stats: Label
var _detail_price: Label
var _detail_level: Label
var _detail_action_btn: Button
var _detail_close_btn: Button
var _no_items_label: Label

func _ready() -> void:
	panel.visible = false

func setup(player: Node2D) -> void:
	_player = player

func open(shop_items: Array[String]) -> void:
	_shop_items = shop_items
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_build_ui()
	_current_tab = 0
	_selected_item = {}
	_refresh()
	AudioManager.play_sfx("enter_shop")

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = DisplayServer.is_touchscreen_available()
	if _is_mobile:
		var margin = 8.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
	else:
		panel.offset_left = -340.0
		panel.offset_right = 340.0
		panel.offset_top = -280.0
		panel.offset_bottom = 280.0

func close() -> void:
	_is_visible = false
	panel.visible = false
	closed.emit()

func _build_ui() -> void:
	# Clear old UI
	for child in panel.get_children():
		child.queue_free()

	var fs_title = 52 if _is_mobile else 20
	var fs_normal = 40 if _is_mobile else 14
	var fs_small = 34 if _is_mobile else 12
	var fs_btn = 44 if _is_mobile else 14
	var btn_h = 100 if _is_mobile else 32
	var tab_h = 110 if _is_mobile else 36
	var margin_px = 16 if _is_mobile else 12

	# Root margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", margin_px)
	margin.add_theme_constant_override("margin_top", margin_px)
	margin.add_theme_constant_override("margin_right", margin_px)
	margin.add_theme_constant_override("margin_bottom", margin_px)
	panel.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 8 if _is_mobile else 6)
	margin.add_child(root_vbox)

	# ---- Top bar: Title | Gold | Close ----
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_bar)

	_title_label = Label.new()
	_title_label.text = "Shop"
	_title_label.add_theme_font_size_override("font_size", fs_title)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	top_bar.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", fs_normal)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	top_bar.add_child(_gold_label)

	_close_btn = Button.new()
	if _is_mobile:
		_close_btn.text = "X"
		_close_btn.custom_minimum_size = Vector2(120, 100)
		_close_btn.add_theme_font_size_override("font_size", 50)
	else:
		_close_btn.text = "Close [Q]"
		_close_btn.custom_minimum_size = Vector2(90, 30)
		_close_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_close_btn, Color(1.0, 0.4, 0.3))
	_close_btn.pressed.connect(close)
	top_bar.add_child(_close_btn)

	# ---- Separator ----
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	root_vbox.add_child(sep)

	# ---- Tab buttons: Buy | Sell ----
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	root_vbox.add_child(tab_bar)

	_buy_tab_btn = Button.new()
	_buy_tab_btn.text = "Buy"
	_buy_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_tab_btn.custom_minimum_size = Vector2(0, tab_h)
	_buy_tab_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_buy_tab_btn, Color(0.3, 0.8, 0.4))
	_buy_tab_btn.pressed.connect(func(): _switch_tab(0))
	tab_bar.add_child(_buy_tab_btn)

	_sell_tab_btn = Button.new()
	_sell_tab_btn.text = "Sell"
	_sell_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_tab_btn.custom_minimum_size = Vector2(0, tab_h)
	_sell_tab_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_sell_tab_btn, Color(1.0, 0.85, 0.3))
	_sell_tab_btn.pressed.connect(func(): _switch_tab(1))
	tab_bar.add_child(_sell_tab_btn)

	# ---- Item list (scrollable) ----
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_item_scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 10 if _is_mobile else 2)
	_item_scroll.add_child(_item_list)

	_no_items_label = Label.new()
	_no_items_label.text = "No items"
	_no_items_label.add_theme_font_size_override("font_size", fs_normal)
	_no_items_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_items_label.visible = false
	_item_list.add_child(_no_items_label)

	# ---- Detail panel (hidden until item selected) ----
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	detail_style.border_color = Color(0.4, 0.35, 0.25)
	detail_style.set_border_width_all(2)
	detail_style.set_corner_radius_all(6)
	detail_style.set_content_margin_all(margin_px)
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	root_vbox.add_child(_detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 4 if _is_mobile else 2)
	_detail_panel.add_child(detail_vbox)

	# Detail: name
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", fs_title - 4)
	detail_vbox.add_child(_detail_name)

	# Detail: rarity + level
	var rarity_row = HBoxContainer.new()
	rarity_row.add_theme_constant_override("separation", 12)
	detail_vbox.add_child(rarity_row)

	_detail_rarity = Label.new()
	_detail_rarity.add_theme_font_size_override("font_size", fs_small)
	rarity_row.add_child(_detail_rarity)

	_detail_level = Label.new()
	_detail_level.add_theme_font_size_override("font_size", fs_small)
	_detail_level.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	rarity_row.add_child(_detail_level)

	# Detail: description
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", fs_small)
	_detail_desc.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	# Detail: stats
	_detail_stats = Label.new()
	_detail_stats.add_theme_font_size_override("font_size", fs_normal)
	_detail_stats.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	detail_vbox.add_child(_detail_stats)

	# Detail: price
	_detail_price = Label.new()
	_detail_price.add_theme_font_size_override("font_size", fs_normal)
	_detail_price.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	detail_vbox.add_child(_detail_price)

	# Detail: action buttons row
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(action_row)

	_detail_action_btn = Button.new()
	_detail_action_btn.custom_minimum_size = Vector2(280 if _is_mobile else 100, btn_h + 10 if _is_mobile else btn_h + 4)
	_detail_action_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_detail_action_btn, Color(0.3, 0.9, 0.4))
	action_row.add_child(_detail_action_btn)

	_detail_close_btn = Button.new()
	_detail_close_btn.text = "Back"
	_detail_close_btn.custom_minimum_size = Vector2(220 if _is_mobile else 80, btn_h + 10 if _is_mobile else btn_h + 4)
	_detail_close_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_detail_close_btn, Color(0.7, 0.7, 0.7))
	_detail_close_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap", -4.0)
		_hide_detail()
	)
	action_row.add_child(_detail_close_btn)

func _switch_tab(tab: int) -> void:
	AudioManager.play_sfx("ui_tap", -4.0)
	_current_tab = tab
	_last_click_index = -1
	_hide_detail()
	_refresh()

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	# Style active tab
	if _current_tab == 0:
		_buy_tab_btn.modulate = Color(1, 1, 1)
		_sell_tab_btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		_buy_tab_btn.modulate = Color(0.6, 0.6, 0.6)
		_sell_tab_btn.modulate = Color(1, 1, 1)

	# Clear item list (keep _no_items_label)
	for child in _item_list.get_children():
		if child != _no_items_label:
			child.queue_free()

	if _current_tab == 0:
		_build_buy_list()
	else:
		_build_sell_list()

func _build_buy_list() -> void:
	var fs = 40 if _is_mobile else 14
	var row_h = 100 if _is_mobile else 30
	var has_items = false

	for item_id in _shop_items:
		var item = ItemData.get_item(item_id)
		if item.is_empty():
			continue
		has_items = true
		var row = _create_item_row(item, item_id, -1, fs, row_h)
		_item_list.add_child(row)

	_no_items_label.visible = not has_items
	if not has_items:
		_no_items_label.text = "Nothing for sale"

func _build_sell_list() -> void:
	var fs = 40 if _is_mobile else 14
	var row_h = 100 if _is_mobile else 30
	var has_items = false

	if _player:
		var inv = _player.inventory
		for i in range(inv.bag.size()):
			var item = inv.bag[i]
			if item.is_empty():
				continue
			has_items = true
			var row = _create_item_row(item, item.get("id", ""), i, fs, row_h)
			_item_list.add_child(row)

	if has_items:
		var hint = Label.new()
		hint.text = "Double-tap item to quick-sell"
		hint.add_theme_font_size_override("font_size", 30 if _is_mobile else 11)
		hint.add_theme_color_override("font_color", Color(0.7, 0.6, 0.35, 0.7))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_list.add_child(hint)
		_item_list.move_child(hint, 1)  # after _no_items_label at index 0

	_no_items_label.visible = not has_items
	if not has_items:
		_no_items_label.text = "No items to sell"

func _create_item_row(item: Dictionary, item_id: String, bag_index: int, fs: int, row_h: int) -> Control:
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.16, 0.22, 0.7)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(10 if _is_mobile else 4)
	row_style.border_color = Color(0.3, 0.28, 0.22, 0.4)
	row_style.set_border_width_all(1)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.24, 0.22, 0.30, 0.85)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(10 if _is_mobile else 4)
	hover_style.border_color = Color(0.9, 0.75, 0.3, 0.7)
	hover_style.set_border_width_all(2)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.30, 0.28, 0.18, 0.9)
	pressed_style.set_corner_radius_all(6)
	pressed_style.set_content_margin_all(10 if _is_mobile else 4)
	pressed_style.border_color = Color(1.0, 0.85, 0.4, 0.9)
	pressed_style.set_border_width_all(2)

	var row_panel = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.custom_minimum_size = Vector2(0, row_h)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Item name
	var name_label = Label.new()
	name_label.text = item.get("name", "?")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rarity = item.get("rarity", 0)
	name_label.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
	name_label.add_theme_font_size_override("font_size", fs)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	# Price
	var price_label = Label.new()
	if _current_tab == 0:
		price_label.text = "%dg" % item.get("buy_price", 0)
	else:
		price_label.text = "%dg" % ItemData.get_sell_price(item.get("id", ""))
	price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	price_label.add_theme_font_size_override("font_size", fs)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(price_label)

	# Make entire row clickable with visual feedback
	var btn_overlay = Button.new()
	btn_overlay.flat = true
	btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Apply transparent styles so hover/press show through the panel
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.set_corner_radius_all(6)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.85, 0.3, 0.08)
	btn_hover.set_corner_radius_all(6)
	btn_hover.border_color = Color(0.9, 0.75, 0.3, 0.5)
	btn_hover.set_border_width_all(1)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(1.0, 0.85, 0.3, 0.15)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.border_color = Color(1.0, 0.85, 0.4, 0.7)
	btn_pressed.set_border_width_all(2)
	btn_overlay.add_theme_stylebox_override("normal", btn_normal)
	btn_overlay.add_theme_stylebox_override("hover", btn_hover)
	btn_overlay.add_theme_stylebox_override("pressed", btn_pressed)
	btn_overlay.add_theme_stylebox_override("focus", btn_hover)
	var _id = item_id
	var _idx = bag_index
	var _item = item
	btn_overlay.pressed.connect(func():
		AudioManager.play_sfx("ui_tap", -4.0)
		if _current_tab == 1 and _idx >= 0:
			var now = Time.get_ticks_msec()
			if _last_click_index == _idx and (now - _last_click_time) <= DOUBLE_CLICK_MS:
				# Double-click: quick-sell
				_cancel_pending_detail()
				_last_click_index = -1
				_last_click_time = 0
				_sell_item(_idx)
				return
			# First click: defer detail panel to allow double-click window
			_last_click_index = _idx
			_last_click_time = now
			_pending_detail_item = _item
			_pending_detail_id = _id
			_pending_detail_idx = _idx
			_cancel_pending_detail()
			_pending_detail_timer = get_tree().create_timer(DOUBLE_CLICK_MS / 1000.0)
			_pending_detail_timer.timeout.connect(func():
				_pending_detail_timer = null
				if _pending_detail_idx >= 0:
					_show_detail(_pending_detail_item, _pending_detail_id, _pending_detail_idx)
					_pending_detail_idx = -1
			)
			return
		_show_detail(_item, _id, _idx)
	)
	btn_overlay.mouse_entered.connect(func():
		AudioManager.play_sfx("ui_hover", -8.0)
		row_panel.add_theme_stylebox_override("panel", hover_style)
	)
	btn_overlay.mouse_exited.connect(func():
		row_panel.add_theme_stylebox_override("panel", row_style)
	)
	row_panel.add_child(btn_overlay)

	return row_panel

func _show_detail(item: Dictionary, item_id: String, bag_index: int) -> void:
	_selected_item = item
	_selected_item_id = item_id
	_selected_bag_index = bag_index
	_detail_panel.visible = true

	# Name
	var rarity = item.get("rarity", 0)
	_detail_name.text = item.get("name", "?")
	_detail_name.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))

	# Rarity
	_detail_rarity.text = ItemData.RARITY_NAMES.get(rarity, "")
	_detail_rarity.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))

	# Level requirement
	var level_req = item.get("level_req", 0)
	_detail_level.text = "Lv %d" % level_req if level_req > 0 else ""

	# Description
	_detail_desc.text = item.get("description", "")

	# Stats
	var stats = item.get("stats", {})
	var stat_lines: Array[String] = []
	for stat_name in stats:
		stat_lines.append("+%s %s" % [str(stats[stat_name]), stat_name.replace("_", " ").capitalize()])
	# Consumable effects
	if item.has("heal_percent"):
		stat_lines.append("Heals %d%% of max HP" % int(item["heal_percent"] * 100))
	if item.has("heal_amount"):
		stat_lines.append("Heals %d HP" % item["heal_amount"])
	_detail_stats.text = "  ".join(stat_lines) if stat_lines.size() > 0 else ""

	# Price and action button
	if _current_tab == 0:
		var price = item.get("buy_price", 0)
		_detail_price.text = "Price: %dg" % price
		_detail_action_btn.text = "Buy (%dg)" % price
		# Disconnect old signals
		for conn in _detail_action_btn.pressed.get_connections():
			_detail_action_btn.pressed.disconnect(conn["callable"])
		_detail_action_btn.pressed.connect(func(): _buy_item(item_id))
		# Disable if can't afford
		_detail_action_btn.disabled = GameManager.gold < price
	else:
		var sell_price = ItemData.get_sell_price(item_id)
		_detail_price.text = "Sell for: %dg" % sell_price
		_detail_action_btn.text = "Sell (%dg)" % sell_price
		for conn in _detail_action_btn.pressed.get_connections():
			_detail_action_btn.pressed.disconnect(conn["callable"])
		var idx = bag_index
		_detail_action_btn.pressed.connect(func(): _sell_item(idx))
		_detail_action_btn.disabled = false

func _cancel_pending_detail() -> void:
	if _pending_detail_timer != null:
		if _pending_detail_timer.timeout.get_connections().size() > 0:
			for conn in _pending_detail_timer.timeout.get_connections():
				_pending_detail_timer.timeout.disconnect(conn["callable"])
		_pending_detail_timer = null
	_pending_detail_idx = -1

func _hide_detail() -> void:
	_detail_panel.visible = false
	_selected_item = {}
	_last_click_index = -1

func _buy_item(item_id: String) -> void:
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		return
	var price = item.get("buy_price", 0)
	if not GameManager.spend_gold(price):
		GameManager.game_message.emit("Not enough gold!", Color(1.0, 0.3, 0.3))
		return
	if not _player.inventory.add_item(item):
		GameManager.add_gold(price)
		GameManager.game_message.emit("Bag is full!", Color(1.0, 0.3, 0.3))
		return
	AudioManager.play_sfx("shop_buy")
	GameManager.game_message.emit("Bought %s" % item.get("name", ""), Color(0.3, 1.0, 0.5))
	_hide_detail()
	_refresh()

func _sell_item(bag_index: int) -> void:
	if not _player:
		return
	if bag_index < 0 or bag_index >= _player.inventory.bag.size():
		return
	var item = _player.inventory.bag[bag_index]
	var sell_price = ItemData.get_sell_price(item.get("id", ""))
	_player.inventory.remove_item_from_bag(bag_index)
	GameManager.add_gold(sell_price)
	AudioManager.play_sfx("shop_sell")
	GameManager.game_message.emit("Sold %s for %dg" % [item.get("name", ""), sell_price], Color(1, 0.85, 0.2))
	_hide_detail()
	_refresh()

func _style_btn(btn: Button, accent: Color = Color(0.9, 0.75, 0.3)) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
	normal.border_color = accent * Color(0.5, 0.5, 0.5, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(4)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 0.95)
	hover.border_color = accent * Color(0.8, 0.8, 0.8, 0.8)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.25, 0.22, 0.14, 0.95)
	pressed.border_color = accent
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.06, 0.7)
	disabled.border_color = Color(0.3, 0.3, 0.3, 0.4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", hover)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1"):
		if _detail_panel.visible:
			_hide_detail()
		else:
			close()
		get_viewport().set_input_as_handled()
