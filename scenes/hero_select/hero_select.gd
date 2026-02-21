extends Control

signal hero_chosen(hero_class: String)

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var margin: MarginContainer = $ScrollContainer/MarginContainer
@onready var hero_container: HBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer/HeroContainer
@onready var title_label: Label = $ScrollContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $ScrollContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var vbox: VBoxContainer = $ScrollContainer/MarginContainer/VBoxContainer

var _cards: Dictionary = {}
var _changelog_dialog: CanvasLayer = null
var _is_mobile: bool = false

func _ready() -> void:
	_detect_mobile()
	_apply_responsive_layout()
	_build_hero_cards()
	_build_version_button()
	# Re-layout on resize
	get_viewport().size_changed.connect(_on_viewport_resized)

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)

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
	if _is_mobile:
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 16)
		vbox.add_theme_constant_override("separation", 12)
		title_label.add_theme_font_size_override("font_size", 22)
		subtitle_label.add_theme_font_size_override("font_size", 12)
		subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hero_container.add_theme_constant_override("separation", 14)
		# Switch to vertical layout for mobile
		if hero_container is HBoxContainer:
			_switch_to_vertical_layout()
	else:
		margin.add_theme_constant_override("margin_left", 40)
		margin.add_theme_constant_override("margin_top", 30)
		margin.add_theme_constant_override("margin_right", 40)
		margin.add_theme_constant_override("margin_bottom", 30)
		vbox.add_theme_constant_override("separation", 20)
		title_label.add_theme_font_size_override("font_size", 36)
		subtitle_label.add_theme_font_size_override("font_size", 16)
		hero_container.add_theme_constant_override("separation", 30)

func _switch_to_vertical_layout() -> void:
	# Replace HBoxContainer with VBoxContainer for vertical card stacking
	var new_container = VBoxContainer.new()
	new_container.name = "HeroContainer"
	new_container.layout_mode = 2
	new_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_container.alignment = BoxContainer.ALIGNMENT_CENTER
	new_container.add_theme_constant_override("separation", 14)
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
	var panel = PanelContainer.new()

	# Responsive card sizing
	var card_min_w: float
	var card_min_h: float
	if _is_mobile:
		var vp_w = get_viewport().get_visible_rect().size.x
		card_min_w = clampf(vp_w - 48, 200, 400)  # Full width minus margins
		card_min_h = 0  # Auto height
	else:
		card_min_w = 300
		card_min_h = 440

	panel.custom_minimum_size = Vector2(card_min_w, card_min_h)
	_cards[hero_key] = panel

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = data.get("color", Color.WHITE).darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	var card_padding = 10 if _is_mobile else 16
	style.set_content_margin_all(card_padding)
	panel.add_theme_stylebox_override("panel", style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6 if _is_mobile else 10)

	# Font sizes based on layout
	var name_font_size = 18 if _is_mobile else 24
	var desc_font_size = 12 if _is_mobile else 13
	var icon_font_size = 10 if _is_mobile else 11
	var stats_font_size = 11 if _is_mobile else 12
	var ability_font_size = 10 if _is_mobile else 11
	var btn_font_size = 13 if _is_mobile else 14

	# Hero sprite preview area
	var preview_bg = ColorRect.new()
	var preview_h = 60 if _is_mobile else 100
	preview_bg.custom_minimum_size = Vector2(0, preview_h)
	preview_bg.color = Color(0.06, 0.06, 0.08)
	card_vbox.add_child(preview_bg)

	# Hero figure centered in preview — position dynamically
	var hero_fig = ColorRect.new()
	var fig_w = 20 if _is_mobile else 24
	var fig_h = 28 if _is_mobile else 32
	hero_fig.custom_minimum_size = Vector2(fig_w, fig_h)
	hero_fig.color = data.get("color", Color.WHITE)
	preview_bg.add_child(hero_fig)
	# Center using deferred call so we know the actual preview size
	preview_bg.resized.connect(func():
		hero_fig.position = Vector2(
			(preview_bg.size.x - fig_w) / 2.0,
			(preview_bg.size.y - fig_h) / 2.0
		)
	)
	# Initial centering fallback
	hero_fig.position = Vector2(
		(card_min_w - card_padding * 2 - fig_w) / 2.0,
		(preview_h - fig_h) / 2.0
	)

	# Class icon indicator (weapon type)
	var icon_label = Label.new()
	var primary = data.get("primary_stat", "strength")
	match primary:
		"strength": icon_label.text = "[ MELEE ]"
		"agility": icon_label.text = "[ RANGED ]"
		"intelligence": icon_label.text = "[ CASTER ]"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", icon_font_size)
	icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	card_vbox.add_child(icon_label)

	# Name
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", data.get("color", Color.WHITE).lightened(0.3))
	card_vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", desc_font_size)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
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
	stats_label.add_theme_font_size_override("font_size", stats_font_size)
	stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	card_vbox.add_child(stats_label)

	# Abilities with descriptions
	var abilities = data.get("abilities", {})
	for ab_key in abilities:
		var ab = abilities[ab_key]
		var hotkey = "Q" if ab_key == "ability_1" else "E"
		var ab_label = Label.new()
		ab_label.text = "[%s] %s - %s" % [hotkey, ab.get("name", ""), ab.get("description", "")]
		ab_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		ab_label.add_theme_font_size_override("font_size", ability_font_size)
		ab_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
		card_vbox.add_child(ab_label)

	# Spacer (only on desktop where cards have fixed height)
	if not _is_mobile:
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_child(spacer)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	var btn_h = 40 if _is_mobile else 44
	button.custom_minimum_size = Vector2(0, btn_h)
	button.add_theme_font_size_override("font_size", btn_font_size)
	button.pressed.connect(_on_hero_selected.bind(hero_key))

	# Hover effects
	button.mouse_entered.connect(func():
		style.border_color = data.get("color", Color.WHITE)
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	)
	button.mouse_exited.connect(func():
		style.border_color = data.get("color", Color.WHITE).darkened(0.3)
		style.set_border_width_all(2)
	)
	card_vbox.add_child(button)

	panel.add_child(card_vbox)
	return panel

func _build_version_button() -> void:
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var version_btn = Button.new()
	version_btn.text = "Version Log (v0.14.0)"
	var ver_btn_w = 160 if _is_mobile else 200
	var ver_btn_h = 32 if _is_mobile else 36
	var ver_font_size = 11 if _is_mobile else 13
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

func _on_hero_selected(hero_key: String) -> void:
	GameManager.select_hero(hero_key)
	hero_chosen.emit(hero_key)
