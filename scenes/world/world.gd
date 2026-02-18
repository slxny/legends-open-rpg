extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	add_to_group("world")

func get_spawn_position() -> Vector2:
	return player_spawn.position
