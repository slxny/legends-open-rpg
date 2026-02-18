extends Control

## SC:BW-style minimap showing terrain, player dot, and enemy dots.
## Positions are mapped through the isometric projection so the minimap
## shows the diamond-shaped world.

const MINIMAP_SIZE = Vector2(180, 130)
const WORLD_SIZE = Vector2(4000, 3000)  # Haven's Rest total area

var _player: Node2D = null

func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE

func setup(player: Node2D) -> void:
	_player = player

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Background (dark, like SC:BW minimap)
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.05, 0.08, 0.05, 0.9))

	# Draw the isometric diamond terrain shape
	var center = MINIMAP_SIZE / 2.0
	# The world corners in iso space form a diamond
	var corners = [
		_world_to_minimap(Vector2(-2000, 0)),   # Left point
		_world_to_minimap(Vector2(0, -1500)),    # Top point
		_world_to_minimap(Vector2(2000, 0)),     # Right point
		_world_to_minimap(Vector2(0, 1500)),     # Bottom point
	]
	var terrain_color = Color(0.1, 0.2, 0.1)
	draw_colored_polygon(PackedVector2Array(corners), terrain_color)

	# Town area diamond
	var town_corners = [
		_world_to_minimap(Vector2(-500, 0)),
		_world_to_minimap(Vector2(0, -400)),
		_world_to_minimap(Vector2(500, 0)),
		_world_to_minimap(Vector2(0, 400)),
	]
	draw_colored_polygon(PackedVector2Array(town_corners), Color(0.18, 0.3, 0.18))

	# Border
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.3, 0.25, 0.2), false, 2.0)

	# Camp markers (red dots) — match havens_rest.tscn positions
	var camp_positions = [
		Vector2(-900, -700), Vector2(800, -900), Vector2(-500, -1300),
		Vector2(-1400, 800), Vector2(600, 1200), Vector2(1600, -400),
		Vector2(1800, 1000), Vector2(-2200, -400), Vector2(2400, -900),
		Vector2(-1800, 1400),
	]
	for camp_pos in camp_positions:
		var mpos = _world_to_minimap(camp_pos)
		draw_circle(mpos, 2.5, Color(0.8, 0.2, 0.2, 0.7))

	# Enemy dots (live enemies)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var epos = _world_to_minimap(enemy.global_position)
			draw_circle(epos, 1.5, Color(1.0, 0.3, 0.3, 0.8))

	# Shop marker (yellow)
	var shop_pos = _world_to_minimap(Vector2(260, -100))
	draw_circle(shop_pos, 2.5, Color(1.0, 1.0, 0.3))

	# Player dot (white, blinking)
	if _player and is_instance_valid(_player):
		var ppos = _world_to_minimap(_player.global_position)
		var blink = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(ppos, 3.0, Color(1.0, 1.0, 1.0, blink))

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	# Convert world position through iso projection, then map to minimap rect.
	# Iso screen range: X spans ~(-2000-1500) to (2000+1500) = -3500 to 3500
	#                   Y spans ~(-2000+1500)*0.5 to (2000+1500)*0.5 = -250 to 1750
	# But we center it.
	var iso_pos = IsometricHelper.world_to_screen(world_pos)
	# Iso screen extents: widest X = world_x - world_y, widest Y = (world_x + world_y)/2
	var iso_size = Vector2(7000.0, 3500.0)  # Full range of iso-projected coords
	var normalized = (iso_pos + iso_size / 2.0) / iso_size
	return normalized * MINIMAP_SIZE
