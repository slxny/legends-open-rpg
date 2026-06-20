extends Node2D

## Painterly multi-pass sky:
##   1. Gradient base with horizon glow
##   2. Sun disc + radial godrays + cloud-shafted light
##   3. Three layered cloud bands with light/shadow shading
##   4. Atmospheric haze at the horizon
##   5. Distant flock of birds silhouettes
##
## All drawn at fixed world bounds — the camera moves across it like a giant
## matte painting. No ellipse-cloud silhouettes left.

@export var world_bounds: Rect2 = Rect2(Vector2(-2400, -520), Vector2(6400, 1100))

const HORIZON_Y := -120.0

const SUN_POS_FRAC := Vector2(0.30, 0.62)   # within the sky rect
const SUN_RADIUS := 38.0
const SUN_CORE := Color(1.0, 0.95, 0.78)
const SUN_GLOW := Color(1.0, 0.72, 0.45)


func _ready() -> void:
	_build_sky_painting()
	_build_cloud_bands()
	_build_horizon_haze()
	_build_bird_flock()


# ----- 1 + 2 -----
func _build_sky_painting() -> void:
	var rect := ColorRect.new()
	rect.position = Vector2(world_bounds.position.x, world_bounds.position.y)
	rect.size = Vector2(world_bounds.size.x, HORIZON_Y - world_bounds.position.y + 80.0)
	rect.z_index = -2
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 c_top : source_color    = vec4(0.06, 0.05, 0.16, 1.0);
		uniform vec4 c_mid : source_color    = vec4(0.22, 0.16, 0.36, 1.0);
		uniform vec4 c_low : source_color    = vec4(0.55, 0.28, 0.32, 1.0);
		uniform vec4 c_horiz : source_color  = vec4(1.00, 0.62, 0.40, 1.0);
		uniform vec4 c_sun_core : source_color = vec4(1.0, 0.95, 0.78, 1.0);
		uniform vec4 c_sun_glow : source_color = vec4(1.0, 0.72, 0.45, 1.0);
		uniform vec2 sun_pos = vec2(0.30, 0.62);
		uniform float sun_radius = 0.04;
		uniform float godray_strength : hint_range(0.0, 2.0) = 0.85;

		float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
		float vnoise(vec2 p) {
			vec2 i = floor(p); vec2 f = fract(p);
			float a = hash(i);
			float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0));
			float d = hash(i + vec2(1.0, 1.0));
			vec2 u = f * f * (3.0 - 2.0 * f);
			return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
		}
		float fbm(vec2 p) {
			float s = 0.0; float w = 0.5;
			for (int i = 0; i < 4; i++) {
				s += vnoise(p) * w;
				p *= 2.05;
				w *= 0.5;
			}
			return s;
		}

		void fragment() {
			vec2 uv = UV;
			// Multi-stop gradient
			vec3 col;
			if (uv.y < 0.40) {
				col = mix(c_top.rgb, c_mid.rgb, smoothstep(0.0, 0.40, uv.y));
			} else if (uv.y < 0.78) {
				col = mix(c_mid.rgb, c_low.rgb, smoothstep(0.40, 0.78, uv.y));
			} else {
				col = mix(c_low.rgb, c_horiz.rgb, pow(smoothstep(0.78, 1.0, uv.y), 1.5));
			}
			// Subtle painterly noise washes
			float wash = fbm(uv * vec2(6.0, 3.5) + vec2(0.0, 0.0));
			col += (wash - 0.5) * 0.06;

			// Sun disc with soft hot core
			float d_sun = distance(uv, sun_pos);
			float core = smoothstep(sun_radius, 0.0, d_sun);
			float glow = smoothstep(sun_radius * 7.0, 0.0, d_sun);
			col = mix(col, c_sun_glow.rgb, glow * 0.45);
			col = mix(col, c_sun_core.rgb, core);

			// Radial godrays — sample noise along a ray from each pixel toward sun
			vec2 to_sun = sun_pos - uv;
			float ray_len = length(to_sun);
			vec2 step = to_sun / 12.0;
			float ray = 0.0;
			vec2 sp = uv;
			for (int i = 0; i < 12; i++) {
				sp += step;
				float n = fbm(sp * vec2(8.0, 4.0));
				ray += smoothstep(0.55, 0.95, n);
			}
			ray /= 12.0;
			float ray_fall = smoothstep(0.8, 0.0, ray_len);
			col += c_sun_glow.rgb * ray * ray_fall * godray_strength;

			// Horizontal banding stripes (very subtle)
			float band = sin(uv.y * 28.0 + uv.x * 1.4) * 0.008;
			col += band;

			COLOR = vec4(col, 1.0);
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sun_pos", SUN_POS_FRAC)
	mat.set_shader_parameter("sun_radius", 0.045)
	rect.material = mat
	add_child(rect)


# ----- 3: cloud bands -----
func _build_cloud_bands() -> void:
	var rect := ColorRect.new()
	rect.position = Vector2(world_bounds.position.x, world_bounds.position.y)
	rect.size = Vector2(world_bounds.size.x, HORIZON_Y - world_bounds.position.y + 40.0)
	rect.z_index = -1
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 cloud_light : source_color = vec4(0.95, 0.78, 0.62, 1.0);
		uniform vec4 cloud_dark  : source_color = vec4(0.22, 0.16, 0.28, 1.0);
		uniform vec4 cloud_rim   : source_color = vec4(1.00, 0.85, 0.55, 1.0);
		uniform float speed = 0.012;
		uniform float band_count : hint_range(1.0, 5.0) = 3.0;

		float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
		float vnoise(vec2 p) {
			vec2 i = floor(p); vec2 f = fract(p);
			float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
			vec2 u = f * f * (3.0 - 2.0 * f);
			return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
		}
		float fbm(vec2 p) {
			float s = 0.0; float w = 0.5;
			for (int i = 0; i < 5; i++) {
				s += vnoise(p) * w; p *= 2.07; w *= 0.5;
			}
			return s;
		}

		float cloud_mask(vec2 uv, float band_y, float thickness, float scroll, float scale) {
			float v = abs(uv.y - band_y);
			float band = smoothstep(thickness, thickness * 0.25, v);
			vec2 cp = vec2(uv.x * scale + scroll, uv.y * scale * 1.4);
			float n = fbm(cp);
			float density = smoothstep(0.46, 0.78, n);
			return density * band;
		}

		void fragment() {
			vec2 uv = UV;
			float t = TIME * speed;

			// Three bands at different heights, scales, scroll speeds.
			float c1 = cloud_mask(uv, 0.18, 0.13, t * 1.0,  3.0);
			float c2 = cloud_mask(uv, 0.34, 0.16, t * 0.6,  2.2);
			float c3 = cloud_mask(uv, 0.55, 0.12, t * 1.6,  4.5);

			vec3 col = vec3(0.0);
			float a = 0.0;

			// Top band — cool / shadowed
			col += mix(cloud_dark.rgb, cloud_light.rgb, smoothstep(0.0, 0.7, c1)) * c1;
			a += c1;

			// Mid band — sun-lit on the bottom edge (rim light from below)
			float rim2 = smoothstep(0.30, 0.50, c2) - smoothstep(0.50, 0.65, c2);
			col += mix(cloud_dark.rgb, cloud_light.rgb, smoothstep(0.0, 0.6, c2)) * c2;
			col += cloud_rim.rgb * rim2 * 0.6;
			a += c2;

			// Low band — warm sunlit
			col += mix(cloud_dark.rgb, cloud_rim.rgb, smoothstep(0.0, 0.5, c3)) * c3;
			a += c3;

			COLOR = vec4(col, clamp(a * 0.85, 0.0, 0.92));
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)


# ----- 4: horizon haze -----
func _build_horizon_haze() -> void:
	var rect := ColorRect.new()
	rect.position = Vector2(world_bounds.position.x, HORIZON_Y - 80.0)
	rect.size = Vector2(world_bounds.size.x, 160.0)
	rect.z_index = 2
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 col : source_color = vec4(0.85, 0.55, 0.42, 0.78);
		void fragment() {
			float a = smoothstep(0.0, 0.55, 1.0 - UV.y);
			a *= smoothstep(0.0, 0.25, UV.y);
			COLOR = vec4(col.rgb, col.a * a);
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)


# ----- 5: Distant birds (silhouettes) -----
func _build_bird_flock() -> void:
	# A few V-shape silhouette flocks drifting slowly across the sky.
	for i in range(3):
		var flock := Node2D.new()
		flock.position = Vector2(
			lerpf(world_bounds.position.x, world_bounds.end.x, 0.20 + i * 0.32),
			world_bounds.position.y + 120.0 + i * 50.0,
		)
		flock.set_meta("speed", 9.0 + i * 4.0)
		add_child(flock)
		for j in range(7):
			var b := Polygon2D.new()
			b.color = Color(0.06, 0.05, 0.10, 0.85)
			var fx: float = (j - 3) * 18.0
			var fy: float = abs(j - 3) * 9.0
			b.polygon = PackedVector2Array([
				Vector2(fx - 6, fy + 2), Vector2(fx, fy - 1),
				Vector2(fx + 6, fy + 2), Vector2(fx, fy + 1),
			])
			flock.add_child(b)


func _process(delta: float) -> void:
	# Slow flock drift
	for child in get_children():
		if child is Node2D and child.has_meta("speed"):
			var spd: float = float(child.get_meta("speed"))
			child.position.x += spd * delta
			if child.position.x > world_bounds.end.x + 200.0:
				child.position.x = world_bounds.position.x - 200.0
