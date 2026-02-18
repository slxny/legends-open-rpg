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

func select_hero(hero_class: String) -> void:
	current_hero_class = hero_class
	hero_selected.emit(hero_class)

func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func start_game() -> void:
	gold = 50  # Starting gold
	game_started.emit()
