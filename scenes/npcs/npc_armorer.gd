extends StaticBody2D

@export var armory_name: String = "Armory"

@onready var beacon: Area2D = $Beacon
@onready var name_label: Label = $NameLabel
@onready var armory_sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("npcs")
	name_label.text = armory_name
	var vp_size = get_viewport().get_visible_rect().size
	if vp_size.x < 700 or (vp_size.x < vp_size.y):
		name_label.add_theme_font_size_override("font_size", 22)
	beacon.activated.connect(_on_beacon_activated)
	var tex = SpriteGenerator.get_texture("armory_building")
	if tex:
		armory_sprite.texture = tex

func _on_beacon_activated(_b: Area2D) -> void:
	var dialogs = get_tree().get_nodes_in_group("armory_dialog")
	if dialogs.size() > 0:
		dialogs[0].open()
