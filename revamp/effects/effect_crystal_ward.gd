extends Node2D

## Visual bubble around the host while Crystal Ward is up. Shard fragments
## orbit the bubble; on expire, shards burst outward.

@export var duration: float = 2.0
var host: Node
var _bubble: Polygon2D
var _orbit_shards: GPUParticles2D
var _burst_shards: GPUParticles2D
var _t: float = 0.0


func _ready() -> void:
	z_index = 6
	_bubble = Polygon2D.new()
	_bubble.color = Color(0.45, 0.85, 1.0, 0.30)
	_bubble.polygon = _circle_poly(Vector2.ZERO, 50.0, 32)
	add_child(_bubble)
	# Inner ring
	var inner := Line2D.new()
	inner.width = 3.0
	inner.default_color = Color(0.55, 0.95, 1.0, 0.85)
	inner.closed = true
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(32):
		var a: float = float(i) / 32.0 * TAU
		pts.append(Vector2(cos(a) * 50.0, sin(a) * 50.0))
	inner.points = pts
	add_child(inner)

	# Orbiting shard fragments: emit on the bubble surface, strong tangential
	# acceleration with near-zero radial drift gives a tight orbit illusion.
	_orbit_shards = GPUParticles2D.new()
	_orbit_shards.amount = 28
	_orbit_shards.lifetime = 1.4
	_orbit_shards.preprocess = 0.7
	_orbit_shards.local_coords = true
	_orbit_shards.texture = _dot_texture(8, Color(0.75, 0.98, 1.0, 1.0))
	var omat := ParticleProcessMaterial.new()
	omat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	omat.emission_sphere_radius = 50.0
	omat.direction = Vector3(0, 0, 0)
	omat.spread = 180.0
	omat.initial_velocity_min = 10.0
	omat.initial_velocity_max = 40.0
	omat.gravity = Vector3.ZERO
	omat.radial_accel_min = -20.0
	omat.radial_accel_max = 20.0
	omat.tangential_accel_min = 240.0
	omat.tangential_accel_max = 360.0
	omat.scale_min = 0.5
	omat.scale_max = 1.2
	omat.color = Color(0.75, 0.98, 1.0, 1.0)
	omat.angular_velocity_min = -360.0
	omat.angular_velocity_max = 360.0
	_orbit_shards.process_material = omat
	add_child(_orbit_shards)


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(host):
		queue_free()
		return
	global_position = host.global_position
	if _bubble:
		var pulse: float = 0.30 + 0.18 * sin(_t * 9.0)
		_bubble.color = Color(0.45, 0.85, 1.0, pulse)
		_bubble.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.04)
	if _t >= duration:
		_expire()


func _expire() -> void:
	# Cap re-entry from any further frame
	set_process(false)
	if _orbit_shards:
		_orbit_shards.emitting = false

	# Outward shard burst at the bubble's last position
	_burst_shards = GPUParticles2D.new()
	_burst_shards.amount = 32
	_burst_shards.lifetime = 0.9
	_burst_shards.one_shot = true
	_burst_shards.explosiveness = 0.95
	_burst_shards.local_coords = false
	_burst_shards.global_position = global_position
	_burst_shards.texture = _dot_texture(8, Color(0.80, 1.0, 1.0, 1.0))
	var bmat := ParticleProcessMaterial.new()
	bmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bmat.emission_sphere_radius = 50.0
	bmat.direction = Vector3(0, 0, 0)
	bmat.spread = 180.0
	bmat.initial_velocity_min = 180.0
	bmat.initial_velocity_max = 420.0
	bmat.gravity = Vector3.ZERO
	bmat.scale_min = 0.6
	bmat.scale_max = 1.4
	bmat.color = Color(0.80, 1.0, 1.0, 1.0)
	bmat.angular_velocity_min = -360.0
	bmat.angular_velocity_max = 360.0
	_burst_shards.process_material = bmat
	var parent := get_parent()
	if parent:
		parent.add_child(_burst_shards)
		var killer := get_tree().create_timer(1.1) if get_tree() else null
		if killer:
			killer.timeout.connect(_burst_shards.queue_free)

	queue_free()


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr


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
