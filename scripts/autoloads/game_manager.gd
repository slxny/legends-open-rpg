extends Node

signal gold_changed(new_amount: int)
signal hero_selected(hero_class: String)
signal game_started
signal item_picked_up(item_name: String)
signal game_message(text: String, color: Color)

enum HeroClass { BLADE_KNIGHT, SHADOW_RANGER }

var current_hero_class: String = ""
var gold: int = 0:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)

var total_kills: int = 0
var killed_bosses: Array[String] = []
var found_artifacts: Array[String] = []

# Armory upgrade levels (0 = no upgrades, 100 = max)
var weapon_upgrade_level: int = 0
var armor_upgrade_level: int = 0

func get_upgrade_cost(current_level: int) -> int:
	return int(10 * pow(current_level + 1, 1.5))

func select_hero(hero_class: String) -> void:
	current_hero_class = hero_class
	hero_selected.emit(hero_class)

func add_gold(amount: int) -> void:
	gold += amount
	# Mirror to EconomyManager for multiplayer-readiness
	EconomyManager.add_gold(amount, 0)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		EconomyManager.set_gold(gold, 0)
		return true
	return false

func start_game() -> void:
	gold = 50  # Starting gold
	EconomyManager.set_gold(50, 0)
	# Initialize death counters for game start
	DeathCounterSystem.reset_all()
	DeathCounterSystem.set_value("gold_p0", 50)
	DeathCounterSystem.set_value("game_started", 1)
	game_started.emit()

func record_kill(enemy_name: String) -> void:
	total_kills += 1
	DeathCounterSystem.add_value("total_kills", 1)
	DeathCounterSystem.add_value("kills_%s" % enemy_name, 1)

func record_boss_kill(boss_id: String) -> void:
	if boss_id not in killed_bosses:
		killed_bosses.append(boss_id)
	DeathCounterSystem.set_flag("boss_killed_%s" % boss_id)

func record_artifact(artifact_id: String) -> void:
	if artifact_id not in found_artifacts:
		found_artifacts.append(artifact_id)
	DeathCounterSystem.set_flag("artifact_%s" % artifact_id)
