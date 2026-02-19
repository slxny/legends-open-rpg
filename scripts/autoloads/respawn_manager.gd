extends Node

## Centralized respawn manager for player death handling.
## Respawn at safe location with full HP after death timer.

signal player_respawned(player_id: int)

const RESPAWN_DELAY := 3.0  # Seconds before respawn

var _respawn_timers: Dictionary = {}  # player_id -> timer

func request_respawn(player_id: int = 0) -> void:
	if _respawn_timers.has(player_id):
		return  # Already respawning
	DeathCounterSystem.set_value("respawn_timer_p%d" % player_id, int(RESPAWN_DELAY))
	_respawn_timers[player_id] = RESPAWN_DELAY

func _process(delta: float) -> void:
	var to_remove: Array = []
	for pid in _respawn_timers:
		_respawn_timers[pid] -= delta
		if _respawn_timers[pid] <= 0:
			_execute_respawn(pid)
			to_remove.append(pid)
	for pid in to_remove:
		_respawn_timers.erase(pid)

func _execute_respawn(player_id: int) -> void:
	DeathCounterSystem.set_value("respawn_timer_p%d" % player_id, 0)
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player):
			# Find world spawn point
			var worlds = get_tree().get_nodes_in_group("world")
			if worlds.size() > 0 and worlds[0].has_method("get_spawn_position"):
				player.global_position = worlds[0].get_spawn_position()
			# Restore HP/Mana
			if player.has_node("StatsComponent"):
				var stats = player.get_node("StatsComponent")
				stats.current_hp = stats.get_total_max_hp()
				stats.current_mana = stats.get_total_max_mana()
				stats._emit_all()
			player_respawned.emit(player_id)
			GameManager.game_message.emit("Respawned!", Color(0.5, 1.0, 0.5))
			break
