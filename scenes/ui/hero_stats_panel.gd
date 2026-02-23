extends CanvasLayer

## Hero stats panel — right-click on your hero to view all stats and active buffs/debuffs.

@onready var panel: PanelContainer = $Panel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/Scroll/ScrollContent/StatsLabel
@onready var buffs_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/ScrollContent/BuffsContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)

func setup(player: Node2D) -> void:
	_player = player

func toggle() -> void:
	_is_visible = !_is_visible
	panel.visible = _is_visible
	if _is_visible:
		_detect_mobile()
		_refresh()

func open() -> void:
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = DisplayServer.is_touchscreen_available() or min(vp_size.x, vp_size.y) < 700
	if _is_mobile:
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 52)
		close_button.add_theme_font_size_override("font_size", 38)
		close_button.custom_minimum_size = Vector2(220, 68)
		stats_label.add_theme_font_size_override("font_size", 36)
		$Panel/MarginContainer/VBox/Scroll/ScrollContent/BuffsTitle.add_theme_font_size_override("font_size", 42)

func close() -> void:
	_is_visible = false
	panel.visible = false

func _process(_delta: float) -> void:
	# Live-update buff timers while panel is open
	if _is_visible and _player:
		_refresh_buffs()

func _refresh() -> void:
	if not _player:
		return
	_refresh_stats()
	_refresh_buffs()

func _refresh_stats() -> void:
	var s = _player.stats
	var total_atk = s.attack_damage + s.weapon_damage + s.armory_weapon_bonus + s.woodwork_attack_bonus
	stats_label.text = """Level %d  |  %s

HP: %d / %d
Mana: %d / %d

Strength:     %d%s
Agility:      %d%s
Intelligence: %d%s
Armor:        %d
Attack:       %d
Speed:        %.0f
Dodge:        %d%%
XP Bonus:     +%d%%""" % [
		s.level, _player.hero_class.replace("_", " ").capitalize(),
		s.current_hp, s.get_total_max_hp(),
		s.current_mana, s.get_total_max_mana(),
		s.strength + s.bonus_strength, _bonus_text(s.bonus_strength),
		s.agility + s.bonus_agility, _bonus_text(s.bonus_agility),
		s.intelligence + s.bonus_intelligence, _bonus_text(s.bonus_intelligence),
		s.get_total_armor(),
		total_atk,
		s.get_total_move_speed(),
		int(s.temp_dodge * 100),
		int(s.woodwork_xp_mult * 100),
	]

func _bonus_text(bonus: int) -> String:
	if bonus > 0:
		return "  (+%d)" % bonus
	elif bonus < 0:
		return "  (%d)" % bonus
	return ""

func _refresh_buffs() -> void:
	for child in buffs_container.get_children():
		child.queue_free()

	if not _player:
		return

	var active = _player.stats.get_active_buffs()
	if active.size() == 0:
		var none_label = Label.new()
		none_label.text = "No active effects"
		none_label.add_theme_font_size_override("font_size", 34 if _is_mobile else 12)
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		buffs_container.add_child(none_label)
		return

	for buff in active:
		var entry = _create_buff_entry(buff)
		buffs_container.add_child(entry)

func _create_buff_entry(buff: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Icon indicator
	var icon = Label.new()
	icon.add_theme_font_size_override("font_size", 40 if _is_mobile else 14)
	if buff.get("is_debuff", false):
		icon.text = "[-]"
		icon.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		icon.text = "[+]"
		icon.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	hbox.add_child(icon)

	# Buff info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name + stat effect
	var name_label = Label.new()
	var buff_name = _get_buff_display_name(buff["id"])
	var stat_text = _get_stat_effect_text(buff["stat"], buff["amount"])
	name_label.text = "%s  %s" % [buff_name, stat_text]
	name_label.add_theme_font_size_override("font_size", 36 if _is_mobile else 13)
	if buff.get("is_debuff", false):
		name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 1, 0.7))
	info.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = _get_buff_description(buff["id"])
	desc_label.add_theme_font_size_override("font_size", 32 if _is_mobile else 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	info.add_child(desc_label)

	hbox.add_child(info)

	# Timer
	var timer_label = Label.new()
	var mins = int(buff["time_left"]) / 60
	var secs = int(buff["time_left"]) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	timer_label.add_theme_font_size_override("font_size", 40 if _is_mobile else 14)
	timer_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.custom_minimum_size = Vector2(140, 0) if _is_mobile else Vector2(50, 0)
	hbox.add_child(timer_label)

	return hbox

func _get_stat_effect_text(stat: String, amount) -> String:
	var sign = "+" if float(amount) > 0 else ""
	match stat:
		"strength": return "(%s%d STR)" % [sign, int(amount)]
		"agility": return "(%s%d AGI)" % [sign, int(amount)]
		"intelligence": return "(%s%d INT)" % [sign, int(amount)]
		"armor": return "(%s%d Armor)" % [sign, int(amount)]
		"max_hp": return "(%s%d Max HP)" % [sign, int(amount)]
		"max_mana": return "(%s%d Max Mana)" % [sign, int(amount)]
		"move_speed": return "(%s%.0f Speed)" % [sign, float(amount)]
		"attack_damage": return "(%s%d Attack)" % [sign, int(amount)]
		"dodge": return "(%s%d%% Dodge)" % [sign, int(float(amount) * 100)]
	return ""

# Map buff IDs to display names from tavern_dialog data
const BUFF_NAMES: Dictionary = {
	"tavern_str": "Brute's Vigor",
	"tavern_agi": "Nimble Fingers",
	"tavern_int": "Pillow Talk",
	"tavern_armor": "Thick Skin",
	"tavern_hp": "Hearty Constitution",
	"tavern_spd": "Spring in Your Step",
	"tavern_dmg": "Lover's Fury",
	"tavern_dodge": "Dancer's Grace",
	"tavern_itch": "The Itch",
	"tavern_fog": "Brain Fog",
	"tavern_weak": "Wobbly Legs",
	"tavern_rash": "Suspicious Rash",
}

const BUFF_DESCS: Dictionary = {
	"tavern_str": "She liked it rough. You feel empowered.",
	"tavern_agi": "You learned some new moves. Feeling limber.",
	"tavern_int": "She whispered ancient secrets between the sheets.",
	"tavern_armor": "What doesn't kill you... she was quite aggressive.",
	"tavern_hp": "A good time does wonders for the body.",
	"tavern_spd": "You're practically skipping out the door.",
	"tavern_dmg": "Passion ignites your battle spirit.",
	"tavern_dodge": "She taught you how to move your hips.",
	"tavern_itch": "Something doesn't feel right down there...",
	"tavern_fog": "Can't think straight. Was it the ale or the company?",
	"tavern_weak": "Your legs are like jelly. Worth it though.",
	"tavern_rash": "Red bumps. Probably nothing. Probably.",
}

func _get_buff_display_name(buff_id: String) -> String:
	return BUFF_NAMES.get(buff_id, buff_id.replace("_", " ").capitalize())

func _get_buff_description(buff_id: String) -> String:
	return BUFF_DESCS.get(buff_id, "")

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
