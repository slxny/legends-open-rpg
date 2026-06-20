extends Control

const HUDStyle := preload("res://revamp/ui/hud_style.gd")


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	HUDStyle.draw_panel(self, rect, 10.0)
	# Sub-divider lines for visual rhythm between slots
	for i in range(1, 8):
		var x: float = i * (size.x / 8.0)
		draw_line(Vector2(x, 12), Vector2(x, size.y - 12), Color(1, 0.85, 0.45, 0.15), 1.0)
	# Gold filigree at all four corners
	HUDStyle.draw_corner_filigree(self, rect.grow(-2.0), 14.0)
	# Gem inlays — sapphire on the long mid-edges (top and bottom centers)
	HUDStyle.draw_gem(self, Vector2(size.x * 0.5, 4.0), 3.0, HUDStyle.SAPPHIRE)
	HUDStyle.draw_gem(self, Vector2(size.x * 0.5, size.y - 4.0), 3.0, HUDStyle.SAPPHIRE)
	# Emerald accent gems at vertical mid edges
	HUDStyle.draw_gem(self, Vector2(4.0, size.y * 0.5), 3.0, HUDStyle.EMERALD)
	HUDStyle.draw_gem(self, Vector2(size.x - 4.0, size.y * 0.5), 3.0, HUDStyle.EMERALD)
