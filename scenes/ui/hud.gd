extends CanvasLayer

## SC:BW-style HUD with dark bottom console panel and segmented bars.

# Top bar refs
@onready var gold_label: Label = $TopBar/GoldLabel

# Bottom console panel refs
@onready var hp_bar: SCBar = $BottomPanel/HBox/UnitInfo/HPBar
@onready var mana_bar: SCBar = $BottomPanel/HBox/UnitInfo/ManaBar
@onready var level_label: Label = $BottomPanel/HBox/UnitInfo/InfoLine
@onready var xp_bar: SCBar = $BottomPanel/HBox/UnitInfo/XPBar

# Minimap
@onready var minimap: Control = $BottomPanel/HBox/Minimap

# Command card refs
@onready var ability_1_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability1
@onready var ability_2_btn: Button = $BottomPanel/HBox/CommandCard/Grid/Ability2

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

	# Ability names
	var hero_data = HeroData.get_hero(player.hero_class)
	if hero_data.has("abilities"):
		var ab = hero_data["abilities"]
		if ab.has("ability_1"):
			ability_1_btn.text = "Q\n" + ab["ability_1"]["name"]
		if ab.has("ability_2"):
			ability_2_btn.text = "E\n" + ab["ability_2"]["name"]

	# Initial values
	_on_hp_changed(stats.current_hp, stats.get_total_max_hp())
	_on_mana_changed(stats.current_mana, stats.get_total_max_mana())
	_on_xp_changed(stats.xp, stats.get_xp_to_next_level())
	level_label.text = "%s  Lv %d  Adventurer" % [hero_data.get("name", "Hero"), stats.level]
	_on_gold_changed(GameManager.gold)

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

func _on_ability_cooldown(index: int, remaining: float, total: float) -> void:
	var btn = ability_1_btn if index == 0 else ability_2_btn
	if remaining > 0:
		btn.disabled = true
		btn.tooltip_text = "%.1fs" % remaining
	else:
		btn.disabled = false
		btn.tooltip_text = "Ready"
