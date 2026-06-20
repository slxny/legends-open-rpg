extends Node2D

## Scatters environment props: jagged rocks, twisted spires, mossy logs,
## shattered weapons, banners. Deterministic seed so visuals are stable.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))
@export var path_start: Vector2 = Vector2(-2000, 0)
@export var path_end: Vector2 = Vector2(3500, 0)

const GROUND_TOP := -60.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for i in range(140):
		_make_rock(rng)
	for i in range(40):
		_make_spire(rng)
	for i in range(32):
		_make_tree(rng)
	for i in range(80):
		_make_debris(rng)
	for i in range(80):
		_make_grass_tuft(rng)
	for i in range(40):
		_make_glow_mushroom(rng)
	for i in range(8):
		_make_banner(rng)


func _rand_world_pos(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(world_bounds.position.x + 100.0, world_bounds.end.x - 100.0),
		rng.randf_range(GROUND_TOP + 30.0, world_bounds.end.y - 80.0),
	)


func _make_rock(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	var r: float = rng.randf_range(14.0, 38.0)
	var poly := Polygon2D.new()
	var col := Color(0.18, 0.18, 0.26).lerp(Color(0.30, 0.32, 0.38), rng.randf())
	poly.color = col
	var verts: PackedVector2Array = PackedVector2Array()
	var sides: int = 6 + rng.randi() % 4
	for i in range(sides):
		var a: float = float(i) / float(sides) * TAU
		var jit: float = 1.0 + rng.randf_range(-0.3, 0.3)
		verts.append(at + Vector2(cos(a) * r * jit, sin(a) * r * 0.7 * jit))
	poly.polygon = verts
	add_child(poly)
	var cap := Polygon2D.new()
	cap.color = col.lightened(0.18)
	var cverts: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var a2: float = float(i) / float(sides) * TAU
		var jit2: float = 1.0 + rng.randf_range(-0.2, 0.2)
		cverts.append(at + Vector2(cos(a2) * r * jit2 * 0.6, sin(a2) * r * 0.4 * jit2 - r * 0.25))
	cap.polygon = cverts
	add_child(cap)


func _make_spire(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	var h: float = rng.randf_range(60.0, 130.0)
	var w: float = h * 0.18
	var col := Color(0.16, 0.14, 0.24)
	var poly := Polygon2D.new()
	poly.color = col
	poly.polygon = PackedVector2Array([
		at + Vector2(-w, 0),
		at + Vector2(-w * 0.4, -h * 0.6),
		at + Vector2(-w * 0.7, -h * 0.85),
		at + Vector2(0, -h),
		at + Vector2(w * 0.6, -h * 0.85),
		at + Vector2(w * 0.4, -h * 0.6),
		at + Vector2(w, 0),
	])
	add_child(poly)
	var crystal := Polygon2D.new()
	crystal.color = Color(0.55, 0.85, 1.0, 0.85)
	crystal.polygon = PackedVector2Array([
		at + Vector2(0, -h - 10),
		at + Vector2(6, -h - 2),
		at + Vector2(0, -h + 4),
		at + Vector2(-6, -h - 2),
	])
	add_child(crystal)


func _make_tree(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	var h: float = rng.randf_range(100.0, 160.0)
	var trunk := Line2D.new()
	trunk.width = rng.randf_range(6.0, 10.0)
	trunk.default_color = Color(0.10, 0.08, 0.12)
	var trunk_pts: PackedVector2Array = PackedVector2Array()
	var seg_count: int = 5
	for i in range(seg_count):
		var t: float = float(i) / float(seg_count - 1)
		trunk_pts.append(at + Vector2(sin(t * 4.0 + rng.randf() * 3.0) * 6.0, -h * t))
	trunk.points = trunk_pts
	add_child(trunk)
	for i in range(rng.randi_range(3, 5)):
		var branch := Line2D.new()
		branch.width = rng.randf_range(2.5, 4.5)
		branch.default_color = Color(0.10, 0.08, 0.12)
		var start_pt: Vector2 = trunk_pts[2 + rng.randi() % (seg_count - 2)]
		var len_: float = rng.randf_range(20.0, 50.0)
		var ang: float = rng.randf_range(-PI * 0.6, -PI * 0.05)
		if rng.randf() < 0.5:
			ang = -ang
		branch.points = PackedVector2Array([
			start_pt,
			start_pt + Vector2(cos(ang), sin(ang)) * len_,
		])
		add_child(branch)


func _make_debris(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	at.y = clampf(at.y, GROUND_TOP + 40.0, world_bounds.end.y - 120.0)
	var kind: int = rng.randi() % 3
	match kind:
		0:
			var blade := Line2D.new()
			blade.width = 3.0
			blade.default_color = Color(0.65, 0.65, 0.72)
			var ang: float = rng.randf_range(-0.8, 0.8)
			blade.points = PackedVector2Array([at, at + Vector2(cos(ang) * 26.0, sin(ang) * 9.0)])
			add_child(blade)
			var hilt := Line2D.new()
			hilt.width = 6.0
			hilt.default_color = Color(0.30, 0.20, 0.12)
			hilt.points = PackedVector2Array([at, at + Vector2(-cos(ang) * 7.0, -sin(ang) * 3.0)])
			add_child(hilt)
		1:
			var arc := Polygon2D.new()
			arc.color = Color(0.32, 0.20, 0.14)
			arc.polygon = PackedVector2Array([
				at, at + Vector2(14, -6), at + Vector2(26, 0), at + Vector2(14, 6),
			])
			add_child(arc)
		_:
			var skull := Polygon2D.new()
			skull.color = Color(0.86, 0.82, 0.74)
			skull.polygon = PackedVector2Array([
				at + Vector2(-7, 0), at + Vector2(-9, -6), at + Vector2(-4, -10),
				at + Vector2(4, -10), at + Vector2(9, -6), at + Vector2(7, 0),
				at + Vector2(3, 3), at + Vector2(-3, 3),
			])
			add_child(skull)


func _make_grass_tuft(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	# 3 thin blades fanning up
	var col := Color(0.35, 0.42, 0.30, 0.85).lerp(Color(0.45, 0.55, 0.30, 0.85), rng.randf())
	for i in range(3):
		var blade := Line2D.new()
		blade.width = 1.6
		blade.default_color = col
		var ang: float = -PI * 0.5 + (i - 1) * 0.35 + rng.randf_range(-0.15, 0.15)
		var h: float = rng.randf_range(10.0, 18.0)
		blade.points = PackedVector2Array([at, at + Vector2(cos(ang) * h * 0.35, sin(ang) * h)])
		add_child(blade)


func _make_glow_mushroom(rng: RandomNumberGenerator) -> void:
	var at: Vector2 = _rand_world_pos(rng)
	# Stem
	var stem := Line2D.new()
	stem.width = 3.0
	stem.default_color = Color(0.85, 0.78, 0.65)
	stem.points = PackedVector2Array([at, at + Vector2(0, -10)])
	add_child(stem)
	# Cap (glowing)
	var cap := Polygon2D.new()
	var glow_col := Color(0.55, 0.92, 0.95, 0.95)
	if rng.randf() < 0.4:
		glow_col = Color(0.95, 0.55, 0.95, 0.95)
	cap.color = glow_col
	cap.polygon = PackedVector2Array([
		at + Vector2(-8, -8), at + Vector2(-5, -14), at + Vector2(5, -14),
		at + Vector2(8, -8), at + Vector2(4, -6), at + Vector2(-4, -6),
	])
	add_child(cap)
	# Halo
	var halo := Polygon2D.new()
	halo.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.30)
	halo.polygon = PackedVector2Array([
		at + Vector2(-14, -10), at + Vector2(0, -22), at + Vector2(14, -10),
		at + Vector2(0, -2),
	])
	halo.z_index = -1
	add_child(halo)


func _make_banner(rng: RandomNumberGenerator) -> void:
	var x: float = lerpf(path_start.x, path_end.x, rng.randf_range(0.2, 0.9))
	var y: float = rng.randf_range(80.0, 260.0)
	if rng.randf() < 0.5:
		y = -y * 0.6
	var at := Vector2(x, y)
	var pole := Line2D.new()
	pole.default_color = Color(0.10, 0.08, 0.12)
	pole.width = 4.0
	pole.points = PackedVector2Array([at, at + Vector2(0, -100)])
	add_child(pole)
	var cloth := Polygon2D.new()
	cloth.color = Color(0.62, 0.20, 0.24)
	cloth.polygon = PackedVector2Array([
		at + Vector2(0, -94),
		at + Vector2(44, -86),
		at + Vector2(40, -52),
		at + Vector2(48, -30),
		at + Vector2(0, -36),
	])
	add_child(cloth)
	var sigil := Polygon2D.new()
	sigil.color = Color(0.95, 0.85, 0.45)
	sigil.polygon = PackedVector2Array([
		at + Vector2(14, -74), at + Vector2(26, -66), at + Vector2(22, -56), at + Vector2(10, -60),
	])
	add_child(sigil)
