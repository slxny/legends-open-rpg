extends Node2D

@export var camp_type: String = "goblin"
@export var enemy_count: int = 4
@export var respawn_time: float = 45.0  # Faster respawn for more action

# Creep camp definitions
const CAMP_TYPES = {
	"rat": {
		"name": "Rat",
		"level_range": [1, 1],
		"sprite_type": "rat",
		"move_speed": 100.0,
		"attack_range": 28.0,
		"aggro_range": 120.0,
		"attack_damage": 6,
		"xp_reward": 4,
		"gold_reward": 1,
		"drop_table": "rat",
	},
	"goblin": {
		"name": "Goblin",
		"level_range": [1, 2],
		"sprite_type": "goblin",
		"move_speed": 70.0,
		"attack_range": 30.0,
		"aggro_range": 100.0,
		"xp_reward": 12,
		"gold_reward": 3,
		"drop_table": "goblin",
	},
	"wolf": {
		"name": "Wolf",
		"level_range": [2, 3],
		"sprite_type": "wolf",
		"move_speed": 110.0,
		"attack_range": 30.0,
		"aggro_range": 130.0,
		"xp_reward": 18,
		"gold_reward": 4,
		"drop_table": "wolf",
	},
	"bandit": {
		"name": "Bandit Scout",
		"level_range": [3, 5],
		"sprite_type": "bandit",
		"move_speed": 85.0,
		"attack_range": 35.0,
		"aggro_range": 110.0,
		"xp_reward": 25,
		"gold_reward": 8,
		"drop_table": "bandit",
	},
	"skeleton": {
		"name": "Skeleton",
		"level_range": [2, 4],
		"sprite_type": "skeleton",
		"move_speed": 65.0,
		"attack_range": 30.0,
		"aggro_range": 110.0,
		"xp_reward": 16,
		"gold_reward": 4,
		"drop_table": "skeleton",
	},
	"spider": {
		"name": "Giant Spider",
		"level_range": [3, 5],
		"sprite_type": "spider",
		"move_speed": 120.0,
		"attack_range": 25.0,
		"aggro_range": 100.0,
		"xp_reward": 20,
		"gold_reward": 5,
		"drop_table": "spider",
	},
	"troll": {
		"name": "Forest Troll",
		"level_range": [5, 7],
		"sprite_type": "troll",
		"move_speed": 60.0,
		"attack_range": 40.0,
		"aggro_range": 120.0,
		"xp_reward": 35,
		"gold_reward": 12,
		"drop_table": "troll",
	},
	"dark_mage": {
		"name": "Dark Mage",
		"level_range": [5, 8],
		"sprite_type": "dark_mage",
		"move_speed": 70.0,
		"attack_range": 50.0,
		"aggro_range": 140.0,
		"xp_reward": 40,
		"gold_reward": 15,
		"drop_table": "dark_mage",
	},
	"ogre": {
		"name": "Ogre",
		"level_range": [7, 10],
		"sprite_type": "ogre",
		"move_speed": 50.0,
		"attack_range": 45.0,
		"aggro_range": 130.0,
		"xp_reward": 55,
		"gold_reward": 20,
		"drop_table": "ogre",
	},
	"ogre_boss": {
		"name": "Ogre Warlord",
		"level_range": [10, 12],
		"sprite_type": "ogre_boss",
		"move_speed": 45.0,
		"attack_range": 50.0,
		"aggro_range": 150.0,
		"xp_reward": 100,
		"gold_reward": 50,
		"drop_table": "ogre_boss",
	},
	# --- Higher-tier enemies (progressive spawns) ---
	"demon_knight": {
		"name": "Demon Knight",
		"level_range": [12, 15],
		"sprite_type": "demon_knight",
		"move_speed": 75.0,
		"attack_range": 40.0,
		"aggro_range": 140.0,
		"xp_reward": 80,
		"gold_reward": 30,
		"drop_table": "dark_mage",
	},
	"ancient_golem": {
		"name": "Ancient Golem",
		"level_range": [15, 18],
		"sprite_type": "ancient_golem",
		"move_speed": 40.0,
		"attack_range": 50.0,
		"aggro_range": 110.0,
		"xp_reward": 110,
		"gold_reward": 40,
		"drop_table": "ogre",
	},
	"shadow_wraith": {
		"name": "Shadow Wraith",
		"level_range": [18, 22],
		"sprite_type": "shadow_wraith",
		"move_speed": 100.0,
		"attack_range": 35.0,
		"aggro_range": 160.0,
		"xp_reward": 140,
		"gold_reward": 50,
		"drop_table": "ogre_boss",
	},
	"dragon_whelp": {
		"name": "Dragon Whelp",
		"level_range": [22, 26],
		"sprite_type": "dragon_whelp",
		"move_speed": 90.0,
		"attack_range": 45.0,
		"aggro_range": 150.0,
		"xp_reward": 180,
		"gold_reward": 65,
		"drop_table": "ogre_boss",
	},
	"infernal": {
		"name": "Infernal",
		"level_range": [26, 30],
		"sprite_type": "infernal",
		"move_speed": 55.0,
		"attack_range": 55.0,
		"aggro_range": 130.0,
		"xp_reward": 220,
		"gold_reward": 80,
		"drop_table": "ogre_boss",
	},
	# --- Mini-Boss types ---
	"mini_boss_ravager": {
		"name": "Ravager",
		"level_range": [8, 10],
		"sprite_type": "ogre_boss",
		"move_speed": 65.0,
		"attack_range": 50.0,
		"aggro_range": 200.0,
		"xp_reward": 200,
		"gold_reward": 100,
		"drop_table": "mini_boss_ravager",
		"is_mini_boss": true,
	},
	"mini_boss_dread_knight": {
		"name": "Dread Knight",
		"level_range": [14, 18],
		"sprite_type": "demon_knight",
		"move_speed": 70.0,
		"attack_range": 45.0,
		"aggro_range": 200.0,
		"xp_reward": 350,
		"gold_reward": 150,
		"drop_table": "mini_boss_dread_knight",
		"is_mini_boss": true,
	},
	"mini_boss_elder_drake": {
		"name": "Elder Drake",
		"level_range": [22, 26],
		"sprite_type": "dragon_whelp",
		"move_speed": 80.0,
		"attack_range": 55.0,
		"aggro_range": 220.0,
		"xp_reward": 500,
		"gold_reward": 250,
		"drop_table": "mini_boss_elder_drake",
		"is_mini_boss": true,
	},
	"mini_boss_abyssal_lord": {
		"name": "Abyssal Lord",
		"level_range": [28, 32],
		"sprite_type": "infernal",
		"move_speed": 60.0,
		"attack_range": 60.0,
		"aggro_range": 240.0,
		"xp_reward": 750,
		"gold_reward": 400,
		"drop_table": "mini_boss_abyssal_lord",
		"is_mini_boss": true,
	},
}

signal mini_boss_died(boss_name: String, position: Vector2)

var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
var _alive_count: int = 0
var _respawn_timer: float = 0.0
var _waiting_respawn: bool = false
var _spawned: bool = false  # Whether initial spawn has happened
var _times_respawned: int = 0
var _cached_player: Node2D = null
var _player_check_timer: float = 0.0
var _spawn_queue: Array = []  # Pending enemies to spawn across frames
var _is_stagger_spawning: bool = false
const PLAYER_CHECK_INTERVAL: float = 0.5  # Only check player proximity twice per second
const ACTIVATION_DISTANCE_SQ: float = 2250000.0  # 1500^2 — camps within this activate immediately
const ENEMIES_PER_FRAME: int = 3  # Max enemies to instantiate per frame during staggered spawn

func _ready() -> void:
	# Defer initial spawn: camps close to origin (player spawn) activate immediately,
	# distant camps wait until the player approaches
	var dist_sq = global_position.length_squared()
	if dist_sq < ACTIVATION_DISTANCE_SQ:
		_spawn_enemies_staggered(false)
	# Distant camps stay dormant until player is nearby (checked in _process)

func _process(delta: float) -> void:
	# Handle staggered spawning: drip-feed enemies across frames
	if _is_stagger_spawning and _spawn_queue.size() > 0:
		var count = mini(_spawn_queue.size(), ENEMIES_PER_FRAME)
		for _i in range(count):
			var pending = _spawn_queue.pop_front()
			_instantiate_enemy(pending)
		if _spawn_queue.size() == 0:
			_is_stagger_spawning = false
		return

	# Check if this camp hasn't spawned yet (distant camp waiting for player)
	if not _spawned and not _is_stagger_spawning:
		_player_check_timer -= delta
		if _player_check_timer <= 0.0:
			_player_check_timer = PLAYER_CHECK_INTERVAL
			if _is_player_in_activation_range():
				_spawn_enemies_staggered(false)
		return

	if not _waiting_respawn:
		return
	# Throttle player proximity checks to twice per second
	_player_check_timer -= delta
	if _player_check_timer <= 0.0:
		_player_check_timer = PLAYER_CHECK_INTERVAL
		if _is_player_nearby():
			return
	_respawn_timer -= delta
	if _respawn_timer <= 0:
		_waiting_respawn = false
		_spawn_enemies_staggered(true)

func _is_player_nearby() -> bool:
	if not _cached_player or not is_instance_valid(_cached_player):
		var players = get_tree().get_nodes_in_group("player")
		_cached_player = players[0] if players.size() > 0 else null
	if _cached_player and is_instance_valid(_cached_player):
		return global_position.distance_squared_to(_cached_player.global_position) < 360000.0  # 600^2
	return false

func _is_player_in_activation_range() -> bool:
	if not _cached_player or not is_instance_valid(_cached_player):
		var players = get_tree().get_nodes_in_group("player")
		_cached_player = players[0] if players.size() > 0 else null
	if _cached_player and is_instance_valid(_cached_player):
		return global_position.distance_squared_to(_cached_player.global_position) < ACTIVATION_DISTANCE_SQ
	return false

func _get_player_level() -> int:
	if not _cached_player or not is_instance_valid(_cached_player):
		var players = get_tree().get_nodes_in_group("player")
		_cached_player = players[0] if players.size() > 0 else null
	if _cached_player and is_instance_valid(_cached_player) and _cached_player.stats:
		return _cached_player.stats.level
	return 1

func _spawn_enemies_staggered(is_respawn: bool) -> void:
	var type_data = CAMP_TYPES.get(camp_type, CAMP_TYPES["goblin"])
	_alive_count = enemy_count
	_spawned = true

	if is_respawn:
		_times_respawned += 1

	var spread = 30.0 + enemy_count * 4.0
	var player_level = _get_player_level()
	var type_max = type_data["level_range"][1]
	_spawn_queue.clear()
	for i in range(enemy_count):
		var base_level = randi_range(type_data["level_range"][0], type_data["level_range"][1])

		# Scale enemy level to at least match the player's level (+0 to 2 bonus)
		var scaled_level = max(base_level, player_level + randi_range(0, 2))

		# Compute effective stats level: dampen growth for levels above natural range
		# Boosted levels contribute at 60% rate so enemies are tougher but still beatable
		var stats_level = scaled_level
		if scaled_level > type_max:
			var boost = scaled_level - type_max
			stats_level = type_max + int(ceil(boost * 0.6))

		var weakness_factor = 1.0
		if is_respawn:
			weakness_factor = max(0.6, 1.0 - _times_respawned * 0.1)

		_spawn_queue.append({
			"offset": Vector2(randf_range(-spread, spread), randf_range(-spread, spread)),
			"type_data": type_data,
			"level": scaled_level,
			"stats_level": stats_level,
			"weakness_factor": weakness_factor,
			"is_respawn": is_respawn,
		})
	_is_stagger_spawning = true

func _instantiate_enemy(pending: Dictionary) -> void:
	var enemy = _enemy_scene.instantiate()
	enemy.position = pending["offset"]
	var type_data = pending["type_data"]
	var level = pending["level"]
	var stats_level = pending["stats_level"]
	var weakness_factor = pending["weakness_factor"]
	var is_respawn = pending["is_respawn"]
	var is_mini_boss = type_data.get("is_mini_boss", false)

	var config = {
		"name": type_data["name"],
		"level": level,
		"stats_level": stats_level,
		"sprite_type": type_data["sprite_type"],
		"move_speed": type_data["move_speed"],
		"attack_range": type_data["attack_range"],
		"aggro_range": type_data["aggro_range"],
		"xp_reward": int((type_data["xp_reward"] + (level - 1) * 5) * weakness_factor),
		"gold_reward": int((type_data["gold_reward"] + (level - 1) * 2) * weakness_factor),
		"drop_table": type_data["drop_table"],
		"weakness_factor": weakness_factor,
		"is_mini_boss": is_mini_boss,
	}
	if type_data.has("attack_damage"):
		var base_atk = type_data["attack_damage"]
		var type_max = type_data["level_range"][1]
		if stats_level > type_max:
			# Scale explicit attack damage for boosted levels
			config["attack_damage"] = base_atk + (stats_level - type_max) * 3
		else:
			config["attack_damage"] = base_atk

	add_child(enemy)
	enemy.initialize(config)
	if is_mini_boss:
		# Mini-bosses get 3x HP, 1.5x damage, larger sprite
		enemy.stats.max_hp = int(enemy.stats.max_hp * 3.0)
		enemy.stats.current_hp = enemy.stats.max_hp
		enemy.stats.attack_damage = int(enemy.stats.attack_damage * 1.5)
		enemy.sprite.scale = Vector2(1.5, 1.5)
		enemy.sprite.modulate = Color(1.2, 0.8, 0.8)  # Reddish tint
		enemy._base_scale = Vector2(1.5, 1.5)
		enemy._base_modulate = Color(1.2, 0.8, 0.8)
		enemy.start_boss_pulse()
	if is_respawn and weakness_factor < 1.0:
		enemy.stats.max_hp = int(enemy.stats.max_hp * weakness_factor)
		enemy.stats.current_hp = enemy.stats.max_hp
		enemy.stats.attack_damage = int(enemy.stats.attack_damage * weakness_factor)
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node2D, xp_reward: int, gold_reward: int) -> void:
	GameManager.record_kill(enemy.enemy_name)
	if not _cached_player or not is_instance_valid(_cached_player):
		var players = get_tree().get_nodes_in_group("player")
		_cached_player = players[0] if players.size() > 0 else null
	var player = _cached_player
	if player and is_instance_valid(player):
		if player.stats:
			player.stats.add_xp(xp_reward)

	# Check if this was a mini-boss
	if enemy.is_mini_boss:
		mini_boss_died.emit(enemy.enemy_name, enemy.global_position)

	_alive_count -= 1
	if _alive_count <= 0:
		# Only respawn once the ENTIRE mob is dead
		_waiting_respawn = true
		# Random jitter: ±30% of base respawn time for variety
		_respawn_timer = respawn_time * randf_range(0.7, 1.3)
