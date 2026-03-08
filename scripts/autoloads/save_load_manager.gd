extends Node

## Save/Load system — JSON serialization of all game state.
## Saves: level, xp, skill_points, gold, wood, alignment, owned_towns,
## artifacts, explored_tiles, inventory, boss_flags, death_counters,
## armory upgrades, woodwork upgrades.

const SAVE_PATH := "user://savegame.json"

signal game_saved
signal game_loaded

func save_game() -> void:
	var player = _get_player()
	if not player:
		return

	var data: Dictionary = {}

	# Player stats
	data["hero_class"] = player.hero_class
	data["level"] = player.stats.level
	data["xp"] = player.stats.xp
	data["skill_points"] = player.stats.skill_points
	data["current_hp"] = player.stats.current_hp
	data["current_mana"] = player.stats.current_mana
	data["position_x"] = player.global_position.x
	data["position_y"] = player.global_position.y

	# Economy
	data["gold"] = GameManager.gold
	data["wood"] = GameManager.wood

	# Alignment
	data["alignment"] = AlignmentManager.get_alignment(0)

	# Owned towns
	var owned_towns: Array = []
	for sid in SettlementManager.SETTLEMENTS:
		if SettlementManager.is_owned(sid, 0):
			owned_towns.append(sid)
	data["owned_towns"] = owned_towns

	# Artifacts
	data["artifacts"] = GameManager.found_artifacts.duplicate()

	# Boss flags
	data["killed_bosses"] = GameManager.killed_bosses.duplicate()

	# Explored tiles
	data["explored_tiles"] = FogOfWarManager.get_explored_data()

	# Inventory — equipment and bag
	data["equipment"] = _serialize_equipment(player.inventory)
	data["bag"] = _serialize_bag(player.inventory)
	data["consumables"] = _serialize_consumables(player.inventory)

	# Total kills and milestones
	data["total_kills"] = GameManager.total_kills
	data["claimed_milestones"] = GameManager._claimed_milestones.duplicate()

	# All death counters (complete state)
	data["death_counters"] = DeathCounterSystem.get_all()

	# Armory upgrades
	data["weapon_upgrade_level"] = GameManager.weapon_upgrade_level
	data["armor_upgrade_level"] = GameManager.armor_upgrade_level

	# Woodwork upgrades
	data["woodwork_bow_level"] = GameManager.woodwork_bow_level
	data["woodwork_shield_level"] = GameManager.woodwork_shield_level
	data["woodwork_totem_level"] = GameManager.woodwork_totem_level
	data["woodwork_watchtower_level"] = GameManager.woodwork_watchtower_level

	# Watchtower building state
	data["watchtower_built"] = GameManager.watchtower_built
	data["watchtower_pos_x"] = GameManager.watchtower_pos_x
	data["watchtower_pos_y"] = GameManager.watchtower_pos_y
	data["watchtower_hp"] = GameManager.watchtower_hp

	# Region time played (for wave/boss spawn timers)
	data["region_elapsed_time"] = GameManager.region_elapsed_time

	# Write to file
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		GameManager.game_message.emit("Game Saved!", Color(0.5, 1.0, 0.5))
		game_saved.emit()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return false

	var data: Dictionary = json.data
	if data.is_empty():
		return false

	# Restore death counters first (foundation for all other systems)
	if data.has("death_counters"):
		DeathCounterSystem.load_from(data["death_counters"])

	# Restore economy
	GameManager.gold = data.get("gold", 0)
	EconomyManager.set_gold(data.get("gold", 0), 0)
	GameManager.wood = data.get("wood", 0)

	# Restore alignment
	AlignmentManager.set_alignment(data.get("alignment", 0), 0)

	# Restore kills/artifacts/bosses
	GameManager.total_kills = data.get("total_kills", 0)
	var loaded_milestones = data.get("claimed_milestones", [])
	GameManager._claimed_milestones.clear()
	for m in loaded_milestones:
		GameManager._claimed_milestones.append(int(m))
	GameManager.kills_changed.emit(GameManager.total_kills)
	GameManager.killed_bosses = Array(data.get("killed_bosses", []), TYPE_STRING, "", null)
	GameManager.found_artifacts = Array(data.get("artifacts", []), TYPE_STRING, "", null)
	GameManager.weapon_upgrade_level = data.get("weapon_upgrade_level", 0)
	GameManager.armor_upgrade_level = data.get("armor_upgrade_level", 0)

	# Restore woodwork upgrades
	GameManager.woodwork_bow_level = data.get("woodwork_bow_level", 0)
	GameManager.woodwork_shield_level = data.get("woodwork_shield_level", 0)
	GameManager.woodwork_totem_level = data.get("woodwork_totem_level", 0)
	GameManager.woodwork_watchtower_level = data.get("woodwork_watchtower_level", 0)

	# Restore watchtower building state
	GameManager.watchtower_built = data.get("watchtower_built", false)
	GameManager.watchtower_pos_x = data.get("watchtower_pos_x", 0.0)
	GameManager.watchtower_pos_y = data.get("watchtower_pos_y", 0.0)
	GameManager.watchtower_hp = data.get("watchtower_hp", 200)

	# Restore region elapsed time (wave/boss spawn timers)
	GameManager.region_elapsed_time = data.get("region_elapsed_time", 0.0)

	# Restore explored tiles
	if data.has("explored_tiles"):
		FogOfWarManager.load_explored_data(data["explored_tiles"])

	# Player state will be applied after player is instantiated
	# Store loaded data for deferred application
	_pending_load = data
	game_loaded.emit()
	GameManager.game_message.emit("Game Loaded!", Color(0.5, 1.0, 0.5))
	return true

var _pending_load: Dictionary = {}

func apply_to_player(player: Node2D) -> void:
	if _pending_load.is_empty():
		return

	var data = _pending_load

	# Restore hero stats — player already called initialize_from_hero() which
	# set base stats at level 1.  We need to re-apply all level-up growth so
	# the actual attributes (max_hp, strength, etc.) match the saved level.
	if player.stats:
		var saved_level = data.get("level", 1)
		var hero_data = HeroData.get_hero(player.hero_class)
		if not hero_data.is_empty() and saved_level > 1:
			var growth = hero_data["growth_per_level"]
			for i in range(saved_level - 1):
				player.stats.max_hp += int(growth.get("max_hp", 0))
				player.stats.max_mana += int(growth.get("max_mana", 0))
				player.stats.strength += int(growth.get("strength", 0))
				player.stats.agility += int(growth.get("agility", 0))
				player.stats.intelligence += int(growth.get("intelligence", 0))
				player.stats._armor_growth_accum += growth.get("armor", 0.0)
				if player.stats._armor_growth_accum >= 1.0:
					var gain = int(player.stats._armor_growth_accum)
					player.stats.armor += gain
					player.stats._armor_growth_accum -= gain
				player.stats.attack_damage += int(growth.get("attack_damage", 0))

		player.stats.level = saved_level
		player.stats.xp = data.get("xp", 0)
		player.stats.skill_points = data.get("skill_points", 0)

		# Re-apply armory upgrade bonuses (levels already restored in load_game)
		player.stats.armory_weapon_bonus = GameManager.weapon_upgrade_level * 2
		player.stats.armory_armor_bonus = GameManager.armor_upgrade_level
		player.stats.armory_hp_bonus = GameManager.armor_upgrade_level * 3

		# Re-apply woodwork upgrade bonuses
		player.stats.woodwork_attack_bonus = GameManager.woodwork_bow_level * 2
		player.stats.woodwork_armor_bonus = GameManager.woodwork_shield_level
		player.stats.woodwork_hp_bonus = GameManager.woodwork_shield_level * 4
		# Watchtower is now a physical building — no passive XP bonus

		# Set current HP/mana AFTER stats are fully recalculated
		# (clamped to actual max so old saves don't exceed the cap)
		player.stats.current_hp = min(data.get("current_hp", player.stats.get_total_max_hp()), player.stats.get_total_max_hp())
		player.stats.current_mana = min(data.get("current_mana", player.stats.get_total_max_mana()), player.stats.get_total_max_mana())
		player.stats._emit_all()

	# Restore position
	player.global_position = Vector2(
		data.get("position_x", 0),
		data.get("position_y", 0)
	)

	# Restore inventory
	if player.inventory:
		_deserialize_equipment(player.inventory, data.get("equipment", {}))
		_deserialize_bag(player.inventory, data.get("bag", []))
		_deserialize_consumables(player.inventory, data.get("consumables", []))

	_pending_load = {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _get_player() -> Node2D:
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		var players = tree.root.get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			return players[0]
	return null

func _serialize_equipment(inv: InventoryComponent) -> Dictionary:
	var result: Dictionary = {}
	for slot_name in inv.equipment:
		var item = inv.equipment[slot_name]
		if not item.is_empty():
			result[slot_name] = item.get("id", "")
	return result

func _serialize_bag(inv: InventoryComponent) -> Array:
	var result: Array = []
	for item in inv.bag:
		if not item.is_empty():
			result.append(item.get("id", ""))
	return result

func _serialize_consumables(inv: InventoryComponent) -> Array:
	return inv.potion_counts.duplicate()

func _deserialize_equipment(inv: InventoryComponent, data: Dictionary) -> void:
	for slot_name in data:
		var item_id = data[slot_name]
		if not item_id.is_empty():
			var item = ItemData.get_item(item_id)
			if not item.is_empty():
				inv.equipment[slot_name] = item
	inv._apply_equipment_stats()

func _deserialize_bag(inv: InventoryComponent, data: Array) -> void:
	inv.bag.clear()
	for item_id in data:
		if not item_id.is_empty():
			var item = ItemData.get_item(item_id)
			if not item.is_empty():
				inv.bag.append(item)

func _deserialize_consumables(inv: InventoryComponent, data: Array) -> void:
	for i in range(min(data.size(), inv.potion_counts.size())):
		if data[i] is int or data[i] is float:
			inv.potion_counts[i] = int(data[i])
		elif data[i] is String and not data[i].is_empty():
			# Legacy save: old consumable ID string — convert to 1 potion
			var potion_index = inv.POTION_IDS.find(data[i])
			if potion_index >= 0:
				inv.potion_counts[potion_index] += 1
