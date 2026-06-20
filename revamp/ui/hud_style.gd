extends RefCounted
class_name RevampHUDStyle

## Shared color palette + small drawing helpers for the revamp HUD.

const FRAME_BG := Color(0.07, 0.06, 0.12, 0.90)
const FRAME_GOLD := Color(0.96, 0.80, 0.42)
const FRAME_GOLD_DARK := Color(0.55, 0.42, 0.18)
const FRAME_HIGHLIGHT := Color(1.0, 0.95, 0.75, 0.55)
const TEXT_PRIMARY := Color(0.95, 0.92, 0.78)
const TEXT_DIM := Color(0.70, 0.66, 0.55)
const HEALTH_FILL := Color(0.85, 0.15, 0.22)
const HEALTH_LOW := Color(1.0, 0.45, 0.12)
const CHARGE_FILL := Color(0.55, 0.85, 1.0)
const POTION_FILL := Color(1.0, 0.45, 0.35)
const CHARGE_GEM := Color(0.55, 0.85, 1.0)
const RUBY := Color(0.88, 0.18, 0.28)
const EMERALD := Color(0.30, 0.78, 0.42)
const SAPPHIRE := Color(0.35, 0.55, 0.95)


static func draw_panel(c: CanvasItem, rect: Rect2, radius: float = 8.0) -> void:
	# Background plate
	c.draw_rect(rect, FRAME_BG, true, -1.0)
	# Gold double-stroke border
	c.draw_rect(rect, FRAME_GOLD_DARK, false, 3.0)
	var inner: Rect2 = rect.grow(-3.0)
	c.draw_rect(inner, FRAME_GOLD, false, 1.5)
	# Engraved hairline along the inner edge
	var hairline: Rect2 = rect.grow(-5.5)
	c.draw_rect(hairline, FRAME_HIGHLIGHT, false, 1.0)
	# Top inner highlight line
	c.draw_line(rect.position + Vector2(8, 4), rect.position + Vector2(rect.size.x - 8, 4), FRAME_HIGHLIGHT, 1.5)


static func draw_glowing_dot(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	c.draw_circle(center, radius * 1.6, Color(col.r, col.g, col.b, 0.30))
	c.draw_circle(center, radius, col)
	c.draw_arc(center, radius, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.95), 1.5)


## Draws a small swirl/scroll flourish in a corner. `dir` is a Vector2 of
## (+/-1, +/-1) indicating which corner (e.g. (-1,-1) = top-left scrolls
## inward toward center). `s` is the visual scale.
static func draw_filigree_corner(c: CanvasItem, origin: Vector2, dir: Vector2, s: float = 12.0) -> void:
	var dx: float = sign(dir.x) if dir.x != 0.0 else 1.0
	var dy: float = sign(dir.y) if dir.y != 0.0 else 1.0
	# Outer sweeping arc — quarter circle from the corner curving in.
	var pivot: Vector2 = origin + Vector2(dx * s, dy * s)
	# Two stacked arcs for a layered scroll feel.
	var seg: int = 14
	var pts1: PackedVector2Array = PackedVector2Array()
	var pts2: PackedVector2Array = PackedVector2Array()
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		# Angle sweep: pick the quadrant that points back at `origin`.
		var a0: float = atan2(-dy, -dx)
		var a: float = a0 + t * (PI * 0.5) * (1.0 if dx * dy > 0.0 else -1.0)
		pts1.append(pivot + Vector2(cos(a), sin(a)) * s)
		pts2.append(pivot + Vector2(cos(a), sin(a)) * (s * 0.62))
	c.draw_polyline(pts1, FRAME_GOLD, 1.5)
	c.draw_polyline(pts2, FRAME_GOLD_DARK, 1.0)
	# Tiny terminal swirl: small filled dot + ring at the inner endpoint.
	var tip: Vector2 = pts2[pts2.size() - 1]
	c.draw_circle(tip, 2.0, FRAME_GOLD)
	c.draw_arc(tip, 3.5, 0.0, TAU, 12, FRAME_GOLD_DARK, 1.0)


## Draws a gem inlay — small colored circle with a gold ring.
static func draw_gem(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	# Soft halo
	c.draw_circle(center, radius + 2.0, Color(col.r, col.g, col.b, 0.25))
	# Gem body
	c.draw_circle(center, radius, col)
	# Inner highlight crescent (small white sliver up-left)
	c.draw_circle(center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.35, Color(1, 1, 1, 0.55))
	# Gold ring
	c.draw_arc(center, radius + 1.0, 0.0, TAU, 18, FRAME_GOLD, 1.4)
	c.draw_arc(center, radius + 2.0, 0.0, TAU, 18, FRAME_GOLD_DARK, 0.8)


## Engraved hairline along the inside of `rect`, inset by `inset` px.
static func draw_engraved_hairline(c: CanvasItem, rect: Rect2, inset: float = 6.0) -> void:
	var r: Rect2 = rect.grow(-inset)
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	c.draw_rect(r, FRAME_HIGHLIGHT, false, 1.0)


## Convenience: paints all four corners of `rect` with `draw_filigree_corner`.
static func draw_corner_filigree(c: CanvasItem, rect: Rect2, s: float = 12.0) -> void:
	var tl: Vector2 = rect.position
	var tr: Vector2 = rect.position + Vector2(rect.size.x, 0)
	var bl: Vector2 = rect.position + Vector2(0, rect.size.y)
	var br: Vector2 = rect.position + rect.size
	draw_filigree_corner(c, tl, Vector2(1, 1), s)
	draw_filigree_corner(c, tr, Vector2(-1, 1), s)
	draw_filigree_corner(c, bl, Vector2(1, -1), s)
	draw_filigree_corner(c, br, Vector2(-1, -1), s)
