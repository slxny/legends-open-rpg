extends Node2D

## Foreground edges — soft vignette wedges at top + bottom that give the
## camera frame a sense of physical edges without dominating the screen.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))


func _ready() -> void:
	_top_wedge()
	_bottom_wedge()


func _top_wedge() -> void:
	var canopy := Polygon2D.new()
	canopy.color = Color(0.04, 0.03, 0.07, 0.65)
	var pts: PackedVector2Array = PackedVector2Array()
	var x0: float = world_bounds.position.x - 200.0
	var x1: float = world_bounds.end.x + 200.0
	var y_top: float = world_bounds.position.y - 60.0
	pts.append(Vector2(x0, y_top - 300.0))
	pts.append(Vector2(x1, y_top - 300.0))
	var x: float = x1
	while x > x0:
		# Subtle scalloped edge
		var bumps: float = sin(x * 0.005) * 8.0 + sin(x * 0.018) * 6.0
		pts.append(Vector2(x, y_top + bumps - 40.0))
		x -= 80.0
	canopy.polygon = pts
	add_child(canopy)


func _bottom_wedge() -> void:
	var cliff := Polygon2D.new()
	cliff.color = Color(0.03, 0.03, 0.06, 0.75)
	var pts: PackedVector2Array = PackedVector2Array()
	var x0: float = world_bounds.position.x - 200.0
	var x1: float = world_bounds.end.x + 200.0
	var y_bot: float = world_bounds.end.y - 40.0
	pts.append(Vector2(x0, y_bot + 300.0))
	pts.append(Vector2(x1, y_bot + 300.0))
	var x: float = x1
	while x > x0:
		var bumps: float = sin(x * 0.0042) * 10.0 + cos(x * 0.013) * 8.0
		pts.append(Vector2(x, y_bot - bumps))
		x -= 80.0
	cliff.polygon = pts
	add_child(cliff)
