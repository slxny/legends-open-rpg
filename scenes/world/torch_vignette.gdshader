// v0.93.3 — softened from the brutal-dark torch into a painterly fantasy
// vignette: warm sun-touched inner area, cool teal-haze corners, gentler
// darkness (0.78 -> 0.46), wider inner (0.18 -> 0.30) so the playable
// area sits in pleasant afternoon light.

shader_type canvas_item;
render_mode blend_mix;

uniform vec2 focus_uv = vec2(0.5, 0.5);
uniform float inner_radius : hint_range(0.05, 0.7) = 0.30;
uniform float outer_radius : hint_range(0.2, 1.4) = 1.05;
uniform float darkness : hint_range(0.0, 1.0) = 0.46;
// Warm sun tint that LIFTS the inner area (gold-cream).
uniform vec3 torch_color : source_color = vec3(1.18, 1.05, 0.70);
uniform float torch_strength : hint_range(0.0, 1.0) = 0.22;
// Atmospheric cool haze for the edges (teal-blue dusk).
uniform vec3 night_color : source_color = vec3(0.20, 0.26, 0.36);

void fragment() {
	// Aspect-corrected distance from focus.
	vec2 d = SCREEN_UV - focus_uv;
	// Approximate aspect from viewport pixel size: SCREEN_PIXEL_SIZE.x / .y is
	// inverse aspect, so multiply x distance by aspect to get a circular fall-off.
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(d);

	// 0 inside inner_radius, ramping to 1 at outer_radius.
	float fall = smoothstep(inner_radius, outer_radius, dist);

	// Output color: tint torch_color toward night_color as fall increases.
	// Alpha encodes darkness: at centre alpha is 0 (transparent), at edges
	// alpha is darkness (multiplied by night_color).
	float a = fall * darkness;

	// Torch lift at the centre (negative fall): adds warm cream tint slightly.
	float lift = (1.0 - fall) * torch_strength;
	vec3 col = mix(torch_color, night_color, fall);
	// Premultiplied output: at centre we want to brighten via additive lift,
	// at edges we want to darken via alpha-blend with night_color.
	COLOR = vec4(col, a);
	// Additive lift for the inner glow (small).
	COLOR.rgb += torch_color * lift * 0.5;
}
