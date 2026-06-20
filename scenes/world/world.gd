extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

const _TORCH_VIGNETTE_SHADER := preload("res://scenes/world/torch_vignette.gdshader")

var _torch_rect: ColorRect = null
var _torch_mat: ShaderMaterial = null
var _cached_player: Node2D = null

func _ready() -> void:
	add_to_group("world")
	_install_edge_indicators()
	_install_cloud_shadows()
	# v0.92.9 — coordinated DARK FANTASY pass:
	# 1. Brutal-dark ambient (deeper than v0.92.7's 0.92/0.86/0.74).
	# 2. Drifting fog-band ribbons across the world.
	# 3. Radial TORCH VIGNETTE around the player so the action sits in a
	#    lit clearing surrounded by cold darkness — Diablo / PoE focal frame.
	_install_brutal_ambient_grade()
	_install_fog_bands()
	_install_torch_vignette()


func _process(_delta: float) -> void:
	# Track the player's screen position to drive the torch vignette.
	if _torch_mat == null:
		return
	if _cached_player == null or not is_instance_valid(_cached_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_cached_player = players[0]
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var canvas_xform: Transform2D = vp.get_canvas_transform()
	var screen_pos: Vector2 = canvas_xform * _cached_player.global_position
	var focus_uv: Vector2 = Vector2(
		clampf(screen_pos.x / vp_size.x, -0.5, 1.5),
		clampf(screen_pos.y / vp_size.y, -0.5, 1.5)
	)
	_torch_mat.set_shader_parameter("focus_uv", focus_uv)


func _install_brutal_ambient_grade() -> void:
	if has_node("BrutalAmbient"):
		return
	var cm := CanvasModulate.new()
	cm.name = "BrutalAmbient"
	# v0.93.3 — LUSH FANTASY pivot. Lifted from brutal twilight (0.72) back
	# to rich painterly afternoon: red preserved, slight warm-gold lift,
	# blue gently knocked so highlights read as sun-touched. The torch
	# vignette + per-character halos provide the focal contrast now.
	cm.color = Color(1.02, 1.00, 0.88, 1.0)
	add_child(cm)


const _FOG_BAND_COUNT: int = 4
const _FOG_BAND_BOUND_X: float = 7800.0

func _install_fog_bands() -> void:
	if has_node("FogBands"):
		return
	var parent := Node2D.new()
	parent.name = "FogBands"
	add_child(parent)
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in range(_FOG_BAND_COUNT):
		var band := Sprite2D.new()
		band.texture = tex
		band.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Cool moonlit fog with a touch of green so it blends with the moss.
		band.modulate = Color(0.78, 0.82, 0.95, rng.randf_range(0.05, 0.10))
		# Wide+short bands so they read as low-hanging mist.
		band.scale = Vector2(rng.randf_range(180.0, 260.0), rng.randf_range(8.0, 18.0))
		band.rotation = rng.randf_range(-0.05, 0.05)
		band.z_index = 9  # Above ground + clouds, below characters.
		var start_y: float = float(i) * 2500.0 - 4500.0 + rng.randf_range(-180, 180)
		band.position = Vector2(-_FOG_BAND_BOUND_X, start_y)
		parent.add_child(band)
		var dur: float = rng.randf_range(58.0, 96.0)
		var end: Vector2 = Vector2(_FOG_BAND_BOUND_X, start_y + rng.randf_range(-80, 80))
		var tw := band.create_tween().set_loops()
		tw.tween_property(band, "position", end, dur).set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(band, "position", band.position, 0.0)


func _install_torch_vignette() -> void:
	if has_node("TorchVignetteLayer"):
		return
	var cl := CanvasLayer.new()
	cl.name = "TorchVignetteLayer"
	cl.layer = 90  # Above world content, below HUD (10) — wait HUD is layer 10.
	# HUD is at layer 10. Vignette must sit BELOW HUD so HUD is never dimmed.
	cl.layer = 5
	add_child(cl)
	var rect := ColorRect.new()
	rect.name = "TorchVignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _TORCH_VIGNETTE_SHADER
	rect.material = mat
	_torch_mat = mat
	_torch_rect = rect
	cl.add_child(rect)


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
