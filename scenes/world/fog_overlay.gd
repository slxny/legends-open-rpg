extends Node2D

## Fog of War visual overlay rendered on the world.
## Draws black/dim rects over unexplored/explored-but-not-visible tiles.
## Updated by FogOfWarManager every trigger tick.

var _camera: Camera2D = null

func _ready() -> void:
	z_index = 100  # Render on top of everything
	FogOfWarManager.fog_updated.connect(_on_fog_updated)
	# Cache camera reference once instead of every frame
	call_deferred("_cache_camera")

func _cache_camera() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		_camera = players[0].get_node_or_null("Camera2D")

func _on_fog_updated() -> void:
	queue_redraw()

func _draw() -> void:
	if not _camera:
		return

	# Only draw fog for tiles visible on screen (performance)
	var viewport_size = get_viewport_rect().size
	var cam_pos = _camera.global_position
	var zoom = _camera.zoom
	var half_view = viewport_size / (2.0 * zoom)

	var min_world = cam_pos - half_view - Vector2(128, 128)
	var max_world = cam_pos + half_view + Vector2(128, 128)

	var cell_size = FogOfWarManager.CELL_SIZE
	var min_cell = Vector2i(int(floor(min_world.x / cell_size)), int(floor(min_world.y / cell_size)))
	var max_cell = Vector2i(int(ceil(max_world.x / cell_size)), int(ceil(max_world.y / cell_size)))

	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell = Vector2i(cx, cy)
			var world_pos = Vector2(cx * cell_size, cy * cell_size)
			var rect = Rect2(world_pos, Vector2(cell_size, cell_size))

			if FogOfWarManager.visible_tiles.has(cell):
				continue  # Fully visible — no overlay
			elif FogOfWarManager.explored_tiles.has(cell):
				# Explored but not visible — dim overlay
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.5))
			else:
				# Unexplored — solid black
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.95))
