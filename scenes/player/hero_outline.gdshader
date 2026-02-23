shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.2, 1.0, 0.3, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform bool enabled = false;

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
	}
	COLOR = col;
}
