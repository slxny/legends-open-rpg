extends Control

## Minimap showing terrain, player dot, enemy dots, and fog of war overlay.
## Click anywhere on the minimap to move the player to that world position.

const MINIMAP_SIZE = Vector2(180, 130)
const WORLD_SIZE = Vector2(12000, 9000)  # Haven's Rest total area
const FOG_CELL_SIZE_ON_MAP := Vector2(
	180.0 / (12000.0 / 64.0),
	130.0 / (9000.0 / 64.0)
)

var _player: Node2D = null
var _redraw_timer: float = 0.0
const REDRAW_INTERVAL: float = 0.25  # Redraw 4 times per second, not 60

func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	FogOfWarManager.fog_updated.connect(queue_redraw)

func setup(player: Node2D) -> void:
	_player = player

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position
		# Clamp to minimap bounds
		local_pos = local_pos.clamp(Vector2.ZERO, MINIMAP_SIZE)
		var world_pos = _minimap_to_world(local_pos)
		if _player and is_instance_valid(_player) and _player.has_method("move_to"):
			_player.move_to(world_pos)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Throttle minimap redraws to ~4 FPS instead of 60
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()

func _draw() -> void:
	# Background (unexplored = black)
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.02, 0.02, 0.02, 0.95))

	# Draw explored terrain with fog states
	_draw_fog_overlay()

	# Town area (if explored)
	var town_center = Vector2(0, 0)
	if FogOfWarManager.is_explored(town_center):
		var town_rect = Rect2(
			_world_to_minimap(Vector2(-500, -400)),
			_world_to_minimap(Vector2(500, 400)) - _world_to_minimap(Vector2(-500, -400))
		)
		draw_rect(town_rect, Color(0.18, 0.3, 0.18))

	# Border
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.3, 0.25, 0.2), false, 2.0)

	# Camp markers (red dots) — only if explored
	var camp_positions = [
		# Goblins
		Vector2(-1200, -900), Vector2(1100, -1100), Vector2(-700, -1600), Vector2(600, 800),
		# Wolves
		Vector2(-2200, 1200), Vector2(900, 1800), Vector2(2400, -700), Vector2(-1800, -1800),
		# Bandits
		Vector2(3000, 1600), Vector2(-3500, -700), Vector2(3800, -1500),
		Vector2(-2800, 2400), Vector2(-4200, -2500), Vector2(4400, 3000),
	]
	for camp_pos in camp_positions:
		if FogOfWarManager.is_explored(camp_pos):
			var mpos = _world_to_minimap(camp_pos)
			draw_circle(mpos, 2.5, Color(0.8, 0.2, 0.2, 0.7))

	# Enemy dots (live enemies) — only if currently visible
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and FogOfWarManager.is_visible(enemy.global_position):
			var epos = _world_to_minimap(enemy.global_position)
			draw_circle(epos, 1.5, Color(1.0, 0.3, 0.3, 0.8))

	# Shop marker (yellow) — only if explored
	var shop_world_pos = Vector2(260, -100)
	if FogOfWarManager.is_explored(shop_world_pos):
		var shop_pos = _world_to_minimap(shop_world_pos)
		draw_circle(shop_pos, 2.5, Color(1.0, 1.0, 0.3))

	# Player dot (white, blinking)
	if _player and is_instance_valid(_player):
		var ppos = _world_to_minimap(_player.global_position)
		var blink = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(ppos, 3.0, Color(1.0, 1.0, 1.0, blink))

func _draw_fog_overlay() -> void:
	# Draw explored/visible areas as colored cells
	for cell in FogOfWarManager.explored_tiles:
		var world_pos = Vector2(cell.x * 64, cell.y * 64)
		var minimap_pos = _world_to_minimap(world_pos)
		var is_vis = FogOfWarManager.visible_tiles.has(cell)
		var color: Color
		if is_vis:
			color = Color(0.1, 0.2, 0.1, 0.9)  # Visible: full bright
		else:
			color = Color(0.06, 0.1, 0.06, 0.9)  # Explored: dim
		draw_rect(Rect2(minimap_pos, FOG_CELL_SIZE_ON_MAP), color)

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var normalized = (world_pos + WORLD_SIZE / 2.0) / WORLD_SIZE
	return normalized * MINIMAP_SIZE

func _minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var normalized = minimap_pos / MINIMAP_SIZE
	return normalized * WORLD_SIZE - WORLD_SIZE / 2.0
