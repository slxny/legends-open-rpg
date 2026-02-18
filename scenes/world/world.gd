extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

func get_spawn_position() -> Vector2:
	return player_spawn.position
