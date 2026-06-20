extends Node2D

## Channeled storm: persistent vortex with repeated lightning strikes and
## damage ticks inside `radius` for `duration` seconds. Slow effect on
## enemies inside. Continuous lightning shards + debris swirl, each strike
## spawns 1-2 fork sub-bolts radiating outward.

@export var radius: float = 280.0
@export var duration: float = 4.0
@export var tick_damage: float = 22.0
@export var tick_interval: float = 0.4

const LightningStrike := preload("res://revamp/effects/effect_lightning_strike.gd")

var shooter: Node
var _ring: Polygon2D
var _swirl: Node2D
var _shards: GPUParticles2D
var _debris: GPUParticles2D
var _t: float = 0.0
var _next_tick: float = 0.0
var _next_strike: float = 0.0


func _ready() -> void:
	_ring = Polygon2D.new()
	_ring.color = Color(0.85, 0.92, 1.0, 0.30)
	_ring.polygon = _ellipse_poly(Vector2.ZERO, radius, radius * 0.55, 48)
	add_child(_ring)
	_swirl = Node2D.new()
	add_child(_swirl)
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var arm := Line2D.new()
		arm.width = 8.0
		arm.default_color = Color(0.75, 0.85, 1.0, 0.55)
		var pts: PackedVector2Array = PackedVector2Array()
		for s in range(10):
			var t: float = float(s) / 9.0
			var r: float = radius * (0.15 + t * 0.85)
			var ang: float = a + t * 2.4
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.55))
		arm.points = pts
		_swirl.add_child(arm)

	# Continuous lightning shard particles: bright cyan-white motes spiraling
	# through the vortex. Strong tangential accel + slight inward pull.
	_shards = GPUParticles2D.new()
	_shards.amount = 36
	_shards.lifetime = 1.2
	_shards.preprocess = 0.6
	_shards.local_coords = true
	_shards.texture = _dot_texture(8, Color(0.85, 0.95, 1.0, 1.0))
	var shmat := ParticleProcessMaterial.new()
	shmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	shmat.emission_sphere_radius = radius * 0.85
	shmat.direction = Vector3(0, 0, 0)
	shmat.spread = 180.0
	shmat.initial_velocity_min = 40.0
	shmat.initial_velocity_max = 110.0
	shmat.gravity = Vector3.ZERO
	shmat.radial_accel_min = -120.0
	shmat.radial_accel_max = -40.0
	shmat.tangential_accel_min = 220.0
	shmat.tangential_accel_max = 420.0
	shmat.scale_min = 0.5
	shmat.scale_max = 1.3
	shmat.color = Color(0.85, 0.95, 1.0, 1.0)
	shmat.angular_velocity_min = -360.0
	shmat.angular_velocity_max = 360.0
	_shards.process_material = shmat
	_shards.z_index = 2
	add_child(_shards)

	# Debris: darker, lower, swirling. Reads as windblown dust through the storm.
	_debris = GPUParticles2D.new()
	_debris.amount = 32
	_debris.lifetime = 1.6
	_debris.preprocess = 0.8
	_debris.local_coords = true
	_debris.texture = _dot_texture(6, Color(0.55, 0.55, 0.62, 0.85))
	var dmat := ParticleProcessMaterial.new()
	dmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dmat.emission_sphere_radius = radius * 0.9
	dmat.direction = Vector3(0, 0, 0)
	dmat.spread = 180.0
	dmat.initial_velocity_min = 30.0
	dmat.initial_velocity_max = 80.0
	dmat.gravity = Vector3.ZERO
	dmat.radial_accel_min = -80.0
	dmat.radial_accel_max = -20.0
	dmat.tangential_accel_min = 160.0
	dmat.tangential_accel_max = 280.0
	dmat.scale_min = 0.4
	dmat.scale_max = 1.0
	dmat.color = Color(0.55, 0.55, 0.62, 0.85)
	dmat.angular_velocity_min = -200.0
	dmat.angular_velocity_max = 200.0
	_debris.process_material = dmat
	_debris.z_index = 0
	add_child(_debris)


func _process(delta: float) -> void:
	_t += delta
	if _swirl:
		_swirl.rotation += delta * 0.9
	# Repeated strikes
	if _t >= _next_strike:
		_next_strike = _t + 0.18
		var strike_pos: Vector2 = global_position + Vector2(
			randf_range(-radius * 0.8, radius * 0.8),
			randf_range(-radius * 0.4, radius * 0.4)
		)
		_spawn_strike_at(strike_pos, 60.0, 0.18)
		# Fork sub-bolts radiating from the strike (1-2 extras)
		var forks: int = 1 + (randi() % 2)
		for i in range(forks):
			var ang: float = randf() * TAU
			var dist: float = randf_range(60.0, 130.0)
			var fork_pos: Vector2 = strike_pos + Vector2(cos(ang) * dist, sin(ang) * dist * 0.55)
			_spawn_strike_at(fork_pos, 38.0, 0.08, 0.6)
	# Damage tick
	if _t >= _next_tick:
		_next_tick = _t + tick_interval
		if shooter and shooter.has_method("resolve_damage"):
			var tree := get_tree()
			if tree:
				for e in tree.get_nodes_in_group("revamp_enemies"):
					if e is Node2D and is_instance_valid(e):
						if e.global_position.distance_to(global_position) <= radius:
							shooter.resolve_damage(e, &"lightning", &"tempest_tick", tick_damage, 1.0)
	if _t >= duration:
		if _shards:
			_shards.emitting = false
		if _debris:
			_debris.emitting = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		set_process(false)


func _spawn_strike_at(pos: Vector2, r: float, dly: float, dmg_scale: float = 1.0) -> void:
	var s := LightningStrike.new()
	s.global_position = pos
	s.delay = dly
	s.damage = tick_damage * dmg_scale
	s.radius = r
	s.shooter = shooter
	s.color_bolt = Color(0.55, 0.85, 1.0)
	var parent := get_parent()
	if parent:
		parent.add_child(s)


func _ellipse_poly(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
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
