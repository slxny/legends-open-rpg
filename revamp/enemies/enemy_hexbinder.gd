extends "res://revamp/enemies/enemy_base.gd"

## RANGED: keeps distance, throws curved hex bolts.

const HexBoltProjectile := preload("res://revamp/effects/projectile_hex_bolt.gd")


func _ready() -> void:
	max_hp = 56.0
	damage = 14.0
	move_speed = 95.0
	attack_range = 360.0
	attack_cooldown = 2.0
	aggro_range = 720.0
	color_primary = Color(0.20, 0.20, 0.46)
	color_secondary = Color(0.06, 0.06, 0.12)
	glow_color = Color(0.55, 0.85, 1.0)
	family = &"hexbinder"
	xp_value = 22
	super._ready()


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Robe SHADOW (deeper silhouette)
	var robe_shadow := Polygon2D.new()
	robe_shadow.color = color_secondary
	robe_shadow.polygon = PackedVector2Array([
		Vector2(-18, -27), Vector2(-24, 0), Vector2(-20, 26),
		Vector2(20, 26), Vector2(24, 0), Vector2(18, -27),
	])
	body.add_child(robe_shadow)
	# Long robe (base)
	var robe := Polygon2D.new()
	robe.color = color_primary
	robe.polygon = PackedVector2Array([
		Vector2(-16, -26), Vector2(-22, 0), Vector2(-18, 24),
		Vector2(18, 24), Vector2(22, 0), Vector2(16, -26),
	])
	body.add_child(robe)
	# Robe mid-tone (lit half)
	var robe_mid := Polygon2D.new()
	robe_mid.color = color_primary.lightened(0.18)
	robe_mid.polygon = PackedVector2Array([
		Vector2(-2, -25), Vector2(-6, 0), Vector2(-3, 24),
		Vector2(18, 24), Vector2(22, 0), Vector2(16, -25),
	])
	body.add_child(robe_mid)
	# Robe folds (3 vertical ribs)
	var fold1 := Polygon2D.new()
	fold1.color = color_primary.lightened(0.34)
	fold1.polygon = PackedVector2Array([Vector2(7, -22), Vector2(10, 0), Vector2(8, 22), Vector2(5, 0)])
	body.add_child(fold1)
	var fold2 := Polygon2D.new()
	fold2.color = color_primary.lightened(0.34)
	fold2.polygon = PackedVector2Array([Vector2(14, -22), Vector2(16, 0), Vector2(14, 22), Vector2(12, 0)])
	body.add_child(fold2)
	var fold3 := Polygon2D.new()
	fold3.color = color_primary.darkened(0.22)
	fold3.polygon = PackedVector2Array([Vector2(-8, -22), Vector2(-11, 0), Vector2(-9, 22), Vector2(-6, 0)])
	body.add_child(fold3)
	# Robe edge highlight (lit rim)
	var robe_rim := Line2D.new()
	robe_rim.width = 1.4
	robe_rim.default_color = color_primary.lightened(0.5)
	robe_rim.points = PackedVector2Array([Vector2(16, -26), Vector2(22, 0), Vector2(18, 24)])
	body.add_child(robe_rim)
	# Hood SHADOW (deeper silhouette behind)
	var hood_shadow := Polygon2D.new()
	hood_shadow.color = Color(0.02, 0.02, 0.06)
	hood_shadow.polygon = PackedVector2Array([
		Vector2(-13, -51), Vector2(-16, -26), Vector2(16, -26), Vector2(13, -51),
		Vector2(0, -58),
	])
	body.add_child(hood_shadow)
	# Tall hood
	var hood := Polygon2D.new()
	hood.color = color_secondary
	hood.polygon = PackedVector2Array([
		Vector2(-12, -50), Vector2(-15, -26), Vector2(15, -26), Vector2(12, -50),
		Vector2(0, -56),
	])
	body.add_child(hood)
	# Hood mid-tone (lit side)
	var hood_mid := Polygon2D.new()
	hood_mid.color = color_secondary.lightened(0.20)
	hood_mid.polygon = PackedVector2Array([
		Vector2(0, -56), Vector2(12, -50), Vector2(15, -26), Vector2(2, -26),
	])
	body.add_child(hood_mid)
	# Glyph accent on hood front (small star sigil)
	# Use a slightly off color so _on_windup_begin still pulses the ORB (which keeps glow_color).
	var glyph := Polygon2D.new()
	glyph.color = Color(glow_color.r * 0.95, glow_color.g * 0.95, glow_color.b * 0.99, 0.95)
	glyph.polygon = PackedVector2Array([
		Vector2(-3, -48), Vector2(0, -54), Vector2(3, -48),
		Vector2(5, -45), Vector2(0, -42), Vector2(-5, -45),
	])
	body.add_child(glyph)
	# Glyph dim halo
	var glyph_halo := Polygon2D.new()
	glyph_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.30)
	glyph_halo.polygon = _circle(Vector2(0, -47), 8.0, 14)
	body.add_child(glyph_halo)
	# Hood rim highlight
	var hood_rim := Line2D.new()
	hood_rim.width = 1.3
	hood_rim.default_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.55)
	hood_rim.points = PackedVector2Array([Vector2(0, -56), Vector2(12, -50), Vector2(15, -26)])
	body.add_child(hood_rim)
	# Face shadow inside hood
	var face_shadow := Polygon2D.new()
	face_shadow.color = Color(0.02, 0.02, 0.05)
	face_shadow.polygon = PackedVector2Array([
		Vector2(-9, -40), Vector2(-12, -28), Vector2(12, -28), Vector2(9, -40),
	])
	body.add_child(face_shadow)
	# Robe sash/belt accent
	var sash := Polygon2D.new()
	sash.color = Color(0.55, 0.45, 0.18)
	sash.polygon = PackedVector2Array([Vector2(-18, -4), Vector2(18, -4), Vector2(16, 2), Vector2(-16, 2)])
	body.add_child(sash)
	# Eyes halo
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.40)
	eye_halo.polygon = _circle(Vector2(0, -34), 8.0, 14)
	body.add_child(eye_halo)
	# Eyes (slightly detuned color so _on_windup_begin pulses the ORB, not these)
	var eyes := Polygon2D.new()
	eyes.color = Color(glow_color.r * 0.95, glow_color.g * 0.97, glow_color.b * 0.99, 1.0)
	eyes.polygon = PackedVector2Array([
		Vector2(-7, -37), Vector2(-2, -37), Vector2(-2, -31), Vector2(-7, -31),
		Vector2(2, -37), Vector2(7, -37), Vector2(7, -31), Vector2(2, -31),
	])
	body.add_child(eyes)
	# Eye bright cores
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 1.0, 1.0, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-6, -36), Vector2(-3, -36), Vector2(-3, -33), Vector2(-6, -33),
		Vector2(3, -36), Vector2(6, -36), Vector2(6, -33), Vector2(3, -33),
	])
	body.add_child(eye_core)
	# Orb back halo (large dim)
	var orb_halo := Polygon2D.new()
	orb_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	orb_halo.polygon = _circle(Vector2(22, -8), 14.0, 18)
	body.add_child(orb_halo)
	# Floating orb in hand  (NOTE: this MUST stay first poly with .color == glow_color
	# beyond eyes since _on_windup_begin pulses the first such match. Eyes are now
	# children too, so they would scale first — we explicitly keep orb after but add
	# a meta to find it via fallback. Both pulsing is fine visually.)
	var orb := Polygon2D.new()
	orb.color = glow_color
	orb.polygon = _circle(Vector2(22, -8), 8.0, 16)
	body.add_child(orb)
	# Orb bright inner core
	var orb_core := Polygon2D.new()
	orb_core.color = Color(1.0, 1.0, 1.0, 0.85)
	orb_core.polygon = _circle(Vector2(20, -10), 3.0, 12)
	body.add_child(orb_core)
	# Orb hand-holder (small dark grip accent)
	var grip := Polygon2D.new()
	grip.color = color_secondary
	grip.polygon = PackedVector2Array([
		Vector2(16, -2), Vector2(22, -4), Vector2(24, 4), Vector2(18, 6),
	])
	body.add_child(grip)


func _pursue_logic(dist: float) -> void:
	# Kiting: stay near max range
	var to_target: Vector2 = (target.global_position - global_position)
	var ideal: float = attack_range * 0.85
	var move_dir: Vector2 = to_target.normalized()
	if dist < ideal - 60.0:
		move_dir = -move_dir
	var sep: Vector2 = _separation_offset()
	velocity = (move_dir + sep).normalized() * move_speed
	_aim = to_target.normalized()


func windup_seconds() -> float:
	return 0.7  # visible cast


func _on_windup_begin() -> void:
	# Telegraphic glow flash on the orb
	var body: Node = get_node_or_null("Body")
	if body:
		for child in body.get_children():
			if child is Polygon2D and (child as Polygon2D).color == glow_color:
				var tw := create_tween()
				tw.tween_property(child, "scale", Vector2(1.8, 1.8), 0.6)
				tw.tween_property(child, "scale", Vector2(1.0, 1.0), 0.1)
				break


func _release_attack() -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var proj := HexBoltProjectile.new()
	proj.global_position = global_position + Vector2(0, -8)
	proj.set_aim(dir)
	proj.damage = damage
	proj.shooter = self
	get_parent().add_child(proj)


func get_resistance(damage_type: StringName) -> float:
	# Hexbinders take extra physical damage but resist arcane.
	match damage_type:
		&"arcane":
			return 0.7
		&"physical":
			return 1.25
		_:
			return 1.0
