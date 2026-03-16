extends CharacterBody2D

signal attacked(target: Node2D)

@onready var stats: StatsComponent = $StatsComponent
@onready var inventory: InventoryComponent = $InventoryComponent

@onready var sprite: Sprite2D = $Sprite
@onready var attack_area: Area2D = $AttackArea
@onready var camera: Camera2D = $Camera2D
@onready var pickup_area: Area2D = $PickupArea

var hero_class: String = ""
var player_id: int = 0
var _is_dead: bool = false  # True while dead and awaiting respawn — blocks all input/movement
var is_on_heal_beacon: bool = false  # True while standing on a heal beacon — blocks all damage
var _death_tween: Tween = null  # Active death/respawn animation tween
var _enemies_in_range: Array[Node2D] = []
# Cached list of nearby enemies for special attacks (updated every 0.2s, avoids full group scan)
var _nearby_enemies: Array[Node2D] = []
var _nearby_enemies_timer: float = 0.0
const NEARBY_ENEMIES_RADIUS_SQ: float = 250000.0  # 500px radius squared
const NEARBY_ENEMIES_INTERVAL: float = 0.2
var _trees_in_range: Array[Node2D] = []
var _target_tree: Node2D = null  # Tree targeted by click-to-harvest
var _target_enemy: Node2D = null  # Enemy targeted by left-click-to-attack
var _is_chopping_tree: bool = false  # When true, spacebar hold = repeat chop (no charge/specials)

# Click-to-move
var _move_target: Vector2 = Vector2.ZERO
var _is_moving_to_target: bool = false
var _stuck_time: float = 0.0  # Tracks how long we've been colliding while moving

var _shadow: Sprite2D = null

# Smooth zoom interpolation
var _target_zoom: Vector2 = Vector2.ZERO  # Zero = uninitialized, will be set on first use
const ZOOM_LERP_SPEED: float = 10.0

# Smooth movement
const ACCEL: float = 900.0  # Pixels/sec² — how fast we reach top speed
const FRICTION: float = 1400.0  # Pixels/sec² — how fast we stop

# Walk animation — 4-frame cycle per direction: idle, stride1, passing, stride2
# Stored as: _walk_frames[dir_key] = [frame1, frame2, frame3]  (idle = _dir_textures[dir_key])
var _walk_frames: Dictionary = {}  # "down" -> [tex1, tex2, tex3], etc.
var _walk_anim_time: float = 0.0
var _walk_anim_frame: int = -1  # -1 = idle
const WALK_FPS: float = 8.0  # Frames per second for walk cycle

# Attack state
var _is_attack_animating: bool = false
var _attack_cooldown: float = 0.0
var _hit_freeze_active: bool = false  # Guard against overlapping hit freezes

# Status effects applied by enemies
var _is_paralyzed: bool = false
var _paralyze_timer: float = 0.0
var _slow_factor: float = 1.0  # 1.0 = normal, < 1.0 = slowed
var _slow_timer: float = 0.0
var _is_bleeding: bool = false
var _bleed_timer: float = 0.0
var _bleed_tick_timer: float = 0.0
var _bleed_damage: float = 2.0
var _bleed_particles: CPUParticles2D = null  # Pooled bleed particle emitter
const BLEED_TICK_INTERVAL: float = 1.0
var _effect_vfx: Sprite2D = null  # Visual indicator for active status effect
# Heal beacon immunity visual feedback
var _was_on_heal_beacon: bool = false  # Previous frame state for detecting transitions
var _immunity_vfx: Sprite2D = null  # Green pulsing aura under hero
var _immunity_vfx_tween: Tween = null  # Looping pulse tween for immunity aura
var _immunity_sprite_tween: Tween = null  # Green tint pulse on hero sprite
var _immunity_label: Label = null  # Floating "IMMUNE" text
var _tex_beacon_green: Texture2D = null  # Cached green beacon texture

# Idle animations — breathing and random fidgets when standing still
var _idle_breathe_tween: Tween = null
var _idle_fidget_tween: Tween = null
var _idle_time: float = 0.0
var _idle_fidget_next: float = 0.0  # Countdown to next fidget
var _is_idle_animating: bool = false  # True during a fidget animation

# Sprite upgrade milestones: level -> texture key suffix
const SPRITE_UPGRADE_LEVELS: Array[int] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
var _current_sprite_tier: int = 0

# Persistent facing direction — updated by movement, attack, and ability input
var _facing: Vector2 = Vector2.DOWN
var _facing_cat: String = "down"  # Current direction category to avoid redundant texture swaps
# Directional idle textures: "down", "up", "side" (flip_h handles left vs right)
var _dir_textures: Dictionary = {}

# Directional attack tracking
var _attack_dir: Vector2 = Vector2.RIGHT   # Direction used in the last attack
var _last_dir_category: String = ""        # "horizontal" | "up" | "down" | "diagonal" | ""

# Melee combo system
# 5 swing types: a=left-to-right, b=right-to-left backhand, c=overhead chop,
#                d=upward thrust, e=spin slash
# Each swing has 3 frames [wind-up, mid-swing, follow-through]
var _combo_swings: Array = []  # Array of Arrays: [[f1,f2,f3], [f1,f2,f3], ...]
var _pickaxe_frames: Array = []  # [wind-up, mid-swing, follow-through] for tree chopping
var _idle_texture: Texture2D = null
var _combo_index: int = 0       # Which swing we're on in the current combo
var _combo_timer: float = 0.0   # Time since last hit — resets combo if too long
const COMBO_WINDOW: float = 1.8 # Seconds before combo resets

# Special attack input — short buffer so rapid taps resolve BEFORE basic attack fires
var _tap_count: int = 0           # Taps accumulated during resolve window
var _tap_resolve_timer: float = 0.0  # Countdown — when it hits 0, resolve the sequence
var _tap_resolved: bool = true    # True once resolved (allows hold-to-attack to resume)
var _charge_time: float = 0.0    # How long attack key has been held continuously
var _is_charging: bool = false    # Whether charge VFX is showing
var _charge_vfx: Sprite2D = null  # Glow VFX while charging
var _charge_arrow: Sprite2D = null  # Directional arrow during charge
var _charge_shake_tween: Tween = null  # Sprite shake during charge
var _charge_sfx_player: AudioStreamPlayer = null  # Looping charge sound
var _charge_vfx_tween: Tween = null  # Looping glow tween during charge
var _is_auto_attacking: bool = false  # True during auto-attack — forces basic swings only
var _effect_vfx_tween: Tween = null  # Looping pulse tween for status effect
var _world_node: Node = null  # Cached world node for VFX spawning
# Cached VFX textures to avoid per-spawn lookups
var _tex_slash_arc: Texture2D = null
var _tex_crystal_white: Texture2D = null
var _tex_selection_red: Texture2D = null
var _tex_beacon_blue: Texture2D = null
# Sprite2D pool for transient VFX (slash arcs, impact sparks, flash rings)
var _vfx_pool: Array[Sprite2D] = []
const VFX_POOL_MAX: int = 40
# Pre-allocated label settings for player damage numbers
var _player_dmg_normal: LabelSettings = null
var _player_dmg_crit: LabelSettings = null
# Cached physics query params (avoids allocation per click)
var _enemy_query_params: PhysicsPointQueryParameters2D = null
var _clickable_query_params: PhysicsPointQueryParameters2D = null
# Shape-based click queries — generous radius for easy clicking/tapping
var _click_circle: CircleShape2D = null
var _enemy_shape_query: PhysicsShapeQueryParameters2D = null
var _tree_shape_query: PhysicsShapeQueryParameters2D = null
const CLICK_RADIUS: float = 30.0  # Desktop click detection radius
const CLICK_RADIUS_MOBILE: float = 55.0  # Larger touch target on mobile
# Damage label pool (avoids Label.new() per hit on player)
var _player_dmg_pool: Array[Label] = []
const PLAYER_DMG_POOL_MAX: int = 30
# Effect label pool (avoids Label.new() per status effect)
var _effect_label_pool: Array[Label] = []
const EFFECT_LABEL_POOL_MAX: int = 10
# Cached LabelSettings for effect labels (keyed by color hex)
var _effect_label_settings_cache: Dictionary = {}
# Bleed particle pool (avoids CPUParticles2D.new() per bleed tick)
var _bleed_particle_pool: Array[CPUParticles2D] = []
const BLEED_PARTICLE_POOL_MAX: int = 5
const CHARGE_GRACE: float = 0.15  # Hold this long before suppressing basic attacks
const TAP_RESOLVE_TIME: float = 0.18  # 180ms buffer — more forgiving for multi-tap specials
const CHARGE_THRESHOLD: float = 1.5   # Hold 1.5s for charged slash

# Screen shake state (procedural, no tween)
var _shake_intensity: float = 0.0
var _shake_time_left: float = 0.0
const SHAKE_DURATION: float = 0.11

# Special attack type for current attack
enum SpecialAttack { NONE, POWER_STRIKE, WHIRLWIND, CHARGED_SLASH, DASH_STRIKE,
	PIERCING_SHOT, ARROW_RAIN, SNIPER_SHOT, SHADOW_STEP }

# Mobile controls
var _is_mobile: bool = false
var _mobile_attack_held: bool = false   # True while mobile attack button is held
var _mobile_atk_canvas: CanvasLayer = null
var _mobile_atk_btn: Button = null
var _mobile_atk_touch_index: int = -1  # Touch index currently pressing the ATK button
var _mobile_potion_btns: Array[Button] = []  # Potion button refs from HUD for multitouch
var _mobile_atk_start_pos: Vector2 = Vector2.ZERO  # Where the ATK touch began (for drag-to-aim)
var _mobile_charge_aim_dir: Vector2 = Vector2.ZERO  # Drag-aim direction while charging (zero = not aiming)
const CHARGE_AIM_DRAG_THRESHOLD: float = 30.0  # Minimum drag distance to change aim direction
# Click/tap aim: any click or non-ATK touch sets attack direction for a short window
var _tap_aim_dir: Vector2 = Vector2.ZERO  # Direction from player toward last click/tap world position
var _tap_aim_timer: float = 0.0  # Remaining validity; expires so stale taps don't affect later attacks
const TAP_AIM_WINDOW: float = 0.6  # Seconds a tap-aim stays valid
# Virtual joystick (mobile — left side of screen)
var _joystick_canvas: CanvasLayer = null
var _joystick_base: Sprite2D = null     # Semi-transparent base circle (appears at touch-down)
var _joystick_knob: Sprite2D = null     # Gold knob circle (tracks finger)
var _joystick_touch_index: int = -1     # Which finger is driving the joystick
var _joystick_input: Vector2 = Vector2.ZERO  # Normalized direction output
var _joystick_center: Vector2 = Vector2.ZERO # Screen-space center (set on touch-down)
var _joystick_active: bool = false
const JOYSTICK_ZONE_FRACTION: float = 0.4   # Left 40% of screen is joystick zone
const JOYSTICK_DEAD_ZONE: float = 0.15      # Inner dead zone (fraction of radius)
const JOYSTICK_RADIUS_LANDSCAPE: float = 80.0
const JOYSTICK_RADIUS_PORTRAIT: float = 110.0
const JOYSTICK_KNOB_FRACTION: float = 0.45  # Knob radius as fraction of base radius
# Two-finger pinch-to-zoom tracking
var _touch_points: Dictionary = {}      # touch index -> screen position (unhandled only)
var _pinch_prev_distance: float = 0.0   # Previous distance between two fingers
# All screen touches — tracked in _input() so UI-consumed touches are included.
# Used for attack direction and movement/diagonal detection on mobile.
var _screen_touches: Dictionary = {}    # touch index -> screen position (all touches)
# Long-press on hero to open stats panel (mobile)
var _longpress_touch_index: int = -1
var _longpress_start_pos: Vector2 = Vector2.ZERO
var _longpress_timer: float = 0.0
const LONGPRESS_DURATION := 2.0
const LONGPRESS_MAX_DRIFT := 20.0  # Cancel if finger moves more than this (pixels)
const ZOOM_MIN_MOBILE := Vector2(2.5, 2.5)  # Less zoom-out on mobile (screen is small)
const ZOOM_MAX_MOBILE := Vector2(7.0, 7.0)  # More zoom-in on mobile

func _ready() -> void:
	add_to_group("player")
	hero_class = GameManager.current_hero_class
	stats.initialize_from_hero(hero_class)
	inventory.setup(stats)

	var tex = SpriteGenerator.get_texture(hero_class)
	if tex:
		sprite.texture = tex
		_idle_texture = tex

	# Cache directional idle textures
	for dir_key in ["down", "up", "side", "down_side", "up_side"]:
		var dtex = SpriteGenerator.get_texture(hero_class + "_dir_" + dir_key)
		if dtex:
			_dir_textures[dir_key] = dtex
	# Default facing texture is the base sprite (facing down/front)
	if not _dir_textures.has("down"):
		_dir_textures["down"] = _idle_texture

	# Cache walk cycle frames (3 frames per direction)
	for dir_key in ["down", "up", "side", "down_side", "up_side"]:
		var frames: Array[Texture2D] = []
		for i in [1, 2, 3]:
			var wtex = SpriteGenerator.get_texture("%s_walk_%s_%d" % [hero_class, dir_key, i])
			if wtex:
				frames.append(wtex)
		if frames.size() == 3:
			_walk_frames[dir_key] = frames

	# Cache melee combo swing frames (5 swing types x 3 frames each)
	for swing_key in ["a", "b", "c", "d", "e"]:
		var f1 = SpriteGenerator.get_texture(hero_class + "_atk" + swing_key + "1")
		var f2 = SpriteGenerator.get_texture(hero_class + "_atk" + swing_key + "2")
		var f3 = SpriteGenerator.get_texture(hero_class + "_atk" + swing_key + "3")
		if f1 and f2 and f3:
			_combo_swings.append([f1, f2, f3])

	# Cache pickaxe frames for tree chopping
	var pf1 = SpriteGenerator.get_texture(hero_class + "_pickaxe1")
	var pf2 = SpriteGenerator.get_texture(hero_class + "_pickaxe2")
	var pf3 = SpriteGenerator.get_texture(hero_class + "_pickaxe3")
	if pf1 and pf2 and pf3:
		_pickaxe_frames = [pf1, pf2, pf3]

	var shape = attack_area.get_node("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = stats.attack_range

	# Shadow under hero
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)

	# Cache VFX textures for reuse (avoids per-spawn dictionary lookups)
	_tex_slash_arc = SpriteGenerator.get_texture("slash_arc")
	_tex_crystal_white = SpriteGenerator.get_texture("crystal_white")
	_tex_selection_red = SpriteGenerator.get_texture("selection_red")
	_tex_beacon_blue = SpriteGenerator.get_texture("beacon_blue")
	_tex_beacon_green = SpriteGenerator.get_texture("beacon_green")
	# Pre-allocate damage label settings (avoids LabelSettings.new() per hit)
	_player_dmg_normal = LabelSettings.new()
	_player_dmg_normal.font_size = 14
	_player_dmg_normal.font_color = Color(1.0, 0.3, 0.3)
	_player_dmg_normal.outline_size = 2
	_player_dmg_normal.outline_color = Color.BLACK
	_player_dmg_crit = LabelSettings.new()
	_player_dmg_crit.font_size = 22
	_player_dmg_crit.font_color = Color(1.0, 0.1, 0.1)
	_player_dmg_crit.outline_size = 2
	_player_dmg_crit.outline_color = Color.BLACK

	# Pre-allocate physics query params (reused every click)
	_enemy_query_params = PhysicsPointQueryParameters2D.new()
	_enemy_query_params.collision_mask = 2  # Enemies only
	_clickable_query_params = PhysicsPointQueryParameters2D.new()
	_clickable_query_params.collision_mask = 4  # NPCs only

	# Shape-based click queries — circle area instead of exact point for forgiving clicks
	_click_circle = CircleShape2D.new()
	_click_circle.radius = CLICK_RADIUS
	_enemy_shape_query = PhysicsShapeQueryParameters2D.new()
	_enemy_shape_query.collision_mask = 2  # Enemies
	_enemy_shape_query.shape = _click_circle
	_tree_shape_query = PhysicsShapeQueryParameters2D.new()
	_tree_shape_query.collision_mask = 4  # Environment (trees)
	_tree_shape_query.shape = _click_circle

	# Sync initial state to DeathCounterSystem
	_sync_to_death_counters()
	# Connect level-up for sprite upgrade and DC sync
	stats.leveled_up.connect(_on_level_up_sprite_upgrade)
	# Register fog of war update trigger
	_register_fog_trigger()

	# Mobile detection and attack button setup
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	if _is_mobile:
		_click_circle.radius = CLICK_RADIUS_MOBILE
		_create_mobile_attack_button()
		_create_mobile_joystick()

	# Connect death/respawn signals for animations
	RespawnManager.player_died.connect(_on_death_animation)
	RespawnManager.player_respawned.connect(_on_respawn_animation)

	# Equipment visual feedback — flash hero with rarity color on equip
	inventory.equipment_changed.connect(_on_equipment_visual_update)

## Public API for external systems (e.g. minimap click) to move the player.
func move_to(world_pos: Vector2) -> void:
	_move_target = world_pos
	_is_moving_to_target = true
	_stuck_time = 0.0
	_spawn_move_indicator(_move_target)


func _physics_process(delta: float) -> void:
	# Long-press timer for stats panel (runs even when dead/paralyzed)
	if _longpress_touch_index >= 0:
		_longpress_timer += delta
		if _longpress_timer >= LONGPRESS_DURATION:
			_longpress_touch_index = -1
			_toggle_hero_stats_panel()

	# Dead: no movement, no actions — waiting for respawn
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Process status effects
	_process_status_effects(delta)

	# Heal beacon immunity visual feedback — detect transitions
	if is_on_heal_beacon and not _was_on_heal_beacon:
		_start_immunity_vfx()
	elif not is_on_heal_beacon and _was_on_heal_beacon:
		_stop_immunity_vfx()
	_was_on_heal_beacon = is_on_heal_beacon

	# Paralyzed: can't move or attack
	if _is_paralyzed:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	# Merge virtual joystick input (mobile)
	if _joystick_input.length() > 0.01:
		input_dir += _joystick_input
	var has_input = input_dir.length_squared() > 0.0
	if has_input:
		input_dir = input_dir.normalized()

	var max_speed = stats.get_total_move_speed() * _slow_factor
	var desired_velocity := Vector2.ZERO

	if has_input:
		_is_moving_to_target = false
		_target_tree = null  # Cancel tree targeting when manually moving
		_target_enemy = null  # Cancel enemy targeting when manually moving
		_is_chopping_tree = false  # Disengage chopping on movement
		desired_velocity = input_dir * max_speed
	elif _is_moving_to_target:
		var dist = global_position.distance_to(_move_target)
		if dist < 5.0:
			_is_moving_to_target = false
		else:
			var dir = (_move_target - global_position).normalized()
			# Ease into stop near the target
			var approach_factor = clampf(dist / 40.0, 0.3, 1.0)
			desired_velocity = dir * max_speed * approach_factor

	# Smooth acceleration / friction
	if desired_velocity.length_squared() > 0.0:
		velocity = velocity.move_toward(desired_velocity, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()

	# Obstacle avoidance: when stuck on a tree/building, steer around it
	if _is_moving_to_target and get_slide_collision_count() > 0 and desired_velocity.length_squared() > 1.0:
		_stuck_time += delta
		if _stuck_time > 0.15:
			var col = get_slide_collision(0)
			var normal = col.get_normal()
			# Pick the perpendicular direction that is closest to the target
			var perp1 = Vector2(-normal.y, normal.x)
			var perp2 = Vector2(normal.y, -normal.x)
			var target_dir = (_move_target - global_position).normalized()
			var avoid_dir = perp1 if perp1.dot(target_dir) > perp2.dot(target_dir) else perp2
			velocity = avoid_dir * stats.get_total_move_speed() * 0.8
			move_and_slide()
	else:
		_stuck_time = 0.0

	_update_walk_anim(delta)
	stats.process_regen(delta)

	# Periodically cache nearby enemies for special attacks (avoids full group scan)
	_nearby_enemies_timer -= delta
	if _nearby_enemies_timer <= 0.0:
		_nearby_enemies_timer = NEARBY_ENEMIES_INTERVAL
		_nearby_enemies.clear()
		var pos = global_position
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and not enemy.get("_is_dead") and enemy.has_method("take_damage"):
				if pos.distance_squared_to(enemy.global_position) < NEARBY_ENEMIES_RADIUS_SQ:
					_nearby_enemies.append(enemy)

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _tap_aim_timer > 0.0:
		_tap_aim_timer -= delta
		if _tap_aim_timer <= 0.0:
			_tap_aim_dir = Vector2.ZERO

	# Auto-chop: when player reaches a clicked tree, chop it automatically
	if _target_tree and is_instance_valid(_target_tree) and not _target_tree.get("_is_chopped"):
		if _target_tree in _trees_in_range:
			_is_moving_to_target = false
			if not _is_attack_animating and _attack_cooldown <= 0.0 and not _is_paralyzed:
				var dir = (_target_tree.global_position - global_position).normalized()
				_set_facing(dir)
				_perform_tree_chop(_target_tree, dir)
	elif _target_tree:
		_target_tree = null  # Tree was chopped or became invalid

	# Auto-attack: when player reaches a left-clicked enemy, attack it
	if _target_enemy and is_instance_valid(_target_enemy) and not _target_enemy.get("_is_dead"):
		if _target_enemy in _enemies_in_range:
			_is_moving_to_target = false
			if not _is_attack_animating and _attack_cooldown <= 0.0 and not _is_paralyzed:
				var dir = (_target_enemy.global_position - global_position).normalized()
				_set_facing(dir)
				_do_basic_auto_attack(dir)
		else:
			# Target moved out of range — chase them
			_move_target = _target_enemy.global_position
			_is_moving_to_target = true
	elif _target_enemy:
		_target_enemy = null  # Enemy died or became invalid

	# Combo timer — reset combo if no attack within window
	if _combo_index > 0:
		_combo_timer += delta
		if _combo_timer >= COMBO_WINDOW:
			_combo_index = 0
			_combo_timer = 0.0
			_last_dir_category = ""

	# --- Tap resolve: wait 0.12s after last press to see if more taps come ---
	if _tap_count > 0 and not _tap_resolved and not _is_paralyzed:
		_tap_resolve_timer -= delta
		if _tap_resolve_timer <= 0.0:
			# Resolve the tap sequence
			var taps = _tap_count
			_tap_count = 0
			_tap_resolved = true
			var move_input = Vector2(
				Input.get_axis("move_left", "move_right"),
				Input.get_axis("move_up", "move_down")
			)
			if _joystick_input.length() > 0.1:
				move_input += _joystick_input
			# On mobile, consider click-to-move velocity OR any non-ATK finger on screen as movement
			var is_moving = move_input.length() > 0.25
			if not is_moving and _is_mobile:
				is_moving = velocity.length() > 30.0 or _get_non_atk_touches().size() > 0
			var is_ranged = hero_class == "shadow_ranger"
			if taps >= 3:
				_try_special_attack(SpecialAttack.ARROW_RAIN if is_ranged else SpecialAttack.WHIRLWIND)
			elif taps >= 2 and is_moving:
				_try_special_attack(SpecialAttack.PIERCING_SHOT if is_ranged else SpecialAttack.POWER_STRIKE)
			else:
				# Single tap, or double-tap without direction = normal attack
				_try_manual_attack()

	# --- Update chopping state: active when trees are in range and we recently chopped one ---
	if _is_chopping_tree:
		var i := _trees_in_range.size() - 1
		while i >= 0:
			var t = _trees_in_range[i]
			if not is_instance_valid(t) or t.get("_is_chopped"):
				_trees_in_range.remove_at(i)
			i -= 1
		if _trees_in_range.is_empty() and (_target_tree == null or not is_instance_valid(_target_tree) or _target_tree.get("_is_chopped")):
			_is_chopping_tree = false

	# --- Hold-to-attack: only after tap sequence resolved ---
	var attack_held = Input.is_action_pressed("attack") or _mobile_attack_held
	if not _is_paralyzed and _tap_resolved:
		if attack_held:
			if _is_chopping_tree:
				# In chopping mode: just keep chopping, no charge/specials
				_charge_time = 0.0
				if not _is_attack_animating and _attack_cooldown <= 0.0:
					var chop_tree = _target_tree if (_target_tree and is_instance_valid(_target_tree) and not _target_tree.get("_is_chopped") and _target_tree in _trees_in_range) else _find_best_tree(_facing)
					if chop_tree:
						var dir = (chop_tree.global_position - global_position).normalized()
						_set_facing(dir)
						_perform_tree_chop(chop_tree, dir)
					else:
						_is_chopping_tree = false
						_try_manual_attack()
			else:
				_charge_time += delta
				if _charge_time >= CHARGE_THRESHOLD and not _is_charging and not _is_attack_animating:
					_is_charging = true
					_start_charge_vfx()
					AudioManager.play_sfx("charge_ready")
				# While holding attack, let player aim: arrow keys, joystick (mobile), or drag (mobile)
				if _charge_time >= CHARGE_GRACE:
					var aim_input = Vector2(
						Input.get_axis("move_left", "move_right"),
						Input.get_axis("move_up", "move_down")
					)
					if _joystick_input.length() > 0.1:
						aim_input += _joystick_input
					if aim_input.length() > 0.25:
						_set_facing(aim_input.normalized())
					elif _is_mobile and _mobile_charge_aim_dir.length() > 0.1:
						_set_facing(_mobile_charge_aim_dir)
				if _is_charging:
					_update_charge_arrow()
				if not _is_charging and _charge_time < CHARGE_GRACE:
					_try_manual_attack()
		else:
			if _is_charging:
				_is_charging = false
				_stop_charge_vfx()
				if not _is_attack_animating:
					var is_ranged = hero_class == "shadow_ranger"
					_try_special_attack(SpecialAttack.SNIPER_SHOT if is_ranged else SpecialAttack.CHARGED_SLASH)
				_mobile_charge_aim_dir = Vector2.ZERO
			_charge_time = 0.0

	# Safety: force-clear stuck charge if touch release was lost (browser/OS swallowed it)
	if _is_charging and not Input.is_action_pressed("attack") and not _mobile_attack_held:
		_is_charging = false
		_stop_charge_vfx()
		_charge_time = 0.0
		_mobile_charge_aim_dir = Vector2.ZERO

	# Procedural screen shake tick
	if _shake_time_left > 0.0:
		_shake_time_left -= delta
		if _shake_time_left <= 0.0:
			camera.offset = Vector2.ZERO
		else:
			var decay = _shake_time_left / SHAKE_DURATION
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity * decay

	# Smooth zoom interpolation
	if _target_zoom != Vector2.ZERO and camera.zoom.distance_squared_to(_target_zoom) > 0.0001:
		camera.zoom = camera.zoom.lerp(_target_zoom, clampf(ZOOM_LERP_SPEED * delta, 0.0, 1.0))

	# Update facing direction from movement (skip during charge — aim takes priority)
	if velocity.length_squared() > 25.0 and not _is_attack_animating and not _is_charging:
		_set_facing(velocity.normalized())

func _update_walk_anim(delta: float) -> void:
	if _is_attack_animating:
		# Kill idle tweens but don't reset transforms — attack tween owns them
		if _idle_breathe_tween and _idle_breathe_tween.is_valid():
			_idle_breathe_tween.kill()
			_idle_breathe_tween = null
		if _idle_fidget_tween and _idle_fidget_tween.is_valid():
			_idle_fidget_tween.kill()
			_idle_fidget_tween = null
		_is_idle_animating = false
		_idle_time = 0.0
		return

	var speed_ratio = velocity.length() / max(stats.get_total_move_speed(), 1.0)
	var frames = _walk_frames.get(_facing_cat, []) as Array

	if speed_ratio > 0.15 and frames.size() == 3:
		# Moving — stop idle animations and reset transforms
		_stop_idle_anims()
		# Advance walk timer — speed scales the animation rate
		_walk_anim_time += delta * WALK_FPS * clampf(speed_ratio, 0.5, 1.2)
		# 4-frame cycle: idle(0) -> stride1(1) -> passing(2) -> stride2(3)
		var new_frame = int(_walk_anim_time) % 4
		if new_frame != _walk_anim_frame:
			_walk_anim_frame = new_frame
			match new_frame:
				0: sprite.texture = _dir_textures.get(_facing_cat, _idle_texture)
				1: sprite.texture = frames[0]
				2: sprite.texture = frames[1]
				3: sprite.texture = frames[2]
	else:
		# Stopped — return to idle pose
		if _walk_anim_frame != -1:
			_walk_anim_frame = -1
			_walk_anim_time = 0.0
			if _idle_texture:
				sprite.texture = _idle_texture
		# Idle animations — breathing + occasional fidgets
		_idle_time += delta
		if not _idle_breathe_tween or not _idle_breathe_tween.is_valid():
			_start_idle_breathe()
		_idle_fidget_next -= delta
		if _idle_fidget_next <= 0.0 and not _is_idle_animating:
			_play_idle_fidget()
			_idle_fidget_next = randf_range(4.0, 9.0)

func _stop_idle_anims() -> void:
	var was_active = _is_idle_animating or (_idle_breathe_tween and _idle_breathe_tween.is_valid())
	if _idle_breathe_tween and _idle_breathe_tween.is_valid():
		_idle_breathe_tween.kill()
		_idle_breathe_tween = null
	if _idle_fidget_tween and _idle_fidget_tween.is_valid():
		_idle_fidget_tween.kill()
		_idle_fidget_tween = null
	if was_active:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
	_is_idle_animating = false
	_idle_time = 0.0
	_idle_fidget_next = randf_range(4.0, 9.0)

func _start_idle_breathe() -> void:
	if _idle_breathe_tween and _idle_breathe_tween.is_valid():
		return
	_idle_breathe_tween = create_tween().set_loops()
	_idle_breathe_tween.tween_property(sprite, "scale", Vector2(1.02, 0.98), 0.9).set_trans(Tween.TRANS_SINE)
	_idle_breathe_tween.tween_property(sprite, "scale", Vector2(0.99, 1.01), 0.9).set_trans(Tween.TRANS_SINE)

func _play_idle_fidget() -> void:
	if _is_attack_animating or _is_idle_animating:
		return
	_is_idle_animating = true
	# Pause breathing while fidgeting (both modify scale)
	if _idle_breathe_tween and _idle_breathe_tween.is_valid():
		_idle_breathe_tween.kill()
		_idle_breathe_tween = null
	_idle_fidget_tween = create_tween()
	var fidget = randi() % 8
	match fidget:
		0:  # Look around — glance to one side then back
			var orig_flip = sprite.flip_h
			_idle_fidget_tween.tween_interval(0.1)
			_idle_fidget_tween.tween_callback(func(): sprite.flip_h = not orig_flip)
			_idle_fidget_tween.tween_interval(0.7)
			_idle_fidget_tween.tween_callback(func(): sprite.flip_h = orig_flip)
		1:  # Weapon ready — quick draw check and sheathe
			_idle_fidget_tween.tween_property(sprite, "position", Vector2(0, -2), 0.1)
			_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.97), 0.1)
			_idle_fidget_tween.tween_interval(0.35)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2.ZERO, 0.15)
			_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.15)
		2:  # Stretch — reach up then settle
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(0.92, 1.08), 0.25).set_trans(Tween.TRANS_SINE)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, -2), 0.25)
			_idle_fidget_tween.tween_interval(0.15)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(1.04, 0.96), 0.15)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, 1), 0.15)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2.ONE, 0.2)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.2)
		3:  # Head scratch — lean to one side with small oscillations
			_idle_fidget_tween.tween_property(sprite, "position", Vector2(2, -1), 0.12)
			_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2(1.03, 0.98), 0.12)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2(2, 0), 0.08)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2(2, -1), 0.08)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2(2, 0), 0.08)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2.ZERO, 0.15)
			_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.15)
		4:  # Impatient tap — foot tap rhythm with bounce
			for _i in range(3):
				_idle_fidget_tween.tween_property(sprite, "position", Vector2(0, -1.5), 0.06)
				_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2(1.02, 0.97), 0.06)
				_idle_fidget_tween.tween_property(sprite, "position", Vector2(0, 0.5), 0.05)
				_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2(0.98, 1.02), 0.05)
			_idle_fidget_tween.tween_property(sprite, "position", Vector2.ZERO, 0.1)
			_idle_fidget_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.1)
		5:  # Battle stance — crouch, flex, hold ready
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(1.1, 0.88), 0.1).set_trans(Tween.TRANS_BACK)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, 3), 0.1)
			# Brief golden flash — channeling power
			_idle_fidget_tween.tween_property(sprite, "modulate", Color(1.2, 1.1, 0.85), 0.08)
			_idle_fidget_tween.tween_interval(0.3)
			# Spring back up
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(0.94, 1.06), 0.1)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, -1), 0.1)
			_idle_fidget_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.12)
		6:  # Shiver — quick cold shudder
			for _i in range(4):
				var x_off = randf_range(-1.5, 1.5)
				_idle_fidget_tween.tween_property(sprite, "position", Vector2(x_off, 0), 0.03)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(0.96, 1.04), 0.06)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.1)
		7:  # Yawn — stretch wide, hold, snap back alert
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(1.08, 0.92), 0.2).set_trans(Tween.TRANS_SINE)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, 1), 0.2)
			_idle_fidget_tween.tween_interval(0.4)
			# Alert snap — something caught their attention
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2(0.95, 1.08), 0.06)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2(0, -2), 0.06)
			_idle_fidget_tween.tween_interval(0.2)
			_idle_fidget_tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
			_idle_fidget_tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.12)
	# Resume breathing after fidget completes
	_idle_fidget_tween.tween_callback(func():
		_is_idle_animating = false
		_start_idle_breathe()
	)

const ZOOM_MIN := Vector2(1.5, 1.5)
const ZOOM_MAX := Vector2(5.0, 5.0)
const ZOOM_STEP := 0.25

func _get_zoom_min() -> Vector2:
	return ZOOM_MIN_MOBILE if _is_mobile else ZOOM_MIN

func _get_zoom_max() -> Vector2:
	return ZOOM_MAX_MOBILE if _is_mobile else ZOOM_MAX

func _is_touch_on_hud_panel(pos: Vector2) -> bool:
	## Returns true if the touch position is in the bottom HUD panel area.
	var vp_size = get_viewport().get_visible_rect().size
	var panel_h = 140.0  # Approximate bottom panel height (3 bars + spacing)
	return pos.y > vp_size.y - panel_h

func _input(event: InputEvent) -> void:
	if _is_dead:
		return
	# Track ALL screen touches (including those consumed by UI) for mobile
	# attack direction and movement/diagonal detection.
	if event is InputEventScreenTouch:
		if event.pressed:
			_screen_touches[event.index] = event.position
		else:
			_screen_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.index in _screen_touches:
			_screen_touches[event.index] = event.position

	# Skip all player input for touches on the HUD bottom panel (MAP, bars, OPT)
	if _is_mobile and event is InputEventScreenTouch and event.pressed:
		if _is_touch_on_hud_panel(event.position):
			return

	# Virtual joystick (left side of screen) — claim touch before ATK button
	if _is_mobile:
		if event is InputEventScreenTouch:
			if event.pressed:
				# Only claim if: no active joystick finger, touch is in left zone, not on ATK
				if _joystick_touch_index == -1:
					var vp_size = get_viewport().get_visible_rect().size
					var in_left_zone = event.position.x < vp_size.x * JOYSTICK_ZONE_FRACTION
					var on_atk = _mobile_atk_btn and is_instance_valid(_mobile_atk_btn) and _mobile_atk_btn.get_global_rect().has_point(event.position)
					if in_left_zone and not on_atk:
						_joystick_touch_index = event.index
						_joystick_center = event.position
						_joystick_active = true
						_show_joystick(event.position)
						get_viewport().set_input_as_handled()
						return
			else:
				if event.index == _joystick_touch_index:
					_joystick_touch_index = -1
					_joystick_input = Vector2.ZERO
					_joystick_active = false
					_hide_joystick()
					get_viewport().set_input_as_handled()
					return
		elif event is InputEventScreenDrag:
			if event.index == _joystick_touch_index:
				var offset = event.position - _joystick_center
				var radius = _get_joystick_radius()
				var clamped = offset if offset.length() <= radius else offset.normalized() * radius
				var normalized = clamped / radius
				if normalized.length() < JOYSTICK_DEAD_ZONE:
					_joystick_input = Vector2.ZERO
				else:
					var len_n = normalized.length()
					_joystick_input = normalized.normalized() * ((len_n - JOYSTICK_DEAD_ZONE) / (1.0 - JOYSTICK_DEAD_ZONE))
				_update_joystick_knob(clamped)
				get_viewport().set_input_as_handled()
				return

	# Manual multitouch handling for the ATK button.  Godot's Button control
	# only responds to the first screen touch (via mouse emulation).  A second
	# finger tapping ATK while another finger is already on screen is silently
	# ignored by Button.  We detect ATK-button touches directly from the raw
	# InputEventScreenTouch so every finger is handled independently.
	if _is_mobile and _mobile_atk_btn and is_instance_valid(_mobile_atk_btn):
		if event is InputEventScreenTouch:
			var atk_rect = _mobile_atk_btn.get_global_rect()
			if event.pressed:
				if atk_rect.has_point(event.position) and _mobile_atk_touch_index == -1:
					_mobile_atk_touch_index = event.index
					_mobile_atk_start_pos = event.position
					_mobile_charge_aim_dir = Vector2.ZERO
					_on_mobile_attack_pressed()
					get_viewport().set_input_as_handled()
			else:
				if event.index == _mobile_atk_touch_index:
					_mobile_atk_touch_index = -1
					_on_mobile_attack_released()
					get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			if event.index == _mobile_atk_touch_index and _mobile_attack_held:
				var drag_offset = event.position - _mobile_atk_start_pos
				if drag_offset.length() > CHARGE_AIM_DRAG_THRESHOLD:
					_mobile_charge_aim_dir = drag_offset.normalized()
					_set_facing(_mobile_charge_aim_dir)

	# Manual multitouch handling for potion buttons (same reason as ATK above).
	if _is_mobile and event is InputEventScreenTouch and event.pressed:
		for i in range(_mobile_potion_btns.size()):
			var btn = _mobile_potion_btns[i]
			if btn and is_instance_valid(btn) and btn.visible:
				if btn.get_global_rect().has_point(event.position):
					inventory.use_consumable(i)
					get_viewport().set_input_as_handled()
					return

	# Non-ATK finger tap: record aim direction (used by attacks and charge aiming)
	if _is_mobile and event is InputEventScreenTouch and event.pressed and event.index != _mobile_atk_touch_index:
		var tap_world = _screen_to_world(event.position)
		var aim = (tap_world - global_position)
		if aim.length() > 5.0:
			_tap_aim_dir = aim.normalized()
			_tap_aim_timer = TAP_AIM_WINDOW
			if _mobile_attack_held and _charge_time >= CHARGE_GRACE:
				_mobile_charge_aim_dir = aim.normalized()
				_set_facing(_mobile_charge_aim_dir)
				get_viewport().set_input_as_handled()

	# Long-press on hero to open stats panel (mobile only)
	if _is_mobile:
		if event is InputEventScreenTouch:
			if event.pressed:
				# Only start tracking if NOT on ATK button and near the player
				var on_atk = _mobile_atk_btn and is_instance_valid(_mobile_atk_btn) and _mobile_atk_btn.get_global_rect().has_point(event.position)
				if not on_atk and _longpress_touch_index == -1:
					var player_screen = _get_player_screen_pos()
					if event.position.distance_to(player_screen) < 80.0:
						_longpress_touch_index = event.index
						_longpress_start_pos = event.position
						_longpress_timer = 0.0
						_set_longpress_outline(true)
			else:
				if event.index == _longpress_touch_index:
					_longpress_touch_index = -1
					_set_longpress_outline(false)
		elif event is InputEventScreenDrag:
			if event.index == _longpress_touch_index:
				if event.position.distance_to(_longpress_start_pos) > LONGPRESS_MAX_DRIFT:
					_longpress_touch_index = -1
					_set_longpress_outline(false)

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	var z_min = _get_zoom_min()
	var z_max = _get_zoom_max()

	# Two-finger pinch-to-zoom via touch tracking (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			_pinch_prev_distance = 0.0
		if _touch_points.size() == 2:
			var keys = _touch_points.keys()
			_pinch_prev_distance = (_touch_points[keys[0]] as Vector2).distance_to(_touch_points[keys[1]])
	if event is InputEventScreenDrag:
		if event.index in _touch_points:
			_touch_points[event.index] = event.position
		if _touch_points.size() >= 2 and _pinch_prev_distance > 0.0:
			var keys = _touch_points.keys()
			var p1 = _touch_points[keys[0]] as Vector2
			var p2 = _touch_points[keys[1]] as Vector2
			var dist = p1.distance_to(p2)
			if dist > 10.0:  # Avoid jitter from near-zero distances
				var factor = dist / _pinch_prev_distance
				camera.zoom = (camera.zoom * factor).clamp(z_min, z_max)
				_pinch_prev_distance = dist
			return

	if event is InputEventMagnifyGesture:
		# Trackpad pinch: factor > 1 = pinch out (zoom in), < 1 = pinch in (zoom out)
		_target_zoom = (camera.zoom * event.factor).clamp(z_min, z_max)
		return

	# While charging, clicks set aim direction instead of moving
	if _charge_time >= CHARGE_GRACE and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			var aim_world = _get_world_mouse_pos()
			var aim = (aim_world - global_position)
			if aim.length() > 5.0:
				_set_facing(aim.normalized())
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var base = _target_zoom if _target_zoom != Vector2.ZERO else camera.zoom
			_target_zoom = (base + Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(z_min, z_max)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var base = _target_zoom if _target_zoom != Vector2.ZERO else camera.zoom
			_target_zoom = (base - Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(z_min, z_max)
			return

		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			# Block tap-to-move in the joystick zone on mobile (joystick owns it)
			if _is_mobile and _joystick_active:
				var vp_size = get_viewport().get_visible_rect().size
				if event.position.x < vp_size.x * JOYSTICK_ZONE_FRACTION:
					return
			# Record click direction for attack aiming
			var _click_world = _get_world_mouse_pos()
			var _click_aim = (_click_world - global_position)
			if _click_aim.length() > 5.0:
				_tap_aim_dir = _click_aim.normalized()
				_tap_aim_timer = TAP_AIM_WINDOW
			# Right-click on self = open hero stats panel
			if event.button_index == MOUSE_BUTTON_RIGHT:
				var mouse_world = _get_world_mouse_pos()
				if global_position.distance_squared_to(mouse_world) < 625.0:  # 25^2
					_toggle_hero_stats_panel()
					return
				# Right-click on enemy = show info
				var enemy_target = _get_enemy_at_mouse()
				if enemy_target:
					if enemy_target.has_method("show_info"):
						enemy_target.show_info()
					return
				# Right-click on tree = show wood info
				var rclick_tree = _get_tree_at_mouse()
				if rclick_tree and rclick_tree.has_method("show_wood_info"):
					rclick_tree.show_wood_info()
					return
				# Right-click on watchtower = show stats
				var rclick_tower = _get_watchtower_at_mouse()
				if rclick_tower:
					_show_watchtower_stats(rclick_tower)
					return
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Left-click on enemy = attack (in range) or move-to-attack
				var lclick_enemy = _get_enemy_at_mouse()
				if lclick_enemy and not _is_paralyzed:
					_is_chopping_tree = false
					_target_tree = null
					if lclick_enemy in _enemies_in_range:
						_target_enemy = lclick_enemy
						_try_manual_attack()
					else:
						_target_enemy = lclick_enemy
						_move_target = lclick_enemy.global_position
						_is_moving_to_target = true
						_spawn_move_indicator(_move_target)
					return
				# Left-click on tree = move to it and auto-chop
				var lclick_tree = _get_tree_at_mouse()
				if lclick_tree:
					_target_enemy = null
					_target_tree = lclick_tree
					_move_target = lclick_tree.global_position
					_is_moving_to_target = true
					_spawn_move_indicator(_move_target)
					return
			# Both mouse buttons move to clicked position
			_target_tree = null
			_target_enemy = null
			_is_chopping_tree = false
			var clicked = _get_clickable_at_mouse()
			if clicked and clicked.has_method("interact"):
				_move_target = clicked.global_position
			else:
				_move_target = _get_world_mouse_pos()
			_is_moving_to_target = true
			_spawn_move_indicator(_move_target)

	# Window controls
	if event.is_action_pressed("ui_cancel"):
		var menus = get_tree().get_nodes_in_group("pause_menu")
		if menus.size() > 0:
			menus[0].toggle()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var mode = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Tap buffering: each press restarts the short resolve timer
	if event.is_action_pressed("attack") and not _is_paralyzed:
		_tap_count += 1
		_tap_resolve_timer = TAP_RESOLVE_TIME  # Reset window on each new tap
		_tap_resolved = false

	# Potion slots
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: inventory.use_consumable(0)
			KEY_2: inventory.use_consumable(1)
			KEY_3: inventory.use_consumable(2)

func _try_manual_attack() -> void:
	if _is_attack_animating or _attack_cooldown > 0.0:
		return

	_attack_cooldown = 0.5 / stats.attack_speed

	# Determine attack direction: held keys/joystick > recent click/tap aim > mobile touch > velocity > facing
	var input_raw = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if _joystick_input.length() > 0.1:
		input_raw += _joystick_input
	var attack_dir: Vector2
	if input_raw.length() > 0.25:
		attack_dir = input_raw.normalized()
	elif _tap_aim_dir.length() > 0.1 and _tap_aim_timer > 0.0:
		attack_dir = _tap_aim_dir
	elif _is_mobile:
		# On mobile: derive direction from active screen touches, then velocity, then facing
		var touch_dir = _get_mobile_touch_dir()
		if touch_dir.length() > 0.1:
			attack_dir = touch_dir
		elif velocity.length() > 30.0:
			attack_dir = velocity.normalized()
		else:
			attack_dir = _facing
	else:
		attack_dir = _facing

	# Update facing to match attack direction
	_set_facing(attack_dir)

	# Diagonal keys + attack = dash strike / shadow step
	# On mobile: two non-ATK fingers on screen = diagonal intent, or moving diagonally
	var is_diagonal = abs(input_raw.x) > 0.3 and abs(input_raw.y) > 0.3
	if not is_diagonal and _is_mobile:
		var non_atk = _get_non_atk_touches()
		if non_atk.size() >= 2:
			# Two fingers on screen (not on ATK) signals diagonal attack intent
			# Compute attack direction from player toward finger midpoint
			var touch_dir = _get_mobile_touch_dir()
			if touch_dir.length() > 0.1:
				attack_dir = touch_dir
				_set_facing(attack_dir)
			is_diagonal = true
		elif velocity.length() > 30.0:
			var vel_norm = velocity.normalized()
			is_diagonal = abs(vel_norm.x) > 0.3 and abs(vel_norm.y) > 0.3
	if is_diagonal:
		if hero_class == "shadow_ranger":
			_execute_shadow_step(attack_dir)
		else:
			_execute_dash_strike(attack_dir)
		return

	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.get("_is_dead"))

	# Find the best target in the attack direction
	var hit_target: Node2D = null
	var mouse_target = _get_enemy_at_mouse()
	if mouse_target and mouse_target in _enemies_in_range:
		hit_target = mouse_target
	else:
		var best_score := -INF
		for enemy in _enemies_in_range:
			var to_enemy = (enemy.global_position - global_position)
			var dot = attack_dir.dot(to_enemy.normalized())
			if dot > 0.3:
				var score = dot - to_enemy.length() * 0.001
				if score > best_score:
					best_score = score
					hit_target = enemy

	if hit_target:
		_target_enemy = hit_target
		_perform_attack(hit_target, attack_dir)
	else:
		# No enemy — check for a harvestable tree in swing direction
		var tree_target = _find_best_tree(attack_dir)
		if tree_target:
			_perform_tree_chop(tree_target, attack_dir)
		else:
			AudioManager.play_sfx("sword_swing")
			_perform_swing_no_target(attack_dir)

func _do_basic_auto_attack(dir: Vector2) -> void:
	# Plain basic attack only — no dash strikes, no combo progression.
	# Used by the auto-attack loop so held keys don't accidentally trigger specials.
	_attack_cooldown = 0.5 / stats.attack_speed
	_combo_timer = 0.0
	_is_auto_attacking = true
	_perform_attack(_target_enemy, dir)
	_is_auto_attacking = false

func _process_status_effects(delta: float) -> void:
	if _is_paralyzed:
		_paralyze_timer -= delta
		if _paralyze_timer <= 0:
			_is_paralyzed = false
			_clear_effect_vfx()
	if _slow_factor < 1.0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
			_clear_effect_vfx()
	if _is_bleeding:
		_bleed_timer -= delta
		_bleed_tick_timer -= delta
		if _bleed_tick_timer <= 0:
			_bleed_tick_timer = BLEED_TICK_INTERVAL
			var stats_comp = $StatsComponent
			stats_comp.take_damage(int(_bleed_damage))
			_spawn_damage_number(int(_bleed_damage), false)
			_spawn_bleed_particles()
			AudioManager.play_sfx("bleed_tick", -12.0)
		if _bleed_timer <= 0:
			_is_bleeding = false
			_clear_effect_vfx()

func apply_effect(effect_type: String, duration: float, value: float = 0.0) -> void:
	if is_on_heal_beacon:
		return  # Immune to all effects while on heal beacon
	match effect_type:
		"knockback":
			var dir = value  # Reuse value slot... actually we need direction
			# Knockback is handled by passing direction + force via apply_knockback_effect
			pass
		"paralyze":
			_is_paralyzed = true
			_paralyze_timer = duration
			_spawn_effect_vfx(Color(0.8, 0.2, 1.0, 0.6), duration, "PARALYZED!")
		"slow":
			_slow_factor = 0.4
			_slow_timer = duration
			_spawn_effect_vfx(Color(0.2, 0.5, 1.0, 0.5), duration, "SLOWED!")
		"bleeding":
			_is_bleeding = true
			_bleed_timer = duration
			_bleed_tick_timer = 0.0  # Tick immediately
			_bleed_damage = value if value > 0 else 2.0
			_spawn_effect_vfx(Color(0.8, 0.1, 0.1, 0.6), duration, "BLEEDING!")

func apply_knockback_effect(dir: Vector2, force: float) -> void:
	if is_on_heal_beacon:
		return  # Immune to knockback while on heal beacon
	# Strong knockback from enemy effect proc
	velocity = dir * force
	_spawn_effect_label("KNOCKBACK!", Color(1.0, 0.6, 0.1))

func _spawn_effect_vfx(color: Color, duration: float, label_text: String) -> void:
	_clear_effect_vfx()
	# Pulsing aura around the player
	_effect_vfx = Sprite2D.new()
	_effect_vfx.texture = _tex_beacon_blue
	_effect_vfx.modulate = color
	_effect_vfx.z_index = -1
	add_child(_effect_vfx)
	if _effect_vfx_tween and _effect_vfx_tween.is_valid():
		_effect_vfx_tween.kill()
	_effect_vfx_tween = _effect_vfx.create_tween().set_loops()
	_effect_vfx_tween.tween_property(_effect_vfx, "modulate:a", color.a * 0.3, 0.4)
	_effect_vfx_tween.tween_property(_effect_vfx, "modulate:a", color.a, 0.4)
	# Auto-cleanup after duration
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(duration)
	cleanup_tween.tween_callback(_clear_effect_vfx)
	# Label
	_spawn_effect_label(label_text, color)

func _spawn_effect_label(text: String, color: Color) -> void:
	var label: Label
	if _effect_label_pool.size() > 0:
		label = _effect_label_pool.pop_back()
	else:
		label = Label.new()
	label.text = text
	label.position = Vector2(-30, -50)
	label.modulate.a = 1.0
	var color_key = color.to_html()
	if not _effect_label_settings_cache.has(color_key):
		var settings = LabelSettings.new()
		settings.font_size = 16
		settings.font_color = color
		settings.outline_size = 2
		settings.outline_color = Color.BLACK
		_effect_label_settings_cache[color_key] = settings
	label.label_settings = _effect_label_settings_cache[color_key]
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 25, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_recycle_effect_label.bind(label))

func _recycle_effect_label(label: Label) -> void:
	if is_instance_valid(label):
		label.get_parent().remove_child(label)
		if _effect_label_pool.size() < EFFECT_LABEL_POOL_MAX:
			_effect_label_pool.append(label)
		else:
			label.queue_free()

func _spawn_bleed_particles() -> void:
	var particles: CPUParticles2D
	if _bleed_particle_pool.size() > 0:
		particles = _bleed_particle_pool.pop_back()
	else:
		particles = CPUParticles2D.new()
		particles.one_shot = true
		particles.amount = 6
		particles.lifetime = 0.6
		particles.explosiveness = 0.8
		particles.direction = Vector2(0, 1)
		particles.spread = 30.0
		particles.gravity = Vector2(0, 80)
		particles.initial_velocity_min = 15.0
		particles.initial_velocity_max = 35.0
		particles.scale_amount_min = 1.5
		particles.scale_amount_max = 3.0
		particles.color = Color(0.7, 0.05, 0.05, 0.9)
	particles.emitting = true
	add_child(particles)
	var cleanup = create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(_recycle_bleed_particles.bind(particles))

func _recycle_bleed_particles(particles: CPUParticles2D) -> void:
	if is_instance_valid(particles):
		particles.emitting = false
		particles.get_parent().remove_child(particles)
		if _bleed_particle_pool.size() < BLEED_PARTICLE_POOL_MAX:
			_bleed_particle_pool.append(particles)
		else:
			particles.queue_free()

func _clear_effect_vfx() -> void:
	if _effect_vfx_tween and _effect_vfx_tween.is_valid():
		_effect_vfx_tween.kill()
		_effect_vfx_tween = null
	if _effect_vfx and is_instance_valid(_effect_vfx):
		_effect_vfx.queue_free()
		_effect_vfx = null

# --- Heal Beacon Immunity Visual Feedback ---

func _start_immunity_vfx() -> void:
	_stop_immunity_vfx()  # Clean up any leftover state

	# 1) Green pulsing aura under hero (larger, slower pulse than status effects)
	_immunity_vfx = Sprite2D.new()
	_immunity_vfx.texture = _tex_beacon_green if _tex_beacon_green else _tex_beacon_blue
	_immunity_vfx.modulate = Color(0.3, 1.0, 0.5, 0.55)
	_immunity_vfx.scale = Vector2(1.3, 1.3)
	_immunity_vfx.z_index = -1
	add_child(_immunity_vfx)
	# Looping pulse: fade + scale breathe
	_immunity_vfx_tween = _immunity_vfx.create_tween().set_loops()
	_immunity_vfx_tween.tween_property(_immunity_vfx, "modulate:a", 0.2, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_immunity_vfx_tween.parallel().tween_property(_immunity_vfx, "scale", Vector2(1.5, 1.5), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_immunity_vfx_tween.tween_property(_immunity_vfx, "modulate:a", 0.55, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_immunity_vfx_tween.parallel().tween_property(_immunity_vfx, "scale", Vector2(1.3, 1.3), 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# 2) Green tint on hero sprite — gentle pulse between white-green and bright green
	_immunity_sprite_tween = create_tween().set_loops()
	_immunity_sprite_tween.tween_property(sprite, "modulate", Color(0.7, 1.3, 0.75), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_immunity_sprite_tween.tween_property(sprite, "modulate", Color(0.85, 1.15, 0.85), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# 3) Floating "IMMUNE" label that bobs gently
	_immunity_label = Label.new()
	_immunity_label.text = "IMMUNE"
	_immunity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_immunity_label.position = Vector2(-28, -48)
	var color_key = Color(0.3, 1.0, 0.5).to_html()
	if not _effect_label_settings_cache.has(color_key + "_imm"):
		var settings = LabelSettings.new()
		var is_mobile = GameManager.is_mobile_device()
		settings.font_size = 22 if is_mobile else 11
		settings.font_color = Color(0.3, 1.0, 0.5)
		settings.outline_size = 4 if is_mobile else 2
		settings.outline_color = Color(0.0, 0.2, 0.05)
		_effect_label_settings_cache[color_key + "_imm"] = settings
	_immunity_label.label_settings = _effect_label_settings_cache[color_key + "_imm"]
	add_child(_immunity_label)
	# Gentle bob animation
	var label_tween = _immunity_label.create_tween().set_loops()
	label_tween.tween_property(_immunity_label, "position:y", -53.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	label_tween.tween_property(_immunity_label, "position:y", -48.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_immunity_vfx() -> void:
	# Kill aura
	if _immunity_vfx_tween and _immunity_vfx_tween.is_valid():
		_immunity_vfx_tween.kill()
		_immunity_vfx_tween = null
	if _immunity_vfx and is_instance_valid(_immunity_vfx):
		_immunity_vfx.queue_free()
		_immunity_vfx = null
	# Restore sprite modulate
	if _immunity_sprite_tween and _immunity_sprite_tween.is_valid():
		_immunity_sprite_tween.kill()
		_immunity_sprite_tween = null
	sprite.modulate = Color.WHITE
	# Kill label
	if _immunity_label and is_instance_valid(_immunity_label):
		_immunity_label.queue_free()
		_immunity_label = null

# --- Special Attack System ---

func _try_special_attack(special: SpecialAttack) -> void:
	if _is_attack_animating:
		return

	var attack_dir = _get_aim_direction()
	_set_facing(attack_dir)

	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.get("_is_dead"))

	match special:
		SpecialAttack.POWER_STRIKE:
			_execute_power_strike(attack_dir)
		SpecialAttack.WHIRLWIND:
			_execute_whirlwind(attack_dir)
		SpecialAttack.CHARGED_SLASH:
			_execute_charged_slash(attack_dir)
		SpecialAttack.DASH_STRIKE:
			_execute_dash_strike(attack_dir)
		SpecialAttack.PIERCING_SHOT:
			_execute_piercing_shot(attack_dir)
		SpecialAttack.ARROW_RAIN:
			_execute_arrow_rain(attack_dir)
		SpecialAttack.SNIPER_SHOT:
			_execute_sniper_shot(attack_dir)
		SpecialAttack.SHADOW_STEP:
			_execute_shadow_step(attack_dir)

func _execute_power_strike(attack_dir: Vector2) -> void:
	# Double-tap: AoE directional slam — lunge forward, hit up to 5 enemies
	# in a cone, 1.5x damage with splash. Satisfying bouncy animation.
	_is_attack_animating = true
	_attack_cooldown = 0.8 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.5
	var lunge_dist := 80.0  # How far the player actually moves forward
	var splash_range := 120.0  # Cone length for finding targets
	var splash_half_angle := 0.7  # ~40° half-cone (dot product threshold ~0.76)

	# Snapshot targets in a cone in front of the player (up to 5)
	var start_pos = global_position
	var cone_targets: Array[Node2D] = []
	for enemy in _nearby_enemies:
		if not is_instance_valid(enemy) or enemy.get("_is_dead") or not enemy.has_method("take_damage"):
			continue
		var to_enemy = enemy.global_position - start_pos
		var dist = to_enemy.length()
		if dist > splash_range + lunge_dist or dist < 1.0:
			continue
		var dot = dir.dot(to_enemy.normalized())
		if dot > cos(splash_half_angle):
			cone_targets.append(enemy)
	# Sort by distance, cap at 5
	cone_targets.sort_custom(func(a, b): return a.global_position.distance_squared_to(start_pos) < b.global_position.distance_squared_to(start_pos))
	if cone_targets.size() > 5:
		cone_targets.resize(5)

	# Pick overhead chop frames for the heavy feel
	var frames = _combo_swings[2] if _combo_swings.size() > 2 else []

	var tween = create_tween()

	# === WIND-UP: Dramatic coil back ===
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Squash down — gathering power
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", base_pos - dir * 12.0 + Vector2(0, 4), 0.08).set_ease(Tween.EASE_OUT)
	# Spring up — anticipation bounce
	tween.tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "position", base_pos - dir * 8.0 + Vector2(0, -12), 0.05).set_ease(Tween.EASE_OUT)
	# Gold flash — charge up
	tween.tween_callback(func(): sprite.modulate = Color(1.5, 1.2, 0.5))
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Second coil bounce
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.7), 0.04).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, -6), 0.03)

	# === LUNGE: Slam forward — move the actual player, not just sprite ===
	tween.tween_callback(func():
		# Actually move the player body forward
		global_position += dir * lunge_dist
	)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Sprite overshoots ahead then snaps back — impact feel
	tween.tween_property(sprite, "position", base_pos + dir * 30.0, 0.04).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2(0.65, 1.5), 0.03).set_ease(Tween.EASE_OUT)

	# === IMPACT: Hit all cone targets, big VFX ===
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		var hit_count := 0
		for enemy in cone_targets:
			if is_instance_valid(enemy) and not enemy.get("_is_dead"):
				var result = CombatManager.calculate_damage(stats.get_stats_dict(), enemy.get_stats_dict(), dmg_mult)
				enemy.take_damage(result["damage"], result["is_crit"])
				var kb_dir = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(kb_dir, 120.0)
				_spawn_impact_vfx(enemy.global_position, result["is_crit"])
				hit_count += 1
		# Big directional slash VFX fan
		_spawn_slash_vfx(dir, 70.0, 2.4)
		_spawn_slash_vfx(dir.rotated(0.35), 55.0, 1.8)
		_spawn_slash_vfx(dir.rotated(-0.35), 55.0, 1.8)
		if hit_count > 0:
			_do_screen_shake(10.0)
			_do_hit_freeze(true)
		else:
			_do_screen_shake(5.0)
		AudioManager.play_sfx("power_strike")
		_spawn_effect_label("POWER STRIKE!", Color(1.0, 0.85, 0.2))
	)

	# === BOUNCY RECOVERY: Satisfying spring oscillations ===
	# Slam recoil — sprite bounces back
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.65), 0.04).set_ease(Tween.EASE_OUT)
	# Bounce up
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, -6), 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.04).set_ease(Tween.EASE_OUT)
	# Settle bounce
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.04).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.88), 0.04).set_ease(Tween.EASE_IN_OUT)
	# Final settle
	tween.tween_property(sprite, "scale", Vector2(0.95, 1.06), 0.04).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.02, 0.98), 0.03).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.04).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.03)
	_anim_return_to_idle(tween, base_pos)

func _execute_whirlwind(attack_dir: Vector2) -> void:
	# Triple-tap: AoE attack hitting ALL enemies in range, 720° double spin
	_is_attack_animating = true
	_attack_cooldown = 1.0 / stats.attack_speed  # Longer cooldown for AoE
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.2

	# Use spin slash frames
	var frames = _combo_swings[4] if _combo_swings.size() > 4 else []

	var tween = create_tween()
	# Crouch and coil
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 3), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.04)
	# Glow purple-white during spin
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.9, 1.3))
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Double spin (720°) — big sweeping AoE feel
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", TAU * 2.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.32)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.set_parallel(false)
	# Spawn slash VFX at midpoint of spin (2 opposing arcs for 360° feel)
	tween.tween_callback(func():
		_spawn_slash_vfx(dir, 50.0, 2.0)
		_spawn_slash_vfx(dir.rotated(PI), 45.0, 1.6)
	)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Hit ALL enemies in attack range
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		var hit_count := 0
		for enemy in _enemies_in_range:
			if is_instance_valid(enemy) and not enemy.get("_is_dead") and enemy.has_method("take_damage"):
				var result = CombatManager.calculate_damage(stats.get_stats_dict(), enemy.get_stats_dict(), dmg_mult)
				enemy.take_damage(result["damage"], result["is_crit"])
				var kb_dir = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(kb_dir, 70.0)
				_spawn_impact_vfx(enemy.global_position, result["is_crit"])
				hit_count += 1
		if hit_count > 0:
			_do_screen_shake(8.0)
			_do_hit_freeze(true)
		else:
			_do_screen_shake(3.0)
		AudioManager.play_sfx("whirlwind")
		_spawn_effect_label("WHIRLWIND!", Color(0.8, 0.5, 1.0))
	)
	# Unwind
	tween.tween_property(sprite, "rotation", 0.0, 0.1)
	tween.tween_interval(0.06)
	_anim_return_to_idle(tween, base_pos)

func _execute_charged_slash(attack_dir: Vector2) -> void:
	# Hold attack 1.5s: Dash the full slash range with running animation,
	# cleaving all enemies in the path. 1.6x damage.
	_is_attack_animating = true
	_attack_cooldown = 0.8 / stats.attack_speed
	var dir = attack_dir
	var perp = Vector2(-dir.y, dir.x)
	var base_pos = sprite.position
	var dmg_mult := 1.6
	var slash_range := stats.attack_range * 3.5  # 3.5x normal attack range
	var slash_width := 30.0  # Half-width of the slash corridor

	# Snapshot targets along the entire slash path BEFORE the animation plays.
	# Query ALL enemies in the world, not just _enemies_in_range (AttackArea is too small).
	var start_pos = global_position
	var end_pos = start_pos + dir * slash_range
	var slash_targets: Array[Node2D] = []
	for enemy in _nearby_enemies:
		if not is_instance_valid(enemy) or enemy.get("_is_dead") or not enemy.has_method("take_damage"):
			continue
		var dist_to_path = _point_to_segment_dist(enemy.global_position, start_pos, end_pos)
		if dist_to_path <= slash_width:
			# Must be in front of the player, not behind
			var to_enemy = enemy.global_position - start_pos
			if dir.dot(to_enemy) > 0.0:
				slash_targets.append(enemy)

	# Use thrust frames for the final slash impact
	var frames = _combo_swings[3] if _combo_swings.size() > 3 else []

	# Walk frames for running animation during the dash
	var walk_tex = _walk_frames.get(_facing_cat, []) as Array
	var idle_tex = _dir_textures.get(_facing_cat, _idle_texture)
	var run_cycle: Array = []
	if walk_tex.size() == 3 and idle_tex:
		run_cycle = [idle_tex, walk_tex[0], walk_tex[1], walk_tex[2]]

	# Dash timing: snappy but visible, scales with distance
	var dash_duration := clampf(slash_range / 500.0, 0.15, 0.40)

	var tween = create_tween()

	# --- COIL: Brief pull-back with golden flash ---
	tween.tween_callback(func(): sprite.modulate = Color(2.0, 1.8, 1.0))
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.04)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.03)

	# --- DASH: Running animation + afterimage trail (concurrent with body movement) ---
	tween.tween_callback(func():
		AudioManager.play_sfx("dash_swoosh")
		# Running animation: rapid walk-frame cycling via separate tween
		if run_cycle.size() == 4:
			var run_steps = maxi(int(dash_duration / 0.05), 3)
			var step_time = dash_duration / float(run_steps)
			var run_tw = create_tween()
			for j in range(run_steps):
				# .bind() captures the texture value NOW, safe across loop iterations
				run_tw.tween_callback(sprite.set.bind("texture", run_cycle[j % 4]))
				run_tw.tween_interval(step_time)
		# Afterimage trail: ghostly sprite copies left behind during the dash
		var ghost_count = maxi(int(dash_duration / 0.06), 3)
		var ghost_interval = dash_duration / float(ghost_count)
		var ghost_tw = create_tween()
		for _k in range(ghost_count):
			ghost_tw.tween_callback(func():
				var ghost = _get_pooled_vfx()
				ghost.texture = sprite.texture
				ghost.global_position = global_position
				ghost.flip_h = sprite.flip_h
				ghost.scale = sprite.scale
				ghost.modulate = Color(1.0, 0.9, 0.3, 0.45)
				ghost.z_index = -1
				_get_world_node().add_child(ghost)
				var gt = ghost.create_tween()
				gt.tween_property(ghost, "modulate:a", 0.0, 0.25)
				gt.tween_callback(_recycle_vfx.bind(ghost))
			)
			ghost_tw.tween_interval(ghost_interval)
	)
	# Physically move the character body forward + lean sprite into the run
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, dash_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, dash_duration * 0.3)
	tween.set_parallel(false)

	# --- SLASH IMPACT: devastating cleave at the end of the dash ---
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)
		# Slash VFX arcs along the full trail (world-space positions from start to end)
		var world = _get_world_node()
		var vfx_steps := 4
		for i in range(vfx_steps):
			var frac = (float(i) + 0.5) / float(vfx_steps)
			var trail_pos = start_pos + dir * slash_range * frac
			var vfx_scale = lerpf(2.2, 1.4, frac)
			# Main slash arc at this trail position
			var s1 = _get_pooled_vfx()
			s1.texture = _tex_slash_arc
			s1.global_position = trail_pos
			s1.rotation = dir.angle()
			s1.scale = Vector2(vfx_scale, vfx_scale)
			s1.modulate = Color(1.0, 0.9, 0.6, 0.9)
			world.add_child(s1)
			var t1 = s1.create_tween()
			t1.set_parallel(true)
			t1.tween_property(s1, "scale", s1.scale * 1.4, 0.15)
			t1.tween_property(s1, "modulate:a", 0.0, 0.2)
			t1.set_parallel(false)
			t1.tween_callback(_recycle_vfx.bind(s1))
			# Offset slash at alternating angle for visual width
			var angle_off = 0.25 if i % 2 == 0 else -0.25
			var s2 = _get_pooled_vfx()
			s2.texture = _tex_slash_arc
			s2.global_position = trail_pos + perp * 8.0 * (1.0 if i % 2 == 0 else -1.0)
			s2.rotation = dir.rotated(angle_off).angle()
			s2.scale = Vector2(vfx_scale * 0.8, vfx_scale * 0.8)
			s2.modulate = Color(1.0, 0.9, 0.6, 0.9)
			world.add_child(s2)
			var t2 = s2.create_tween()
			t2.set_parallel(true)
			t2.tween_property(s2, "scale", s2.scale * 1.4, 0.15)
			t2.tween_property(s2, "modulate:a", 0.0, 0.2)
			t2.set_parallel(false)
			t2.tween_callback(_recycle_vfx.bind(s2))
		# Big final slash at the landing point
		_spawn_slash_vfx(dir, 55.0, 2.5)
		_spawn_slash_vfx(dir.rotated(0.3), 50.0, 1.8)
		# Damage all enemies in the slash corridor
		var hit_count := 0
		for enemy in slash_targets:
			if not is_instance_valid(enemy) or enemy.get("_is_dead"):
				continue
			var result = CombatManager.calculate_damage(stats.get_stats_dict(), enemy.get_stats_dict(), dmg_mult)
			enemy.take_damage(result["damage"], result["is_crit"])
			enemy.apply_knockback(dir, 140.0)
			_spawn_impact_vfx(enemy.global_position, result["is_crit"])
			hit_count += 1
		if hit_count > 0:
			_do_screen_shake(10.0)
			_do_hit_freeze(true)
		else:
			_do_screen_shake(5.0)
		AudioManager.play_sfx("charge_release")
		_spawn_effect_label("CHARGED SLASH!", Color(1.0, 0.9, 0.3))
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.08)
	_anim_return_to_idle(tween, base_pos)

func _execute_dash_strike(attack_dir: Vector2) -> void:
	# Diagonal + attack: Dash forward through enemies, 1.3x damage
	_is_attack_animating = true
	_attack_cooldown = 0.6 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.3
	var dash_distance := 60.0  # Player physically moves forward

	# Snapshot targets BEFORE the dash — after dashing, enemies end up behind us
	# and leave the AttackArea, so we must pick targets now.
	var start_pos = global_position
	var end_pos = start_pos + dir * dash_distance
	var dash_targets: Array[Node2D] = []
	# Collect all enemies near the dash path (in range or along the path)
	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.get("_is_dead"))
	for enemy in _enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		# Check if enemy is close to the dash line segment
		var dist_to_path = _point_to_segment_dist(enemy.global_position, start_pos, end_pos)
		if dist_to_path < stats.attack_range + 20.0:
			# Also check rough direction alignment — don't hit enemies far behind us
			var to_enemy = (enemy.global_position - start_pos)
			var dot = dir.dot(to_enemy.normalized())
			if dot > -0.3:  # generous: catch enemies slightly to the side/behind
				dash_targets.append(enemy)

	# Use spin slash frames
	var frames = _combo_swings[4] if _combo_swings.size() > 4 else []

	var tween = create_tween()
	# Brief coil
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.05)
	# Tint cyan for dash
	tween.tween_callback(func(): sprite.modulate = Color(0.8, 1.2, 1.4))
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Dash forward — spin + translate the CHARACTER (not just sprite)
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", TAU, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0, 0.16)
	# Actually move the player body forward
	tween.tween_property(self, "global_position", end_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Slash trail VFX along the dash path
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		_spawn_slash_vfx(dir, 45.0, 1.6)
		_spawn_slash_vfx(dir.rotated(PI * 0.4), 35.0, 1.2)
		_spawn_slash_vfx(dir.rotated(-PI * 0.4), 35.0, 1.2)
		# Hit all enemies along the dash path using pre-captured targets
		var did_hit := false
		for hit_target in dash_targets:
			if is_instance_valid(hit_target) and not hit_target.get("_is_dead"):
				var result = CombatManager.calculate_damage(stats.get_stats_dict(), hit_target.get_stats_dict(), dmg_mult)
				hit_target.take_damage(result["damage"], result["is_crit"])
				hit_target.apply_knockback(dir, 75.0)
				_spawn_impact_vfx(hit_target.global_position, result["is_crit"])
				did_hit = true
		if did_hit:
			_do_screen_shake(6.0)
			_do_hit_freeze(false)
		else:
			_do_screen_shake(2.0)
		AudioManager.play_sfx("dash_swoosh")
		_spawn_effect_label("DASH STRIKE!", Color(0.4, 0.9, 1.0))
	)
	tween.tween_property(sprite, "rotation", 0.0, 0.08)
	tween.tween_interval(0.05)
	_anim_return_to_idle(tween, base_pos)

# --- Shadow Ranger Special Attacks (ranged, lower damage than melee) ---

func _execute_piercing_shot(attack_dir: Vector2) -> void:
	# Double-tap: Piercing arrow that passes through all enemies in a line. 1.2x damage.
	_is_attack_animating = true
	_attack_cooldown = 0.6 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.2
	var pierce_range := stats.attack_range * 2.5

	# Bow draw animation
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.0, 1.1, 0.7))
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.1)
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.08)
	# Release
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 3.0, 0.04)
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		# Spawn piercing projectile (passes through enemies, doesn't stop on first hit)
		var projectile = Area2D.new()
		projectile.position = global_position
		projectile.collision_layer = 0
		projectile.collision_mask = 2

		var shape_node = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 6.0
		shape_node.shape = circle
		projectile.add_child(shape_node)

		var visual = Sprite2D.new()
		visual.texture = SpriteGenerator.get_texture("arrow_projectile")
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.modulate = Color(1.0, 0.9, 0.4)
		visual.scale = Vector2(1.5, 1.5)
		projectile.add_child(visual)

		# Trail glow
		var trail = Sprite2D.new()
		trail.texture = _tex_slash_arc
		trail.modulate = Color(1.0, 0.8, 0.3, 0.5)
		trail.scale = Vector2(1.2, 0.4)
		trail.rotation = PI
		projectile.add_child(trail)

		projectile.rotation = dir.angle()
		_get_world_node().add_child(projectile)

		var end_pos = global_position + dir * pierce_range
		var travel_time = pierce_range / 500.0
		var proj_tween = projectile.create_tween()
		proj_tween.tween_property(projectile, "position", end_pos, travel_time)
		proj_tween.tween_callback(projectile.queue_free)

		# Track already-hit enemies so each is only hit once
		var hit_enemies: Array[Node2D] = []
		projectile.body_entered.connect(func(body: Node2D):
			if body.is_in_group("enemies") and body.has_method("take_damage") and body not in hit_enemies:
				hit_enemies.append(body)
				var result = CombatManager.calculate_damage(stats.get_stats_dict(), body.get_stats_dict(), dmg_mult)
				body.take_damage(result["damage"], result["is_crit"])
				body.apply_knockback(dir, 30.0)
				_spawn_impact_vfx(body.global_position, result["is_crit"])
				_do_screen_shake(3.0)
		)
		AudioManager.play_sfx("power_strike")
		_spawn_effect_label("PIERCING SHOT!", Color(1.0, 0.85, 0.3))
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.06)
	_anim_return_to_idle(tween, base_pos)

func _execute_arrow_rain(attack_dir: Vector2) -> void:
	# Triple-tap: Rain of arrows centered on the hero. 1.0x damage, AoE.
	_is_attack_animating = true
	_attack_cooldown = 0.9 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.0
	var rain_center = global_position  # Centered on hero
	var rain_radius := 150.0  # Generous AoE radius
	var arrow_count := 12

	# Snapshot enemies in range BEFORE animation (they might move)
	var rain_targets: Array[Node2D] = []
	var rain_radius_sq = rain_radius * rain_radius
	for enemy in _nearby_enemies:
		if is_instance_valid(enemy) and not enemy.get("_is_dead") and enemy.has_method("take_damage"):
			if enemy.global_position.distance_squared_to(rain_center) <= rain_radius_sq:
				rain_targets.append(enemy)

	# Dramatic bow raise animation
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(0.8, 0.9, 1.3))
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -6), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.06)
	# Fire upward
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		AudioManager.play_sfx("whirlwind")
		_spawn_effect_label("ARROW RAIN!", Color(0.6, 0.8, 1.0))

		# Spawn arrows raining down with staggered timing (visual only)
		# Use a single tween with intervals instead of 12 separate create_timer calls
		var world = _get_world_node()
		var arrow_tex = SpriteGenerator.get_texture("arrow_projectile")
		var rain_tween = create_tween()
		for i in range(arrow_count):
			if i > 0:
				rain_tween.tween_interval(0.04)
			rain_tween.tween_callback(func():
				var angle_r = randf() * TAU
				var dist_r = randf() * rain_radius
				var offset = Vector2(cos(angle_r), sin(angle_r)) * dist_r
				var land_pos = rain_center + offset
				var start_pos_arrow = land_pos + Vector2(randf_range(-20, 20), -90)

				var arrow = _get_pooled_vfx()
				arrow.texture = arrow_tex
				arrow.global_position = start_pos_arrow
				arrow.rotation = (land_pos - start_pos_arrow).angle()
				arrow.modulate = Color(0.8, 0.9, 1.0, 0.9)
				world.add_child(arrow)

				var atween = arrow.create_tween()
				atween.tween_property(arrow, "global_position", land_pos, 0.1)
				atween.tween_callback(_spawn_impact_vfx.bind(land_pos, false))
				atween.tween_property(arrow, "modulate:a", 0.0, 0.15)
				atween.tween_callback(_recycle_vfx.bind(arrow))
			)

		# Guaranteed AoE damage to all enemies in radius after a short delay
		get_tree().create_timer(0.15).timeout.connect(func():
			var did_hit := false
			for hit_target in rain_targets:
				if is_instance_valid(hit_target) and not hit_target.get("_is_dead"):
					var result = CombatManager.calculate_damage(stats.get_stats_dict(), hit_target.get_stats_dict(), dmg_mult)
					hit_target.take_damage(result["damage"], result["is_crit"])
					var kb_dir = (hit_target.global_position - rain_center).normalized()
					hit_target.apply_knockback(kb_dir, 35.0)
					did_hit = true
			if did_hit:
				_do_screen_shake(6.0)
				_do_hit_freeze(false)
			else:
				_do_screen_shake(3.0)
		)
		_do_screen_shake(5.0)
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.5)  # Wait for arrows to land
	_anim_return_to_idle(tween, base_pos)

func _execute_sniper_shot(attack_dir: Vector2) -> void:
	# Hold 1.5s: Long-range precision shot. 1.3x damage, huge range, knockback.
	_is_attack_animating = true
	_attack_cooldown = 0.8 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.3
	var snipe_range := stats.attack_range * 4.0

	# Find the best target along the snipe line
	var start_pos_world = global_position
	var end_pos_world = start_pos_world + dir * snipe_range
	var best_target: Node2D = null
	var best_dist := INF
	for enemy in _nearby_enemies:
		if not is_instance_valid(enemy) or enemy.get("_is_dead") or not enemy.has_method("take_damage"):
			continue
		var dist_to_path = _point_to_segment_dist(enemy.global_position, start_pos_world, end_pos_world)
		if dist_to_path <= 25.0:
			var to_enemy = enemy.global_position - start_pos_world
			if dir.dot(to_enemy) > 0.0:
				var d = to_enemy.length()
				if d < best_dist:
					best_dist = d
					best_target = enemy

	# Dramatic aim animation
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.6))
	tween.tween_property(sprite, "position", base_pos - dir * 6.0, 0.12)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	# Flash on release
	tween.tween_callback(func(): sprite.modulate = Color(2.0, 1.8, 1.0))
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.03)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.03)
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		# Spawn fast sniper projectile with trail
		var projectile = Area2D.new()
		projectile.position = global_position
		projectile.collision_layer = 0
		projectile.collision_mask = 2

		var shape_node = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 5.0
		shape_node.shape = circle
		projectile.add_child(shape_node)

		var visual = Sprite2D.new()
		visual.texture = SpriteGenerator.get_texture("arrow_projectile")
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.modulate = Color(1.0, 0.9, 0.3)
		visual.scale = Vector2(2.0, 1.5)
		projectile.add_child(visual)

		projectile.rotation = dir.angle()
		_get_world_node().add_child(projectile)

		# Afterimage trail during flight
		var ghost_count := 5
		var ghost_interval = snipe_range / 700.0 / float(ghost_count)
		var ghost_tw = projectile.create_tween()
		for _k in range(ghost_count):
			ghost_tw.tween_callback(func():
				var ghost = _get_pooled_vfx()
				ghost.texture = SpriteGenerator.get_texture("arrow_projectile")
				ghost.global_position = projectile.global_position
				ghost.rotation = projectile.rotation
				ghost.scale = Vector2(1.5, 1.0)
				ghost.modulate = Color(1.0, 0.8, 0.3, 0.4)
				_get_world_node().add_child(ghost)
				var gt = ghost.create_tween()
				gt.tween_property(ghost, "modulate:a", 0.0, 0.15)
				gt.tween_callback(_recycle_vfx.bind(ghost))
			)
			ghost_tw.tween_interval(ghost_interval)

		var end_pos = global_position + dir * snipe_range
		var travel_time = snipe_range / 700.0
		var proj_tween = projectile.create_tween()
		proj_tween.tween_property(projectile, "position", end_pos, travel_time)
		proj_tween.tween_callback(projectile.queue_free)

		# Hit the pre-selected target for guaranteed damage
		if best_target and is_instance_valid(best_target):
			var hit_delay = best_dist / 700.0
			get_tree().create_timer(hit_delay).timeout.connect(func():
				if is_instance_valid(best_target) and not best_target.get("_is_dead"):
					var result = CombatManager.calculate_damage(stats.get_stats_dict(), best_target.get_stats_dict(), dmg_mult)
					best_target.take_damage(result["damage"], result["is_crit"])
					best_target.apply_knockback(dir, 120.0)
					_spawn_impact_vfx(best_target.global_position, true)
					_do_screen_shake(8.0)
					_do_hit_freeze(true)
			)
		else:
			_do_screen_shake(3.0)

		AudioManager.play_sfx("charge_release")
		_spawn_effect_label("SNIPER SHOT!", Color(1.0, 0.9, 0.3))
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.06)
	_anim_return_to_idle(tween, base_pos)

func _execute_shadow_step(attack_dir: Vector2) -> void:
	# Diagonal + attack: Quick dodge-roll backward, then fire 3 arrows in a spread. 1.1x damage.
	_is_attack_animating = true
	_attack_cooldown = 0.6 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position
	var dmg_mult := 1.1
	var dodge_distance := 50.0
	var dodge_dir = -dir  # Roll AWAY from attack direction

	# Dodge-roll animation
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(0.6, 1.0, 0.8, 0.7))
	# Roll backward
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", -TAU, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", global_position + dodge_dir * dodge_distance, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	# Quick aim after dodge
	tween.tween_property(sprite, "rotation", 0.0, 0.04)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.0, 0.8))
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.04)
	# Fire spread of 3 arrows
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		var spread_deg = deg_to_rad(25.0)
		for i in range(3):
			var angle_offset = lerp(-spread_deg / 2.0, spread_deg / 2.0, float(i) / 2.0)
			var shot_dir = dir.rotated(angle_offset)
			_spawn_projectile(shot_dir, 420.0, stats.attack_range * 2.0, dmg_mult)
		AudioManager.play_sfx("dash_swoosh")
		_spawn_effect_label("SHADOW STEP!", Color(0.4, 1.0, 0.7))
		_do_screen_shake(4.0)
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.tween_interval(0.06)
	_anim_return_to_idle(tween, base_pos)

## Distance from a point to a line segment (start -> end)
func _point_to_segment_dist(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg = seg_end - seg_start
	var seg_len_sq = seg.length_squared()
	if seg_len_sq < 0.001:
		return point.distance_to(seg_start)
	var t = clampf((point - seg_start).dot(seg) / seg_len_sq, 0.0, 1.0)
	var proj = seg_start + seg * t
	return point.distance_to(proj)

func _find_best_target(dir: Vector2) -> Node2D:
	# Find the best target in a direction from current enemies in range
	var hit_target: Node2D = null
	var mouse_target = _get_enemy_at_mouse()
	if mouse_target and mouse_target in _enemies_in_range:
		return mouse_target
	var best_score := -INF
	for enemy in _enemies_in_range:
		if not is_instance_valid(enemy) or enemy.get("_is_dead"):
			continue
		var to_enemy = (enemy.global_position - global_position)
		var dot = dir.dot(to_enemy.normalized())
		if dot > 0.2:
			var score = dot - to_enemy.length() * 0.001
			if score > best_score:
				best_score = score
				hit_target = enemy
	return hit_target

func _start_charge_vfx() -> void:
	_stop_charge_vfx()
	_charge_vfx = Sprite2D.new()
	_charge_vfx.texture = _tex_beacon_blue
	_charge_vfx.modulate = Color(1.0, 0.8, 0.2, 0.0)
	_charge_vfx.z_index = -1
	add_child(_charge_vfx)
	# Glow intensifies as you charge
	if _charge_vfx_tween and _charge_vfx_tween.is_valid():
		_charge_vfx_tween.kill()
	_charge_vfx_tween = _charge_vfx.create_tween().set_loops()
	_charge_vfx_tween.tween_property(_charge_vfx, "modulate:a", 0.7, 0.3)
	_charge_vfx_tween.tween_property(_charge_vfx, "modulate:a", 0.3, 0.3)
	# Also vibrate sprite to show charge tension
	if _charge_shake_tween and _charge_shake_tween.is_valid():
		_charge_shake_tween.kill()
	_charge_shake_tween = create_tween().set_loops()
	_charge_shake_tween.tween_property(sprite, "offset:x", sprite.offset.x + 1.5, 0.03)
	_charge_shake_tween.tween_property(sprite, "offset:x", sprite.offset.x - 1.5, 0.03)
	# Directional arrow indicator
	_charge_arrow = _create_charge_arrow()
	add_child(_charge_arrow)
	_update_charge_arrow()
	# Looping charge buildup sound
	_start_charge_sfx()

func _stop_charge_vfx() -> void:
	_stop_charge_sfx()
	if _charge_vfx_tween and _charge_vfx_tween.is_valid():
		_charge_vfx_tween.kill()
		_charge_vfx_tween = null
	if _charge_shake_tween and _charge_shake_tween.is_valid():
		_charge_shake_tween.kill()
		_charge_shake_tween = null
		sprite.offset.x = 0.0
	if _charge_vfx and is_instance_valid(_charge_vfx):
		_charge_vfx.queue_free()
		_charge_vfx = null
	if _charge_arrow and is_instance_valid(_charge_arrow):
		_charge_arrow.queue_free()
		_charge_arrow = null

func _start_charge_sfx() -> void:
	_stop_charge_sfx()
	_charge_sfx_player = AudioStreamPlayer.new()
	_charge_sfx_player.stream = AudioManager.get_sfx("charge_loop")
	_charge_sfx_player.volume_db = -4.0
	add_child(_charge_sfx_player)
	_charge_sfx_player.play()

func _stop_charge_sfx() -> void:
	if _charge_sfx_player and is_instance_valid(_charge_sfx_player):
		_charge_sfx_player.stop()
		_charge_sfx_player.queue_free()
		_charge_sfx_player = null

func _create_charge_arrow() -> Sprite2D:
	# Procedurally generate a small arrow sprite (16x8) pointing right
	var img = Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var arrow_col = Color(1.0, 0.9, 0.3, 0.9)
	var outline_col = Color(0.3, 0.2, 0.0, 0.8)
	# Shaft
	_draw_rect_on_img(img, 0, 2, 10, 4, outline_col)
	_draw_rect_on_img(img, 1, 3, 8, 2, arrow_col)
	# Arrowhead
	_draw_rect_on_img(img, 10, 0, 2, 8, outline_col)
	_draw_rect_on_img(img, 12, 1, 2, 6, outline_col)
	_draw_rect_on_img(img, 14, 2, 2, 4, outline_col)
	_draw_rect_on_img(img, 10, 1, 2, 6, arrow_col)
	_draw_rect_on_img(img, 12, 2, 2, 4, arrow_col)
	_draw_rect_on_img(img, 14, 3, 1, 2, arrow_col)
	var s = Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.z_index = 2
	return s

func _draw_rect_on_img(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(y, mini(y + h, img.get_height())):
		for px in range(x, mini(x + w, img.get_width())):
			img.set_pixel(px, py, col)

func _update_charge_arrow() -> void:
	if not _charge_arrow or not is_instance_valid(_charge_arrow):
		return
	var dir = _facing.normalized() if _facing.length() > 0.1 else Vector2.RIGHT
	_charge_arrow.position = dir * 28.0
	_charge_arrow.rotation = dir.angle()

# --- Mobile Attack Button ---

func _create_mobile_attack_button() -> void:
	_mobile_atk_canvas = CanvasLayer.new()
	_mobile_atk_canvas.layer = 11  # Above HUD (which is layer 10)
	add_child(_mobile_atk_canvas)

	_mobile_atk_btn = Button.new()
	_mobile_atk_btn.text = "ATK"
	_mobile_atk_btn.modulate = Color(1.0, 1.0, 1.0, 0.8)
	_mobile_atk_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_mobile_atk_btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.7))

	# NOTE: button_down/button_up signals are NOT connected here.  Touch
	# detection is handled manually in _input() via InputEventScreenTouch so
	# that multitouch works (Godot's Button only responds to the first finger).
	_mobile_atk_canvas.add_child(_mobile_atk_btn)

	# Defer positioning to ensure viewport size is finalized
	_reposition_atk_button()
	get_viewport().size_changed.connect(_reposition_atk_button)

func _reposition_atk_button() -> void:
	if not _mobile_atk_btn or not is_instance_valid(_mobile_atk_btn):
		return
	var vp_size = get_viewport().get_visible_rect().size
	var is_landscape = vp_size.x > vp_size.y
	var btn_size = 144 if is_landscape else 216

	_mobile_atk_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_mobile_atk_btn.size = Vector2(btn_size, btn_size)
	# Position: lower-right, above the HUD bottom panel
	var margin_right = 30 if is_landscape else 40
	var margin_bottom = 160 if is_landscape else 170
	_mobile_atk_btn.position = Vector2(vp_size.x - btn_size - margin_right, vp_size.y - btn_size - margin_bottom)

	# Style: dark background with gold border for SC:BW feel
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.08, 0.85)
	style_normal.border_color = Color(0.7, 0.55, 0.2, 0.9)
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(btn_size / 2)  # Circular
	style_normal.set_content_margin_all(8)
	_mobile_atk_btn.add_theme_stylebox_override("normal", style_normal)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.4, 0.3, 0.1, 0.95)
	style_pressed.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_mobile_atk_btn.add_theme_stylebox_override("pressed", style_pressed)

	var style_hover = style_normal.duplicate()
	_mobile_atk_btn.add_theme_stylebox_override("hover", style_hover)

	_mobile_atk_btn.add_theme_font_size_override("font_size", 43 if is_landscape else 62)
	_mobile_atk_btn.pivot_offset = Vector2(btn_size / 2.0, btn_size / 2.0)

func set_atk_button_visible(vis: bool) -> void:
	if _mobile_atk_btn and is_instance_valid(_mobile_atk_btn):
		_mobile_atk_btn.visible = vis
	if not vis:
		# Also reset joystick when hiding controls (e.g. menus)
		_joystick_input = Vector2.ZERO
		_joystick_active = false
		_joystick_touch_index = -1
		_hide_joystick()

# --- Mobile Virtual Joystick ---

func _create_mobile_joystick() -> void:
	_joystick_canvas = CanvasLayer.new()
	_joystick_canvas.layer = 11
	add_child(_joystick_canvas)

	# Generate base circle texture (dark fill + gold ring)
	var base_tex = _gen_circle_texture(128, Color(0.15, 0.12, 0.08, 0.45), Color(0.7, 0.55, 0.2, 0.5), 4)
	_joystick_base = Sprite2D.new()
	_joystick_base.texture = base_tex
	_joystick_base.visible = false
	_joystick_canvas.add_child(_joystick_base)

	# Generate knob circle texture (gold fill + lighter ring)
	var knob_tex = _gen_circle_texture(64, Color(0.7, 0.55, 0.2, 0.7), Color(0.9, 0.75, 0.3, 0.85), 3)
	_joystick_knob = Sprite2D.new()
	_joystick_knob.texture = knob_tex
	_joystick_knob.visible = false
	_joystick_canvas.add_child(_joystick_knob)

func _gen_circle_texture(diameter: int, fill_color: Color, ring_color: Color, ring_width: int) -> ImageTexture:
	var img = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(diameter / 2.0, diameter / 2.0)
	var radius = diameter / 2.0
	for y in range(diameter):
		for x in range(diameter):
			var dist = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius:
				if dist >= radius - float(ring_width):
					img.set_pixel(x, y, ring_color)
				else:
					img.set_pixel(x, y, fill_color)
	return ImageTexture.create_from_image(img)

func _get_joystick_radius() -> float:
	var vp = get_viewport().get_visible_rect().size
	return JOYSTICK_RADIUS_PORTRAIT if vp.y > vp.x else JOYSTICK_RADIUS_LANDSCAPE

func _show_joystick(screen_pos: Vector2) -> void:
	if not _joystick_base or not _joystick_knob:
		return
	var radius = _get_joystick_radius()
	var base_scale = (radius * 2.0) / 128.0  # base texture is 128px
	_joystick_base.scale = Vector2(base_scale, base_scale)
	_joystick_base.position = screen_pos
	_joystick_base.visible = true
	var knob_scale = (radius * JOYSTICK_KNOB_FRACTION * 2.0) / 64.0  # knob texture is 64px
	_joystick_knob.scale = Vector2(knob_scale, knob_scale)
	_joystick_knob.position = screen_pos
	_joystick_knob.visible = true

func _hide_joystick() -> void:
	if _joystick_base:
		_joystick_base.visible = false
	if _joystick_knob:
		_joystick_knob.visible = false

func _update_joystick_knob(clamped_offset: Vector2) -> void:
	if _joystick_knob:
		_joystick_knob.position = _joystick_center + clamped_offset

func _on_mobile_attack_pressed() -> void:
	_flash_atk_button()
	# Count as a tap (same as spacebar press) for special attack detection
	if not _is_paralyzed:
		_tap_count += 1
		_tap_resolve_timer = TAP_RESOLVE_TIME
		_tap_resolved = false
	_mobile_attack_held = true

func _on_mobile_attack_released() -> void:
	_mobile_attack_held = false

var _atk_flash_tween: Tween = null

func _flash_atk_button() -> void:
	if not _mobile_atk_btn or not is_instance_valid(_mobile_atk_btn):
		return
	# Kill any in-progress flash so rapid taps restart cleanly
	if _atk_flash_tween and _atk_flash_tween.is_valid():
		_atk_flash_tween.kill()
	# Scale punch + bright color flash
	_mobile_atk_btn.scale = Vector2(1.18, 1.18)
	_mobile_atk_btn.modulate = Color(2.0, 1.6, 0.6, 1.0)
	_atk_flash_tween = create_tween()
	_atk_flash_tween.set_parallel(true)
	_atk_flash_tween.tween_property(_mobile_atk_btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	_atk_flash_tween.tween_property(_mobile_atk_btn, "modulate", Color(1.0, 1.0, 1.0, 0.8), 0.2).set_ease(Tween.EASE_OUT)

func _get_non_atk_touches() -> Dictionary:
	# Return all active screen touches EXCEPT those on the ATK button or joystick.
	# Uses _screen_touches (tracked in _input) so UI-consumed touches are included.
	if not _mobile_atk_btn or not is_instance_valid(_mobile_atk_btn):
		return _screen_touches
	var atk_rect = _mobile_atk_btn.get_global_rect()
	var result: Dictionary = {}
	for idx in _screen_touches:
		if idx == _joystick_touch_index:
			continue
		if not atk_rect.has_point(_screen_touches[idx]):
			result[idx] = _screen_touches[idx]
	return result

func _get_mobile_touch_dir() -> Vector2:
	# Derive an aim direction from active screen touches (fingers NOT on ATK button).
	# Single finger: direction from player screen-pos to that finger.
	# Two+ fingers: direction from player screen-pos to the midpoint of all fingers.
	var touches = _get_non_atk_touches()
	if touches.is_empty():
		return Vector2.ZERO
	var player_screen_pos = get_viewport().get_canvas_transform() * global_position
	var touch_center: Vector2
	if touches.size() == 1:
		touch_center = touches.values()[0]
	else:
		var sum := Vector2.ZERO
		for pos in touches.values():
			sum += pos
		touch_center = sum / touches.size()
	var dir = (touch_center - player_screen_pos)
	if dir.length() < 10.0:
		return Vector2.ZERO
	return dir.normalized()

func _get_world_mouse_pos() -> Vector2:
	# Use the viewport's canvas transform so the result matches what is
	# visually on screen, even when camera position_smoothing is active.
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _get_enemy_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	# First try exact point hit for precision
	_enemy_query_params.position = mouse_pos
	var point_results = space.intersect_point(_enemy_query_params, 1)
	if point_results.size() > 0:
		var col = point_results[0]["collider"]
		if col.is_in_group("enemies") and not col.get("_is_dead"):
			return col
	# Fall back to generous shape query — find nearest enemy within click radius
	_enemy_shape_query.transform = Transform2D(0, mouse_pos)
	var results = space.intersect_shape(_enemy_shape_query, 8)
	var best: Node2D = null
	var best_dist_sq: float = INF
	for r in results:
		var col = r["collider"]
		if col.is_in_group("enemies") and not col.get("_is_dead"):
			var d = mouse_pos.distance_squared_to(col.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				best = col
	return best

func _get_clickable_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	_clickable_query_params.position = mouse_pos
	var results = space.intersect_point(_clickable_query_params, 1)
	if results.size() > 0:
		return results[0]["collider"]
	return null

func _get_tree_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	# First try exact point hit
	_clickable_query_params.position = mouse_pos
	var point_results = space.intersect_point(_clickable_query_params, 4)
	for result in point_results:
		var col = result["collider"]
		if col.is_in_group("harvestable_trees") and not col.get("_is_chopped"):
			return col
	# Fall back to generous shape query — find nearest tree within click radius
	_tree_shape_query.transform = Transform2D(0, mouse_pos)
	var results = space.intersect_shape(_tree_shape_query, 8)
	var best: Node2D = null
	var best_dist_sq: float = INF
	for r in results:
		var col = r["collider"]
		if col.is_in_group("harvestable_trees") and not col.get("_is_chopped"):
			var d = mouse_pos.distance_squared_to(col.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				best = col
	return best

func _get_watchtower_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var best: Node2D = null
	var best_dist_sq: float = 2500.0  # 50px radius
	for tower in get_tree().get_nodes_in_group("watchtower"):
		if not is_instance_valid(tower):
			continue
		var d = mouse_pos.distance_squared_to(tower.global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			best = tower
	return best

func _show_watchtower_stats(tower: Node2D) -> void:
	var panels = get_tree().get_nodes_in_group("watchtower_stats_panel")
	if panels.size() > 0:
		panels[0].show_tower(tower)
	else:
		# Create panel on first use
		var panel_scene = load("res://scenes/ui/watchtower_stats_panel.tscn")
		if panel_scene:
			var panel = panel_scene.instantiate()
			panel.add_to_group("watchtower_stats_panel")
			get_tree().current_scene.add_child(panel)
			panel.show_tower(tower)

func _set_facing(dir: Vector2) -> void:
	_facing = dir
	# 8-way direction detection using angle-based octants
	var new_cat: String
	var new_flip: bool = false
	var angle = dir.angle()  # radians: 0=right, PI/2=down, -PI/2=up
	# Normalize to [0, TAU)
	if angle < 0:
		angle += TAU
	# Divide circle into 8 octants (each 45°=PI/4)
	# Octant boundaries offset by 22.5° so cardinal directions are centered
	var octant = int(floor((angle + PI / 8.0) / (PI / 4.0))) % 8
	match octant:
		0:  # Right
			new_cat = "side"
			new_flip = false
		1:  # Down-right
			new_cat = "down_side"
			new_flip = false
		2:  # Down
			new_cat = "down"
		3:  # Down-left
			new_cat = "down_side"
			new_flip = true
		4:  # Left
			new_cat = "side"
			new_flip = true
		5:  # Up-left
			new_cat = "up_side"
			new_flip = true
		6:  # Up
			new_cat = "up"
		7:  # Up-right
			new_cat = "up_side"
			new_flip = false
		_:
			new_cat = "down"
	# Only update sprite when the category or flip actually changes
	if new_cat == _facing_cat and new_flip == sprite.flip_h:
		return
	_facing_cat = new_cat
	sprite.flip_h = new_flip
	_idle_texture = _dir_textures.get(new_cat, _dir_textures.get("down"))
	# Reset walk animation so it picks up the new direction's frames immediately
	_walk_anim_frame = -1
	if not _is_attack_animating and _idle_texture:
		sprite.texture = _idle_texture

func _get_aim_direction() -> Vector2:
	# Prefer held arrow/WASD/joystick, then recent click/tap aim, then mobile charge drag, then mobile touch, then last facing
	var input_raw = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if _joystick_input.length() > 0.1:
		input_raw += _joystick_input
	if input_raw.length() > 0.25:
		return input_raw.normalized()
	if _tap_aim_dir.length() > 0.1 and _tap_aim_timer > 0.0:
		return _tap_aim_dir
	if _is_mobile:
		# Charge drag-to-aim: if player dragged on ATK button while charging, use that direction
		if _mobile_charge_aim_dir.length() > 0.1:
			return _mobile_charge_aim_dir
		var touch_dir = _get_mobile_touch_dir()
		if touch_dir.length() > 0.1:
			return touch_dir
	return _facing


func _spawn_projectile(direction: Vector2, speed: float, max_range: float, dmg_mult: float) -> void:
	var projectile = Area2D.new()
	projectile.position = global_position
	projectile.collision_layer = 0
	projectile.collision_mask = 2

	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 5.0
	shape_node.shape = circle
	projectile.add_child(shape_node)

	var visual = Sprite2D.new()
	visual.texture = SpriteGenerator.get_texture("arrow_projectile")
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.add_child(visual)

	projectile.rotation = direction.angle()
	_get_world_node().add_child(projectile)

	# Tween owned by projectile so it auto-dies if projectile is freed on hit
	var tween = projectile.create_tween()
	var end_pos = global_position + direction * max_range
	var travel_time = max_range / speed
	tween.tween_property(projectile, "position", end_pos, travel_time)
	tween.tween_callback(projectile.queue_free)

	projectile.body_entered.connect(func(body: Node2D):
		if not is_instance_valid(projectile):
			return
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var result = CombatManager.calculate_damage(stats.get_stats_dict(), body.get_stats_dict(), dmg_mult)
			body.take_damage(result["damage"], result["is_crit"])
			_spawn_impact_vfx(body.global_position)
			projectile.queue_free()
	)

func _perform_attack(target: Node2D, attack_dir: Vector2 = Vector2.RIGHT) -> void:
	_is_attack_animating = true
	attacked.emit(target)

	AudioManager.play_sfx("sword_swing")
	var hero_data = HeroData.get_hero(hero_class)
	if hero_data.get("primary_stat") == "agility":
		var result = CombatManager.calculate_damage(stats.get_stats_dict(), target.get_stats_dict())
		_do_ranged_attack(target, result)
	else:
		var result = CombatManager.calculate_damage(stats.get_stats_dict(), target.get_stats_dict())
		_do_melee_attack(target, result, attack_dir)

func _perform_swing_no_target(dir: Vector2) -> void:
	# Full swing animation with VFX but no target — empty swing in attack direction
	_is_attack_animating = true
	var cur_cat = _get_dir_category(dir)
	var swing_idx = _pick_combo_swing(cur_cat)
	var frames = _combo_swings[swing_idx] if swing_idx < _combo_swings.size() else []
	_last_dir_category = cur_cat
	_combo_index += 1
	_combo_timer = 0.0
	var base_pos = sprite.position
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# Simple whiff: lunge forward, play slash VFX, return
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.07)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.06)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.04)
	tween.tween_callback(func(): _spawn_slash_vfx(dir, 30.0, 1.0))
	tween.tween_interval(0.05)
	_anim_return_to_idle(tween, base_pos)

func _get_dir_category(dir: Vector2) -> String:
	if abs(dir.x) > 0.4 and abs(dir.y) > 0.4:
		return "diagonal"
	if abs(dir.y) >= abs(dir.x):
		return "up" if dir.y < 0.0 else "down"
	return "horizontal"

func _pick_combo_swing(cur_cat: String) -> int:
	# Directional combo chart — prev direction category → current → swing type
	match [_last_dir_category, cur_cat]:
		# Diagonal input always triggers spin slash
		[_, "diagonal"]:
			return 4
		# First attack in combo: pick based on direction
		["", "up"]:
			return 3   # Rising thrust
		["", "down"]:
			return 2   # Overhead chop
		# horizontal → vertical transitions
		["horizontal", "up"]:
			return 3   # Rising thrust when swinging upward after horizontal
		["horizontal", "down"]:
			return 2   # Overhead slam downward after horizontal
		# Opposite verticals — the signature big combos
		["up", "down"]:
			return 2   # Slam down after jumping up
		["down", "up"]:
			return 3   # Rising uppercut after crouching down
		# Vertical → horizontal: spin out of the vertical
		["up", "horizontal"], ["down", "horizontal"]:
			return 4   # Spin slash when sweeping horizontal after vertical
		# Same or fallback: alternate A/B horizontal swings
		_:
			return _combo_index % 2

func _do_melee_attack(target: Node2D, result: Dictionary, attack_dir: Vector2 = Vector2.RIGHT) -> void:
	if not is_instance_valid(target):
		_is_attack_animating = false
		return

	var dir = attack_dir  # Swing in the direction the player is pressing
	var perp = Vector2(-dir.y, dir.x)
	var base_pos = sprite.position

	# Direction-based combo selection
	var swing_idx: int
	if _is_auto_attacking:
		# Auto-attack: alternate between basic left/right slashes only (0 and 1)
		swing_idx = _combo_index % 2
		_combo_index += 1
		_combo_timer = 0.0
		_last_dir_category = ""
	else:
		var cur_cat = _get_dir_category(dir)
		swing_idx = _pick_combo_swing(cur_cat)
		_last_dir_category = cur_cat
		_combo_index += 1
		_combo_timer = 0.0

	var has_frames = swing_idx < _combo_swings.size()
	var frames = _combo_swings[swing_idx] if has_frames else []

	var tween = create_tween()
	match swing_idx:
		0:  # A: left-to-right slash
			_anim_swing_horizontal(tween, frames, base_pos, dir, perp, target, result, 1.0)
		1:  # B: right-to-left backhand
			_anim_swing_horizontal(tween, frames, base_pos, dir, perp, target, result, -1.0)
		2:  # C: overhead chop
			_anim_overhead_chop(tween, frames, base_pos, dir, target, result)
		3:  # D: upward thrust
			_anim_upward_thrust(tween, frames, base_pos, dir, target, result)
		4:  # E: spin slash
			_anim_spin_slash(tween, frames, base_pos, dir, target, result)

func _anim_swing_horizontal(tween: Tween, frames: Array, base_pos: Vector2,
		dir: Vector2, perp: Vector2, target: Node2D, result: Dictionary, side: float) -> void:
	# side=1.0 for left-to-right, -1.0 for right-to-left backhand
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Wind-up: shift to the opposite side
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + perp * side * -4.0, 0.07)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Slash across: sweep through with lunge
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + perp * side * 4.0, 0.06)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Follow-through
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + perp * side * 6.0, 0.04)
	tween.tween_callback(func():
		if is_instance_valid(target):
			target.take_damage(result["damage"], result["is_crit"])
			target.apply_knockback(dir, 40.0)
			_spawn_slash_vfx(dir.rotated(side * 0.3), 35.0, 1.0)
			_spawn_impact_vfx(target.global_position, result["is_crit"])
			if result["is_crit"]:
				_do_screen_shake(4.0)
				_do_hit_freeze(true)
	)
	# Return to idle
	tween.tween_interval(0.05)
	_anim_return_to_idle(tween, base_pos)

func _anim_overhead_chop(tween: Tween, frames: Array, base_pos: Vector2,
		dir: Vector2, target: Node2D, result: Dictionary) -> void:
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Big wind-up: pull back and lift
	tween.tween_property(sprite, "position", base_pos - dir * 5.0 + Vector2(0, -4), 0.10)
	# Squash anticipation
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.04)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Slam down
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, 2), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.03)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Impact — lunge and stretch
	tween.tween_property(sprite, "position", base_pos + dir * 14.0, 0.04)
	tween.tween_callback(func():
		if is_instance_valid(target):
			target.take_damage(result["damage"], result["is_crit"])
			target.apply_knockback(dir, 55.0)
			_spawn_slash_vfx(dir, 40.0, 1.4)
			_spawn_impact_vfx(target.global_position, result["is_crit"])
			if result["is_crit"]:
				_do_screen_shake(5.0)
				_do_hit_freeze(true)
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.tween_interval(0.04)
	_anim_return_to_idle(tween, base_pos)

func _anim_upward_thrust(tween: Tween, frames: Array, base_pos: Vector2,
		dir: Vector2, target: Node2D, result: Dictionary) -> void:
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Crouch down
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 3), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.85), 0.04)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Thrust upward and forward
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, -6), 0.06)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.04)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Full extension
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, -8), 0.03)
	tween.tween_callback(func():
		if is_instance_valid(target):
			target.take_damage(result["damage"], result["is_crit"])
			target.apply_knockback(dir, 30.0)
			_spawn_slash_vfx(dir.rotated(-0.4), 30.0, 1.0)
			_spawn_impact_vfx(target.global_position, result["is_crit"])
			if result["is_crit"]:
				_do_screen_shake(5.0)
				_do_hit_freeze(true)
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.tween_interval(0.04)
	_anim_return_to_idle(tween, base_pos)

func _anim_spin_slash(tween: Tween, frames: Array, base_pos: Vector2,
		dir: Vector2, target: Node2D, result: Dictionary) -> void:
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Coil
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.06)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Spin (360 rotation + lunge)
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", TAU, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.18)
	tween.set_parallel(false)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	tween.tween_callback(func():
		if is_instance_valid(target):
			target.take_damage(result["damage"], result["is_crit"])
			target.apply_knockback(dir, 60.0)
			# Wide slash VFX — hits in a circle
			_spawn_slash_vfx(dir, 40.0, 1.6)
			_spawn_slash_vfx(dir.rotated(PI * 0.5), 35.0, 1.2)
			_spawn_slash_vfx(dir.rotated(-PI * 0.5), 35.0, 1.2)
			_spawn_impact_vfx(target.global_position, result["is_crit"])
			if result["is_crit"]:
				_do_screen_shake(6.0)
				_do_hit_freeze(true)
			else:
				_do_screen_shake(2.0)
	)
	# Unwind rotation
	tween.tween_property(sprite, "rotation", 0.0, 0.08)
	tween.tween_interval(0.04)
	_anim_return_to_idle(tween, base_pos)

func _anim_return_to_idle(tween: Tween, base_pos: Vector2) -> void:
	tween.tween_callback(func():
		if _idle_texture:
			sprite.texture = _idle_texture
	)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.tween_callback(func(): _is_attack_animating = false)

func _do_ranged_attack(target: Node2D, result: Dictionary) -> void:
	if not is_instance_valid(target):
		_is_attack_animating = false
		return

	# Bow draw animation: squish sprite briefly
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)
	tween.tween_callback(func():
		if not is_instance_valid(target):
			_is_attack_animating = false
			return
		# Spawn arrow projectile
		var arrow = Sprite2D.new()
		arrow.texture = SpriteGenerator.get_texture("arrow_projectile")
		arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow.global_position = global_position + Vector2(0, -10)
		arrow.rotation = (target.global_position - global_position).angle()
		_get_world_node().add_child(arrow)

		var arrow_dir = (target.global_position - global_position).normalized()
		var arrow_tween = arrow.create_tween()
		arrow_tween.tween_property(arrow, "global_position", target.global_position, 0.12)
		arrow_tween.tween_callback(func():
			if is_instance_valid(target):
				target.take_damage(result["damage"], result["is_crit"])
				target.apply_knockback(arrow_dir, 20.0)
				_spawn_impact_vfx(target.global_position, result["is_crit"])
				if result["is_crit"]:
					_do_screen_shake(3.0)
					_do_hit_freeze(true)
			arrow.queue_free()
		)
	)
	tween.tween_interval(0.2)
	tween.tween_callback(func(): _is_attack_animating = false)

func _spawn_slash_vfx(direction: Vector2, radius: float, scale_mult: float) -> void:
	var slash = _get_pooled_vfx()
	slash.texture = _tex_slash_arc
	slash.global_position = global_position + direction * radius * 0.5
	slash.rotation = direction.angle()
	slash.scale = Vector2(scale_mult, scale_mult)
	slash.modulate = Color(1.0, 0.9, 0.6, 0.9)
	_get_world_node().add_child(slash)

	var tween = slash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "scale", slash.scale * 1.4, 0.15)
	tween.tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(_recycle_vfx.bind(slash))

func _spawn_impact_vfx(pos: Vector2, is_crit: bool = false) -> void:
	# Reduced spark count: 1 normal, 2 crit (was 2/4)
	var spark_count = 2 if is_crit else 1
	var spread = 28.0 if is_crit else 18.0
	var world = _get_world_node()
	for i in range(spark_count):
		var spark = _get_pooled_vfx()
		spark.texture = _tex_crystal_white
		spark.global_position = pos
		var sc = randf_range(0.3, 0.7) if not is_crit else randf_range(0.5, 1.0)
		spark.scale = Vector2(sc, sc)
		var r = randf_range(0.9, 1.0)
		var g = randf_range(0.2, 0.5) if not is_crit else randf_range(0.6, 0.9)
		spark.modulate = Color(r, g, 0.1, 1.0)
		spark.z_index = 12
		world.add_child(spark)
		var dir = Vector2.from_angle(randf() * TAU) * randf_range(spread * 0.4, spread)
		var dur = randf_range(0.12, 0.22)
		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + dir, dur)
		tween.tween_property(spark, "modulate:a", 0.0, dur)
		tween.tween_property(spark, "scale", Vector2.ZERO, dur)
		tween.set_parallel(false)
		tween.tween_callback(_recycle_vfx.bind(spark))

	# Flash ring at impact centre
	var flash = _get_pooled_vfx()
	flash.texture = _tex_selection_red
	flash.modulate = Color(1.0, 0.9, 0.5, 0.9) if not is_crit else Color(1.0, 0.3, 0.1, 1.0)
	flash.scale = Vector2(0.2, 0.2)
	flash.z_index = 13
	flash.global_position = pos
	world.add_child(flash)
	var ft = flash.create_tween()
	ft.set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(1.2, 1.2) if not is_crit else Vector2(2.0, 2.0), 0.1)
	ft.tween_property(flash, "modulate:a", 0.0, 0.12)
	ft.set_parallel(false)
	ft.tween_callback(_recycle_vfx.bind(flash))

func _do_hit_freeze(is_crit: bool) -> void:
	if _hit_freeze_active:
		return  # Don't stack freezes
	_hit_freeze_active = true
	# Sprite-only hit flash — no Engine.time_scale to avoid whole-game stutter
	sprite.modulate = Color(2.5, 2.5, 2.5) if is_crit else Color(1.8, 1.8, 1.8)
	var freeze_dur = 0.04 if not is_crit else 0.06
	get_tree().create_timer(freeze_dur, true, false, true).timeout.connect(func():
		sprite.modulate = Color.WHITE
		_hit_freeze_active = false
	)

func _do_screen_shake(intensity: float) -> void:
	# Procedural shake — driven by _physics_process, no tween allocation
	_shake_intensity = intensity
	_shake_time_left = SHAKE_DURATION

func _spawn_auto_attack_projectile(target: Node2D) -> void:
	pass  # Handled by _do_ranged_attack now

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		_enemies_in_range.append(body)
	elif body.is_in_group("harvestable_trees"):
		_trees_in_range.append(body)

func _on_attack_area_body_exited(body: Node2D) -> void:
	_enemies_in_range.erase(body)
	_trees_in_range.erase(body)

# Walk-over pickup for items/gold dropped on the ground
func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("ground_items"):
		var item = area.get_meta("item_data", {})
		if item.is_empty():
			return
		if item.get("id") == "_gold":
			GameManager.add_gold(item.get("gold_amount", 0))
			GameManager.game_message.emit("+ %s" % item.get("name", "Gold"), Color(0.3, 0.6, 1.0))
			AudioManager.play_sfx("gold_pickup", -3.0)
			_free_drop(area)
			return
		if item.get("id") == "_wood":
			GameManager.add_wood(item.get("wood_amount", 0))
			GameManager.game_message.emit("+ %s" % item.get("name", "Wood"), Color(0.65, 0.45, 0.2))
			AudioManager.play_sfx("gold_pickup", -3.0)
			_free_drop(area)
			return
		if inventory.add_item(item):
			GameManager.game_message.emit("+ %s" % item.get("name", "Item"), Color(0.2, 1.0, 0.2))
			AudioManager.play_sfx("item_pickup")
			_free_drop(area)

const _EnemyScript = preload("res://scenes/enemies/enemy.gd")

func _free_drop(area: Area2D) -> void:
	# Recycle pooled drops (have "Visual" child), queue_free others
	if area.has_node("Visual"):
		_EnemyScript.recycle_drop(area)
	else:
		area.queue_free()

func _find_best_tree(dir: Vector2) -> Node2D:
	_trees_in_range = _trees_in_range.filter(func(t): return is_instance_valid(t) and not t.get("_is_chopped"))
	var best_tree: Node2D = null
	var best_score := -INF
	for tree in _trees_in_range:
		var to_tree = (tree.global_position - global_position)
		var dot = dir.dot(to_tree.normalized())
		if dot > 0.0:  # Tree is roughly in front of us
			var score = dot - to_tree.length() * 0.001
			if score > best_score:
				best_score = score
				best_tree = tree
	return best_tree

func _perform_tree_chop(tree: Node2D, attack_dir: Vector2) -> void:
	_is_chopping_tree = true
	_is_attack_animating = true
	_attack_cooldown = 0.5 / stats.attack_speed
	var dir = attack_dir
	var base_pos = sprite.position

	# Use pickaxe frames for tree chopping, fall back to overhead chop if unavailable
	var frames = _pickaxe_frames if _pickaxe_frames.size() == 3 else (_combo_swings[2] if _combo_swings.size() > 2 else [])

	var tween = create_tween()
	# Wind-up
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -3), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Chop forward
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.03)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Impact
	tween.tween_callback(func():
		if is_instance_valid(tree) and tree.has_method("take_damage"):
			tree.take_damage(1)
			_spawn_wood_chips(tree.global_position, dir)
			_do_screen_shake(1.5)
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.tween_interval(0.04)
	_anim_return_to_idle(tween, base_pos)

func _spawn_wood_chips(pos: Vector2, dir: Vector2) -> void:
	var world = _get_world_node()
	for i in range(2):
		var chip = _get_pooled_vfx()
		chip.texture = _tex_crystal_white
		chip.global_position = pos
		chip.scale = Vector2(0.3, 0.3)
		chip.modulate = Color(0.55, 0.38, 0.18)
		chip.z_index = 12
		world.add_child(chip)
		var chip_dir = dir.rotated(randf_range(-0.8, 0.8)) * randf_range(12, 22)
		var dur = randf_range(0.15, 0.25)
		var t = chip.create_tween()
		t.set_parallel(true)
		t.tween_property(chip, "global_position", pos + chip_dir, dur)
		t.tween_property(chip, "modulate:a", 0.0, dur)
		t.tween_property(chip, "scale", Vector2.ZERO, dur)
		t.set_parallel(false)
		t.tween_callback(_recycle_vfx.bind(chip))


func _spawn_move_indicator(pos: Vector2) -> void:
	var indicator = _get_pooled_vfx()
	indicator.texture = SpriteGenerator.get_texture("beacon_green")
	indicator.scale = Vector2(0.3, 0.3)
	indicator.global_position = pos
	indicator.modulate = Color(1, 1, 1, 0.7)
	_get_world_node().add_child(indicator)
	var tween = indicator.create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_recycle_vfx.bind(indicator))

func _toggle_hero_stats_panel() -> void:
	_set_longpress_outline(false)
	var panels = get_tree().get_nodes_in_group("hero_stats_panel")
	if panels.size() > 0:
		panels[0].toggle()

func _on_equipment_visual_update() -> void:
	# Flash hero sprite with highest equipped rarity color
	var best_rarity: int = -1
	for slot_name in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		var item = inventory.equipment.get(slot_name, {})
		if not item.is_empty():
			var r = item.get("rarity", 0)
			if r > best_rarity:
				best_rarity = r
	if best_rarity < 0:
		return
	var flash_color = ItemData.RARITY_COLORS.get(best_rarity, Color.WHITE)
	# Brief bright flash then return to normal
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", flash_color.lightened(0.5), 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _set_longpress_outline(on: bool) -> void:
	var mat = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", on)

func _get_player_screen_pos() -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * global_position

func _get_pooled_vfx() -> Sprite2D:
	if _vfx_pool.size() > 0:
		var s = _vfx_pool.pop_back()
		s.rotation = 0.0
		s.z_index = 0
		return s
	var s = Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

func _recycle_vfx(s: Sprite2D) -> void:
	if is_instance_valid(s):
		s.get_parent().remove_child(s)
		if _vfx_pool.size() < VFX_POOL_MAX:
			_vfx_pool.append(s)
		else:
			s.queue_free()

func _get_world_node() -> Node:
	if _world_node and is_instance_valid(_world_node):
		return _world_node
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		_world_node = world[0]
	else:
		_world_node = get_tree().current_scene
	return _world_node

func get_stats_dict() -> Dictionary:
	return stats.get_stats_dict()

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return  # Can't take damage while dead
	if is_on_heal_beacon:
		return  # Immune while standing on heal beacon
	stats.take_damage(amount)
	_spawn_damage_number(amount, is_crit)
	_do_hit_flash()
	AudioManager.play_sfx("player_hurt", -4.0)

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	var label: Label
	if _player_dmg_pool.size() > 0:
		label = _player_dmg_pool.pop_back()
	else:
		label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10), -35)
	label.label_settings = _player_dmg_crit if is_crit else _player_dmg_normal
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_recycle_player_dmg_label.bind(label))

func _recycle_player_dmg_label(label: Label) -> void:
	if is_instance_valid(label):
		label.get_parent().remove_child(label)
		if _player_dmg_pool.size() < PLAYER_DMG_POOL_MAX:
			_player_dmg_pool.append(label)
		else:
			label.queue_free()

func _do_hit_flash() -> void:
	# Impact squash + red flash + recoil wobble
	var base_pos = sprite.position
	var tween = create_tween()
	# Bright red flash with squeeze
	tween.tween_property(sprite, "modulate", Color(1.6, 0.3, 0.3), 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.03)
	# Stretch rebound
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.6, 0.6), 0.05)
	# Wobble settle
	tween.tween_property(sprite, "scale", Vector2(1.06, 0.94), 0.04)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos, 0.06)

## Sprite upgrade at level milestones (5, 10, 15, ... 50)
func _on_level_up_sprite_upgrade(new_level: int) -> void:
	_sync_to_death_counters()
	AudioManager.play_sfx("level_up")
	# Check if we hit a sprite upgrade tier
	var tier = 0
	for threshold in SPRITE_UPGRADE_LEVELS:
		if new_level >= threshold:
			tier += 1
	if tier > _current_sprite_tier:
		_current_sprite_tier = tier
		_apply_sprite_upgrade(tier)
	# Celebration animation
	_play_level_up_vfx()

func _apply_sprite_upgrade(tier: int) -> void:
	# Try to load tier-specific texture: e.g. blade_knight_t2
	var tier_key = "%s_t%d" % [hero_class, tier]
	var tex = SpriteGenerator.get_texture(tier_key)
	if tex:
		sprite.texture = tex
		_idle_texture = tex
		_dir_textures["down"] = tex
	# Also try tier-specific directional sprites
	for dir_key in ["down", "up", "side", "down_side", "up_side"]:
		var dtex = SpriteGenerator.get_texture("%s_t%d_dir_%s" % [hero_class, tier, dir_key])
		if dtex:
			_dir_textures[dir_key] = dtex

func _play_level_up_vfx() -> void:
	# Golden burst: hero glows, expands, spawns radial sparkles, settles
	var base_scale = sprite.scale
	var tween = create_tween()
	# Phase 1: Golden glow swell
	tween.tween_property(sprite, "modulate", Color(1.8, 1.5, 0.5), 0.08)
	tween.parallel().tween_property(sprite, "scale", base_scale * 1.25, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Phase 2: Bright white peak flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.2, 1.5), 0.04)
	# Spawn radial sparkles at peak
	tween.tween_callback(_spawn_level_up_sparkles)
	# Spawn expanding ring
	tween.tween_callback(_spawn_level_up_ring)
	# Phase 3: Settle with bounce
	tween.tween_property(sprite, "scale", base_scale * 0.9, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 1.2, 0.7), 0.08)
	tween.tween_property(sprite, "scale", base_scale * 1.05, 0.06)
	tween.tween_property(sprite, "scale", base_scale, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_do_screen_shake(5.0)

func _spawn_level_up_sparkles() -> void:
	var world = _get_world_node()
	if not world:
		return
	for _i in range(randi_range(8, 12)):
		var sparkle = Sprite2D.new()
		sparkle.texture = _tex_crystal_white
		if not sparkle.texture:
			sparkle.queue_free()
			return
		sparkle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sparkle.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-20, -5))
		sparkle.scale = Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
		sparkle.modulate = Color(
			randf_range(1.2, 2.0),
			randf_range(0.9, 1.5),
			randf_range(0.2, 0.6),
			0.9
		)
		sparkle.z_index = 5
		world.add_child(sparkle)
		var angle = randf() * TAU
		var dist = randf_range(20, 45)
		var dest = sparkle.global_position + Vector2(cos(angle), sin(angle)) * dist
		var t = sparkle.create_tween()
		t.set_parallel(true)
		t.tween_property(sparkle, "global_position", dest, randf_range(0.3, 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(sparkle, "scale", Vector2(0.05, 0.05), 0.45)
		t.tween_property(sparkle, "rotation", randf_range(-TAU, TAU), 0.45)
		t.set_parallel(false)
		t.tween_property(sparkle, "modulate:a", 0.0, 0.2)
		t.tween_callback(sparkle.queue_free)

func _spawn_level_up_ring() -> void:
	var world = _get_world_node()
	if not world:
		return
	var ring = Sprite2D.new()
	ring.texture = _tex_crystal_white if _tex_crystal_white else _tex_slash_arc
	if not ring.texture:
		ring.queue_free()
		return
	ring.global_position = global_position + Vector2(0, -10)
	ring.modulate = Color(1.0, 0.85, 0.3, 0.8)
	ring.scale = Vector2(0.3, 0.3)
	ring.z_index = 10
	world.add_child(ring)
	var t = ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(ring.queue_free)

func _sync_to_death_counters() -> void:
	DeathCounterSystem.set_value("level_p%d" % player_id, stats.level)
	DeathCounterSystem.set_value("xp_p%d" % player_id, stats.xp)
	DeathCounterSystem.set_value("hp_p%d" % player_id, stats.current_hp)
	DeathCounterSystem.set_value("max_hp_p%d" % player_id, stats.get_total_max_hp())

func _register_fog_trigger() -> void:
	var fog_trigger = TriggerEngine.Trigger.new()
	fog_trigger.conditions = [func(): return is_instance_valid(self)]
	fog_trigger.actions = [func(): FogOfWarManager.update_visibility([global_position])]
	TriggerEngine.register(fog_trigger)

# ── Death & Respawn Animations ─────────────────────────────────────────

func _on_death_animation(_player_id: int) -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	# Reset attack state so it can't get stuck across death/respawn
	_is_attack_animating = false
	_attack_cooldown = 0.0
	_hit_freeze_active = false
	sprite.modulate = Color.WHITE
	# Cancel any ongoing animations
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	if _idle_breathe_tween and _idle_breathe_tween.is_valid():
		_idle_breathe_tween.kill()
	if _idle_fidget_tween and _idle_fidget_tween.is_valid():
		_idle_fidget_tween.kill()
	_stop_immunity_vfx()
	_was_on_heal_beacon = false
	# Death animation: dramatic multi-phase hero death
	_death_tween = create_tween()
	# Phase 1: Impact freeze — bright white flash, time stops for the hero
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.05)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.05)
	_death_tween.tween_interval(0.1)  # Hold the freeze frame
	# Phase 2: Stagger — hero reels, trying to stay up
	_death_tween.tween_property(sprite, "modulate", Color(1.3, 0.4, 0.3), 0.08)
	_death_tween.tween_property(sprite, "position", sprite.position + Vector2(-3, 0), 0.06)
	_death_tween.parallel().tween_property(sprite, "rotation", deg_to_rad(-8), 0.06)
	_death_tween.tween_property(sprite, "position", sprite.position + Vector2(4, 0), 0.06)
	_death_tween.parallel().tween_property(sprite, "rotation", deg_to_rad(12), 0.06)
	_death_tween.tween_property(sprite, "position", sprite.position + Vector2(-2, 0), 0.05)
	_death_tween.parallel().tween_property(sprite, "rotation", deg_to_rad(-5), 0.05)
	# Phase 3: Knees buckle — squash down with color drain
	_death_tween.tween_property(sprite, "scale", Vector2(1.3, 0.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, 6), 0.15)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.2, 0.15, 0.8), 0.15)
	# Phase 4: Final collapse sideways
	_death_tween.tween_property(sprite, "rotation", deg_to_rad(80), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(6, 10), 0.2)
	_death_tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.3), 0.2)
	# Phase 5: Fade to ghostly
	_death_tween.tween_property(sprite, "modulate", Color(0.5, 0.15, 0.1, 0.3), 0.3)
	# Hide shadow
	if _shadow:
		_death_tween.tween_property(_shadow, "modulate:a", 0.0, 0.15)
	# Spawn death particles
	_death_tween.tween_callback(_spawn_hero_death_particles)

func _spawn_hero_death_particles() -> void:
	var world = _get_world_node()
	if not world:
		return
	# Red-orange embers rising from fallen hero
	for _i in range(randi_range(6, 10)):
		var ember = Sprite2D.new()
		ember.texture = _tex_crystal_white
		if not ember.texture:
			ember.queue_free()
			return
		ember.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ember.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-5, 5))
		ember.scale = Vector2(randf_range(0.2, 0.5), randf_range(0.2, 0.5))
		ember.modulate = Color(
			randf_range(1.0, 1.8),
			randf_range(0.2, 0.5),
			randf_range(0.05, 0.15),
			randf_range(0.6, 0.9)
		)
		ember.z_index = 5
		world.add_child(ember)
		var dest = ember.global_position + Vector2(randf_range(-15, 15), randf_range(-30, -12))
		var t = ember.create_tween()
		t.set_parallel(true)
		t.tween_property(ember, "global_position", dest, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_SINE)
		t.tween_property(ember, "scale", Vector2(0.03, 0.03), 0.8)
		t.tween_property(ember, "rotation", randf_range(-TAU, TAU), 0.8)
		t.set_parallel(false)
		t.tween_property(ember, "modulate:a", 0.0, 0.3)
		t.tween_callback(ember.queue_free)
	_do_screen_shake(8.0)

func _on_respawn_animation(_player_id: int) -> void:
	# Kill death tween if still running
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	# Reset ALL input and combat state so nothing is stale after respawn
	_is_attack_animating = false
	_attack_cooldown = 0.0
	_hit_freeze_active = false
	sprite.modulate = Color.WHITE
	_is_moving_to_target = false
	_move_target = Vector2.ZERO
	_stuck_time = 0.0
	_target_tree = null
	_target_enemy = null
	_is_chopping_tree = false
	_joystick_touch_index = -1
	_joystick_input = Vector2.ZERO
	_joystick_active = false
	_hide_joystick()
	_mobile_atk_touch_index = -1
	_mobile_attack_held = false
	_mobile_charge_aim_dir = Vector2.ZERO
	_tap_count = 0
	_tap_resolve_timer = 0.0
	_tap_resolved = true
	_charge_time = 0.0
	_is_charging = false
	_combo_index = 0
	_combo_timer = 0.0
	_tap_aim_dir = Vector2.ZERO
	_tap_aim_timer = 0.0
	# Reset sprite to invisible for regen build-up
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.scale = Vector2(0.3, 0.3)
	sprite.rotation = 0.0
	if _shadow:
		_shadow.modulate.a = 0.0
	# Grand resurrection animation
	_death_tween = create_tween()
	# Phase 1: Gathering energy — swirling sparkles converge inward
	_death_tween.tween_callback(_spawn_respawn_converge_sparkles)
	_death_tween.tween_interval(0.25)
	# Phase 2: Form materializes — scale up from nothing with ethereal blue-white glow
	_death_tween.set_parallel(true)
	_death_tween.tween_property(sprite, "modulate", Color(0.7, 0.9, 1.5, 0.6), 0.15).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.15).set_ease(Tween.EASE_OUT)
	_death_tween.chain()
	# Phase 3: Body solidifies — flicker between translucent and solid
	_death_tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
	_death_tween.tween_property(sprite, "modulate:a", 0.4, 0.04)
	_death_tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
	_death_tween.tween_property(sprite, "modulate:a", 0.5, 0.03)
	_death_tween.tween_property(sprite, "modulate:a", 1.0, 0.04)
	# Phase 4: Golden power surge — expand with bright flash
	_death_tween.set_parallel(true)
	_death_tween.tween_property(sprite, "modulate", Color(2.0, 1.7, 0.8, 1.0), 0.08)
	_death_tween.tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_death_tween.chain()
	# Phase 5: Settle with heroic bounce
	_death_tween.tween_property(sprite, "scale", Vector2(0.92, 1.08), 0.07)
	_death_tween.parallel().tween_property(sprite, "modulate", Color(1.3, 1.15, 0.8), 0.07)
	_death_tween.tween_property(sprite, "scale", Vector2(1.04, 0.97), 0.06)
	_death_tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	_death_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	# Restore shadow
	if _shadow:
		_death_tween.parallel().tween_property(_shadow, "modulate:a", 1.0, 0.15)
	_death_tween.tween_callback(func():
		_is_dead = false
		_spawn_respawn_flash()
		_do_screen_shake(6.0)
	)

func _spawn_respawn_converge_sparkles() -> void:
	# Sparkles that converge inward to the respawn point
	var world = _get_world_node()
	if not world:
		return
	for _i in range(randi_range(8, 12)):
		var spark = Sprite2D.new()
		spark.texture = _tex_crystal_white
		if not spark.texture:
			spark.queue_free()
			return
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var angle = randf() * TAU
		var dist = randf_range(35, 60)
		spark.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist + Vector2(0, -10)
		spark.scale = Vector2(randf_range(0.3, 0.6), randf_range(0.3, 0.6))
		spark.modulate = Color(
			randf_range(0.6, 1.0),
			randf_range(0.8, 1.2),
			randf_range(1.2, 2.0),
			0.8
		)
		spark.z_index = 5
		world.add_child(spark)
		# Converge inward toward hero center
		var dest = global_position + Vector2(randf_range(-3, 3), randf_range(-12, -8))
		var t = spark.create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "global_position", dest, randf_range(0.2, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(spark, "scale", Vector2(0.1, 0.1), 0.35)
		t.tween_property(spark, "rotation", randf_range(-TAU, TAU), 0.35)
		t.set_parallel(false)
		t.tween_property(spark, "modulate:a", 0.0, 0.05)
		t.tween_callback(spark.queue_free)

func _spawn_respawn_flash() -> void:
	# Double expanding ring — golden inner, white outer
	var world = _get_world_node()
	if not world:
		return
	for ring_i in range(2):
		var flash = Sprite2D.new()
		flash.texture = _tex_crystal_white if _tex_crystal_white else _tex_slash_arc
		if not flash.texture:
			flash.queue_free()
			continue
		flash.global_position = global_position + Vector2(0, -10)
		flash.z_index = 10
		if ring_i == 0:
			# Inner golden ring — faster, smaller
			flash.modulate = Color(1.0, 0.85, 0.3, 0.9)
			flash.scale = Vector2(0.3, 0.3)
			world.add_child(flash)
			var t = flash.create_tween()
			t.set_parallel(true)
			t.tween_property(flash, "scale", Vector2(3.5, 3.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(flash, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.set_parallel(false)
			t.tween_callback(flash.queue_free)
		else:
			# Outer white ring — slower, larger
			flash.modulate = Color(0.8, 1.0, 0.8, 0.6)
			flash.scale = Vector2(0.5, 0.5)
			world.add_child(flash)
			var t = flash.create_tween()
			t.set_parallel(true)
			t.tween_property(flash, "scale", Vector2(5.0, 5.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(flash, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.set_parallel(false)
			t.tween_callback(flash.queue_free)
