extends CanvasLayer

## SC:BW-style HUD with dark bottom console panel, segmented bars,
## 3x3 command card, kill counter, and save/load buttons.

# Top bar refs
@onready var top_bar: HBoxContainer = $TopBar
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var wood_label: Label = $TopBar/WoodLabel
@onready var kills_label: Label = $TopBar/KillsLabel

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


# Tutorial hint system
var _hint_panel: PanelContainer = null
var _hint_label: RichTextLabel = null
var _hint_queue: Array[Dictionary] = []
var _hint_timer: Timer = null
var _hint_showing: bool = false
var _hint_tween: Tween = null

# Command overlay (mobile)
var _cmd_overlay: PanelContainer = null
var _cmd_overlay_visible: bool = false

# Minimap overlay (mobile)
var _map_overlay: PanelContainer = null
var _map_overlay_visible: bool = false
var _map_overlay_vbox: VBoxContainer = null  # Overlay content container for reparenting minimap
var _minimap_home: PanelContainer = null  # Bottom-bar container that holds minimap when overlay is closed
var _opt_btn: Button = null  # OPT button ref for multitouch
var _map_tap_btn: Button = null  # MAP tap button ref for multitouch
var _overlay_open_touch_index: int = -1  # Finger that opened an overlay (ignore its release)

func _ready() -> void:
	_detect_mobile()
	if _is_mobile:
		_apply_mobile_layout()
	else:
		_add_desktop_menu_button()
	_create_hint_panel()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	_is_portrait = _is_mobile and vp_size.y >= vp_size.x

func _apply_mobile_layout() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = vp_size.x > vp_size.y

	# ── Top bar: scale font sizes for readability & keep off rounded corners ──
	# DisplayServer safe area is unreliable on web — use generous fixed insets
	# that cover modern phone rounded corners and notch areas.
	if is_landscape:
		var pad_x = int(vp_size.x * 0.05)  # 5% horizontal padding
		var pad_y = 6
		top_bar.offset_left = pad_x
		top_bar.offset_top = pad_y
		top_bar.offset_bottom = pad_y + 18
		top_bar.offset_right = -pad_x
		gold_label.add_theme_font_size_override("font_size", 10)
		wood_label.add_theme_font_size_override("font_size", 10)
		kills_label.add_theme_font_size_override("font_size", 9)
	else:
		var pad_x = int(vp_size.x * 0.06)  # 6% horizontal padding in portrait
		var pad_y = int(vp_size.y * 0.04)  # 4% top padding for rounded corners + status bar
		top_bar.offset_left = pad_x
		top_bar.offset_top = pad_y
		top_bar.offset_bottom = pad_y + 72
		top_bar.offset_right = -pad_x
		gold_label.add_theme_font_size_override("font_size", 44)
		wood_label.add_theme_font_size_override("font_size", 44)
		kills_label.add_theme_font_size_override("font_size", 38)

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

		# MAP panel — shows live minimap, tap to expand
		var btn_w = panel_h * 2  # 2x width for comfortable touch targets
		_minimap_home = PanelContainer.new()
		_minimap_home.custom_minimum_size = Vector2(btn_w, 0)
		_minimap_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_minimap_home.add_theme_stylebox_override("panel", btn_style_normal.duplicate())
		# Reparent minimap from bottom_hbox into this panel
		minimap.get_parent().remove_child(minimap)
		minimap.custom_minimum_size = Vector2(0, 0)
		minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		minimap.visible = true
		minimap.click_to_move_enabled = false  # Small preview: tap opens overlay instead
		minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let taps pass through to parent
		_minimap_home.add_child(minimap)
		# Make the panel clickable — use a transparent Button overlay for reliable touch
		_map_tap_btn = Button.new()
		_map_tap_btn.flat = true
		_map_tap_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_map_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_map_tap_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_tap_btn.self_modulate = Color(1, 1, 1, 0)  # Invisible
		_map_tap_btn.pressed.connect(_toggle_map_overlay)
		_minimap_home.add_child(_map_tap_btn)
		bottom_hbox.add_child(_minimap_home)
		bottom_hbox.move_child(_minimap_home, 0)  # Move to leftmost position

		# OPT button — wide, right of bars
		_opt_btn = Button.new()
		_opt_btn.text = "OPT"
		_opt_btn.custom_minimum_size = Vector2(btn_w, 0)
		_opt_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_opt_btn.add_theme_font_size_override("font_size", 28)
		_opt_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_opt_btn.add_theme_stylebox_override("normal", btn_style_normal.duplicate())
		_opt_btn.add_theme_stylebox_override("pressed", btn_style_pressed.duplicate())
		_opt_btn.add_theme_stylebox_override("hover", btn_style_normal.duplicate())
		_opt_btn.pressed.connect(_toggle_cmd_overlay)
		bottom_hbox.add_child(_opt_btn)

		# Build overlays (hidden by default)
		_build_cmd_overlay()
		_build_map_overlay()
		return

	# ── LANDSCAPE: compact strip with MAP and OPT buttons ──
	var bar_h_ls = 40
	var panel_h_ls = bar_h_ls * 3 + 10  # 3 bars + spacing = ~130px
	bottom_panel.offset_top = -panel_h_ls
	bottom_hbox.add_theme_constant_override("separation", 2)

	level_label.visible = false
	hp_bar.custom_minimum_size.y = bar_h_ls
	mana_bar.custom_minimum_size.y = bar_h_ls
	xp_bar.custom_minimum_size.y = bar_h_ls
	unit_info.add_theme_constant_override("separation", 1)

	# Hide the default command card — we use MAP + OPT overlays instead
	command_card.visible = false

	# Shared button style for landscape
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
	btn_style_normal.border_color = Color(0.5, 0.4, 0.18, 0.8)
	btn_style_normal.set_border_width_all(2)
	btn_style_normal.set_corner_radius_all(6)
	btn_style_normal.set_content_margin_all(0)

	var btn_style_pressed = btn_style_normal.duplicate()
	btn_style_pressed.bg_color = Color(0.25, 0.2, 0.08, 0.95)
	btn_style_pressed.border_color = Color(0.9, 0.75, 0.3, 1.0)

	# MAP panel — shows live minimap, tap to expand
	var btn_w = panel_h_ls
	_minimap_home = PanelContainer.new()
	_minimap_home.custom_minimum_size = Vector2(btn_w, 0)
	_minimap_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap_home.add_theme_stylebox_override("panel", btn_style_normal.duplicate())
	minimap.get_parent().remove_child(minimap)
	minimap.custom_minimum_size = Vector2(0, 0)
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap.visible = true
	minimap.click_to_move_enabled = false
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let taps pass through to button
	_minimap_home.add_child(minimap)
	# Use a transparent Button overlay for reliable touch on mobile
	_map_tap_btn = Button.new()
	_map_tap_btn.flat = true
	_map_tap_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_tap_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_tap_btn.self_modulate = Color(1, 1, 1, 0)
	_map_tap_btn.pressed.connect(_toggle_map_overlay)
	_minimap_home.add_child(_map_tap_btn)
	bottom_hbox.add_child(_minimap_home)
	bottom_hbox.move_child(_minimap_home, 0)

	# OPT button — right of bars
	_opt_btn = Button.new()
	_opt_btn.text = "OPT"
	_opt_btn.custom_minimum_size = Vector2(btn_w, 0)
	_opt_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_opt_btn.add_theme_font_size_override("font_size", 16)
	_opt_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_opt_btn.add_theme_stylebox_override("normal", btn_style_normal.duplicate())
	_opt_btn.add_theme_stylebox_override("pressed", btn_style_pressed.duplicate())
	_opt_btn.add_theme_stylebox_override("hover", btn_style_normal.duplicate())
	_opt_btn.pressed.connect(_toggle_cmd_overlay)
	bottom_hbox.add_child(_opt_btn)

	# Build overlays (hidden by default)
	_build_cmd_overlay()
	_build_map_overlay()

func _build_cmd_overlay() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = _is_mobile and vp_size.x > vp_size.y

	_cmd_overlay = PanelContainer.new()
	_cmd_overlay.visible = false
	_cmd_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8 if is_landscape else 16)
	_cmd_overlay.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4 if is_landscape else 8)
	_cmd_overlay.add_child(vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title = Label.new()
	title.text = "Commands"
	title.add_theme_font_size_override("font_size", 18 if is_landscape else 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "X"
	var close_size = Vector2(60, 40) if is_landscape else (Vector2(160, 130) if _is_mobile else Vector2(120, 40))
	var close_fs = 22 if is_landscape else (60 if _is_mobile else 20)
	close_btn.custom_minimum_size = close_size
	close_btn.add_theme_font_size_override("font_size", close_fs)
	_style_btn(close_btn, Color(1.0, 0.4, 0.3))
	close_btn.pressed.connect(_toggle_cmd_overlay)
	title_row.add_child(close_btn)

	# 3x3 grid of command buttons
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4 if is_landscape else 6)
	grid.add_theme_constant_override("v_separation", 4 if is_landscape else 6)
	vbox.add_child(grid)

	var btn_size = Vector2(0, 40) if is_landscape else Vector2(0, 90)
	var fs = 14 if is_landscape else 26

	var log_b = Button.new()
	log_b.text = "F1\nLog"
	log_b.custom_minimum_size = btn_size
	log_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_b.add_theme_font_size_override("font_size", fs)
	_style_btn(log_b, Color(0.7, 0.7, 0.8))
	log_b.pressed.connect(func():
		_on_changelog_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(log_b)

	for i in range(3):
		var p = Button.new()
		p.text = "%d\n---" % (i + 1)
		p.custom_minimum_size = btn_size
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_font_size_override("font_size", fs)
		_style_btn(p, Color(0.5, 1.0, 0.5))
		var idx = i
		p.pressed.connect(func():
			if _player and is_instance_valid(_player):
				_player.inventory.use_consumable(idx)
			_toggle_cmd_overlay()
		)
		grid.add_child(p)

	var inv_b = Button.new()
	inv_b.text = "I\nItems"
	inv_b.custom_minimum_size = btn_size
	inv_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_b.add_theme_font_size_override("font_size", fs)
	_style_btn(inv_b, Color(0.5, 0.8, 1.0))
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
	_style_btn(save_b, Color(0.4, 0.7, 1.0))
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
	_style_btn(load_b, Color(0.4, 0.7, 1.0))
	load_b.pressed.connect(func():
		_on_load_pressed()
		_toggle_cmd_overlay()
	)
	grid.add_child(load_b)

	var menu_b = Button.new()
	menu_b.text = "Menu"
	menu_b.custom_minimum_size = btn_size
	menu_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_b.add_theme_font_size_override("font_size", fs)
	_style_btn(menu_b, Color(0.9, 0.75, 0.3))
	menu_b.pressed.connect(func():
		_toggle_cmd_overlay()
		_open_pause_menu()
	)
	grid.add_child(menu_b)

	add_child(_cmd_overlay)

func _toggle_cmd_overlay() -> void:
	# Close MAP overlay if open
	if _map_overlay and _map_overlay_visible:
		_map_overlay_visible = false
		_map_overlay.visible = false

	_cmd_overlay_visible = !_cmd_overlay_visible
	_cmd_overlay.visible = _cmd_overlay_visible
	_update_atk_button_visibility()
	if _cmd_overlay_visible:
		AudioManager.play_sfx("ui_tap", -4.0)
		_update_overlay_potions()
		await get_tree().process_frame
		await get_tree().process_frame
		var vp_size = get_viewport().get_visible_rect().size
		var overlay_w = vp_size.x - 32
		var actual_h = _cmd_overlay.get_combined_minimum_size().y
		_cmd_overlay.position = Vector2(16, vp_size.y - bottom_panel.size.y - actual_h - 8)
		_cmd_overlay.size = Vector2(overlay_w, actual_h)

func _update_atk_button_visibility() -> void:
	if _player and is_instance_valid(_player) and _player.has_method("set_atk_button_visible"):
		_player.set_atk_button_visible(not _cmd_overlay_visible and not _map_overlay_visible)

func _update_overlay_potions() -> void:
	if not _cmd_overlay or not _player or not is_instance_valid(_player):
		return
	var grid = _cmd_overlay.get_child(0).get_child(1) as GridContainer  # vbox -> grid
	var inv = _player.inventory
	var names = ["Small", "Medium", "Great"]
	# Potion buttons are children 1, 2, 3 of the grid (after Log button)
	for i in range(3):
		var btn = grid.get_child(1 + i) as Button
		var count = inv.potion_counts[i]
		if count <= 0:
			btn.text = "%d\n---" % (i + 1)
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = "%d\n%s x%d" % [i + 1, names[i], count]
			btn.modulate = Color.WHITE

func _build_map_overlay() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = _is_mobile and vp_size.x > vp_size.y

	_map_overlay = PanelContainer.new()
	_map_overlay.visible = false
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color(0.3, 0.4, 0.55, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6 if is_landscape else 12)
	_map_overlay.add_theme_stylebox_override("panel", style)

	_map_overlay_vbox = VBoxContainer.new()
	_map_overlay_vbox.add_theme_constant_override("separation", 4 if is_landscape else 6)
	_map_overlay.add_child(_map_overlay_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	_map_overlay_vbox.add_child(title_row)
	var title = Label.new()
	title.text = "Map"
	title.add_theme_font_size_override("font_size", 16 if is_landscape else 36)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "X"
	var close_size = Vector2(50, 36) if is_landscape else (Vector2(160, 130) if _is_mobile else Vector2(120, 40))
	var close_fs = 20 if is_landscape else (60 if _is_mobile else 20)
	close_btn.custom_minimum_size = close_size
	close_btn.add_theme_font_size_override("font_size", close_fs)
	_style_btn(close_btn, Color(1.0, 0.4, 0.3))
	close_btn.pressed.connect(_toggle_map_overlay)
	title_row.add_child(close_btn)

	add_child(_map_overlay)

func _toggle_map_overlay() -> void:
	# Close CMD overlay if open
	if _cmd_overlay and _cmd_overlay_visible:
		_cmd_overlay_visible = false
		_cmd_overlay.visible = false

	_map_overlay_visible = !_map_overlay_visible
	_map_overlay.visible = _map_overlay_visible
	_update_atk_button_visibility()
	if _map_overlay_visible:
		AudioManager.play_sfx("ui_tap", -4.0)
		# Reparent minimap into the expanded overlay
		if _minimap_home and minimap.get_parent() == _minimap_home:
			_minimap_home.remove_child(minimap)
			_map_overlay_vbox.add_child(minimap)
			minimap.click_to_move_enabled = true
		await get_tree().process_frame
		var vp_size = get_viewport().get_visible_rect().size
		var is_ls = vp_size.x > vp_size.y
		var overlay_w: float
		var map_h: float
		if is_ls:
			map_h = vp_size.y * 0.55
			overlay_w = min(vp_size.x * 0.5, map_h * 1.4)
		else:
			overlay_w = vp_size.x - 32
			map_h = vp_size.x * 0.65
		_map_overlay.size = Vector2(overlay_w, map_h)
		_map_overlay.position = Vector2((vp_size.x - overlay_w) / 2.0, vp_size.y - bottom_panel.size.y - map_h - 8)
	else:
		# Reparent minimap back into the bottom-bar home panel
		if _minimap_home and minimap.get_parent() != _minimap_home:
			minimap.get_parent().remove_child(minimap)
			_minimap_home.add_child(minimap)
			minimap.click_to_move_enabled = false
			minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let tap button receive input

func _open_pause_menu() -> void:
	var menus = get_tree().get_nodes_in_group("pause_menu")
	if menus.size() > 0:
		menus[0].toggle()

func _add_desktop_menu_button() -> void:
	# Add a Menu button to the command card grid (after Load)
	var menu_btn = Button.new()
	menu_btn.text = "Esc\nMenu"
	menu_btn.custom_minimum_size = Vector2(68, 32)
	menu_btn.add_theme_font_size_override("font_size", 10)
	_style_btn(menu_btn, Color(0.9, 0.75, 0.3))
	menu_btn.pressed.connect(_open_pause_menu)
	command_grid.add_child(menu_btn)

func setup(player: Node2D) -> void:
	_player = player
	minimap.setup(player)
	var stats: StatsComponent = player.stats

	stats.hp_changed.connect(_on_hp_changed)
	stats.mana_changed.connect(_on_mana_changed)
	stats.xp_changed.connect(_on_xp_changed)
	stats.leveled_up.connect(_on_leveled_up)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.wood_changed.connect(_on_wood_changed)
	GameManager.kills_changed.connect(_on_kills_changed)

	var hero_data = HeroData.get_hero(player.hero_class)

	# Connect command card buttons
	log_btn.text = "F1\nLog"
	log_btn.disabled = false
	log_btn.pressed.connect(_on_changelog_pressed)

	# Potion slots — tap to use consumable (Button.pressed for desktop mouse clicks)
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

	# Pass potion button refs to player for multitouch handling on mobile
	player._mobile_potion_btns = [potion_1_btn, potion_2_btn, potion_3_btn]

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
	_on_kills_changed(GameManager.total_kills)

	# Start tutorial hints after a short delay
	_start_tutorial_hints(hero_data)

func _input(event: InputEvent) -> void:
	# ── Mobile multitouch handling ──
	# Godot's Button only responds to the first finger (mouse emulation).
	# We manually detect all InputEventScreenTouch so a second finger can
	# tap HUD buttons while another finger controls the joystick / aim.
	if _is_mobile and event is InputEventScreenTouch:
		# When the finger that OPENED an overlay lifts, consume the release
		# so Godot's Button mouse-emulation doesn't toggle it back closed.
		if not event.pressed and event.index == _overlay_open_touch_index:
			_overlay_open_touch_index = -1
			get_viewport().set_input_as_handled()
			return

		if event.pressed:
			var pos = event.position

			# 1) Bottom-bar buttons: OPT and MAP (always visible when mobile)
			if _opt_btn and _opt_btn.is_visible_in_tree() and _opt_btn.get_global_rect().has_point(pos):
				_toggle_cmd_overlay()
				if _cmd_overlay_visible:
					_overlay_open_touch_index = event.index
				get_viewport().set_input_as_handled()
				return
			if _map_tap_btn and _map_tap_btn.is_visible_in_tree() and _map_tap_btn.get_global_rect().has_point(pos):
				_toggle_map_overlay()
				if _map_overlay_visible:
					_overlay_open_touch_index = event.index
				get_viewport().set_input_as_handled()
				return

			# 2) Open overlay: press buttons inside via multitouch, or close if outside
			if _cmd_overlay_visible and _cmd_overlay:
				if _cmd_overlay.get_global_rect().has_point(pos):
					_press_button_at(_cmd_overlay, pos)
				else:
					_toggle_cmd_overlay()
				get_viewport().set_input_as_handled()
				return
			if _map_overlay_visible and _map_overlay:
				if _map_overlay.get_global_rect().has_point(pos):
					_press_button_at(_map_overlay, pos)
				else:
					_toggle_map_overlay()
				get_viewport().set_input_as_handled()
				return

			# No overlay open and tap not on MAP/OPT — let event pass to game world
			return

	# ── Desktop / first-finger fallback: close overlay on outside click ──
	if not _cmd_overlay_visible and not _map_overlay_visible:
		return
	var is_touch = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not is_touch:
		return
	var pos = event.position
	if _cmd_overlay_visible and _cmd_overlay and _cmd_overlay.get_global_rect().has_point(pos):
		return
	if _map_overlay_visible and _map_overlay and _map_overlay.get_global_rect().has_point(pos):
		return
	if _cmd_overlay_visible:
		_toggle_cmd_overlay()
	elif _map_overlay_visible:
		_toggle_map_overlay()
	get_viewport().set_input_as_handled()

## Recursively find and press the Button under a touch position (for multitouch).
func _press_button_at(container: Control, pos: Vector2) -> bool:
	for child in container.get_children():
		if child is Button and child.is_visible_in_tree() and child.get_global_rect().has_point(pos):
			child.pressed.emit()
			return true
		if child is Control and _press_button_at(child, pos):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Also catch any unhandled touch while overlay is open (belt and suspenders)
	if _cmd_overlay_visible or _map_overlay_visible:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			if _cmd_overlay_visible:
				_toggle_cmd_overlay()
			elif _map_overlay_visible:
				_toggle_map_overlay()
			get_viewport().set_input_as_handled()
			return
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

func _style_btn(btn: Button, accent: Color = Color(0.9, 0.75, 0.3)) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
	normal.border_color = accent * Color(0.5, 0.5, 0.5, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(4)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 0.95)
	hover.border_color = accent * Color(0.8, 0.8, 0.8, 0.8)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.25, 0.22, 0.14, 0.95)
	pressed.border_color = accent
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

func _on_kills_changed(total: int) -> void:
	kills_label.text = "Kills: %d" % total


func _update_potion_labels() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var inv = _player.inventory
	var btns = [potion_1_btn, potion_2_btn, potion_3_btn]
	var names = ["Small", "Medium", "Great"]
	for i in range(3):
		var count = inv.potion_counts[i]
		if count <= 0:
			btns[i].text = "%d\n---" % (i + 1)
			btns[i].modulate = Color(0.5, 0.5, 0.5)
		else:
			btns[i].text = "%d\n%s x%d" % [i + 1, names[i], count]
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
	AudioManager.play_sfx("save_game")

func _on_load_pressed() -> void:
	SaveLoadManager.load_game()
	AudioManager.play_sfx("load_game")
	if _player and is_instance_valid(_player):
		SaveLoadManager.apply_to_player(_player)


# ── Tutorial Hint System ────────────────────────────────────────────────

func _create_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.visible = false
	_hint_panel.z_index = 50
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if _is_mobile:
		_hint_panel.gui_input.connect(_on_hint_tapped)
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

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.8))
	if _is_mobile:
		_hint_label.custom_minimum_size = Vector2(650, 0)
		_hint_label.add_theme_font_size_override("normal_font_size", 38)
		_hint_label.add_theme_font_size_override("bold_font_size", 40)
	else:
		_hint_label.custom_minimum_size = Vector2(460, 0)
		_hint_label.add_theme_font_size_override("normal_font_size", 14)
		_hint_label.add_theme_font_size_override("bold_font_size", 15)
	hbox.add_child(_hint_label)

	# Close (X) button — always available on both mobile and desktop
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
	close_btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	if _is_mobile:
		close_btn.custom_minimum_size = Vector2(80, 80)
		close_btn.add_theme_font_size_override("font_size", 48)
	else:
		close_btn.custom_minimum_size = Vector2(36, 36)
		close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(_dismiss_hint)
	hbox.add_child(close_btn)

	_hint_panel.add_child(hbox)

	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_show_next_hint)
	add_child(_hint_timer)
	add_child(_hint_panel)

func _dismiss_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_panel.visible = false
	_hint_tween = null
	if not _hint_queue.is_empty():
		_hint_timer.wait_time = max(_hint_queue[0]["delay"], 30.0)
		_hint_timer.start()

func _start_tutorial_hints(hero_data: Dictionary) -> void:
	var is_ranged = _player and _player.hero_class == "shadow_ranger"
	var hero_name = "Blade Knight" if not is_ranged else "Shadow Ranger"
	var ATK = "[color=#ff9966][b]ATK button[/b][/color]" if _is_mobile else "[color=#ff9966][b]SPACE[/b][/color]"
	var DIAG = "[color=#66eeff][b]Move diagonally + tap ATK[/b][/color]" if _is_mobile else "[color=#66eeff][b]Diagonal keys + SPACE[/b][/color]"

	_hint_queue = []

	# --- 1. Special attacks (hero-specific, platform-aware) ---
	if is_ranged:
		_hint_queue.append_array([
			{
				"delay": 15.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap %s[/b][/color] while moving → [color=#ffcc44]Piercing Shot[/color] — arrow passes through all enemies!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#6699ff][b]Triple-tap %s[/b][/color] → [color=#6699ff]Arrow Rain[/color] — 6 arrows rain down on a target area!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold %s for 1.5s[/b][/color] then release → [color=#ffcc44]Sniper Shot[/color] — massive long-range precision hit!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  %s → [color=#66eebb]Shadow Step[/color] — dodge backward and fire a 3-arrow spread!" % DIAG,
			},
		])
	else:
		_hint_queue.append_array([
			{
				"delay": 15.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ff9966][b]Double-tap %s[/b][/color] while moving → [color=#ffcc44]Power Strike[/color] — 1.4x heavy single-target hit!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#cc88ff][b]Triple-tap %s[/b][/color] → [color=#cc88ff]Whirlwind[/color] — 720° spin hitting every enemy around you!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  [color=#ffdd55][b]Hold %s for 1.5s[/b][/color] then release → [color=#ffcc44]Charged Slash[/color] — dash through enemies for 1.6x damage!" % ("ATK" if _is_mobile else "SPACE"),
			},
			{
				"delay": 30.0,
				"text": "[color=#f0d866]TIP:[/color]  %s → [color=#66eeff]Dash Strike[/color] — quick spin-dash through foes!" % DIAG,
			},
		])

	# --- 2b. Cursor hint (mobile, early game, rare) ---
	if _is_mobile:
		_hint_queue.append({
			"delay": 35.0,
			"text": "[color=#f0d866]TIP:[/color]  The [color=#f0cc4a][b]gold cursor[/b][/color] shows where you're pointing — tap enemies, beacons, or trees to interact with them",
		})

	# --- 3. Controls (platform-specific) ---
	if _is_mobile:
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaaaaa][b]Tap[/b][/color] enemies to auto-attack  |  [color=#aaaaaa][b]Pinch[/b][/color] to zoom in/out",
		})
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaddff][b]Touch and hold your hero for 2s[/b][/color] to view detailed stats — HP, Mana, STR, buffs, and more",
		})
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  Tap [color=#88ddff][b]Items[/b][/color] to open your inventory  |  Tap [color=#66ff88][b]potion slots[/b][/color] to use consumables in battle",
		})
	else:
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#aaaaaa][b]Left-click[/b][/color] enemies to auto-attack  |  [color=#aaaaaa][b]Right-click[/b][/color] your hero for stats panel",
		})
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  [color=#88ddff][b]I[/b][/color] for inventory  |  [color=#66ff88][b]1, 2, 3[/b][/color] to use potions",
		})

	# --- 4. Healing & beacons ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Step onto a [color=#66ff88][b]green beacon[/b][/color] to fully restore HP and Mana — you're also [color=#66ff88]immune to all damage[/color] while standing on it",
	})

	# --- 5. Shops & town ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Walk onto [color=#ffdd55][b]yellow beacons[/b][/color] near buildings for Shops, Armory, and Tavern  |  Buy gear, potions, and upgrade your equipment",
	})

	# --- 6. Trees & wood ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Attack [color=#88cc66][b]trees[/b][/color] to chop wood — small trees drop ~15, medium ~30, large ~60  |  Wood is used for building and upgrades",
	})

	# --- 7. Item drops & equipment ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Enemies drop [color=#ddaaff][b]equipment[/b][/color] and [color=#ffdd55][b]gold[/b][/color] when killed  |  Walk over drops to pick them up  |  Equip gear from your inventory for stat boosts",
	})

	# --- 8. Leveling & sprite upgrades ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Your %s [color=#ffcc44][b]upgrades visually[/b][/color] every 5 levels — stronger armor and new details appear as you grow!" % hero_name,
	})

	# --- 9. Minibosses ---
	_hint_queue.append({
		"delay": 30.0,
		"text": "[color=#f0d866]TIP:[/color]  Watch for [color=#ff6666][b]red beacons[/b][/color] — they spawn [color=#ff6666]minibosses[/color] with high HP and big rewards  |  Come prepared with potions and full mana!",
	})

	# --- 10. Pause / help ---
	if _is_mobile:
		_hint_queue.append({
			"delay": 60.0,
			"text": "[color=#f0d866]REMINDER:[/color]  [color=#aaddff][b]Touch and hold your hero[/b][/color] to check stats anytime — see buffs, debuffs, armor, dodge, and more",
		})
	else:
		_hint_queue.append({
			"delay": 30.0,
			"text": "[color=#f0d866]TIP:[/color]  Press [color=#aaaaaa][b]Esc[/b][/color] to pause  |  The [color=#aaaaaa][b]Help[/b][/color] menu has all controls and tips",
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
	_hint_tween.tween_interval(12.0)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(_on_hint_finished)

func _on_hint_finished() -> void:
	_hint_panel.visible = false
	_hint_tween = null
	if not _hint_queue.is_empty():
		_hint_timer.wait_time = max(_hint_queue[0]["delay"], 30.0)
		_hint_timer.start()

func _on_hint_tapped(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		# Dismiss the current hint immediately on tap
		if _hint_tween and _hint_tween.is_valid():
			_hint_tween.kill()
		_hint_panel.visible = false
		_hint_tween = null
		# Schedule next hint with at least 30s gap
		if not _hint_queue.is_empty():
			_hint_timer.wait_time = max(_hint_queue[0]["delay"], 30.0)
			_hint_timer.start()
