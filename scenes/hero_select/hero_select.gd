extends Control

signal hero_chosen(hero_class: String)

var _hero_selected := false

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var margin: MarginContainer = $ScrollContainer/MarginContainer
@onready var hero_container: HBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/HeroContainer
@onready var title_label: Label = $ScrollContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $ScrollContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var vbox: VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer

var _cards: Dictionary = {}
var _changelog_dialog: CanvasLayer = null
var _is_mobile: bool = false
var _title_section: VBoxContainer = null
var _game_title_label: Label = null
var _game_sub_label: Label = null
var _deco_top_line: HBoxContainer = null
var _deco_bot_line: HBoxContainer = null

func _ready() -> void:
	_detect_mobile()
	_apply_responsive_layout()
	_build_game_title()
	_build_hero_cards()
	_build_byline()
	_build_version_button()
	# Re-layout on resize
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Cinematic fade-in from boot splash dark background
	_start_title_fade_in()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()

func _on_viewport_resized() -> void:
	var was_mobile = _is_mobile
	_detect_mobile()
	if was_mobile != _is_mobile:
		# Full rebuild on layout mode change
		_apply_responsive_layout()
		for child in hero_container.get_children():
			child.queue_free()
		_build_hero_cards()

func _apply_responsive_layout() -> void:
	# Title colors match loading screen gold theme
	title_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.29))
	subtitle_label.add_theme_color_override("font_color", Color(0.67, 0.6, 0.4))
	if _is_mobile:
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 30)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 30)
		vbox.add_theme_constant_override("separation", 30)
		title_label.add_theme_font_size_override("font_size", 52)
		subtitle_label.add_theme_font_size_override("font_size", 28)
		hero_container.add_theme_constant_override("separation", 30)
		# Switch to vertical layout for mobile
		if hero_container is HBoxContainer:
			_switch_to_vertical_layout()
	else:
		margin.add_theme_constant_override("margin_left", 60)
		margin.add_theme_constant_override("margin_top", 40)
		margin.add_theme_constant_override("margin_right", 60)
		margin.add_theme_constant_override("margin_bottom", 40)
		vbox.add_theme_constant_override("separation", 24)
		title_label.add_theme_font_size_override("font_size", 44)
		subtitle_label.add_theme_font_size_override("font_size", 22)
		hero_container.add_theme_constant_override("separation", 40)

func _switch_to_vertical_layout() -> void:
	# Replace HBoxContainer with VBoxContainer for vertical card stacking
	var new_container = VBoxContainer.new()
	new_container.name = "HeroContainer"
	new_container.layout_mode = 2
	new_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_container.alignment = BoxContainer.ALIGNMENT_CENTER
	new_container.add_theme_constant_override("separation", 24)
	var parent = hero_container.get_parent()
	var idx = hero_container.get_index()
	parent.remove_child(hero_container)
	hero_container.queue_free()
	parent.add_child(new_container)
	parent.move_child(new_container, idx)
	hero_container = new_container

func _build_hero_cards() -> void:
	for key in HeroData.get_all_hero_keys():
		var data = HeroData.get_hero(key)
		var card = _create_hero_card(key, data)
		hero_container.add_child(card)

func _create_hero_card(hero_key: String, data: Dictionary) -> PanelContainer:
	if _is_mobile:
		return _create_mobile_hero_card(hero_key, data)
	return _create_desktop_hero_card(hero_key, data)

func _create_mobile_hero_card(hero_key: String, data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var vp_w = get_viewport().get_visible_rect().size.x
	var card_min_w = clampf(vp_w - 40, 300, 900)
	panel.custom_minimum_size = Vector2(card_min_w, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards[hero_key] = panel

	var hero_color: Color = data.get("color", Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04)
	style.border_color = hero_color
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 14)
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Color bar accent at top
	var color_bar = ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, 10)
	color_bar.color = hero_color
	card_vbox.add_child(color_bar)

	# Hero name — BIG and bold
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown").to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 52)
	name_label.add_theme_color_override("font_color", hero_color.lightened(0.3))
	card_vbox.add_child(name_label)

	# Type tag — short, clear
	var type_label = Label.new()
	var primary = data.get("primary_stat", "strength")
	match primary:
		"strength": type_label.text = "MELEE"
		"agility": type_label.text = "RANGED"
		"intelligence": type_label.text = "CASTER"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 32)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	card_vbox.add_child(type_label)

	# Big SELECT button — easy to tap
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 110)
	button.add_theme_font_size_override("font_size", 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_hero_selected.bind(hero_key))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = hero_color.darkened(0.4)
	btn_style.set_corner_radius_all(12)
	btn_style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = hero_color.darkened(0.2)
	btn_hover.set_corner_radius_all(12)
	btn_hover.set_content_margin_all(12)
	button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = hero_color
	btn_pressed.set_corner_radius_all(12)
	btn_pressed.set_content_margin_all(12)
	button.add_theme_stylebox_override("pressed", btn_pressed)

	card_vbox.add_child(button)

	panel.add_child(card_vbox)

	# Tapping anywhere on the card selects the hero — not just the button
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_hero_selected(hero_key)
		elif event is InputEventScreenTouch and event.pressed:
			_on_hero_selected(hero_key)
	)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return panel

func _create_desktop_hero_card(hero_key: String, data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var hero_color: Color = data.get("color", Color.WHITE)

	var card_min_w: float = 420
	var card_min_h: float = 520

	panel.custom_minimum_size = Vector2(card_min_w, card_min_h)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards[hero_key] = panel

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04)
	style.border_color = hero_color.darkened(0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	var card_padding = 24
	style.set_content_margin_all(card_padding)
	panel.add_theme_stylebox_override("panel", style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 14)

	# Color bar accent at top
	var color_bar = ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, 6)
	color_bar.color = hero_color
	card_vbox.add_child(color_bar)

	# Hero sprite preview area
	var preview_bg = ColorRect.new()
	var preview_h = 130
	preview_bg.custom_minimum_size = Vector2(0, preview_h)
	preview_bg.color = Color(0.04, 0.03, 0.02)
	card_vbox.add_child(preview_bg)

	# Hero figure centered in preview
	var hero_fig = ColorRect.new()
	var fig_w = 32
	var fig_h = 44
	hero_fig.custom_minimum_size = Vector2(fig_w, fig_h)
	hero_fig.color = hero_color
	preview_bg.add_child(hero_fig)
	preview_bg.resized.connect(func():
		hero_fig.position = Vector2(
			(preview_bg.size.x - fig_w) / 2.0,
			(preview_bg.size.y - fig_h) / 2.0
		)
	)
	hero_fig.position = Vector2(
		(card_min_w - card_padding * 2 - fig_w) / 2.0,
		(preview_h - fig_h) / 2.0
	)

	# Class type tag
	var icon_label = Label.new()
	var primary = data.get("primary_stat", "strength")
	match primary:
		"strength": icon_label.text = "MELEE"
		"agility": icon_label.text = "RANGED"
		"intelligence": icon_label.text = "CASTER"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 18)
	icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	card_vbox.add_child(icon_label)

	# Name — large and colored
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown").to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", hero_color.lightened(0.3))
	card_vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	card_vbox.add_child(desc_label)

	# Separator
	var sep = HSeparator.new()
	card_vbox.add_child(sep)

	# Stats
	var base = data.get("base_stats", {})
	var stats_text = "STR: %d   AGI: %d   INT: %d\nHP: %d   Mana: %d   ATK: %d\nRange: %s   Speed: %.0f" % [
		base.get("strength", 0), base.get("agility", 0), base.get("intelligence", 0),
		base.get("max_hp", 0), base.get("max_mana", 0), base.get("attack_damage", 0),
		"Melee" if base.get("attack_range", 40) < 50 else "Ranged",
		base.get("move_speed", 150),
	]
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	card_vbox.add_child(stats_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(spacer)

	# Select button — styled with hero color
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_hero_selected.bind(hero_key))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = hero_color.darkened(0.5)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = hero_color.darkened(0.25)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = hero_color
	btn_pressed.set_corner_radius_all(8)
	btn_pressed.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", btn_pressed)

	card_vbox.add_child(button)

	panel.add_child(card_vbox)

	# Hover effects on entire card
	panel.mouse_entered.connect(func():
		style.border_color = hero_color
		style.set_border_width_all(4)
	)
	panel.mouse_exited.connect(func():
		style.border_color = hero_color.darkened(0.35)
		style.set_border_width_all(3)
	)

	# Clicking anywhere on the card selects the hero
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_hero_selected(hero_key)
	)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return panel

func _build_game_title() -> void:
	# Insert game title section ABOVE "Choose Your Hero" — matches loading screen style
	_title_section = VBoxContainer.new()
	_title_section.add_theme_constant_override("separation", 4 if _is_mobile else 2)
	_title_section.alignment = BoxContainer.ALIGNMENT_CENTER

	# Top decorative line — em-dash middot pattern matching loading screen
	_deco_top_line = HBoxContainer.new()
	_deco_top_line.alignment = BoxContainer.ALIGNMENT_CENTER
	var deco_top = Label.new()
	deco_top.text = "\u2014 \u00B7 \u2014"
	deco_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deco_top.add_theme_font_size_override("font_size", 28 if _is_mobile else 20)
	deco_top.add_theme_color_override("font_color", Color(0.72, 0.58, 0.16, 0.35))
	_deco_top_line.add_child(deco_top)
	_title_section.add_child(_deco_top_line)

	# Main game title — gold with glow like loading screen (#f0cc4a)
	_game_title_label = Label.new()
	_game_title_label.text = "OPEN LEGENDS RPG"
	_game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title_label.add_theme_font_size_override("font_size", 72 if _is_mobile else 64)
	var title_settings = LabelSettings.new()
	title_settings.font_color = Color(0.94, 0.80, 0.29)  # #f0cc4a
	title_settings.outline_size = 8 if _is_mobile else 6
	title_settings.outline_color = Color(0.94, 0.80, 0.29, 0.25)
	title_settings.shadow_color = Color(0.94, 0.80, 0.29, 0.3)
	title_settings.shadow_offset = Vector2(0, 0)
	_game_title_label.label_settings = title_settings
	_title_section.add_child(_game_title_label)

	# Subtitle accent — muted gold matching loading screen (#aa9966)
	_game_sub_label = Label.new()
	_game_sub_label.text = "FORGE YOUR LEGEND"
	_game_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_sub_label.add_theme_font_size_override("font_size", 28 if _is_mobile else 22)
	_game_sub_label.add_theme_color_override("font_color", Color(0.67, 0.6, 0.4))
	_title_section.add_child(_game_sub_label)

	# Bottom decorative line
	_deco_bot_line = HBoxContainer.new()
	_deco_bot_line.alignment = BoxContainer.ALIGNMENT_CENTER
	var deco_bot = Label.new()
	deco_bot.text = "\u2014 \u00B7 \u2014"
	deco_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deco_bot.add_theme_font_size_override("font_size", 28 if _is_mobile else 20)
	deco_bot.add_theme_color_override("font_color", Color(0.72, 0.58, 0.16, 0.35))
	_deco_bot_line.add_child(deco_bot)
	_title_section.add_child(_deco_bot_line)

	# Insert at position 0 in vbox (before TitleLabel)
	vbox.add_child(_title_section)
	vbox.move_child(_title_section, 0)

func _build_byline() -> void:
	var byline_bar = HBoxContainer.new()
	byline_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var byline = RichTextLabel.new()
	byline.bbcode_enabled = true
	byline.fit_content = true
	byline.scroll_active = false
	byline.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font_size = 28 if _is_mobile else 20
	byline.append_text("[center][font_size=%d][color=#8888aa]by [url=https://OpenClassActions.com][color=#99aadd]Steve Levine[/color][/url][/color][/font_size][/center]" % font_size)
	byline.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	byline.custom_minimum_size = Vector2(300 if _is_mobile else 150, 0)
	byline_bar.add_child(byline)

	vbox.add_child(byline_bar)

func _build_version_button() -> void:
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var version_btn = Button.new()
	var _cl_script = preload("res://scenes/ui/changelog_dialog.gd")
	version_btn.text = "Version Log (%s)" % _cl_script.GAME_VERSION
	var ver_btn_w = 480 if _is_mobile else 280
	var ver_btn_h = 96 if _is_mobile else 44
	var ver_font_size = 33 if _is_mobile else 18
	version_btn.custom_minimum_size = Vector2(ver_btn_w, ver_btn_h)
	version_btn.add_theme_font_size_override("font_size", ver_font_size)
	version_btn.pressed.connect(_on_version_log_pressed)
	bottom_bar.add_child(version_btn)

	vbox.add_child(bottom_bar)

func _on_version_log_pressed() -> void:
	if _changelog_dialog == null:
		var scene = load("res://scenes/ui/changelog_dialog.tscn")
		_changelog_dialog = scene.instantiate()
		add_child(_changelog_dialog)
	_changelog_dialog.open()

func _start_title_fade_in() -> void:
	# vbox order: [0] title_section, [1] TitleLabel, [2] SubtitleLabel,
	#             [3] HeroContainer, [4] byline_bar, [5] version_bar
	var child_count = vbox.get_child_count()

	# Hide everything initially (opacity only — never touch position on VBox children)
	for i in range(child_count):
		vbox.get_child(i).modulate.a = 0.0

	# Hide individual title section children for per-element animation
	_game_title_label.modulate.a = 0.0
	_game_sub_label.modulate.a = 0.0
	_deco_top_line.modulate.a = 0.0
	_deco_bot_line.modulate.a = 0.0
	# Make title_section container visible so children can fade independently
	_title_section.modulate.a = 1.0

	var tween = create_tween()
	tween.set_parallel(true)

	# Phase 1 (0.0s): Game title fades in with slight scale punch
	tween.tween_property(_game_title_label, "modulate:a", 1.0, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_game_title_label.scale = Vector2(1.08, 1.08)
	_game_title_label.pivot_offset = _game_title_label.size / 2.0
	tween.tween_property(_game_title_label, "scale", Vector2.ONE, 1.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Phase 2 (0.4s): Subtitle fades in
	tween.tween_property(_game_sub_label, "modulate:a", 1.0, 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.4)

	# Phase 3 (0.7s): Decorative lines fade in
	tween.tween_property(_deco_top_line, "modulate:a", 1.0, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.7)
	tween.tween_property(_deco_bot_line, "modulate:a", 1.0, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.7)

	# Phase 4 (1.0s+): Below-title content fades in with stagger
	for i in range(1, child_count):
		var delay = 1.0 + (i - 1) * 0.2
		var node = vbox.get_child(i)
		tween.tween_property(node, "modulate:a", 1.0, 0.7) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(delay)

func _on_hero_selected(hero_key: String) -> void:
	if _hero_selected:
		return
	_hero_selected = true
	GameManager.select_hero(hero_key)
	hero_chosen.emit(hero_key)
