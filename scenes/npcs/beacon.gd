extends Area2D

## Beacon — the core SC:BW UMS interaction system.
## Colored circles on the ground that trigger events when the hero walks onto them.
## Routes all activations through BeaconManager for centralized dispatch.

signal activated(beacon: Area2D)

@export var beacon_color: Color = Color(1, 1, 0)  # Yellow default
@export var beacon_label: String = ""
@export var beacon_radius: float = 20.0
@export var beacon_type: String = ""  # shop, heal, teleport, boss_spawn, town_purchase, alignment_choice
@export var beacon_data: Dictionary = {}

@onready var visual: Sprite2D = $Visual
@onready var label: Label = $Label

var _player_inside: bool = false
var _heal_tick_timer: float = 0.0
const HEAL_TICK_INTERVAL := 0.15  # Heal frequently while standing on a heal beacon
const ZOOM_REF := 3.0

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
		var vp_size = get_viewport().get_visible_rect().size
		if vp_size.x < 700 or (vp_size.x < vp_size.y):
			label.add_theme_font_size_override("font_size", 18)
		label.pivot_offset = label.size / 2.0
	else:
		label.visible = false

	# Set collision shape — make unique so instances don't share the sub-resource
	var shape = $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		shape.shape = shape.shape.duplicate()
		shape.shape.radius = beacon_radius

func _process(delta: float) -> void:
	if label.visible:
		var cam = get_viewport().get_camera_2d()
		if cam:
			var comp = ZOOM_REF / cam.zoom.x
			label.scale = Vector2(comp, comp)

	# Continuous healing while player stands on a heal beacon (no sound)
	if _player_inside and beacon_type == "heal":
		_heal_tick_timer += delta
		if _heal_tick_timer >= HEAL_TICK_INTERVAL:
			_heal_tick_timer -= HEAL_TICK_INTERVAL
			var players = get_tree().get_nodes_in_group("player")
			for player in players:
				if is_instance_valid(player) and player.has_node("StatsComponent"):
					var stats = player.get_node("StatsComponent")
					if stats.current_hp < stats.get_total_max_hp() or stats.current_mana < stats.get_total_max_mana():
						stats.current_hp = stats.get_total_max_hp()
						stats.current_mana = stats.get_total_max_mana()
						stats._emit_all()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_heal_tick_timer = 0.0
		activated.emit(self)
		# Route through BeaconManager for centralized dispatch
		if not beacon_type.is_empty():
			BeaconManager.activate(beacon_type, beacon_data, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_heal_tick_timer = 0.0
