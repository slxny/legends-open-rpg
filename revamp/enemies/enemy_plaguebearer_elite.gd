extends "res://revamp/enemies/enemy_base.gd"

## ELITE: Plaguebearer. Two real mechanics:
##   1. Telegraphed toxic pools dropped every 4s at the player's last position;
##      pools persist 5s and tick damage if you stand in them.
##   2. Summons 2 wraithlings every 9s.
## Drops a guaranteed minor loot beam on death.

const ToxicPool := preload("res://revamp/effects/effect_toxic_pool.gd")
const Wraithling := preload("res://revamp/enemies/enemy_wraithling.gd")

signal elite_died(at: Vector2)

var _next_pool_at: float = 2.0
var _next_summon_at: float = 5.0


func _ready() -> void:
	max_hp = 460.0
	damage = 22.0
	move_speed = 105.0
	attack_range = 70.0
	attack_cooldown = 1.8
	aggro_range = 700.0
	color_primary = Color(0.28, 0.55, 0.30)
	color_secondary = Color(0.10, 0.20, 0.16)
	glow_color = Color(0.45, 1.0, 0.30)
	family = &"plaguebearer"
	xp_value = 220
	super._ready()
	add_to_group("revamp_elites")


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)
	# Plague halo around boss (back)
	var halo := Polygon2D.new()
	halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.22)
	halo.polygon = _ellipse(Vector2(0, 0), 64.0, 42.0, 28)
	halo.z_index = -2
	body.add_child(halo)
	# Inner halo ring (brighter)
	var halo_inner := Polygon2D.new()
	halo_inner.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.14)
	halo_inner.polygon = _ellipse(Vector2(0, 4), 44.0, 30.0, 24)
	halo_inner.z_index = -1
	body.add_child(halo_inner)
	# Robe SHADOW (deeper silhouette)
	var robe_shadow := Polygon2D.new()
	robe_shadow.color = color_secondary
	robe_shadow.polygon = PackedVector2Array([
		Vector2(-28, -35), Vector2(-34, -8), Vector2(-28, 30),
		Vector2(28, 30), Vector2(34, -8), Vector2(28, -35),
	])
	body.add_child(robe_shadow)
	# Larger bulky robe (base)
	var robe := Polygon2D.new()
	robe.color = color_primary
	robe.polygon = PackedVector2Array([
		Vector2(-26, -34), Vector2(-32, -8), Vector2(-26, 28),
		Vector2(26, 28), Vector2(32, -8), Vector2(26, -34),
	])
	body.add_child(robe)
	# Robe mid-tone (lit half)
	var robe_mid := Polygon2D.new()
	robe_mid.color = color_primary.lightened(0.18)
	robe_mid.polygon = PackedVector2Array([
		Vector2(-2, -33), Vector2(-6, -8), Vector2(-2, 28),
		Vector2(26, 28), Vector2(32, -8), Vector2(26, -33),
	])
	body.add_child(robe_mid)
	# Robe folds (3 vertical ribs)
	var fold1 := Polygon2D.new()
	fold1.color = color_primary.lightened(0.34)
	fold1.polygon = PackedVector2Array([Vector2(8, -28), Vector2(12, -8), Vector2(10, 22), Vector2(6, -8)])
	body.add_child(fold1)
	var fold2 := Polygon2D.new()
	fold2.color = color_primary.lightened(0.34)
	fold2.polygon = PackedVector2Array([Vector2(18, -28), Vector2(22, -8), Vector2(20, 22), Vector2(16, -8)])
	body.add_child(fold2)
	var fold3 := Polygon2D.new()
	fold3.color = color_primary.darkened(0.22)
	fold3.polygon = PackedVector2Array([Vector2(-10, -28), Vector2(-14, -8), Vector2(-12, 22), Vector2(-8, -8)])
	body.add_child(fold3)
	# Tattered robe hem accent
	var hem := Polygon2D.new()
	hem.color = color_secondary
	hem.polygon = PackedVector2Array([
		Vector2(-26, 26), Vector2(-20, 32), Vector2(-14, 26),
		Vector2(-8, 34), Vector2(0, 26), Vector2(8, 34),
		Vector2(14, 26), Vector2(20, 32), Vector2(26, 26),
	])
	body.add_child(hem)
	# Robe edge highlight
	var robe_rim := Line2D.new()
	robe_rim.width = 1.6
	robe_rim.default_color = color_primary.lightened(0.45)
	robe_rim.points = PackedVector2Array([Vector2(26, -34), Vector2(32, -8), Vector2(26, 28)])
	body.add_child(robe_rim)
	# Glowing seam down the chest
	var seam := Line2D.new()
	seam.width = 3.0
	seam.default_color = glow_color
	seam.points = PackedVector2Array([Vector2(0, -28), Vector2(-4, -10), Vector2(2, 6), Vector2(-2, 22)])
	body.add_child(seam)
	# Seam inner bright core
	var seam_core := Line2D.new()
	seam_core.width = 1.2
	seam_core.default_color = Color(1.0, 1.0, 0.85, 0.9)
	seam_core.points = PackedVector2Array([Vector2(0, -28), Vector2(-4, -10), Vector2(2, 6), Vector2(-2, 22)])
	body.add_child(seam_core)
	# Chest sigil accent (cross-band)
	var sigil := Polygon2D.new()
	sigil.color = glow_color
	sigil.polygon = PackedVector2Array([
		Vector2(-10, -4), Vector2(10, -4), Vector2(10, 0), Vector2(-10, 0),
		Vector2(-2, -10), Vector2(2, -10), Vector2(2, 6), Vector2(-2, 6),
	])
	# triangulation-safe alt: separate cross arms
	sigil.polygon = PackedVector2Array([
		Vector2(-10, -2), Vector2(10, -2), Vector2(10, 2), Vector2(-10, 2),
	])
	body.add_child(sigil)
	var sigil_v := Polygon2D.new()
	sigil_v.color = glow_color
	sigil_v.polygon = PackedVector2Array([
		Vector2(-2, -10), Vector2(2, -10), Vector2(2, 6), Vector2(-2, 6),
	])
	body.add_child(sigil_v)
	# Hood SHADOW
	var hood_shadow := Polygon2D.new()
	hood_shadow.color = Color(0.04, 0.10, 0.06)
	hood_shadow.polygon = PackedVector2Array([
		Vector2(-19, -55), Vector2(-23, -34), Vector2(23, -34), Vector2(19, -55),
		Vector2(0, -62),
	])
	body.add_child(hood_shadow)
	# Tall hood
	var hood := Polygon2D.new()
	hood.color = color_secondary
	hood.polygon = PackedVector2Array([
		Vector2(-18, -54), Vector2(-22, -34), Vector2(22, -34), Vector2(18, -54),
		Vector2(0, -60),
	])
	body.add_child(hood)
	# Hood mid-tone (lit side)
	var hood_mid := Polygon2D.new()
	hood_mid.color = color_secondary.lightened(0.22)
	hood_mid.polygon = PackedVector2Array([
		Vector2(0, -60), Vector2(18, -54), Vector2(22, -34), Vector2(2, -34),
	])
	body.add_child(hood_mid)
	# Hood rim highlight
	var hood_rim := Line2D.new()
	hood_rim.width = 1.4
	hood_rim.default_color = color_primary.lightened(0.40)
	hood_rim.points = PackedVector2Array([Vector2(0, -60), Vector2(18, -54), Vector2(22, -34)])
	body.add_child(hood_rim)
	# Horns shadow
	var hornL_shadow := Polygon2D.new()
	hornL_shadow.color = Color(0.04, 0.10, 0.06)
	hornL_shadow.polygon = PackedVector2Array([Vector2(-23, -50), Vector2(-36, -66), Vector2(-23, -38)])
	body.add_child(hornL_shadow)
	var hornR_shadow := Polygon2D.new()
	hornR_shadow.color = Color(0.04, 0.10, 0.06)
	hornR_shadow.polygon = PackedVector2Array([Vector2(23, -50), Vector2(36, -66), Vector2(23, -38)])
	body.add_child(hornR_shadow)
	# Horns
	var hornL := Polygon2D.new()
	hornL.color = color_secondary
	hornL.polygon = PackedVector2Array([Vector2(-22, -50), Vector2(-34, -64), Vector2(-22, -38)])
	body.add_child(hornL)
	var hornR := Polygon2D.new()
	hornR.color = color_secondary
	hornR.polygon = PackedVector2Array([Vector2(22, -50), Vector2(34, -64), Vector2(22, -38)])
	body.add_child(hornR)
	# Horn segment accents (3 ridge bands per horn)
	var hornL_seg1 := Polygon2D.new()
	hornL_seg1.color = color_secondary.lightened(0.30)
	hornL_seg1.polygon = PackedVector2Array([Vector2(-24, -46), Vector2(-28, -50), Vector2(-26, -42)])
	body.add_child(hornL_seg1)
	var hornL_seg2 := Polygon2D.new()
	hornL_seg2.color = color_secondary.lightened(0.20)
	hornL_seg2.polygon = PackedVector2Array([Vector2(-28, -54), Vector2(-32, -58), Vector2(-29, -50)])
	body.add_child(hornL_seg2)
	var hornR_seg1 := Polygon2D.new()
	hornR_seg1.color = color_secondary.lightened(0.30)
	hornR_seg1.polygon = PackedVector2Array([Vector2(24, -46), Vector2(28, -50), Vector2(26, -42)])
	body.add_child(hornR_seg1)
	var hornR_seg2 := Polygon2D.new()
	hornR_seg2.color = color_secondary.lightened(0.20)
	hornR_seg2.polygon = PackedVector2Array([Vector2(28, -54), Vector2(32, -58), Vector2(29, -50)])
	body.add_child(hornR_seg2)
	# Horn tip glow accents
	var hornL_tip := Polygon2D.new()
	hornL_tip.color = glow_color
	hornL_tip.polygon = PackedVector2Array([
		Vector2(-34, -63), Vector2(-30, -63), Vector2(-32, -67),
	])
	body.add_child(hornL_tip)
	var hornR_tip := Polygon2D.new()
	hornR_tip.color = glow_color
	hornR_tip.polygon = PackedVector2Array([
		Vector2(30, -63), Vector2(34, -63), Vector2(32, -67),
	])
	body.add_child(hornR_tip)
	# Face shadow inside hood
	var face_shadow := Polygon2D.new()
	face_shadow.color = Color(0.02, 0.06, 0.04)
	face_shadow.polygon = PackedVector2Array([
		Vector2(-12, -46), Vector2(-16, -34), Vector2(16, -34), Vector2(12, -46),
	])
	body.add_child(face_shadow)
	# Eye halo (back glow)
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	eye_halo.polygon = _circle(Vector2(0, -41), 10.0, 16)
	body.add_child(eye_halo)
	# Plague eyes
	var eyes := Polygon2D.new()
	eyes.color = glow_color
	eyes.polygon = PackedVector2Array([
		Vector2(-9, -45), Vector2(-3, -45), Vector2(-3, -37), Vector2(-9, -37),
		Vector2(3, -45), Vector2(9, -45), Vector2(9, -37), Vector2(3, -37),
	])
	body.add_child(eyes)
	# Eye bright cores
	var eye_core := Polygon2D.new()
	eye_core.color = Color(1.0, 1.0, 0.80, 0.95)
	eye_core.polygon = PackedVector2Array([
		Vector2(-7, -43), Vector2(-4, -43), Vector2(-4, -39), Vector2(-7, -39),
		Vector2(4, -43), Vector2(7, -43), Vector2(7, -39), Vector2(4, -39),
	])
	body.add_child(eye_core)
	# Censer shadow
	var censer_shadow := Polygon2D.new()
	censer_shadow.color = Color(0.02, 0.06, 0.04)
	censer_shadow.polygon = PackedVector2Array([
		Vector2(31, 17), Vector2(37, 9), Vector2(41, 21), Vector2(37, 31),
	])
	body.add_child(censer_shadow)
	# Censer (swinging from one hand)
	var censer := Polygon2D.new()
	censer.color = color_secondary
	censer.polygon = PackedVector2Array([
		Vector2(30, 16), Vector2(36, 8), Vector2(40, 20), Vector2(36, 30),
	])
	body.add_child(censer)
	# Censer lit face (mid)
	var censer_mid := Polygon2D.new()
	censer_mid.color = color_secondary.lightened(0.30)
	censer_mid.polygon = PackedVector2Array([
		Vector2(34, 10), Vector2(40, 20), Vector2(37, 25), Vector2(34, 18),
	])
	body.add_child(censer_mid)
	# Censer glow accent (ember dot inside)
	var censer_ember := Polygon2D.new()
	censer_ember.color = glow_color
	censer_ember.polygon = PackedVector2Array([
		Vector2(34, 18), Vector2(38, 18), Vector2(36, 22),
	])
	body.add_child(censer_ember)
	# Censer chain
	var censer_chain := Line2D.new()
	censer_chain.width = 2.0
	censer_chain.default_color = color_secondary
	censer_chain.points = PackedVector2Array([Vector2(28, 4), Vector2(34, 16)])
	body.add_child(censer_chain)


func _process(delta: float) -> void:
	super._process(delta)
	var now_s: float = Time.get_ticks_msec() * 0.001
	if now_s >= _next_pool_at and is_instance_valid(target):
		_next_pool_at = now_s + 4.0
		_drop_pool_at(target.global_position)
	if now_s >= _next_summon_at:
		_next_summon_at = now_s + 9.0
		_summon_wraithlings()


func _drop_pool_at(at: Vector2) -> void:
	var pool := ToxicPool.new()
	pool.global_position = at
	pool.shooter = self
	pool.damage_per_tick = 9.0
	pool.duration = 5.0
	pool.radius = 110.0
	get_parent().add_child(pool)


func _summon_wraithlings() -> void:
	for i in range(2):
		var w := Wraithling.new()
		w.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		get_parent().add_child(w)


func get_resistance(damage_type: StringName) -> float:
	match damage_type:
		&"poison":
			return 0.0  # immune to poison
		&"arcane":
			return 1.1
		_:
			return 1.0


func get_defense_stats() -> Dictionary:
	return {"armor": 4}


func _on_death() -> void:
	elite_died.emit(global_position)
	# Bigger pop
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 1.8, 1.5, 0.0), 0.32)
	tw.parallel().tween_property(self, "scale", Vector2(1.8, 1.8), 0.32)
	tw.tween_callback(queue_free)
	_drop_xp_orb()
