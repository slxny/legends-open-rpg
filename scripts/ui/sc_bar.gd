extends Control
class_name SCBar

## v0.92.6 — pleasant UI bar pass: rounded corners, vertical gradient,
## glowing outer rim, pulsing low-HP warning, brighter text. Drop-in
## replacement for the old flat-rectangle SCBar — same set_value API.

@export var max_val: float = 100.0
@export var current_val: float = 100.0
@export var bar_mode: int = 0  # 0 = HP, 1 = mana, 2 = XP
@export var show_label: bool = true
@export var label_text: String = ""

var _pulse_t: float = 0.0  # 0..1 sin wave for low-HP pulse
const _CORNER_RADIUS: float = 6.0
const _OUTER_GLOW: float = 2.0
const _LOW_HP_PULSE_RATIO: float = 0.30

func _ready() -> void:
	# Pulse animation runs at all times; redraw triggered when low HP.
	set_process(true)

func _process(delta: float) -> void:
	if max_val <= 0:
		return
	var ratio: float = current_val / max_val
	if bar_mode == 0 and ratio <= _LOW_HP_PULSE_RATIO:
		_pulse_t = fmod(_pulse_t + delta * 3.2, TAU)
		queue_redraw()

func set_value(current: float, maximum: float) -> void:
	if current_val == current and max_val == maximum:
		return  # No change — skip expensive redraw
	current_val = current
	max_val = maximum
	queue_redraw()

func _draw() -> void:
	var bar_size = size
	if bar_size.x <= 0 or bar_size.y <= 0 or max_val <= 0:
		return

	var ratio = clampf(current_val / max_val, 0.0, 1.0)
	var bar_color = _get_bar_color(ratio)

	# Pulse (low HP only): add a slight brightening to the bar color.
	if bar_mode == 0 and ratio <= _LOW_HP_PULSE_RATIO:
		var pulse_amt: float = (sin(_pulse_t) + 1.0) * 0.5  # 0..1
		bar_color = bar_color.lerp(Color(1.6, 0.4, 0.4), pulse_amt * 0.55)

	# Outer GLOW rim (sized larger than bar). Drawn first so bar sits on top.
	var glow_alpha: float = clampf(ratio * 0.6 + 0.1, 0.1, 0.6)
	var glow_color: Color = Color(bar_color.r, bar_color.g, bar_color.b, glow_alpha)
	_fill_rounded_rect(Rect2(Vector2(-_OUTER_GLOW, -_OUTER_GLOW), bar_size + Vector2(_OUTER_GLOW, _OUTER_GLOW) * 2.0), _CORNER_RADIUS + _OUTER_GLOW, glow_color)

	# Bar BACKGROUND — dark warm with subtle border lightening.
	_fill_rounded_rect(Rect2(Vector2.ZERO, bar_size), _CORNER_RADIUS, Color(0.08, 0.07, 0.10, 0.95))

	# Inner area inset 2 px so the fill clears the border ring.
	var inset: float = 2.0
	var inner_pos = Vector2(inset, inset)
	var inner_size = bar_size - Vector2(inset * 2.0, inset * 2.0)
	if inner_size.x <= 0 or inner_size.y <= 0:
		return

	# Filled portion — vertical gradient (lighter at top, darker at bottom).
	if ratio > 0.0:
		var fill_w: float = inner_size.x * ratio
		var fill_rect = Rect2(inner_pos, Vector2(fill_w, inner_size.y))
		var top_col: Color = bar_color.lightened(0.30)
		var bot_col: Color = bar_color.darkened(0.18)
		# 5-stripe pseudo-gradient (Godot Control has no native gradient draw).
		var slice_h: float = inner_size.y / 5.0
		for i in range(5):
			var f: float = float(i) / 4.0
			var stripe_color: Color = top_col.lerp(bot_col, f)
			var stripe_rect = Rect2(
				Vector2(inner_pos.x, inner_pos.y + slice_h * float(i)),
				Vector2(fill_w, slice_h + 0.5)
			)
			_fill_rounded_rect_clipped(stripe_rect, fill_rect, _CORNER_RADIUS - inset, stripe_color)
		# Bright SHEEN strip on top 20%.
		var sheen_h: float = max(1.0, inner_size.y * 0.18)
		var sheen_rect = Rect2(inner_pos, Vector2(fill_w, sheen_h))
		_fill_rounded_rect_clipped(sheen_rect, fill_rect, _CORNER_RADIUS - inset, Color(1, 1, 1, 0.35))

	# Subtle TICK marks every 25% (faint vertical lines on the dark base).
	for i in range(1, 4):
		var tick_x: float = inner_pos.x + inner_size.x * (float(i) * 0.25)
		draw_line(Vector2(tick_x, inner_pos.y + 2), Vector2(tick_x, inner_pos.y + inner_size.y - 2), Color(1, 1, 1, 0.08))

	# Label overlay — bigger, bolder, with shadow.
	if show_label and not label_text.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = clampi(int(bar_size.y * 0.65), 11, 32)
		var text_width = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var x_pos = (bar_size.x - text_width) / 2.0
		var y_pos = bar_size.y / 2.0 + font_size / 2.0 - 2
		# Soft shadow.
		draw_string(font, Vector2(x_pos + 1, y_pos + 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
		# Main text.
		draw_string(font, Vector2(x_pos, y_pos), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.98))

func _fill_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	# Compose a rounded rect from a central rect + 2 side rects + 4 corner circles.
	var r: float = clampf(radius, 0.0, min(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.1:
		draw_rect(rect, color)
		return
	# Center cross.
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(r, rect.size.y - r * 2.0)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - r, r), Vector2(r, rect.size.y - r * 2.0)), color)
	# 4 corners as quarter-circles approximated with draw_circle (full circle, masked).
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)

func _fill_rounded_rect_clipped(stripe_rect: Rect2, container_rect: Rect2, radius: float, color: Color) -> void:
	# Used for fill stripes inside a rounded container. Just draw a flat rect
	# clipped to the container's bounding box — corners are handled by the
	# container's underlying rounded shape (background is dark, edges blend).
	var clipped = stripe_rect.intersection(container_rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	# Round edges by drawing two small corner circles where appropriate.
	var r: float = clampf(radius, 0.0, min(container_rect.size.x, container_rect.size.y) * 0.5)
	# Always-rect interior.
	draw_rect(clipped, color)
	# Corner rounding only matters at the left edge (start of fill).
	if abs(clipped.position.x - container_rect.position.x) < 0.5 and r > 0.1:
		if abs(clipped.position.y - container_rect.position.y) < 0.5:
			draw_circle(container_rect.position + Vector2(r, r), r, color)
		if abs(clipped.position.y + clipped.size.y - container_rect.position.y - container_rect.size.y) < 0.5:
			draw_circle(container_rect.position + Vector2(r, container_rect.size.y - r), r, color)

func _get_bar_color(ratio: float) -> Color:
	match bar_mode:
		0:  # HP — saturated greens to warm yellow to red.
			if ratio > 0.66:
				return Color(0.28, 0.85, 0.30)
			elif ratio > 0.33:
				return Color(0.95, 0.78, 0.15)
			else:
				return Color(0.92, 0.22, 0.18)
		1:  # Mana — bright cyan-blue.
			return Color(0.30, 0.55, 1.00)
		2:  # XP — vibrant magenta-purple.
			return Color(0.78, 0.36, 0.95)
		_:
			return Color(0.7, 0.7, 0.7)
