extends Area2D

## Boss's fire bolt — straight projectile, hits player.

const SPEED := 420.0
const LIFETIME := 3.0

@export var damage: float = 18.0
var shooter: Node
var _dir: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _t: float = 0.0


func set_aim(d: Vector2) -> void:
	_dir = d.normalized()


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	shape.shape = circ
	add_child(shape)
	body_entered.connect(_on_body)
	var head := Polygon2D.new()
	head.color = Color(1.0, 0.55, 0.20)
	head.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(0, 8), Vector2(-10, 4),
		Vector2(-12, 0), Vector2(-10, -4), Vector2(0, -8),
	])
	add_child(head)
	var glow := Polygon2D.new()
	glow.color = Color(1.0, 0.65, 0.25, 0.45)
	glow.polygon = _circle(Vector2.ZERO, 22.0, 16)
	glow.z_index = -1
	add_child(glow)
	var trail := Line2D.new()
	trail.width = 6.0
	trail.default_color = Color(1.0, 0.4, 0.1, 0.85)
	trail.points = PackedVector2Array([Vector2(0, 0), Vector2(-32, 0)])
	trail.z_index = -2
	add_child(trail)
	rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	_life += delta
	_t += delta
	if _life > LIFETIME:
		queue_free()
		return
	position += _dir * SPEED * delta
	scale = Vector2.ONE * (1.0 + sin(_t * 22.0) * 0.08)


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
