extends Node2D

## Persistent toxic pool spawned by the Plaguebearer. Ticks damage to the
## player while they stand inside.

@export var duration: float = 5.0
@export var radius: float = 110.0
@export var damage_per_tick: float = 9.0
@export var tick_interval: float = 0.5

var shooter: Node
var _pool: Polygon2D
var _bubble: Node2D
var _t: float = 0.0
var _next_tick: float = 0.3
var _telegraph: float = 0.6


func _ready() -> void:
	# Telegraph: starts faded, fills in over 0.6s, then becomes active.
	_pool = Polygon2D.new()
	_pool.color = Color(0.30, 0.95, 0.30, 0.15)
	_pool.polygon = _ellipse(Vector2.ZERO, radius, radius * 0.55, 28)
	add_child(_pool)
	# Inner bubbles
	_bubble = Node2D.new()
	add_child(_bubble)
	for i in range(7):
		var b := Polygon2D.new()
		b.color = Color(0.50, 1.0, 0.50, 0.6)
		var bx: float = randf_range(-radius * 0.6, radius * 0.6)
		var by: float = randf_range(-radius * 0.4, radius * 0.3)
		b.polygon = _circle(Vector2(bx, by), randf_range(6, 14), 12)
		_bubble.add_child(b)


func _process(delta: float) -> void:
	_t += delta
	if _t < _telegraph:
		if _pool:
			_pool.color.a = lerpf(0.15, 0.65, _t / _telegraph)
		return
	if _pool:
		_pool.color.a = 0.55 + sin(_t * 6.0) * 0.08
	# Damage tick
	if _t >= _next_tick:
		_next_tick = _t + tick_interval
		var tree := get_tree()
		if tree:
			for p in tree.get_nodes_in_group("revamp_player"):
				if p is Node2D and p.global_position.distance_to(global_position) <= radius:
					if p.has_method("take_damage"):
						p.take_damage(damage_per_tick, false)
	if _t >= duration:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		set_process(false)


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return arr


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr
