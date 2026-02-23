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
var _is_portrait: bool = false

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
var _hint_tween: Tween = null

# Command overlay (mobile portrait)
var _cmd_overlay: PanelContainer = null
var _cmd_overlay_visible: bool = false

# Minimap overlay (mobile portrait)
var _map_overlay: PanelContainer = null
var _map_overlay_visible: bool = false

func _ready() -> void:
	_detect_mobile()
	if _is_mobile:
		_apply_mobile_layout()
		_add_mobile_menu_button()
	_create_tooltip_panel()
	_create_hint_panel()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = DisplayServer.is_touchscreen_available()
	_is_portrait = _is_mobile and vp_size.y >= vp_size.x

func _apply_mobile_layout() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = vp_size.x > vp_size.y

	# ── Top bar: scale font sizes for readability & keep off screen edges ──
	var safe_right = DisplayServer.get_display_safe_area().position.x
	var right_pad = max(16, safe_right)
	if is_landscape:
		top_bar.offset_bottom = 18
		top_bar.offset_right = -right_pad
		gold_label.add_theme_font_size_override("font_size", 10)
		wood_label.add_theme_font_size_override("font_size", 10)
		alignment_label.add_theme_font_size_override("font_size", 9)
	else:
		top_bar.offset_bottom = 72
		top_bar.offset_right = -right_pad
		gold_label.add_theme_font_size_override("font_size", 44)
		wood_label.add_theme_font_size_override("font_size", 44)
		alignment_label.add_theme_font_size_override("font_size", 38)

	# ── PORTRAIT: [MAP] [bars] [OPT] layout ──
	if not is_landscape:
		# Hide command card (minimap gets reparented into overlay later)
		command_card.visible = false
		level_label.visible = false

		# Bottom panel with 40px bars
		var bar_h = 40
		var panel_h = bar_h * 3 + 14  # 3 bars + spacing = ~134px
		bottom_panel.offset_top = -panel_h
		bottom_hbox.add_theme_constant_override("separation", 4)
		hp_bar.custom_minimum_size.y = bar_h
		mana_bar.custom_minimum_size.y = bar_h
		xp_bar.custom_minimum_size.y = bar_h
		unit_info.add_theme_constant_override("separation", 2)

		# Shared button style
		var btn_style_normal = StyleBoxFlat.new()
		btn_style_normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
		btn_style_normal.border_color = Color(0.5, 0.4, 0.18, 0.8)
		btn_style_normal.set_border_width_all(2)
		btn_style_normal.set_corner_radius_all(6)
		btn_style_normal.set_content_margin_all(0)

		var btn_style_pressed = btn_style_normal.duplicate()
		btn_style_pressed.bg_color = Color(0.25, 0.2, 0.08, 0.95)
		btn_style_pressed.border_color = Color(0.9, 0.75, 0.3, 1.0)

		# MAP button — square, left of bars
		var map_btn = Button.new()
		map_btn.text = "MAP"
		map_btn.custom_minimum_size = Vector2(panel_h, 0)
		map_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map_btn.add_theme_font_size_override("font_size", 28)
		map_btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		map_btn.add_theme_stylebox_override("normal", btn_style_normal.duplicate())
		map_btn.add_theme_stylebox_override("pressed", btn_style_pressed.duplicate())
		map_btn.add_theme_stylebox_override("hover", btn_style_normal.duplicate())
		map_btn.pressed.connect(_toggle_map_overlay)
		bottom_hbox.add_child(map_btn)
		bottom_hbox.move_child(map_btn, 0)  # Move to leftmost position

		# OPT button — square, right of bars
		var opt_btn = Button.new()
		opt_btn.text = "OPT"
		opt_btn.custom_minimum_size = Vector2(panel_h, 0)
		opt_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		opt_btn.add_theme_font_size_override("font_size", 28)
		opt_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		opt_btn.add_theme_stylebox_override("normal", btn_style_normal.duplicate())
		opt_btn.add_theme_stylebox_override("pressed", btn_style_pressed.duplicate())
		opt_btn.add_theme_stylebox_override("hover", btn_style_normal.duplicate())
		opt_btn.pressed.connect(_toggle_cmd_overlay)
		bottom_hbox.add_child(opt_btn)

		# Build overlays (hidden by default)
		_build_cmd_overlay()
		_build_map_overlay()
		return

	# ── LANDSCAPE: compact strip with doubled bar height ──
	var bar_h_ls = 40
	var panel_h_ls = bar_h_ls * 3 + 10  # 3 bars + spacing = ~130px
	bottom_panel.offset_top = -panel_h_ls
	bottom_hbox.add_theme_constant_override("separation", 2)

	minimap.visible = false
	level_label.visible = false
	hp_bar.custom_minimum_size.y = bar_h_ls
	mana_bar.custom_minimum_size.y = bar_h_ls
	xp_bar.custom_minimum_size.y = bar_h_ls
	unit_info.add_theme_constant_override("separation", 1)

	command_card.custom_minimum_size.x = 160
	command_label.visible = false
	log_btn.visible = false
	save_btn.visible = false
	load_btn.visible = false
	command_grid.add_theme_constant_override("h_separation", 1)
	command_grid.add_theme_constant_override("v_separation", 1)
	for child in command_grid.get_children():
		if child is Button and child.visible:
			child.custom_minimum_size = Vector2(52, 14)
			child.add_theme_font_size_override("font_size", 8)

func _build_cmd_overlay() -> void:
	_cmd_overlay = PanelContainer.new()
	_cmd_overlay.visible = false
	_cmd_overlay.z_index = 90

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	_cmd_overlay.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_cmd_overlay.add_child(vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title = Label.new()
	title.text = "Commands"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(120, 100)
	close_btn.add_theme_font_size_override("font_size", 50)
	close_btn.pressed.connect(_toggle_cmd_overlay)
	title_row.add_child(close_btn)

	# 3x3 grid of command buttons
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var btn_size = Vector2(0, 90)
	var fs = 26

	# Row 1: Ability 1, Ability 2, Log
	var a1 = Button.new()
	a1.text = ability_1_btn.text
	a1.custom_minimum_size = btn_size
	a1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a1.add_theme_font_size_override("font_size", fs)
	a1.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player._use_ability("ability_1")
		_toggle_cmd_overlay()
	)
	grid.add_child(a1)

	var a2 = Button.new()
	a2.text = ability_2_btn.text
	a2.custom_minimum_size = btn_size
	a2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a2.add_theme_font_size_override("font_size", fs)
	a2.pressed.connect(func():
		if _player and is_instance_valid(_player):
			_player._use_ability("ability_2")
		_toggle_cmd_overlay()
	)
	grid.add_child(a2)

	var log_b = Button.new()
	log_b.text = "F1\nLog"
	log_b.custom_minimum_size = btn_size
	log_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_b.add_theme_font_size_override("font_size", fs)
	log_b.pressed.connect(func():
		_on_changelog_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(log_b)

	# Row 2: Potions 1-3
	for i in range(3):
		var p = Button.new()
		p.text = "%d\n---" % (i + 1)
		p.custom_minimum_size = btn_size
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_font_size_override("font_size", fs)
		var idx = i
		p.pressed.connect(func():
			if _player and is_instance_valid(_player):
				_player.inventory.use_consumable(idx)
			_toggle_cmd_overlay()
		)
		grid.add_child(p)

	# Row 3: Items, Save, Load
	var inv_b = Button.new()
	inv_b.text = "I\nItems"
	inv_b.custom_minimum_size = btn_size
	inv_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_b.add_theme_font_size_override("font_size", fs)
	inv_b.pressed.connect(func():
		_on_inventory_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(inv_b)

	var save_b = Button.new()
	save_b.text = "Save\nGame"
	save_b.custom_minimum_size = btn_size
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_b.add_theme_font_size_override("font_size", fs)
	save_b.pressed.connect(func():
		_on_save_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(save_b)

	var load_b = Button.new()
	load_b.text = "Load\nGame"
	load_b.custom_minimum_size = btn_size
	load_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_b.add_theme_font_size_override("font_size", fs)
	load_b.pressed.connect(func():
		_on_load_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(load_b)

	# Position the overlay above the bottom panel
	add_child(_cmd_overlay)

func _toggle_cmd_overlay() -> void:
	# Close MAP overlay if open
	if _map_overlay and _map_overlay_visible:
		_map_overlay_visible = false
		_map_overlay.visible = false

	_cmd_overlay_visible = !_cmd_overlay_visible
	_cmd_overlay.visible = _cmd_overlay_visible
	if _cmd_overlay_visible:
		AudioManager.play_sfx("ui_tap", -4.0)
		# Update potion labels in overlay
		_update_overlay_potions()
		# Position: centered, above bottom bar
		await get_tree().process_frame
		var vp_size = get_viewport().get_visible_rect().size
		var overlay_w = vp_size.x - 32
		_cmd_overlay.size = Vector2(overlay_w, 0)
		_cmd_overlay.position = Vector2(16, vp_size.y - bottom_panel.size.y - _cmd_overlay.size.y - 8)

func _update_overlay_potions() -> void:
	if not _cmd_overlay or not _player or not is_instance_valid(_player):
		return
	var grid = _cmd_overlay.get_child(0).get_child(1) as GridContainer  # vbox -> grid
	var inv = _player.inventory
	# Potion buttons are children 3, 4, 5 of the grid
	for i in range(3):
		var btn = grid.get_child(3 + i) as Button
		var item = inv.consumables[i] if i < inv.consumables.size() else {}
		if item.is_empty():
			btn.text = "%d\n---" % (i + 1)
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = "%d\n%s" % [i + 1, item.get("name", "Potion")]
			btn.modulate = Color.WHITE

func _build_map_overlay() -> void:
	_map_overlay = PanelContainer.new()
	_map_overlay.visible = false
	_map_overlay.z_index = 90

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color(0.3, 0.4, 0.55, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_map_overlay.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_map_overlay.add_child(vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title = Label.new()
	title.text = "Map"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(120, 100)
	close_btn.add_theme_font_size_override("font_size", 50)
	close_btn.pressed.connect(_toggle_map_overlay)
	title_row.add_child(close_btn)

	# Reparent the minimap into the overlay and scale it up
	minimap.get_parent().remove_child(minimap)
	minimap.custom_minimum_size = Vector2(0, 0)
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap.visible = true
	vbox.add_child(minimap)

	add_child(_map_overlay)

func _toggle_map_overlay() -> void:
	# Close CMD overlay if open
	if _cmd_overlay_visible:
		_cmd_overlay_visible = false
		_cmd_overlay.visible = false

	_map_overlay_visible = !_map_overlay_visible
	_map_overlay.visible = _map_overlay_visible
	if _map_overlay_visible:
		AudioManager.play_sfx("ui_tap", -4.0)
		await get_tree().process_frame
		var vp_size = get_viewport().get_visible_rect().size
		var is_ls = vp_size.x > vp_size.y
		var overlay_w: float
		var map_h: float
		if is_ls:
			# Landscape: compact overlay that doesn't dominate the screen
			map_h = vp_size.y * 0.5
			overlay_w = min(vp_size.x * 0.45, map_h * 1.3)
		else:
			overlay_w = vp_size.x - 32
			map_h = vp_size.x * 0.65
		_map_overlay.size = Vector2(overlay_w, map_h)
		_map_overlay.position = Vector2((vp_size.x - overlay_w) / 2.0, vp_size.y - bottom_panel.size.y - map_h - 8)

func _add_mobile_menu_button() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = vp_size.x > vp_size.y
	var menu_btn = Button.new()
	menu_btn.text = "Menu"
	if is_landscape:
		menu_btn.custom_minimum_size = Vector2(40, 14)
		menu_btn.add_theme_font_size_override("font_size", 9)
	else:
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

	# Tooltips: desktop hover, mobile long-press
	if _is_mobile:
		_setup_mobile_ability_tooltip(ability_1_btn, "ability_1")
		_setup_mobile_ability_tooltip(ability_2_btn, "ability_2")
	else:
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

	# Update potion button labels when inventory changes
	player.inventory.inventory_changed.connect(_update_potion_labels)
	_update_potion_labels()

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

func _update_potion_labels() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var inv = _player.inventory
	var btns = [potion_1_btn, potion_2_btn, potion_3_btn]
	for i in range(3):
		var item = inv.consumables[i] if i < inv.consumables.size() else {}
		if item.is_empty():
			btns[i].text = "%d\n---" % (i + 1)
			btns[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			btns[i].text = "%d\n%s" % [i + 1, item.get("name", "Potion")]
			btns[i].modulate = Color.WHITE

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

func _setup_mobile_ability_tooltip(btn: Button, ability_key: String) -> void:
	var hold_timer = Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = 0.6
	add_child(hold_timer)
	hold_timer.timeout.connect(func():
		if not _tooltip_data.has(ability_key):
			return
		_tooltip_label.text = _tooltip_data[ability_key]
		_tooltip_panel.visible = true
		# Position above button (same logic as desktop _show_tooltip)
		await get_tree().process_frame
		var btn_rect = btn.get_global_rect()
		var tip_size = _tooltip_panel.size
		var x_pos = btn_rect.position.x + btn_rect.size.x / 2.0 - tip_size.x / 2.0
		var y_pos = btn_rect.position.y - tip_size.y - 8.0
		x_pos = clampf(x_pos, 4, get_viewport().get_visible_rect().size.x - tip_size.x - 4)
		if y_pos < 4:
			y_pos = btn_rect.position.y + btn_rect.size.y + 8.0
		_tooltip_panel.position = Vector2(x_pos, y_pos)
	)
	btn.button_down.connect(func(): hold_timer.start())
	btn.button_up.connect(func():
		hold_timer.stop()
		if _tooltip_panel.visible:
			# Auto-hide tooltip after 2s
			var hide_tw = create_tween()
			hide_tw.tween_interval(2.0)
			hide_tw.tween_callback(func(): _tooltip_panel.visible = false)
	)

func _show_tooltip() -> void:
	if _hovered_btn == null:
		return
	_tooltip_panel.visible = true
	# Position above the hovered button
	await get_tree().process_frame
	# Re-check after await — user may have unhovered during the frame
	if _hovered_btn == null:
		_tooltip_panel.visible = false
		return
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
	# On mobile, allow tap-to-dismiss; on desktop, ignore mouse so it doesn't block
	if _is_mobile:
		_hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_hint_panel.gui_input.connect(_on_hint_tapped)
	else:
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

	if _is_mobile:
		_hint_queue = [
			{
				"delay": 4.0,
				"text": "[color=#f0d866]TIP:[/color]  Tap [color=#66ccff][b]Q[/b][/color] for [color=#f0d866]%s[/color]  and  [color=#66ccff][b]E[/b][/color] for [color=#f0d866]%s[/color]" % [ab1_name, ab2_name],
			},
			{
				"delay": 15.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#aaddff][b]Hold your hero for 2s[/b][/color] to view detailed stats — HP, Mana, STR, and more",
			},
		]
	else:
		_hint_queue = [
			{
				"delay": 4.0,
				"text": "[color=#f0d866]TIP:[/color]  Press [color=#66ccff][b]Q[/b][/color] for [color=#f0d866]%s[/color]  and  [color=#66ccff][b]E[/b][/color] for [color=#f0d866]%s[/color]" % [ab1_name, ab2_name],
			},
		]

	if is_ranged:
		if _is_mobile:
			_hint_queue.append_array([
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap ATK[/b][/color] while moving for a [color=#ffcc44]Piercing Shot[/color] — arrow passes through all enemies!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#6699ff][b]Triple-tap ATK[/b][/color] for [color=#6699ff]Arrow Rain[/color] — arrows rain down on a target area!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold ATK 1.5s[/b][/color] then release for a [color=#ffcc44]Sniper Shot[/color] — long-range precision hit!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#66eebb][b]Move diagonally + tap ATK[/b][/color] for a [color=#66eebb]Shadow Step[/color] — dodge back and fire a spread!",
				},
			])
		else:
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
		if _is_mobile:
			_hint_queue.append_array([
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap ATK[/b][/color] while moving for a [color=#ffcc44]Power Strike[/color] — heavy single-target hit!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#cc88ff][b]Triple-tap ATK[/b][/color] for a [color=#cc88ff]Whirlwind[/color] — spin attack hitting all nearby enemies!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold ATK 1.5s[/b][/color] then release for a [color=#ffcc44]Charged Slash[/color] — dash through enemies!",
				},
				{
					"delay": 18.0,
					"text": "[color=#f0d866]TIP:[/color]  [color=#66eeff][b]Move diagonally + tap ATK[/b][/color] for a [color=#66eeff]Dash Strike[/color] — quick dash through foes!",
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

	if _is_mobile:
		_hint_queue.append({
			"delay": 18.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaaaaa][b]Tap[/b][/color] enemies to auto-attack  |  [color=#aaaaaa][b]Pinch[/b][/color] to zoom in/out",
		})
		_hint_queue.append({
			"delay": 25.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaddff][b]Hold Q or E for a moment[/b][/color] to see ability details — mana cost, cooldown, and damage",
		})
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  Tap [color=#88ddff][b]Items[/b][/color] to open your inventory  |  Tap [color=#66ff88][b]potion slots[/b][/color] (1, 2, 3) to use consumables",
		})
		_hint_queue.append({
			"delay": 45.0,
			"text": "[color=#f0d866]TIP:[/color]  Walk onto [color=#aaddff][b]colored beacons[/b][/color] for Shops, Armory, and Tavern  |  Attack [color=#88cc66][b]trees[/b][/color] to chop wood",
		})
		# Repeat long-press hint at a longer interval
		_hint_queue.append({
			"delay": 120.0,
			"text": "[color=#f0d866]REMINDER:[/color]  [color=#aaddff][b]Hold your hero for 2s[/b][/color] to check your stats anytime",
		})
	else:
		_hint_queue.append({
			"delay": 18.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaaaaa][b]Left-click[/b][/color] enemies to auto-attack  |  [color=#aaaaaa][b]Right-click[/b][/color] your hero for stats",
		})
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#88ddff][b]I[/b][/color] for inventory  |  [color=#66ff88][b]1, 2, 3[/b][/color] to use potions  |  [color=#aaaaaa]Hover Q/E for ability details[/color]",
		})
		_hint_queue.append({
			"delay": 45.0,
			"text": "[color=#f0d866]TIP:[/color]  Walk onto [color=#aaddff][b]colored beacons[/b][/color] for Shops, Armory, and Tavern  |  Attack [color=#88cc66][b]trees[/b][/color] to chop wood",
		})
		_hint_queue.append({
			"delay": 60.0,
			"text": "[color=#f0d866]TIP:[/color]  Press [color=#aaaaaa][b]Esc[/b][/color] to pause  |  [color=#aaaaaa][b]Help[/b][/color] in the pause menu has all controls and tips",
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

	# Position above the bottom panel using offsets (hint_panel has bottom anchors)
	await get_tree().process_frame
	var panel_w = _hint_panel.size.x
	var panel_h = _hint_panel.size.y
	var vp_size_hint = get_viewport().get_visible_rect().size
	var is_landscape_hint = vp_size_hint.x > vp_size_hint.y
	var bottom_offset = 125.0
	if _is_mobile:
		bottom_offset = 140.0 if is_landscape_hint else 150.0
	_hint_panel.offset_left = -panel_w / 2.0
	_hint_panel.offset_right = panel_w / 2.0
	_hint_panel.offset_bottom = -(bottom_offset + 10)
	_hint_panel.offset_top = -(bottom_offset + panel_h + 10)

	# Fade in → hold → fade out
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_panel, "modulate:a", 1.0, 0.4)
	_hint_tween.tween_interval(6.0)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(_on_hint_finished)

func _on_hint_finished() -> void:
	_hint_panel.visible = false
	_hint_tween = null
	if not _hint_queue.is_empty():
		_hint_timer.wait_time = _hint_queue[0]["delay"]
		_hint_timer.start()

func _on_hint_tapped(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		# Dismiss the current hint immediately on tap
		if _hint_tween and _hint_tween.is_valid():
			_hint_tween.kill()
		_hint_panel.visible = false
		_hint_tween = null
		# Schedule next hint sooner (2s instead of full delay)
		if not _hint_queue.is_empty():
			_hint_timer.wait_time = min(_hint_queue[0]["delay"], 2.0)
			_hint_timer.start()
