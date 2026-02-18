extends Control

signal hero_chosen(hero_class: String)

@onready var hero_container: HBoxContainer = $MarginContainer/VBoxContainer/HeroContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel

var _cards: Dictionary = {}

func _ready() -> void:
	_build_hero_cards()

func _build_hero_cards() -> void:
	for key in HeroData.get_all_hero_keys():
		var data = HeroData.get_hero(key)
		var card = _create_hero_card(key, data)
		hero_container.add_child(card)

func _create_hero_card(hero_key: String, data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 440)
	_cards[hero_key] = panel

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = data.get("color", Color.WHITE).darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Hero sprite preview area
	var preview_bg = ColorRect.new()
	preview_bg.custom_minimum_size = Vector2(0, 100)
	preview_bg.color = Color(0.06, 0.06, 0.08)
	vbox.add_child(preview_bg)

	# Hero figure centered in preview
	var hero_fig = ColorRect.new()
	hero_fig.custom_minimum_size = Vector2(24, 32)
	hero_fig.color = data.get("color", Color.WHITE)
	hero_fig.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Add over the preview background
	preview_bg.add_child(hero_fig)
	hero_fig.position = Vector2(138, 30)  # roughly centered

	# Class icon indicator (weapon type)
	var icon_label = Label.new()
	var primary = data.get("primary_stat", "strength")
	match primary:
		"strength": icon_label.text = "[ MELEE ]"
		"agility": icon_label.text = "[ RANGED ]"
		"intelligence": icon_label.text = "[ CASTER ]"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 11)
	icon_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(icon_label)

	# Name
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", data.get("color", Color.WHITE).lightened(0.3))
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(desc_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

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
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vbox.add_child(stats_label)

	# Abilities with descriptions
	var abilities = data.get("abilities", {})
	for ab_key in abilities:
		var ab = abilities[ab_key]
		var hotkey = "Q" if ab_key == "ability_1" else "E"
		var ab_label = Label.new()
		ab_label.text = "[%s] %s - %s" % [hotkey, ab.get("name", ""), ab.get("description", "")]
		ab_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		ab_label.add_theme_font_size_override("font_size", 11)
		ab_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
		vbox.add_child(ab_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 44)
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
	vbox.add_child(button)

	panel.add_child(vbox)
	return panel

func _on_hero_selected(hero_key: String) -> void:
	GameManager.select_hero(hero_key)
	hero_chosen.emit(hero_key)
