extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
var _selected_buff: Dictionary = {}

# Double-click quick-visit tracking
var _last_click_id: String = ""
var _last_click_time: int = 0
const DOUBLE_CLICK_MS: int = 400
var _pending_detail_timer: SceneTreeTimer = null
var _pending_detail_buff: Dictionary = {}

# UI refs built in code
var _title_label: Label
var _gold_label: Label
var _close_btn: Button
var _item_scroll: ScrollContainer
var _item_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_effect: Label
var _detail_duration: Label
var _detail_cost: Label
var _detail_action_btn: Button
var _detail_close_btn: Button
var _active_label: Label

const VISIT_COST: int = 50

# Buffs: { id, name, description, stat, amount, duration, color }
const BUFFS: Array[Dictionary] = [
	{"id": "tavern_str", "name": "Brute's Vigor", "desc": "She liked it rough. You feel empowered.", "stat": "strength", "amount": 8, "duration": 600.0, "color": Color(1, 0.4, 0.3)},
	{"id": "tavern_agi", "name": "Nimble Fingers", "desc": "You learned some new moves. Feeling limber.", "stat": "agility", "amount": 8, "duration": 600.0, "color": Color(0.3, 1, 0.4)},
	{"id": "tavern_int", "name": "Pillow Talk", "desc": "She whispered ancient secrets between the sheets.", "stat": "intelligence", "amount": 8, "duration": 600.0, "color": Color(0.4, 0.5, 1)},
	{"id": "tavern_armor", "name": "Thick Skin", "desc": "What doesn't kill you... she was quite aggressive.", "stat": "armor", "amount": 5, "duration": 600.0, "color": Color(0.8, 0.7, 0.3)},
	{"id": "tavern_hp", "name": "Hearty Constitution", "desc": "A good time does wonders for the body.", "stat": "max_hp", "amount": 40, "duration": 600.0, "color": Color(1, 0.3, 0.5)},
	{"id": "tavern_spd", "name": "Spring in Your Step", "desc": "You're practically skipping out the door.", "stat": "move_speed", "amount": 25.0, "duration": 600.0, "color": Color(0.3, 0.8, 0.9)},
	{"id": "tavern_dmg", "name": "Lover's Fury", "desc": "Passion ignites your battle spirit.", "stat": "attack_damage", "amount": 6, "duration": 600.0, "color": Color(1, 0.5, 0.2)},
	{"id": "tavern_dodge", "name": "Dancer's Grace", "desc": "She taught you how to move your hips.", "stat": "dodge", "amount": 0.08, "duration": 600.0, "color": Color(0.7, 0.3, 1)},
]

# Debuffs: same structure but negative / harmful
const DEBUFFS: Array[Dictionary] = [
	{"id": "tavern_itch", "name": "The Itch", "desc": "Something doesn't feel right down there...", "stat": "agility", "amount": -5, "duration": 300.0, "color": Color(0.6, 0.8, 0.2)},
	{"id": "tavern_fog", "name": "Brain Fog", "desc": "Can't think straight. Was it the ale or the company?", "stat": "intelligence", "amount": -6, "duration": 300.0, "color": Color(0.5, 0.5, 0.3)},
	{"id": "tavern_weak", "name": "Wobbly Legs", "desc": "Your legs are like jelly. Worth it though.", "stat": "move_speed", "amount": -20.0, "duration": 300.0, "color": Color(0.7, 0.4, 0.6)},
	{"id": "tavern_rash", "name": "Suspicious Rash", "desc": "Red bumps. Probably nothing. Probably.", "stat": "armor", "amount": -4, "duration": 300.0, "color": Color(0.9, 0.3, 0.2)},
]

func _ready() -> void:
	panel.visible = false

func setup(player: Node2D) -> void:
	_player = player

func open() -> void:
	if not _player:
		return
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_build_ui()
	_selected_buff = {}
	_refresh()
	AudioManager.play_sfx("enter_tavern")

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

func close() -> void:
	_is_visible = false
	panel.visible = false
	_cancel_pending_detail()
	closed.emit()

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
	_title_label.text = "The Lusty Wench"
	_title_label.add_theme_font_size_override("font_size", fs_title)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.5))
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
		_close_btn.text = "Close [Q]"
		_close_btn.custom_minimum_size = Vector2(90, 30)
		_close_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_close_btn, Color(1.0, 0.4, 0.3))
	_close_btn.pressed.connect(close)
	top_bar.add_child(_close_btn)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	root_vbox.add_child(sep)

	# Description
	var desc = Label.new()
	desc.text = "Pay gold for companionship. 80% chance of a blessing, 20% risk of... complications."
	desc.add_theme_font_size_override("font_size", fs_small)
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(desc)

	# Active buff status
	_active_label = Label.new()
	_active_label.add_theme_font_size_override("font_size", fs_small)
	_active_label.visible = false
	root_vbox.add_child(_active_label)

	# Double-click hint
	var hint = Label.new()
	hint.text = "Double-click a buff to visit directly (%dg)" % VISIT_COST
	hint.add_theme_font_size_override("font_size", 30 if _is_mobile else 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(hint)

	# Buff list (scrollable)
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
	detail_style.bg_color = Color(0.14, 0.10, 0.12, 0.95)
	detail_style.border_color = Color(0.6, 0.3, 0.35)
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

	_detail_effect = Label.new()
	_detail_effect.add_theme_font_size_override("font_size", fs_normal)
	detail_vbox.add_child(_detail_effect)

	_detail_duration = Label.new()
	_detail_duration.add_theme_font_size_override("font_size", fs_small)
	_detail_duration.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	detail_vbox.add_child(_detail_duration)

	_detail_cost = Label.new()
	_detail_cost.add_theme_font_size_override("font_size", fs_normal)
	_detail_cost.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	detail_vbox.add_child(_detail_cost)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(action_row)

	_detail_action_btn = Button.new()
	_detail_action_btn.custom_minimum_size = Vector2(280 if _is_mobile else 140, btn_h + 10 if _is_mobile else btn_h + 4)
	_detail_action_btn.add_theme_font_size_override("font_size", fs_btn)
	_style_btn(_detail_action_btn, Color(0.9, 0.4, 0.5))
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

	# Active buff
	if _player:
		var active = _get_active_tavern_buff()
		if not active.is_empty():
			var mins = int(active["time_left"]) / 60
			var secs = int(active["time_left"]) % 60
			var buff_type = "Affliction" if active["is_debuff"] else "Blessing"
			_active_label.text = "Active %s: %s (%d:%02d)" % [buff_type, active["id"].replace("tavern_", "").capitalize(), mins, secs]
			_active_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if active["is_debuff"] else Color(0.3, 1, 0.5))
			_active_label.visible = true
		else:
			_active_label.visible = false

	for child in _item_list.get_children():
		child.queue_free()

	# Show all possible buffs as browsable list
	for buff in BUFFS:
		_add_buff_row(buff, false)

	if _selected_buff.size() > 0 and _detail_panel.visible:
		_show_detail(_selected_buff)

func _get_effect_text(buff: Dictionary) -> String:
	var sign = "+" if buff["amount"] > 0 else ""
	var val = buff["amount"]
	if buff["stat"] == "dodge":
		return "%s%d%% %s" % [sign, int(val * 100), buff["stat"].capitalize()]
	return "%s%s %s" % [sign, str(int(val)), buff["stat"].replace("_", " ").capitalize()]

func _add_buff_row(buff: Dictionary, _is_debuff: bool) -> void:
	var fs = 40 if _is_mobile else 14
	var row_h = 100 if _is_mobile else 30

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.16, 0.14, 0.16, 0.7)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(10 if _is_mobile else 4)
	row_style.border_color = Color(0.3, 0.25, 0.25, 0.4)
	row_style.set_border_width_all(1)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.26, 0.20, 0.22, 0.85)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(10 if _is_mobile else 4)
	hover_style.border_color = Color(0.9, 0.4, 0.5, 0.7)
	hover_style.set_border_width_all(2)

	var row_panel = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.custom_minimum_size = Vector2(0, row_h)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	var name_label = Label.new()
	name_label.text = buff["name"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", buff["color"])
	name_label.add_theme_font_size_override("font_size", fs)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	var effect_label = Label.new()
	effect_label.text = _get_effect_text(buff)
	effect_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	effect_label.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(effect_label)

	# Clickable overlay with double-click
	var btn_overlay = Button.new()
	btn_overlay.flat = true
	btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.set_corner_radius_all(6)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.9, 0.4, 0.5, 0.08)
	btn_hover.set_corner_radius_all(6)
	btn_hover.border_color = Color(0.9, 0.4, 0.5, 0.5)
	btn_hover.set_border_width_all(1)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.9, 0.4, 0.5, 0.15)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.border_color = Color(1.0, 0.5, 0.6, 0.7)
	btn_pressed.set_border_width_all(2)
	btn_overlay.add_theme_stylebox_override("normal", btn_normal)
	btn_overlay.add_theme_stylebox_override("hover", btn_hover)
	btn_overlay.add_theme_stylebox_override("pressed", btn_pressed)
	btn_overlay.add_theme_stylebox_override("focus", btn_hover)
	var b = buff
	btn_overlay.pressed.connect(func():
		AudioManager.play_sfx("ui_tap", -4.0)
		var now = Time.get_ticks_msec()
		if _last_click_id == b["id"] and (now - _last_click_time) <= DOUBLE_CLICK_MS:
			_cancel_pending_detail()
			_last_click_id = ""
			_last_click_time = 0
			_on_visit()
			return
		_last_click_id = b["id"]
		_last_click_time = now
		_pending_detail_buff = b
		_cancel_pending_detail()
		_pending_detail_timer = get_tree().create_timer(DOUBLE_CLICK_MS / 1000.0)
		_pending_detail_timer.timeout.connect(func():
			_pending_detail_timer = null
			if _pending_detail_buff.size() > 0:
				_show_detail(_pending_detail_buff)
				_pending_detail_buff = {}
		)
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

func _show_detail(buff: Dictionary) -> void:
	_selected_buff = buff
	_detail_panel.visible = true

	_detail_name.text = buff["name"]
	_detail_name.add_theme_color_override("font_color", buff["color"])
	_detail_desc.text = buff["desc"]

	_detail_effect.text = "Effect: %s" % _get_effect_text(buff)
	_detail_effect.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))

	var mins = int(buff["duration"]) / 60
	_detail_duration.text = "Duration: %d minutes" % mins

	_detail_cost.text = "Cost: %dg (random outcome)" % VISIT_COST

	_detail_action_btn.visible = true
	_detail_action_btn.text = "Visit (%dg)" % VISIT_COST
	_detail_action_btn.disabled = GameManager.gold < VISIT_COST
	for conn in _detail_action_btn.pressed.get_connections():
		_detail_action_btn.pressed.disconnect(conn["callable"])
	_detail_action_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap", -4.0)
		_on_visit()
	)

func _hide_detail() -> void:
	_detail_panel.visible = false
	_selected_buff = {}
	_last_click_id = ""

func _cancel_pending_detail() -> void:
	if _pending_detail_timer != null:
		if _pending_detail_timer.timeout.get_connections().size() > 0:
			for conn in _pending_detail_timer.timeout.get_connections():
				_pending_detail_timer.timeout.disconnect(conn["callable"])
		_pending_detail_timer = null
	_pending_detail_buff = {}

func _on_visit() -> void:
	if not _player:
		return
	if not GameManager.spend_gold(VISIT_COST):
		GameManager.game_message.emit("Not enough gold!", Color(1, 0.3, 0.3))
		return

	AudioManager.play_sfx("gold_pickup", -3.0)
	_clear_tavern_buffs()

	# 80% buff, 20% debuff
	var is_debuff = randf() < 0.2
	var chosen: Dictionary
	if is_debuff:
		chosen = DEBUFFS[randi() % DEBUFFS.size()]
	else:
		chosen = BUFFS[randi() % BUFFS.size()]

	_player.stats.apply_timed_buff(
		chosen["id"],
		chosen["stat"],
		chosen["amount"],
		chosen["duration"],
		is_debuff
	)

	AudioManager.play_sfx("wench_debuff" if is_debuff else "wench_buff")
	GameManager.game_message.emit(chosen["name"] + ": " + chosen["desc"], chosen.get("color", Color.WHITE))

	_hide_detail()
	_refresh()

	# Visual flash
	var flash_color = Color(1.0, 0.8, 0.85) if not is_debuff else Color(0.85, 1.0, 0.8)
	var tw = create_tween()
	tw.tween_property(panel, "modulate", flash_color, 0.1)
	tw.tween_property(panel, "modulate", Color(1, 1, 1), 0.25)

func _clear_tavern_buffs() -> void:
	if not _player:
		return
	for buff_data in BUFFS:
		_player.stats.remove_buff(buff_data["id"])
	for debuff_data in DEBUFFS:
		_player.stats.remove_buff(debuff_data["id"])

func _get_active_tavern_buff() -> Dictionary:
	if not _player:
		return {}
	for b in _player.stats.get_active_buffs():
		if b["id"].begins_with("tavern_"):
			return b
	return {}

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
