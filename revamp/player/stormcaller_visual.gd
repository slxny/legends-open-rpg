extends Node2D

## Detailed Stormcaller — composed of ~50 polygons for shaded silhouette,
## flowing cloak with wind motion, glowing chest sigil, hood drop-shadow,
## staff with orb + particle aura, twin floating arcane runes.
##
## All draws are layered for a painted look (back→front):
##   ground halo  →  drop shadow  →  cloak back  →  cape secondary  →
##   robe shadow  →  robe body  →  robe highlights  →  belt + buckle →
##   chest sigil  →  hood shadow  →  hood  →  hood rim  →  face shadow →
##   eyes  →  staff rod  →  orb halo  →  orb core  →  orb sparkles →
##   floating runes  →  cloak front  →  modulate effects

const ROBE_DEEP := Color(0.10, 0.06, 0.18)
const ROBE_BASE := Color(0.28, 0.20, 0.55)
const ROBE_MID := Color(0.38, 0.28, 0.62)
const ROBE_HI := Color(0.55, 0.40, 0.80)
const ROBE_EDGE := Color(0.78, 0.55, 0.95)
const CAPE_BASE := Color(0.18, 0.12, 0.30)
const CAPE_HI := Color(0.42, 0.28, 0.60)
const BELT := Color(0.95, 0.65, 0.30)
const BELT_DARK := Color(0.55, 0.35, 0.12)
const SIGIL_GLOW := Color(0.55, 0.92, 1.00)
const EYE_GLOW := Color(0.65, 0.95, 1.0)
const HOOD_DEEP := Color(0.04, 0.02, 0.06)
const ROD := Color(0.20, 0.12, 0.08)
const ROD_HI := Color(0.42, 0.28, 0.18)

var _body: Node2D
var _cape: Node2D
var _cape_polys: Array = []
var _staff: Node2D
var _orb_halo: Polygon2D
var _orb_core: Polygon2D
var _orb_sparkle: Node2D
var _runes_holder: Node2D
var _aura_particles: GPUParticles2D
var _eyes: Polygon2D
var _sigil: Polygon2D

var _t: float = 0.0
var _move_dir: Vector2 = Vector2.RIGHT
var _facing_x: float = 1.0
var _bob_amp: float = 0.0
var _flash_until_ms: int = 0
var _dodge_until_ms: int = 0


func _ready() -> void:
	_build_ground_halo()
	_build_drop_shadow()
	_build_cape_back()       # back layer
	_build_body()            # all robe + belt + sigil + hood + face + eyes
	_build_staff()           # staff body
	_build_orb()             # orb + halo + sparkle particles
	_build_floating_runes()  # orbiting glyphs


# === LAYERS ===

func _build_ground_halo() -> void:
	var halo := Polygon2D.new()
	halo.color = Color(0.55, 0.85, 1.0, 0.30)
	halo.polygon = _circle(Vector2.ZERO, 42.0, 28)
	halo.scale.y = 0.45
	halo.position = Vector2(0, 22)
	halo.z_index = -4
	add_child(halo)
	# Inner brighter core
	var core := Polygon2D.new()
	core.color = Color(0.85, 0.95, 1.0, 0.18)
	core.polygon = _circle(Vector2.ZERO, 26.0, 24)
	core.scale.y = 0.4
	core.position = Vector2(0, 22)
	core.z_index = -3
	add_child(core)


func _build_drop_shadow() -> void:
	var s := Polygon2D.new()
	s.color = Color(0, 0, 0, 0.55)
	s.polygon = _circle(Vector2.ZERO, 20.0, 18)
	s.scale.y = 0.42
	s.position = Vector2(0, 20)
	s.z_index = -2
	add_child(s)


func _build_cape_back() -> void:
	_cape = Node2D.new()
	_cape.z_index = -1
	add_child(_cape)
	# Build cape as 5 ribbon segments that can sway independently.
	for i in range(5):
		var seg := Polygon2D.new()
		var t: float = float(i) / 4.0
		seg.color = CAPE_BASE.lerp(CAPE_HI, t * 0.55)
		# Base polygon — vertical strip narrowing downward.
		var x0: float = -22.0 + i * 4.0
		var x1: float = x0 + 9.0
		seg.polygon = PackedVector2Array([
			Vector2(x0, -22.0),
			Vector2(x1, -22.0),
			Vector2(x1 + 1.0, 24.0),
			Vector2(x0 - 1.0, 24.0),
		])
		_cape_polys.append(seg)
		_cape.add_child(seg)
	# Edge glow
	var edge := Polygon2D.new()
	edge.color = Color(0.55, 0.40, 0.80, 0.55)
	edge.polygon = PackedVector2Array([
		Vector2(-22, -22), Vector2(-23, 0), Vector2(-21, 26),
	])
	_cape.add_child(edge)


func _build_body() -> void:
	_body = Node2D.new()
	add_child(_body)

	# --- back cloak deep silhouette ---
	var cloak_back := Polygon2D.new()
	cloak_back.color = ROBE_DEEP
	cloak_back.polygon = PackedVector2Array([
		Vector2(-26, -30), Vector2(-32, -8), Vector2(-30, 16),
		Vector2(-24, 28), Vector2(24, 28), Vector2(30, 16),
		Vector2(32, -8), Vector2(26, -30),
	])
	_body.add_child(cloak_back)

	# --- robe shadow (slightly bigger than body for depth) ---
	var robe_shadow := Polygon2D.new()
	robe_shadow.color = ROBE_DEEP
	robe_shadow.polygon = PackedVector2Array([
		Vector2(-18, -22), Vector2(-23, 0), Vector2(-19, 24),
		Vector2(19, 24), Vector2(23, 0), Vector2(18, -22),
	])
	_body.add_child(robe_shadow)

	# --- robe base ---
	var robe := Polygon2D.new()
	robe.color = ROBE_BASE
	robe.polygon = PackedVector2Array([
		Vector2(-16, -20), Vector2(-21, 0), Vector2(-18, 22),
		Vector2(18, 22), Vector2(21, 0), Vector2(16, -20),
	])
	_body.add_child(robe)

	# --- robe mid-tone (lit side) ---
	var robe_mid := Polygon2D.new()
	robe_mid.color = ROBE_MID
	robe_mid.polygon = PackedVector2Array([
		Vector2(-3, -19), Vector2(-9, 0), Vector2(-5, 22),
		Vector2(18, 22), Vector2(21, 0), Vector2(16, -19),
	])
	_body.add_child(robe_mid)

	# --- robe highlights (cloth folds, 3 strips) ---
	var fold1 := Polygon2D.new()
	fold1.color = ROBE_HI
	fold1.polygon = PackedVector2Array([Vector2(6, -16), Vector2(9, 0), Vector2(7, 18), Vector2(4, 0)])
	_body.add_child(fold1)
	var fold2 := Polygon2D.new()
	fold2.color = ROBE_HI
	fold2.polygon = PackedVector2Array([Vector2(12, -16), Vector2(14, 0), Vector2(13, 18), Vector2(11, 0)])
	_body.add_child(fold2)
	var fold3 := Polygon2D.new()
	fold3.color = ROBE_BASE.darkened(0.25)
	fold3.polygon = PackedVector2Array([Vector2(-7, -16), Vector2(-10, 0), Vector2(-8, 18), Vector2(-5, 0)])
	_body.add_child(fold3)

	# --- robe edge highlight (lit rim) ---
	var rim := Line2D.new()
	rim.width = 1.6
	rim.default_color = ROBE_EDGE
	rim.points = PackedVector2Array([
		Vector2(16, -20), Vector2(21, 0), Vector2(18, 22),
	])
	_body.add_child(rim)

	# --- belt sash ---
	var sash := Polygon2D.new()
	sash.color = BELT
	sash.polygon = PackedVector2Array([
		Vector2(-17, -7), Vector2(17, -7), Vector2(15, -3), Vector2(-15, -3),
	])
	_body.add_child(sash)
	var sash_shadow := Polygon2D.new()
	sash_shadow.color = BELT_DARK
	sash_shadow.polygon = PackedVector2Array([
		Vector2(-17, -3), Vector2(17, -3), Vector2(15, -1), Vector2(-15, -1),
	])
	_body.add_child(sash_shadow)
	# Buckle
	var buckle := Polygon2D.new()
	buckle.color = Color(0.95, 0.78, 0.30)
	buckle.polygon = PackedVector2Array([
		Vector2(-4, -8), Vector2(4, -8), Vector2(5, -2), Vector2(-5, -2),
	])
	_body.add_child(buckle)
	var buckle_gem := Polygon2D.new()
	buckle_gem.color = SIGIL_GLOW
	buckle_gem.polygon = PackedVector2Array([
		Vector2(-2, -6), Vector2(2, -6), Vector2(0, -2),
	])
	_body.add_child(buckle_gem)

	# --- chest sigil (glowing) ---
	_sigil = Polygon2D.new()
	_sigil.color = SIGIL_GLOW
	_sigil.polygon = PackedVector2Array([
		Vector2(-5, -14), Vector2(5, -14), Vector2(7, -10),
		Vector2(0, -8), Vector2(-7, -10),
	])
	_sigil.material = _glow_pulse_mat(SIGIL_GLOW)
	_body.add_child(_sigil)
	# Sigil halo
	var sigil_halo := Polygon2D.new()
	sigil_halo.color = Color(SIGIL_GLOW.r, SIGIL_GLOW.g, SIGIL_GLOW.b, 0.30)
	sigil_halo.polygon = _circle(Vector2(0, -11), 12.0, 16)
	_body.add_child(sigil_halo)

	# --- shoulder armor pieces ---
	var shldL := Polygon2D.new()
	shldL.color = HOOD_DEEP
	shldL.polygon = PackedVector2Array([
		Vector2(-21, -22), Vector2(-26, -16), Vector2(-22, -10), Vector2(-16, -20),
	])
	_body.add_child(shldL)
	var shldR := Polygon2D.new()
	shldR.color = HOOD_DEEP
	shldR.polygon = PackedVector2Array([
		Vector2(21, -22), Vector2(26, -16), Vector2(22, -10), Vector2(16, -20),
	])
	_body.add_child(shldR)
	# Shoulder gold trim
	var trimL := Line2D.new()
	trimL.width = 1.4
	trimL.default_color = BELT
	trimL.points = PackedVector2Array([Vector2(-26, -16), Vector2(-22, -10)])
	_body.add_child(trimL)
	var trimR := Line2D.new()
	trimR.width = 1.4
	trimR.default_color = BELT
	trimR.points = PackedVector2Array([Vector2(26, -16), Vector2(22, -10)])
	_body.add_child(trimR)

	# --- hood drop shadow on face ---
	var face_shadow := Polygon2D.new()
	face_shadow.color = HOOD_DEEP
	face_shadow.polygon = PackedVector2Array([
		Vector2(-11, -34), Vector2(-14, -22), Vector2(14, -22), Vector2(11, -34),
		Vector2(6, -38), Vector2(-6, -38),
	])
	_body.add_child(face_shadow)

	# --- hood (back) ---
	var hood_back := Polygon2D.new()
	hood_back.color = ROBE_DEEP
	hood_back.polygon = PackedVector2Array([
		Vector2(-16, -38), Vector2(-21, -24), Vector2(-14, -16),
		Vector2(14, -16), Vector2(21, -24), Vector2(16, -38),
		Vector2(9, -46), Vector2(-9, -46),
	])
	_body.add_child(hood_back)

	# --- hood (mid tone, lit) ---
	var hood_mid := Polygon2D.new()
	hood_mid.color = ROBE_MID
	hood_mid.polygon = PackedVector2Array([
		Vector2(2, -42), Vector2(18, -32), Vector2(16, -18),
		Vector2(4, -18),
	])
	_body.add_child(hood_mid)

	# --- hood rim highlight ---
	var hood_rim := Line2D.new()
	hood_rim.width = 1.4
	hood_rim.default_color = ROBE_EDGE
	hood_rim.points = PackedVector2Array([
		Vector2(-9, -46), Vector2(9, -46), Vector2(16, -38), Vector2(21, -24),
	])
	_body.add_child(hood_rim)

	# --- hood front shadow line ---
	var hood_front_shadow := Polygon2D.new()
	hood_front_shadow.color = HOOD_DEEP
	hood_front_shadow.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(-11, -19), Vector2(11, -19), Vector2(14, -22),
	])
	_body.add_child(hood_front_shadow)

	# --- eyes (twin glow with light cone) ---
	_eyes = Polygon2D.new()
	_eyes.color = EYE_GLOW
	_eyes.polygon = PackedVector2Array([
		Vector2(-6, -27), Vector2(-3, -27), Vector2(-3, -24), Vector2(-6, -24),
		Vector2(3, -27), Vector2(6, -27), Vector2(6, -24), Vector2(3, -24),
	])
	_body.add_child(_eyes)
	# Eye glow halo
	var eye_halo := Polygon2D.new()
	eye_halo.color = Color(EYE_GLOW.r, EYE_GLOW.g, EYE_GLOW.b, 0.35)
	eye_halo.polygon = PackedVector2Array([
		Vector2(-9, -29), Vector2(0, -32), Vector2(9, -29),
		Vector2(9, -22), Vector2(0, -21), Vector2(-9, -22),
	])
	_body.add_child(eye_halo)


func _build_staff() -> void:
	_staff = Node2D.new()
	add_child(_staff)
	# Rod with two-tone shading
	var rod := Line2D.new()
	rod.width = 5.0
	rod.default_color = ROD
	rod.points = PackedVector2Array([Vector2(22, 18), Vector2(30, -46)])
	_staff.add_child(rod)
	var rod_hi := Line2D.new()
	rod_hi.width = 2.0
	rod_hi.default_color = ROD_HI
	rod_hi.points = PackedVector2Array([Vector2(22, 18), Vector2(30, -46)])
	rod_hi.position = Vector2(-1, 0)
	_staff.add_child(rod_hi)
	# Wrappings
	for y in [0, 6, 12]:
		var wrap := Line2D.new()
		wrap.width = 3.5
		wrap.default_color = Color(0.42, 0.28, 0.10)
		wrap.points = PackedVector2Array([Vector2(24 + y * 0.1, y), Vector2(28 + y * 0.1, y)])
		_staff.add_child(wrap)


func _build_orb() -> void:
	# Halo (large, transparent)
	_orb_halo = Polygon2D.new()
	_orb_halo.color = Color(EYE_GLOW.r, EYE_GLOW.g, EYE_GLOW.b, 0.30)
	_orb_halo.polygon = _circle(Vector2(30, -46), 26.0, 24)
	add_child(_orb_halo)
	# Mid glow
	var mid := Polygon2D.new()
	mid.color = Color(EYE_GLOW.r, EYE_GLOW.g, EYE_GLOW.b, 0.55)
	mid.polygon = _circle(Vector2(30, -46), 15.0, 20)
	add_child(mid)
	# Core
	_orb_core = Polygon2D.new()
	_orb_core.color = EYE_GLOW
	_orb_core.polygon = _circle(Vector2(30, -46), 9.0, 16)
	add_child(_orb_core)
	# Inner glint
	var glint := Polygon2D.new()
	glint.color = Color(1, 1, 1, 0.85)
	glint.polygon = _circle(Vector2(28, -49), 3.0, 12)
	add_child(glint)
	# Aura particles around orb
	_aura_particles = GPUParticles2D.new()
	_aura_particles.position = Vector2(30, -46)
	_aura_particles.amount = 16
	_aura_particles.lifetime = 1.0
	_aura_particles.preprocess = 1.0
	_aura_particles.texture = _dot_texture(8, Color(0.85, 0.95, 1.0, 0.85))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 14.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 22.0
	mat.spread = 180.0
	mat.scale_min = 0.4
	mat.scale_max = 1.1
	mat.color = Color(0.85, 0.95, 1.0, 0.85)
	_aura_particles.process_material = mat
	add_child(_aura_particles)


func _build_floating_runes() -> void:
	_runes_holder = Node2D.new()
	_runes_holder.position = Vector2(0, -6)
	add_child(_runes_holder)
	# Three different glyph shapes
	var glyph_shapes := [
		PackedVector2Array([Vector2(-5, 0), Vector2(0, -7), Vector2(5, 0), Vector2(0, 7)]),
		PackedVector2Array([Vector2(-6, -3), Vector2(0, -7), Vector2(6, -3), Vector2(3, 5), Vector2(-3, 5)]),
		PackedVector2Array([Vector2(-4, -5), Vector2(4, -5), Vector2(5, 2), Vector2(0, 6), Vector2(-5, 2)]),
	]
	for i in range(3):
		var rune := Polygon2D.new()
		rune.color = SIGIL_GLOW
		rune.polygon = glyph_shapes[i]
		rune.material = _glow_pulse_mat(SIGIL_GLOW)
		rune.set_meta("phase", float(i) * TAU / 3.0)
		# Halo
		var halo := Polygon2D.new()
		halo.color = Color(SIGIL_GLOW.r, SIGIL_GLOW.g, SIGIL_GLOW.b, 0.30)
		halo.polygon = _circle(Vector2.ZERO, 7.0, 16)
		rune.add_child(halo)
		_runes_holder.add_child(rune)


# === ANIMATION ===

func set_move_state(velocity: Vector2, aim: Vector2, in_dodge: bool) -> void:
	if velocity.length_squared() > 0.5:
		_move_dir = velocity.normalized()
		_bob_amp = clampf(velocity.length() / 220.0, 0.0, 1.0)
	else:
		_bob_amp = lerpf(_bob_amp, 0.0, 0.12)
	if absf(aim.x) > 0.2:
		_facing_x = signf(aim.x)


func play_dodge(_direction: Vector2) -> void:
	_dodge_until_ms = Time.get_ticks_msec() + 320


func flash_hit() -> void:
	_flash_until_ms = Time.get_ticks_msec() + 120


func _process(delta: float) -> void:
	_t += delta
	var bob: float = sin(_t * 8.0) * (1.4 + _bob_amp * 2.6)

	# Body / staff bob
	if _body:
		_body.position.y = bob
		_body.scale.x = _facing_x
	if _staff:
		_staff.position.y = bob * 0.6
		_staff.scale.x = _facing_x
	if _orb_halo:
		_orb_halo.position.y = bob * 0.6
		_orb_halo.scale = Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.08)
	if _orb_core:
		_orb_core.position.y = bob * 0.6

	# Cape sway — each segment sways with an offset wave; tilts based on movement.
	if _cape_polys.size() > 0:
		var tilt: float = clampf(-_move_dir.x * _facing_x * 0.15, -0.20, 0.20)
		for i in range(_cape_polys.size()):
			var seg: Polygon2D = _cape_polys[i]
			var t: float = float(i) / float(_cape_polys.size() - 1)
			var sway: float = sin(_t * 3.2 - i * 0.6) * 2.5 * (1.0 + _bob_amp * 0.8)
			seg.position = Vector2(sway, 0)
			seg.rotation = tilt * t

	# Floating runes orbit on a vertical ellipse around the chest
	if _runes_holder:
		_runes_holder.position.y = bob * 0.6 - 6
		var i: int = 0
		for child in _runes_holder.get_children():
			if child is Polygon2D:
				var ph: float = float(child.get_meta("phase", 0.0))
				var a: float = _t * 1.4 + ph
				child.position = Vector2(cos(a) * 28.0, sin(a) * 10.0 - 8.0)
				child.rotation = a * 1.6
			i += 1

	# Eye glow scale pulse
	if _eyes:
		_eyes.scale = Vector2.ONE * (1.0 + sin(_t * 5.0) * 0.07)

	# Modulate flash + dodge tint
	var now: int = Time.get_ticks_msec()
	if now < _flash_until_ms:
		modulate = Color(2.4, 1.8, 1.8)
	elif now < _dodge_until_ms:
		modulate = Color(0.55, 0.95, 1.3, 0.78)
	else:
		modulate = Color.WHITE


# === HELPERS ===

func _glow_pulse_mat(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
		void fragment() {
			float p = 0.7 + 0.3 * sin(TIME * 3.0);
			COLOR.rgb = col.rgb;
			COLOR.a *= p;
		}
	"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", c)
	return m


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr


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
