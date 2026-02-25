extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var gold_label: Label = $Panel/MarginContainer/VBox/TopBar/GoldLabel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var content: VBoxContainer = $Panel/MarginContainer/VBox/Content

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

func _make_btn_normal_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.17, 0.24, 0.9)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.45, 0.4, 0.3, 0.6)
	s.set_border_width_all(1)
	return s

func _make_btn_hover_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.26, 0.24, 0.32, 0.95)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(0.9, 0.75, 0.3, 0.8)
	s.set_border_width_all(2)
	return s

func _make_btn_pressed_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.32, 0.30, 0.20, 0.95)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8 if _is_mobile else 4)
	s.border_color = Color(1.0, 0.85, 0.4, 0.95)
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

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)

func setup(player: Node2D) -> void:
	_player = player
	# Apply any existing armory upgrades on game start
	_apply_armory_bonuses()

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
		gold_label.add_theme_font_size_override("font_size", 44)
		close_button.text = "X"
		close_button.add_theme_font_size_override("font_size", 60)
		close_button.custom_minimum_size = Vector2(160, 130)

func close() -> void:
	_is_visible = false
	panel.visible = false
	closed.emit()

func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold

	for child in content.get_children():
		child.queue_free()

	_add_upgrade_section("Weapon", GameManager.weapon_upgrade_level, "weapon")
	_add_upgrade_section("Armor", GameManager.armor_upgrade_level, "armor")

func _add_upgrade_section(title: String, current_level: int, upgrade_type: String) -> void:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8 if _is_mobile else 4)

	# Header
	var header = Label.new()
	header.text = "%s Forge" % title
	header.add_theme_font_size_override("font_size", 50 if _is_mobile else 16)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	section.add_child(header)

	# Level display
	var level_label = Label.new()
	level_label.text = "Level: %d / 100" % current_level
	level_label.add_theme_font_size_override("font_size", 44 if _is_mobile else 14)
	section.add_child(level_label)

	# Current bonus
	var bonus_label = Label.new()
	if upgrade_type == "weapon":
		bonus_label.text = "Current: +%d Attack Damage" % (current_level * 2)
	else:
		bonus_label.text = "Current: +%d Armor, +%d Max HP" % [current_level, current_level * 3]
	bonus_label.add_theme_font_size_override("font_size", 38 if _is_mobile else 12)
	bonus_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	section.add_child(bonus_label)

	if current_level < 100:
		var cost = GameManager.get_upgrade_cost(current_level)

		# Next level preview
		var next_label = Label.new()
		if upgrade_type == "weapon":
			next_label.text = "Next (Lv%d): +%d Attack Damage" % [current_level + 1, (current_level + 1) * 2]
		else:
			next_label.text = "Next (Lv%d): +%d Armor, +%d Max HP" % [current_level + 1, current_level + 1, (current_level + 1) * 3]
		next_label.add_theme_font_size_override("font_size", 38 if _is_mobile else 12)
		next_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		section.add_child(next_label)

		# Cost + upgrade button row
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var cost_label = Label.new()
		cost_label.text = "%dg" % cost
		cost_label.add_theme_font_size_override("font_size", 44 if _is_mobile else 14)
		cost_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(cost_label)

		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrade"
		upgrade_btn.custom_minimum_size = Vector2(320, 110) if _is_mobile else Vector2(100, 36)
		upgrade_btn.add_theme_font_size_override("font_size", 42 if _is_mobile else 14)
		_style_action_btn(upgrade_btn)
		var type = upgrade_type
		upgrade_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap", -4.0)
			_do_upgrade(type)
		)
		if GameManager.gold < cost:
			upgrade_btn.disabled = true
		hbox.add_child(upgrade_btn)

		section.add_child(hbox)
	else:
		var max_label = Label.new()
		max_label.text = "MAX LEVEL"
		max_label.add_theme_font_size_override("font_size", 40 if _is_mobile else 14)
		max_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		section.add_child(max_label)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	section.add_child(sep)

	content.add_child(section)

func _do_upgrade(upgrade_type: String) -> void:
	var current_level: int
	if upgrade_type == "weapon":
		current_level = GameManager.weapon_upgrade_level
	else:
		current_level = GameManager.armor_upgrade_level

	if current_level >= 100:
		return

	var cost = GameManager.get_upgrade_cost(current_level)
	if not GameManager.spend_gold(cost):
		GameManager.game_message.emit("Not enough gold!", Color(1, 0.3, 0.3))
		return

	if upgrade_type == "weapon":
		GameManager.weapon_upgrade_level += 1
	else:
		GameManager.armor_upgrade_level += 1

	_apply_armory_bonuses()
	_refresh()

	var new_level = GameManager.weapon_upgrade_level if upgrade_type == "weapon" else GameManager.armor_upgrade_level
	GameManager.game_message.emit("%s upgraded to level %d!" % [upgrade_type.capitalize(), new_level], Color(1, 0.85, 0.5))
	AudioManager.play_sfx("forge_weapon" if upgrade_type == "weapon" else "forge_armor", -8.0)
	# Brief gold flash on the panel to confirm the upgrade visually
	var tw = create_tween()
	tw.tween_property(panel, "modulate", Color(1.3, 1.15, 0.8), 0.1)
	tw.tween_property(panel, "modulate", Color(1, 1, 1), 0.25)

func _apply_armory_bonuses() -> void:
	if not _player:
		return
	_player.stats.armory_weapon_bonus = GameManager.weapon_upgrade_level * 2
	_player.stats.armory_armor_bonus = GameManager.armor_upgrade_level
	_player.stats.armory_hp_bonus = GameManager.armor_upgrade_level * 3
	_player.stats._emit_all()

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
