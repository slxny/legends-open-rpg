extends Node2D

## Telegraphed lightning bolt. Pre-strike spark particles in the telegraph oval,
## post-strike ember puff and a bright glow ring on impact.

@export var delay: float = 0.0
@export var damage: float = 70.0
@export var radius: float = 70.0
@export var color_bolt: Color = Color(0.95, 0.95, 0.55)

var shooter: Node
var _telegraph: Polygon2D
var _bolt: Line2D
var _flash: Polygon2D
var _ring: Sprite2D
var _sparks: GPUParticles2D
var _embers: GPUParticles2D
var _t: float = 0.0
var _struck: bool = false


func _ready() -> void:
	_telegraph = Polygon2D.new()
	_telegraph.color = Color(0.95, 0.85, 0.30, 0.4)
	_telegraph.polygon = _ellipse_poly(Vector2.ZERO, radius, radius * 0.5, 24)
	add_child(_telegraph)

	# Telegraph spark particles: continuous warning sparkle inside the oval
	_sparks = GPUParticles2D.new()
	_sparks.amount = 32
	_sparks.lifetime = 0.7
	_sparks.preprocess = 0.3
	_sparks.local_coords = true
	_sparks.texture = _dot_texture(8, Color(1.0, 0.95, 0.55, 1.0))
	var smat := ParticleProcessMaterial.new()
	smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smat.emission_sphere_radius = radius * 0.75
	smat.direction = Vector3(0, -1, 0)
	smat.spread = 180.0
	smat.initial_velocity_min = 20.0
	smat.initial_velocity_max = 90.0
	smat.gravity = Vector3(0, -60, 0)
	smat.scale_min = 0.4
	smat.scale_max = 1.1
	smat.color = Color(1.0, 0.95, 0.55, 1.0)
	smat.angular_velocity_min = -180.0
	smat.angular_velocity_max = 180.0
	_sparks.process_material = smat
	_sparks.z_index = -1
	add_child(_sparks)


func _process(delta: float) -> void:
	_t += delta
	if not _struck and _t >= delay:
		_strike()


func _strike() -> void:
	_struck = true
	if _telegraph:
		_telegraph.queue_free()
	if _sparks:
		_sparks.emitting = false
	# Bolt
	_bolt = Line2D.new()
	_bolt.width = 12.0
	_bolt.default_color = color_bolt
	var pts: PackedVector2Array = PackedVector2Array()
	var x: float = 0.0
	var y: float = -460.0
	while y < 0.0:
		pts.append(Vector2(x, y))
		y += 22.0
		x += randf_range(-14.0, 14.0)
	pts.append(Vector2(0, 0))
	_bolt.points = pts
	add_child(_bolt)
	# Flash
	_flash = Polygon2D.new()
	_flash.color = Color(1.0, 1.0, 0.85, 0.85)
	_flash.polygon = _ellipse_poly(Vector2.ZERO, radius * 1.6, radius * 0.85, 24)
	add_child(_flash)
	# Bright glow ring on impact (sprite from dot, scaled large)
	_ring = Sprite2D.new()
	_ring.texture = _dot_texture(64, Color(1.0, 1.0, 0.7, 0.85))
	var ring_scale: float = (radius * 2.6) / 64.0
	_ring.scale = Vector2.ONE * ring_scale * 0.3
	add_child(_ring)
	var tw_ring := create_tween()
	tw_ring.tween_property(_ring, "scale", Vector2.ONE * ring_scale, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_ring.parallel().tween_property(_ring, "modulate:a", 0.0, 0.35)

	# Ember puff: one-shot radial burst of warm sparks
	_embers = GPUParticles2D.new()
	_embers.amount = 36
	_embers.lifetime = 0.9
	_embers.one_shot = true
	_embers.explosiveness = 0.9
	_embers.texture = _dot_texture(8, Color(1.0, 0.75, 0.30, 1.0))
	var emat := ParticleProcessMaterial.new()
	emat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	emat.emission_sphere_radius = 6.0
	emat.direction = Vector3(0, -1, 0)
	emat.spread = 180.0
	emat.initial_velocity_min = 60.0
	emat.initial_velocity_max = 240.0
	emat.gravity = Vector3(0, 200, 0)
	emat.scale_min = 0.5
	emat.scale_max = 1.3
	emat.color = Color(1.0, 0.75, 0.30, 1.0)
	emat.angular_velocity_min = -360.0
	emat.angular_velocity_max = 360.0
	_embers.process_material = emat
	add_child(_embers)

	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	tw.parallel().tween_property(_bolt, "default_color:a", 0.0, 0.35)
	# Hold long enough for ember/ring to play out before freeing.
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)
	# Damage
	if shooter and shooter.has_method("resolve_damage"):
		var tree := get_tree()
		if tree:
			for e in tree.get_nodes_in_group("revamp_enemies"):
				if e is Node2D and is_instance_valid(e):
					if e.global_position.distance_to(global_position) <= radius:
						shooter.resolve_damage(e, &"lightning", &"burst", damage, 1.0)


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
