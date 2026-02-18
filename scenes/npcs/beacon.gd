extends Area2D

## Beacon — the core SC:BW UMS interaction system.
## Colored circles on the ground that trigger events when the hero walks onto them.

signal activated(beacon: Area2D)

@export var beacon_color: Color = Color(1, 1, 0)  # Yellow default
@export var beacon_label: String = ""
@export var beacon_radius: float = 20.0

@onready var visual: Sprite2D = $Visual
@onready var label: Label = $Label

var _player_inside: bool = false

# Map beacon colors to texture names
const BEACON_TEXTURE_MAP = {
	"green": "beacon_green",
	"yellow": "beacon_yellow",
	"blue": "beacon_blue",
	"red": "beacon_red",
}

func _ready() -> void:
	add_to_group("beacons")
	# Determine beacon texture from color
	var tex_name = "beacon_yellow"
	if beacon_color.g > 0.7 and beacon_color.r < 0.5:
		tex_name = "beacon_green"
	elif beacon_color.b > 0.7 and beacon_color.r < 0.5:
		tex_name = "beacon_blue"
	elif beacon_color.r > 0.7 and beacon_color.g < 0.5:
		tex_name = "beacon_red"
	var tex = SpriteGenerator.get_texture(tex_name)
	if tex:
		visual.texture = tex
		var tex_size = tex.get_size()
		visual.scale = Vector2(beacon_radius * 2.0 / tex_size.x, beacon_radius * 2.0 / tex_size.y)

	if not beacon_label.is_empty():
		label.text = beacon_label
	else:
		label.visible = false

	# Set collision shape
	var shape = $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = beacon_radius

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		activated.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
