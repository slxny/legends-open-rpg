extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var equip_tab_btn: Button = $Panel/MarginContainer/VBox/TabBar/EquipTab
@onready var bag_tab_btn: Button = $Panel/MarginContainer/VBox/TabBar/BagTab
@onready var content_scroll: ScrollContainer = $Panel/MarginContainer/VBox/ContentScroll
@onready var content_vbox: VBoxContainer = $Panel/MarginContainer/VBox/ContentScroll/ContentVBox
@onready var detail_label: Label = $Panel/MarginContainer/VBox/DetailPanel/DetailMargin/DetailLabel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsLabel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
var _current_tab: int = 0  # 0 = Equipment, 1 = Bag
var _selected_item: Dictionary = {}

const TAB_ACTIVE_COLOR := Color(1.0, 0.85, 0.4)
const TAB_INACTIVE_COLOR := Color(0.6, 0.6, 0.6)

# Style helpers for item buttons
func _make_item_style(is_empty: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if is_empty:
		s.bg_color = Color(0.12, 0.12, 0.15, 0.4)
	else:
		s.bg_color = Color(0.16, 0.16, 0.22, 0.7)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(6 if _is_mobile else 3)
	s.border_color = Color(0.3, 0.28, 0.22, 0.4)
	s.set_border_width_all(1)
	return s

func _make_hover_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.24, 0.22, 0.30, 0.85)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(6 if _is_mobile else 3)
	s.border_color = Color(0.9, 0.75, 0.3, 0.7)
	s.set_border_width_all(2)
	return s

func _make_pressed_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.28, 0.18, 0.9)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(6 if _is_mobile else 3)
	s.border_color = Color(1.0, 0.85, 0.4, 0.9)
	s.set_border_width_all(2)
	return s

func _style_item_btn(btn: Button, is_empty: bool) -> void:
	btn.add_theme_stylebox_override("normal", _make_item_style(is_empty))
	btn.add_theme_stylebox_override("hover", _make_hover_style())
	btn.add_theme_stylebox_override("pressed", _make_pressed_style())
	btn.add_theme_stylebox_override("focus", _make_hover_style())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not is_empty else Control.CURSOR_ARROW

func _ready() -> void:
	panel.visible = false
	equip_tab_btn.pressed.connect(_switch_tab.bind(0))
	bag_tab_btn.pressed.connect(_switch_tab.bind(1))

func setup(player: Node2D) -> void:
	_player = player
	player.inventory.inventory_changed.connect(_refresh)
	player.inventory.equipment_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
	elif _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_is_visible = !_is_visible
	panel.visible = _is_visible
	if _is_visible:
		_selected_item = {}
		_detect_mobile()
		_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = DisplayServer.is_touchscreen_available() or min(vp_size.x, vp_size.y) < 700
	if _is_mobile:
		var margin = 8.0
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = margin
		panel.offset_right = -margin
		panel.offset_top = margin
		panel.offset_bottom = -margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 48)
		equip_tab_btn.add_theme_font_size_override("font_size", 38)
		equip_tab_btn.custom_minimum_size.y = 80
		bag_tab_btn.add_theme_font_size_override("font_size", 38)
		bag_tab_btn.custom_minimum_size.y = 80
		detail_label.add_theme_font_size_override("font_size", 34)
		stats_label.add_theme_font_size_override("font_size", 32)
		# Replace keyboard hint with close button
		var close_hint = $Panel/MarginContainer/VBox/TopBar/CloseHint
		close_hint.queue_free()
		var close_btn = Button.new()
		close_btn.text = "X"
		close_btn.custom_minimum_size = Vector2(70, 60)
		close_btn.add_theme_font_size_override("font_size", 36)
		close_btn.pressed.connect(toggle)
		$Panel/MarginContainer/VBox/TopBar.add_child(close_btn)
	else:
		# Desktop: compact right-side panel, stops above the 115px bottom HUD
		panel.anchor_left = 1.0
		panel.anchor_top = 0.08
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -280.0
		panel.offset_right = -8.0
		panel.offset_top = 0.0
		panel.offset_bottom = -120.0

func _switch_tab(tab: int) -> void:
	AudioManager.play_sfx("ui_tap", -4.0)
	_current_tab = tab
	_selected_item = {}
	_refresh()

func _refresh() -> void:
	if not _player:
		return
	_update_tab_style()
	if _current_tab == 0:
		_refresh_equipment()
	else:
		_refresh_bag()
	_refresh_detail()
	_refresh_stats()

func _update_tab_style() -> void:
	equip_tab_btn.add_theme_color_override("font_color", TAB_ACTIVE_COLOR if _current_tab == 0 else TAB_INACTIVE_COLOR)
	bag_tab_btn.add_theme_color_override("font_color", TAB_ACTIVE_COLOR if _current_tab == 1 else TAB_INACTIVE_COLOR)

func _refresh_equipment() -> void:
	for child in content_vbox.get_children():
		child.queue_free()

	var inv = _player.inventory
	var slot_names = ["weapon", "armor", "helm", "boots", "ring", "amulet"]
	var btn_size = Vector2(0, 96) if _is_mobile else Vector2(0, 32)
	var font_size = 34 if _is_mobile else 12

	for slot_name in slot_names:
		var item = inv.equipment.get(slot_name, {})
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6 if _is_mobile else 3)

		# Slot label
		var slot_label = Label.new()
		slot_label.text = slot_name.capitalize() + ":"
		slot_label.custom_minimum_size = Vector2(80 if not _is_mobile else 170, 0)
		slot_label.add_theme_font_size_override("font_size", font_size)
		slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot_label)

		# Item button
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = btn_size
		btn.add_theme_font_size_override("font_size", font_size)

		if item.is_empty():
			btn.text = "-- empty --"
			_style_item_btn(btn, true)
		else:
			btn.text = item.get("name", "?")
			var rarity = item.get("rarity", 0)
			btn.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
			_style_item_btn(btn, false)
			var bound_item = item
			var bound_slot = slot_name
			btn.pressed.connect(func():
				AudioManager.play_sfx("ui_tap", -4.0)
				_selected_item = bound_item
				_refresh_detail()
			)
			btn.mouse_entered.connect(func():
				AudioManager.play_sfx("ui_hover", -8.0)
				_selected_item = bound_item
				_refresh_detail()
			)

		row.add_child(btn)

		# Unequip button
		if not item.is_empty():
			var unequip_btn = Button.new()
			unequip_btn.text = "X"
			unequip_btn.custom_minimum_size = Vector2(36, 0) if not _is_mobile else Vector2(80, 80)
			unequip_btn.add_theme_font_size_override("font_size", font_size)
			unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			unequip_btn.tooltip_text = "Unequip"
			var s_name = slot_name
			unequip_btn.pressed.connect(func():
				AudioManager.play_sfx("ui_tap", -4.0)
				inv.unequip(s_name)
			)
			_style_item_btn(unequip_btn, false)
			row.add_child(unequip_btn)

		content_vbox.add_child(row)

func _refresh_bag() -> void:
	for child in content_vbox.get_children():
		child.queue_free()

	var inv = _player.inventory
	var cols = 3 if not _is_mobile else 2
	var btn_height = 32 if not _is_mobile else 92
	var font_size = 11 if not _is_mobile else 30

	var grid = GridContainer.new()
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6 if _is_mobile else 3)
	grid.add_theme_constant_override("v_separation", 6 if _is_mobile else 3)

	for i in range(inv.bag.size()):
		var item = inv.bag[i]
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, btn_height)
		btn.add_theme_font_size_override("font_size", font_size)
		btn.text = item.get("name", "?")
		var rarity = item.get("rarity", 0)
		btn.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
		btn.clip_text = true
		_style_item_btn(btn, false)

		var idx = i
		var bound_item = item
		if item.get("slot") == ItemData.Slot.CONSUMABLE:
			btn.pressed.connect(func():
				AudioManager.play_sfx("ui_tap", -4.0)
				_player.inventory.move_bag_consumable_to_slot(idx); _refresh()
			)
		else:
			btn.pressed.connect(func():
				AudioManager.play_sfx("ui_tap", -4.0)
				_player.inventory.equip_from_bag(idx); _refresh()
			)
		btn.mouse_entered.connect(func():
			AudioManager.play_sfx("ui_hover", -8.0)
			_selected_item = bound_item
			_refresh_detail()
		)

		grid.add_child(btn)

	# Fill remaining with empty slots
	for i in range(inv.bag.size(), InventoryComponent.MAX_BAG_SLOTS):
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, btn_height)
		btn.add_theme_font_size_override("font_size", font_size)
		btn.text = "---"
		_style_item_btn(btn, true)
		grid.add_child(btn)

	content_vbox.add_child(grid)

func _refresh_detail() -> void:
	if _selected_item.is_empty():
		detail_label.text = "Hover or tap an item to see stats"
		return

	var item = _selected_item
	var rarity_name = ItemData.RARITY_NAMES.get(item.get("rarity", 0), "")
	var text = "%s  (%s)\n" % [item.get("name", ""), rarity_name]
	var desc = item.get("description", "")
	if desc != "":
		text += desc + "\n"
	var stats = item.get("stats", {})
	var stat_parts: Array[String] = []
	for stat_name in stats:
		stat_parts.append("+%s %s" % [str(stats[stat_name]), stat_name.replace("_", " ").capitalize()])
	if stat_parts.size() > 0:
		text += ", ".join(stat_parts)
	if item.has("buy_price"):
		text += "\nValue: %dg" % item["buy_price"]
	detail_label.text = text.strip_edges()

func _refresh_stats() -> void:
	if not _player:
		return
	var s = _player.stats
	var text = "HP:%d/%d  MP:%d/%d  ATK:%d  ARM:%d\nSTR:%d(+%d) AGI:%d(+%d) INT:%d(+%d) SPD:%.0f" % [
		s.current_hp, s.get_total_max_hp(),
		s.current_mana, s.get_total_max_mana(),
		s.attack_damage + s.weapon_damage,
		s.get_total_armor(),
		s.strength, s.bonus_strength,
		s.agility, s.bonus_agility,
		s.intelligence, s.bonus_intelligence,
		s.get_total_move_speed(),
	]
	var buffs = s.get_active_buffs()
	if buffs.size() > 0:
		var buff_parts: Array[String] = []
		for b in buffs:
			var sign = "+" if float(b["amount"]) > 0 else ""
			buff_parts.append("%s%s %s" % [sign, str(b["amount"]), b["stat"].capitalize()])
		text += "\nFX: " + ", ".join(buff_parts)
	stats_label.text = text
