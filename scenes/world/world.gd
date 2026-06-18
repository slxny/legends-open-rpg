extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	add_to_group("world")
	# v0.90.4 — global ambient color grade. Warm twilight tint shifts the
	# whole world toward a softer, more painterly look (vs the previous
	# raw 100%/100%/100% lighting). Subtle on individual sprites but
	# transforms the overall mood when you pan the camera.
	_install_ambient_grade()
	# v0.90.4 — ambient floating motes drifting across the world plane.
	# Atmosphere noise — fireflies / dust depending on hour-of-day rng.
	_install_ambient_motes()
	# v0.90.6 — cinematic post-process: vignette, contrast, saturation,
	# split-tone (cool shadows / warm highlights), subtle bloom.
	_install_post_process()

func _install_ambient_grade() -> void:
	# v0.90.6 — the heavy lifting moved to the post-process shader; this
	# stays as a very subtle base tint so unshadered scenes still feel warm.
	if has_node("AmbientGrade"):
		return
	var cm := CanvasModulate.new()
	cm.name = "AmbientGrade"
	cm.color = Color(1.02, 0.99, 0.94, 1.0)
	add_child(cm)

const _POST_PROCESS_SHADER := preload("res://scenes/world/post_process.gdshader")

func _install_post_process() -> void:
	if has_node("PostProcessLayer"):
		return
	# CanvasLayer at very high layer index → rendered last, on top of everything.
	var cl := CanvasLayer.new()
	cl.name = "PostProcessLayer"
	cl.layer = 100
	add_child(cl)
	# BackBufferCopy captures the screen so the shader's SCREEN_TEXTURE works.
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	cl.add_child(bbc)
	# Full-screen ColorRect carrying the post-process material.
	var rect := ColorRect.new()
	rect.name = "PostProcessRect"
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _POST_PROCESS_SHADER
	rect.material = mat
	cl.add_child(rect)

func _install_ambient_motes() -> void:
	if has_node("AmbientMotes"):
		return
	var p := GPUParticles2D.new()
	p.name = "AmbientMotes"
	p.amount = 80
	p.lifetime = 7.0
	p.preprocess = 5.0
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.fixed_fps = 30
	p.visibility_rect = Rect2(-2000, -2000, 4000, 4000)
	p.z_index = 50
	# Material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1500, 1000, 0)
	mat.direction = Vector3(0.3, -1, 0)
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.6
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.color = Color(1.5, 1.25, 0.7, 0.55)
	p.process_material = mat
	# Tiny dot texture from sprite generator
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex != null:
		p.texture = tex
	add_child(p)

func get_spawn_position() -> Vector2:
	return player_spawn.position
