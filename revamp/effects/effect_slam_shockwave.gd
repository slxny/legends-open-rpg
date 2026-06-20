extends Node2D

## Ground shockwave for the Tombwarden's slam. Damages the player if inside
## radius at the moment of impact.

@export var radius: float = 140.0
@export var damage: float = 28.0

var shooter: Node
var _ring: Polygon2D
var _crack: Line2D
var _t: float = 0.0


func _ready() -> void:
	_ring = Polygon2D.new()
	_ring.color = Color(0.95, 0.55, 0.30, 0.85)
	_ring.polygon = _ellipse(Vector2.ZERO, 20.0, 10.0, 24)
	add_child(_ring)
	_crack = Line2D.new()
	_crack.width = 4.0
	_crack.default_color = Color(0.95, 0.45, 0.20, 0.85)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2.ZERO)
	var ang: float = 0.0
	while ang < TAU:
		var r: float = radius * randf_range(0.6, 1.0)
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.55))
		pts.append(Vector2.ZERO)
		ang += PI / 5.0
	_crack.points = pts
	add_child(_crack)
	# Damage check now
	_apply_damage()


func _apply_damage() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for p in tree.get_nodes_in_group("revamp_player"):
		if p is Node2D and p.global_position.distance_to(global_position) <= radius:
			if p.has_method("take_damage"):
				p.take_damage(damage, false)


func _process(delta: float) -> void:
	_t += delta
	if _ring:
		var s: float = lerpf(0.05, 1.0, clampf(_t / 0.35, 0.0, 1.0))
		_ring.scale = Vector2(s * (radius / 20.0), s * (radius / 20.0))
		_ring.color.a = lerpf(0.85, 0.0, clampf(_t / 0.6, 0.0, 1.0))
	if _crack:
		_crack.default_color.a = lerpf(0.85, 0.0, clampf(_t / 0.55, 0.0, 1.0))
	if _t > 0.7:
		queue_free()


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return arr
