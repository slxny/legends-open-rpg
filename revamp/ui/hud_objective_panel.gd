extends Control

const HUDStyle := preload("res://revamp/ui/hud_style.gd")


func _draw() -> void:
	# Centered banner with chevron caps
	var inner := Rect2(Vector2(40, 0), Vector2(size.x - 80, size.y))
	HUDStyle.draw_panel(self, inner, 6.0)
	# Chevron caps
	var l_pts := PackedVector2Array([
		Vector2(20, 6), Vector2(40, 0), Vector2(40, size.y),
		Vector2(20, size.y - 6),
	])
	var r_pts := PackedVector2Array([
		Vector2(size.x - 20, 6), Vector2(size.x - 40, 0), Vector2(size.x - 40, size.y),
		Vector2(size.x - 20, size.y - 6),
	])
	draw_colored_polygon(l_pts, HUDStyle.FRAME_BG)
	draw_colored_polygon(r_pts, HUDStyle.FRAME_BG)
	draw_polyline(l_pts, HUDStyle.FRAME_GOLD, 1.5)
	draw_polyline(r_pts, HUDStyle.FRAME_GOLD, 1.5)
	# Gold filigree at the four corners of the inner panel
	HUDStyle.draw_corner_filigree(self, inner.grow(-2.0), 10.0)
	# Ruby gem inlay at each chevron cap tip
	HUDStyle.draw_gem(self, Vector2(22.0, size.y * 0.5), 3.5, HUDStyle.RUBY)
	HUDStyle.draw_gem(self, Vector2(size.x - 22.0, size.y * 0.5), 3.5, HUDStyle.RUBY)
	# Small accent gems at top/bottom center of the banner
	HUDStyle.draw_gem(self, Vector2(size.x * 0.5, 4.0), 2.5, HUDStyle.SAPPHIRE)
	HUDStyle.draw_gem(self, Vector2(size.x * 0.5, size.y - 4.0), 2.5, HUDStyle.SAPPHIRE)
