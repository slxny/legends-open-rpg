extends CanvasLayer

## Pause menu — Escape opens this instead of quitting.
## Pauses the game tree while open. Includes changelog, help, save/load, quit.

@onready var panel: PanelContainer = $Panel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

func setup(player: Node2D) -> void:
	_player = player

func toggle() -> void:
	if _is_visible:
		close()
	else:
		open()

func open() -> void:
	if _is_visible:
		return
	_is_visible = true
	_detect_mobile()
	_build_menu()
	panel.visible = true
	get_tree().paused = true

func close() -> void:
	if not _is_visible:
		return
	_is_visible = false
	panel.visible = false
	get_tree().paused = false

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()

func _build_menu() -> void:
	# Clear previous content
	for child in panel.get_children():
		child.queue_free()

	var vp_size = get_viewport().get_visible_rect().size
	if _is_mobile:
		var margin = 40.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
	else:
		panel.offset_left = -200.0
		panel.offset_right = 200.0
		panel.offset_top = -220.0
		panel.offset_bottom = 220.0

	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16 if _is_mobile else 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Top bar with title and close button
	var top_bar = HBoxContainer.new()

	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 64 if _is_mobile else 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	top_bar.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(160, 130) if _is_mobile else Vector2(40, 32)
	close_btn.add_theme_font_size_override("font_size", 60 if _is_mobile else 16)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_style_btn(close_btn, Color(1.0, 0.4, 0.3))
	close_btn.pressed.connect(func(): close())
	top_bar.add_child(close_btn)

	vbox.add_child(top_bar)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Menu buttons
	var btn_size = Vector2(0, 90) if _is_mobile else Vector2(0, 44)
	var btn_font = 40 if _is_mobile else 16

	_add_menu_button(vbox, "Resume", btn_size, btn_font, Color(0.3, 0.8, 0.4), func(): close())
	_add_menu_button(vbox, "Save Game", btn_size, btn_font, Color(0.4, 0.7, 1.0), _on_save)
	_add_menu_button(vbox, "Load Game", btn_size, btn_font, Color(0.4, 0.7, 1.0), _on_load)
	_add_menu_button(vbox, "Changelog", btn_size, btn_font, Color(0.7, 0.7, 0.8), _on_changelog)
	_add_menu_button(vbox, "Help", btn_size, btn_font, Color(0.7, 0.7, 0.8), _on_help)
	_add_menu_button(vbox, "Quit Game", btn_size, btn_font, Color(1.0, 0.4, 0.3), _on_quit)

	margin_container.add_child(vbox)
	panel.add_child(margin_container)

func _add_menu_button(parent: VBoxContainer, text: String, min_size: Vector2, font_size: int, color: Color, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", color)
	_style_btn(btn, color)
	btn.pressed.connect(callback)
	parent.add_child(btn)

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

func _on_save() -> void:
	SaveLoadManager.save_game()
	AudioManager.play_sfx("save_game")
	close()

func _on_load() -> void:
	SaveLoadManager.load_game()
	AudioManager.play_sfx("load_game")
	if _player and is_instance_valid(_player):
		SaveLoadManager.apply_to_player(_player)
	close()

func _on_changelog() -> void:
	close()
	var dialogs = get_tree().get_nodes_in_group("changelog_dialog")
	if dialogs.size() > 0:
		dialogs[0].open()

func _on_help() -> void:
	close()
	_show_help_dialog()

func _on_quit() -> void:
	get_tree().quit()

func _show_help_dialog() -> void:
	var help_layer = CanvasLayer.new()
	help_layer.layer = 50
	get_tree().current_scene.add_child(help_layer)

	var help_panel = PanelContainer.new()
	help_panel.anchors_preset = Control.PRESET_CENTER
	help_panel.anchor_left = 0.5
	help_panel.anchor_top = 0.5
	help_panel.anchor_right = 0.5
	help_panel.anchor_bottom = 0.5
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var vp_size = get_viewport().get_visible_rect().size
	if _is_mobile:
		var m = 10.0
		help_panel.offset_left = -vp_size.x / 2.0 + m
		help_panel.offset_right = vp_size.x / 2.0 - m
		help_panel.offset_top = -vp_size.y / 2.0 + m
		help_panel.offset_bottom = vp_size.y / 2.0 - m
	else:
		help_panel.offset_left = -300.0
		help_panel.offset_right = 300.0
		help_panel.offset_top = -280.0
		help_panel.offset_bottom = 280.0
	help_layer.add_child(help_panel)

	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 16)
	mc.add_theme_constant_override("margin_top", 16)
	mc.add_theme_constant_override("margin_right", 16)
	mc.add_theme_constant_override("margin_bottom", 16)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Top bar with title and close
	var top = HBoxContainer.new()
	var htitle = Label.new()
	htitle.text = "Controls & Help"
	htitle.add_theme_font_size_override("font_size", 48 if _is_mobile else 20)
	htitle.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	top.add_child(htitle)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "X" if _is_mobile else "Close"
	close_btn.custom_minimum_size = Vector2(160, 130) if _is_mobile else Vector2(80, 32)
	if _is_mobile:
		close_btn.add_theme_font_size_override("font_size", 60)
	_style_btn(close_btn, Color(1.0, 0.4, 0.3))
	close_btn.pressed.connect(func(): help_layer.queue_free())
	top.add_child(close_btn)
	vbox.add_child(top)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Help content in a scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content = Label.new()
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fs = 34 if _is_mobile else 13
	content.add_theme_font_size_override("font_size", fs)
	content.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	content.text = """Movement: WASD or right-click to move
Attack: Space bar or left-click an enemy
Abilities: Q and E (or tap ability buttons)
Inventory: I key (or tap Items button)
Interact: F key (walk onto beacons)
Fullscreen: F11

Potions: 1, 2, 3 keys (or tap potion buttons)
Changelog: F1 key

Tips:
- Click enemies to select and view their stats
- Right-click your hero to view detailed stats
- Walk onto colored beacons to interact with NPCs
- Buy gear from the Shop to get stronger
- Visit the Armory and Woodworker for permanent upgrades
- The Tavern offers temporary buffs... with risks
- Chop trees for wood (attack them!)
- Capture towns by defeating the boss nearby
- Save often! Use Save Game in the pause menu"""
	scroll.add_child(content)
	vbox.add_child(scroll)

	mc.add_child(vbox)
	help_panel.add_child(mc)

	# Close on escape
	var input_handler = Node.new()
	input_handler.set_script(null)
	help_layer.add_child(input_handler)
	help_layer.set_meta("_close_on_cancel", true)
	# Use a timer to check for escape since we can't easily add _unhandled_input
	# Instead, connect close_btn and let user tap/click Close

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event.is_action_pressed("ui_cancel"):
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
