extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	add_to_group("world")
	# Apply isometric projection to the entire world.
	# All children (terrain, enemies, player) are rendered through this transform.
	# Game logic stays in Cartesian coordinates — the transform only affects visuals.
	transform = IsometricHelper.get_iso_transform()

func get_spawn_position() -> Vector2:
	return player_spawn.position
