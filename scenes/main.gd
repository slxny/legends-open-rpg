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
var _changelog_scene: PackedScene = preload("res://scenes/ui/changelog_dialog.tscn")
var _pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

@onready var hero_select: Control = $HeroSelect

var _world: Node2D = null
var _player: CharacterBody2D = null
var _game_started := false
var _web_fullscreen_requested := false

func _ready() -> void:
	hero_select.hero_chosen.connect(_on_hero_chosen)

func _input(event: InputEvent) -> void:
	# On web, request fullscreen on the first user tap/click to hide the address bar.
	# Uses JavaScriptBridge for broader mobile browser support (Android Chrome, etc.).
	# Note: iOS Safari does not support the Fullscreen API at all — users must
	# "Add to Home Screen" to get a fullscreen PWA experience on iOS.
	if not _web_fullscreen_requested and OS.has_feature("web"):
		if (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventScreenTouch and event.pressed):
			_web_fullscreen_requested = true
			if JavaScriptBridge.eval("'requestFullscreen' in document.documentElement", true):
				JavaScriptBridge.eval("document.documentElement.requestFullscreen().catch(function(){})", true)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_hero_chosen(hero_class: String) -> void:
	if _game_started:
		return
	_game_started = true
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

	var changelog = _changelog_scene.instantiate()
	changelog.add_to_group("changelog_dialog")
	add_child(changelog)

	var pause_menu = _pause_menu_scene.instantiate()
	pause_menu.add_to_group("pause_menu")
	add_child(pause_menu)
	pause_menu.setup(_player)

	# Connect level-up to dramatic message
	_player.stats.leveled_up.connect(_on_player_leveled_up)
	_player.stats.died.connect(_on_player_died)
	# Connect countdown for center screen display
	RespawnManager.countdown_tick.connect(_on_respawn_countdown)
	RespawnManager.player_respawned.connect(_on_player_respawned)

	# Register game-wide triggers
	_register_triggers()

func _on_player_leveled_up(new_level: int) -> void:
	var gold_color = Color(1.0, 0.9, 0.2)
	var stat_color = Color(0.6, 0.95, 0.6)
	GameManager.game_message.emit("Level Up! Lv %d" % new_level, gold_color)

	# Show individual stat gains as top-down notifications
	var data = HeroData.get_hero(_player.stats.hero_class)
	if data.is_empty():
		return
	var growth = data["growth_per_level"]
	var gains: Array[String] = []
	if growth.get("max_hp", 0) > 0:
		gains.append("+%d HP" % int(growth["max_hp"]))
	if growth.get("max_mana", 0) > 0:
		gains.append("+%d Mana" % int(growth["max_mana"]))
	if growth.get("strength", 0) > 0:
		gains.append("+%d STR" % int(growth["strength"]))
	if growth.get("agility", 0) > 0:
		gains.append("+%d AGI" % int(growth["agility"]))
	if growth.get("intelligence", 0) > 0:
		gains.append("+%d INT" % int(growth["intelligence"]))
	if growth.get("attack_damage", 0) > 0:
		gains.append("+%d ATK" % int(growth["attack_damage"]))
	for g in gains:
		GameManager.game_message.emit(g, stat_color)

func _on_player_died() -> void:
	# Instant death — show fallen message, route to RespawnManager immediately
	GameManager.game_message.emit("YOU HAVE FALLEN!", Color(1.0, 0.15, 0.15))
	RespawnManager.request_respawn(0)

func _on_respawn_countdown(_player_id: int, seconds_left: int) -> void:
	# Show countdown number as dramatic center message
	GameManager.game_message.emit("Respawning... %d" % seconds_left, Color(1.0, 0.7, 0.2))

func _on_player_respawned(_player_id: int) -> void:
	GameManager.game_message.emit("Respawned!", Color(0.5, 1.0, 0.5))

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
