extends Control

## Spherical HP orb. Liquid fill rises with current HP, surrounded by a
## gold ring and a small numeric overlay.

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

var _hp: float = 1.0
var _max: float = 1.0
var _t: float = 0.0
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size = size
	_label.text = "—"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	set_process(true)
	queue_redraw()


func set_hp(current: float, maximum: float) -> void:
	_hp = current
	_max = max(maximum, 0.01)
	_label.text = "%d / %d" % [int(_hp), int(_max)]
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * 0.46
	# Outer ring backdrop
	draw_circle(c, radius + 6.0, Color(0, 0, 0, 0.55))
	draw_circle(c, radius + 1.5, HUDStyle.FRAME_GOLD_DARK)
	# Glass orb base
	draw_circle(c, radius, Color(0.08, 0.05, 0.12, 0.95))
	# Liquid fill — only draw when there's something to render so we don't
	# spam triangulation errors on a degenerate strip.
	var ratio: float = clampf(_hp / _max, 0.0, 1.0)
	if ratio > 0.005:
		var fill_color: Color = HUDStyle.HEALTH_FILL if ratio > 0.35 else HUDStyle.HEALTH_LOW
		var top: float = c.y + radius - radius * 2.0 * ratio
		# Bottom arc (left → right along the bottom semicircle, then clip)
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 36
		for i in range(steps + 1):
			var t: float = float(i) / float(steps)
			var ang: float = lerpf(0.0, PI, t)
			var x: float = c.x - cos(ang) * radius
			var y: float = c.y + sin(ang) * radius
			if y < top:
				y = top
			pts.append(Vector2(x, y))
		# Top wave (right → left)
		var wave: int = 16
		for i in range(wave + 1):
			var t: float = float(i) / float(wave)
			var x: float = lerpf(c.x + radius, c.x - radius, t)
			var y: float = top + sin(_t * 3.0 + t * 6.0) * 2.5
			pts.append(Vector2(x, y))
		draw_colored_polygon(pts, fill_color)
	# Highlight crescent
	draw_arc(c + Vector2(-radius * 0.4, -radius * 0.2), radius * 0.55, PI * 0.95, PI * 1.45, 18, Color(1, 1, 1, 0.35), 4.0)
	# Outer rim gold
	draw_arc(c, radius, 0.0, TAU, 64, HUDStyle.FRAME_GOLD, 2.5)
	# Glints
	for i in range(4):
		var a: float = _t * 0.6 + float(i) * TAU / 4.0
		var glint: Vector2 = c + Vector2(cos(a), sin(a)) * (radius + 4.0)
		draw_circle(glint, 2.5, Color(1, 0.95, 0.7, 0.5))
	# Gold scroll-cap perched on top of the orb
	_draw_scroll_cap(c + Vector2(0.0, -radius - 1.5), radius * 0.55)


func _draw_scroll_cap(anchor: Vector2, w: float) -> void:
	# Overlapping arc forming a horned cap, plus a small ruby at center.
	var arc_pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 22
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var a: float = lerpf(PI, 0.0, t)
		arc_pts.append(anchor + Vector2(cos(a) * w, -sin(a) * (w * 0.55) - 2.0))
	draw_polyline(arc_pts, HUDStyle.FRAME_GOLD, 2.0)
	# Inner shadow arc
	var arc_in: PackedVector2Array = PackedVector2Array()
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var a: float = lerpf(PI, 0.0, t)
		arc_in.append(anchor + Vector2(cos(a) * (w * 0.78), -sin(a) * (w * 0.42) - 2.0))
	draw_polyline(arc_in, HUDStyle.FRAME_GOLD_DARK, 1.2)
	# Curled horns at each end (small filled dots + ring)
	var lhorn: Vector2 = anchor + Vector2(-w, -2.0)
	var rhorn: Vector2 = anchor + Vector2(w, -2.0)
	draw_circle(lhorn, 2.5, HUDStyle.FRAME_GOLD)
	draw_circle(rhorn, 2.5, HUDStyle.FRAME_GOLD)
	draw_arc(lhorn, 3.6, 0.0, TAU, 14, HUDStyle.FRAME_GOLD_DARK, 1.0)
	draw_arc(rhorn, 3.6, 0.0, TAU, 14, HUDStyle.FRAME_GOLD_DARK, 1.0)
	# Crown gem at the apex
	HUDStyle.draw_gem(self, anchor + Vector2(0.0, -w * 0.55 - 2.0), 3.0, HUDStyle.RUBY)
