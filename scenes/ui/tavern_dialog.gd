extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

# UI refs built in code
var _title_label: Label
var _gold_label: Label
var _close_btn: Button
var _active_label: Label
var _visit_btn: Button
var _result_label: Label

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
		panel.offset_left = -240.0
		panel.offset_right = 240.0
		panel.offset_top = -180.0
		panel.offset_bottom = 180.0

func close() -> void:
	_is_visible = false
	panel.visible = false
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

	# Result label (shows after visiting)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", fs_normal)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.visible = false
	root_vbox.add_child(_result_label)

	# Spacer to push button down
	var mid_spacer = Control.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(mid_spacer)

	# Visit button
	_visit_btn = Button.new()
	_visit_btn.custom_minimum_size = Vector2(0, btn_h + 16 if _is_mobile else btn_h + 8)
	_visit_btn.add_theme_font_size_override("font_size", fs_btn + 4 if _is_mobile else fs_btn + 2)
	_visit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(_visit_btn, Color(0.9, 0.4, 0.5))
	_visit_btn.pressed.connect(_on_visit)
	root_vbox.add_child(_visit_btn)

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	_visit_btn.text = "Visit the Wench (%dg)" % VISIT_COST
	_visit_btn.disabled = GameManager.gold < VISIT_COST

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

	# Show result in dialog
	_result_label.text = chosen["name"] + " — " + chosen["desc"]
	_result_label.add_theme_color_override("font_color", chosen["color"])
	_result_label.visible = true

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
