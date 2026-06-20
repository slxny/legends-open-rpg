extends CanvasLayer

## Custom HUD for the revamp slice. Built entirely from CanvasItem draws +
## a couple of Labels — no default Godot ProgressBar / PanelContainer chrome.
##
## Top-left:    HP orb + class resource (Arcane Charges) + potions
## Bottom-center: 6 ability slots (LMB / RMB / 1 / 2 / 3 / 4) + Dodge + Potion
## Top-center: Objective text
## Top-center (boss): Boss bar + name + phase pip
## Bottom-right (transient): Pickup callout with rarity color

const HUDStyle := preload("res://revamp/ui/hud_style.gd")
const AbilitySlot := preload("res://revamp/ui/ability_slot.gd")

var _player: Node
var _hp_orb: Control
var _charges: Control
var _potions: Control
var _slots: Array = []
var _objective_label: Label
var _objective_panel: Control
var _boss_bar: Control
var _pickup_callout: Control


func _ready() -> void:
	layer = 10
	_build_top_left()
	_build_action_bar()
	_build_objective()
	_build_boss_bar()
	_build_pickup_callout()


func bind_player(p: Node) -> void:
	_player = p
	if p == null:
		return
	p.hp_changed.connect(_on_hp_changed)
	p.charges_changed.connect(_on_charges_changed)
	p.potion_changed.connect(_on_potion_changed)
	p.cooldowns_changed.connect(_on_cooldowns_changed)
	p.equipment_changed.connect(_on_equipment_changed)


# === TOP LEFT ORB + CHARGES + POTIONS ===

func _build_top_left() -> void:
	_hp_orb = preload("res://revamp/ui/hud_hp_orb.gd").new()
	_hp_orb.position = Vector2(28, 28)
	_hp_orb.size = Vector2(160, 160)
	add_child(_hp_orb)
	_charges = preload("res://revamp/ui/hud_charges.gd").new()
	_charges.position = Vector2(28, 200)
	_charges.size = Vector2(220, 36)
	add_child(_charges)
	_potions = preload("res://revamp/ui/hud_potions.gd").new()
	_potions.position = Vector2(28, 244)
	_potions.size = Vector2(180, 32)
	add_child(_potions)


# === BOTTOM ACTION BAR ===

func _build_action_bar() -> void:
	var bar_root := Control.new()
	bar_root.name = "ActionBar"
	bar_root.size = Vector2(660, 96)
	bar_root.anchor_left = 0.5
	bar_root.anchor_right = 0.5
	bar_root.anchor_top = 1.0
	bar_root.anchor_bottom = 1.0
	bar_root.position = Vector2(-330, -118)
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_root)
	# Background frame
	var bg := preload("res://revamp/ui/hud_bar_frame.gd").new()
	bg.size = bar_root.size
	bar_root.add_child(bg)
	# Slots: bolt (LMB), burst (RMB), step (1), ward (2), sigil (3), tempest (4), dodge (SPACE), potion (Q)
	var defs := [
		{"key": &"bolt", "label": "Bolt", "hint": "LMB", "color": Color(0.55, 0.90, 1.0)},
		{"key": &"burst", "label": "Burst", "hint": "RMB", "color": Color(0.75, 0.55, 1.0)},
		{"key": &"step", "label": "Step", "hint": "1", "color": Color(0.55, 0.95, 0.95)},
		{"key": &"ward", "label": "Ward", "hint": "2", "color": Color(0.45, 0.85, 1.0)},
		{"key": &"sigil", "label": "Sigil", "hint": "3", "color": Color(0.95, 0.55, 0.95)},
		{"key": &"tempest", "label": "Tempest", "hint": "4", "color": Color(1.0, 0.85, 0.30)},
		{"key": &"dodge", "label": "Dodge", "hint": "SP", "color": Color(0.95, 0.95, 0.95)},
		{"key": &"potion", "label": "Heal", "hint": "Q", "color": Color(0.95, 0.30, 0.35)},
	]
	var x: float = 18.0
	for d in defs:
		var slot := AbilitySlot.new()
		slot.position = Vector2(x, 12)
		slot.size = Vector2(72, 72)
		slot.set_meta("key", d["key"])
		slot.icon_color = d["color"]
		slot.key_hint = d["hint"]
		slot.label_text = d["label"]
		bar_root.add_child(slot)
		_slots.append(slot)
		x += 80.0


# === OBJECTIVE ===

func _build_objective() -> void:
	_objective_panel = preload("res://revamp/ui/hud_objective_panel.gd").new()
	_objective_panel.size = Vector2(720, 56)
	_objective_panel.anchor_left = 0.5
	_objective_panel.anchor_right = 0.5
	_objective_panel.position = Vector2(-360, 36)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)
	_objective_label = Label.new()
	_objective_label.text = ""
	_objective_label.size = Vector2(720, 56)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_objective_label.add_theme_constant_override("outline_size", 6)
	_objective_panel.add_child(_objective_label)


func set_objective(text: String) -> void:
	if _objective_label == null:
		return
	_objective_label.text = text
	# Flash effect
	_objective_panel.modulate = Color(1.4, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_objective_panel, "modulate", Color(1, 1, 1), 0.5)


# === BOSS BAR ===

func _build_boss_bar() -> void:
	_boss_bar = preload("res://revamp/ui/hud_boss_bar.gd").new()
	_boss_bar.size = Vector2(820, 80)
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.position = Vector2(-410, 102)
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_bar)


func show_boss_bar(name_text: String) -> void:
	if _boss_bar:
		_boss_bar.visible = true
		_boss_bar.set_boss_name(name_text)


func hide_boss_bar() -> void:
	if _boss_bar:
		_boss_bar.visible = false


func update_boss_health(current: float, maximum: float) -> void:
	if _boss_bar:
		_boss_bar.set_health(current, maximum)


func flash_boss_phase(phase: int) -> void:
	if _boss_bar:
		_boss_bar.flash_phase(phase)


# === PICKUP CALLOUT ===

func _build_pickup_callout() -> void:
	_pickup_callout = preload("res://revamp/ui/hud_pickup_callout.gd").new()
	_pickup_callout.size = Vector2(380, 220)
	_pickup_callout.anchor_left = 1.0
	_pickup_callout.anchor_right = 1.0
	_pickup_callout.anchor_top = 0.0
	_pickup_callout.position = Vector2(-410, 60)
	_pickup_callout.visible = false
	_pickup_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pickup_callout)


func show_pickup(item: Resource) -> void:
	if _pickup_callout and _pickup_callout.has_method("show_for"):
		_pickup_callout.show_for(item)


# === Player signal handlers ===

func _on_hp_changed(current: float, maximum: float) -> void:
	if _hp_orb:
		_hp_orb.set_hp(current, maximum)


func _on_charges_changed(current: int, maximum: int) -> void:
	if _charges:
		_charges.set_charges(current, maximum)


func _on_potion_changed(current: int, maximum: int) -> void:
	if _potions:
		_potions.set_count(current, maximum)


func _on_cooldowns_changed(snapshot: Dictionary) -> void:
	for slot in _slots:
		var key: StringName = StringName(slot.get_meta("key"))
		if snapshot.has(key):
			slot.apply_state(snapshot[key])


func _on_equipment_changed(item_id: String) -> void:
	# Used to refresh ability tooltips when build mods change.
	for slot in _slots:
		if slot.has_method("set_modified"):
			slot.set_modified(item_id != "")
