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
	# v0.91.4 — slow drifting cloud shadows across the world. Subtle motion
	# overlay: 5 soft dark patches sliding across the canvas in a loop. Adds
	# the Stardew "world is alive" feel without changing the ground texture.
	_install_cloud_shadows()
	# v0.92.7 — BRUTAL ambient grade. Pushes the whole world toward a darker
	# dark-fantasy register so the brutal hack-and-slash combat lands. Subtle
	# desaturation + slight green-shadow / warm-highlight bias.
	_install_brutal_ambient_grade()


func _install_brutal_ambient_grade() -> void:
	if has_node("BrutalAmbient"):
		return
	var cm := CanvasModulate.new()
	cm.name = "BrutalAmbient"
	# Multiply: red preserved, green slightly knocked, blue dimmed harder so
	# the world sits in deep moss / earth tones without going gray.
	cm.color = Color(0.92, 0.86, 0.74, 1.0)
	add_child(cm)


const _CLOUD_SHADOW_COUNT: int = 5
const _CLOUD_BOUND_X: float = 7000.0
const _CLOUD_BOUND_Y: float = 5000.0

func _install_cloud_shadows() -> void:
	if has_node("CloudShadows"):
		return
	var parent := Node2D.new()
	parent.name = "CloudShadows"
	add_child(parent)
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(_CLOUD_SHADOW_COUNT):
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = Color(0.0, 0.05, 0.1, 0.18)
		s.scale = Vector2(rng.randf_range(35.0, 60.0), rng.randf_range(20.0, 38.0))
		s.rotation = rng.randf() * TAU
		s.z_index = 6  # Above ground/decor, below characters (sit above ~0 z).
		var start := Vector2(
			rng.randf_range(-_CLOUD_BOUND_X, _CLOUD_BOUND_X),
			rng.randf_range(-_CLOUD_BOUND_Y, _CLOUD_BOUND_Y)
		)
		s.position = start
		parent.add_child(s)
		var drift_dur: float = rng.randf_range(38.0, 62.0)
		var drift_vec := Vector2(rng.randf_range(0.5, 1.0), rng.randf_range(-0.15, 0.15)).normalized() * 2200.0
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position", start + drift_vec, drift_dur)
		tw.tween_property(s, "position", start, 0.0)  # reset instantly to loop

const _EDGE_INDICATOR_SCRIPT := preload("res://scripts/components/edge_indicator_layer.gd")

func _install_edge_indicators() -> void:
	if has_node("EdgeIndicatorLayer"):
		return
	var layer = _EDGE_INDICATOR_SCRIPT.new()
	layer.name = "EdgeIndicatorLayer"
	add_child(layer)

func get_spawn_position() -> Vector2:
	return player_spawn.position
