extends Node

var _player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var _world_scene: PackedScene = preload("res://scenes/world/world.tscn")
var _hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")
var _inventory_scene: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
var _shop_scene: PackedScene = preload("res://scenes/ui/shop_dialog.tscn")
var _messages_scene: PackedScene = preload("res://scenes/ui/game_messages.tscn")

@onready var hero_select: Control = $HeroSelect

var _world: Node2D = null
var _player: CharacterBody2D = null

func _ready() -> void:
	hero_select.hero_chosen.connect(_on_hero_chosen)

func _on_hero_chosen(hero_class: String) -> void:
	# Remove hero selection screen
	hero_select.queue_free()

	# Start game
	GameManager.start_game()

	# Instance world
	_world = _world_scene.instantiate()
	add_child(_world)

	# Instance player at spawn
	_player = _player_scene.instantiate()
	_player.position = _world.get_spawn_position()
	_world.add_child(_player)

	# Instance UI
	var hud = _hud_scene.instantiate()
	add_child(hud)
	hud.setup(_player)

	var inventory_screen = _inventory_scene.instantiate()
	add_child(inventory_screen)
	inventory_screen.setup(_player)

	var shop_dialog = _shop_scene.instantiate()
	shop_dialog.add_to_group("shop_dialog")
	add_child(shop_dialog)
	shop_dialog.setup(_player)

	var messages = _messages_scene.instantiate()
	add_child(messages)

	# Connect level-up to dramatic message
	_player.stats.leveled_up.connect(_on_player_leveled_up)
	_player.stats.died.connect(_on_player_died)

func _on_player_leveled_up(new_level: int) -> void:
	var tier = "Adventurer"
	if new_level >= 36:
		tier = "Demigod"
	elif new_level >= 26:
		tier = "Master"
	elif new_level >= 16:
		tier = "Veteran"
	GameManager.game_message.emit("LEVEL UP! You are now Level %d (%s)" % [new_level, tier], Color(1.0, 0.9, 0.2))

func _on_player_died() -> void:
	GameManager.game_message.emit("You have fallen! Respawning...", Color(1.0, 0.2, 0.2))
	# Respawn at world spawn with full HP
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_player) and is_instance_valid(_world):
		_player.position = _world.get_spawn_position()
		_player.stats.current_hp = _player.stats.get_total_max_hp()
		_player.stats.current_mana = _player.stats.get_total_max_mana()
		_player.stats._emit_all()
