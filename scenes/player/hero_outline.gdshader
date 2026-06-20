shader_type canvas_item;

// v0.92.4 — thicker outline + much stronger top-light + warm rim highlight.
// Matches the pronounced pixel-art treatment now applied to every enemy.

uniform vec4 outline_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform bool enabled = false;
uniform float top_lift : hint_range(0.0, 0.6) = 0.40;
uniform float bottom_dim : hint_range(0.0, 0.5) = 0.26;
uniform vec3 rim_color : source_color = vec3(1.20, 1.00, 0.70);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (enabled && col.a < 0.5) {
		// Thicker outline: 2-pixel ring.
		vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
		float a = 0.0;
		for (int dx = -2; dx <= 2; dx++) {
			for (int dy = -2; dy <= 2; dy++) {
				if (dx == 0 && dy == 0) continue;
				float dist_sq = float(dx * dx + dy * dy);
				if (dist_sq > 5.0) continue;
				a = max(a, texture(TEXTURE, UV + vec2(float(dx) * ps.x, float(dy) * ps.y)).a);
			}
		}
		if (a > 0.5) {
			col = outline_color;
		}
		COLOR = col;
	} else {
		float lift = top_lift * (1.0 - UV.y);
		float dim = bottom_dim * UV.y;
		vec3 lit = col.rgb + vec3(lift) - vec3(dim);
		// Warm rim at top.
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float above = texture(TEXTURE, UV + vec2(0.0, -ps.y * 2.0)).a;
		float rim_mask = (1.0 - above) * step(UV.y, 0.32);
		lit += rim_color * rim_mask * rim_strength;
		COLOR = vec4(clamp(lit, 0.0, 2.0), col.a);
	}
}
