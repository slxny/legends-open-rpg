extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var equipment_grid: GridContainer = $Panel/MarginContainer/VBox/HBox/EquipmentPanel/EquipGrid
@onready var bag_grid: GridContainer = $Panel/MarginContainer/VBox/HBox/BagPanel/BagGrid
@onready var stats_label: Label = $Panel/MarginContainer/VBox/HBox/StatsPanel/StatsLabel
@onready var item_tooltip: PanelContainer = $ItemTooltip
@onready var tooltip_label: Label = $ItemTooltip/MarginContainer/TooltipLabel

var _player: Node2D = null
var _is_visible: bool = false
var _is_mobile: bool = false

func _ready() -> void:
	panel.visible = false
	item_tooltip.visible = false

func setup(player: Node2D) -> void:
	_player = player
	player.inventory.inventory_changed.connect(_refresh)
	player.inventory.equipment_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
	elif _is_visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1")):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_is_visible = !_is_visible
	panel.visible = _is_visible
	if _is_visible:
		_detect_mobile()
		_refresh()

func _detect_mobile() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)
	if _is_mobile:
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 36)
		$Panel/MarginContainer/VBox/TopBar/CloseHint.add_theme_font_size_override("font_size", 26)
		$Panel/MarginContainer/VBox/HBox/EquipmentPanel/Title.add_theme_font_size_override("font_size", 32)
		$Panel/MarginContainer/VBox/HBox/BagPanel/Title.add_theme_font_size_override("font_size", 32)
		$Panel/MarginContainer/VBox/HBox/StatsPanel/Title.add_theme_font_size_override("font_size", 32)
		stats_label.add_theme_font_size_override("font_size", 26)
		tooltip_label.add_theme_font_size_override("font_size", 26)

func _refresh() -> void:
	if not _player:
		return
	_refresh_equipment()
	_refresh_bag()
	_refresh_stats()

func _refresh_equipment() -> void:
	# Clear existing
	for child in equipment_grid.get_children():
		child.queue_free()

	var inv = _player.inventory
	var slot_names = ["weapon", "armor", "helm", "boots", "ring", "amulet"]
	for slot_name in slot_names:
		var item = inv.equipment.get(slot_name, {})
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 80) if _is_mobile else Vector2(100, 40)
		if _is_mobile:
			btn.add_theme_font_size_override("font_size", 22)
		if item.is_empty():
			btn.text = "[%s]" % slot_name.capitalize()
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.text = item.get("name", "?")
			var rarity = item.get("rarity", 0)
			btn.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
			btn.pressed.connect(func(): inv.unequip(slot_name))
			btn.mouse_entered.connect(_show_tooltip.bind(item))
			btn.mouse_exited.connect(_hide_tooltip)
		equipment_grid.add_child(btn)

func _refresh_bag() -> void:
	for child in bag_grid.get_children():
		child.queue_free()

	var inv = _player.inventory
	for i in range(inv.bag.size()):
		var item = inv.bag[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 72) if _is_mobile else Vector2(90, 36)
		if _is_mobile:
			btn.add_theme_font_size_override("font_size", 22)
		btn.text = item.get("name", "?")
		var rarity = item.get("rarity", 0)
		btn.add_theme_color_override("font_color", ItemData.RARITY_COLORS.get(rarity, Color.WHITE))
		var idx = i
		btn.pressed.connect(func(): _player.inventory.equip_from_bag(idx); _refresh())
		btn.mouse_entered.connect(_show_tooltip.bind(item))
		btn.mouse_exited.connect(_hide_tooltip)
		bag_grid.add_child(btn)

	# Fill remaining slots with empty
	for i in range(inv.bag.size(), InventoryComponent.MAX_BAG_SLOTS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 72) if _is_mobile else Vector2(90, 36)
		if _is_mobile:
			btn.add_theme_font_size_override("font_size", 22)
		btn.text = "---"
		btn.modulate = Color(0.4, 0.4, 0.4)
		bag_grid.add_child(btn)

func _refresh_stats() -> void:
	if not _player:
		return
	var s = _player.stats
	var text = """Level: %d
HP: %d / %d
Mana: %d / %d
STR: %d (+%d)
AGI: %d (+%d)
INT: %d (+%d)
Armor: %d
Attack: %d
Speed: %.0f""" % [
		s.level,
		s.current_hp, s.get_total_max_hp(),
		s.current_mana, s.get_total_max_mana(),
		s.strength, s.bonus_strength,
		s.agility, s.bonus_agility,
		s.intelligence, s.bonus_intelligence,
		s.get_total_armor(),
		s.attack_damage + s.weapon_damage,
		s.get_total_move_speed(),
	]
	# Show active buffs/debuffs
	var buffs = s.get_active_buffs()
	if buffs.size() > 0:
		text += "\n\n-- Effects --"
		for b in buffs:
			var mins = int(b["time_left"]) / 60
			var secs = int(b["time_left"]) % 60
			var sign = "+" if float(b["amount"]) > 0 else ""
			text += "\n%s%s %s (%d:%02d)" % [sign, str(b["amount"]), b["stat"].capitalize(), mins, secs]
	stats_label.text = text

func _show_tooltip(item: Dictionary) -> void:
	if item.is_empty():
		return
	var text = "%s\n%s\n" % [item.get("name", ""), ItemData.RARITY_NAMES.get(item.get("rarity", 0), "")]
	text += item.get("description", "") + "\n"
	var stats = item.get("stats", {})
	for stat_name in stats:
		text += "+%s %s\n" % [str(stats[stat_name]), stat_name.replace("_", " ").capitalize()]
	if item.has("buy_price"):
		text += "Value: %dg" % item["buy_price"]
	tooltip_label.text = text.strip_edges()
	item_tooltip.visible = true

func _hide_tooltip() -> void:
	item_tooltip.visible = false
