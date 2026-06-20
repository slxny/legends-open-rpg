extends "res://revamp/enemies/enemy_base.gd"

## SUPPORT: keeps a safe distance, casts a healing beam on the most damaged ally.


func _ready() -> void:
	max_hp = 70.0
	damage = 8.0
	move_speed = 95.0
	attack_range = 220.0  # ally heal range
	attack_cooldown = 1.4
	aggro_range = 700.0
	color_primary = Color(0.30, 0.55, 0.40)
	color_secondary = Color(0.10, 0.20, 0.16)
	glow_color = Color(0.55, 1.0, 0.55)
	family = &"acolyte"
	xp_value = 25
	super._ready()


var _beam: Line2D
var _beam_target: Node2D


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Robe SHADOW (deeper silhouette)
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
	# Robe mid-tone (lit half)
	var robe_mid := Polygon2D.new()
	robe_mid.color = color_primary.lightened(0.18)
	robe_mid.polygon = PackedVector2Array([
		Vector2(-2, -21), Vector2(-6, 0), Vector2(-3, 22),
		Vector2(16, 22), Vector2(20, 0), Vector2(14, -21),
	])
	body.add_child(robe_mid)
	# Robe folds (3 vertical ribs)
	var fold1 := Polygon2D.new()
	fold1.color = color_primary.lightened(0.34)
	fold1.polygon = PackedVector2Array([Vector2(6, -18), Vector2(8, 0), Vector2(6, 18), Vector2(4, 0)])
	body.add_child(fold1)
	var fold2 := Polygon2D.new()
	fold2.color = color_primary.lightened(0.34)
	fold2.polygon = PackedVector2Array([Vector2(12, -18), Vector2(14, 0), Vector2(12, 18), Vector2(10, 0)])
	body.add_child(fold2)
	var fold3 := Polygon2D.new()
	fold3.color = color_primary.darkened(0.25)
	fold3.polygon = PackedVector2Array([Vector2(-8, -18), Vector2(-11, 0), Vector2(-8, 18), Vector2(-5, 0)])
	body.add_child(fold3)
	# Vine accent at hem (ivy tendril)
	var vine := Line2D.new()
	vine.width = 1.6
	vine.default_color = glow_color.darkened(0.40)
	vine.points = PackedVector2Array([
		Vector2(-14, 20), Vector2(-10, 18), Vector2(-6, 22),
		Vector2(0, 18), Vector2(6, 22), Vector2(10, 18), Vector2(14, 20),
	])
	body.add_child(vine)
	# Robe edge highlight (lit rim)
	var robe_rim := Line2D.new()
	robe_rim.width = 1.4
	robe_rim.default_color = color_primary.lightened(0.45)
	robe_rim.points = PackedVector2Array([Vector2(14, -22), Vector2(20, 0), Vector2(16, 22)])
	body.add_child(robe_rim)
	# Coiled wyrm motif on chest (curled line)
	var motif := Line2D.new()
	motif.width = 2.0
	motif.default_color = glow_color
	var motif_pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var t: float = float(i) / 15.0
		var a: float = t * TAU
		motif_pts.append(Vector2(cos(a) * 6.0 * (1.0 - t * 0.5), sin(a) * 6.0 * (1.0 - t * 0.5)))
	motif.points = motif_pts
	motif.position = Vector2(0, 4)
	body.add_child(motif)
	# Motif halo (back glow)
	var motif_halo := Polygon2D.new()
	motif_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.25)
	motif_halo.polygon = _circle(Vector2(0, 4), 9.0, 14)
	body.add_child(motif_halo)
	# Motif eye-center accent
	var motif_eye := Polygon2D.new()
	motif_eye.color = Color(1.0, 1.0, 0.85, 0.95)
	motif_eye.polygon = PackedVector2Array([
		Vector2(-1, 3), Vector2(1, 3), Vector2(1, 5), Vector2(-1, 5),
	])
	body.add_child(motif_eye)
	# Hood shadow
	var hood_shadow := Polygon2D.new()
	hood_shadow.color = Color(0.04, 0.08, 0.06)
	hood_shadow.polygon = PackedVector2Array([
		Vector2(-13, -37), Vector2(-16, -22), Vector2(16, -22), Vector2(13, -37),
	])
	body.add_child(hood_shadow)
	# Tall hood with antlers
	var hood := Polygon2D.new()
	hood.color = color_secondary
	hood.polygon = PackedVector2Array([
		Vector2(-12, -36), Vector2(-15, -22), Vector2(15, -22), Vector2(12, -36),
	])
	body.add_child(hood)
	# Hood mid-tone (lit side)
	var hood_mid := Polygon2D.new()
	hood_mid.color = color_secondary.lightened(0.22)
	hood_mid.polygon = PackedVector2Array([
		Vector2(0, -36), Vector2(12, -36), Vector2(15, -22), Vector2(2, -22),
	])
	body.add_child(hood_mid)
	# Hood rim highlight
	var hood_rim := Line2D.new()
	hood_rim.width = 1.2
	hood_rim.default_color = color_primary.lightened(0.30)
	hood_rim.points = PackedVector2Array([Vector2(-12, -36), Vector2(12, -36), Vector2(15, -22)])
	body.add_child(hood_rim)
	# Antler shadow lines (thicker dark behind)
	var antL_back := Line2D.new()
	antL_back.width = 4.5
	antL_back.default_color = Color(0.04, 0.08, 0.06)
	antL_back.points = PackedVector2Array([Vector2(-12, -36), Vector2(-22, -54), Vector2(-30, -48)])
	body.add_child(antL_back)
	var antR_back := Line2D.new()
	antR_back.width = 4.5
	antR_back.default_color = Color(0.04, 0.08, 0.06)
	antR_back.points = PackedVector2Array([Vector2(12, -36), Vector2(22, -54), Vector2(30, -48)])
	body.add_child(antR_back)
	# Antlers
	var antL := Line2D.new()
	antL.width = 3.0
	antL.default_color = color_secondary
	antL.points = PackedVector2Array([Vector2(-12, -36), Vector2(-22, -54), Vector2(-30, -48)])
	body.add_child(antL)
	var antR := Line2D.new()
	antR.width = 3.0
	antR.default_color = color_secondary
	antR.points = PackedVector2Array([Vector2(12, -36), Vector2(22, -54), Vector2(30, -48)])
	body.add_child(antR)
	# Antler tip glow accents
	var tipL := Polygon2D.new()
	tipL.color = glow_color
	tipL.polygon = PackedVector2Array([
		Vector2(-31, -50), Vector2(-29, -50), Vector2(-28, -46), Vector2(-32, -46),
	])
	body.add_child(tipL)
	var tipR := Polygon2D.new()
	tipR.color = glow_color
	tipR.polygon = PackedVector2Array([
		Vector2(29, -50), Vector2(31, -50), Vector2(32, -46), Vector2(28, -46),
	])
	body.add_child(tipR)
	# Face shadow inside hood
	var face_shadow := Polygon2D.new()
	face_shadow.color = Color(0.04, 0.08, 0.06)
	face_shadow.polygon = PackedVector2Array([
		Vector2(-9, -32), Vector2(-12, -23), Vector2(12, -23), Vector2(9, -32),
	])
	body.add_child(face_shadow)
	# Eye halo
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.30)
	eye_halo.polygon = _circle(Vector2(0, -28), 8.0, 14)
	body.add_child(eye_halo)
	# Eyes
	var eyes := Polygon2D.new()
	eyes.color = glow_color
	eyes.polygon = PackedVector2Array([
		Vector2(-6, -30), Vector2(-3, -30), Vector2(-3, -27), Vector2(-6, -27),
		Vector2(3, -30), Vector2(6, -30), Vector2(6, -27), Vector2(3, -27),
	])
	body.add_child(eyes)
	# Eye bright cores
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 1.0, 0.85, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-5, -29), Vector2(-4, -29), Vector2(-4, -28), Vector2(-5, -28),
		Vector2(4, -29), Vector2(5, -29), Vector2(5, -28), Vector2(4, -28),
	])
	body.add_child(eye_core)
	# Healing beam (hidden until cast)
	_beam = Line2D.new()
	_beam.width = 5.0
	_beam.default_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
	_beam.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(_beam)


func _pursue_logic(_dist: float) -> void:
	# Stay back; orbit nearest ally to heal.
	var ally: Node2D = _find_healable_ally()
	var to_player: Vector2 = (target.global_position - global_position).normalized()
	if ally:
		var to_ally: Vector2 = (ally.global_position - global_position).normalized()
		# Move toward ally but stay away from player
		velocity = (to_ally * 0.6 + (-to_player) * 0.4 + _separation_offset()).normalized() * move_speed
	else:
		velocity = (-to_player + _separation_offset()).normalized() * move_speed * 0.7
	_aim = to_player


func _find_healable_ally() -> Node2D:
	var best: Node2D = null
	var best_def: float = -INF
	var tree := get_tree()
	if tree == null:
		return null
	for e in tree.get_nodes_in_group("revamp_enemies"):
		if e == self:
			continue
		if e is Node2D and is_instance_valid(e):
			var hp: float = float(e.get("current_hp"))
			var mh: float = float(e.get("max_hp"))
			var deficit: float = mh - hp
			if deficit > best_def and global_position.distance_to(e.global_position) < attack_range:
				best_def = deficit
				best = e
	if best_def < 5.0:
		return null
	return best


func _release_attack() -> void:
	var ally: Node2D = _find_healable_ally()
	if ally == null:
		return
	_beam_target = ally
	var heal: float = 32.0
	var hp: float = float(ally.get("current_hp"))
	var mh: float = float(ally.get("max_hp"))
	var new_hp: float = clampf(hp + heal, 0.0, mh)
	ally.set("current_hp", new_hp)
	if ally.has_signal("hp_changed"):
		ally.emit_signal("hp_changed", new_hp, mh)
	# Flash beam
	if _beam:
		_beam.default_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.85)
		_beam.points = PackedVector2Array([Vector2.ZERO, to_local(ally.global_position)])
		var tw := create_tween()
		tw.tween_property(_beam, "default_color:a", 0.0, 0.4)


func get_resistance(damage_type: StringName) -> float:
	match damage_type:
		&"arcane":
			return 1.2
		_:
			return 1.0
