extends Node2D

## RevampWorld — composes the full environment tree for the vertical slice.
##
## Layer order (low z to high):
##   -1000  Sky band (atmospheric gradient)
##   -900   Far parallax mountains (silhouette)
##   -800   Mid scenery (distant ruins, fog wash)
##   -700   Midground floor wash + cloud shadow blobs
##   -200   Ground tile material
##   -150   Painted blob overlays + decals
##   -90    Foliage decor + low rocks
##   -50    Foreground framing (cliff edges, props near camera)
##   0+     Gameplay actors

const SkyBand := preload("res://revamp/environment/sky_band.gd")
const FarMountains := preload("res://revamp/environment/far_mountains.gd")
const DistantRuins := preload("res://revamp/environment/distant_ruins.gd")
const GroundLayer := preload("res://revamp/environment/ground_layer.gd")
const PropScatter := preload("res://revamp/environment/prop_scatter.gd")
const ForegroundFrame := preload("res://revamp/environment/foreground_frame.gd")
const AmbientParticles := preload("res://revamp/effects/ambient_particles.gd")
const BossArenaMarker := preload("res://revamp/environment/boss_arena_marker.gd")
const CheckpointShrine := preload("res://revamp/environment/checkpoint_shrine.gd")
const RuneCircleBoss := preload("res://revamp/environment/rune_circle_boss.gd")
const LootPickup := preload("res://revamp/items/loot_pickup.gd")

const PATH_START := Vector2(-2000.0, 0.0)
const CHECKPOINT := Vector2(900.0, -10.0)
const BOSS_ARENA_CENTER := Vector2(2800.0, 0.0)
const PATH_END := Vector2(3500.0, 0.0)
# Camera at zoom 1.55 with 1280×960 viewport shows ~826×620 game units. The
# world bounds intentionally extend further so distant parallax layers
# pre-render off-screen as the player advances.
const WORLD_BOUNDS := Rect2(Vector2(-2400.0, -520.0), Vector2(6400.0, 1100.0))
# Horizon is the y where sky meets terrain. All layer constants in the
# child scripts compute their positions relative to this.
const HORIZON_Y := -120.0

@onready var sky: Node = null
@onready var mountains: Node = null
@onready var ruins: Node = null
@onready var ground: Node = null
@onready var props: Node = null
@onready var foreground: Node = null
@onready var ambient: Node = null
@onready var arena: Node = null
@onready var checkpoint: Node = null
@onready var boss_circle: Node = null

var encounter_anchors: Dictionary = {}


func _ready() -> void:
	_compose()
	_register_encounter_anchors()


func _compose() -> void:
	# Sky (lowest)
	sky = SkyBand.new()
	sky.world_bounds = WORLD_BOUNDS
	sky.name = "Sky"
	sky.z_index = -1000
	add_child(sky)

	# Far silhouette mountains
	mountains = FarMountains.new()
	mountains.world_bounds = WORLD_BOUNDS
	mountains.name = "FarMountains"
	mountains.z_index = -900
	add_child(mountains)

	# Distant ruins (broken towers, statues)
	ruins = DistantRuins.new()
	ruins.world_bounds = WORLD_BOUNDS
	ruins.name = "DistantRuins"
	ruins.z_index = -800
	add_child(ruins)

	# Ground material (painterly terrain)
	ground = GroundLayer.new()
	ground.world_bounds = WORLD_BOUNDS
	ground.name = "Ground"
	ground.z_index = -200
	add_child(ground)

	# Scattered props (rocks, foliage, broken pillars, banners)
	props = PropScatter.new()
	props.world_bounds = WORLD_BOUNDS
	props.path_start = PATH_START
	props.path_end = PATH_END
	props.name = "Props"
	props.z_index = -90
	add_child(props)

	# Boss arena floor markings + columns
	arena = BossArenaMarker.new()
	arena.center = BOSS_ARENA_CENTER
	arena.name = "BossArena"
	arena.z_index = -180
	add_child(arena)

	# Rune circle at boss center (lights up when fight starts)
	boss_circle = RuneCircleBoss.new()
	boss_circle.global_position = BOSS_ARENA_CENTER
	boss_circle.name = "BossRuneCircle"
	boss_circle.z_index = -170
	add_child(boss_circle)

	# Checkpoint shrine pre-boss
	checkpoint = CheckpointShrine.new()
	checkpoint.global_position = CHECKPOINT
	checkpoint.name = "CheckpointShrine"
	checkpoint.z_index = -80
	add_child(checkpoint)

	# Foreground framing (cliff edges around camera bounds)
	foreground = ForegroundFrame.new()
	foreground.world_bounds = WORLD_BOUNDS
	foreground.name = "ForegroundFrame"
	foreground.z_index = -50
	add_child(foreground)

	# Ambient particles (motes, sparks, drifting embers)
	ambient = AmbientParticles.new()
	ambient.world_bounds = WORLD_BOUNDS
	ambient.name = "AmbientParticles"
	ambient.z_index = -40
	add_child(ambient)


func _register_encounter_anchors() -> void:
	# Authored encounter positions along the path:
	encounter_anchors = {
		"intro_swarm": Vector2(-1300.0, -80.0),
		"melee_pack": Vector2(-500.0, 60.0),
		"mixed_ranged": Vector2(200.0, -60.0),
		"heavy_support": Vector2(1500.0, 40.0),
		"elite": Vector2(2100.0, -40.0),
		"boss": BOSS_ARENA_CENTER,
	}


func player_spawn_position() -> Vector2:
	return PATH_START


func checkpoint_position() -> Vector2:
	return CHECKPOINT


func boss_arena_center() -> Vector2:
	return BOSS_ARENA_CENTER


func anchor(name_id: String) -> Vector2:
	return encounter_anchors.get(name_id, Vector2.ZERO)


func add_loot_pickup(item: Resource, drop_pos: Vector2) -> Node2D:
	var pickup: Node2D = LootPickup.new()
	pickup.item = item
	pickup.global_position = drop_pos
	pickup.z_index = 5
	add_child(pickup)
	return pickup
