extends Control

## Five gem slots for Arcane Charges. Filled with glowing diamonds when
## present, dim runes when empty.

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

var _current: int = 0
var _max: int = 5
var _t: float = 0.0


func _ready() -> void:
	set_process(true)


func set_charges(current: int, maximum: int) -> void:
	_current = current
	_max = maximum
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var spacing: float = 36.0
	for i in range(_max):
		var center: Vector2 = Vector2(i * spacing + 18.0, size.y * 0.5)
		var lit: bool = i < _current
		var col: Color = HUDStyle.CHARGE_FILL if lit else Color(0.25, 0.30, 0.40)
		# Diamond
		var pts := PackedVector2Array([
			center + Vector2(0, -12),
			center + Vector2(10, 0),
			center + Vector2(0, 12),
			center + Vector2(-10, 0),
		])
		# Halo for lit
		if lit:
			draw_circle(center, 18.0 + sin(_t * 3.0 + i) * 2.0, Color(col.r, col.g, col.b, 0.4))
		draw_colored_polygon(pts, col)
		# Gold edge
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), HUDStyle.FRAME_GOLD, 1.5)
		# Inner glint when lit
		if lit:
			draw_line(center + Vector2(-3, -6), center + Vector2(3, -2), Color(1, 1, 1, 0.85), 1.5)
