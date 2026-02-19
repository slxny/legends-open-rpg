extends Node

## SC:BW Death Counter emulation.
## All game state stored as named integer counters.
## Used for: level, xp, alignment, artifact flags, town ownership,
## respawn timers, boss killed flags, etc.
## Never store hero state inside the hero scene — store here.

var counters: Dictionary = {}

func set_value(key: String, value: int) -> void:
	counters[key] = value

func get_value(key: String) -> int:
	return counters.get(key, 0)

func add_value(key: String, amount: int) -> void:
	counters[key] = get_value(key) + amount

func subtract_value(key: String, amount: int) -> void:
	counters[key] = get_value(key) - amount

func has_flag(key: String) -> bool:
	return get_value(key) != 0

func set_flag(key: String) -> void:
	set_value(key, 1)

func clear_flag(key: String) -> void:
	set_value(key, 0)

func reset_all() -> void:
	counters.clear()

func get_all() -> Dictionary:
	return counters.duplicate()

func load_from(data: Dictionary) -> void:
	counters = data.duplicate()
