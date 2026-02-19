extends Node

## Fog of War system.
## Stores explored tiles in a dictionary.
## Three states: Unexplored (black), Explored (dim), Visible (full bright).
## Uses a viewport mask texture approach.

signal fog_updated

## Grid cell size for fog tracking
const CELL_SIZE := 64

## Explored tiles: Vector2i -> true
var explored_tiles: Dictionary = {}

## Currently visible tiles (recalculated each frame): Vector2i -> true
var visible_tiles: Dictionary = {}

## Player sight radius in grid cells
var sight_radius: int = 6

func _ready() -> void:
	set_process(false)  # Managed by trigger engine tick

func update_visibility(player_positions: Array) -> void:
	visible_tiles.clear()
	for pos in player_positions:
		var grid_pos = world_to_grid(pos)
		# Reveal cells within sight radius
		for dx in range(-sight_radius, sight_radius + 1):
			for dy in range(-sight_radius, sight_radius + 1):
				if dx * dx + dy * dy <= sight_radius * sight_radius:
					var cell = Vector2i(grid_pos.x + dx, grid_pos.y + dy)
					visible_tiles[cell] = true
					explored_tiles[cell] = true
	fog_updated.emit()

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE))
	)

func is_visible(world_pos: Vector2) -> bool:
	return visible_tiles.has(world_to_grid(world_pos))

func is_explored(world_pos: Vector2) -> bool:
	return explored_tiles.has(world_to_grid(world_pos))

func get_fog_state(world_pos: Vector2) -> int:
	## Returns: 0 = unexplored, 1 = explored (dim), 2 = visible (bright)
	var cell = world_to_grid(world_pos)
	if visible_tiles.has(cell):
		return 2
	elif explored_tiles.has(cell):
		return 1
	return 0

func get_explored_data() -> Array:
	## Serialize explored tiles for save system
	var result: Array = []
	for cell in explored_tiles:
		result.append([cell.x, cell.y])
	return result

func load_explored_data(data: Array) -> void:
	explored_tiles.clear()
	for entry in data:
		if entry is Array and entry.size() == 2:
			explored_tiles[Vector2i(entry[0], entry[1])] = true
