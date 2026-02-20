extends Node2D

@export var camp_type: String = "goblin"
@export var enemy_count: int = 4
@export var respawn_time: float = 45.0  # Faster respawn for more action

# Creep camp definitions
const CAMP_TYPES = {
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
}

var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
var _alive_count: int = 0
var _respawn_timer: float = 0.0
var _waiting_respawn: bool = false
var _times_respawned: int = 0

func _ready() -> void:
	_spawn_enemies(false)

func _process(delta: float) -> void:
	if _waiting_respawn:
		# Never respawn while player is on screen (within view distance)
		if _is_player_nearby():
			return
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_waiting_respawn = false
			_spawn_enemies(true)

func _is_player_nearby() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player):
			if global_position.distance_to(player.global_position) < 600.0:
				return true
	return false

func _spawn_enemies(is_respawn: bool) -> void:
	var type_data = CAMP_TYPES.get(camp_type, CAMP_TYPES["goblin"])
	_alive_count = enemy_count

	if is_respawn:
		_times_respawned += 1

	for i in range(enemy_count):
		var enemy = _enemy_scene.instantiate()
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		enemy.position = offset

		var level = randi_range(type_data["level_range"][0], type_data["level_range"][1])
		# Respawned enemies are slightly weaker (fewer HP, less reward)
		var weakness_factor = 1.0
		if is_respawn:
			weakness_factor = max(0.6, 1.0 - _times_respawned * 0.1)

		var config = {
			"name": type_data["name"],
			"level": level,
			"sprite_type": type_data["sprite_type"],
			"move_speed": type_data["move_speed"],
			"attack_range": type_data["attack_range"],
			"aggro_range": type_data["aggro_range"],
			"xp_reward": int((type_data["xp_reward"] + (level - 1) * 5) * weakness_factor),
			"gold_reward": int((type_data["gold_reward"] + (level - 1) * 2) * weakness_factor),
			"drop_table": type_data["drop_table"],
			"weakness_factor": weakness_factor,
		}

		add_child(enemy)
		enemy.initialize(config)
		# Apply weakness to respawned enemies
		if is_respawn and weakness_factor < 1.0:
			enemy.stats.max_hp = int(enemy.stats.max_hp * weakness_factor)
			enemy.stats.current_hp = enemy.stats.max_hp
			enemy.stats.attack_damage = int(enemy.stats.attack_damage * weakness_factor)
		enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node2D, xp_reward: int, gold_reward: int) -> void:
	GameManager.record_kill(enemy.enemy_name)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.stats:
			player.stats.add_xp(xp_reward)

	_alive_count -= 1
	if _alive_count <= 0:
		# Only respawn once the ENTIRE mob is dead
		_waiting_respawn = true
		# Random jitter: ±30% of base respawn time for variety
		_respawn_timer = respawn_time * randf_range(0.7, 1.3)
