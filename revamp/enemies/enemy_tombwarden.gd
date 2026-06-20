extends "res://revamp/enemies/enemy_base.gd"

## HEAVY: slow, telegraphed slam with ground-crack AOE.

const SlamShockwave := preload("res://revamp/effects/effect_slam_shockwave.gd")


func _ready() -> void:
	max_hp = 220.0
	damage = 28.0
	move_speed = 78.0
	attack_range = 80.0
	attack_cooldown = 2.4
	aggro_range = 600.0
	color_primary = Color(0.34, 0.30, 0.42)
	color_secondary = Color(0.12, 0.10, 0.18)
	glow_color = Color(0.95, 0.55, 0.30)
	family = &"tombwarden"
	xp_value = 45
	super._ready()


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Torso SHADOW (deeper silhouette behind)
	var torso_shadow := Polygon2D.new()
	torso_shadow.color = color_secondary
	torso_shadow.polygon = PackedVector2Array([
		Vector2(-28, -33), Vector2(-34, -10), Vector2(-28, 26),
		Vector2(28, 26), Vector2(34, -10), Vector2(28, -33),
	])
	body.add_child(torso_shadow)
	# Stone body (base)
	var torso := Polygon2D.new()
	torso.color = color_primary
	torso.polygon = PackedVector2Array([
		Vector2(-26, -32), Vector2(-32, -10), Vector2(-26, 24),
		Vector2(26, 24), Vector2(32, -10), Vector2(26, -32),
	])
	body.add_child(torso)
	# Torso mid-tone (lit right half)
	var torso_mid := Polygon2D.new()
	torso_mid.color = color_primary.lightened(0.15)
	torso_mid.polygon = PackedVector2Array([
		Vector2(-2, -31), Vector2(-6, -10), Vector2(-2, 24),
		Vector2(26, 24), Vector2(32, -10), Vector2(26, -31),
	])
	body.add_child(torso_mid)
	# Stone plate-segment accents (3 horizontal bands)
	var plate1 := Polygon2D.new()
	plate1.color = color_primary.darkened(0.18)
	plate1.polygon = PackedVector2Array([
		Vector2(-28, -16), Vector2(28, -16), Vector2(27, -12), Vector2(-27, -12),
	])
	body.add_child(plate1)
	var plate2 := Polygon2D.new()
	plate2.color = color_primary.darkened(0.18)
	plate2.polygon = PackedVector2Array([
		Vector2(-28, 4), Vector2(28, 4), Vector2(27, 8), Vector2(-27, 8),
	])
	body.add_child(plate2)
	# Highlight ridge along top of torso (lit upper edge)
	var ridge := Polygon2D.new()
	ridge.color = color_primary.lightened(0.30)
	ridge.polygon = PackedVector2Array([
		Vector2(-26, -32), Vector2(26, -32), Vector2(22, -28), Vector2(-22, -28),
	])
	body.add_child(ridge)
	# Chest cracks accent (extra fracture lines)
	var crack_extra := Line2D.new()
	crack_extra.width = 1.4
	crack_extra.default_color = color_secondary
	crack_extra.points = PackedVector2Array([
		Vector2(-20, -4), Vector2(-14, 2), Vector2(-8, 10),
	])
	body.add_child(crack_extra)
	var crack_extra2 := Line2D.new()
	crack_extra2.width = 1.4
	crack_extra2.default_color = color_secondary
	crack_extra2.points = PackedVector2Array([
		Vector2(15, -28), Vector2(20, -22), Vector2(24, -14),
	])
	body.add_child(crack_extra2)
	# Cracks (glowing — the original primary crack)
	var crack := Line2D.new()
	crack.width = 2.5
	crack.default_color = glow_color
	crack.points = PackedVector2Array([
		Vector2(-12, -22), Vector2(-6, -10), Vector2(0, 4),
		Vector2(6, -2), Vector2(10, 16),
	])
	body.add_child(crack)
	# Crack inner bright core (thin)
	var crack_core := Line2D.new()
	crack_core.width = 1.0
	crack_core.default_color = Color(1.0, 0.92, 0.75, 0.95)
	crack_core.points = PackedVector2Array([
		Vector2(-12, -22), Vector2(-6, -10), Vector2(0, 4),
		Vector2(6, -2), Vector2(10, 16),
	])
	body.add_child(crack_core)
	# Torso lit rim
	var torso_rim := Line2D.new()
	torso_rim.width = 1.6
	torso_rim.default_color = color_primary.lightened(0.40)
	torso_rim.points = PackedVector2Array([Vector2(26, -32), Vector2(32, -10), Vector2(26, 24)])
	body.add_child(torso_rim)
	# Head shadow
	var head_shadow := Polygon2D.new()
	head_shadow.color = Color(0.04, 0.03, 0.06)
	head_shadow.polygon = PackedVector2Array([
		Vector2(-15, -51), Vector2(-19, -34), Vector2(-15, -27), Vector2(15, -27),
		Vector2(19, -34), Vector2(15, -51),
	])
	body.add_child(head_shadow)
	# Head
	var head := Polygon2D.new()
	head.color = color_secondary
	head.polygon = PackedVector2Array([
		Vector2(-14, -50), Vector2(-18, -34), Vector2(-14, -28), Vector2(14, -28),
		Vector2(18, -34), Vector2(14, -50),
	])
	body.add_child(head)
	# Head mid-tone (lit half)
	var head_mid := Polygon2D.new()
	head_mid.color = color_secondary.lightened(0.22)
	head_mid.polygon = PackedVector2Array([
		Vector2(0, -50), Vector2(14, -50), Vector2(18, -34), Vector2(14, -28),
		Vector2(0, -28),
	])
	body.add_child(head_mid)
	# Head rim highlight
	var head_rim := Line2D.new()
	head_rim.width = 1.2
	head_rim.default_color = color_primary.lightened(0.30)
	head_rim.points = PackedVector2Array([Vector2(-14, -50), Vector2(14, -50), Vector2(18, -34)])
	body.add_child(head_rim)
	# Eye slit halo (back glow)
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	eye_halo.polygon = _ellipse(Vector2(0, -39), 14.0, 6.0, 18)
	body.add_child(eye_halo)
	# Glowing eye slit
	var eye := Polygon2D.new()
	eye.color = glow_color
	eye.polygon = PackedVector2Array([
		Vector2(-10, -42), Vector2(10, -42), Vector2(10, -36), Vector2(-10, -36),
	])
	body.add_child(eye)
	# Eye bright core (thin inner pip)
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 0.95, 0.70, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-8, -41), Vector2(8, -41), Vector2(8, -37), Vector2(-8, -37),
	])
	body.add_child(eye_core)
	# Maul shadow
	var maul_shadow := Polygon2D.new()
	maul_shadow.color = Color(0.02, 0.02, 0.04)
	maul_shadow.polygon = PackedVector2Array([
		Vector2(32, 16), Vector2(32, -18), Vector2(58, -24), Vector2(58, 22),
	])
	body.add_child(maul_shadow)
	# Maul
	var maul := Polygon2D.new()
	maul.color = color_secondary
	maul.polygon = PackedVector2Array([
		Vector2(30, 14), Vector2(30, -16), Vector2(56, -22), Vector2(56, 20),
	])
	body.add_child(maul)
	# Maul lit face (mid-tone)
	var maul_mid := Polygon2D.new()
	maul_mid.color = color_primary.lightened(0.10)
	maul_mid.polygon = PackedVector2Array([
		Vector2(30, -2), Vector2(30, -16), Vector2(56, -22), Vector2(56, -8),
	])
	body.add_child(maul_mid)
	# Maul rune accent (glowing band)
	var maul_rune := Polygon2D.new()
	maul_rune.color = glow_color
	maul_rune.polygon = PackedVector2Array([
		Vector2(38, -3), Vector2(50, -5), Vector2(50, 3), Vector2(38, 5),
	])
	body.add_child(maul_rune)
	# Maul edge highlight
	var maul_edge := Line2D.new()
	maul_edge.width = 1.2
	maul_edge.default_color = color_primary.lightened(0.45)
	maul_edge.points = PackedVector2Array([Vector2(30, -16), Vector2(56, -22)])
	body.add_child(maul_edge)
	# Maul rod
	var maulrod := Line2D.new()
	maulrod.width = 5.0
	maulrod.default_color = Color(0.20, 0.14, 0.10)
	maulrod.points = PackedVector2Array([Vector2(28, 18), Vector2(20, 26)])
	body.add_child(maulrod)
	# Maul rod highlight
	var maulrod_hi := Line2D.new()
	maulrod_hi.width = 2.0
	maulrod_hi.default_color = Color(0.40, 0.28, 0.18)
	maulrod_hi.points = PackedVector2Array([Vector2(28, 18), Vector2(20, 26)])
	maulrod_hi.position = Vector2(-1, 0)
	body.add_child(maulrod_hi)


func windup_seconds() -> float:
	return 0.9


func _on_windup_begin() -> void:
	# Show ground telegraph circle
	var teleg := Polygon2D.new()
	teleg.color = Color(0.95, 0.55, 0.30, 0.55)
	teleg.polygon = _ellipse(Vector2.ZERO, 140.0, 70.0, 24)
	teleg.position = global_position
	teleg.z_index = -1
	get_parent().add_child(teleg)
	var tw := create_tween()
	tw.tween_property(teleg, "color:a", 0.85, 0.85)
	tw.tween_callback(teleg.queue_free)


func _release_attack() -> void:
	var shock := SlamShockwave.new()
	shock.global_position = global_position
	shock.radius = 140.0
	shock.damage = damage
	shock.shooter = self
	get_parent().add_child(shock)


func get_defense_stats() -> Dictionary:
	return {"armor": 6}


func get_resistance(damage_type: StringName) -> float:
	match damage_type:
		&"physical":
			return 0.7
		&"lightning":
			return 1.25
		_:
			return 1.0
