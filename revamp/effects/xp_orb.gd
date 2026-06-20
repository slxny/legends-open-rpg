extends Node2D

## Floating XP orb that magnetizes to the revamp player after a brief settle,
## then disappears + tells the player it was picked up.

@export var value: int = 8

const SEEK_RADIUS := 280.0
const SPEED := 480.0

var _target: Node2D
var _vis: Polygon2D
var _t: float = 0.0
var _settle_until_ms: int = 0
var _settle_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	_vis = Polygon2D.new()
	_vis.color = Color(0.55, 0.95, 0.55, 0.95)
	_vis.polygon = _circle(Vector2.ZERO, 7.0, 14)
	add_child(_vis)
	var halo := Polygon2D.new()
	halo.color = Color(0.55, 0.95, 0.55, 0.35)
	halo.polygon = _circle(Vector2.ZERO, 14.0, 16)
	halo.z_index = -1
	add_child(halo)
	_settle_until_ms = Time.get_ticks_msec() + 400
	_settle_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 80.0
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if Time.get_ticks_msec() < _settle_until_ms:
		position += _settle_dir * delta
		_settle_dir = _settle_dir.lerp(Vector2.ZERO, delta * 4.0)
		return
	if not is_instance_valid(_target):
		var tree := get_tree()
		if tree:
			var players := tree.get_nodes_in_group("revamp_player")
			if players.size() > 0:
				_target = players[0]
	if is_instance_valid(_target):
		var d: Vector2 = _target.global_position - global_position
		var dist: float = d.length()
		if dist < 26.0:
			# Pickup
			if _target.has_method("gain_charge"):
				_target.gain_charge(0)  # no charge bonus; XP system stub
			queue_free()
			return
		var step: float = SPEED * delta * (1.0 + (1.0 - clampf(dist / SEEK_RADIUS, 0.0, 1.0)) * 2.0)
		position += d.normalized() * step


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr
