extends Node2D

## Slow drifting motes + occasional firefly sparks. GPU particles to keep
## frame cost low on GL Compatibility.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -1600), Vector2(6400, 3200))


func _ready() -> void:
	_make_motes()
	_make_fireflies()
	_make_embers()


func _make_motes() -> void:
	var p := GPUParticles2D.new()
	p.amount = 120
	p.lifetime = 6.0
	p.preprocess = 4.0
	p.position = world_bounds.get_center()
	p.texture = _dot_texture(8, Color(0.95, 0.92, 0.85, 0.7))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(world_bounds.size.x * 0.5, world_bounds.size.y * 0.4, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 22.0
	mat.scale_min = 0.4
	mat.scale_max = 1.1
	mat.color = Color(0.95, 0.92, 0.85, 0.7)
	mat.angular_velocity_min = -45.0
	mat.angular_velocity_max = 45.0
	p.process_material = mat
	add_child(p)


func _make_fireflies() -> void:
	var p := GPUParticles2D.new()
	p.amount = 24
	p.lifetime = 4.5
	p.preprocess = 3.0
	p.position = world_bounds.get_center()
	p.texture = _dot_texture(10, Color(0.95, 0.85, 0.45, 0.95))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(world_bounds.size.x * 0.4, world_bounds.size.y * 0.25, 1)
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 35.0
	mat.spread = 180.0
	mat.color = Color(0.95, 0.85, 0.45, 0.85)
	p.process_material = mat
	add_child(p)


func _make_embers() -> void:
	var p := GPUParticles2D.new()
	p.amount = 36
	p.lifetime = 3.5
	p.preprocess = 2.0
	p.position = world_bounds.get_center()
	p.texture = _dot_texture(6, Color(1.0, 0.55, 0.20, 0.9))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(world_bounds.size.x * 0.45, world_bounds.size.y * 0.4, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.gravity = Vector3(0, -25, 0)
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 45.0
	mat.spread = 25.0
	mat.scale_min = 0.4
	mat.scale_max = 0.9
	mat.color = Color(1.0, 0.55, 0.20, 0.85)
	p.process_material = mat
	add_child(p)


func _dot_texture(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d: float = (Vector2(x, y) - c).length() / float(size * 0.5)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.5)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)
