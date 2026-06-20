extends Control

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

var _hp: float = 1.0
var _max: float = 1.0
var _name_text: String = ""
var _phase: int = 1
var _phase_flash_t: float = 0.0


func _ready() -> void:
	set_process(true)


func set_health(current: float, maximum: float) -> void:
	_hp = current
	_max = max(maximum, 0.01)
	queue_redraw()


func set_boss_name(t: String) -> void:
	_name_text = t
	queue_redraw()


func flash_phase(p: int) -> void:
	_phase = p
	_phase_flash_t = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _phase_flash_t > 0.0:
		_phase_flash_t = maxf(0.0, _phase_flash_t - delta * 0.8)
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	HUDStyle.draw_panel(self, rect, 4.0)
	# Boss bar fill
	var bar_rect := Rect2(Vector2(28, 32), Vector2(size.x - 56, 28))
	draw_rect(bar_rect, Color(0.04, 0.02, 0.06), true)
	var ratio: float = clampf(_hp / _max, 0.0, 1.0)
	var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y))
	# Gradient fill — orange to red
	var seg_count: int = 64
	for i in range(seg_count):
		var t0: float = float(i) / float(seg_count)
		var t1: float = float(i + 1) / float(seg_count)
		if t0 > ratio:
			break
		var x0: float = fill_rect.position.x + bar_rect.size.x * t0
		var x1: float = fill_rect.position.x + bar_rect.size.x * min(t1, ratio)
		var seg := Rect2(Vector2(x0, fill_rect.position.y), Vector2(x1 - x0, fill_rect.size.y))
		var col := Color(1.0, 0.45, 0.10).lerp(Color(0.85, 0.15, 0.22), t0)
		draw_rect(seg, col, true)
	# Bar border
	draw_rect(bar_rect, HUDStyle.FRAME_GOLD, false, 1.5)
	# Sheen
	draw_rect(Rect2(bar_rect.position + Vector2(2, 2), Vector2(bar_rect.size.x - 4, 6)), Color(1, 1, 1, 0.20), true)
	# Filigree corners on the outer panel
	HUDStyle.draw_corner_filigree(self, rect.grow(-2.0), 12.0)
	# Repeating arc filigree across the top edge
	_draw_top_arc_filigree()
	# Crown silhouette centered above the boss name
	_draw_crown(Vector2(size.x * 0.5, 4.0), 10.0)
	# Name + phase pips
	var name_pos := Vector2(28, 6)
	var font := ThemeDB.fallback_font
	if font:
		var col_name: Color = HUDStyle.TEXT_PRIMARY
		if _phase_flash_t > 0.0:
			col_name = col_name.lerp(Color(1, 0.7, 0.3), _phase_flash_t)
		draw_string_outline(font, name_pos + Vector2(0, 18), _name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 1))
		draw_string(font, name_pos + Vector2(0, 18), _name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col_name)
	# Phase pips
	for i in range(3):
		var pip_pos: Vector2 = Vector2(size.x - 80 + i * 22, 18)
		var lit: bool = i < _phase
		var col: Color = HUDStyle.FRAME_GOLD if lit else Color(0.30, 0.30, 0.30)
		draw_circle(pip_pos, 7.0, col)
		draw_arc(pip_pos, 8.0, 0.0, TAU, 16, HUDStyle.FRAME_GOLD_DARK, 1.2)
	# Ruby gem inlays at the mid-vertical edges
	HUDStyle.draw_gem(self, Vector2(4.0, size.y * 0.5), 3.0, HUDStyle.RUBY)
	HUDStyle.draw_gem(self, Vector2(size.x - 4.0, size.y * 0.5), 3.0, HUDStyle.RUBY)


func _draw_top_arc_filigree() -> void:
	# Repeating shallow arcs along the top edge — engraved crest motif.
	var arc_w: float = 18.0
	var y: float = 22.0
	var x0: float = 80.0
	var x1: float = size.x - 80.0
	if x1 <= x0:
		return
	var n: int = int(floor((x1 - x0) / arc_w))
	for i in range(n):
		var cx: float = x0 + (float(i) + 0.5) * arc_w
		# Half-circle arc, opens downward.
		var pts: PackedVector2Array = PackedVector2Array()
		var seg: int = 10
		for j in range(seg + 1):
			var t: float = float(j) / float(seg)
			var a: float = PI + t * PI
			pts.append(Vector2(cx + cos(a) * (arc_w * 0.35), y + sin(a) * 3.5))
		draw_polyline(pts, HUDStyle.FRAME_GOLD_DARK, 1.0)


func _draw_crown(center: Vector2, h: float) -> void:
	# Three-point crown silhouette as an open polyline so it never triangulates badly.
	var base_y: float = center.y + h * 0.5
	var top_y: float = center.y - h * 0.5
	var mid_y: float = center.y - h * 0.15
	var w: float = h * 1.6
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - w * 0.5, base_y),
		Vector2(center.x - w * 0.5, mid_y),
		Vector2(center.x - w * 0.32, top_y + 2.0),
		Vector2(center.x - w * 0.18, mid_y + 1.5),
		Vector2(center.x, top_y),
		Vector2(center.x + w * 0.18, mid_y + 1.5),
		Vector2(center.x + w * 0.32, top_y + 2.0),
		Vector2(center.x + w * 0.5, mid_y),
		Vector2(center.x + w * 0.5, base_y),
		Vector2(center.x - w * 0.5, base_y),
	])
	draw_polyline(pts, HUDStyle.FRAME_GOLD, 1.6)
	# Three small gem inlays on the crown points
	HUDStyle.draw_gem(self, Vector2(center.x - w * 0.32, top_y + 2.0), 1.6, HUDStyle.EMERALD)
	HUDStyle.draw_gem(self, Vector2(center.x, top_y), 2.0, HUDStyle.RUBY)
	HUDStyle.draw_gem(self, Vector2(center.x + w * 0.32, top_y + 2.0), 1.6, HUDStyle.EMERALD)
