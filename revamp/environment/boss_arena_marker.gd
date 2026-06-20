extends Node2D

## Boss arena floor — a dark circular plate with cracked glowing glyphs around
## the edge, lava cracks, eight broken columns, scattered braziers, and a
## perimeter ash field.

@export var center: Vector2 = Vector2.ZERO
@export var radius: float = 420.0


func _ready() -> void:
	position = center
	_ash_field()
	_floor_plate()
	_lava_cracks()
	_glyph_ring()
	_columns()
	_braziers()
	_skull_pile()


func _ash_field() -> void:
	# Soft halo of ashen ground just outside the arena
	var halo := Polygon2D.new()
	halo.color = Color(0.18, 0.10, 0.12, 0.55)
	halo.polygon = _ellipse(Vector2.ZERO, radius * 1.45, radius * 0.85, 36)
	halo.z_index = -2
	add_child(halo)


func _floor_plate() -> void:
	var plate := Polygon2D.new()
	plate.color = Color(0.12, 0.07, 0.10, 0.95)
	plate.polygon = _ellipse(Vector2.ZERO, radius, radius * 0.55, 56)
	add_child(plate)
	# Inner ring (faintly lighter)
	var inner := Polygon2D.new()
	inner.color = Color(0.22, 0.12, 0.16, 0.85)
	inner.polygon = _ellipse(Vector2.ZERO, radius * 0.55, radius * 0.30, 56)
	add_child(inner)
	# Etched concentric rings (gold)
	for r in [radius * 0.85, radius * 0.65, radius * 0.40, radius * 0.22]:
		var ring := Line2D.new()
		ring.width = 1.8
		ring.default_color = Color(0.85, 0.55, 0.25, 0.55)
		ring.closed = true
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(64):
			var a: float = float(i) / 64.0 * TAU
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))
		ring.points = pts
		add_child(ring)


func _lava_cracks() -> void:
	# Glowing fissures radiating outward from center
	for i in range(10):
		var a: float = float(i) / 10.0 * TAU + randf_range(-0.06, 0.06)
		var crack := Line2D.new()
		crack.width = 3.5
		crack.default_color = Color(1.0, 0.45, 0.10, 0.85)
		var pts: PackedVector2Array = PackedVector2Array()
		var len_: float = randf_range(radius * 0.55, radius * 0.95)
		var sub: int = 6
		for s in range(sub + 1):
			var t: float = float(s) / float(sub)
			var r: float = t * len_
			var jitter: float = sin(s * 1.4) * 14.0
			pts.append(Vector2(cos(a) * r + jitter * 0.4, sin(a) * r * 0.55 + jitter * 0.3))
		crack.points = pts
		crack.material = _make_pulse_mat()
		add_child(crack)


func _make_pulse_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		void fragment() {
			float pulse = 0.7 + 0.3 * sin(TIME * 2.0 + UV.x * 8.0);
			COLOR.a *= pulse;
		}
	"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _glyph_ring() -> void:
	for i in range(24):
		var a: float = float(i) / 24.0 * TAU
		var pos: Vector2 = Vector2(cos(a) * (radius * 0.92), sin(a) * (radius * 0.92) * 0.55)
		var glyph := Polygon2D.new()
		glyph.color = Color(0.95, 0.45, 0.20, 0.85)
		glyph.polygon = _glyph_at(pos, a + PI * 0.5)
		add_child(glyph)


func _columns() -> void:
	# Eight columns around the perimeter
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var base_pos: Vector2 = Vector2(cos(a) * radius * 0.95, sin(a) * radius * 0.55)
		var col := Polygon2D.new()
		col.color = Color(0.14, 0.10, 0.16)
		var w: float = 40.0
		var h: float = 180.0 + randf() * 40.0
		# Vary broken vs intact randomly
		if randf() < 0.5:
			h *= 0.55  # broken column
		col.polygon = PackedVector2Array([
			base_pos + Vector2(-w * 0.55, 0),
			base_pos + Vector2(-w * 0.4, -h * 0.6),
			base_pos + Vector2(-w * 0.55, -h * 0.85),
			base_pos + Vector2(-w * 0.1, -h),
			base_pos + Vector2(w * 0.4, -h * 0.92),
			base_pos + Vector2(w * 0.5, -h * 0.55),
			base_pos + Vector2(w * 0.55, 0),
		])
		add_child(col)
		# Capstone glow (only on tall columns)
		if h > 150.0:
			var glow := Polygon2D.new()
			glow.color = Color(1.0, 0.45, 0.20, 0.6)
			glow.polygon = _circle_poly(base_pos + Vector2(0, -h * 0.95), 18.0, 18)
			add_child(glow)


func _braziers() -> void:
	# 4 cardinal braziers with flickering fire
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for d in dirs:
		var at: Vector2 = Vector2(d.x * radius * 0.55, d.y * radius * 0.30)
		# Tripod base
		var base := Polygon2D.new()
		base.color = Color(0.12, 0.10, 0.16)
		base.polygon = PackedVector2Array([
			at + Vector2(-14, 0), at + Vector2(-10, -28), at + Vector2(10, -28), at + Vector2(14, 0),
		])
		add_child(base)
		# Bowl
		var bowl := Polygon2D.new()
		bowl.color = Color(0.18, 0.10, 0.10)
		bowl.polygon = PackedVector2Array([
			at + Vector2(-22, -28), at + Vector2(22, -28),
			at + Vector2(18, -36), at + Vector2(-18, -36),
		])
		add_child(bowl)
		# Flame
		var flame := Polygon2D.new()
		flame.color = Color(1.0, 0.55, 0.15, 0.92)
		flame.polygon = PackedVector2Array([
			at + Vector2(-14, -36), at + Vector2(-6, -48), at + Vector2(0, -68),
			at + Vector2(6, -48), at + Vector2(14, -36),
		])
		flame.material = _make_pulse_mat()
		add_child(flame)
		# Flame halo
		var halo := Polygon2D.new()
		halo.color = Color(1.0, 0.45, 0.10, 0.30)
		halo.polygon = _circle_poly(at + Vector2(0, -50), 26.0, 18)
		add_child(halo)


func _skull_pile() -> void:
	# Pile of skulls in front of the boss spawn (south side)
	var center_pile := Vector2(0, radius * 0.40 * 0.55)
	for i in range(6):
		var skull := Polygon2D.new()
		skull.color = Color(0.86, 0.82, 0.74)
		var off: Vector2 = Vector2(randf_range(-40, 40), randf_range(-8, 8))
		var at: Vector2 = center_pile + off
		skull.polygon = PackedVector2Array([
			at + Vector2(-7, 0), at + Vector2(-9, -7), at + Vector2(-4, -11),
			at + Vector2(4, -11), at + Vector2(9, -7), at + Vector2(7, 0),
			at + Vector2(3, 3), at + Vector2(-3, 3),
		])
		add_child(skull)


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return arr


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr


func _glyph_at(c: Vector2, angle: float) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	var raw: PackedVector2Array = PackedVector2Array([
		Vector2(-8, -12), Vector2(8, -12), Vector2(10, -8), Vector2(-10, -8),
		Vector2(-10, 8), Vector2(10, 8), Vector2(8, 12), Vector2(-8, 12),
	])
	for p in raw:
		var r := p.rotated(angle)
		arr.append(c + r * 0.6)
	return arr
