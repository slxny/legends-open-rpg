shader_type canvas_item;

// v0.91.5 — outline + top-light fake directional lighting in one pass.
// Top of sprite brighter, bottom darker — consistent with all enemies.

uniform vec4 outline_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform bool enabled = false;
uniform float top_lift : hint_range(0.0, 0.5) = 0.22;
uniform float bottom_dim : hint_range(0.0, 0.5) = 0.14;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (enabled && col.a < 0.5) {
		vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
		float a = texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
		a = max(a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
		if (a > 0.5) {
			col = outline_color;
		}
		COLOR = col;
	} else {
		float lift = top_lift * (1.0 - UV.y);
		float dim = bottom_dim * UV.y;
		vec3 lit = col.rgb + vec3(lift) - vec3(dim);
		COLOR = vec4(clamp(lit, 0.0, 2.0), col.a);
	}
}
