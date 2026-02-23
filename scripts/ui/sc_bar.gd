extends Control
class_name SCBar

## Smooth health/mana/xp bar with color based on fill %.

@export var max_val: float = 100.0
@export var current_val: float = 100.0
@export var bar_mode: int = 0  # 0 = HP (green/yellow/red), 1 = mana (blue), 2 = XP (purple)
@export var show_label: bool = true
@export var label_text: String = ""

func set_value(current: float, maximum: float) -> void:
	if current_val == current and max_val == maximum:
		return  # No change — skip expensive redraw
	current_val = current
	max_val = maximum
	queue_redraw()

func _draw() -> void:
	var bar_size = size
	var border = 1.0

	# Black background with dark border
	draw_rect(Rect2(Vector2.ZERO, bar_size), Color(0.12, 0.12, 0.12))
	draw_rect(Rect2(Vector2.ZERO, bar_size), Color(0.25, 0.25, 0.3), false, border)

	# Inner area
	var inner_pos = Vector2(border + 1, border + 1)
	var inner_size = bar_size - Vector2((border + 1) * 2, (border + 1) * 2)

	if max_val <= 0 or inner_size.x <= 0 or inner_size.y <= 0:
		return

	var ratio = clampf(current_val / max_val, 0.0, 1.0)
	var bar_color = _get_bar_color(ratio)

	# Filled portion — smooth, no segments
	if ratio > 0.0:
		var fill_w = inner_size.x * ratio
		var fill_rect = Rect2(inner_pos, Vector2(fill_w, inner_size.y))
		draw_rect(fill_rect, bar_color)
		# Highlight strip on top 30% for depth
		var hl_rect = Rect2(inner_pos, Vector2(fill_w, max(1, inner_size.y * 0.3)))
		draw_rect(hl_rect, bar_color.lightened(0.25))

	# Empty portion
	if ratio < 1.0:
		var empty_x = inner_pos.x + inner_size.x * ratio
		var empty_w = inner_size.x * (1.0 - ratio)
		draw_rect(Rect2(Vector2(empty_x, inner_pos.y), Vector2(empty_w, inner_size.y)), Color(0.06, 0.06, 0.08))

	# Label overlay — font auto-scales to bar height
	if show_label and not label_text.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = clampi(int(bar_size.y * 0.6), 9, 32)
		var text_width = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var x_pos = (bar_size.x - text_width) / 2.0
		var y_pos = bar_size.y / 2.0 + font_size / 2.0 - 1
		draw_string(font, Vector2(x_pos + 1, y_pos + 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(x_pos, y_pos), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.95, 0.95))

func _get_bar_color(ratio: float) -> Color:
	match bar_mode:
		0:  # HP: green → yellow → red
			if ratio > 0.66:
				return Color(0.15, 0.72, 0.15)
			elif ratio > 0.33:
				return Color(0.8, 0.75, 0.1)
			else:
				return Color(0.8, 0.15, 0.1)
		1:  # Mana: blue
			return Color(0.2, 0.35, 0.85)
		2:  # XP: purple/violet
			return Color(0.55, 0.3, 0.8)
		_:
			return Color(0.5, 0.5, 0.5)
