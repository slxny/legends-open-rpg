// v0.92.9 — radial TORCH VIGNETTE around the player. Soft warm-orange glow
// at the centre, hard fall-off to deep navy darkness at the screen edges.
// Drawn full-screen on a CanvasLayer that tracks the player. Creates the
// brutal hack-and-slash "lit clearing in a dark world" focal frame without
// any actual Light2D setup.

shader_type canvas_item;
render_mode blend_mix;

// World-space player position projected to screen UV (set every frame).
uniform vec2 focus_uv = vec2(0.5, 0.5);
// Inner bright radius in UV units (0..1). Centre of the lit clearing.
uniform float inner_radius : hint_range(0.05, 0.6) = 0.18;
// Outer fall-off radius. Past this, darkness multiplier is full.
uniform float outer_radius : hint_range(0.2, 1.4) = 0.95;
// How dark the corners get. 0 = no vignette, 1 = pure black corners.
uniform float darkness : hint_range(0.0, 1.0) = 0.78;
// Warm torch tint that LIFTS the inner area.
uniform vec3 torch_color : source_color = vec3(1.35, 0.92, 0.55);
// How much the torch tint adds at centre.
uniform float torch_strength : hint_range(0.0, 1.0) = 0.35;
// Cool deep navy that COOLS the dark corners.
uniform vec3 night_color : source_color = vec3(0.18, 0.14, 0.28);

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
