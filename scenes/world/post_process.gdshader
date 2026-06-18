// v0.90.6 — global screen-space post-process applied via a CanvasLayer that
// covers the viewport. Reads SCREEN_TEXTURE, writes a cinematic grade:
// vignette darkening, contrast boost, saturation lift, subtle warm-shadow /
// cool-highlight split. This is the single biggest visual identity shift —
// the game now LOOKS color-graded instead of raw procedural.

shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.85;
uniform float contrast : hint_range(0.5, 2.0) = 1.18;
uniform float saturation : hint_range(0.0, 2.0) = 1.22;
uniform float brightness : hint_range(-0.5, 0.5) = -0.04;
uniform vec3 shadow_tint : source_color = vec3(0.88, 0.92, 1.05);   // cool shadows
uniform vec3 highlight_tint : source_color = vec3(1.08, 1.02, 0.88); // warm highlights
uniform float bloom_threshold : hint_range(0.5, 1.0) = 0.82;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.35;

vec3 adjust_saturation(vec3 c, float s) {
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), c, s);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = textureLod(SCREEN_TEXTURE, uv, 0.0).rgb;

	// Contrast + brightness
	vec3 col = (src - 0.5) * contrast + 0.5 + brightness;

	// Shadow/highlight split-tone: lerp toward shadow_tint in dark areas,
	// toward highlight_tint in bright areas.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.2, 0.85, lum));
	col *= tint;

	// Saturation
	col = adjust_saturation(col, saturation);

	// Cheap bloom: sample neighbors, keep bright parts, blur, add back.
	vec2 ps = SCREEN_PIXEL_SIZE * 2.0;
	vec3 b = vec3(0.0);
	b += textureLod(SCREEN_TEXTURE, uv + vec2( ps.x,  0.0), 1.0).rgb;
	b += textureLod(SCREEN_TEXTURE, uv + vec2(-ps.x,  0.0), 1.0).rgb;
	b += textureLod(SCREEN_TEXTURE, uv + vec2( 0.0,  ps.y), 1.0).rgb;
	b += textureLod(SCREEN_TEXTURE, uv + vec2( 0.0, -ps.y), 1.0).rgb;
	b *= 0.25;
	float bl = dot(b, vec3(0.299, 0.587, 0.114));
	float bm = smoothstep(bloom_threshold, 1.0, bl);
	col += b * bm * bloom_strength;

	// Vignette
	vec2 cuv = uv - vec2(0.5);
	float d = length(cuv) * 1.41421;
	float vig = smoothstep(vignette_softness, vignette_softness - vignette_strength, d);
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
