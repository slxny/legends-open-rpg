extends Node

## Isometric projection helper.
## All game logic uses flat Cartesian coordinates. This autoload provides
## the transform matrix applied to the World node so that the flat world
## renders as an isometric diamond view (2:1 ratio, classic SC:BW style).
##
## World axes after transform:
##   +X  ->  screen right-and-down   (east  in game)
##   +Y  ->  screen left-and-down    (south in game)

# The 2:1 isometric basis vectors (no translation).
# x_axis: world-X draws to the right and half-down
# y_axis: world-Y draws to the left and half-down
const ISO_X := Vector2(1.0, 0.5)
const ISO_Y := Vector2(-1.0, 0.5)

## The transform applied to the World node.
static func get_iso_transform() -> Transform2D:
	return Transform2D(ISO_X, ISO_Y, Vector2.ZERO)

## Inverse: convert screen-space position back to world (Cartesian) position.
## Used for mouse input.
static func get_iso_inverse() -> Transform2D:
	return get_iso_transform().affine_inverse()

## Convert a world-space position to isometric screen position.
static func world_to_screen(world_pos: Vector2) -> Vector2:
	return get_iso_transform() * world_pos

## Convert an isometric screen position back to world-space.
static func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_iso_inverse() * screen_pos

## The inverse basis (rotation/scale only, no translation).
## Apply this to sprites so they appear un-skewed on screen.
static func get_sprite_counter_transform() -> Transform2D:
	var inv := get_iso_transform().affine_inverse()
	# Return just the basis (no origin offset)
	return Transform2D(inv.x, inv.y, Vector2.ZERO)

## Apply the counter-transform to a CanvasItem already in the scene tree.
## Node2D nodes: sets .transform directly.
## Control nodes: reparents under a Node2D wrapper carrying the transform,
## since Control does not support direct .transform assignment.
static func apply_counter_transform(node: CanvasItem) -> void:
	var ct := get_sprite_counter_transform()
	if node is Node2D:
		node.transform = ct
	else:
		var parent := node.get_parent()
		if parent:
			var wrapper := Node2D.new()
			wrapper.transform = ct
			wrapper.position = node.position
			parent.add_child(wrapper)
			node.reparent(wrapper, false)
			node.position = Vector2.ZERO

## Wrap a CanvasItem (not yet in the tree) inside a Node2D carrying the
## counter-transform. Returns the wrapper — add it to the tree instead of
## the original node. `pos` sets the wrapper's position in its parent space.
static func counter_transform_wrap(node: CanvasItem, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var wrapper := Node2D.new()
	wrapper.transform = get_sprite_counter_transform()
	wrapper.position = pos
	wrapper.add_child(node)
	return wrapper
