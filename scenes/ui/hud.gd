extends CanvasLayer

## SC:BW-style HUD with dark bottom console panel, segmented bars,
## 3x3 command card, alignment display, and save/load buttons.

# Top bar refs
@onready var top_bar: HBoxContainer = $TopBar
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var wood_label: Label = $TopBar/WoodLabel
@onready var alignment_label: Label = $TopBar/AlignmentLabel

# Bottom console panel refs
@onready var bottom_panel: PanelContainer = $BottomPanel
@onready var bottom_hbox: HBoxContainer = $BottomPanel/HBox
@onready var hp_bar: SCBar = $BottomPanel/HBox/UnitInfo/HPBar
@onready var mana_bar: SCBar = $BottomPanel/HBox/UnitInfo/ManaBar
@onready var level_label: Label = $BottomPanel/HBox/UnitInfo/InfoLine
@onready var xp_bar: SCBar = $BottomPanel/HBox/UnitInfo/XPBar
@onready var unit_info: VBoxContainer = $BottomPanel/HBox/UnitInfo

# Minimap
@onready var minimap: Control = $BottomPanel/HBox/Minimap

# Command card refs (3x3 grid)
@onready var command_card: VBoxContainer = $BottomPanel/HBox/CommandCard
@onready var command_label: Label = $BottomPanel/HBox/CommandCard/Label
@onready var command_grid: GridContainer = $BottomPanel/HBox/CommandCard/Grid
@onready var ability_1_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability1
@onready var ability_2_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability2
@onready var log_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Slot3
@onready var potion_1_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Slot4
@onready var potion_2_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Slot5
@onready var potion_3_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Slot6
@onready var inv_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Inv
@onready var save_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Save
@onready var load_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Load

var _player: Node2D = null
var _is_mobile: bool = false

# Ability tooltip panel
var _tooltip_panel: PanelContainer = null
var _tooltip_label: RichTextLabel = null
var _tooltip_timer: Timer = null
var _tooltip_data: Dictionary = {}  # key -> formatted tooltip string
var _hovered_btn: Button = null

# Tutorial hint system
var _hint_panel: PanelContainer = null
var _hint_label: RichTextLabel = null
var _hint_queue: Array[Dictionary] = []
var _hint_timer: Timer = null
var _hint_showing: bool = false

func _ready() -> void:
	_detect_mobile()
	if _is_mobile:
		_apply_mobile_layout()
		_add_mobile_menu_button()
	_create_tooltip_panel()
	_create_hint_panel()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)

func _apply_mobile_layout() -> void:
	# ── Top bar: triple font sizes for 6.9" readability ──
	top_bar.offset_bottom = 72
	gold_label.add_theme_font_size_override("font_size", 44)
	wood_label.add_theme_font_size_override("font_size", 44)
	alignment_label.add_theme_font_size_override("font_size", 38)

	# ── Bottom panel: grow taller ──
	bottom_panel.offset_top = -400
	bottom_hbox.add_theme_constant_override("separation", 20)

	# ── Unit info: bigger text and bars ──
	level_label.add_theme_font_size_override("font_size", 48)
	hp_bar.custom_minimum_size.y = 56
	mana_bar.custom_minimum_size.y = 56
	xp_bar.custom_minimum_size.y = 42
	unit_info.add_theme_constant_override("separation", 8)

	# ── Minimap: scale up ──
	minimap.custom_minimum_size = Vector2(240, 240)

	# ── Command card: larger button sizes and fonts ──
	command_card.custom_minimum_size.x = 500
	command_label.add_theme_font_size_override("font_size", 36)
	command_grid.add_theme_constant_override("h_separation", 4)
	command_grid.add_theme_constant_override("v_separation", 4)

	for child in command_grid.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(158, 100)
			child.add_theme_font_size_override("font_size", 30)

func _add_mobile_menu_button() -> void:
	var menu_btn = Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(140, 60)
	menu_btn.add_theme_font_size_override("font_size", 34)
	menu_btn.modulate = Color(1, 1, 1, 0.7)
	menu_btn.pressed.connect(func():
		var menus = get_tree().get_nodes_in_group("pause_menu")
		if menus.size() > 0:
			menus[0].toggle()
	)
	# Insert at position 0 in top bar (before the spacer)
	top_bar.add_child(menu_btn)
	top_bar.move_child(menu_btn, 0)

func setup(player: Node2D) -> void:
	_player = player
	minimap.setup(player)
	var stats: StatsComponent = player.stats
	var ability_mgr: AbilityManager = player.ability_mgr

	stats.hp_changed.connect(_on_hp_changed)
	stats.mana_changed.connect(_on_mana_changed)
	stats.xp_changed.connect(_on_xp_changed)
	stats.leveled_up.connect(_on_leveled_up)
	ability_mgr.ability_cooldown_updated.connect(_on_ability_cooldown)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.wood_changed.connect(_on_wood_changed)
	AlignmentManager.alignment_changed.connect(_on_alignment_changed)

	# Ability names & tooltips
	var hero_data = HeroData.get_hero(player.hero_class)
	if hero_data.has("abilities"):
		var ab = hero_data["abilities"]
		if ab.has("ability_1"):
			ability_1_btn.text = "Q\n" + ab["ability_1"]["name"]
			_tooltip_data["ability_1"] = _build_ability_tooltip(ab["ability_1"], "Q")
		if ab.has("ability_2"):
			ability_2_btn.text = "E\n" + ab["ability_2"]["name"]
			_tooltip_data["ability_2"] = _build_ability_tooltip(ab["ability_2"], "E")

	# Connect ability buttons to actually cast on press (needed for mobile tap)
	ability_1_btn.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player._use_ability("ability_1")
	)
	ability_2_btn.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player._use_ability("ability_2")
	)

	# Tooltip hover — desktop only (on mobile, tap should cast, not tooltip)
	if not _is_mobile:
		ability_1_btn.mouse_entered.connect(_on_ability_hover.bind(ability_1_btn, "ability_1"))
		ability_1_btn.mouse_exited.connect(_on_ability_unhover)
		ability_2_btn.mouse_entered.connect(_on_ability_hover.bind(ability_2_btn, "ability_2"))
		ability_2_btn.mouse_exited.connect(_on_ability_unhover)

	# Connect command card buttons
	log_btn.text = "F1\nLog"
	log_btn.disabled = false
	log_btn.pressed.connect(_on_changelog_pressed)

	# Potion slots — tap to use consumable
	potion_1_btn.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player.inventory.use_consumable(0)
	)
	potion_2_btn.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player.inventory.use_consumable(1)
	)
	potion_3_btn.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player.inventory.use_consumable(2)
	)

	# Inventory toggle
	inv_btn.pressed.connect(_on_inventory_pressed)

	# Save/Load are click-only (no F-key binding)
	save_btn.text = "Save\nGame"
	load_btn.text = "Load\nGame"
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)

	# Initial values
	_on_hp_changed(stats.current_hp, stats.get_total_max_hp())
	_on_mana_changed(stats.current_mana, stats.get_total_max_mana())
	_on_xp_changed(stats.xp, stats.get_xp_to_next_level())
	level_label.text = "%s  Lv %d  Adventurer" % [hero_data.get("name", "Hero"), stats.level]
	_on_gold_changed(GameManager.gold)
	_on_wood_changed(GameManager.wood)
	_update_alignment_display()

	# Start tutorial hints after a short delay
	_start_tutorial_hints(hero_data)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_on_changelog_pressed()

func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.label_text = "HP: %d / %d" % [current, maximum]
	hp_bar.set_value(current, maximum)

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.label_text = "MP: %d / %d" % [current, maximum]
	mana_bar.set_value(current, maximum)

func _on_xp_changed(current: int, needed: int) -> void:
	xp_bar.label_text = "XP: %d / %d" % [current, needed]
	xp_bar.set_value(current, needed)

func _on_leveled_up(new_level: int) -> void:
	var tier = "Adventurer"
	if new_level >= 36:
		tier = "Demigod"
	elif new_level >= 26:
		tier = "Master"
	elif new_level >= 16:
		tier = "Veteran"
	if _player:
		var hero_data = HeroData.get_hero(_player.hero_class)
		level_label.text = "%s  Lv %d  %s" % [hero_data.get("name", "Hero"), new_level, tier]

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_wood_changed(amount: int) -> void:
	wood_label.text = "Wood: %d" % amount

func _on_alignment_changed(_player_id: int, _value: int) -> void:
	_update_alignment_display()

func _update_alignment_display() -> void:
	var faction = AlignmentManager.get_faction_name(0)
	var val = AlignmentManager.get_alignment(0)
	var color: Color
	match faction:
		"Holy":
			color = Color(1.0, 0.95, 0.5)
		"Good":
			color = Color(0.5, 1.0, 0.5)
		"Neutral":
			color = Color(0.7, 0.7, 0.7)
		"Dark":
			color = Color(0.7, 0.4, 0.8)
		"Evil":
			color = Color(1.0, 0.2, 0.2)
		_:
			color = Color.WHITE
	alignment_label.text = "%s (%+d)" % [faction, val]
	alignment_label.add_theme_color_override("font_color", color)

func _on_ability_cooldown(index: int, remaining: float, _total: float) -> void:
	var btn = ability_1_btn if index == 0 else ability_2_btn
	if remaining > 0:
		btn.disabled = true
	else:
		btn.disabled = false

func _on_changelog_pressed() -> void:
	var dialogs = get_tree().get_nodes_in_group("changelog_dialog")
	if dialogs.size() > 0:
		var dlg = dialogs[0]
		if dlg._is_visible:
			dlg.close()
		else:
			dlg.open()

func _on_inventory_pressed() -> void:
	var event = InputEventAction.new()
	event.action = "toggle_inventory"
	event.pressed = true
	Input.parse_input_event(event)

func _on_save_pressed() -> void:
	SaveLoadManager.save_game()

func _on_load_pressed() -> void:
	SaveLoadManager.load_game()
	if _player and is_instance_valid(_player):
		SaveLoadManager.apply_to_player(_player)

# ── Ability Tooltip System ──────────────────────────────────────────────

func _create_tooltip_panel() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_color = Color(0.45, 0.4, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.8))
	if _is_mobile:
		_tooltip_label.custom_minimum_size = Vector2(420, 0)
		_tooltip_label.add_theme_font_size_override("normal_font_size", 26)
		_tooltip_label.add_theme_font_size_override("bold_font_size", 28)
	else:
		_tooltip_label.custom_minimum_size = Vector2(240, 0)
		_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
		_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_tooltip_panel.add_child(_tooltip_label)

	# Timer for delayed show
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = 0.3
	_tooltip_timer.timeout.connect(_show_tooltip)
	add_child(_tooltip_timer)
	add_child(_tooltip_panel)

func _build_ability_tooltip(ability: Dictionary, hotkey: String) -> String:
	var name_str = ability.get("name", "Unknown")
	var desc = ability.get("description", "")
	var mana = ability.get("mana_cost", 0)
	var cd = ability.get("cooldown", 0.0)

	var text = "[b][color=#f0d866]%s[/color][/b]  [color=#aaaaaa][%s][/color]\n" % [name_str, hotkey]
	text += "[color=#bbbbbb]%s[/color]\n\n" % desc

	# Stats line
	var stats_parts: Array[String] = []
	if mana > 0:
		stats_parts.append("[color=#6699ff]%d Mana[/color]" % mana)
	if cd > 0:
		stats_parts.append("[color=#ccaa55]%.0fs Cooldown[/color]" % cd)
	if stats_parts.size() > 0:
		text += "  ".join(stats_parts) + "\n"

	# Extra details
	if ability.has("damage_multiplier"):
		text += "[color=#ff8866]%.0f%% damage[/color]" % (ability["damage_multiplier"] * 100)
		if ability.has("radius"):
			text += "  [color=#aaaaaa]in %.0fpx radius[/color]" % ability["radius"]
		if ability.has("projectile_count"):
			text += "  [color=#aaaaaa]%d projectiles[/color]" % ability["projectile_count"]
		text += "\n"
	if ability.has("armor_bonus"):
		text += "[color=#66ccff]+%d Armor[/color]  for [color=#cccccc]%.0fs[/color]\n" % [ability["armor_bonus"], ability.get("duration", 0)]
	if ability.has("dodge_bonus"):
		text += "[color=#66ff99]+%.0f%% Dodge[/color]  for [color=#cccccc]%.0fs[/color]\n" % [ability["dodge_bonus"] * 100, ability.get("duration", 0)]

	return text.strip_edges()

func _on_ability_hover(btn: Button, ability_key: String) -> void:
	if not _tooltip_data.has(ability_key):
		return
	_hovered_btn = btn
	_tooltip_label.text = _tooltip_data[ability_key]
	_tooltip_timer.start()

func _on_ability_unhover() -> void:
	_hovered_btn = null
	_tooltip_timer.stop()
	_tooltip_panel.visible = false

func _show_tooltip() -> void:
	if _hovered_btn == null:
		return
	_tooltip_panel.visible = true
	# Position above the hovered button
	await get_tree().process_frame
	var btn_rect = _hovered_btn.get_global_rect()
	var tip_size = _tooltip_panel.size
	var x_pos = btn_rect.position.x + btn_rect.size.x / 2.0 - tip_size.x / 2.0
	var y_pos = btn_rect.position.y - tip_size.y - 8.0
	# Clamp to screen
	x_pos = clampf(x_pos, 4, get_viewport().get_visible_rect().size.x - tip_size.x - 4)
	if y_pos < 4:
		y_pos = btn_rect.position.y + btn_rect.size.y + 8.0
	_tooltip_panel.position = Vector2(x_pos, y_pos)

# ── Tutorial Hint System ────────────────────────────────────────────────

func _create_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.visible = false
	_hint_panel.z_index = 50
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.92)
	style.border_color = Color(0.35, 0.55, 0.8, 0.8)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_hint_panel.add_theme_stylebox_override("panel", style)

	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.8))
	if _is_mobile:
		_hint_label.custom_minimum_size = Vector2(700, 0)
		_hint_label.add_theme_font_size_override("normal_font_size", 38)
		_hint_label.add_theme_font_size_override("bold_font_size", 40)
	else:
		_hint_label.custom_minimum_size = Vector2(500, 0)
		_hint_label.add_theme_font_size_override("normal_font_size", 14)
		_hint_label.add_theme_font_size_override("bold_font_size", 15)
	_hint_panel.add_child(_hint_label)

	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_show_next_hint)
	add_child(_hint_timer)
	add_child(_hint_panel)

func _start_tutorial_hints(hero_data: Dictionary) -> void:
	var ab1_name = "Ability 1"
	var ab2_name = "Ability 2"
	if hero_data.has("abilities"):
		var ab = hero_data["abilities"]
		if ab.has("ability_1"):
			ab1_name = ab["ability_1"]["name"]
		if ab.has("ability_2"):
			ab2_name = ab["ability_2"]["name"]

	var is_ranged = _player and _player.hero_class == "shadow_ranger"

	_hint_queue = [
		{
			"delay": 4.0,
			"text": "[color=#f0d866]TIP:[/color]  Press [color=#66ccff][b]Q[/b][/color] for [color=#f0d866]%s[/color]  and  [color=#66ccff][b]E[/b][/color] for [color=#f0d866]%s[/color]" % [ab1_name, ab2_name],
		},
	]

	if is_ranged:
		_hint_queue.append_array([
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap SPACE[/b][/color] while moving for a [color=#ffcc44]Piercing Shot[/color] — arrow passes through all enemies!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#6699ff][b]Triple-tap SPACE[/b][/color] for [color=#6699ff]Arrow Rain[/color] — arrows rain down on a target area!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold SPACE 1.5s[/b][/color] then release for a [color=#ffcc44]Sniper Shot[/color] — long-range precision hit!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#66eebb][b]Diagonal keys + SPACE[/b][/color] for a [color=#66eebb]Shadow Step[/color] — dodge back and fire a spread!",
			},
		])
	else:
		_hint_queue.append_array([
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap SPACE[/b][/color] while moving for a [color=#ffcc44]Power Strike[/color] — heavy single-target hit!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#cc88ff][b]Triple-tap SPACE[/b][/color] for a [color=#cc88ff]Whirlwind[/color] — spin attack hitting all nearby enemies!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold SPACE 1.5s[/b][/color] then release for a [color=#ffcc44]Charged Slash[/color] — dash through enemies!",
			},
			{
				"delay": 18.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#66eeff][b]Diagonal keys + SPACE[/b][/color] for a [color=#66eeff]Dash Strike[/color] — quick dash through foes!",
			},
		])

	_hint_queue.append({
		"delay": 18.0,
		"text": "[color=#f0d866]TIP:[/color]  [color=#aaaaaa][b]Left-click[/b][/color] enemies to auto-attack  |  [color=#aaaaaa][b]Right-click[/b][/color] your hero for stats",
	})

	# Start the first hint after its delay
	if _hint_queue.size() > 0:
		_hint_timer.wait_time = _hint_queue[0]["delay"]
		_hint_timer.start()

func _show_next_hint() -> void:
	if _hint_queue.is_empty():
		return

	var hint = _hint_queue.pop_front()
	_hint_label.text = hint["text"]
	_hint_panel.visible = true
	_hint_panel.modulate.a = 0.0

	# Position above the bottom panel
	await get_tree().process_frame
	var screen_w = get_viewport().get_visible_rect().size.x
	var panel_w = _hint_panel.size.x
	var bottom_offset = -340.0 if _is_mobile else -175.0
	_hint_panel.position = Vector2((screen_w - panel_w) / 2.0, bottom_offset - _hint_panel.size.y - 10)

	# Fade in
	var tween = create_tween()
	tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.4)
	# Hold for 6 seconds
	tween.tween_interval(6.0)
	# Fade out
	tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		_hint_panel.visible = false
		# Schedule the next hint
		if not _hint_queue.is_empty():
			_hint_timer.wait_time = _hint_queue[0]["delay"]
			_hint_timer.start()
	)
