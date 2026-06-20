extends Area2D

## Slow curving dark bolt thrown by hexbinders. Hits the revamp player only.

const SPEED := 360.0
const LIFETIME := 3.0

@export var damage: float = 14.0
var shooter: Node
var _dir: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _ghost: Polygon2D
var _trail: Line2D


func set_aim(d: Vector2) -> void:
	_dir = d.normalized()


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1  # player
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	shape.shape = circ
	add_child(shape)
	body_entered.connect(_on_body)
	_ghost = Polygon2D.new()
	_ghost.color = Color(0.45, 0.30, 0.85, 0.92)
	_ghost.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(0, 8), Vector2(-10, 4),
		Vector2(-12, 0), Vector2(-10, -4), Vector2(0, -8),
	])
	add_child(_ghost)
	var glow := Polygon2D.new()
	glow.color = Color(0.55, 0.40, 1.0, 0.35)
	glow.polygon = _circle(Vector2.ZERO, 18.0, 16)
	glow.z_index = -1
	add_child(glow)
	_trail = Line2D.new()
	_trail.width = 4.5
	_trail.default_color = Color(0.45, 0.30, 0.85, 0.65)
	_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-30, 0)])
	_trail.z_index = -2
	add_child(_trail)
	rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return
	position += _dir * SPEED * delta


func _on_body(body: Node) -> void:
	if body.is_in_group("revamp_player") and body.has_method("take_damage"):
		body.take_damage(damage, false)
		queue_free()


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr
