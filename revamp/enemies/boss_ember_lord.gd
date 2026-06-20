extends "res://revamp/enemies/enemy_base.gd"

## BOSS: Lord of Embers. Three phases.
##   Phase 1 (100→66 %): Cleave melee + telegraphed slam.
##   Phase 2 (66→33 %):  Adds spiral fire bolts + perimeter fire pillars on cast.
##   Phase 3 (33→0 %):   Constant fire ring around boss + summons 4 wraithlings.

signal phase_changed(phase: int)
signal boss_died_at(at: Vector2)

const FireBolt := preload("res://revamp/effects/projectile_fire_bolt.gd")
const FirePillar := preload("res://revamp/effects/effect_fire_pillar.gd")
const Wraithling := preload("res://revamp/enemies/enemy_wraithling.gd")
const SlamShockwave := preload("res://revamp/effects/effect_slam_shockwave.gd")

const PLATE_DEEP := Color(0.10, 0.04, 0.06)
const PLATE_BASE := Color(0.45, 0.14, 0.16)
const PLATE_MID := Color(0.60, 0.24, 0.20)
const PLATE_HI := Color(0.85, 0.40, 0.28)
const EMBER_GLOW := Color(1.0, 0.55, 0.20)
const EMBER_CORE := Color(1.0, 0.92, 0.65)
const GOLD := Color(0.95, 0.78, 0.30)
const SHADOW := Color(0.04, 0.02, 0.04)

@export var phase: int = 1
var _next_spiral_at: float = 6.0
var _next_pillar_at: float = 10.0
var _next_summon_at: float = 18.0
var _arena_center: Vector2 = Vector2.ZERO
var _ember_scar: Polygon2D
var _heat_halo: Polygon2D
var _scythe_trail: GPUParticles2D
var _eye_glow: Polygon2D
var _ember_particles: GPUParticles2D


func _ready() -> void:
	max_hp = 2400.0
	damage = 40.0
	move_speed = 115.0
	attack_range = 110.0
	attack_cooldown = 2.0
	aggro_range = 2000.0
	color_primary = PLATE_BASE
	color_secondary = PLATE_DEEP
	glow_color = EMBER_GLOW
	family = &"ember_lord"
	xp_value = 800
	super._ready()
	add_to_group("revamp_boss")
	z_index = 5


func set_arena_center(c: Vector2) -> void:
	_arena_center = c


func _build_visual() -> void:
	super._build_visual()
	var body := Node2D.new()
	body.name = "Body"
	add_child(body)

	# ---- Background ember halo (heat distortion) ----
	_heat_halo = Polygon2D.new()
	_heat_halo.color = Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.22)
	_heat_halo.polygon = _ellipse(Vector2.ZERO, 130.0, 90.0, 36)
	_heat_halo.z_index = -2
	body.add_child(_heat_halo)
	# Mid halo (smaller, hotter)
	var halo2 := Polygon2D.new()
	halo2.color = Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.35)
	halo2.polygon = _ellipse(Vector2.ZERO, 88.0, 60.0, 28)
	halo2.z_index = -2
	body.add_child(halo2)

	# ---- Cape (deep) ----
	var cape_back := Polygon2D.new()
	cape_back.color = SHADOW
	cape_back.polygon = PackedVector2Array([
		Vector2(-48, -50), Vector2(-72, -10), Vector2(-66, 36),
		Vector2(-30, 56), Vector2(30, 56), Vector2(66, 36),
		Vector2(72, -10), Vector2(48, -50),
	])
	body.add_child(cape_back)
	# Cape edge highlight
	var cape_edge := Line2D.new()
	cape_edge.width = 2.4
	cape_edge.default_color = EMBER_GLOW
	cape_edge.points = PackedVector2Array([
		Vector2(-48, -50), Vector2(-72, -10), Vector2(-66, 36),
		Vector2(-30, 56),
	])
	body.add_child(cape_edge)
	var cape_edge_r := Line2D.new()
	cape_edge_r.width = 2.4
	cape_edge_r.default_color = EMBER_GLOW
	cape_edge_r.points = PackedVector2Array([
		Vector2(48, -50), Vector2(72, -10), Vector2(66, 36),
		Vector2(30, 56),
	])
	body.add_child(cape_edge_r)

	# ---- Torso silhouette (deep) ----
	var torso_back := Polygon2D.new()
	torso_back.color = PLATE_DEEP
	torso_back.polygon = PackedVector2Array([
		Vector2(-50, -60), Vector2(-62, -20), Vector2(-52, 42),
		Vector2(52, 42), Vector2(62, -20), Vector2(50, -60),
	])
	body.add_child(torso_back)

	# ---- Torso plates (base) ----
	var torso := Polygon2D.new()
	torso.color = PLATE_BASE
	torso.polygon = PackedVector2Array([
		Vector2(-44, -56), Vector2(-56, -16), Vector2(-46, 38),
		Vector2(46, 38), Vector2(56, -16), Vector2(44, -56),
	])
	body.add_child(torso)

	# Lit side mid-tone
	var torso_mid := Polygon2D.new()
	torso_mid.color = PLATE_MID
	torso_mid.polygon = PackedVector2Array([
		Vector2(0, -55), Vector2(-12, -16), Vector2(-6, 38),
		Vector2(46, 38), Vector2(56, -16), Vector2(44, -55),
	])
	body.add_child(torso_mid)

	# Plate seams (vertical lines)
	for x in [-22.0, 22.0]:
		var seam := Line2D.new()
		seam.width = 1.6
		seam.default_color = PLATE_DEEP
		seam.points = PackedVector2Array([
			Vector2(x, -50), Vector2(x, 36),
		])
		body.add_child(seam)
	# Horizontal plate divider
	var hseam := Line2D.new()
	hseam.width = 1.8
	hseam.default_color = PLATE_DEEP
	hseam.points = PackedVector2Array([Vector2(-50, -10), Vector2(50, -10)])
	body.add_child(hseam)
	# Belly plate highlight
	var belly_hi := Polygon2D.new()
	belly_hi.color = PLATE_HI
	belly_hi.polygon = PackedVector2Array([
		Vector2(6, -8), Vector2(38, -8), Vector2(36, 30), Vector2(8, 30),
	])
	body.add_child(belly_hi)

	# ---- Chest ember scar (glowing veins) ----
	_ember_scar = Polygon2D.new()
	_ember_scar.color = EMBER_GLOW
	_ember_scar.polygon = PackedVector2Array([
		Vector2(-10, -42), Vector2(-2, -38), Vector2(2, -28), Vector2(8, -22),
		Vector2(4, -10), Vector2(0, 4), Vector2(-6, -8), Vector2(-10, -22),
		Vector2(-12, -34),
	])
	_ember_scar.material = _pulse_mat(EMBER_GLOW)
	body.add_child(_ember_scar)
	# Ember core inside scar
	var ember_core := Polygon2D.new()
	ember_core.color = EMBER_CORE
	ember_core.polygon = PackedVector2Array([
		Vector2(-2, -26), Vector2(4, -22), Vector2(0, -12), Vector2(-4, -20),
	])
	body.add_child(ember_core)

	# ---- Pauldrons (deep) ----
	var pauldL_back := Polygon2D.new()
	pauldL_back.color = SHADOW
	pauldL_back.polygon = PackedVector2Array([
		Vector2(-60, -46), Vector2(-76, -16), Vector2(-62, 4), Vector2(-44, -16),
	])
	body.add_child(pauldL_back)
	var pauldR_back := Polygon2D.new()
	pauldR_back.color = SHADOW
	pauldR_back.polygon = PackedVector2Array([
		Vector2(60, -46), Vector2(76, -16), Vector2(62, 4), Vector2(44, -16),
	])
	body.add_child(pauldR_back)
	# Pauldron base
	var pauldL := Polygon2D.new()
	pauldL.color = PLATE_BASE
	pauldL.polygon = PackedVector2Array([
		Vector2(-58, -42), Vector2(-72, -16), Vector2(-60, 0), Vector2(-46, -16),
	])
	body.add_child(pauldL)
	var pauldR := Polygon2D.new()
	pauldR.color = PLATE_BASE
	pauldR.polygon = PackedVector2Array([
		Vector2(58, -42), Vector2(72, -16), Vector2(60, 0), Vector2(46, -16),
	])
	body.add_child(pauldR)
	# Pauldron spikes
	var spikeL := Polygon2D.new()
	spikeL.color = PLATE_DEEP
	spikeL.polygon = PackedVector2Array([
		Vector2(-72, -16), Vector2(-86, -28), Vector2(-66, -20),
	])
	body.add_child(spikeL)
	var spikeR := Polygon2D.new()
	spikeR.color = PLATE_DEEP
	spikeR.polygon = PackedVector2Array([
		Vector2(72, -16), Vector2(86, -28), Vector2(66, -20),
	])
	body.add_child(spikeR)
	# Pauldron ember dot (lava cracks)
	for sx in [-58.0, 58.0]:
		var emb := Polygon2D.new()
		emb.color = EMBER_GLOW
		emb.polygon = PackedVector2Array([
			Vector2(sx - 3, -24), Vector2(sx + 3, -24), Vector2(sx + 2, -18),
			Vector2(sx - 2, -18),
		])
		body.add_child(emb)

	# ---- Greaves / leg armor ----
	var legL := Polygon2D.new()
	legL.color = PLATE_DEEP
	legL.polygon = PackedVector2Array([
		Vector2(-26, 38), Vector2(-30, 56), Vector2(-12, 56), Vector2(-10, 38),
	])
	body.add_child(legL)
	var legR := Polygon2D.new()
	legR.color = PLATE_DEEP
	legR.polygon = PackedVector2Array([
		Vector2(26, 38), Vector2(30, 56), Vector2(12, 56), Vector2(10, 38),
	])
	body.add_child(legR)

	# ---- Helm (deep silhouette) ----
	var helm_back := Polygon2D.new()
	helm_back.color = SHADOW
	helm_back.polygon = PackedVector2Array([
		Vector2(-34, -92), Vector2(-40, -64), Vector2(-32, -50),
		Vector2(32, -50), Vector2(40, -64), Vector2(34, -92),
	])
	body.add_child(helm_back)
	var helm := Polygon2D.new()
	helm.color = PLATE_DEEP
	helm.polygon = PackedVector2Array([
		Vector2(-30, -86), Vector2(-36, -60), Vector2(-30, -50),
		Vector2(30, -50), Vector2(36, -60), Vector2(30, -86),
	])
	body.add_child(helm)
	# Helm mid tone
	var helm_mid := Polygon2D.new()
	helm_mid.color = PLATE_BASE.darkened(0.15)
	helm_mid.polygon = PackedVector2Array([
		Vector2(0, -84), Vector2(-6, -60), Vector2(0, -50),
		Vector2(30, -50), Vector2(36, -60), Vector2(30, -84),
	])
	body.add_child(helm_mid)
	# Helm gold trim
	var trim := Line2D.new()
	trim.width = 1.6
	trim.default_color = GOLD
	trim.points = PackedVector2Array([
		Vector2(-30, -50), Vector2(30, -50),
	])
	body.add_child(trim)

	# ---- Horns ----
	var hornL_back := Polygon2D.new()
	hornL_back.color = SHADOW
	hornL_back.polygon = PackedVector2Array([
		Vector2(-36, -84), Vector2(-66, -120), Vector2(-32, -66),
	])
	body.add_child(hornL_back)
	var hornR_back := Polygon2D.new()
	hornR_back.color = SHADOW
	hornR_back.polygon = PackedVector2Array([
		Vector2(36, -84), Vector2(66, -120), Vector2(32, -66),
	])
	body.add_child(hornR_back)
	var hornL := Polygon2D.new()
	hornL.color = PLATE_DEEP
	hornL.polygon = PackedVector2Array([
		Vector2(-34, -84), Vector2(-58, -110), Vector2(-30, -66),
	])
	body.add_child(hornL)
	var hornR := Polygon2D.new()
	hornR.color = PLATE_DEEP
	hornR.polygon = PackedVector2Array([
		Vector2(34, -84), Vector2(58, -110), Vector2(30, -66),
	])
	body.add_child(hornR)
	# Horn ember tips
	for hp in [Vector2(-58, -110), Vector2(58, -110)]:
		var tip := Polygon2D.new()
		tip.color = EMBER_GLOW
		tip.polygon = _circle(hp, 6.0, 12)
		tip.material = _pulse_mat(EMBER_GLOW)
		body.add_child(tip)

	# ---- Eye band (glowing slit) ----
	_eye_glow = Polygon2D.new()
	_eye_glow.color = EMBER_CORE
	_eye_glow.polygon = PackedVector2Array([
		Vector2(-22, -72), Vector2(22, -72), Vector2(22, -64), Vector2(-22, -64),
	])
	_eye_glow.material = _pulse_mat(EMBER_CORE)
	body.add_child(_eye_glow)
	# Eye band side gleams
	for sx in [-22.0, 22.0]:
		var gleam := Polygon2D.new()
		gleam.color = EMBER_GLOW
		gleam.polygon = PackedVector2Array([
			Vector2(sx - 4, -76), Vector2(sx + 4, -76), Vector2(sx + 6, -60), Vector2(sx - 6, -60),
		])
		body.add_child(gleam)
	# Light cone below eyes
	var eye_cone := Polygon2D.new()
	eye_cone.color = Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.30)
	eye_cone.polygon = PackedVector2Array([
		Vector2(-22, -64), Vector2(22, -64), Vector2(34, -36), Vector2(-34, -36),
	])
	body.add_child(eye_cone)

	# ---- Skirt / belt with ember plates ----
	var belt := Polygon2D.new()
	belt.color = PLATE_DEEP
	belt.polygon = PackedVector2Array([
		Vector2(-50, 14), Vector2(50, 14), Vector2(48, 22), Vector2(-48, 22),
	])
	body.add_child(belt)
	# Belt gold buckle
	var buckle := Polygon2D.new()
	buckle.color = GOLD
	buckle.polygon = PackedVector2Array([
		Vector2(-10, 12), Vector2(10, 12), Vector2(12, 22), Vector2(-12, 22),
	])
	body.add_child(buckle)
	var buckle_gem := Polygon2D.new()
	buckle_gem.color = EMBER_GLOW
	buckle_gem.polygon = PackedVector2Array([
		Vector2(-4, 14), Vector2(4, 14), Vector2(5, 20), Vector2(0, 22), Vector2(-5, 20),
	])
	buckle_gem.material = _pulse_mat(EMBER_GLOW)
	body.add_child(buckle_gem)

	# ---- Scythe (held in right hand) ----
	# Rod with two-tone
	var rod_back := Line2D.new()
	rod_back.width = 9.0
	rod_back.default_color = SHADOW
	rod_back.points = PackedVector2Array([Vector2(46, 30), Vector2(88, -70)])
	body.add_child(rod_back)
	var rod_mid := Line2D.new()
	rod_mid.width = 6.0
	rod_mid.default_color = PLATE_DEEP
	rod_mid.points = PackedVector2Array([Vector2(46, 30), Vector2(88, -70)])
	body.add_child(rod_mid)
	var rod_hi := Line2D.new()
	rod_hi.width = 2.0
	rod_hi.default_color = PLATE_MID
	rod_hi.points = PackedVector2Array([Vector2(46, 30), Vector2(88, -70)])
	rod_hi.position = Vector2(-1.5, 0)
	body.add_child(rod_hi)
	# Scythe blade — large fiery curve
	var blade_back := Polygon2D.new()
	blade_back.color = SHADOW
	blade_back.polygon = PackedVector2Array([
		Vector2(86, -68), Vector2(122, -76), Vector2(140, -60), Vector2(120, -48), Vector2(96, -54),
	])
	body.add_child(blade_back)
	var blade := Polygon2D.new()
	blade.color = EMBER_GLOW
	blade.polygon = PackedVector2Array([
		Vector2(88, -68), Vector2(120, -72), Vector2(134, -60), Vector2(116, -50), Vector2(96, -56),
	])
	body.add_child(blade)
	# Blade hot core
	var blade_core := Polygon2D.new()
	blade_core.color = EMBER_CORE
	blade_core.polygon = PackedVector2Array([
		Vector2(96, -64), Vector2(118, -66), Vector2(126, -60), Vector2(108, -56),
	])
	body.add_child(blade_core)
	# Blade gold trim
	var blade_trim := Line2D.new()
	blade_trim.width = 1.6
	blade_trim.default_color = GOLD
	blade_trim.points = PackedVector2Array([
		Vector2(88, -68), Vector2(120, -72), Vector2(134, -60),
	])
	body.add_child(blade_trim)
	# Crossguard
	var guard := Polygon2D.new()
	guard.color = GOLD
	guard.polygon = PackedVector2Array([
		Vector2(80, -54), Vector2(96, -64), Vector2(98, -56), Vector2(82, -46),
	])
	body.add_child(guard)

	# Scythe particle trail (faint embers)
	_scythe_trail = GPUParticles2D.new()
	_scythe_trail.position = Vector2(120, -65)
	_scythe_trail.amount = 24
	_scythe_trail.lifetime = 1.2
	_scythe_trail.preprocess = 1.0
	_scythe_trail.texture = _dot_texture(8, Color(1.0, 0.55, 0.20, 0.95))
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 14.0
	pmat.gravity = Vector3(0, -30, 0)
	pmat.initial_velocity_min = 10.0
	pmat.initial_velocity_max = 28.0
	pmat.spread = 180.0
	pmat.scale_min = 0.3
	pmat.scale_max = 1.0
	pmat.color = Color(1.0, 0.55, 0.20, 0.95)
	_scythe_trail.process_material = pmat
	body.add_child(_scythe_trail)

	# ---- Ember particles around boss body ----
	_ember_particles = GPUParticles2D.new()
	_ember_particles.position = Vector2.ZERO
	_ember_particles.amount = 28
	_ember_particles.lifetime = 1.6
	_ember_particles.preprocess = 1.0
	_ember_particles.texture = _dot_texture(6, Color(1.0, 0.6, 0.20, 0.9))
	var emat := ParticleProcessMaterial.new()
	emat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	emat.emission_box_extents = Vector3(50, 50, 1)
	emat.gravity = Vector3(0, -60, 0)
	emat.initial_velocity_min = 14.0
	emat.initial_velocity_max = 36.0
	emat.scale_min = 0.3
	emat.scale_max = 0.9
	emat.color = Color(1.0, 0.55, 0.18, 0.85)
	_ember_particles.process_material = emat
	body.add_child(_ember_particles)


# === Behavior (unchanged from previous) ===

func _process(delta: float) -> void:
	super._process(delta)
	if _heat_halo:
		_heat_halo.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.0018) * 0.05)
	_evaluate_phase()
	var now_s: float = Time.get_ticks_msec() * 0.001
	if phase >= 2 and now_s >= _next_spiral_at:
		_next_spiral_at = now_s + (5.5 if phase == 2 else 4.0)
		_fire_spiral()
	if phase >= 2 and now_s >= _next_pillar_at:
		_next_pillar_at = now_s + (8.0 if phase == 2 else 6.0)
		_fire_pillars()
	if phase >= 3 and now_s >= _next_summon_at:
		_next_summon_at = now_s + 14.0
		_summon_wraithlings()
		_phase3_ring()


func _evaluate_phase() -> void:
	var ratio: float = current_hp / max_hp
	var new_phase: int = phase
	if ratio <= 0.33:
		new_phase = 3
	elif ratio <= 0.66:
		new_phase = 2
	else:
		new_phase = 1
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_phase_transition_flash()


func _phase_transition_flash() -> void:
	var f := Polygon2D.new()
	f.color = Color(1.0, 0.8, 0.4, 0.65)
	f.polygon = _ellipse(Vector2.ZERO, 220.0, 140.0, 32)
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.6)
	tw.tween_callback(f.queue_free)


func _fire_spiral() -> void:
	var n: int = 12 if phase == 2 else 18
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		var proj := FireBolt.new()
		proj.global_position = global_position
		proj.set_aim(Vector2(cos(a), sin(a)))
		proj.damage = 16.0
		proj.shooter = self
		get_parent().add_child(proj)


func _fire_pillars() -> void:
	var count: int = 5 if phase == 2 else 8
	for i in range(count):
		var pillar := FirePillar.new()
		var pos: Vector2 = _arena_center + Vector2(randf_range(-450, 450), randf_range(-260, 260))
		pillar.global_position = pos
		pillar.shooter = self
		pillar.damage = 36.0
		pillar.delay = 0.9
		get_parent().add_child(pillar)


func _summon_wraithlings() -> void:
	for i in range(4):
		var w := Wraithling.new()
		var a: float = float(i) / 4.0 * TAU
		w.global_position = global_position + Vector2(cos(a), sin(a)) * 110.0
		get_parent().add_child(w)


func _phase3_ring() -> void:
	var n: int = 24
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		var proj := FireBolt.new()
		proj.global_position = global_position
		proj.set_aim(Vector2(cos(a), sin(a)))
		proj.damage = 14.0
		proj.shooter = self
		get_parent().add_child(proj)


func windup_seconds() -> float:
	return 0.75


func _on_windup_begin() -> void:
	var teleg := Polygon2D.new()
	teleg.color = Color(1.0, 0.45, 0.25, 0.45)
	teleg.polygon = _ellipse(Vector2.ZERO, 180.0, 100.0, 24)
	teleg.position = global_position
	teleg.z_index = -1
	get_parent().add_child(teleg)
	var tw := create_tween()
	tw.tween_property(teleg, "color:a", 0.85, 0.7)
	tw.tween_callback(teleg.queue_free)


func _release_attack() -> void:
	var shock := SlamShockwave.new()
	shock.global_position = global_position
	shock.radius = 170.0
	shock.damage = damage
	shock.shooter = self
	get_parent().add_child(shock)
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - global_position).normalized()
		var bolt := FireBolt.new()
		bolt.global_position = global_position
		bolt.set_aim(dir)
		bolt.damage = damage * 0.7
		bolt.shooter = self
		get_parent().add_child(bolt)


func get_defense_stats() -> Dictionary:
	return {"armor": 8}


func get_resistance(damage_type: StringName) -> float:
	match damage_type:
		&"fire":
			return 0.3
		&"physical":
			return 0.85
		&"arcane":
			return 1.15
		_:
			return 1.0


func _on_death() -> void:
	boss_died_at.emit(global_position)
	var ex := Polygon2D.new()
	ex.color = Color(1.0, 0.6, 0.2, 0.9)
	ex.polygon = _ellipse(Vector2.ZERO, 240, 150, 32)
	add_child(ex)
	var tw := create_tween()
	tw.tween_property(ex, "scale", Vector2(2.4, 2.4), 0.6)
	tw.parallel().tween_property(ex, "color:a", 0.0, 0.8)
	tw.parallel().tween_property(self, "modulate", Color(2.0, 1.6, 1.0, 0.0), 0.9)
	tw.tween_callback(queue_free)


# === Helpers ===

func _pulse_mat(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
		void fragment() {
			float p = 0.65 + 0.35 * sin(TIME * 2.4);
			COLOR.rgb = col.rgb;
			COLOR.a *= p;
		}
	"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", c)
	return m


func _dot_texture(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var d: float = (Vector2(x, y) - c).length() / float(size * 0.5)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.5)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)
