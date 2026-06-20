extends Node2D

## Inert by default; pulses violently when the boss spawns. Set active(true)
## via the encounter director.

var _active: bool = false
var _t: float = 0.0
var _ring: Polygon2D
var _bolts: Line2D


func _ready() -> void:
	_ring = Polygon2D.new()
	_ring.color = Color(0.45, 0.25, 1.0, 0.0)
	_ring.polygon = _ring_poly(Vector2.ZERO, 220.0, 240.0, 64)
	add_child(_ring)


func set_active(on: bool) -> void:
	_active = on


func _process(delta: float) -> void:
	_t += delta
	if not _ring:
		return
	if _active:
		var pulse: float = 0.55 + 0.35 * sin(_t * 4.0)
		_ring.color = Color(0.55, 0.25, 1.0, pulse)
	else:
		_ring.color.a = lerpf(_ring.color.a, 0.0, clampf(delta * 4.0, 0.0, 1.0))


func _ring_poly(c: Vector2, inner: float, outer: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * outer, sin(a) * outer * 0.55))
	for i in range(n - 1, -1, -1):
		var a2: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a2) * inner, sin(a2) * inner * 0.55))
	return arr
