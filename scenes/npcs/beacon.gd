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
var _heal_range_sq: float = 0.0  # Squared beacon radius for distance healing check
var _played_heal_sfx: bool = false  # Track whether SFX already played this visit
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
	# Pre-compute squared range for distance-based heal check (generous margin)
	_heal_range_sq = (beacon_radius + 20.0) * (beacon_radius + 20.0)

func _process(delta: float) -> void:
	if label.visible:
		var cam = get_viewport().get_camera_2d()
		if cam:
			var comp = ZOOM_REF / cam.zoom.x
			label.scale = Vector2(comp, comp)

	# Heal beacon: restore HP/MP every frame so HP never visibly drops
	if beacon_type == "heal":
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if not is_instance_valid(player) or not player.has_node("StatsComponent"):
				continue
			var dist_sq = global_position.distance_squared_to(player.global_position)
			if dist_sq <= _heal_range_sq:
				var stats = player.get_node("StatsComponent")
				var needs_heal = stats.current_hp < stats.get_total_max_hp() or stats.current_mana < stats.get_total_max_mana()
				if needs_heal:
					stats.current_hp = stats.get_total_max_hp()
					stats.current_mana = stats.get_total_max_mana()
					stats._emit_all()
					# SFX + message only on first actual heal per visit
					if not _played_heal_sfx:
						_played_heal_sfx = true
						AudioManager.play_sfx("beacon_heal")
						GameManager.game_message.emit("Fully Restored!", Color(0.3, 1.0, 0.5))
			else:
				# Player left — reset so SFX plays on next visit if needed
				_played_heal_sfx = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		activated.emit(self)
		# Route through BeaconManager for non-heal types (heal is distance-based)
		if not beacon_type.is_empty() and beacon_type != "heal":
			BeaconManager.activate(beacon_type, beacon_data, body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
