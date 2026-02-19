extends Node

## Alignment system: -100 (evil) to +100 (good).
## Modified by: killing good NPCs, helping towns, choosing shrines.
## Factions read alignment value to determine hostility.

signal alignment_changed(player_id: int, new_value: int)

const ALIGNMENT_MIN := -100
const ALIGNMENT_MAX := 100

func get_alignment(player_id: int = 0) -> int:
	return clampi(DeathCounterSystem.get_value("alignment_p%d" % player_id), ALIGNMENT_MIN, ALIGNMENT_MAX)

func set_alignment(value: int, player_id: int = 0) -> void:
	var clamped = clampi(value, ALIGNMENT_MIN, ALIGNMENT_MAX)
	DeathCounterSystem.set_value("alignment_p%d" % player_id, clamped)
	alignment_changed.emit(player_id, clamped)

func modify_alignment(amount: int, player_id: int = 0) -> void:
	set_alignment(get_alignment(player_id) + amount, player_id)

func get_faction_name(player_id: int = 0) -> String:
	var val = get_alignment(player_id)
	if val >= 50:
		return "Holy"
	elif val >= 20:
		return "Good"
	elif val > -20:
		return "Neutral"
	elif val > -50:
		return "Dark"
	else:
		return "Evil"

func is_hostile_to_good(player_id: int = 0) -> bool:
	return get_alignment(player_id) < -30

func is_hostile_to_evil(player_id: int = 0) -> bool:
	return get_alignment(player_id) > 30
