extends CanvasLayer

## Top-of-screen effects layer — vignette, damage flash, death fade,
## respawn pulse, low-HP heartbeat tint. Sits BELOW the HUD layer.

var _vignette: ColorRect
var _flash: ColorRect
var _fade: ColorRect
var _t: float = 0.0
var _low_hp_active: bool = false
var _player_ref: Node


func _ready() -> void:
	layer = 5
	_build()


func _build() -> void:
	_vignette = _make_vignette()
	add_child(_vignette)
	_flash = _make_color_rect(Color(1, 0.25, 0.25, 0.0))
	add_child(_flash)
	_fade = _make_color_rect(Color(0, 0, 0, 0.0))
	add_child(_fade)


func _make_color_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.anchor_left = 0
	r.anchor_top = 0
	r.anchor_right = 1
	r.anchor_bottom = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _make_vignette() -> ColorRect:
	var r := ColorRect.new()
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec4 inner_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
		uniform vec4 outer_color : source_color = vec4(0.0, 0.0, 0.05, 0.85);
		uniform float radius : hint_range(0.1, 1.5) = 0.95;
		uniform float softness : hint_range(0.01, 1.5) = 0.65;
		uniform float pulse : hint_range(0.0, 1.0) = 0.0;
		uniform vec4 pulse_color : source_color = vec4(1.0, 0.15, 0.2, 0.45);
		void fragment() {
			vec2 uv = UV - vec2(0.5);
			uv.x *= 1.6;
			float d = length(uv);
			float v = smoothstep(radius - softness, radius, d);
			vec4 base = mix(inner_color, outer_color, v);
			vec4 tint = mix(base, pulse_color, pulse * smoothstep(0.0, radius, d));
			COLOR = tint;
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	r.material = mat
	r.anchor_left = 0
	r.anchor_top = 0
	r.anchor_right = 1
	r.anchor_bottom = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func bind_player(p: Node) -> void:
	_player_ref = p
	if p and p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp_changed)


func _process(delta: float) -> void:
	_t += delta
	if _vignette and _vignette.material is ShaderMaterial:
		var mat: ShaderMaterial = _vignette.material
		var p: float = 0.0
		if _low_hp_active:
			p = 0.45 + 0.4 * (sin(_t * 6.0) * 0.5 + 0.5)
		mat.set_shader_parameter("pulse", p)


func play_hit_flash(strength: float = 0.35) -> void:
	if not _flash:
		return
	var tw := create_tween()
	_flash.color = Color(1, 0.18, 0.18, clampf(strength, 0.0, 0.7))
	tw.tween_property(_flash, "color", Color(1, 0.18, 0.18, 0.0), 0.18)


func play_death_fade() -> void:
	if not _fade:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0.85), 0.7)
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0.85), 0.4)
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0.0), 0.6)


func play_respawn_pulse() -> void:
	if not _flash:
		return
	var tw := create_tween()
	_flash.color = Color(0.6, 0.85, 1.0, 0.4)
	tw.tween_property(_flash, "color", Color(0.6, 0.85, 1.0, 0.0), 0.6)


func _on_hp_changed(current: float, maximum: float) -> void:
	var ratio: float = 0.0
	if maximum > 0.0:
		ratio = current / maximum
	_low_hp_active = ratio < 0.35
	if ratio < 0.6:
		play_hit_flash(0.25 * (1.0 - ratio))
