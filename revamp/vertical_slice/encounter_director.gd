extends Node

## Encounter director — drives the slice's authored progression:
## intro swarm → melee pack → mixed ranged → heavy+support → elite → boss → reward.
##
## Encounters trigger when the player crosses x-anchors. Each spawn is in
## a clear formation (not random scatter) so combat reads.

signal objective_changed(text: String)
signal boss_health_changed(current: float, maximum: float)
signal boss_spawned(name_text: String)
signal boss_defeated()
signal loot_dropped(item: Resource, drop_pos: Vector2)
signal encounter_cleared(name: StringName)

const Wraithling := preload("res://revamp/enemies/enemy_wraithling.gd")
const Cultist := preload("res://revamp/enemies/enemy_cultist.gd")
const Hexbinder := preload("res://revamp/enemies/enemy_hexbinder.gd")
const Tombwarden := preload("res://revamp/enemies/enemy_tombwarden.gd")
const WyrmAcolyte := preload("res://revamp/enemies/enemy_wyrm_acolyte.gd")
const PlaguebearerElite := preload("res://revamp/enemies/enemy_plaguebearer_elite.gd")
const EmberLord := preload("res://revamp/enemies/boss_ember_lord.gd")
const RevampItems := preload("res://revamp/items/revamp_items.gd")
const RevampItemResource := preload("res://revamp/items/revamp_item.gd")

var world: Node
var player: Node
var hud: Node

var _stage_index: int = 0
var _stages: Array = []
var _active_encounter_name: StringName = &""
var _active_alive: Array = []
var _boss_ref: Node


func bind(w: Node, p: Node, h: Node) -> void:
	world = w
	player = p
	hud = h
	_stages = [
		{"name": &"intro_swarm", "anchor": w.anchor("intro_swarm"), "x_trigger": -1700.0, "spawn": _spawn_intro_swarm, "objective": "Push east. Storm Bolt clears swarms — your charges build with each hit."},
		{"name": &"melee_pack", "anchor": w.anchor("melee_pack"), "x_trigger": -900.0, "spawn": _spawn_melee_pack, "objective": "Cultists ahead. Right-click spends charges in a lightning Storm Burst."},
		{"name": &"mixed_ranged", "anchor": w.anchor("mixed_ranged"), "x_trigger": -200.0, "spawn": _spawn_mixed_ranged, "objective": "Hexbinders behind the line. Aether Step (1) — close, blink, dispatch."},
		{"name": &"heavy_support", "anchor": w.anchor("heavy_support"), "x_trigger": 1100.0, "spawn": _spawn_heavy_support, "objective": "Tombwarden + Acolyte. Crystal Ward (2) eats the slam. Kill the healer first."},
		{"name": &"elite", "anchor": w.anchor("elite"), "x_trigger": 1900.0, "spawn": _spawn_elite, "objective": "ELITE: Plaguebearer. Avoid pools. Gravity Sigil (3) clumps adds for cleave."},
		{"name": &"boss", "anchor": w.anchor("boss"), "x_trigger": 2500.0, "spawn": _spawn_boss, "objective": "BOSS: Lord of Embers. Tempest (4) is your phase finisher."},
	]
	set_process(true)
	_objective(_stages[0]["objective"])


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Stage triggers
	if _stage_index < _stages.size():
		var stage: Dictionary = _stages[_stage_index]
		if player.global_position.x >= float(stage["x_trigger"]):
			_objective(stage["objective"])
			_start_stage(stage)
			_stage_index += 1
	# Encounter clear detection
	if _active_encounter_name != &"" and _all_dead():
		var cleared := _active_encounter_name
		_active_encounter_name = &""
		_active_alive.clear()
		encounter_cleared.emit(cleared)
		if cleared == &"elite":
			# Drop a hint item
			var minor: RefCounted = RevampItems.make_item("minor_voltrune")
			loot_dropped.emit(minor, world.anchor("elite") + Vector2(0, 40))
	# Boss HP updates
	if is_instance_valid(_boss_ref):
		boss_health_changed.emit(float(_boss_ref.get("current_hp")), float(_boss_ref.get("max_hp")))


func _start_stage(stage: Dictionary) -> void:
	_active_encounter_name = stage["name"]
	stage["spawn"].call()


func _spawn_intro_swarm() -> void:
	var anchor: Vector2 = world.anchor("intro_swarm")
	for i in range(5):
		var ang: float = float(i) / 5.0 * TAU
		_add_enemy(Wraithling.new(), anchor + Vector2(cos(ang), sin(ang)) * 120.0)


func _spawn_melee_pack() -> void:
	var anchor: Vector2 = world.anchor("melee_pack")
	# Line of 3 cultists with 2 wraithlings flanking
	for i in range(3):
		_add_enemy(Cultist.new(), anchor + Vector2(60 + i * 40, (i - 1) * 30))
	for i in range(2):
		_add_enemy(Wraithling.new(), anchor + Vector2(140, -90 + i * 180))


func _spawn_mixed_ranged() -> void:
	var anchor: Vector2 = world.anchor("mixed_ranged")
	# 2 hexbinders behind 2 cultists
	for i in range(2):
		_add_enemy(Cultist.new(), anchor + Vector2(60, -50 + i * 100))
	for i in range(2):
		_add_enemy(Hexbinder.new(), anchor + Vector2(220, -40 + i * 80))


func _spawn_heavy_support() -> void:
	var anchor: Vector2 = world.anchor("heavy_support")
	_add_enemy(Tombwarden.new(), anchor + Vector2(110, 0))
	_add_enemy(WyrmAcolyte.new(), anchor + Vector2(220, -70))
	for i in range(3):
		_add_enemy(Wraithling.new(), anchor + Vector2(40 + i * 35, 100 - i * 30))


func _spawn_elite() -> void:
	var anchor: Vector2 = world.anchor("elite")
	var elite: Node = PlaguebearerElite.new()
	_add_enemy(elite, anchor + Vector2(60, 0))
	if elite.has_signal("elite_died"):
		elite.elite_died.connect(_on_elite_died)
	# Two cultists as backup
	_add_enemy(Cultist.new(), anchor + Vector2(-40, -50))
	_add_enemy(Cultist.new(), anchor + Vector2(-40, 50))


func _spawn_boss() -> void:
	var anchor: Vector2 = world.anchor("boss")
	var boss: Node = EmberLord.new()
	boss.set_arena_center(anchor)
	_add_enemy(boss, anchor + Vector2(0, -80))
	_boss_ref = boss
	boss_spawned.emit("LORD OF EMBERS")
	# Activate boss arena rune circle
	var circle: Node = world.get_node_or_null("BossRuneCircle")
	if circle and circle.has_method("set_active"):
		circle.set_active(true)
	# Lighting shift
	var lighting: Node = world.get_parent().get_node_or_null("Lighting")
	if lighting and lighting.has_method("set_mode"):
		lighting.set_mode(&"boss")
	# Camera punch
	var cam: Node = world.get_parent().get_node_or_null("CameraSystem")
	if cam and cam.has_method("enter_boss_mode"):
		cam.enter_boss_mode()
	if cam and cam.has_method("shake"):
		cam.shake(28.0)
	if boss.has_signal("boss_died_at"):
		boss.boss_died_at.connect(_on_boss_died)
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase)


func _on_boss_phase(phase: int) -> void:
	if hud and hud.has_method("flash_boss_phase"):
		hud.flash_boss_phase(phase)


func _on_boss_died(at: Vector2) -> void:
	boss_defeated.emit()
	objective_changed.emit("VICTORY. Collect the relic.")
	# Lighting → loot mode
	var lighting: Node = world.get_parent().get_node_or_null("Lighting")
	if lighting and lighting.has_method("set_mode"):
		lighting.set_mode(&"loot")
	# Drop the build-changing legendary
	var item: RefCounted = RevampItems.make_item("ember_circlet")
	loot_dropped.emit(item, at + Vector2(0, 30))


func _on_elite_died(at: Vector2) -> void:
	# Hint loot drop from elite
	var item: RefCounted = RevampItems.make_item("minor_voltrune")
	loot_dropped.emit(item, at + Vector2(0, 20))


func _add_enemy(enemy: Node, at: Vector2) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy is Node2D:
		(enemy as Node2D).global_position = at
	world.add_child(enemy)
	_active_alive.append(enemy)


func _all_dead() -> bool:
	for e in _active_alive:
		if is_instance_valid(e):
			return false
	return true


func _objective(text: String) -> void:
	objective_changed.emit(text)
