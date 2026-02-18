extends Control

## SC:BW-style minimap showing terrain, player dot, and enemy dots.

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

	# Terrain representation (green base)
	draw_rect(Rect2(Vector2(2, 2), MINIMAP_SIZE - Vector2(4, 4)), Color(0.1, 0.2, 0.1))

	# Town area
	var town_minimap_pos = _world_to_minimap(Vector2(0, 0))
	var town_size = Vector2(320, 260) / WORLD_SIZE * MINIMAP_SIZE
	draw_rect(Rect2(town_minimap_pos - town_size / 2, town_size), Color(0.18, 0.3, 0.18))

	# Walls (border)
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.3, 0.25, 0.2), false, 2.0)

	# Camp markers (red dots) — match havens_rest.tscn positions
	var camp_positions = [
		Vector2(-700, -500), Vector2(600, -700), Vector2(-300, -900),
		Vector2(-900, 600), Vector2(400, 800),
		Vector2(1000, 700), Vector2(-1200, -200), Vector2(1300, -500),
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
	var shop_pos = _world_to_minimap(Vector2(110, -40))
	draw_circle(shop_pos, 2.5, Color(1.0, 1.0, 0.3))

	# Player dot (white, blinking)
	if _player and is_instance_valid(_player):
		var ppos = _world_to_minimap(_player.global_position)
		var blink = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(ppos, 3.0, Color(1.0, 1.0, 1.0, blink))

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	# World ranges from -2000,-1500 to 2000,1500
	var normalized = (world_pos + WORLD_SIZE / 2) / WORLD_SIZE
	return normalized * MINIMAP_SIZE
