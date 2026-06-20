extends Control

## Custom-drawn ability button. Shows the ability icon (procedural glyph),
## cooldown overlay, key hint, label, and a "modified" gold border when the
## player's equipped item changes that ability.

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

@export var icon_color: Color = Color(0.85, 0.85, 1.0)
@export var key_hint: String = ""
@export var label_text: String = ""

var _state: Dictionary = {}
var _modified: bool = false
var _t: float = 0.0


func _ready() -> void:
	set_process(true)


func apply_state(s: Dictionary) -> void:
	_state = s
	queue_redraw()


func set_modified(on: bool) -> void:
	_modified = on
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var ready: bool = bool(_state.get("ready", true))
	var cd_rem: float = float(_state.get("cooldown_remaining", 0.0))
	var cd_tot: float = float(_state.get("cooldown_total", 1.0))
	var rect := Rect2(Vector2.ZERO, size)
	# Background
	draw_rect(rect, HUDStyle.FRAME_BG, true)
	# Color tint when ready
	var tint: Color = icon_color if ready else Color(0.4, 0.4, 0.4)
	if not ready:
		tint = tint.darkened(0.4)
	# Icon: a glyph specific to ability (use color + simple shape)
	_draw_glyph(rect, tint)
	# Cooldown sweep
	if not ready and cd_tot > 0.01:
		var ratio: float = clampf(cd_rem / cd_tot, 0.0, 1.0)
		_draw_cooldown_sweep(rect.get_center(), min(rect.size.x, rect.size.y) * 0.45, ratio)
		# Numeric remaining
		var font := ThemeDB.fallback_font
		if font:
			var t: String = "%.1f" % cd_rem
			draw_string_outline(font, rect.position + Vector2(rect.size.x * 0.5 - 12, rect.size.y * 0.5 + 6), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, 4, Color(0, 0, 0))
			draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - 12, rect.size.y * 0.5 + 6), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1))
	# Three-layer ornate border: outer dark gold / mid bright gold / inner highlight
	var outer_col: Color = HUDStyle.FRAME_GOLD_DARK
	var mid_col: Color = HUDStyle.FRAME_GOLD if _modified else HUDStyle.FRAME_GOLD_DARK.lerp(HUDStyle.FRAME_GOLD, 0.55)
	if _modified:
		var pulse: float = 0.7 + 0.3 * sin(_t * 4.0)
		mid_col = mid_col.lerp(Color(1, 0.7, 0.3), pulse * 0.6)
	draw_rect(rect, outer_col, false, 2.0)
	draw_rect(rect.grow(-2.0), mid_col, false, 1.4)
	draw_rect(rect.grow(-3.5), HUDStyle.FRAME_HIGHLIGHT, false, 1.0)
	# Tiny gem-dots at the four corners
	var corner_inset: float = 4.0
	var corner_col: Color = HUDStyle.CHARGE_GEM if _modified else HUDStyle.FRAME_GOLD
	var tl: Vector2 = rect.position + Vector2(corner_inset, corner_inset)
	var tr: Vector2 = rect.position + Vector2(rect.size.x - corner_inset, corner_inset)
	var bl: Vector2 = rect.position + Vector2(corner_inset, rect.size.y - corner_inset)
	var br: Vector2 = rect.position + Vector2(rect.size.x - corner_inset, rect.size.y - corner_inset)
	for p in [tl, tr, bl, br]:
		draw_circle(p, 1.6, corner_col)
		draw_arc(p, 2.4, 0.0, TAU, 10, HUDStyle.FRAME_GOLD_DARK, 0.8)
	# Key hint top-right
	var font2 := ThemeDB.fallback_font
	if font2:
		draw_string_outline(font2, rect.position + Vector2(rect.size.x - 22, 14), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0))
		draw_string(font2, rect.position + Vector2(rect.size.x - 22, 14), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HUDStyle.FRAME_GOLD)
		draw_string_outline(font2, rect.position + Vector2(4, rect.size.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0))
		draw_string(font2, rect.position + Vector2(4, rect.size.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HUDStyle.TEXT_PRIMARY)
	# Charge-cost dots
	var req: int = int(_state.get("requires_charges", 0))
	if req > 0:
		for i in range(req):
			var dot_pos: Vector2 = rect.position + Vector2(6 + i * 8, 18)
			draw_circle(dot_pos, 2.5, HUDStyle.CHARGE_FILL)


func _draw_glyph(rect: Rect2, tint: Color) -> void:
	var c: Vector2 = rect.get_center()
	# Common base: filled ring
	draw_circle(c, min(rect.size.x, rect.size.y) * 0.34, Color(tint.r, tint.g, tint.b, 0.35))
	draw_arc(c, min(rect.size.x, rect.size.y) * 0.34, 0.0, TAU, 24, tint, 2.0)
	# Glyph rendered with stroked lines (no triangulation needed).
	match key_hint:
		"LMB":
			# Arrow tip pointing up-right
			draw_line(c + Vector2(-10, 8), c + Vector2(10, -10), tint, 3.0)
			draw_line(c + Vector2(10, -10), c + Vector2(2, -8), tint, 3.0)
			draw_line(c + Vector2(10, -10), c + Vector2(8, -2), tint, 3.0)
		"RMB":
			# Lightning bolt zigzag (open polyline)
			var pts := PackedVector2Array([
				c + Vector2(-3, -12), c + Vector2(-7, -2), c + Vector2(0, 0),
				c + Vector2(-3, 12), c + Vector2(7, 0), c + Vector2(0, -2),
				c + Vector2(3, -12),
			])
			draw_polyline(pts, tint, 2.5)
		"1":
			# Two stacked chevrons (step icon)
			draw_line(c + Vector2(-9, -2), c + Vector2(-2, -8), tint, 2.5)
			draw_line(c + Vector2(-2, -8), c + Vector2(5, -2), tint, 2.5)
			draw_line(c + Vector2(-9, 8), c + Vector2(-2, 2), tint, 2.5)
			draw_line(c + Vector2(-2, 2), c + Vector2(5, 8), tint, 2.5)
		"2":
			# Shield arc
			draw_arc(c, 11.0, PI * 0.80, PI * 2.20, 18, tint, 3.0)
			draw_line(c + Vector2(-10, -4), c + Vector2(0, -12), tint, 2.5)
			draw_line(c + Vector2(10, -4), c + Vector2(0, -12), tint, 2.5)
		"3":
			# Hexagonal sigil (closed polyline)
			var pts := PackedVector2Array()
			for i in range(7):
				var a: float = float(i % 6) / 6.0 * TAU - PI * 0.5
				pts.append(c + Vector2(cos(a) * 10.0, sin(a) * 10.0))
			draw_polyline(pts, tint, 2.0)
			draw_circle(c, 3.0, tint)
		"4":
			# Tempest spiral
			var pts := PackedVector2Array()
			for i in range(22):
				var t: float = float(i) / 21.0
				var r: float = 2.0 + t * 12.0
				var a: float = t * TAU * 1.6
				pts.append(c + Vector2(cos(a) * r, sin(a) * r))
			draw_polyline(pts, tint, 2.0)
		"SP":
			# Running figure: two arrows pointing right with afterimage
			draw_line(c + Vector2(-9, -2), c + Vector2(1, -8), tint, 2.2)
			draw_line(c + Vector2(-9, 2), c + Vector2(1, 8), tint, 2.2)
			draw_line(c + Vector2(1, -8), c + Vector2(9, 0), tint, 2.5)
			draw_line(c + Vector2(1, 8), c + Vector2(9, 0), tint, 2.5)
		"Q":
			# Vial outline (closed polyline so the cross doesn't triangulate)
			var pts := PackedVector2Array([
				c + Vector2(-5, -10), c + Vector2(5, -10), c + Vector2(5, -6),
				c + Vector2(8, 4), c + Vector2(0, 10), c + Vector2(-8, 4),
				c + Vector2(-5, -6), c + Vector2(-5, -10),
			])
			draw_polyline(pts, tint, 2.0)
			# Stopper bar
			draw_line(c + Vector2(-6, -12), c + Vector2(6, -12), tint, 3.0)
		_:
			draw_circle(c, 6.0, tint)


func _draw_cooldown_sweep(c: Vector2, r: float, remaining_ratio: float) -> void:
	# Sweep darkens the part of the icon that's still on cooldown.
	# Pie sector from -PI/2 sweeping clockwise. Skip drawing when the
	# sector is too thin — a degenerate polygon spams "triangulation failed".
	if remaining_ratio <= 0.01:
		return
	var seg_count: int = 36
	var pts: PackedVector2Array = PackedVector2Array([c])
	var total_arc: float = TAU * remaining_ratio
	for i in range(seg_count + 1):
		var t: float = float(i) / float(seg_count)
		var a: float = -PI * 0.5 + t * total_arc
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.65))
