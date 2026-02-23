extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var wood_label: Label = $Panel/MarginContainer/VBox/TopBar/WoodLabel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var content: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Content

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

func _make_btn_normal_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.18, 0.14, 0.9)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.4, 0.45, 0.3, 0.6)
	s.set_border_width_all(1)
	return s

func _make_btn_hover_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.24, 0.28, 0.20, 0.95)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.8, 0.9, 0.4, 0.8)
	s.set_border_width_all(2)
	return s

func _make_btn_pressed_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.30, 0.34, 0.18, 0.95)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.95, 1.0, 0.5, 0.95)
	s.set_border_width_all(2)
	return s

func _make_btn_disabled_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.14, 0.6)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.25, 0.25, 0.25, 0.4)
	s.set_border_width_all(1)
	return s

func _style_action_btn(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_btn_normal_style())
	btn.add_theme_stylebox_override("hover", _make_btn_hover_style())
	btn.add_theme_stylebox_override("pressed", _make_btn_pressed_style())
	btn.add_theme_stylebox_override("disabled", _make_btn_disabled_style())
	btn.add_theme_stylebox_override("focus", _make_btn_hover_style())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Four upgrade tracks — each costs wood and improves a different axis
# Costs scale: base * (level + 1)^1.3
const UPGRADES = {
	"bow": {
		"title": "Reinforced Bow",
		"desc": "Carved longbow with hardwood limbs.",
		"max_level": 20,
		"base_cost": 5,
		"color": Color(1.0, 0.6, 0.3),
	},
	"shield": {
		"title": "Wooden Bulwark",
		"desc": "Layered wooden shield and bracing.",
		"max_level": 20,
		"base_cost": 5,
		"color": Color(0.5, 0.8, 1.0),
	},
	"totem": {
		"title": "Totem of Vigor",
		"desc": "Carved totem that channels nature's strength.",
		"max_level": 15,
		"base_cost": 8,
		"color": Color(0.4, 1.0, 0.5),
	},
	"watchtower": {
		"title": "Watchtower",
		"desc": "Tall lookout that sharpens your awareness.",
		"max_level": 10,
		"base_cost": 12,
		"color": Color(1.0, 0.9, 0.4),
	},
}

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)

func setup(player: Node2D) -> void:
	_player = player
	_apply_woodwork_bonuses()

func open() -> void:
	_is_visible = true
	panel.visible = true
	_detect_mobile()
	_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = DisplayServer.is_touchscreen_available()
	if _is_mobile:
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 56)
		wood_label.add_theme_font_size_override("font_size", 44)
		close_button.text = "X"
		close_button.add_theme_font_size_override("font_size", 50)
		close_button.custom_minimum_size = Vector2(120, 100)

func close() -> void:
	_is_visible = false
	panel.visible = false
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
	match upgrade_key:
		"bow":
			return "+%d Attack Damage" % (level * 2)
		"shield":
			return "+%d Armor, +%d Max HP" % [level, level * 4]
		"totem":
			return "+%d STR, +%d AGI, +%d INT" % [level, level, level]
		"watchtower":
			return "+%d%% XP Gain" % (level * 8)
	return ""

func _refresh() -> void:
	wood_label.text = "Wood: %d" % GameManager.wood

	for child in content.get_children():
		child.queue_free()

	for key in UPGRADES:
		_add_upgrade_row(key)

func _add_upgrade_row(key: String) -> void:
	var info = UPGRADES[key]
	var level = _get_level(key)
	var max_lvl = info["max_level"]
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8 if _is_mobile else 3)

	# Header
	var header = Label.new()
	header.text = info["title"]
	header.add_theme_font_size_override("font_size", 48 if _is_mobile else 15)
	header.add_theme_color_override("font_color", info["color"])
	section.add_child(header)

	# Description
	var desc = Label.new()
	desc.text = info["desc"]
	desc.add_theme_font_size_override("font_size", 36 if _is_mobile else 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	section.add_child(desc)

	# Current bonus
	var bonus = Label.new()
	bonus.text = "Lv %d/%d — %s" % [level, max_lvl, _get_bonus_text(key, level)]
	bonus.add_theme_font_size_override("font_size", 38 if _is_mobile else 12)
	bonus.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	section.add_child(bonus)

	if level < max_lvl:
		var cost = _get_cost(key)
		# Next level
		var next = Label.new()
		next.text = "Next: %s" % _get_bonus_text(key, level + 1)
		next.add_theme_font_size_override("font_size", 36 if _is_mobile else 11)
		next.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		section.add_child(next)

		# Cost + button
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var cost_lbl = Label.new()
		cost_lbl.text = "%d wood" % cost
		cost_lbl.add_theme_font_size_override("font_size", 40 if _is_mobile else 13)
		cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.45, 0.2))
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(cost_lbl)

		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

		var btn = Button.new()
		btn.text = "Build"
		btn.custom_minimum_size = Vector2(300, 100) if _is_mobile else Vector2(90, 34)
		btn.add_theme_font_size_override("font_size", 42 if _is_mobile else 13)
		_style_action_btn(btn)
		var k = key
		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap", -4.0)
			_do_upgrade(k)
		)
		if GameManager.wood < cost:
			btn.disabled = true
		hbox.add_child(btn)
		section.add_child(hbox)
	else:
		var max_label = Label.new()
		max_label.text = "MAX LEVEL"
		max_label.add_theme_font_size_override("font_size", 40 if _is_mobile else 13)
		max_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		section.add_child(max_label)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	section.add_child(sep)
	content.add_child(section)

func _do_upgrade(key: String) -> void:
	var level = _get_level(key)
	var max_lvl = UPGRADES[key]["max_level"]
	if level >= max_lvl:
		return
	var cost = _get_cost(key)
	if not GameManager.spend_wood(cost):
		GameManager.game_message.emit("Not enough wood!", Color(1, 0.3, 0.3))
		return

	_set_level(key, level + 1)
	_apply_woodwork_bonuses()
	_refresh()

	var new_lvl = _get_level(key)
	GameManager.game_message.emit(
		"%s upgraded to level %d!" % [UPGRADES[key]["title"], new_lvl],
		UPGRADES[key]["color"]
	)
	AudioManager.play_sfx("woodwork_" + key, -6.0)
	# Brief green-tinted flash on the panel to confirm the build
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
	# Totem: +1 STR/AGI/INT per level via timed buff system would be complex,
	# so we apply it directly to bonus stats
	var totem_lvl = GameManager.woodwork_totem_level
	# Store previous totem values to avoid stacking on re-apply
	if not _player.has_meta("_woodwork_totem_applied"):
		_player.set_meta("_woodwork_totem_applied", 0)
	var prev = _player.get_meta("_woodwork_totem_applied")
	var diff = totem_lvl - prev
	if diff != 0:
		s.bonus_strength += diff
		s.bonus_agility += diff
		s.bonus_intelligence += diff
		_player.set_meta("_woodwork_totem_applied", totem_lvl)
	# Watchtower: +8% XP per level
	s.woodwork_xp_mult = GameManager.woodwork_watchtower_level * 0.08
	s._emit_all()

func _unhandled_input(event: InputEvent) -> void:
	if _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		close()
		get_viewport().set_input_as_handled()
