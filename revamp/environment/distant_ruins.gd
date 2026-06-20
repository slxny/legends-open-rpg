extends Node2D

## Distant ruins along the horizon — broken towers, archway, oversized statue,
## pillar cluster. Each piece has:
##   - silhouette body
##   - shadow back layer
##   - weathering cracks
##   - lit-side highlight
##   - small glowing window/eye
## reading at distance as painted matte rather than flat polygons.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))

const HORIZON_Y := -120.0
const RUIN_TINT := Color(0.22, 0.18, 0.36)
const RUIN_LIT := Color(0.34, 0.26, 0.46)
const RUIN_DARK := Color(0.10, 0.07, 0.18)
const WINDOW_GLOW := Color(0.95, 0.55, 0.30, 0.85)


func _ready() -> void:
	_build_tower(Vector2(-1700, HORIZON_Y + 10), 170.0, true)
	_build_archway(Vector2(-400, HORIZON_Y + 14))
	_build_statue(Vector2(800, HORIZON_Y + 12))
	_build_tower(Vector2(2200, HORIZON_Y + 6), 220.0, true)
	_build_pillar_group(Vector2(3400, HORIZON_Y + 16))


# ---- Tower with shading + weathered cracks + glowing windows ----
func _build_tower(at: Vector2, height: float, broken: bool) -> void:
	var w: float = 70.0
	# Back silhouette (offset, slightly larger for depth)
	var back := Polygon2D.new()
	back.color = RUIN_DARK
	back.polygon = PackedVector2Array([
		at + Vector2(-w * 0.55, 4),
		at + Vector2(-w * 0.66, -height * 0.4),
		at + Vector2(-w * 0.62, -height * 0.7),
		at + Vector2(-w * 0.78, -height * 0.85),
		at + Vector2(-w * 0.25, -height * 1.02),
		at + Vector2(w * 0.10, -height * 0.80),
		at + Vector2(w * 0.60, -height * 0.92),
		at + Vector2(w * 0.62, -height * 0.7),
		at + Vector2(w * 0.66, -height * 0.4),
		at + Vector2(w * 0.55, 4),
	])
	add_child(back)
	# Main body
	var body := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(at + Vector2(-w * 0.5, 0))
	pts.append(at + Vector2(-w * 0.6, -height * 0.4))
	pts.append(at + Vector2(-w * 0.55, -height * 0.7))
	if broken:
		pts.append(at + Vector2(-w * 0.7, -height * 0.85))
		pts.append(at + Vector2(-w * 0.2, -height))
		pts.append(at + Vector2(w * 0.1, -height * 0.78))
		pts.append(at + Vector2(w * 0.55, -height * 0.9))
	else:
		pts.append(at + Vector2(0, -height * 1.05))
	pts.append(at + Vector2(w * 0.55, -height * 0.7))
	pts.append(at + Vector2(w * 0.6, -height * 0.4))
	pts.append(at + Vector2(w * 0.5, 0))
	body.polygon = pts
	body.color = RUIN_TINT
	add_child(body)

	# Lit-side highlight (right edge brighter)
	var lit := Polygon2D.new()
	lit.color = RUIN_LIT
	lit.polygon = PackedVector2Array([
		at + Vector2(w * 0.36, 0),
		at + Vector2(w * 0.50, -height * 0.4),
		at + Vector2(w * 0.46, -height * 0.7),
		at + Vector2(w * 0.55, -height * 0.7),
		at + Vector2(w * 0.6, -height * 0.4),
		at + Vector2(w * 0.5, 0),
	])
	add_child(lit)

	# Stonework horizontal banding
	for ratio in [0.30, 0.55, 0.78]:
		var band := Line2D.new()
		band.width = 1.2
		band.default_color = RUIN_DARK
		band.points = PackedVector2Array([
			at + Vector2(-w * 0.58, -height * ratio),
			at + Vector2(w * 0.58, -height * ratio),
		])
		add_child(band)

	# Weathering cracks
	for j in range(3):
		var crack := Line2D.new()
		crack.width = 0.9
		crack.default_color = RUIN_DARK
		var sx: float = randf_range(-w * 0.45, w * 0.45)
		var sy: float = randf_range(-height * 0.85, -height * 0.15)
		crack.points = PackedVector2Array([
			at + Vector2(sx, sy),
			at + Vector2(sx + randf_range(-4, 4), sy + randf_range(8, 30)),
			at + Vector2(sx + randf_range(-8, 8), sy + randf_range(20, 60)),
		])
		add_child(crack)

	# Window slits (glowing)
	for i in range(3):
		var wnd := ColorRect.new()
		wnd.size = Vector2(4, 9)
		wnd.color = WINDOW_GLOW
		wnd.position = at + Vector2(-2.0, -height * (0.30 + 0.18 * i))
		add_child(wnd)
		# Window halo
		var halo := Polygon2D.new()
		halo.color = Color(WINDOW_GLOW.r, WINDOW_GLOW.g, WINDOW_GLOW.b, 0.30)
		halo.polygon = _circle(at + Vector2(0, -height * (0.30 + 0.18 * i) + 4), 7.0, 12)
		add_child(halo)


# ---- Archway with keystone + moss ----
func _build_archway(at: Vector2) -> void:
	# Back shadow
	var back := Polygon2D.new()
	back.color = RUIN_DARK
	back.polygon = PackedVector2Array([
		at + Vector2(-58, 6),
		at + Vector2(-58, -114),
		at + Vector2(-30, -142),
		at + Vector2(0, -156),
		at + Vector2(30, -142),
		at + Vector2(58, -114),
		at + Vector2(58, 6),
		at + Vector2(38, 6),
		at + Vector2(38, -108),
		at + Vector2(-38, -108),
		at + Vector2(-38, 6),
	])
	add_child(back)
	# Left column
	var col_l := Polygon2D.new()
	col_l.color = RUIN_TINT
	col_l.polygon = PackedVector2Array([
		at + Vector2(-55, 0),
		at + Vector2(-48, -110),
		at + Vector2(-32, -116),
		at + Vector2(-26, 0),
	])
	add_child(col_l)
	# Left column lit edge
	var lit_l := Polygon2D.new()
	lit_l.color = RUIN_LIT
	lit_l.polygon = PackedVector2Array([
		at + Vector2(-32, -116),
		at + Vector2(-26, 0),
		at + Vector2(-30, 0),
		at + Vector2(-36, -114),
	])
	add_child(lit_l)
	# Right column
	var col_r := Polygon2D.new()
	col_r.color = RUIN_TINT
	col_r.polygon = PackedVector2Array([
		at + Vector2(26, 0),
		at + Vector2(32, -116),
		at + Vector2(48, -110),
		at + Vector2(55, 0),
	])
	add_child(col_r)
	# Right column lit edge
	var lit_r := Polygon2D.new()
	lit_r.color = RUIN_LIT
	lit_r.polygon = PackedVector2Array([
		at + Vector2(48, -110),
		at + Vector2(55, 0),
		at + Vector2(51, 0),
		at + Vector2(44, -108),
	])
	add_child(lit_r)
	# Arch top
	var top := Polygon2D.new()
	top.color = RUIN_TINT.darkened(0.1)
	top.polygon = PackedVector2Array([
		at + Vector2(-48, -110), at + Vector2(-30, -136),
		at + Vector2(0, -150), at + Vector2(30, -136), at + Vector2(48, -110),
		at + Vector2(40, -104), at + Vector2(0, -130), at + Vector2(-40, -104),
	])
	add_child(top)
	# Keystone (large center stone with gold inlay)
	var key := Polygon2D.new()
	key.color = RUIN_DARK
	key.polygon = PackedVector2Array([
		at + Vector2(-12, -148), at + Vector2(12, -148),
		at + Vector2(14, -132), at + Vector2(-14, -132),
	])
	add_child(key)
	var key_gem := Polygon2D.new()
	key_gem.color = Color(0.95, 0.78, 0.30)
	key_gem.polygon = PackedVector2Array([
		at + Vector2(-3, -144), at + Vector2(3, -144),
		at + Vector2(4, -138), at + Vector2(0, -134), at + Vector2(-4, -138),
	])
	add_child(key_gem)
	# Moss at base of columns
	for cx in [-40.0, 40.0]:
		var moss := Polygon2D.new()
		moss.color = Color(0.30, 0.45, 0.32, 0.65)
		moss.polygon = PackedVector2Array([
			at + Vector2(cx - 16, 0), at + Vector2(cx - 12, -6),
			at + Vector2(cx + 12, -4), at + Vector2(cx + 16, 0),
		])
		add_child(moss)


# ---- Statue with weathering + halo ----
func _build_statue(at: Vector2) -> void:
	# Back silhouette
	var back := Polygon2D.new()
	back.color = RUIN_DARK
	back.polygon = PackedVector2Array([
		at + Vector2(-54, 6), at + Vector2(-42, -20),
		at + Vector2(-36, -94), at + Vector2(-30, -134),
		at + Vector2(-18, -164), at + Vector2(-12, -192),
		at + Vector2(12, -192), at + Vector2(18, -164),
		at + Vector2(30, -134), at + Vector2(36, -94),
		at + Vector2(42, -20), at + Vector2(54, 6),
	])
	add_child(back)
	# Base
	var base := Polygon2D.new()
	base.color = RUIN_TINT.darkened(0.15)
	base.polygon = PackedVector2Array([
		at + Vector2(-50, 0), at + Vector2(-40, -18),
		at + Vector2(40, -18), at + Vector2(50, 0),
	])
	add_child(base)
	# Base step lines
	for y in [-4.0, -10.0, -16.0]:
		var step := Line2D.new()
		step.width = 1.0
		step.default_color = RUIN_DARK
		step.points = PackedVector2Array([
			at + Vector2(-48, y), at + Vector2(48, y),
		])
		add_child(step)
	# Body
	var body := Polygon2D.new()
	body.color = RUIN_TINT
	body.polygon = PackedVector2Array([
		at + Vector2(-32, -18), at + Vector2(-38, -90), at + Vector2(-28, -130),
		at + Vector2(-16, -160), at + Vector2(-9, -188), at + Vector2(9, -188),
		at + Vector2(16, -160), at + Vector2(28, -130), at + Vector2(38, -90),
		at + Vector2(32, -18),
	])
	add_child(body)
	# Lit side highlight
	var lit := Polygon2D.new()
	lit.color = RUIN_LIT
	lit.polygon = PackedVector2Array([
		at + Vector2(8, -18), at + Vector2(12, -90), at + Vector2(20, -130),
		at + Vector2(20, -160), at + Vector2(28, -130), at + Vector2(38, -90),
		at + Vector2(32, -18),
	])
	add_child(lit)
	# Robe folds
	for cx in [-20.0, -8.0, 8.0, 20.0]:
		var fold := Line2D.new()
		fold.width = 1.4
		fold.default_color = RUIN_DARK
		fold.points = PackedVector2Array([
			at + Vector2(cx, -18), at + Vector2(cx * 0.6, -80), at + Vector2(cx * 0.4, -120),
		])
		add_child(fold)
	# Outstretched arms
	for sx in [-1.0, 1.0]:
		var arm := Polygon2D.new()
		arm.color = RUIN_TINT
		arm.polygon = PackedVector2Array([
			at + Vector2(sx * 16, -150), at + Vector2(sx * 42, -140), at + Vector2(sx * 44, -132), at + Vector2(sx * 16, -142),
		])
		add_child(arm)
	# Head
	var head := Polygon2D.new()
	head.color = RUIN_TINT.lightened(0.08)
	head.polygon = _circle(at + Vector2(0, -208), 14.0, 14)
	add_child(head)
	# Halo (outer + inner)
	var halo_out := Polygon2D.new()
	halo_out.color = Color(0.95, 0.75, 0.45, 0.18)
	halo_out.polygon = _ring(at + Vector2(0, -212), 28.0, 40.0, 24)
	add_child(halo_out)
	var halo := Polygon2D.new()
	halo.color = Color(0.95, 0.75, 0.45, 0.45)
	halo.polygon = _ring(at + Vector2(0, -212), 26.0, 32.0, 24)
	add_child(halo)


# ---- Pillar cluster with broken caps + base rubble ----
func _build_pillar_group(at: Vector2) -> void:
	# Rubble base
	var rubble := Polygon2D.new()
	rubble.color = RUIN_DARK
	rubble.polygon = PackedVector2Array([
		at + Vector2(-80, 0), at + Vector2(-70, -10),
		at + Vector2(-40, -6), at + Vector2(20, -8),
		at + Vector2(60, -4), at + Vector2(80, 0),
	])
	add_child(rubble)
	for i in range(5):
		var px: float = at.x + (i - 2) * 38.0
		var heights := [110.0, 56.0, 82.0, 40.0, 96.0]
		var h: float = heights[i]
		# Back shadow
		var back := Polygon2D.new()
		back.color = RUIN_DARK
		back.polygon = PackedVector2Array([
			Vector2(px - 14, at.y + 2), Vector2(px - 11, at.y - h - 2),
			Vector2(px + 11, at.y - h - 2), Vector2(px + 14, at.y + 2),
		])
		add_child(back)
		# Body
		var col := Polygon2D.new()
		col.color = RUIN_TINT
		col.polygon = PackedVector2Array([
			Vector2(px - 12, at.y), Vector2(px - 9, at.y - h),
			Vector2(px + 9, at.y - h), Vector2(px + 12, at.y),
		])
		add_child(col)
		# Lit side
		var lit := Polygon2D.new()
		lit.color = RUIN_LIT
		lit.polygon = PackedVector2Array([
			Vector2(px + 4, at.y - h), Vector2(px + 9, at.y - h),
			Vector2(px + 12, at.y), Vector2(px + 6, at.y),
		])
		add_child(lit)
		# Cap (broken irregular top)
		var cap := Polygon2D.new()
		cap.color = RUIN_TINT.darkened(0.15)
		var cap_h: float = randf_range(4.0, 9.0)
		cap.polygon = PackedVector2Array([
			Vector2(px - 12, at.y - h),
			Vector2(px - 6, at.y - h - cap_h),
			Vector2(px + 4, at.y - h - cap_h * 0.6),
			Vector2(px + 12, at.y - h),
		])
		add_child(cap)
		# Crack line down body
		if randf() < 0.6:
			var crack := Line2D.new()
			crack.width = 0.7
			crack.default_color = RUIN_DARK
			crack.points = PackedVector2Array([
				Vector2(px + randf_range(-4, 4), at.y - h * 0.85),
				Vector2(px + randf_range(-4, 4), at.y - h * 0.45),
				Vector2(px + randf_range(-4, 4), at.y - h * 0.10),
			])
			add_child(crack)


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr


func _ring(c: Vector2, inner: float, outer: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * outer, sin(a) * outer))
	for i in range(n - 1, -1, -1):
		var a2: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a2) * inner, sin(a2) * inner))
	return arr
