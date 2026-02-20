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

## Pre-computed sight offsets (avoids nested loop + distance check every tick)
var _sight_offsets: Array[Vector2i] = []
var _last_grid_pos: Vector2i = Vector2i(-99999, -99999)

func _ready() -> void:
	set_process(false)  # Managed by trigger engine tick
	_precompute_sight_offsets()

func _precompute_sight_offsets() -> void:
	_sight_offsets.clear()
	var r_sq = sight_radius * sight_radius
	for dx in range(-sight_radius, sight_radius + 1):
		for dy in range(-sight_radius, sight_radius + 1):
			if dx * dx + dy * dy <= r_sq:
				_sight_offsets.append(Vector2i(dx, dy))

func update_visibility(player_positions: Array) -> void:
	# Skip update if player hasn't moved to a new grid cell
	if player_positions.size() > 0:
		var new_grid = world_to_grid(player_positions[0])
		if new_grid == _last_grid_pos:
			return  # Same cell — no visibility change
		_last_grid_pos = new_grid

	visible_tiles.clear()
	for pos in player_positions:
		var grid_pos = world_to_grid(pos)
		for offset in _sight_offsets:
			var cell = grid_pos + offset
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
