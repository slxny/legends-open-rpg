extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var gold_label: Label = $Panel/MarginContainer/VBox/TopBar/GoldLabel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var content: VBoxContainer = $Panel/MarginContainer/VBox/Content

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
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
	close_button.pressed.connect(close)

func setup(player: Node2D) -> void:
	_player = player

func open() -> void:
	if not _player:
		return
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
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 40)
		gold_label.add_theme_font_size_override("font_size", 32)
		close_button.add_theme_font_size_override("font_size", 28)
		close_button.custom_minimum_size = Vector2(180, 60)

func close() -> void:
	_is_visible = false
	panel.visible = false
	closed.emit()

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold

	for child in content.get_children():
		child.queue_free()

	# Flavorful header
	var header = Label.new()
	header.text = "The Lusty Wench"
	header.add_theme_font_size_override("font_size", 36 if _is_mobile else 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.4, 0.5))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	var desc = Label.new()
	desc.text = "A dimly lit establishment of... companionship.\nPay gold to spend time with one of the wenches.\nYou might gain a useful skill... or catch something."
	desc.add_theme_font_size_override("font_size", 24 if _is_mobile else 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	content.add_child(sep)

	# Show active tavern buff/debuff if any
	if _player:
		var active = _get_active_tavern_buff()
		if not active.is_empty():
			var active_label = Label.new()
			var mins = int(active["time_left"]) / 60
			var secs = int(active["time_left"]) % 60
			var buff_type = "Affliction" if active["is_debuff"] else "Blessing"
			active_label.text = "Active %s: %s (%d:%02d remaining)" % [buff_type, active["id"].replace("tavern_", "").capitalize(), mins, secs]
			active_label.add_theme_font_size_override("font_size", 24 if _is_mobile else 12)
			active_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if active["is_debuff"] else Color(0.3, 1, 0.5))
			content.add_child(active_label)

			var sep2 = HSeparator.new()
			sep2.add_theme_constant_override("separation", 6)
			content.add_child(sep2)

	# Cost and button
	var hbox = HBoxContainer.new()

	var cost_info = Label.new()
	cost_info.text = "Spend a night: %dg" % VISIT_COST
	cost_info.add_theme_font_size_override("font_size", 28 if _is_mobile else 14)
	cost_info.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	hbox.add_child(cost_info)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var visit_btn = Button.new()
	visit_btn.text = "Visit the Wench"
	visit_btn.custom_minimum_size = Vector2(260, 72) if _is_mobile else Vector2(130, 36)
	if _is_mobile:
		visit_btn.add_theme_font_size_override("font_size", 26)
	visit_btn.pressed.connect(_on_visit)
	if GameManager.gold < VISIT_COST:
		visit_btn.disabled = true
	content.add_child(hbox)
	hbox.add_child(visit_btn)

	# Odds hint
	var odds = Label.new()
	odds.text = "80% chance of a blessing, 20% chance of... complications."
	odds.add_theme_font_size_override("font_size", 20 if _is_mobile else 10)
	odds.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	content.add_child(odds)

func _on_visit() -> void:
	if not _player:
		return
	if not GameManager.spend_gold(VISIT_COST):
		GameManager.game_message.emit("Not enough gold!", Color(1, 0.3, 0.3))
		return

	AudioManager.play_sfx("gold_pickup", -3.0)

	# Remove any existing tavern buff/debuff first
	_clear_tavern_buffs()

	# 80% buff, 20% debuff
	var is_debuff = randf() < 0.2
	var chosen: Dictionary

	if is_debuff:
		chosen = DEBUFFS[randi() % DEBUFFS.size()]
	else:
		chosen = BUFFS[randi() % BUFFS.size()]

	# Apply to player stats
	_player.stats.apply_timed_buff(
		chosen["id"],
		chosen["stat"],
		chosen["amount"],
		chosen["duration"],
		is_debuff
	)

	# Show result message
	var result_color = chosen.get("color", Color.WHITE)
	if is_debuff:
		GameManager.game_message.emit(chosen["name"] + ": " + chosen["desc"], result_color)
	else:
		GameManager.game_message.emit(chosen["name"] + ": " + chosen["desc"], result_color)

	_refresh()

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

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
