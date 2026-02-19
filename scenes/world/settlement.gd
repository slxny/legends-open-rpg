extends Node2D

## Settlement — purchasable town with buildings and guards.
## When purchased: buildings change to player color, guards spawn at patrol points.

@export var settlement_id: String = "havens_rest"
@export var purchase_cost: int = 500

var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
var _guards: Array[Node2D] = []
var _owned_by: int = -1  # Player ID, -1 = unowned

func _ready() -> void:
	add_to_group("settlements")
	# Check if already owned via DeathCounterSystem
	var owner = SettlementManager.get_owner(settlement_id)
	if owner >= 0:
		_apply_ownership(owner)
	# Listen for purchase events
	SettlementManager.settlement_purchased.connect(_on_settlement_purchased)

func _on_settlement_purchased(sid: String, player_id: int) -> void:
	if sid == settlement_id:
		_apply_ownership(player_id)

func _apply_ownership(player_id: int) -> void:
	_owned_by = player_id
	# Change building sprites to player color
	var player_color = _get_player_color(player_id)
	for child in get_children():
		if child.is_in_group("settlement_buildings"):
			child.modulate = player_color
	# Spawn guards at patrol points
	_spawn_guards(player_id)

func _spawn_guards(player_id: int) -> void:
	# Remove existing guards
	for guard in _guards:
		if is_instance_valid(guard):
			guard.queue_free()
	_guards.clear()

	var config = SettlementManager.get_settlement_config(settlement_id)
	var guard_count = config.get("guard_count", 4)
	var guard_level = config.get("guard_level", 5)

	for i in range(guard_count):
		var guard = _enemy_scene.instantiate()
		# Position guards around settlement
		var angle = TAU * float(i) / guard_count
		var radius = 80.0
		guard.position = Vector2(cos(angle), sin(angle)) * radius

		add_child(guard)
		guard.initialize({
			"name": "Town Guard",
			"level": guard_level,
			"sprite_type": "bandit",  # Use bandit sprite as guard placeholder
			"move_speed": 60.0,
			"attack_range": 35.0,
			"aggro_range": 150.0,
			"xp_reward": 0,  # Guards give no XP
			"gold_reward": 0,
			"drop_table": "",
		})
		# Guards don't attack the owning player
		guard.remove_from_group("enemies")
		guard.add_to_group("guards")
		guard.modulate = _get_player_color(player_id)
		_guards.append(guard)

func try_purchase(player_id: int = 0) -> bool:
	return SettlementManager.purchase(settlement_id, player_id)

func _get_player_color(player_id: int) -> Color:
	var colors = [
		Color(0.3, 0.5, 1.0),  # Blue
		Color(1.0, 0.3, 0.3),  # Red
		Color(0.3, 1.0, 0.3),  # Green
		Color(1.0, 1.0, 0.3),  # Yellow
	]
	return colors[player_id % colors.size()]
