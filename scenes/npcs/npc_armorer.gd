extends StaticBody2D

@export var armory_name: String = "Armory"

@onready var beacon: Area2D = $Beacon
@onready var name_label: Label = $NameLabel
@onready var armory_sprite: Sprite2D = $Sprite

var _player: Node2D = null
var _label_check_timer: float = 0.0
const LABEL_VISIBLE_DISTANCE_SQ: float = 14400.0  # 120^2
const LABEL_CHECK_INTERVAL: float = 0.3
const ZOOM_REF := 3.0

func _ready() -> void:
	add_to_group("npcs")
	name_label.text = armory_name
	name_label.visible = false
	var vp_size = get_viewport().get_visible_rect().size
	if DisplayServer.is_touchscreen_available() and min(vp_size.x, vp_size.y) < 1200:
		name_label.add_theme_font_size_override("font_size", 18)
	name_label.pivot_offset = name_label.size / 2.0
	beacon.activated.connect(_on_beacon_activated)
	var tex = SpriteGenerator.get_texture("armory_building")
	if tex:
		armory_sprite.texture = tex
	_label_check_timer = randf_range(0.0, LABEL_CHECK_INTERVAL)

func _process(delta: float) -> void:
	_label_check_timer -= delta
	if _label_check_timer > 0.0:
		return
	_label_check_timer = LABEL_CHECK_INTERVAL
	if not _player or not is_instance_valid(_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
		else:
			return
	var dist_sq = global_position.distance_squared_to(_player.global_position)
	name_label.visible = dist_sq < LABEL_VISIBLE_DISTANCE_SQ
	if name_label.visible:
		var cam = get_viewport().get_camera_2d()
		if cam:
			var comp = ZOOM_REF / cam.zoom.x
			name_label.scale = Vector2(comp, comp)

func _on_beacon_activated(_b: Area2D) -> void:
	var dialogs = get_tree().get_nodes_in_group("armory_dialog")
	if dialogs.size() > 0:
		dialogs[0].open()
