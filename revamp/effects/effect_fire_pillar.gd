extends Node2D

## Pillar of fire: ground telegraph -> erupts upward -> burst damage.

@export var delay: float = 0.9
@export var damage: float = 36.0
@export var radius: float = 100.0

var shooter: Node
var _teleg: Polygon2D
var _flame: Polygon2D
var _t: float = 0.0
var _erupted: bool = false


func _ready() -> void:
	_teleg = Polygon2D.new()
	_teleg.color = Color(1.0, 0.4, 0.15, 0.55)
	_teleg.polygon = _ellipse(Vector2.ZERO, radius, radius * 0.55, 24)
	add_child(_teleg)


func _process(delta: float) -> void:
	_t += delta
	if not _erupted and _t >= delay:
		_erupt()


func _erupt() -> void:
	_erupted = true
	_flame = Polygon2D.new()
	_flame.color = Color(1.0, 0.6, 0.15, 0.92)
	_flame.polygon = PackedVector2Array([
		Vector2(-30, 0), Vector2(-50, -80), Vector2(-30, -180),
		Vector2(0, -260), Vector2(30, -180), Vector2(50, -80), Vector2(30, 0),
	])
	add_child(_flame)
	var tw := create_tween()
	tw.tween_property(_flame, "color:a", 0.0, 0.55)
	tw.parallel().tween_property(_teleg, "color:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
	# Damage
	var tree := get_tree()
	if tree:
		for p in tree.get_nodes_in_group("revamp_player"):
			if p is Node2D and p.global_position.distance_to(global_position) <= radius:
				if p.has_method("take_damage"):
					p.take_damage(damage, false)


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return arr
