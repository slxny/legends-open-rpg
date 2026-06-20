extends Node2D

## Ground rune that pulls enemies inward over `duration`, then implodes
## dealing burst damage in `radius`. Streamers spiral inward; implode releases
## a violent radial burst.

@export var duration: float = 1.8
@export var radius: float = 200.0
@export var pull_strength: float = 380.0
@export var implode_damage: float = 95.0

var shooter: Node
var _ring: Polygon2D
var _inner: Polygon2D
var _flash: Polygon2D
var _streamers: GPUParticles2D
var _implode_burst: GPUParticles2D
var _t: float = 0.0
var _imploded: bool = false


func _ready() -> void:
	# Outer rune ring
	_ring = Polygon2D.new()
	_ring.color = Color(0.95, 0.55, 0.95, 0.65)
	_ring.polygon = _ring_poly(Vector2.ZERO, radius * 0.9, radius, 48)
	add_child(_ring)
	# Inner sigil
	_inner = Polygon2D.new()
	_inner.color = Color(0.95, 0.55, 0.95, 0.85)
	_inner.polygon = _star_poly(Vector2.ZERO, radius * 0.35, radius * 0.55, 6)
	add_child(_inner)

	# Streamer particles: spawn on a ring at the rune edge, fall inward toward
	# center via radial gravity. Combined with a small tangential push this reads
	# as a spiral pull.
	_streamers = GPUParticles2D.new()
	_streamers.amount = 40
	_streamers.lifetime = 1.4
	_streamers.preprocess = 0.7
	_streamers.local_coords = true
	_streamers.texture = _dot_texture(8, Color(1.0, 0.65, 1.0, 1.0))
	var smat := ParticleProcessMaterial.new()
	smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smat.emission_sphere_radius = radius * 0.95
	# Tangential swirl: spread fully + small base velocity, then strong radial gravity inward.
	smat.direction = Vector3(0, 0, 0)
	smat.spread = 180.0
	smat.initial_velocity_min = 30.0
	smat.initial_velocity_max = 70.0
	smat.gravity = Vector3.ZERO
	# Radial accel pulls toward the emitter origin (0,0,0) at strong magnitude.
	smat.radial_accel_min = -420.0
	smat.radial_accel_max = -260.0
	# Tangential accel creates the spiral.
	smat.tangential_accel_min = 180.0
	smat.tangential_accel_max = 320.0
	smat.scale_min = 0.5
	smat.scale_max = 1.2
	smat.color = Color(1.0, 0.65, 1.0, 1.0)
	smat.angular_velocity_min = -180.0
	smat.angular_velocity_max = 180.0
	_streamers.process_material = smat
	_streamers.z_index = 1
	add_child(_streamers)


func _process(delta: float) -> void:
	_t += delta
	if _inner:
		_inner.rotation += delta * 1.4
	if _ring:
		var pulse: float = 0.45 + 0.35 * sin(_t * 7.0)
		_ring.color = Color(0.95, 0.55, 0.95, pulse)
	# Pull enemies in
	var tree := get_tree()
	if tree:
		for e in tree.get_nodes_in_group("revamp_enemies"):
			if e is Node2D and is_instance_valid(e):
				var d: Vector2 = global_position - e.global_position
				var dist: float = d.length()
				if dist < radius and dist > 1.0:
					var pull: Vector2 = d.normalized() * pull_strength * delta * (1.0 - dist / radius)
					if e.has_method("apply_external_motion"):
						e.apply_external_motion(pull)
					else:
						e.global_position += pull
	if not _imploded and _t >= duration:
		_implode()


func _implode() -> void:
	_imploded = true
	if _streamers:
		_streamers.emitting = false
	_flash = Polygon2D.new()
	_flash.color = Color(0.95, 0.55, 0.95, 0.85)
	_flash.polygon = _circle_poly(Vector2.ZERO, radius, 48)
	add_child(_flash)

	# Implode burst: one-shot violent outward spray
	_implode_burst = GPUParticles2D.new()
	_implode_burst.amount = 40
	_implode_burst.lifetime = 0.9
	_implode_burst.one_shot = true
	_implode_burst.explosiveness = 0.98
	_implode_burst.local_coords = false
	_implode_burst.global_position = global_position
	_implode_burst.texture = _dot_texture(10, Color(1.0, 0.7, 1.0, 1.0))
	var bmat := ParticleProcessMaterial.new()
	bmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bmat.emission_sphere_radius = 8.0
	bmat.direction = Vector3(0, -1, 0)
	bmat.spread = 180.0
	bmat.initial_velocity_min = 220.0
	bmat.initial_velocity_max = 520.0
	bmat.gravity = Vector3.ZERO
	bmat.scale_min = 0.7
	bmat.scale_max = 1.5
	bmat.color = Color(1.0, 0.7, 1.0, 1.0)
	bmat.angular_velocity_min = -360.0
	bmat.angular_velocity_max = 360.0
	_implode_burst.process_material = bmat
	var parent := get_parent()
	if parent:
		parent.add_child(_implode_burst)
		var killer := get_tree().create_timer(1.1) if get_tree() else null
		if killer:
			killer.timeout.connect(_implode_burst.queue_free)

	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.45)
	tw.parallel().tween_property(_ring, "color:a", 0.0, 0.25)
	tw.parallel().tween_property(_inner, "color:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
	if shooter and shooter.has_method("resolve_damage"):
		var tree := get_tree()
		if tree:
			for e in tree.get_nodes_in_group("revamp_enemies"):
				if e is Node2D and is_instance_valid(e):
					if e.global_position.distance_to(global_position) <= radius:
						shooter.resolve_damage(e, &"arcane", &"sigil", implode_damage, 1.0)


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55))
	return arr


func _ring_poly(c: Vector2, inner: float, outer: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * outer, sin(a) * outer * 0.55))
	for i in range(n - 1, -1, -1):
		var a2: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a2) * inner, sin(a2) * inner * 0.55))
	return arr


func _star_poly(c: Vector2, inner: float, outer: float, points: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	var n: int = points * 2
	for i in range(n):
		var a: float = float(i) / float(n) * TAU - PI * 0.5
		var r: float = outer if (i % 2) == 0 else inner
		arr.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55))
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
