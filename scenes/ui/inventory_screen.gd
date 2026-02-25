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
var _is_landscape: bool = false
var _current_tab: int = 0  # 0 = Equipment, 1 = Bag
var _selected_item: Dictionary = {}
var _selected_bag_index: int = -1
var _last_tap_index: int = -1
var _last_tap_time: float = 0.0
const DOUBLE_TAP_WINDOW: float = 0.4

const TAB_ACTIVE_COLOR := Color(1.0, 0.85, 0.4)
const TAB_INACTIVE_COLOR := Color(0.6, 0.6, 0.6)

const SLOT_NAMES = {
	ItemData.Slot.WEAPON: "weapon",
	ItemData.Slot.ARMOR: "armor",
	ItemData.Slot.HELM: "helm",
	ItemData.Slot.BOOTS: "boots",
	ItemData.Slot.RING: "ring",
	ItemData.Slot.AMULET: "amulet",
}

func _slot_name_for_item(item: Dictionary) -> String:
	return SLOT_NAMES.get(item.get("slot", -1), "")

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
	elif _is_visible:
		var pos := Vector2(-1, -1)
		if event is InputEventMouseButton and event.pressed:
			pos = event.position
		elif event is InputEventScreenTouch and event.pressed:
			pos = event.position
		if pos.x >= 0 and not panel.get_global_rect().has_point(pos):
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	_is_visible = !_is_visible
	panel.visible = _is_visible
	if _is_visible:
		_selected_item = {}
		_selected_bag_index = -1
		_last_tap_index = -1
		_detect_mobile()
		_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	_is_landscape = vp_size.x > vp_size.y
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
		# Scale all sizes relative to shorter screen dimension for consistency
		var base_dim = min(vp_size.x, vp_size.y)
		var scale = base_dim / 1080.0
		var fs_title = int(48 * scale)
		var fs_tab = int(40 * scale)
		var tab_h = int(72 * scale)
		var fs_detail = int(34 * scale)
		var fs_stats = int(30 * scale)
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", fs_title)
		equip_tab_btn.add_theme_font_size_override("font_size", fs_tab)
		equip_tab_btn.custom_minimum_size.y = tab_h
		bag_tab_btn.add_theme_font_size_override("font_size", fs_tab)
		bag_tab_btn.custom_minimum_size.y = tab_h
		detail_label.add_theme_font_size_override("font_size", fs_detail)
		stats_label.add_theme_font_size_override("font_size", fs_stats)
		# Always show the fixed detail panel — it stays at the bottom, items scroll above
		$Panel/MarginContainer/VBox/DetailPanel.visible = true
		$Panel/MarginContainer/VBox/Sep2.visible = true
		$Panel/MarginContainer/VBox/Sep3.visible = false
		stats_label.visible = false
		# Replace keyboard hint with close button (only once)
		var close_hint = $Panel/MarginContainer/VBox/TopBar.get_node_or_null("CloseHint")
		if close_hint:
			close_hint.queue_free()
		var close_sz = Vector2(int(120 * scale), int(80 * scale))
		var close_fs = int(44 * scale)
		if not $Panel/MarginContainer/VBox/TopBar.get_node_or_null("MobileCloseBtn"):
			var close_btn = Button.new()
			close_btn.name = "MobileCloseBtn"
			close_btn.text = "X"
			close_btn.custom_minimum_size = close_sz
			close_btn.add_theme_font_size_override("font_size", close_fs)
			close_btn.pressed.connect(toggle)
			$Panel/MarginContainer/VBox/TopBar.add_child(close_btn)
		else:
			var existing_btn = $Panel/MarginContainer/VBox/TopBar.get_node("MobileCloseBtn")
			existing_btn.custom_minimum_size = close_sz
			existing_btn.add_theme_font_size_override("font_size", close_fs)
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
		# Show fixed detail panel on desktop
		$Panel/MarginContainer/VBox/DetailPanel.visible = true
		$Panel/MarginContainer/VBox/Sep2.visible = true
		$Panel/MarginContainer/VBox/Sep3.visible = true
		stats_label.visible = true

func _switch_tab(tab: int) -> void:
	AudioManager.play_sfx("ui_tap", -4.0)
	_current_tab = tab
	_selected_item = {}
	_selected_bag_index = -1
	_last_tap_index = -1
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
	var vp_size_local = get_viewport().get_visible_rect().size
	var scale = min(vp_size_local.x, vp_size_local.y) / 1080.0
	var btn_h: int
	var font_size: int
	if not _is_mobile:
		btn_h = 32; font_size = 12
	else:
		btn_h = int(60 * scale); font_size = int(26 * scale)
	var btn_size = Vector2(0, btn_h)

	for slot_name in slot_names:
		var item = inv.equipment.get(slot_name, {})
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(8 * scale) if _is_mobile else 3)

		# Slot label
		var slot_label = Label.new()
		slot_label.text = slot_name.capitalize() + ":"
		var lbl_w = 80 if not _is_mobile else int(130 * scale)
		slot_label.custom_minimum_size = Vector2(lbl_w, 0)
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
			btn.pressed.connect(func():
				AudioManager.play_sfx("ui_tap", -4.0)
				_selected_item = bound_item
				_selected_bag_index = -1
				_refresh_detail()
			)
			btn.mouse_entered.connect(func():
				AudioManager.play_sfx("ui_hover", -8.0)
				_selected_item = bound_item
				_selected_bag_index = -1
				_refresh_detail()
			)

		row.add_child(btn)

		# Unequip button
		if not item.is_empty():
			var unequip_btn = Button.new()
			unequip_btn.text = "X"
			var uneq_sz = Vector2(36, 0) if not _is_mobile else Vector2(int(60 * scale), int(60 * scale))
			unequip_btn.custom_minimum_size = uneq_sz
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
	var vp_size_local = get_viewport().get_visible_rect().size
	var scale = min(vp_size_local.x, vp_size_local.y) / 1080.0
	var cols: int
	var btn_height: int
	var font_size: int
	var spacing: int
	if not _is_mobile:
		cols = 3; btn_height = 32; font_size = 11; spacing = 3
	else:
		cols = 3; btn_height = int(56 * scale); font_size = int(24 * scale); spacing = int(6 * scale)

	var grid = GridContainer.new()
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", spacing)
	grid.add_theme_constant_override("v_separation", spacing)

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
		btn.pressed.connect(_on_bag_item_pressed.bind(idx, bound_item))
		btn.mouse_entered.connect(func():
			AudioManager.play_sfx("ui_hover", -8.0)
			_selected_item = bound_item
			_selected_bag_index = idx
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

func _get_item_stat_line(item: Dictionary) -> String:
	var stats = item.get("stats", {})
	var parts: Array[String] = []
	for stat_name in stats:
		parts.append("+%s %s" % [str(stats[stat_name]), stat_name.replace("_", " ").capitalize()])
	return ", ".join(parts)

func _get_item_detail_text(item: Dictionary) -> String:
	var rarity_name = ItemData.RARITY_NAMES.get(item.get("rarity", 0), "")
	var text = "%s (%s)" % [item.get("name", ""), rarity_name]
	var stat_line = _get_item_stat_line(item)
	if stat_line != "":
		text += " — " + stat_line
	if item.has("buy_price"):
		text += "  [%dg]" % item["buy_price"]
	return text

func _get_comparison_text(bag_item: Dictionary, equipped_item: Dictionary) -> String:
	# Compact: item name + stats on one line, equipped on next, diff on third
	var text = _get_item_detail_text(bag_item)
	if equipped_item.is_empty():
		text += "\nEquipped: (empty)"
	else:
		text += "\nEquipped: " + _get_item_detail_text(equipped_item)
	# Stat diff
	var bag_stats = bag_item.get("stats", {})
	var eq_stats = equipped_item.get("stats", {})
	var all_keys: Dictionary = {}
	for k in bag_stats:
		all_keys[k] = true
	for k in eq_stats:
		all_keys[k] = true
	var diffs: Array[String] = []
	for k in all_keys:
		var bag_val = bag_stats.get(k, 0)
		var eq_val = eq_stats.get(k, 0)
		var diff = bag_val - eq_val
		if diff != 0:
			var sign = "+" if diff > 0 else ""
			diffs.append("%s%d %s" % [sign, diff, k.replace("_", " ").capitalize()])
	if diffs.size() > 0:
		text += "\n" + ", ".join(diffs)
	text += "  [2x tap = equip]"
	return text

func _refresh_detail() -> void:
	# Always use the fixed detail_label at the bottom of the panel
	if _selected_item.is_empty():
		detail_label.text = "Tap item to see stats, double-tap to equip"
		return

	if _selected_bag_index >= 0 and _player:
		var inv = _player.inventory
		var slot_name = _slot_name_for_item(_selected_item)
		var equipped = inv.equipment.get(slot_name, {}) if not slot_name.is_empty() else {}
		detail_label.text = _get_comparison_text(_selected_item, equipped)
	else:
		detail_label.text = _get_item_detail_text(_selected_item)

func _refresh_stats() -> void:
	if not _player:
		return
	if not stats_label.visible:
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

func _on_bag_item_pressed(idx: int, item: Dictionary) -> void:
	AudioManager.play_sfx("ui_tap", -4.0)
	var now = Time.get_ticks_msec() / 1000.0
	if _last_tap_index == idx and (now - _last_tap_time) < DOUBLE_TAP_WINDOW:
		# Double-tap — equip the item
		_last_tap_index = -1
		_last_tap_time = 0.0
		_player.inventory.equip_from_bag(idx)
		_refresh()
		return
	# Single tap — select and show comparison in the fixed detail panel
	_last_tap_index = idx
	_last_tap_time = now
	_selected_item = item
	_selected_bag_index = idx
	_refresh_detail()
