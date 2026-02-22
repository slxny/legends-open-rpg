extends Node

## Centralized beacon dispatch system.
## All beacon activations are routed through here.
## Beacon types: shop, heal, teleport, boss_spawn, town_purchase, alignment_choice.
## Immediate response. No dialogue trees.

signal beacon_activated(beacon_type: String, data: Dictionary, player: Node2D)

var _last_heal_sfx_ms: int = 0

func activate(beacon_type: String, data: Dictionary, player: Node2D = null) -> void:
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

func _get_players() -> Array:
	return Engine.get_main_loop().root.get_tree().get_nodes_in_group("player") if Engine.get_main_loop() else []
