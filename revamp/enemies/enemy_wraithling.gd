extends "res://revamp/enemies/enemy_base.gd"

## SWARM: small wisp that hovers and lunges. Low HP, dies in one bolt.


func _ready() -> void:
	max_hp = 26.0
	damage = 9.0
	move_speed = 170.0
	attack_range = 36.0
	attack_cooldown = 1.0
	aggro_range = 620.0
	color_primary = Color(0.30, 0.20, 0.45)
	color_secondary = Color(0.08, 0.06, 0.14)
	glow_color = Color(0.55, 0.30, 1.0)
	family = &"wraith"
	xp_value = 8
	super._ready()


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Outer aura (back, dim)
	var aura := Polygon2D.new()
	aura.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.30)
	aura.polygon = _circle(Vector2(0, -4), 26.0, 22)
	aura.z_index = -3
	body.add_child(aura)
	# Inner aura ring (brighter)
	var aura_inner := Polygon2D.new()
	aura_inner.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.18)
	aura_inner.polygon = _circle(Vector2(0, -4), 16.0, 18)
	aura_inner.z_index = -2
	body.add_child(aura_inner)
	# Trailing wisp tail (deep shadow)
	var tail_shadow := Polygon2D.new()
	tail_shadow.color = Color(color_secondary.r, color_secondary.g, color_secondary.b, 0.70)
	tail_shadow.polygon = PackedVector2Array([
		Vector2(-6, 8), Vector2(6, 8), Vector2(10, 20), Vector2(0, 30), Vector2(-10, 20),
	])
	body.add_child(tail_shadow)
	# Trailing wisp tail
	var tail := Polygon2D.new()
	tail.color = Color(color_primary.r, color_primary.g, color_primary.b, 0.65)
	tail.polygon = PackedVector2Array([
		Vector2(-4, 8), Vector2(4, 8), Vector2(8, 18), Vector2(0, 26), Vector2(-8, 18),
	])
	body.add_child(tail)
	# Tail lit edge
	var tail_lit := Polygon2D.new()
	tail_lit.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.32)
	tail_lit.polygon = PackedVector2Array([
		Vector2(0, 8), Vector2(4, 8), Vector2(8, 18), Vector2(2, 24),
	])
	body.add_child(tail_lit)
	# Head SHADOW (slightly bigger, darker, behind)
	var head_shadow := Polygon2D.new()
	head_shadow.color = color_secondary
	head_shadow.polygon = PackedVector2Array([
		Vector2(-10, -17), Vector2(-13, -10), Vector2(-13, 1),
		Vector2(-7, 10), Vector2(7, 10), Vector2(13, 1),
		Vector2(13, -10), Vector2(10, -17),
	])
	body.add_child(head_shadow)
	# Head (skull-ish base)
	var head := Polygon2D.new()
	head.color = Color(0.78, 0.74, 0.70)
	head.polygon = PackedVector2Array([
		Vector2(-9, -16), Vector2(-12, -10), Vector2(-12, 0),
		Vector2(-6, 8), Vector2(6, 8), Vector2(12, 0),
		Vector2(12, -10), Vector2(9, -16),
	])
	body.add_child(head)
	# Head mid-tone (lit half on right)
	var head_mid := Polygon2D.new()
	head_mid.color = Color(0.92, 0.89, 0.84)
	head_mid.polygon = PackedVector2Array([
		Vector2(2, -16), Vector2(9, -16), Vector2(12, -10), Vector2(12, 0),
		Vector2(6, 8), Vector2(2, 8),
	])
	body.add_child(head_mid)
	# Cheek-bone shadow accents (sunken sockets)
	var socketL := Polygon2D.new()
	socketL.color = color_secondary
	socketL.polygon = PackedVector2Array([
		Vector2(-9, -9), Vector2(-2, -9), Vector2(-2, -3), Vector2(-9, -3),
	])
	body.add_child(socketL)
	var socketR := Polygon2D.new()
	socketR.color = color_secondary
	socketR.polygon = PackedVector2Array([
		Vector2(2, -9), Vector2(9, -9), Vector2(9, -3), Vector2(2, -3),
	])
	body.add_child(socketR)
	# Jaw teeth accent (3 tiny notches)
	var teeth := Polygon2D.new()
	teeth.color = Color(0.92, 0.89, 0.84)
	teeth.polygon = PackedVector2Array([
		Vector2(-4, 4), Vector2(-3, 7), Vector2(-2, 4),
		Vector2(-1, 7), Vector2(0, 4),
		Vector2(1, 7), Vector2(2, 4),
		Vector2(3, 7), Vector2(4, 4),
	])
	body.add_child(teeth)
	# Crown crack accent (vertical fracture line)
	var crack := Line2D.new()
	crack.width = 1.0
	crack.default_color = color_secondary
	crack.points = PackedVector2Array([Vector2(1, -16), Vector2(0, -10), Vector2(-1, -3)])
	body.add_child(crack)
	# Edge highlight along lit side
	var rim := Line2D.new()
	rim.width = 1.4
	rim.default_color = Color(1.0, 0.98, 0.94)
	rim.points = PackedVector2Array([Vector2(9, -16), Vector2(12, -10), Vector2(12, 0), Vector2(6, 8)])
	body.add_child(rim)
	# Eyes (slightly larger glow)
	var eyes := Polygon2D.new()
	eyes.color = glow_color
	eyes.polygon = PackedVector2Array([
		Vector2(-8, -9), Vector2(-2, -9), Vector2(-2, -3), Vector2(-8, -3),
		Vector2(2, -9), Vector2(8, -9), Vector2(8, -3), Vector2(2, -3),
	])
	body.add_child(eyes)
	# Eye bright cores (thin inner blaze)
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 1.0, 1.0, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-6, -8), Vector2(-4, -8), Vector2(-4, -5), Vector2(-6, -5),
		Vector2(4, -8), Vector2(6, -8), Vector2(6, -5), Vector2(4, -5),
	])
	body.add_child(eye_core)
