extends CanvasLayer
class_name EdgeIndicatorLayer

## v0.91.0 — Off-screen enemy indicators. Red arrows pinned to the screen
## edge point toward enemies that are within aggro range but not visible.
## Adds real combat readability: you'll never get jumped from off-screen.

const DETECT_RADIUS_SQ: float = 900.0 * 900.0
const EDGE_MARGIN: float = 38.0
const POOL_MAX: int = 24

var _player: Node2D = null
var _arrows: Array[Polygon2D] = []
var _arrow_pool: Array[Polygon2D] = []


func _ready() -> void:
	layer = 80  # Below post-process (100) but above world UI.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
	if not is_instance_valid(_player):
		_player = null
		return

	var viewport := get_viewport()
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	var center: Vector2 = vp_size * 0.5

	# Recycle every arrow this frame and re-place; cheap because pool.
	for a in _arrows:
		a.visible = false
		_arrow_pool.append(a)
	_arrows.clear()

	var enemies := get_tree().get_nodes_in_group("enemies")
	var p_pos: Vector2 = _player.global_position
	for e in enemies:
		if not (e is Node2D):
			continue
		var enemy: Node2D = e
		if enemy.get("_is_dead"):
			continue
		if p_pos.distance_squared_to(enemy.global_position) > DETECT_RADIUS_SQ:
			continue
		var screen_pos: Vector2 = canvas_xform * enemy.global_position
		# Skip if visible on-screen.
		if screen_pos.x >= EDGE_MARGIN and screen_pos.x <= vp_size.x - EDGE_MARGIN and \
				screen_pos.y >= EDGE_MARGIN and screen_pos.y <= vp_size.y - EDGE_MARGIN:
			continue
		# Off-screen: clamp a ray from center → screen_pos onto the inner border.
		var dir: Vector2 = (screen_pos - center)
		if dir.length_squared() < 1.0:
			continue
		var dir_n: Vector2 = dir.normalized()
		# Find scalar t so center + dir_n*t hits the bordered rect.
		var inner_half: Vector2 = (vp_size * 0.5) - Vector2(EDGE_MARGIN, EDGE_MARGIN)
		var tx: float = inner_half.x / max(0.001, absf(dir_n.x))
		var ty: float = inner_half.y / max(0.001, absf(dir_n.y))
		var t: float = min(tx, ty)
		var edge: Vector2 = center + dir_n * t
		var arrow: Polygon2D = _get_arrow()
		arrow.position = edge
		arrow.rotation = dir_n.angle()
		arrow.visible = true
		_arrows.append(arrow)


func _get_arrow() -> Polygon2D:
	var a: Polygon2D
	if _arrow_pool.size() > 0:
		a = _arrow_pool.pop_back()
	else:
		a = Polygon2D.new()
		# Triangle pointing right (+x). Rotation aligns it with the direction.
		a.polygon = PackedVector2Array([
			Vector2(14, 0),
			Vector2(-8, -7),
			Vector2(-4, 0),
			Vector2(-8, 7),
		])
		a.color = Color(1.7, 0.25, 0.25, 0.92)
		add_child(a)
	return a
