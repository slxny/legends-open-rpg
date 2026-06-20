extends Node2D

## Painterly ground material — dark slate base, lichen overlays, glowing
## arcane runes embedded in the path, scorch marks at combat anchors.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))

const HORIZON_Y := -120.0
const GROUND_TOP := -90.0
const BASE_COLOR := Color(0.20, 0.21, 0.30)
const PATH_COLOR := Color(0.30, 0.27, 0.38)
const LICHEN_COLORS := [
	Color(0.40, 0.55, 0.50, 0.55),
	Color(0.55, 0.42, 0.62, 0.50),
	Color(0.65, 0.55, 0.30, 0.45),
]
const RUNE_COLOR := Color(0.45, 0.85, 1.0, 0.85)


func _ready() -> void:
	_paint_base()
	_paint_path()
	_paint_lichen()
	_paint_runes()
	_paint_scorch()


func _paint_base() -> void:
	var r := ColorRect.new()
	var play_top: float = GROUND_TOP
	var play_h: float = world_bounds.end.y - play_top + 200.0
	r.position = Vector2(world_bounds.position.x, play_top)
	r.size = Vector2(world_bounds.size.x, play_h)
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		uniform vec4 base_color : source_color;
		uniform vec4 stripe_color : source_color = vec4(0.32, 0.30, 0.45, 1.0);
		float hash(vec2 p) {
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}
		float noise(vec2 p) {
			vec2 i = floor(p);
			vec2 f = fract(p);
			float a = hash(i);
			float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0));
			float d = hash(i + vec2(1.0, 1.0));
			vec2 u = f * f * (3.0 - 2.0 * f);
			return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
		}
		void fragment() {
			vec2 uv = UV * vec2(30.0, 9.0);
			float n = noise(uv) * 0.6 + noise(uv * 2.5) * 0.4;
			vec3 col = mix(base_color.rgb, stripe_color.rgb, n);
			// vertical fade — darker as we go further "into the distance" up
			float depth_fade = smoothstep(0.0, 0.25, UV.y);
			col = mix(base_color.rgb * 0.65, col, depth_fade);
			COLOR = vec4(col, 1.0);
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("base_color", BASE_COLOR)
	r.material = mat
	add_child(r)


func _paint_path() -> void:
	var pts: Array[Vector2] = []
	var x: float = -2400.0
	while x < 4000.0:
		pts.append(Vector2(x, 0.0 + sin(x * 0.0007) * 28.0 + cos(x * 0.0015) * 18.0))
		x += 80.0
	var path := Line2D.new()
	path.width = 220.0
	path.default_color = PATH_COLOR
	path.points = PackedVector2Array(pts)
	path.joint_mode = Line2D.LINE_JOINT_ROUND
	path.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path.end_cap_mode = Line2D.LINE_CAP_ROUND
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		void fragment() {
			float w = abs(UV.y - 0.5) * 2.0;
			float a = smoothstep(1.0, 0.6, w);
			COLOR.a *= a;
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	path.material = mat
	add_child(path)


func _paint_lichen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xCA11
	for i in range(180):
		var blob := Polygon2D.new()
		var c: Color = LICHEN_COLORS[rng.randi() % LICHEN_COLORS.size()]
		blob.color = c
		var cx: float = rng.randf_range(world_bounds.position.x + 100.0, world_bounds.end.x - 100.0)
		var cy: float = rng.randf_range(GROUND_TOP + 20.0, world_bounds.end.y - 100.0)
		var r: float = rng.randf_range(28.0, 70.0)
		var sides: int = 8 + rng.randi() % 6
		var poly: PackedVector2Array = PackedVector2Array()
		for s in range(sides):
			var a: float = float(s) / float(sides) * TAU
			var jitter: float = 1.0 + rng.randf_range(-0.25, 0.25)
			poly.append(Vector2(cx + cos(a) * r * jitter, cy + sin(a) * r * 0.45 * jitter))
		blob.polygon = poly
		add_child(blob)


func _paint_runes() -> void:
	var rune_x: float = -2200.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x711E
	while rune_x < 3600.0:
		var y: float = sin(rune_x * 0.0007) * 28.0 + cos(rune_x * 0.0015) * 18.0 + rng.randf_range(-25, 25)
		_draw_rune(Vector2(rune_x, y), rng.randi() % 4)
		rune_x += rng.randf_range(380.0, 620.0)


func _draw_rune(at: Vector2, kind: int) -> void:
	var holder := Node2D.new()
	holder.position = at
	add_child(holder)
	var outer := Polygon2D.new()
	outer.color = Color(0.05, 0.10, 0.16, 0.80)
	outer.polygon = _circle_poly(Vector2.ZERO, 26.0, 24)
	holder.add_child(outer)
	var glow := Polygon2D.new()
	glow.color = RUNE_COLOR
	glow.polygon = _rune_glyph(kind)
	glow.material = _make_pulse_mat()
	holder.add_child(glow)


func _make_pulse_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		uniform vec4 col : source_color = vec4(0.45, 0.85, 1.0, 0.85);
		void fragment() {
			float pulse = 0.55 + 0.45 * sin(TIME * 1.6 + UV.x * 12.0);
			COLOR.rgb = col.rgb;
			COLOR.a = col.a * pulse;
		}
	"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", RUNE_COLOR)
	return m


func _rune_glyph(kind: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	match kind:
		0:
			pts = PackedVector2Array([Vector2(-14, 10), Vector2(0, -12), Vector2(14, 10)])
		1:
			pts = PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(0, -13), Vector2(0, 13)])
		2:
			pts = PackedVector2Array([Vector2(0, -15), Vector2(13, 0), Vector2(0, 15), Vector2(-13, 0)])
		_:
			pts = PackedVector2Array([Vector2(-15, -8), Vector2(0, 10), Vector2(15, -8)])
	var poly: PackedVector2Array = PackedVector2Array()
	for p in pts:
		poly.append(p + Vector2(2.0, 0))
	for i in range(pts.size() - 1, -1, -1):
		poly.append(pts[i] + Vector2(-2.0, 0))
	return poly


func _paint_scorch() -> void:
	var scorch_centers := [Vector2(-1300, -40), Vector2(-500, 30), Vector2(200, -30), Vector2(1500, 25), Vector2(2100, -25)]
	for sc in scorch_centers:
		for j in range(7):
			var s := Polygon2D.new()
			s.color = Color(0.06, 0.05, 0.10, 0.55)
			var rad: float = randf_range(40.0, 80.0)
			s.polygon = _circle_poly(sc + Vector2(randf_range(-60, 60), randf_range(-30, 30)), rad, 10)
			add_child(s)


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return arr
