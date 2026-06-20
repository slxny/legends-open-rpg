extends Area2D

## A floating crystal that restores HP + saves on touch. Also serves as
## respawn anchor.

signal player_rested

const HEAL_PERCENT := 1.0
const TOUCH_RADIUS := 80.0

var _crystal: Polygon2D
var _glow: Polygon2D
var _t: float = 0.0
var _rest_cooldown_ms: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TOUCH_RADIUS
	shape.shape = circle
	add_child(shape)
	# Pedestal
	var ped := Polygon2D.new()
	ped.color = Color(0.10, 0.10, 0.18)
	ped.polygon = PackedVector2Array([
		Vector2(-45, 0), Vector2(-32, -16), Vector2(32, -16), Vector2(45, 0),
		Vector2(36, 14), Vector2(-36, 14),
	])
	add_child(ped)
	# Crystal
	_crystal = Polygon2D.new()
	_crystal.color = Color(0.55, 0.90, 1.0, 0.95)
	_crystal.polygon = PackedVector2Array([
		Vector2(0, -68), Vector2(20, -42), Vector2(14, -18),
		Vector2(-14, -18), Vector2(-20, -42),
	])
	add_child(_crystal)
	# Glow halo
	_glow = Polygon2D.new()
	_glow.color = Color(0.55, 0.90, 1.0, 0.35)
	_glow.polygon = _circle_poly(Vector2(0, -42), 70.0, 24)
	_glow.z_index = -1
	add_child(_glow)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.rotation = sin(_t * 0.8) * 0.08
		_crystal.position.y = -2 + sin(_t * 1.4) * 4.0
	if _glow:
		_glow.scale = Vector2.ONE * (1.0 + sin(_t * 1.7) * 0.08)


func _on_body(body: Node) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _rest_cooldown_ms < 5000:
		return
	_rest_cooldown_ms = now
	if body.has_method("heal_full"):
		body.heal_full()
	player_rested.emit()
	# Brief shrine flash
	if _glow:
		_glow.color = Color(0.95, 0.95, 0.65, 0.85)
		var tw := create_tween()
		tw.tween_property(_glow, "color", Color(0.55, 0.90, 1.0, 0.35), 0.8)


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55))
	return arr
