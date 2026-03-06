extends CanvasLayer

## Hero stats panel — right-click on your hero to view all stats and active buffs/debuffs.

@onready var panel: PanelContainer = $Panel
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/VBox/Scroll/ScrollContent/StatsLabel
@onready var buffs_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/ScrollContent/BuffsContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var _dim: ColorRect = $Dim

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false
var _buff_refresh_timer: float = 0.0
const BUFF_REFRESH_INTERVAL: float = 1.0  # Refresh buff display once per second, not every frame

# ── Colours ──
const COL_BG        = Color(0.06, 0.06, 0.08, 1.0)
const COL_BORDER    = Color(0.55, 0.45, 0.2, 0.6)
const COL_TITLE     = Color(1.0, 0.92, 0.65)
const COL_LABEL     = Color(0.55, 0.52, 0.48)
const COL_VALUE     = Color(0.92, 0.9, 0.85)
const COL_BONUS_POS = Color(0.4, 1.0, 0.55)
const COL_BONUS_NEG = Color(1.0, 0.4, 0.4)
const COL_HP        = Color(0.85, 0.25, 0.22)
const COL_MANA      = Color(0.3, 0.55, 1.0)
const COL_SECTION   = Color(0.75, 0.65, 0.4)
const COL_DIM       = Color(0.0, 0.0, 0.0, 0.45)
const COL_CLOSE_BG  = Color(0.18, 0.16, 0.13, 0.9)
const COL_CLOSE_BRD = Color(0.5, 0.4, 0.2, 0.5)
const COL_CLOSE_HOV = Color(0.25, 0.22, 0.16, 0.95)

func _ready() -> void:
	panel.visible = false
	_dim.visible = false
	close_button.pressed.connect(close)
	_style_panel()

func setup(player: Node2D) -> void:
	_player = player

func toggle() -> void:
	_is_visible = !_is_visible
	panel.visible = _is_visible
	_dim.visible = _is_visible
	if _is_visible:
		_buff_refresh_timer = 0.0
		_detect_mobile()
		_refresh()

func open() -> void:
	_is_visible = true
	panel.visible = true
	_dim.visible = true
	_buff_refresh_timer = 0.0
	_detect_mobile()
	_refresh()

func close() -> void:
	_is_visible = false
	panel.visible = false
	_dim.visible = false

func _style_panel() -> void:
	# Panel background
	var bg = StyleBoxFlat.new()
	bg.bg_color = COL_BG
	bg.border_color = COL_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(12)
	bg.shadow_color = Color(0, 0, 0, 0.35)
	bg.shadow_size = 8
	panel.add_theme_stylebox_override("panel", bg)

	# Close button styling
	var cb_normal = StyleBoxFlat.new()
	cb_normal.bg_color = COL_CLOSE_BG
	cb_normal.border_color = COL_CLOSE_BRD
	cb_normal.set_border_width_all(1)
	cb_normal.set_corner_radius_all(6)
	cb_normal.set_content_margin_all(4)
	var cb_hover = cb_normal.duplicate()
	cb_hover.bg_color = COL_CLOSE_HOV
	cb_hover.border_color = Color(0.7, 0.55, 0.25, 0.7)
	var cb_pressed = cb_normal.duplicate()
	cb_pressed.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	close_button.add_theme_stylebox_override("normal", cb_normal)
	close_button.add_theme_stylebox_override("hover", cb_hover)
	close_button.add_theme_stylebox_override("pressed", cb_pressed)
	close_button.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.65))

	# Dim overlay
	_dim.color = COL_DIM

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	if _is_mobile:
		var margin = 16.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 48)
		close_button.text = "X"
		close_button.add_theme_font_size_override("font_size", 60)
		close_button.custom_minimum_size = Vector2(160, 130)
		stats_label.add_theme_font_size_override("normal_font_size", 34)
		$Panel/MarginContainer/VBox/Scroll/ScrollContent/BuffsTitle.add_theme_font_size_override("font_size", 40)

var _buff_refresh_timer: float = 0.0
const BUFF_REFRESH_INTERVAL: float = 0.5  # Refresh buffs twice per second, not every frame


func _process(delta: float) -> void:
	if _is_visible and _player:
		_buff_refresh_timer -= delta
		if _buff_refresh_timer <= 0.0:
			_buff_refresh_timer = BUFF_REFRESH_INTERVAL
			_refresh_buffs()

func _refresh() -> void:
	if not _player:
		return
	_refresh_stats()
	_refresh_buffs()

# ── Stats display ──

func _refresh_stats() -> void:
	var s = _player.stats
	var total_atk = s.attack_damage + s.weapon_damage + s.armory_weapon_bonus + s.woodwork_attack_bonus
	var lines: Array[String] = []

	# Header
	lines.append("[color=#%s]Level %d[/color]  ·  [color=#%s]%s[/color]" % [
		COL_VALUE.to_html(false), s.level,
		COL_TITLE.to_html(false), _player.hero_class.replace("_", " ").capitalize(),
	])
	lines.append("")

	# Vitals
	lines.append(_stat_line("HP", "%d / %d" % [s.current_hp, s.get_total_max_hp()], COL_HP))
	lines.append(_stat_line("Mana", "%d / %d" % [s.current_mana, s.get_total_max_mana()], COL_MANA))
	lines.append("")

	# Core attributes
	lines.append(_stat_line("Strength", str(s.strength + s.bonus_strength) + _bonus_text(s.bonus_strength)))
	lines.append(_stat_line("Agility", str(s.agility + s.bonus_agility) + _bonus_text(s.bonus_agility)))
	lines.append(_stat_line("Intelligence", str(s.intelligence + s.bonus_intelligence) + _bonus_text(s.bonus_intelligence)))
	lines.append("")

	# Secondary stats
	lines.append(_stat_line("Armor", str(s.get_total_armor())))
	lines.append(_stat_line("Attack", str(total_atk)))
	lines.append(_stat_line("Speed", "%.0f" % s.get_total_move_speed()))
	lines.append(_stat_line("Dodge", "%d%%" % int(s.temp_dodge * 100)))
	lines.append(_stat_line("XP Bonus", "+%d%%" % int(s.woodwork_xp_mult * 100)))
	lines.append("")

	# Kill stats
	lines.append(_stat_line("Total Kills", str(GameManager.total_kills), COL_TITLE))
	# Show next milestone
	var next_milestone := 0
	for m in GameManager.KILL_MILESTONES:
		if m["kills"] not in GameManager._claimed_milestones:
			next_milestone = m["kills"]
			break
	if next_milestone > 0:
		lines.append(_stat_line("Next Milestone", "%d kills" % next_milestone))

	stats_label.bbcode_enabled = true
	stats_label.text = "\n".join(lines)

func _stat_line(label: String, value: String, value_color: Color = COL_VALUE) -> String:
	return "[color=#%s]%s[/color]   [color=#%s]%s[/color]" % [
		COL_LABEL.to_html(false), label,
		value_color.to_html(false), value,
	]

func _bonus_text(bonus: int) -> String:
	if bonus > 0:
		return "  [color=#%s](+%d)[/color]" % [COL_BONUS_POS.to_html(false), bonus]
	elif bonus < 0:
		return "  [color=#%s](%d)[/color]" % [COL_BONUS_NEG.to_html(false), bonus]
	return ""

# ── Buffs display ──

func _refresh_buffs() -> void:
	for child in buffs_container.get_children():
		child.queue_free()

	if not _player:
		return

	var active = _player.stats.get_active_buffs()
	if active.size() == 0:
		var none_label = Label.new()
		none_label.text = "No active effects"
		none_label.add_theme_font_size_override("font_size", 32 if _is_mobile else 12)
		none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		buffs_container.add_child(none_label)
		return

	for buff in active:
		var entry = _create_buff_entry(buff)
		buffs_container.add_child(entry)

func _create_buff_entry(buff: Dictionary) -> PanelContainer:
	var is_debuff = buff.get("is_debuff", false)

	# Outer container with subtle background
	var outer = PanelContainer.new()
	var entry_bg = StyleBoxFlat.new()
	entry_bg.bg_color = Color(1, 0.3, 0.2, 0.06) if is_debuff else Color(0.3, 1, 0.4, 0.06)
	entry_bg.set_corner_radius_all(6)
	entry_bg.set_content_margin_all(6 if not _is_mobile else 10)
	outer.add_theme_stylebox_override("panel", entry_bg)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	outer.add_child(hbox)

	# Icon
	var icon = Label.new()
	icon.add_theme_font_size_override("font_size", 38 if _is_mobile else 15)
	if is_debuff:
		icon.text = "▼"
		icon.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	else:
		icon.text = "▲"
		icon.add_theme_color_override("font_color", Color(0.35, 1, 0.55))
	hbox.add_child(icon)

	# Buff info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	var buff_name = _get_buff_display_name(buff["id"])
	var stat_text = _get_stat_effect_text(buff["stat"], buff["amount"])
	name_label.text = "%s  %s" % [buff_name, stat_text]
	name_label.add_theme_font_size_override("font_size", 34 if _is_mobile else 13)
	name_label.add_theme_color_override("font_color", Color(1, 0.55, 0.5) if is_debuff else Color(0.5, 1, 0.7))
	info.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = _get_buff_description(buff["id"])
	desc_label.add_theme_font_size_override("font_size", 30 if _is_mobile else 11)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	hbox.add_child(info)

	# Timer
	var timer_label = Label.new()
	var mins = int(buff["time_left"]) / 60
	var secs = int(buff["time_left"]) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	timer_label.add_theme_font_size_override("font_size", 38 if _is_mobile else 14)
	timer_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.custom_minimum_size = Vector2(130, 0) if _is_mobile else Vector2(48, 0)
	hbox.add_child(timer_label)

	return outer

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
