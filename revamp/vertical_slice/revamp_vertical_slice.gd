extends Node2D

## RevampVerticalSlice — top-level orchestrator for the replacement game.
## Builds the entire scene tree from code so we can iterate on composition
## without editing a giant .tscn. Composes existing autoloads (CombatManager,
## HitStopController, TimeManager, AudioManager, SaveLoadManager) but does NOT
## inherit from any old gameplay scene.

const RevampWorld := preload("res://revamp/environment/revamp_world.gd")
const RevampLighting := preload("res://revamp/environment/revamp_lighting.gd")
const RevampCamera := preload("res://revamp/vertical_slice/revamp_camera.gd")
const StormcallerPlayer := preload("res://revamp/player/stormcaller_player.gd")
const RevampHUD := preload("res://revamp/ui/revamp_hud.gd")
const EncounterDirector := preload("res://revamp/vertical_slice/encounter_director.gd")
const DemoController := preload("res://revamp/demo/demo_controller.gd")
const ScreenEffects := preload("res://revamp/effects/screen_effects.gd")
const RevampSaveAdapter := preload("res://revamp/progression/revamp_save_adapter.gd")

@onready var world: Node2D
@onready var lighting: CanvasModulate
@onready var camera: Camera2D
@onready var player: CharacterBody2D
@onready var hud: CanvasLayer
@onready var screen_fx: CanvasLayer
@onready var director: Node
@onready var demo: Node
@onready var save_adapter: Node

var _demo_enabled: bool = false
var _autocapture_path: String = ""
var _autocapture_delay: float = 0.0
var _seed: int = 0


func _ready() -> void:
	_parse_cmdline()
	_build_tree()
	_wire_signals()
	# Kick the director once so its first objective fires AFTER the HUD signal
	# is connected. Without this, the very first objective string would emit
	# during _build_tree before the wire-up.
	if director and director.has_method("set_process"):
		director.set_process(true)
	if director and director.has_signal("objective_changed") and hud and hud.has_method("set_objective"):
		# Re-fire the current first-stage objective on the next frame.
		_replay_initial_objective.call_deferred()
	if _demo_enabled and is_instance_valid(demo):
		demo.start()
	if _autocapture_path != "":
		_schedule_autocapture()


func _replay_initial_objective() -> void:
	if director and director.has_method("get") and hud and hud.has_method("set_objective"):
		var stages: Variant = director.get("_stages")
		if stages is Array and (stages as Array).size() > 0:
			var first: Dictionary = stages[0]
			hud.set_objective(String(first.get("objective", "")))


func _parse_cmdline() -> void:
	for a in OS.get_cmdline_args():
		if a == "--revamp-demo":
			_demo_enabled = true
		elif a.begins_with("--revamp-autocapture="):
			var spec: String = a.substr("--revamp-autocapture=".length())
			var sep: int = spec.find(":")
			if sep > 0:
				_autocapture_delay = float(spec.substr(0, sep))
				_autocapture_path = spec.substr(sep + 1)
		elif a.begins_with("--revamp-seed="):
			_seed = int(a.substr("--revamp-seed=".length()))
	if _seed != 0:
		seed(_seed)


func _build_tree() -> void:
	# 1. World composition (sky → far → mid → terrain → props → foreground)
	world = RevampWorld.new()
	world.name = "World"
	add_child(world)

	# 2. Lighting (canvas modulate + ambient palette)
	lighting = RevampLighting.new()
	lighting.name = "Lighting"
	add_child(lighting)

	# 3. Camera system (follow + soft snap + impulse on big hits)
	camera = RevampCamera.new()
	camera.name = "CameraSystem"
	add_child(camera)

	# 4. Player at the entry spawn
	player = StormcallerPlayer.new()
	player.name = "Player"
	player.global_position = world.player_spawn_position()
	world.add_child(player)
	camera.target = player

	# 5. Screen effects (vignette, hit flash, damage shake holder)
	screen_fx = ScreenEffects.new()
	screen_fx.name = "ScreenEffects"
	add_child(screen_fx)

	# 6. HUD on top
	hud = RevampHUD.new()
	hud.name = "RevampHUD"
	add_child(hud)
	hud.bind_player(player)

	# 7. Encounter director (manages spawn waves, elite trigger, boss gate)
	director = EncounterDirector.new()
	director.name = "EncounterDirector"
	add_child(director)
	director.bind(world, player, hud)

	# 8. Save adapter — sidecar persistence for revamp loadouts
	save_adapter = RevampSaveAdapter.new()
	save_adapter.name = "RevampSaveAdapter"
	add_child(save_adapter)
	save_adapter.bind(player)
	save_adapter.try_load()

	# 9. Demo controller (only active if --revamp-demo)
	demo = DemoController.new()
	demo.name = "DemoController"
	add_child(demo)
	demo.bind(self, player, director, hud)


func _wire_signals() -> void:
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	if director.has_signal("objective_changed"):
		director.objective_changed.connect(hud.set_objective)
	if director.has_signal("boss_health_changed"):
		director.boss_health_changed.connect(hud.update_boss_health)
	if director.has_signal("boss_spawned"):
		director.boss_spawned.connect(hud.show_boss_bar)
	if director.has_signal("boss_defeated"):
		director.boss_defeated.connect(hud.hide_boss_bar)
	if director.has_signal("loot_dropped"):
		director.loot_dropped.connect(_on_loot_dropped)


func _on_player_died() -> void:
	# Quick fade then respawn at the last checkpoint.
	if screen_fx and screen_fx.has_method("play_death_fade"):
		screen_fx.play_death_fade()
	get_tree().create_timer(1.6).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_instance_valid(player):
		return
	var anchor: Vector2 = world.checkpoint_position()
	player.respawn(anchor)
	if screen_fx and screen_fx.has_method("play_respawn_pulse"):
		screen_fx.play_respawn_pulse()


func _on_loot_dropped(item: Resource, drop_pos: Vector2) -> void:
	world.add_loot_pickup(item, drop_pos)


func _schedule_autocapture() -> void:
	# Independent of ScreenshotCapture autoload so the revamp slice can be
	# captured even when not launched via main.tscn.
	await get_tree().create_timer(maxf(0.2, _autocapture_delay)).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[revamp] capture image null")
		get_tree().quit()
		return
	var dir: String = _autocapture_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(_autocapture_path)
	if err != OK:
		push_error("[revamp] save_png failed: %s -> %s" % [err, _autocapture_path])
	else:
		print("[revamp] captured: ", _autocapture_path)
	get_tree().quit()
