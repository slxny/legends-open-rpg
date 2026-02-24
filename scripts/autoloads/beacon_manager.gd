extends Node

## Centralized beacon dispatch system.
## All beacon activations are routed through here.
## Beacon types: shop, heal, teleport, boss_spawn, town_purchase, alignment_choice.
## Immediate response. No dialogue trees.

signal beacon_activated(beacon_type: String, data: Dictionary, player: Node2D)

var _last_heal_sfx_ms: int = 0
var _teleport_cooldown_ms: int = 0  # Prevents beacon re-trigger after teleport

func activate(beacon_type: String, data: Dictionary, player: Node2D = null) -> void:
	# Block beacon activation during teleport cooldown (prevents enter→exit loops)
	if beacon_type in ["dungeon_enter", "dungeon_exit", "teleport"]:
		var now = Time.get_ticks_msec()
		if now - _teleport_cooldown_ms < 1000:
			return
	if player == null:
		var players = _get_players()
		if players.size() > 0:
			player = players[0]

	match beacon_type:
		"shop":
			_handle_shop(data, player)
		"heal":
			_handle_heal(data, player)
		"teleport":
			_handle_teleport(data, player)
		"boss_spawn":
			_handle_boss_spawn(data, player)
		"town_purchase":
			_handle_town_purchase(data, player)
		"alignment_choice":
			_handle_alignment_choice(data, player)
		"dungeon_enter":
			_handle_dungeon_enter(data, player)
		"dungeon_exit":
			_handle_dungeon_exit(data, player)
		_:
			pass

	beacon_activated.emit(beacon_type, data, player)

func _handle_shop(data: Dictionary, player: Node2D) -> void:
	# Open shop UI — dispatch to existing shop_dialog group
	var shop_dialogs = player.get_tree().get_nodes_in_group("shop_dialog")
	if shop_dialogs.size() > 0 and shop_dialogs[0].has_method("open_shop"):
		shop_dialogs[0].open_shop()

func _handle_heal(data: Dictionary, player: Node2D) -> void:
	if player and player.has_node("StatsComponent"):
		var stats = player.get_node("StatsComponent")
		# Skip if already at full HP and mana
		if stats.current_hp >= stats.get_total_max_hp() and stats.current_mana >= stats.get_total_max_mana():
			return
		stats.current_hp = stats.get_total_max_hp()
		stats.current_mana = stats.get_total_max_mana()
		stats._emit_all()
		# Play heal chime only if not recently played (prevents repeat while standing on beacon)
		var now = Time.get_ticks_msec()
		if now - _last_heal_sfx_ms > 2000:
			AudioManager.play_sfx("beacon_heal")
			_last_heal_sfx_ms = now
		GameManager.game_message.emit("Fully Restored!", Color(0.3, 1.0, 0.5))

func _handle_teleport(data: Dictionary, player: Node2D) -> void:
	var dest = data.get("destination", Vector2.ZERO)
	if dest != Vector2.ZERO and player:
		player.global_position = dest
		_teleport_cooldown_ms = Time.get_ticks_msec()
		GameManager.game_message.emit("Teleported!", Color(0.5, 0.7, 1.0))

func _handle_boss_spawn(data: Dictionary, _player: Node2D) -> void:
	var boss_id = data.get("boss_id", "")
	if boss_id.is_empty():
		return
	# Check if boss already killed
	if DeathCounterSystem.has_flag("boss_killed_%s" % boss_id):
		GameManager.game_message.emit("This foe has already been vanquished.", Color(0.6, 0.6, 0.6))
		return
	# Boss spawning handled by trigger system — set flag to indicate spawn requested
	DeathCounterSystem.set_flag("boss_spawn_requested_%s" % boss_id)

func _handle_town_purchase(data: Dictionary, _player: Node2D) -> void:
	var settlement_id = data.get("settlement_id", "")
	if settlement_id.is_empty():
		return
	var player_id = data.get("player_id", 0)
	if SettlementManager.is_owned(settlement_id, player_id):
		GameManager.game_message.emit("You already own this settlement.", Color(0.8, 0.8, 0.4))
		return
	if SettlementManager.purchase(settlement_id, player_id):
		var config = SettlementManager.get_settlement_config(settlement_id)
		GameManager.game_message.emit("%s Purchased!" % config.get("name", "Settlement"), Color(1.0, 0.9, 0.2))
	else:
		GameManager.game_message.emit("Not enough gold!", Color(1.0, 0.3, 0.3))

func _handle_alignment_choice(data: Dictionary, _player: Node2D) -> void:
	var amount = data.get("alignment_change", 0)
	var player_id = data.get("player_id", 0)
	if amount != 0:
		AlignmentManager.modify_alignment(amount, player_id)
		var direction = "Good" if amount > 0 else "Dark"
		GameManager.game_message.emit("Alignment shifted toward %s!" % direction, Color(0.8, 0.6, 1.0))

func _handle_dungeon_exit(data: Dictionary, player: Node2D) -> void:
	var dest = data.get("destination", Vector2.ZERO)
	if dest != Vector2.ZERO and player:
		player.global_position = dest
		_teleport_cooldown_ms = Time.get_ticks_msec()
		AudioManager.play_sfx("dungeon_exit")
		GameManager.game_message.emit("Returned to Haven's Rest", Color(0.3, 1.0, 0.5))
		# Restore minimap to Haven's Rest
		var minimaps = player.get_tree().get_nodes_in_group("minimap")
		if minimaps.size() > 0 and minimaps[0].has_method("reset_to_default"):
			minimaps[0].reset_to_default()

func _handle_dungeon_enter(data: Dictionary, player: Node2D) -> void:
	var min_level = data.get("min_level", 1)
	if player and player.has_node("StatsComponent"):
		var stats = player.get_node("StatsComponent")
		if stats.level < min_level:
			GameManager.game_message.emit("You must be Level %d to enter!" % min_level, Color(1.0, 0.3, 0.3))
			return
	var dest = data.get("destination", Vector2.ZERO)
	if dest != Vector2.ZERO and player:
		player.global_position = dest
		_teleport_cooldown_ms = Time.get_ticks_msec()
		AudioManager.play_sfx("dungeon_enter")
		GameManager.game_message.emit("Descending into the Crypt...", Color(0.6, 0.4, 0.8))
		# Switch minimap to dungeon view
		var dungeons = player.get_tree().get_nodes_in_group("dungeon_crypt")
		if dungeons.is_empty():
			# Fallback: find by node name
			var world_nodes = player.get_tree().get_nodes_in_group("world")
			if world_nodes.size() > 0:
				var dungeon = world_nodes[0].get_node_or_null("DungeonCrypt")
				if dungeon and dungeon.has_method("setup_dungeon_minimap"):
					dungeon.setup_dungeon_minimap()
		else:
			dungeons[0].setup_dungeon_minimap()

func _get_players() -> Array:
	return Engine.get_main_loop().root.get_tree().get_nodes_in_group("player") if Engine.get_main_loop() else []
