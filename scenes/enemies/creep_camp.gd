extends Node2D

@export var camp_type: String = "goblin"
@export var enemy_count: int = 4
@export var respawn_time: float = 90.0

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

func _ready() -> void:
	_spawn_enemies()

func _process(delta: float) -> void:
	if _waiting_respawn:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_waiting_respawn = false
			_spawn_enemies()

func _spawn_enemies() -> void:
	var type_data = CAMP_TYPES.get(camp_type, CAMP_TYPES["goblin"])
	_alive_count = enemy_count

	for i in range(enemy_count):
		var enemy = _enemy_scene.instantiate()
		# Scatter enemies around camp center
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		enemy.position = offset

		var level = randi_range(type_data["level_range"][0], type_data["level_range"][1])
		var config = {
			"name": type_data["name"],
			"level": level,
			"sprite_type": type_data["sprite_type"],
			"move_speed": type_data["move_speed"],
			"attack_range": type_data["attack_range"],
			"aggro_range": type_data["aggro_range"],
			"xp_reward": type_data["xp_reward"] + (level - 1) * 5,
			"gold_reward": type_data["gold_reward"] + (level - 1) * 2,
			"drop_table": type_data["drop_table"],
		}

		add_child(enemy)
		enemy.initialize(config)
		enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node2D, xp_reward: int, gold_reward: int) -> void:
	# Give XP directly (gold comes from walk-over crystal drops)
	GameManager.total_kills += 1
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.stats:
			player.stats.add_xp(xp_reward)

	_alive_count -= 1
	if _alive_count <= 0:
		# All enemies dead, start respawn timer
		_waiting_respawn = true
		_respawn_timer = respawn_time
