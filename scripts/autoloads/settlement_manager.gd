extends Node

## Settlement ownership system.
## Tracks which player owns which town via DeathCounterSystem flags.
## Purchasing a settlement: spend gold, set DC flag, spawn guards.

signal settlement_purchased(settlement_id: String, player_id: int)
signal settlement_lost(settlement_id: String)

## Settlement definitions: cost, guard count, guard level
const SETTLEMENTS: Dictionary = {
	"havens_rest": {"cost": 500, "guard_count": 4, "guard_level": 5, "name": "Haven's Rest"},
	"darkwood_outpost": {"cost": 800, "guard_count": 6, "guard_level": 8, "name": "Darkwood Outpost"},
	"iron_hold": {"cost": 1200, "guard_count": 8, "guard_level": 12, "name": "Iron Hold"},
}

func is_owned(settlement_id: String, player_id: int = 0) -> bool:
	return DeathCounterSystem.get_value("town_owned_%s_p%d" % [settlement_id, player_id]) == 1

func get_settlement_owner(settlement_id: String) -> int:
	## Returns the player_id that owns this settlement, or -1 if unowned.
	for pid in range(8):  # Support up to 8 players
		if DeathCounterSystem.get_value("town_owned_%s_p%d" % [settlement_id, pid]) == 1:
			return pid
	return -1

func purchase(settlement_id: String, player_id: int = 0) -> bool:
	var config = SETTLEMENTS.get(settlement_id, {})
	if config.is_empty():
		return false
	var cost = config["cost"]
	if not EconomyManager.spend_gold(cost, player_id):
		return false
	# Set ownership flag
	DeathCounterSystem.set_value("town_owned_%s_p%d" % [settlement_id, player_id], 1)
	settlement_purchased.emit(settlement_id, player_id)
	return true

func release(settlement_id: String) -> void:
	for pid in range(8):
		DeathCounterSystem.set_value("town_owned_%s_p%d" % [settlement_id, pid], 0)
	settlement_lost.emit(settlement_id)

func get_settlement_config(settlement_id: String) -> Dictionary:
	return SETTLEMENTS.get(settlement_id, {})
