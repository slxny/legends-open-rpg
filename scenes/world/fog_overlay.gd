extends Node2D

## Fog of War visual overlay rendered on the world.
## Draws black/dim rects over unexplored/explored-but-not-visible tiles.
## Updated by FogOfWarManager every trigger tick.

var _camera: Camera2D = null
const _FOG_DIM := Color(0.0, 0.0, 0.0, 0.5)
const _FOG_BLACK := Color(0.0, 0.0, 0.0, 0.95)
var _fog_redraw_pending: bool = false
var _fog_redraw_timer: float = 0.0
const FOG_REDRAW_INTERVAL: float = 0.3

func _ready() -> void:
	z_index = 100  # Render on top of everything
	FogOfWarManager.fog_updated.connect(_on_fog_updated)
	call_deferred("_cache_camera")

func _process(delta: float) -> void:
	if _fog_redraw_pending:
		_fog_redraw_timer -= delta
		if _fog_redraw_timer <= 0.0:
			_fog_redraw_pending = false
			queue_redraw()

func _cache_camera() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		_camera = players[0].get_node_or_null("Camera2D")

func _on_fog_updated() -> void:
	if not _fog_redraw_pending:
		_fog_redraw_pending = true
		_fog_redraw_timer = FOG_REDRAW_INTERVAL

func _draw() -> void:
	if not _camera or not is_instance_valid(_camera):
		_cache_camera()
		if not _camera:
			return

	var viewport_size = get_viewport_rect().size
	var cam_pos = _camera.global_position
	var zoom = _camera.zoom
	var half_view = viewport_size / (2.0 * zoom)

	var min_world = cam_pos - half_view - Vector2(128, 128)
	var max_world = cam_pos + half_view + Vector2(128, 128)

	var cell_size_f = float(FogOfWarManager.CELL_SIZE)
	var min_cx = int(floor(min_world.x / cell_size_f))
	var min_cy = int(floor(min_world.y / cell_size_f))
	var max_cx = int(ceil(max_world.x / cell_size_f))
	var max_cy = int(ceil(max_world.y / cell_size_f))

	var visible = FogOfWarManager.visible_tiles
	var explored = FogOfWarManager.explored_tiles
	var cell = Vector2i()

	# Batch adjacent cells in each row into spans to reduce draw calls.
	# Instead of one draw_rect per cell, merge consecutive same-state cells.
	for cy in range(min_cy, max_cy + 1):
		cell.y = cy
		var wy = cy * cell_size_f
		var span_start_x: int = min_cx
		var span_state: int = -1  # -1=none, 0=visible(skip), 1=dim, 2=black

		for cx in range(min_cx, max_cx + 2):  # +2 to flush final span
			var cur_state: int
			if cx <= max_cx:
				cell.x = cx
				if visible.has(cell):
					cur_state = 0
				elif explored.has(cell):
					cur_state = 1
				else:
					cur_state = 2
			else:
				cur_state = -1  # End-of-row sentinel

			if cur_state != span_state:
				# Flush previous span
				if span_state == 1:
					draw_rect(Rect2(span_start_x * cell_size_f, wy, (cx - span_start_x) * cell_size_f, cell_size_f), _FOG_DIM)
				elif span_state == 2:
					draw_rect(Rect2(span_start_x * cell_size_f, wy, (cx - span_start_x) * cell_size_f, cell_size_f), _FOG_BLACK)
				span_start_x = cx
				span_state = cur_state
