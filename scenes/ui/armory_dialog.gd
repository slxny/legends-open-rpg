extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
var _selected_key: String = ""

# Double-click/tap quick-upgrade
var _last_click_key: String = ""
var _last_click_time: int = 0
const DOUBLE_CLICK_MS: int = 400

# UI refs built in code
var _title_label: Label
var _gold_label: Label
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

const UPGRADES = {
	"weapon": {
		"title": "Weapon Forge",
		"desc": "Tempered steel and sharpened edges. Increases base attack damage for all attacks.",
		"max_level": 100,
		"color": Color(1.0, 0.7, 0.3),
	},
	"armor": {
		"title": "Armor Forge",
		"desc": "Reinforced plating and chain links. Grants bonus armor and max HP.",
		"max_level": 100,
		"color": Color(0.5, 0.7, 1.0),
	},
}

func _ready() -> void:
	panel.visible = false

func setup(player: Node2D) -> void:
	_player = player
	_apply_armory_bonuses()

func open() -> void:
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_build_ui()
	_selected_key = ""
	_refresh()
	AudioManager.play_sfx("enter_shop")

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
		panel.offset_top = -220.0
		panel.offset_bottom = 220.0

func close() -> void:
	_is_visible = false
	panel.visible = false
	closed.emit()

func _get_level(key: String) -> int:
	match key:
		"weapon": return GameManager.weapon_upgrade_level
		"armor": return GameManager.armor_upgrade_level
	return 0

func _get_cost(key: String) -> int:
	return GameManager.get_upgrade_cost(_get_level(key))

func _get_weapon_bonus(level: int) -> int:
	# Slightly accelerating: +2 per level base, +0.03 per level squared
	return int(level * 2 + level * level * 0.03)

func _get_armor_bonus(level: int) -> int:
	return int(level + level * level * 0.01)

func _get_hp_bonus(level: int) -> int:
	return int(level * 3 + level * level * 0.05)

func _get_bonus_text(key: String, level: int) -> String:
	if level == 0:
		return "No bonus yet"
	match key:
		"weapon": return "+%d Attack Damage" % _get_weapon_bonus(level)
		"armor": return "+%d Armor, +%d Max HP" % [_get_armor_bonus(level), _get_hp_bonus(level)]
	return ""

func _get_short_bonus(key: String, level: int) -> String:
	if level == 0:
		return ""
	match key:
		"weapon": return "+%d ATK" % _get_weapon_bonus(level)
		"armor": return "+%d ARM +%d HP" % [_get_armor_bonus(level), _get_hp_bonus(level)]
	return ""

func _build_ui() -> void:
	for child in panel.get_children():
		child.queue_free()

	var fs_title = 52 if _is_mobile else 20
	var fs_normal = 40 if _is_mobile else 14
	var fs_small = 34 if _is_mobile else 12
	var fs_btn = 44 if _is_mobile else 14
	var btn_h = 100 if _is_mobile else 32
	var margin_px = 16 if _is_mobile else 12

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

	# Top bar
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_bar)

	_title_label = Label.new()
	_title_label.text = "Armory"
	_title_label.add_theme_font_size_override("font_size", fs_title)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
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
		_close_btn.custom_minimum_size = Vector2(160, 130)
		_close_btn.add_theme_font_size_override("font_size", 60)
	else:
		_close_btn.text = "X  [Q]"
		_close_btn.custom_minimum_size = Vector2(120, 40)
		_close_btn.add_theme_font_size_override("font_size", 20)
	_style_btn(_close_btn, Color(1.0, 0.4, 0.3))
	_close_btn.pressed.connect(close)
	top_bar.add_child(_close_btn)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	root_vbox.add_child(sep)

	# Hint
	var hint = Label.new()
	hint.text = "Double-click to quick-upgrade"
	hint.add_theme_font_size_override("font_size", 30 if _is_mobile else 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(hint)

	# Upgrade list
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_item_scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 10 if _is_mobile else 2)
	_item_scroll.add_child(_item_list)

	# Detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.visible = false
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	detail_style.border_color = Color(0.5, 0.4, 0.25)
	detail_style.set_border_width_all(2)
	detail_style.set_corner_radius_all(6)
	detail_style.set_content_margin_all(margin_px)
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	root_vbox.add_child(_detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 4 if _is_mobile else 2)
	_detail_panel.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", fs_title - 4)
	detail_vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", fs_small)
	_detail_desc.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	_detail_current = Label.new()
	_detail_current.add_theme_font_size_override("font_size", fs_normal)
	_detail_current.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	detail_vbox.add_child(_detail_current)

	_detail_next = Label.new()
	_detail_next.add_theme_font_size_override("font_size", fs_small)
	detail_vbox.add_child(_detail_next)

	_detail_cost = Label.new()
	_detail_cost.add_theme_font_size_override("font_size", fs_normal)
	_detail_cost.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	detail_vbox.add_child(_detail_cost)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(action_row)

	_detail_action_btn = Button.new()
	_detail_action_btn.custom_minimum_size = Vector2(280 if _is_mobile else 120, btn_h + 10 if _is_mobile else btn_h + 4)
	_detail_action_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_detail_action_btn, Color(0.3, 0.8, 0.4))
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
	_gold_label.text = "Gold: %d" % GameManager.gold

	for child in _item_list.get_children():
		child.queue_free()

	for key in UPGRADES:
		_add_upgrade_row(key)

	if _selected_key != "" and _detail_panel.visible:
		_show_detail(_selected_key)

func _add_upgrade_row(key: String) -> void:
	var info = UPGRADES[key]
	var level = _get_level(key)
	var max_lvl = info["max_level"]
	var fs = 40 if _is_mobile else 14
	var row_h = 100 if _is_mobile else 30

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.16, 0.20, 0.7)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(10 if _is_mobile else 4)
	row_style.border_color = Color(0.3, 0.28, 0.22, 0.4)
	row_style.set_border_width_all(1)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.24, 0.22, 0.28, 0.85)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(10 if _is_mobile else 4)
	hover_style.border_color = Color(0.9, 0.75, 0.3, 0.7)
	hover_style.set_border_width_all(2)

	var row_panel = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.custom_minimum_size = Vector2(0, row_h)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	var name_label = Label.new()
	name_label.text = info["title"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", info["color"])
	name_label.add_theme_font_size_override("font_size", fs)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var short = _get_short_bonus(key, level)
	if short != "":
		var bonus_lbl = Label.new()
		bonus_lbl.text = short
		bonus_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		bonus_lbl.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
		bonus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(bonus_lbl)

	var right_label = Label.new()
	right_label.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if level >= max_lvl:
		right_label.text = "Lv %d MAX" % level
		right_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	else:
		var cost = _get_cost(key)
		right_label.text = "Lv %d  %dg" % [level, cost]
		right_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(right_label)

	# Clickable overlay with double-click support
	var btn_overlay = Button.new()
	btn_overlay.flat = true
	btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.set_corner_radius_all(6)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.9, 0.75, 0.3, 0.08)
	btn_hover.set_corner_radius_all(6)
	btn_hover.border_color = Color(0.9, 0.75, 0.3, 0.5)
	btn_hover.set_border_width_all(1)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.9, 0.75, 0.3, 0.15)
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
		_detail_next.text = "Next (Lv %d): %s" % [level + 1, _get_bonus_text(key, level + 1)]
		_detail_next.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		_detail_cost.text = "Cost: %dg" % cost
		_detail_action_btn.visible = true
		_detail_action_btn.text = "Upgrade (%dg)" % cost
		_detail_action_btn.disabled = GameManager.gold < cost
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
	if not GameManager.spend_gold(cost):
		GameManager.game_message.emit("Not enough gold!", Color(1, 0.3, 0.3))
		return

	match key:
		"weapon": GameManager.weapon_upgrade_level += 1
		"armor": GameManager.armor_upgrade_level += 1

	_apply_armory_bonuses()
	_refresh()

	var new_level = _get_level(key)
	GameManager.game_message.emit(
		"%s upgraded to level %d!" % [UPGRADES[key]["title"], new_level],
		UPGRADES[key]["color"]
	)
	AudioManager.play_sfx("forge_weapon" if key == "weapon" else "forge_armor", -8.0)
	var tw = create_tween()
	tw.tween_property(panel, "modulate", Color(1.3, 1.15, 0.8), 0.1)
	tw.tween_property(panel, "modulate", Color(1, 1, 1), 0.25)

func _apply_armory_bonuses() -> void:
	if not _player:
		return
	_player.stats.armory_weapon_bonus = _get_weapon_bonus(GameManager.weapon_upgrade_level)
	_player.stats.armory_armor_bonus = _get_armor_bonus(GameManager.armor_upgrade_level)
	_player.stats.armory_hp_bonus = _get_hp_bonus(GameManager.armor_upgrade_level)
	_player.stats._emit_all()

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
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x >= 0 and not panel.get_global_rect().has_point(pos):
		close()
		get_viewport().set_input_as_handled()
