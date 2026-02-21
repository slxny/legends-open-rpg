extends Node

var _player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var _world_scene: PackedScene = preload("res://scenes/world/world.tscn")
var _hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")
var _inventory_scene: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")
var _shop_scene: PackedScene = preload("res://scenes/ui/shop_dialog.tscn")
var _armory_scene: PackedScene = preload("res://scenes/ui/armory_dialog.tscn")
var _tavern_scene: PackedScene = preload("res://scenes/ui/tavern_dialog.tscn")
var _woodwork_scene: PackedScene = preload("res://scenes/ui/woodworking_dialog.tscn")
var _hero_stats_scene: PackedScene = preload("res://scenes/ui/hero_stats_panel.tscn")
var _messages_scene: PackedScene = preload("res://scenes/ui/game_messages.tscn")
var _center_msg_scene: PackedScene = preload("res://scenes/ui/center_message_system.tscn")

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

	var armory_dialog = _armory_scene.instantiate()
	armory_dialog.add_to_group("armory_dialog")
	add_child(armory_dialog)
	armory_dialog.setup(_player)

	var tavern_dialog = _tavern_scene.instantiate()
	tavern_dialog.add_to_group("tavern_dialog")
	add_child(tavern_dialog)
	tavern_dialog.setup(_player)

	var woodwork_dialog = _woodwork_scene.instantiate()
	woodwork_dialog.add_to_group("woodworking_dialog")
	add_child(woodwork_dialog)
	woodwork_dialog.setup(_player)

	var hero_stats = _hero_stats_scene.instantiate()
	hero_stats.add_to_group("hero_stats_panel")
	add_child(hero_stats)
	hero_stats.setup(_player)

	var messages = _messages_scene.instantiate()
	add_child(messages)

	# Center message system for dramatic SC-style announcements
	var center_msg = _center_msg_scene.instantiate()
	add_child(center_msg)

	# Connect level-up to dramatic message
	_player.stats.leveled_up.connect(_on_player_leveled_up)
	_player.stats.died.connect(_on_player_died)

	# Register game-wide triggers
	_register_triggers()

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
	# Route through RespawnManager for multiplayer-readiness
	RespawnManager.request_respawn(0)

func _register_triggers() -> void:
	# XP/level sync trigger — keeps DC in sync with player stats every tick
	var xp_sync = TriggerEngine.Trigger.new()
	xp_sync.conditions = [func(): return is_instance_valid(_player)]
	xp_sync.actions = [func():
		DeathCounterSystem.set_value("level_p0", _player.stats.level)
		DeathCounterSystem.set_value("xp_p0", _player.stats.xp)
	]
	TriggerEngine.register(xp_sync)

	# Gold sync trigger
	var gold_sync = TriggerEngine.Trigger.new()
	gold_sync.conditions = [func(): return true]
	gold_sync.actions = [func():
		DeathCounterSystem.set_value("gold_p0", GameManager.gold)
	]
	TriggerEngine.register(gold_sync)
