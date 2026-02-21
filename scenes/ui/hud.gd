extends CanvasLayer

## SC:BW-style HUD with dark bottom console panel, segmented bars,
## 3x3 command card, alignment display, and save/load buttons.

# Top bar refs
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var wood_label: Label = $TopBar/WoodLabel
@onready var alignment_label: Label = $TopBar/AlignmentLabel

# Bottom console panel refs
@onready var hp_bar: SCBar = $BottomPanel/HBox/UnitInfo/HPBar
@onready var mana_bar: SCBar = $BottomPanel/HBox/UnitInfo/ManaBar
@onready var level_label: Label = $BottomPanel/HBox/UnitInfo/InfoLine
@onready var xp_bar: SCBar = $BottomPanel/HBox/UnitInfo/XPBar

# Minimap
@onready var minimap: Control = $BottomPanel/HBox/Minimap

# Command card refs (3x3 grid)
@onready var ability_1_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability1
@onready var ability_2_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability2
@onready var log_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Slot3
@onready var save_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Save
@onready var load_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Load

var _player: Node2D = null

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

	# Ability names
	var hero_data = HeroData.get_hero(player.hero_class)
	if hero_data.has("abilities"):
		var ab = hero_data["abilities"]
		if ab.has("ability_1"):
			ability_1_btn.text = "Q\n" + ab["ability_1"]["name"]
		if ab.has("ability_2"):
			ability_2_btn.text = "E\n" + ab["ability_2"]["name"]

	# Connect command card buttons
	log_btn.text = "F1\nLog"
	log_btn.disabled = false
	log_btn.pressed.connect(_on_changelog_pressed)
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

func _unhandled_input(event: InputEvent) -> void:
	# F1 = Changelog, F5 = Save, F9 = Load
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_on_changelog_pressed()
		elif event.keycode == KEY_F5:
			_on_save_pressed()
		elif event.keycode == KEY_F9:
			_on_load_pressed()

func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.label_text = "%d / %d" % [current, maximum]
	hp_bar.set_value(current, maximum)

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.label_text = "%d / %d" % [current, maximum]
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

func _on_ability_cooldown(index: int, remaining: float, total: float) -> void:
	var btn = ability_1_btn if index == 0 else ability_2_btn
	if remaining > 0:
		btn.disabled = true
		btn.tooltip_text = "%.1fs" % remaining
	else:
		btn.disabled = false
		btn.tooltip_text = "Ready"

func _on_changelog_pressed() -> void:
	var dialogs = get_tree().get_nodes_in_group("changelog_dialog")
	if dialogs.size() > 0:
		var dlg = dialogs[0]
		if dlg._is_visible:
			dlg.close()
		else:
			dlg.open()

func _on_save_pressed() -> void:
	SaveLoadManager.save_game()

func _on_load_pressed() -> void:
	SaveLoadManager.load_game()
	if _player and is_instance_valid(_player):
		SaveLoadManager.apply_to_player(_player)
