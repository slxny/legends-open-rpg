extends Control

## Minimap showing terrain, player dot, enemy dots, and fog of war overlay.
## Click anywhere on the minimap to move the player to that world position.
## Supports switching between regions (Haven's Rest, dungeon, etc.).

const DEFAULT_SIZE = Vector2(180, 130)

# Region-configurable state (defaults = Haven's Rest)
var world_size: Vector2 = Vector2(12000, 9000)
var camp_markers: Array = [
	Vector2(-1200, -900), Vector2(1100, -1100), Vector2(-700, -1600), Vector2(600, 800),
	Vector2(-2200, 1200), Vector2(900, 1800), Vector2(2400, -700), Vector2(-1800, -1800),
	Vector2(3000, 1600), Vector2(-3500, -700), Vector2(3800, -1500),
	Vector2(-2800, 2400), Vector2(-4200, -2500), Vector2(4400, 3000),
	Vector2(1500, -3500), Vector2(-1500, 3500), Vector2(2000, -4000), Vector2(-2000, 4000),
	Vector2(0, -3000), Vector2(0, 3000), Vector2(1000, 2200), Vector2(-1000, -2200),
	Vector2(-3000, 3000), Vector2(3500, 2600), Vector2(5000, 0), Vector2(-5000, 0),
	Vector2(1200, 3800), Vector2(-1200, -3800), Vector2(5200, 1200), Vector2(-5200, -1200),
	Vector2(5000, -1500), Vector2(-5000, 1500), Vector2(4000, -4000), Vector2(-4000, 4000),
]
var shop_markers: Array = [Vector2(260, -100)]
var town_rect_world: Rect2 = Rect2(-500, -400, 1000, 800)
var show_town: bool = true
var exit_markers: Array = []  # Green dots for dungeon exit beacons
var world_offset: Vector2 = Vector2.ZERO  # Center of the region in world space

# Saved defaults for reset
var _default_world_size: Vector2 = Vector2(12000, 9000)
var _default_camp_markers: Array = []
var _default_shop_markers: Array = []
var _default_town_rect: Rect2 = Rect2(-500, -400, 1000, 800)

var _player: Node2D = null
var _redraw_timer: float = 0.0
var click_to_move_enabled: bool = true:  # When false, clicks pass through to parent
	set(v):
		click_to_move_enabled = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_PASS
const REDRAW_INTERVAL: float = 0.25  # Redraw 4 times per second, not 60
var _cached_enemies: Array = []  # Cached enemy positions for minimap dots
var _cached_bosses: Array = []  # Cached miniboss positions for pulsing diamond indicators
var _cached_explored_rects: Array = []  # Pre-built fog overlay rects
var _fog_dirty: bool = true  # Rebuild fog cache on next draw
var _last_draw_size: Vector2 = Vector2.ZERO  # Invalidate fog cache on resize

func _ready() -> void:
	add_to_group("minimap")
	custom_minimum_size = DEFAULT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	FogOfWarManager.fog_updated.connect(func(): _fog_dirty = true)
	# Save defaults
	_default_camp_markers = camp_markers.duplicate()
	_default_shop_markers = shop_markers.duplicate()

func setup(player: Node2D) -> void:
	_player = player

func set_region(region_world_size: Vector2, camps: Array, shops: Array, town: Rect2, show_town_area: bool, exits: Array = [], offset: Vector2 = Vector2.ZERO) -> void:
	world_size = region_world_size
	world_offset = offset
	camp_markers = camps
	shop_markers = shops
	town_rect_world = town
	show_town = show_town_area
	exit_markers = exits
	_fog_dirty = true
	queue_redraw()

func reset_to_default() -> void:
	world_size = _default_world_size
	world_offset = Vector2.ZERO
	camp_markers = _default_camp_markers.duplicate()
	shop_markers = _default_shop_markers.duplicate()
	town_rect_world = _default_town_rect
	show_town = true
	exit_markers = []
	_fog_dirty = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not click_to_move_enabled:
		return  # Let parent handle the click (e.g. to open expanded overlay)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position
		local_pos = local_pos.clamp(Vector2.ZERO, size)
		var world_pos = _minimap_to_world(local_pos)
		if _player and is_instance_valid(_player) and _player.has_method("move_to"):
			_player.move_to(world_pos)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		_cached_enemies.clear()
		_cached_bosses.clear()
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and FogOfWarManager.is_visible(enemy.global_position):
				if enemy.is_mini_boss:
					_cached_bosses.append(enemy.global_position)
				else:
					_cached_enemies.append(enemy.global_position)
		queue_redraw()

func _draw() -> void:
	var ms = size
	if ms.x < 1 or ms.y < 1:
		return

	# Invalidate fog cache if our size changed
	if ms != _last_draw_size:
		_last_draw_size = ms
		_fog_dirty = true

	# Background (unexplored = black)
	draw_rect(Rect2(Vector2.ZERO, ms), Color(0.02, 0.02, 0.02, 0.95))

	# Draw explored terrain with fog states
	_draw_fog_overlay(ms)

	# Town area (if explored and enabled)
	if show_town and town_rect_world.has_area():
		var town_center = Vector2(town_rect_world.position.x + town_rect_world.size.x / 2.0, town_rect_world.position.y + town_rect_world.size.y / 2.0)
		if FogOfWarManager.is_explored(town_center):
			var town_rect = Rect2(
				_world_to_minimap(town_rect_world.position, ms),
				_world_to_minimap(town_rect_world.end, ms) - _world_to_minimap(town_rect_world.position, ms)
			)
			draw_rect(town_rect, Color(0.18, 0.3, 0.18))

	# Border
	draw_rect(Rect2(Vector2.ZERO, ms), Color(0.3, 0.25, 0.2), false, 2.0)

	# Scale dots based on map size relative to default
	var dot_scale = ms.x / DEFAULT_SIZE.x

	# Camp markers (red dots) — only if explored
	for camp_pos in camp_markers:
		if FogOfWarManager.is_explored(camp_pos):
			var mpos = _world_to_minimap(camp_pos, ms)
			draw_circle(mpos, 2.5 * dot_scale, Color(0.8, 0.2, 0.2, 0.7))

	# Enemy dots (from cached world positions, converted at draw time)
	for epos in _cached_enemies:
		draw_circle(_world_to_minimap(epos, ms), 1.5 * dot_scale, Color(1.0, 0.3, 0.3, 0.8))

	# Miniboss diamonds (pulsing orange-red, larger than enemy dots)
	for bpos in _cached_bosses:
		var mpos = _world_to_minimap(bpos, ms)
		var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 150.0)
		var d = 4.0 * dot_scale * pulse
		var points = PackedVector2Array([
			mpos + Vector2(0, -d), mpos + Vector2(d, 0),
			mpos + Vector2(0, d), mpos + Vector2(-d, 0)
		])
		draw_colored_polygon(points, Color(1.0, 0.4, 0.1, pulse))

	# Shop markers (yellow) — only if explored
	for shop_pos in shop_markers:
		if FogOfWarManager.is_explored(shop_pos):
			var spos = _world_to_minimap(shop_pos, ms)
			draw_circle(spos, 2.5 * dot_scale, Color(1.0, 1.0, 0.3))

	# Exit markers (green) — dungeon exits
	for exit_pos in exit_markers:
		if FogOfWarManager.is_explored(exit_pos):
			var epos = _world_to_minimap(exit_pos, ms)
			var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 250.0)
			draw_circle(epos, 3.0 * dot_scale, Color(0.2, 1.0, 0.2, pulse))

	# Player dot (white, blinking)
	if _player and is_instance_valid(_player):
		var ppos = _world_to_minimap(_player.global_position, ms)
		var blink = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(ppos, 3.0 * dot_scale, Color(1.0, 1.0, 1.0, blink))

func _draw_fog_overlay(ms: Vector2) -> void:
	var fog_cell = Vector2(ms.x / (world_size.x / 64.0), ms.y / (world_size.y / 64.0))
	if _fog_dirty:
		_fog_dirty = false
		_cached_explored_rects.clear()
		for cell in FogOfWarManager.explored_tiles:
			var minimap_pos = _world_to_minimap(Vector2(cell.x * 64, cell.y * 64), ms)
			var is_vis = FogOfWarManager.visible_tiles.has(cell)
			_cached_explored_rects.append([minimap_pos, is_vis])

	for entry in _cached_explored_rects:
		var color: Color
		if entry[1]:
			color = Color(0.1, 0.2, 0.1, 0.9)
		else:
			color = Color(0.06, 0.1, 0.06, 0.9)
		draw_rect(Rect2(entry[0], fog_cell), color)

func _world_to_minimap(world_pos: Vector2, ms: Vector2) -> Vector2:
	var normalized = (world_pos - world_offset + world_size / 2.0) / world_size
	return normalized * ms

func _minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var normalized = minimap_pos / size
	return normalized * world_size - world_size / 2.0 + world_offset
