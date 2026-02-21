extends Control
class_name SCBar

## SC:BW-style segmented health/mana/xp bar.
## Draws discrete block segments that change color based on fill %.

@export var max_val: float = 100.0
@export var current_val: float = 100.0
@export var bar_mode: int = 0  # 0 = HP (green/yellow/red), 1 = mana (blue), 2 = XP (purple)
@export var segment_count: int = 0  # 0 = auto-calculate from max_val
@export var show_label: bool = true
@export var label_text: String = ""

var _label_settings: LabelSettings = null
var _is_mobile: bool = false

func _ready() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)
	_label_settings = LabelSettings.new()
	_label_settings.font_size = 24 if _is_mobile else 13
	_label_settings.font_color = Color(0.95, 0.95, 0.95)
	_label_settings.outline_size = 3 if _is_mobile else 2
	_label_settings.outline_color = Color(0, 0, 0)

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

	# Determine segment count
	var segs = segment_count
	if segs <= 0:
		segs = clampi(int(max_val / 10.0), 4, 40)

	var seg_gap = 1.0
	var total_gaps = (segs - 1) * seg_gap
	var seg_width = (inner_size.x - total_gaps) / float(segs)
	if seg_width < 2.0:
		seg_width = 2.0
		segs = int((inner_size.x + seg_gap) / (seg_width + seg_gap))

	var filled_segs = int(ceil(ratio * segs))

	# Get bar color based on mode and fill ratio
	var bar_color = _get_bar_color(ratio)
	var bar_color_dark = bar_color.darkened(0.3)

	for i in range(segs):
		var seg_x = inner_pos.x + i * (seg_width + seg_gap)
		var seg_rect = Rect2(Vector2(seg_x, inner_pos.y), Vector2(seg_width, inner_size.y))

		if i < filled_segs:
			# Filled segment — slight gradient (top lighter)
			draw_rect(seg_rect, bar_color)
			# Highlight on top pixel row
			var highlight_rect = Rect2(seg_rect.position, Vector2(seg_rect.size.x, max(1, seg_rect.size.y * 0.3)))
			draw_rect(highlight_rect, bar_color.lightened(0.25))
		else:
			# Empty segment — very dark
			draw_rect(seg_rect, Color(0.06, 0.06, 0.08))

	# Label overlay
	if show_label and not label_text.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = 24 if _is_mobile else 13
		var text_width = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var x_pos = (bar_size.x - text_width) / 2.0
		var y_pos = bar_size.y / 2.0 + font_size / 2.0 - 1
		# Shadow for readability
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
