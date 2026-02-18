extends StaticBody2D

@export var shop_name: String = "General Store"
@export var shop_items: Array[String] = [
	"health_potion_small", "health_potion_medium", "mana_potion_small",
	"rusty_sword", "short_bow", "cloth_tunic", "leather_vest",
	"leather_cap", "worn_boots", "copper_ring",
]

@onready var beacon: Area2D = $Beacon
@onready var name_label: Label = $NameLabel
@onready var shop_sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("npcs")
	name_label.text = shop_name
	beacon.activated.connect(_on_beacon_activated)
	var tex = SpriteGenerator.get_texture("shop_building")
	if tex:
		shop_sprite.texture = tex
	# Counter-transform sprite and label for isometric projection
	var ct = IsometricHelper.get_sprite_counter_transform()
	shop_sprite.transform = ct
	IsometricHelper.apply_counter_transform(name_label)

func _on_beacon_activated(_b: Area2D) -> void:
	# Find the shop dialog in the scene tree and open it
	var shop_dialogs = get_tree().get_nodes_in_group("shop_dialog")
	if shop_dialogs.size() > 0:
		shop_dialogs[0].open(shop_items)
	else:
		# Fallback: find via UI layer
		var ui = get_tree().current_scene.get_node_or_null("UI/ShopDialog")
		if ui:
			ui.open(shop_items)
