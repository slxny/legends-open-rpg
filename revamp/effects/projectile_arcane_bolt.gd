extends Area2D

## Fast arcane projectile. Damages enemies, grants the shooter a charge on hit.
## Particle-driven: streaming trail motes, pulsing glow halo, and impact burst.

const SPEED := 950.0
const LIFETIME := 1.2

@export var damage: float = 26.0
@export var pierce_max: int = 0

var shooter: Node
var _dir: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _hit_count: int = 0
var _hit_targets: Dictionary = {}
var _trail: Line2D
var _head: Polygon2D
var _glow: Polygon2D
var _halo: Sprite2D
var _trail_particles: GPUParticles2D
var _spark_particles: GPUParticles2D


func set_aim(d: Vector2) -> void:
	_dir = d.normalized()


func _ready() -> void:
	collision_layer = 1 << 4  # projectiles
	collision_mask = 1 << 1   # enemies
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	shape.shape = circ
	add_child(shape)
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)

	# Soft glowing halo (sprite from dot texture, pulses)
	_halo = Sprite2D.new()
	_halo.texture = _dot_texture(32, Color(0.55, 0.85, 1.0, 0.55))
	_halo.scale = Vector2.ONE * 1.6
	_halo.z_index = -2
	add_child(_halo)

	# Streaming trail particles (cyan motes left behind as the bolt travels)
	_trail_particles = GPUParticles2D.new()
	_trail_particles.amount = 32
	_trail_particles.lifetime = 0.6
	_trail_particles.preprocess = 0.0
	_trail_particles.local_coords = false
	_trail_particles.texture = _dot_texture(8, Color(0.65, 0.92, 1.0, 0.95))
	var tmat := ParticleProcessMaterial.new()
	tmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	tmat.emission_sphere_radius = 4.0
	tmat.direction = Vector3(-1, 0, 0)
	tmat.spread = 40.0
	tmat.initial_velocity_min = 20.0
	tmat.initial_velocity_max = 80.0
	tmat.gravity = Vector3.ZERO
	tmat.scale_min = 0.5
	tmat.scale_max = 1.2
	tmat.color = Color(0.65, 0.92, 1.0, 0.95)
	tmat.angular_velocity_min = -180.0
	tmat.angular_velocity_max = 180.0
	_trail_particles.process_material = tmat
	_trail_particles.z_index = -3
	add_child(_trail_particles)

	# Head + glow (kept; particle layer wraps them)
	_head = Polygon2D.new()
	_head.color = Color(0.85, 0.96, 1.0, 1.0)
	_head.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(4, 6), Vector2(-6, 4),
		Vector2(-10, 0), Vector2(-6, -4), Vector2(4, -6),
	])
	add_child(_head)
	_glow = Polygon2D.new()
	_glow.color = Color(0.55, 0.85, 1.0, 0.45)
	_glow.polygon = _circle_poly(Vector2.ZERO, 22.0, 16)
	_glow.z_index = -1
	add_child(_glow)
	_trail = Line2D.new()
	_trail.width = 6.0
	_trail.default_color = Color(0.55, 0.85, 1.0, 0.85)
	_trail.points = PackedVector2Array([Vector2.ZERO])
	_trail.z_index = -2
	add_child(_trail)
	rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		_destroy()
		return
	var step: Vector2 = _dir * SPEED * delta
	position += step
	# Update trail (in local space so we just append a tail point behind)
	if _trail:
		_trail.add_point(-_dir.rotated(-rotation) * 0.0)  # head stays at origin
		if _trail.get_point_count() > 18:
			_trail.remove_point(0)
		# Tail follows behind the head
		var pts: PackedVector2Array = PackedVector2Array()
		var trail_dir: Vector2 = Vector2.LEFT  # local, since we rotate the node
		for i in range(8):
			pts.append(trail_dir * float(i) * 9.0)
		_trail.points = pts
	# Wobble glow + halo pulse
	if _glow:
		_glow.scale = Vector2.ONE * (1.0 + sin(_life * 28.0) * 0.12)
	if _halo:
		var pulse: float = 1.0 + sin(_life * 18.0) * 0.22
		_halo.scale = Vector2.ONE * (1.6 * pulse)
		var a: float = 0.45 + 0.20 * sin(_life * 24.0)
		_halo.modulate = Color(1.0, 1.0, 1.0, a)


func _on_body(body: Node) -> void:
	_try_hit(body)


func _on_area(area: Node) -> void:
	_try_hit(area)


func _try_hit(node: Node) -> void:
	if _hit_targets.has(node.get_instance_id()):
		return
	if node.is_in_group("revamp_enemies") and node.has_method("take_damage"):
		_hit_targets[node.get_instance_id()] = true
		_hit_count += 1
		if shooter and shooter.has_method("resolve_damage"):
			shooter.resolve_damage(node, &"arcane", &"bolt", damage, 1.0)
		else:
			node.take_damage(int(damage), false)
		# Charge gain on hit
		if shooter and shooter.has_method("gain_charge"):
			shooter.gain_charge(1)
		_spawn_impact_burst()
		if _hit_count > pierce_max:
			_destroy()


func _spawn_impact_burst() -> void:
	# One-shot radial burst at current global position, parented to the tree so it
	# survives our queue_free.
	var parent := get_parent()
	if parent == null:
		return
	_spark_particles = GPUParticles2D.new()
	_spark_particles.amount = 28
	_spark_particles.lifetime = 0.55
	_spark_particles.one_shot = true
	_spark_particles.explosiveness = 0.95
	_spark_particles.global_position = global_position
	_spark_particles.texture = _dot_texture(8, Color(0.75, 0.95, 1.0, 1.0))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 4.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 90.0
	mat.initial_velocity_max = 260.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	mat.color = Color(0.75, 0.95, 1.0, 1.0)
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
	_spark_particles.process_material = mat
	parent.add_child(_spark_particles)
	# Self-clean the orphan burst
	var killer := get_tree().create_timer(0.7) if get_tree() else null
	if killer:
		killer.timeout.connect(_spark_particles.queue_free)


func _destroy() -> void:
	# Fade out before queue_free for a clean visual
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


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
