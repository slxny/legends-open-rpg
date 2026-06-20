extends Node2D

## Three parallax mountain layers with snow caps, atmospheric shading,
## and rocky ridge highlights. Each layer is darker + cooler-tinted the
## further back it sits.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))

const HORIZON_Y := -120.0


func _ready() -> void:
	_build_layer(Color(0.38, 0.32, 0.55), HORIZON_Y - 32.0, 130.0, 1.0, true,  Color(0.85, 0.82, 0.95))
	_build_layer(Color(0.24, 0.20, 0.40), HORIZON_Y - 18.0,  95.0, 1.4, true,  Color(0.62, 0.58, 0.78))
	_build_layer(Color(0.14, 0.12, 0.26), HORIZON_Y +  2.0,  70.0, 2.0, false, Color(0.30, 0.28, 0.42))


func _build_layer(col: Color, base_y: float, peak_h: float, jaggedness: float, draw_snow: bool, snow_col: Color) -> void:
	# 1. Solid base ridge.
	var ridge := Polygon2D.new()
	ridge.color = col
	var span: float = world_bounds.size.x + 600.0
	var step: float = 60.0
	var x0: float = world_bounds.position.x - 300.0
	var floor_y: float = HORIZON_Y + 20.0
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(x0, floor_y))
	var x: float = x0
	var i: int = 0
	var peak_pts: PackedVector2Array = PackedVector2Array()
	while x <= x0 + span:
		var peak: float = peak_h * 0.55 + sin(i * 0.72) * peak_h * 0.35 + randf() * peak_h * 0.4 * jaggedness
		var p := Vector2(x, base_y - peak)
		pts.append(p)
		peak_pts.append(p)
		x += step
		i += 1
	pts.append(Vector2(x0 + span, floor_y))
	ridge.polygon = pts
	add_child(ridge)

	# 2. Lit-side shading: a brighter polygon along the right-facing slopes.
	var lit := Polygon2D.new()
	lit.color = col.lightened(0.10)
	var lit_pts: PackedVector2Array = PackedVector2Array()
	for j in range(peak_pts.size()):
		var p := peak_pts[j]
		var hi := p + Vector2(step * 0.32, 0)
		var dip := Vector2(p.x + step * 0.7, p.y + peak_h * 0.18)
		lit_pts.append(p)
		lit_pts.append(hi)
		lit_pts.append(dip)
	# Just shade each peak independently via small triangle highlight
	for j in range(peak_pts.size() - 1):
		var tri := Polygon2D.new()
		tri.color = col.lightened(0.08)
		var p := peak_pts[j]
		var nx := peak_pts[j + 1]
		tri.polygon = PackedVector2Array([
			p, Vector2(p.x + step * 0.4, p.y + peak_h * 0.15), Vector2(p.x + step * 0.2, p.y + peak_h * 0.45),
		])
		add_child(tri)

	# 3. Snow caps on tallest peaks (only for back two layers).
	if draw_snow:
		for j in range(peak_pts.size()):
			var p := peak_pts[j]
			# Only on peaks where the next neighbor is lower (true peak).
			var prev_y: float = 9999.0
			var next_y: float = 9999.0
			if j > 0: prev_y = peak_pts[j - 1].y
			if j + 1 < peak_pts.size(): next_y = peak_pts[j + 1].y
			if p.y < prev_y and p.y < next_y and randf() < 0.45:
				var snow := Polygon2D.new()
				snow.color = snow_col
				var w := step * 0.3
				snow.polygon = PackedVector2Array([
					p,
					Vector2(p.x - w * 0.4, p.y + peak_h * 0.12),
					Vector2(p.x + w * 0.4, p.y + peak_h * 0.10),
				])
				add_child(snow)
				# Small shadow under snow
				var sh := Polygon2D.new()
				sh.color = snow_col.darkened(0.25)
				sh.polygon = PackedVector2Array([
					Vector2(p.x - w * 0.2, p.y + peak_h * 0.10),
					Vector2(p.x + w * 0.2, p.y + peak_h * 0.08),
					Vector2(p.x + w * 0.4, p.y + peak_h * 0.14),
					Vector2(p.x - w * 0.4, p.y + peak_h * 0.16),
				])
				add_child(sh)

	# 4. Ridge highlight outline.
	var highlight := Line2D.new()
	highlight.default_color = col.lightened(0.22)
	highlight.width = 1.8
	var hi_pts: PackedVector2Array = PackedVector2Array()
	for p in pts:
		if p.y < floor_y - 5.0:
			hi_pts.append(p)
	highlight.points = hi_pts
	add_child(highlight)
