extends Node

## Centralized economy manager. Minerals = Gold.
## All gold changes go through here for multiplayer-readiness.

signal gold_changed(player_id: int, new_amount: int)

## Per-player gold storage. Player 0 is single-player default.
var _gold: Dictionary = {}  # player_id -> int

func _ready() -> void:
	# Initialize default player
	_gold[0] = 0

func get_gold(player_id: int = 0) -> int:
	return _gold.get(player_id, 0)

func set_gold(amount: int, player_id: int = 0) -> void:
	_gold[player_id] = max(0, amount)
	gold_changed.emit(player_id, _gold[player_id])
	DeathCounterSystem.set_value("gold_p%d" % player_id, _gold[player_id])

func add_gold(amount: int, player_id: int = 0) -> void:
	set_gold(get_gold(player_id) + amount, player_id)

func spend_gold(amount: int, player_id: int = 0) -> bool:
	if get_gold(player_id) >= amount:
		set_gold(get_gold(player_id) - amount, player_id)
		return true
	return false

func reset(player_id: int = 0) -> void:
	set_gold(0, player_id)
