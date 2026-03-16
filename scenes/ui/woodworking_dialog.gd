extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
var _selected_key: String = ""
var _npc_position: Vector2 = Vector2.ZERO
const AUTO_CLOSE_DIST_SQ: float = 22500.0  # 150px

# Double-click/tap quick-build
var _last_click_key: String = ""
var _last_click_time: int = 0
const DOUBLE_CLICK_MS: int = 400

# UI refs built in code
var _title_label: Label
var _wood_label: Label
var _close_btn: Button
var _item_scroll: ScrollContainer
var _item_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_current: Label
var _detail_next: Label
var _detail_cost: Label
var _detail_action_btn: Button
var _detail_close_btn: Button

# Four upgrade tracks — each costs wood and improves a different axis
const UPGRADES = {
	"bow": {
		"title": "Reinforced Bow",
		"desc": "Carved longbow with hardwood limbs. Increases attack damage for all attacks.",
		"max_level": 100,
		"base_cost": 5,
		"color": Color(1.0, 0.6, 0.3),
	},
	"shield": {
		"title": "Wooden Bulwark",
		"desc": "Layered wooden shield and bracing. Grants bonus armor and max HP.",
		"max_level": 100,
		"base_cost": 5,
		"color": Color(0.5, 0.8, 1.0),
	},
	"totem": {
		"title": "Totem of Vigor",
		"desc": "Carved totem that channels nature's strength. Boosts all attributes equally.",
		"max_level": 100,
		"base_cost": 8,
		"color": Color(0.4, 1.0, 0.5),
	},
	"watchtower": {
		"title": "Watchtower",
		"desc": "Build defensive towers with archers. Up to 4 towers, each costs much more. Walk near and press E (or tap) to repair with wood.",
		"max_level": 50,
		"base_cost": 15,
		"color": Color(0.18, 0.82, 0.44),
	},
}

# Placement mode state
var _placing_tower: bool = false
var _placement_ghost: Sprite2D = null
var _watchtower_scene: PackedScene = preload("res://scenes/world/watchtower.tscn")

func _ready() -> void:
	panel.visible = false
	set_process(false)

func setup(player: Node2D) -> void:
	_player = player
	_apply_woodwork_bonuses()

func open(npc_pos: Vector2 = Vector2.ZERO) -> void:
	_npc_position = npc_pos
	_is_visible = true
	set_process(true)
	panel.visible = true
	_detect_mobile()
	_build_ui()
	_selected_key = ""
	_refresh()
	AudioManager.play_sfx("enter_woodworker")

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	if _is_mobile:
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
	else:
		panel.offset_left = -280.0
		panel.offset_right = 280.0
		panel.offset_top = -250.0
		panel.offset_bottom = 250.0

func _process(_delta: float) -> void:
	if _player and _npc_position != Vector2.ZERO:
		if _player.global_position.distance_squared_to(_npc_position) > AUTO_CLOSE_DIST_SQ:
			close()

func close() -> void:
	_is_visible = false
	panel.visible = false
	set_process(false)
	closed.emit()

func _get_level(upgrade_key: String) -> int:
	match upgrade_key:
		"bow": return GameManager.woodwork_bow_level
		"shield": return GameManager.woodwork_shield_level
		"totem": return GameManager.woodwork_totem_level
		"watchtower": return GameManager.woodwork_watchtower_level
	return 0

func _set_level(upgrade_key: String, value: int) -> void:
	match upgrade_key:
		"bow": GameManager.woodwork_bow_level = value
		"shield": GameManager.woodwork_shield_level = value
		"totem": GameManager.woodwork_totem_level = value
		"watchtower": GameManager.woodwork_watchtower_level = value

func _get_cost(upgrade_key: String) -> int:
	var info = UPGRADES[upgrade_key]
	var level = _get_level(upgrade_key)
	return int(info["base_cost"] * pow(level + 1, 1.3))

func _get_bonus_text(upgrade_key: String, level: int) -> String:
	if level == 0:
		return "No bonus yet"
	match upgrade_key:
		"bow":
			return "+%d Attack Damage" % (level * 2)
		"shield":
			return "+%d Armor, +%d Max HP" % [level, level * 4]
		"totem":
			return "+%d STR, +%d AGI, +%d INT" % [level, level, level]
		"watchtower":
			var hp = 200 + (level - 1) * 30
			var atk = 8 + (level - 1) * 3
			return "%d HP, %d ATK" % [hp, atk]
	return ""

func _get_short_bonus(upgrade_key: String, level: int) -> String:
	if level == 0:
		return ""
	match upgrade_key:
		"bow": return "+%d ATK" % (level * 2)
		"shield": return "+%d ARM +%d HP" % [level, level * 4]
		"totem": return "+%d All Stats" % level
		"watchtower":
			var count = GameManager.get_watchtower_count()
			if count == 0:
				return "No towers"
			return "%d tower%s Lv%d" % [count, "s" if count > 1 else "", level]
	return ""

func _build_ui() -> void:
	# Clear old UI from panel
	for child in panel.get_children():
		child.queue_free()

	var fs_title = 52 if _is_mobile else 20
	var fs_normal = 40 if _is_mobile else 14
	var fs_small = 34 if _is_mobile else 12
	var fs_btn = 44 if _is_mobile else 14
	var btn_h = 100 if _is_mobile else 32
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

	# ---- Top bar: Title | Wood | Close ----
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_bar)

	_title_label = Label.new()
	_title_label.text = "Woodworking"
	_title_label.add_theme_font_size_override("font_size", fs_title)
	_title_label.add_theme_color_override("font_color", Color(0.65, 0.45, 0.2))
	top_bar.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_wood_label = Label.new()
	_wood_label.add_theme_font_size_override("font_size", fs_normal)
	_wood_label.add_theme_color_override("font_color", Color(0.65, 0.45, 0.2))
	top_bar.add_child(_wood_label)

	_close_btn = Button.new()
	if _is_mobile:
		_close_btn.text = "X"
		_close_btn.custom_minimum_size = Vector2(160, 130)
		_close_btn.add_theme_font_size_override("font_size", 60)
	else:
		_close_btn.text = "X  [Q]"
		_close_btn.custom_minimum_size = Vector2(120, 40)
		_close_btn.add_theme_font_size_override("font_size", 20)
	_style_btn(_close_btn, Color(1.0, 0.4, 0.3))
	_close_btn.pressed.connect(close)
	top_bar.add_child(_close_btn)

	# ---- Separator ----
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	root_vbox.add_child(sep)

	# Hint
	var hint = Label.new()
	hint.text = "Double-click to quick-build"
	hint.add_theme_font_size_override("font_size", 30 if _is_mobile else 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(hint)

	# ---- Upgrade list (scrollable) ----
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_item_scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 10 if _is_mobile else 2)
	_item_scroll.add_child(_item_list)

	# ---- Detail panel (hidden until upgrade selected) ----
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.12, 0.12, 0.10, 0.95)
	detail_style.border_color = Color(0.5, 0.4, 0.2)
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

	# Detail: description
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", fs_small)
	_detail_desc.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	# Detail: current bonus
	_detail_current = Label.new()
	_detail_current.add_theme_font_size_override("font_size", fs_normal)
	_detail_current.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	detail_vbox.add_child(_detail_current)

	# Detail: next level bonus
	_detail_next = Label.new()
	_detail_next.add_theme_font_size_override("font_size", fs_small)
	_detail_next.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	detail_vbox.add_child(_detail_next)

	# Detail: cost
	_detail_cost = Label.new()
	_detail_cost.add_theme_font_size_override("font_size", fs_normal)
	_detail_cost.add_theme_color_override("font_color", Color(0.65, 0.45, 0.2))
	detail_vbox.add_child(_detail_cost)

	# Detail: action buttons row
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(action_row)

	_detail_action_btn = Button.new()
	_detail_action_btn.custom_minimum_size = Vector2(280 if _is_mobile else 120, btn_h + 10 if _is_mobile else btn_h + 4)
	_detail_action_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_detail_action_btn, Color(0.4, 0.8, 0.3))
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

func _refresh() -> void:
	_wood_label.text = "Wood: %d" % GameManager.wood

	# Clear item list
	for child in _item_list.get_children():
		child.queue_free()

	for key in UPGRADES:
		_add_upgrade_row(key)

	# Refresh detail if one is selected
	if _selected_key != "" and _detail_panel.visible:
		_show_detail(_selected_key)

func _add_upgrade_row(key: String) -> void:
	var info = UPGRADES[key]
	var level = _get_level(key)
	var max_lvl = info["max_level"]
	var fs = 40 if _is_mobile else 14
	var row_h = 100 if _is_mobile else 30

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.16, 0.14, 0.7)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(10 if _is_mobile else 4)
	row_style.border_color = Color(0.3, 0.28, 0.22, 0.4)
	row_style.set_border_width_all(1)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.24, 0.22, 0.18, 0.85)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(10 if _is_mobile else 4)
	hover_style.border_color = Color(0.8, 0.65, 0.2, 0.7)
	hover_style.set_border_width_all(2)

	var row_panel = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.custom_minimum_size = Vector2(0, row_h)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	# Upgrade name
	var name_label = Label.new()
	name_label.text = info["title"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", info["color"])
	name_label.add_theme_font_size_override("font_size", fs)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	# Short bonus text (if any level)
	var short = _get_short_bonus(key, level)
	if short != "":
		var bonus_lbl = Label.new()
		bonus_lbl.text = short
		bonus_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		bonus_lbl.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
		bonus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(bonus_lbl)

	# Level / cost / MAX
	var right_label = Label.new()
	right_label.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if level >= max_lvl:
		right_label.text = "Lv %d MAX" % level
		right_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	else:
		right_label.text = "Lv %d" % level
		right_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(right_label)

	# Clickable overlay
	var btn_overlay = Button.new()
	btn_overlay.flat = true
	btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.set_corner_radius_all(6)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.8, 0.65, 0.2, 0.08)
	btn_hover.set_corner_radius_all(6)
	btn_hover.border_color = Color(0.8, 0.65, 0.2, 0.5)
	btn_hover.set_border_width_all(1)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.8, 0.65, 0.2, 0.15)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.border_color = Color(1.0, 0.85, 0.4, 0.7)
	btn_pressed.set_border_width_all(2)
	btn_overlay.add_theme_stylebox_override("normal", btn_normal)
	btn_overlay.add_theme_stylebox_override("hover", btn_hover)
	btn_overlay.add_theme_stylebox_override("pressed", btn_pressed)
	btn_overlay.add_theme_stylebox_override("focus", btn_hover)
	var k = key
	btn_overlay.pressed.connect(func():
		AudioManager.play_sfx("ui_tap", -4.0)
		var now = Time.get_ticks_msec()
		if _last_click_key == k and (now - _last_click_time) <= DOUBLE_CLICK_MS:
			_last_click_key = ""
			_last_click_time = 0
			_do_upgrade(k)
			return
		_last_click_key = k
		_last_click_time = now
		_show_detail(k)
	)
	btn_overlay.mouse_entered.connect(func():
		AudioManager.play_sfx("ui_hover", -8.0)
		row_panel.add_theme_stylebox_override("panel", hover_style)
	)
	btn_overlay.mouse_exited.connect(func():
		row_panel.add_theme_stylebox_override("panel", row_style)
	)
	row_panel.add_child(btn_overlay)

	_item_list.add_child(row_panel)

func _show_detail(key: String) -> void:
	_selected_key = key
	var info = UPGRADES[key]
	var level = _get_level(key)
	var max_lvl = info["max_level"]

	_detail_panel.visible = true

	_detail_name.text = info["title"]
	_detail_name.add_theme_color_override("font_color", info["color"])

	_detail_desc.text = info["desc"]

	_detail_current.text = "Current (Lv %d): %s" % [level, _get_bonus_text(key, level)]

	if level >= max_lvl:
		_detail_next.text = "MAX LEVEL"
		_detail_next.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		_detail_cost.text = ""
		_detail_action_btn.visible = false
	else:
		var cost = _get_cost(key)
		_detail_next.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		_detail_action_btn.visible = true

		if key == "watchtower":
			var count = GameManager.get_watchtower_count()
			if _watchtower_wants_new_tower():
				var build_cost = _get_watchtower_build_cost()
				if level == 0:
					_detail_next.text = "Build your first Watchtower!"
				else:
					_detail_next.text = "Build tower %d of %d" % [count + 1, GameManager.MAX_WATCHTOWERS]
				_detail_cost.text = "Cost: %d wood" % build_cost
				_detail_action_btn.text = "Build & Place (%d wood)" % build_cost
				_detail_action_btn.disabled = GameManager.wood < build_cost
			else:
				_detail_next.text = "Next (Lv %d): %s" % [level + 1, _get_bonus_text(key, level + 1)]
				_detail_cost.text = "Cost: %d wood" % cost
				_detail_action_btn.text = "Upgrade All (%d wood)" % cost
				_detail_action_btn.disabled = GameManager.wood < cost
		else:
			_detail_next.text = "Next (Lv %d): %s" % [level + 1, _get_bonus_text(key, level + 1)]
			_detail_cost.text = "Cost: %d wood" % cost
			_detail_action_btn.text = "Build (%d wood)" % cost
			_detail_action_btn.disabled = GameManager.wood < cost
		# Reconnect
		for conn in _detail_action_btn.pressed.get_connections():
			_detail_action_btn.pressed.disconnect(conn["callable"])
		var k = key
		_detail_action_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap", -4.0)
			_do_upgrade(k)
		)

func _hide_detail() -> void:
	_detail_panel.visible = false
	_selected_key = ""

func _do_upgrade(key: String) -> void:
	var level = _get_level(key)
	var max_lvl = UPGRADES[key]["max_level"]
	if level >= max_lvl:
		return
	var cost = _get_cost(key)
	if GameManager.wood < cost:
		GameManager.game_message.emit("Not enough wood!", Color(1, 0.3, 0.3))
		return

	# Watchtower: first build or new tower enters placement mode
	if key == "watchtower" and _watchtower_wants_new_tower():
		var slot_cost = _get_watchtower_build_cost()
		if GameManager.wood < slot_cost:
			GameManager.game_message.emit("Not enough wood! Need %d." % slot_cost, Color(1, 0.3, 0.3))
			return
		GameManager.spend_wood(slot_cost)
		_placement_cost_paid = slot_cost
		if level == 0:
			_set_level(key, 1)
		_apply_woodwork_bonuses()
		close()
		_start_placement_mode()
		return

	GameManager.spend_wood(cost)
	_set_level(key, level + 1)
	_apply_woodwork_bonuses()
	_refresh()

	# If watchtower upgrade, update existing tower stats
	if key == "watchtower":
		_upgrade_existing_tower()

	var new_lvl = _get_level(key)
	GameManager.game_message.emit(
		"%s upgraded to level %d!" % [UPGRADES[key]["title"], new_lvl],
		UPGRADES[key]["color"]
	)
	AudioManager.play_sfx("woodwork_" + key, -6.0)
	var tw = create_tween()
	tw.tween_property(panel, "modulate", Color(0.9, 1.2, 0.85), 0.1)
	tw.tween_property(panel, "modulate", Color(1, 1, 1), 0.25)

func _apply_woodwork_bonuses() -> void:
	if not _player:
		return
	var s = _player.stats
	# Bow: +2 attack per level
	s.woodwork_attack_bonus = GameManager.woodwork_bow_level * 2
	# Shield: +1 armor, +4 HP per level
	s.woodwork_armor_bonus = GameManager.woodwork_shield_level
	s.woodwork_hp_bonus = GameManager.woodwork_shield_level * 4
	# Totem: +1 STR/AGI/INT per level via direct bonus stats
	var totem_lvl = GameManager.woodwork_totem_level
	if not _player.has_meta("_woodwork_totem_applied"):
		_player.set_meta("_woodwork_totem_applied", 0)
	var prev = _player.get_meta("_woodwork_totem_applied")
	var diff = totem_lvl - prev
	if diff != 0:
		s.bonus_strength += diff
		s.bonus_agility += diff
		s.bonus_intelligence += diff
		_player.set_meta("_woodwork_totem_applied", totem_lvl)
	# Watchtower is a physical building now — no passive XP bonus
	s._emit_all()

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

func _watchtower_wants_new_tower() -> bool:
	var level = _get_level("watchtower")
	if level == 0:
		return true  # First tower ever
	# Has upgrade level but can build more towers
	var count = GameManager.get_watchtower_count()
	return count < GameManager.MAX_WATCHTOWERS

func _get_watchtower_build_cost() -> int:
	var base = UPGRADES["watchtower"]["base_cost"]
	var level = _get_level("watchtower")
	var level_cost = int(base * pow(level + 1, 1.3)) if level == 0 else 0
	var slot_cost = GameManager.get_watchtower_slot_cost(base)
	return level_cost + slot_cost

func _upgrade_existing_tower() -> void:
	for tower in get_tree().get_nodes_in_group("watchtower"):
		if is_instance_valid(tower) and not tower._is_destroyed:
			var extra = GameManager.watchtowers[tower.tower_index].get("level", 0) if tower.tower_index >= 0 and tower.tower_index < GameManager.watchtowers.size() else 0
			tower.setup(GameManager.woodwork_watchtower_level, tower.current_hp, extra)

func _start_placement_mode() -> void:
	_placing_tower = true
	# Create ghost preview
	_placement_ghost = Sprite2D.new()
	_placement_ghost.texture = SpriteGenerator.get_texture("watch_tower")
	_placement_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_placement_ghost.modulate = Color(0.5, 1.0, 0.5, 0.5)
	_placement_ghost.z_index = 100
	_placement_ghost.position = Vector2(0, -16)  # Match tower sprite offset
	var world_nodes = get_tree().get_nodes_in_group("world")
	var world = world_nodes[0] if world_nodes.size() > 0 else get_tree().current_scene
	# Wrap in a Node2D so we can move the container
	var ghost_container = Node2D.new()
	ghost_container.name = "PlacementGhost"
	ghost_container.add_child(_placement_ghost)
	world.add_child(ghost_container)
	_placement_ghost = ghost_container
	GameManager.game_message.emit("Click to place your Watchtower!", Color(0.18, 0.82, 0.44))

# Store the cost paid when entering placement mode so we can refund exactly
var _placement_cost_paid: int = 0

func _cancel_placement() -> void:
	_placing_tower = false
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_placement_ghost.queue_free()
		_placement_ghost = null
	# Refund the wood spent
	GameManager.add_wood(_placement_cost_paid)
	# If this was the very first tower, reset level back to 0
	if GameManager.get_watchtower_count() == 0 and GameManager.woodwork_watchtower_level == 1:
		_set_level("watchtower", 0)
	_placement_cost_paid = 0
	GameManager.game_message.emit("Watchtower placement cancelled. Wood refunded.", Color(0.7, 0.7, 0.7))

func _place_tower(world_pos: Vector2) -> void:
	_placing_tower = false
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_placement_ghost.queue_free()
		_placement_ghost = null

	# Find first available slot
	var slot := -1
	for i in range(GameManager.MAX_WATCHTOWERS):
		if not GameManager.watchtowers[i]["built"]:
			slot = i
			break
	if slot < 0:
		GameManager.game_message.emit("All tower slots are full!", Color(1.0, 0.3, 0.3))
		return

	# Spawn the actual watchtower
	var tower = _watchtower_scene.instantiate()
	tower.global_position = world_pos
	tower.tower_index = slot
	var world_nodes = get_tree().get_nodes_in_group("world")
	var world = world_nodes[0] if world_nodes.size() > 0 else get_tree().current_scene
	world.add_child(tower)
	tower.setup(GameManager.woodwork_watchtower_level)

	# Save state in multi-tower array
	GameManager.watchtowers[slot] = {
		"built": true,
		"pos_x": world_pos.x,
		"pos_y": world_pos.y,
		"hp": tower.current_hp,
		"level": 0,
	}
	# Legacy compat
	GameManager.watchtower_built = true
	GameManager.watchtower_pos_x = world_pos.x
	GameManager.watchtower_pos_y = world_pos.y
	GameManager.watchtower_hp = tower.current_hp

	var count = GameManager.get_watchtower_count()
	GameManager.game_message.emit(
		"Watchtower %d built! It will defend the area." % count,
		Color(0.25, 0.9, 0.5)
	)
	AudioManager.play_sfx("woodwork_watchtower", -6.0)

func _unhandled_input(event: InputEvent) -> void:
	# Placement mode input handling
	if _placing_tower:
		if event.is_action_pressed("ui_cancel"):
			_cancel_placement()
			get_viewport().set_input_as_handled()
			return
		# Update ghost position
		var world_pos := Vector2.ZERO
		var got_pos := false
		if event is InputEventMouseMotion:
			world_pos = _screen_to_world(event.position)
			got_pos = true
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			world_pos = _screen_to_world(event.position)
			_place_tower(world_pos)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventScreenTouch and event.pressed:
			world_pos = _screen_to_world(event.position)
			_place_tower(world_pos)
			get_viewport().set_input_as_handled()
			return
		if got_pos and _placement_ghost and is_instance_valid(_placement_ghost):
			_placement_ghost.global_position = world_pos
		return

	if not _is_visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1"):
		if _detail_panel.visible:
			_hide_detail()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x >= 0 and not panel.get_global_rect().has_point(pos):
		close()
		get_viewport().set_input_as_handled()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var cam = get_viewport().get_camera_2d()
	if cam:
		var vp_size = get_viewport().get_visible_rect().size
		var offset = screen_pos - vp_size / 2.0
		return cam.global_position + offset / cam.zoom
	return screen_pos
