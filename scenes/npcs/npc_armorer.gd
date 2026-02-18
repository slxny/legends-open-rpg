extends StaticBody2D

@export var armory_name: String = "Armory"

@onready var beacon: Area2D = $Beacon
@onready var name_label: Label = $NameLabel
@onready var armory_sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("npcs")
	name_label.text = armory_name
	beacon.activated.connect(_on_beacon_activated)
	var tex = SpriteGenerator.get_texture("armory_building")
	if tex:
		armory_sprite.texture = tex
	# Counter-transform sprite and label for isometric projection
	var ct = IsometricHelper.get_sprite_counter_transform()
	armory_sprite.transform = ct
	IsometricHelper.apply_counter_transform(name_label)

func _on_beacon_activated(_b: Area2D) -> void:
	var dialogs = get_tree().get_nodes_in_group("armory_dialog")
	if dialogs.size() > 0:
		dialogs[0].open()
