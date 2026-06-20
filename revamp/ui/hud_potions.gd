extends Control

## Potion vial row, one per remaining charge.

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

var _current: int = 0
var _max: int = 3


func set_count(current: int, maximum: int) -> void:
	_current = current
	_max = maximum
	queue_redraw()


func _draw() -> void:
	var spacing: float = 44.0
	for i in range(_max):
		var center: Vector2 = Vector2(i * spacing + 22.0, size.y * 0.5)
		var lit: bool = i < _current
		var col: Color = HUDStyle.POTION_FILL if lit else Color(0.25, 0.18, 0.20)
		# Vial outline
		var stem := PackedVector2Array([
			center + Vector2(-6, -14),
			center + Vector2(6, -14),
			center + Vector2(6, -10),
		])
		var body := PackedVector2Array([
			center + Vector2(-8, -10),
			center + Vector2(8, -10),
			center + Vector2(10, 10),
			center + Vector2(0, 16),
			center + Vector2(-10, 10),
		])
		draw_colored_polygon(body, col)
		draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[0]]), HUDStyle.FRAME_GOLD, 1.2)
		draw_colored_polygon(stem, Color(0.25, 0.18, 0.18))
		# Stopper
		draw_rect(Rect2(center + Vector2(-7, -18), Vector2(14, 6)), Color(0.55, 0.32, 0.18), true)
		if lit:
			draw_circle(center + Vector2(-3, 0), 2.0, Color(1, 1, 1, 0.7))
