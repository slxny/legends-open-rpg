extends "res://revamp/enemies/enemy_base.gd"

## STANDARD MELEE: robed cultist with curved dagger.


func _ready() -> void:
	max_hp = 78.0
	damage = 16.0
	move_speed = 130.0
	attack_range = 56.0
	attack_cooldown = 1.6
	aggro_range = 520.0
	color_primary = Color(0.38, 0.10, 0.18)
	color_secondary = Color(0.10, 0.04, 0.08)
	glow_color = Color(1.0, 0.4, 0.3)
	family = &"cultist"
	xp_value = 18
	super._ready()


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Robe SHADOW (deeper silhouette behind body for depth)
	var robe_shadow := Polygon2D.new()
	robe_shadow.color = color_secondary
	robe_shadow.polygon = PackedVector2Array([
		Vector2(-16, -23), Vector2(-22, 0), Vector2(-18, 24),
		Vector2(18, 24), Vector2(22, 0), Vector2(16, -23),
	])
	body.add_child(robe_shadow)
	# Robe base
	var robe := Polygon2D.new()
	robe.color = color_primary
	robe.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(-20, 0), Vector2(-16, 22),
		Vector2(16, 22), Vector2(20, 0), Vector2(14, -22),
	])
	body.add_child(robe)
	# Robe mid-tone (lit half on right side)
	var robe_mid := Polygon2D.new()
	robe_mid.color = color_primary.lightened(0.18)
	robe_mid.polygon = PackedVector2Array([
		Vector2(-2, -21), Vector2(-6, 0), Vector2(-3, 22),
		Vector2(16, 22), Vector2(20, 0), Vector2(14, -21),
	])
	body.add_child(robe_mid)
	# Robe fold highlight strips (3 cloth ribs)
	var fold1 := Polygon2D.new()
	fold1.color = color_primary.lightened(0.32)
	fold1.polygon = PackedVector2Array([Vector2(6, -16), Vector2(8, 0), Vector2(6, 18), Vector2(4, 0)])
	body.add_child(fold1)
	var fold2 := Polygon2D.new()
	fold2.color = color_primary.lightened(0.32)
	fold2.polygon = PackedVector2Array([Vector2(12, -16), Vector2(14, 0), Vector2(13, 18), Vector2(11, 0)])
	body.add_child(fold2)
	var fold3 := Polygon2D.new()
	fold3.color = color_primary.darkened(0.22)
	fold3.polygon = PackedVector2Array([Vector2(-8, -16), Vector2(-11, 0), Vector2(-9, 18), Vector2(-6, 0)])
	body.add_child(fold3)
	# Tattered robe hem (accent jagged bottom)
	var hem := Polygon2D.new()
	hem.color = color_secondary
	hem.polygon = PackedVector2Array([
		Vector2(-16, 20), Vector2(-12, 26), Vector2(-8, 22),
		Vector2(-4, 28), Vector2(0, 22), Vector2(4, 26),
		Vector2(8, 22), Vector2(12, 28), Vector2(16, 22),
	])
	body.add_child(hem)
	# Robe edge highlight (lit rim line)
	var robe_rim := Line2D.new()
	robe_rim.width = 1.4
	robe_rim.default_color = color_primary.lightened(0.45)
	robe_rim.points = PackedVector2Array([Vector2(14, -22), Vector2(20, 0), Vector2(16, 22)])
	body.add_child(robe_rim)
	# Hood shadow (back darker layer)
	var hood_shadow := Polygon2D.new()
	hood_shadow.color = Color(0.04, 0.02, 0.04)
	hood_shadow.polygon = PackedVector2Array([
		Vector2(-13, -35), Vector2(-16, -22), Vector2(16, -22), Vector2(13, -35),
		Vector2(7, -40), Vector2(-7, -40),
	])
	body.add_child(hood_shadow)
	# Hood
	var hood := Polygon2D.new()
	hood.color = color_secondary
	hood.polygon = PackedVector2Array([
		Vector2(-12, -34), Vector2(-15, -22), Vector2(15, -22), Vector2(12, -34),
		Vector2(6, -38), Vector2(-6, -38),
	])
	body.add_child(hood)
	# Hood mid (lit side)
	var hood_mid := Polygon2D.new()
	hood_mid.color = color_secondary.lightened(0.18)
	hood_mid.polygon = PackedVector2Array([
		Vector2(0, -38), Vector2(6, -38), Vector2(12, -34), Vector2(15, -22),
		Vector2(2, -22),
	])
	body.add_child(hood_mid)
	# Hood rim highlight (lit edge)
	var hood_rim := Line2D.new()
	hood_rim.width = 1.2
	hood_rim.default_color = color_primary.lightened(0.45)
	hood_rim.points = PackedVector2Array([Vector2(-6, -38), Vector2(6, -38), Vector2(12, -34)])
	body.add_child(hood_rim)
	# Face shadow inside hood
	var face_shadow := Polygon2D.new()
	face_shadow.color = Color(0.04, 0.02, 0.04)
	face_shadow.polygon = PackedVector2Array([
		Vector2(-9, -30), Vector2(-12, -23), Vector2(12, -23), Vector2(9, -30),
	])
	body.add_child(face_shadow)
	# Glowing eye slit (larger halo behind)
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	eye_halo.polygon = _circle(Vector2(0, -26), 9.0, 14)
	body.add_child(eye_halo)
	# Glowing eye slit
	var eyes := Polygon2D.new()
	eyes.color = glow_color
	eyes.polygon = PackedVector2Array([
		Vector2(-8, -29), Vector2(-2, -29), Vector2(-2, -24), Vector2(-8, -24),
		Vector2(2, -29), Vector2(8, -29), Vector2(8, -24), Vector2(2, -24),
	])
	body.add_child(eyes)
	# Eye bright core
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 0.95, 0.85, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-7, -28), Vector2(-3, -28), Vector2(-3, -25), Vector2(-7, -25),
		Vector2(3, -28), Vector2(7, -28), Vector2(7, -25), Vector2(3, -25),
	])
	body.add_child(eye_core)
	# Belt sash (with shadow underline)
	var sash_shadow := Polygon2D.new()
	sash_shadow.color = Color(0.55, 0.36, 0.10)
	sash_shadow.polygon = PackedVector2Array([Vector2(-16, 4), Vector2(16, 4), Vector2(14, 6), Vector2(-14, 6)])
	body.add_child(sash_shadow)
	var sash := Polygon2D.new()
	sash.color = Color(0.95, 0.75, 0.30)
	sash.polygon = PackedVector2Array([Vector2(-16, -2), Vector2(16, -2), Vector2(14, 4), Vector2(-14, 4)])
	body.add_child(sash)
	# Belt buckle (accent)
	var buckle := Polygon2D.new()
	buckle.color = Color(1.0, 0.86, 0.42)
	buckle.polygon = PackedVector2Array([
		Vector2(-4, -3), Vector2(4, -3), Vector2(5, 3), Vector2(-5, 3),
	])
	body.add_child(buckle)
	var buckle_gem := Polygon2D.new()
	buckle_gem.color = glow_color
	buckle_gem.polygon = PackedVector2Array([
		Vector2(-2, -1), Vector2(2, -1), Vector2(0, 2),
	])
	body.add_child(buckle_gem)
	# Dagger (with darker back-edge)
	var dagger_back := Line2D.new()
	dagger_back.width = 4.5
	dagger_back.default_color = Color(0.45, 0.45, 0.50)
	dagger_back.points = PackedVector2Array([Vector2(18, 6), Vector2(34, -10)])
	body.add_child(dagger_back)
	var dagger := Line2D.new()
	dagger.width = 3.0
	dagger.default_color = Color(0.92, 0.92, 0.96)
	dagger.points = PackedVector2Array([Vector2(18, 6), Vector2(34, -10)])
	body.add_child(dagger)
	# Dagger hilt (small accent quad)
	var hilt := Polygon2D.new()
	hilt.color = Color(0.42, 0.22, 0.10)
	hilt.polygon = PackedVector2Array([
		Vector2(14, 10), Vector2(20, 4), Vector2(22, 6), Vector2(16, 12),
	])
	body.add_child(hilt)
	# Dagger blade lit edge
	var blade_edge := Line2D.new()
	blade_edge.width = 1.0
	blade_edge.default_color = Color(1.0, 1.0, 0.95, 0.9)
	blade_edge.points = PackedVector2Array([Vector2(20, 3), Vector2(33, -9)])
	body.add_child(blade_edge)
