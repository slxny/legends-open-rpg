extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	add_to_group("world")
	# v0.91.2 — visual revamp restart. Stripped the screen-space post-process,
	# golden motes, color-grade CanvasModulate, and per-region tint presets —
	# they were stacking layers on top of an ugly base instead of fixing it.
	# Aesthetic direction is now modern pixel-art (Stardew / HLD / Eastward):
	# larger sprites, bold outlines, painted ground, mascara-thick shadows.
	# Edge indicators kept — they're a gameplay readability layer, not visuals.
	_install_edge_indicators()

const _EDGE_INDICATOR_SCRIPT := preload("res://scripts/components/edge_indicator_layer.gd")

func _install_edge_indicators() -> void:
	if has_node("EdgeIndicatorLayer"):
		return
	var layer = _EDGE_INDICATOR_SCRIPT.new()
	layer.name = "EdgeIndicatorLayer"
	add_child(layer)

func get_spawn_position() -> Vector2:
	return player_spawn.position
