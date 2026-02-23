extends Node

## Centralized respawn manager for player death handling.
## Instant death → 3-2-1 countdown with sounds → regeneration with animation.

signal player_died(player_id: int)
signal player_respawned(player_id: int)
signal countdown_tick(player_id: int, seconds_left: int)

const COUNTDOWN_SECONDS := 3  # 3-2-1 countdown

var _respawning: Dictionary = {}  # player_id -> true (guard against double-requests)

func request_respawn(player_id: int = 0) -> void:
	if _respawning.has(player_id):
		return  # Already respawning
	_respawning[player_id] = true
	DeathCounterSystem.set_value("respawn_timer_p%d" % player_id, COUNTDOWN_SECONDS)

	# Phase 1: Instant death — play death sound, trigger death animation on player
	player_died.emit(player_id)
	AudioManager.play_sfx("player_death")

	# Brief pause to let the death sound/animation land before countdown starts
	await get_tree().create_timer(0.6).timeout

	# Phase 2: Countdown 3-2-1 with tick sounds
	for i in range(COUNTDOWN_SECONDS, 0, -1):
		DeathCounterSystem.set_value("respawn_timer_p%d" % player_id, i)
		countdown_tick.emit(player_id, i)
		AudioManager.play_sfx("respawn_countdown")
		await get_tree().create_timer(1.0).timeout

	# Phase 3: Execute respawn with regeneration animation
	_execute_respawn(player_id)

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
			# Play regeneration sound and emit respawned signal
			AudioManager.play_sfx("respawn_complete")
			player_respawned.emit(player_id)
			break
	_respawning.erase(player_id)
