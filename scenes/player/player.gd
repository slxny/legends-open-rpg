extends CharacterBody2D

signal attacked(target: Node2D)

@onready var stats: StatsComponent = $StatsComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var ability_mgr: AbilityManager = $AbilityManager
@onready var sprite: Sprite2D = $Sprite
@onready var attack_area: Area2D = $AttackArea
@onready var camera: Camera2D = $Camera2D
@onready var pickup_area: Area2D = $PickupArea

var hero_class: String = ""
var player_id: int = 0
var _enemies_in_range: Array[Node2D] = []

# Click-to-move
var _move_target: Vector2 = Vector2.ZERO
var _is_moving_to_target: bool = false

var _shadow: Sprite2D = null

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
var _shake_tween: Tween = null  # Track screen shake to prevent overlap

# Status effects applied by enemies
var _is_paralyzed: bool = false
var _paralyze_timer: float = 0.0
var _slow_factor: float = 1.0  # 1.0 = normal, < 1.0 = slowed
var _slow_timer: float = 0.0
var _effect_vfx: Sprite2D = null  # Visual indicator for active status effect

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
var _charge_shake_tween: Tween = null  # Sprite shake during charge
const TAP_RESOLVE_TIME: float = 0.12  # 120ms buffer — ~7 frames, barely perceptible
const CHARGE_THRESHOLD: float = 1.5   # Hold 1.5s for charged slash

# Special attack type for current attack
enum SpecialAttack { NONE, POWER_STRIKE, WHIRLWIND, CHARGED_SLASH, DASH_STRIKE }

func _ready() -> void:
	add_to_group("player")
	hero_class = GameManager.current_hero_class
	stats.initialize_from_hero(hero_class)
	inventory.setup(stats)
	ability_mgr.setup(stats, hero_class)

	var tex = SpriteGenerator.get_texture(hero_class)
	if tex:
		sprite.texture = tex
		_idle_texture = tex

	# Cache directional idle textures
	for dir_key in ["down", "up", "side"]:
		var dtex = SpriteGenerator.get_texture(hero_class + "_dir_" + dir_key)
		if dtex:
			_dir_textures[dir_key] = dtex
	# Default facing texture is the base sprite (facing down/front)
	if not _dir_textures.has("down"):
		_dir_textures["down"] = _idle_texture

	# Cache walk cycle frames (3 frames per direction)
	for dir_key in ["down", "up", "side"]:
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

	var shape = attack_area.get_node("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = stats.attack_range

	# Shadow under hero
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)

	# Sync initial state to DeathCounterSystem
	_sync_to_death_counters()
	# Connect level-up for sprite upgrade and DC sync
	stats.leveled_up.connect(_on_level_up_sprite_upgrade)
	# Register fog of war update trigger
	_register_fog_trigger()

## Public API for external systems (e.g. minimap click) to move the player.
func move_to(world_pos: Vector2) -> void:
	_move_target = world_pos
	_is_moving_to_target = true
	_spawn_move_indicator(_move_target)


func _physics_process(delta: float) -> void:
	# Process status effects
	_process_status_effects(delta)

	# Paralyzed: can't move or attack
	if _is_paralyzed:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	var max_speed = stats.get_total_move_speed() * _slow_factor
	var desired_velocity := Vector2.ZERO

	if input_dir.length() > 0:
		_is_moving_to_target = false
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
	if desired_velocity.length() > 0:
		velocity = velocity.move_toward(desired_velocity, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	_update_walk_anim(delta)
	stats.process_regen(delta)

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

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
			if taps >= 3:
				_try_special_attack(SpecialAttack.WHIRLWIND)
			elif taps >= 2:
				_try_special_attack(SpecialAttack.POWER_STRIKE)
			else:
				# Single tap — fire normal attack immediately
				_try_manual_attack()

	# --- Hold-to-attack: only after tap sequence resolved ---
	if not _is_paralyzed and _tap_resolved:
		if Input.is_action_pressed("attack"):
			_charge_time += delta
			if _charge_time >= CHARGE_THRESHOLD and not _is_charging and not _is_attack_animating:
				_is_charging = true
				_start_charge_vfx()
			if not _is_charging:
				_try_manual_attack()
		else:
			if _is_charging and not _is_attack_animating:
				_is_charging = false
				_stop_charge_vfx()
				_try_special_attack(SpecialAttack.CHARGED_SLASH)
			_charge_time = 0.0

	# Update facing direction from movement
	if velocity.length() > 5 and not _is_attack_animating:
		_set_facing(velocity.normalized())

func _update_walk_anim(delta: float) -> void:
	if _is_attack_animating:
		return  # Attack tweens own the sprite

	var speed_ratio = velocity.length() / max(stats.get_total_move_speed(), 1.0)
	var frames = _walk_frames.get(_facing_cat, []) as Array

	if speed_ratio > 0.15 and frames.size() == 3:
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

const ZOOM_MIN := Vector2(1.5, 1.5)
const ZOOM_MAX := Vector2(5.0, 5.0)
const ZOOM_STEP := 0.25

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		# Trackpad pinch: factor > 1 = pinch out (zoom in), < 1 = pinch in (zoom out)
		var new_zoom = (camera.zoom * event.factor).clamp(ZOOM_MIN, ZOOM_MAX)
		camera.zoom = new_zoom
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(ZOOM_MIN, ZOOM_MAX)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(ZOOM_MIN, ZOOM_MAX)
			return

		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click on an enemy = attack (same as space)
			if event.button_index == MOUSE_BUTTON_RIGHT:
				var enemy_target = _get_enemy_at_mouse()
				if enemy_target and not _is_paralyzed:
					_try_manual_attack()
					return
			# Both mouse buttons move to clicked position
			var clicked = _get_clickable_at_mouse()
			if clicked and clicked.has_method("interact"):
				_move_target = clicked.global_position
			else:
				_move_target = _get_world_mouse_pos()
			_is_moving_to_target = true
			_spawn_move_indicator(_move_target)

	# Window controls
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
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

	# Abilities (Q and E)
	if event.is_action_pressed("ability_1"):
		_use_ability("ability_1")
	elif event.is_action_pressed("ability_2"):
		_use_ability("ability_2")
	# Consumable slots
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: inventory.use_consumable(0)
			KEY_2: inventory.use_consumable(1)
			KEY_3: inventory.use_consumable(2)
			KEY_4: inventory.use_consumable(3)

func _try_manual_attack() -> void:
	if _is_attack_animating or _attack_cooldown > 0.0:
		return

	_attack_cooldown = 0.5 / stats.attack_speed

	# Determine attack direction from held movement input, fall back to last facing
	var input_raw = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var attack_dir: Vector2
	if input_raw.length() > 0.25:
		attack_dir = input_raw.normalized()
	else:
		attack_dir = _facing

	# Update facing to match attack direction
	_set_facing(attack_dir)

	# Diagonal keys + attack = dash strike
	if abs(input_raw.x) > 0.3 and abs(input_raw.y) > 0.3:
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
		_perform_attack(hit_target, attack_dir)
	else:
		_perform_swing_no_target(attack_dir)

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

func apply_effect(effect_type: String, duration: float, value: float = 0.0) -> void:
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

func apply_knockback_effect(dir: Vector2, force: float) -> void:
	# Strong knockback from enemy effect proc
	velocity = dir * force
	_spawn_effect_label("KNOCKBACK!", Color(1.0, 0.6, 0.1))

func _spawn_effect_vfx(color: Color, duration: float, label_text: String) -> void:
	_clear_effect_vfx()
	# Pulsing aura around the player
	_effect_vfx = Sprite2D.new()
	_effect_vfx.texture = SpriteGenerator.get_texture("beacon_blue")
	_effect_vfx.modulate = color
	_effect_vfx.z_index = -1
	add_child(_effect_vfx)
	var tween = _effect_vfx.create_tween().set_loops()
	tween.tween_property(_effect_vfx, "modulate:a", color.a * 0.3, 0.4)
	tween.tween_property(_effect_vfx, "modulate:a", color.a, 0.4)
	# Auto-cleanup after duration
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(duration)
	cleanup_tween.tween_callback(_clear_effect_vfx)
	# Label
	_spawn_effect_label(label_text, color)

func _spawn_effect_label(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = Vector2(-30, -50)
	var settings = LabelSettings.new()
	settings.font_size = 16
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 25, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _clear_effect_vfx() -> void:
	if _effect_vfx and is_instance_valid(_effect_vfx):
		_effect_vfx.queue_free()
		_effect_vfx = null

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

func _execute_power_strike(attack_dir: Vector2) -> void:
	# Double-tap: Heavy single-target hit, 1.4x damage, dramatic wind-up
	_is_attack_animating = true
	_attack_cooldown = 0.7 / stats.attack_speed  # Slightly longer cooldown
	var dir = attack_dir
	var perp = Vector2(-dir.y, dir.x)
	var base_pos = sprite.position

	var hit_target = _find_best_target(dir)
	var dmg_mult := 1.4

	# Pick overhead chop frames for the heavy feel
	var frames = _combo_swings[2] if _combo_swings.size() > 2 else []

	var tween = create_tween()
	# Long dramatic wind-up: pull WAY back
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	tween.tween_property(sprite, "position", base_pos - dir * 8.0 + Vector2(0, -6), 0.14)
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.06)
	# Flash gold during wind-up
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.7))
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# SLAM forward
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.25), 0.03)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	# Impact
	tween.tween_property(sprite, "position", base_pos + dir * 20.0, 0.03)
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		if hit_target and is_instance_valid(hit_target):
			var result = CombatManager.calculate_damage(stats.get_stats_dict(), hit_target.get_stats_dict(), dmg_mult)
			hit_target.take_damage(result["damage"], result["is_crit"])
			hit_target.apply_knockback(dir, 90.0)
			_spawn_slash_vfx(dir, 50.0, 1.8)
			_spawn_slash_vfx(dir.rotated(0.2), 45.0, 1.4)
			_spawn_slash_vfx(dir.rotated(-0.2), 45.0, 1.4)
			_spawn_impact_vfx(hit_target.global_position, true)
			_do_screen_shake(7.0)
			_do_hit_freeze(true)
		else:
			_spawn_slash_vfx(dir, 50.0, 1.8)
			_do_screen_shake(3.0)
		_spawn_effect_label("POWER STRIKE!", Color(1.0, 0.85, 0.2))
	)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.06)
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
	# Spawn slash VFX at midpoint of spin
	tween.tween_callback(func():
		_spawn_slash_vfx(dir, 50.0, 2.0)
		_spawn_slash_vfx(dir.rotated(PI * 0.5), 45.0, 1.6)
		_spawn_slash_vfx(dir.rotated(PI), 45.0, 1.6)
		_spawn_slash_vfx(dir.rotated(-PI * 0.5), 45.0, 1.6)
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
		_spawn_effect_label("WHIRLWIND!", Color(0.8, 0.5, 1.0))
	)
	# Unwind
	tween.tween_property(sprite, "rotation", 0.0, 0.1)
	tween.tween_interval(0.06)
	_anim_return_to_idle(tween, base_pos)

func _execute_charged_slash(attack_dir: Vector2) -> void:
	# Hold attack 1.5s: Heavy single hit, 1.6x damage
	_is_attack_animating = true
	_attack_cooldown = 0.8 / stats.attack_speed
	var dir = attack_dir
	var perp = Vector2(-dir.y, dir.x)
	var base_pos = sprite.position
	var dmg_mult := 1.6

	var hit_target = _find_best_target(dir)

	# Use thrust frames for the release
	var frames = _combo_swings[3] if _combo_swings.size() > 3 else []

	var tween = create_tween()
	# Already charged up — now RELEASE. Brief coil then explosive lunge
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[0])
	# Bright flash on release
	tween.tween_callback(func(): sprite.modulate = Color(2.0, 1.8, 1.0))
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.04)
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.03)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[1])
	# Explosive forward lunge
	tween.tween_property(sprite, "position", base_pos + dir * 24.0, 0.06)
	if frames.size() >= 3:
		tween.tween_callback(func(): sprite.texture = frames[2])
	tween.tween_property(sprite, "position", base_pos + dir * 28.0, 0.03)
	# Impact — the big one
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		# Massive VFX burst
		_spawn_slash_vfx(dir, 55.0, 2.2)
		_spawn_slash_vfx(dir.rotated(0.3), 50.0, 1.8)
		_spawn_slash_vfx(dir.rotated(-0.3), 50.0, 1.8)
		_spawn_slash_vfx(dir, 35.0, 1.4)
		if hit_target and is_instance_valid(hit_target):
			var result = CombatManager.calculate_damage(stats.get_stats_dict(), hit_target.get_stats_dict(), dmg_mult)
			hit_target.take_damage(result["damage"], result["is_crit"])
			hit_target.apply_knockback(dir, 140.0)
			_spawn_impact_vfx(hit_target.global_position, true)
			_do_screen_shake(10.0)
			_do_hit_freeze(true)
		else:
			_do_screen_shake(5.0)
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
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("_is_dead"):
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
		_spawn_effect_label("DASH STRIKE!", Color(0.4, 0.9, 1.0))
	)
	tween.tween_property(sprite, "rotation", 0.0, 0.08)
	tween.tween_interval(0.05)
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
	_charge_vfx.texture = SpriteGenerator.get_texture("beacon_blue")
	_charge_vfx.modulate = Color(1.0, 0.8, 0.2, 0.0)
	_charge_vfx.z_index = -1
	add_child(_charge_vfx)
	# Glow intensifies as you charge
	var tween = _charge_vfx.create_tween().set_loops()
	tween.tween_property(_charge_vfx, "modulate:a", 0.7, 0.3)
	tween.tween_property(_charge_vfx, "modulate:a", 0.3, 0.3)
	# Also vibrate sprite to show charge tension
	if _charge_shake_tween and _charge_shake_tween.is_valid():
		_charge_shake_tween.kill()
	_charge_shake_tween = create_tween().set_loops()
	_charge_shake_tween.tween_property(sprite, "offset:x", sprite.offset.x + 1.5, 0.03)
	_charge_shake_tween.tween_property(sprite, "offset:x", sprite.offset.x - 1.5, 0.03)

func _stop_charge_vfx() -> void:
	if _charge_shake_tween and _charge_shake_tween.is_valid():
		_charge_shake_tween.kill()
		_charge_shake_tween = null
		sprite.offset.x = 0.0
	if _charge_vfx and is_instance_valid(_charge_vfx):
		_charge_vfx.queue_free()
		_charge_vfx = null

func _get_world_mouse_pos() -> Vector2:
	# Use the viewport's canvas transform so the result matches what is
	# visually on screen, even when camera position_smoothing is active.
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

func _get_enemy_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collision_mask = 2  # Enemies only
	var results = space.intersect_point(params, 1)
	if results.size() > 0:
		var col = results[0]["collider"]
		if col.is_in_group("enemies") and not col.get("_is_dead"):
			return col
	return null

func _get_clickable_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collision_mask = 4  # NPCs only for movement interaction
	var results = space.intersect_point(params, 1)
	if results.size() > 0:
		return results[0]["collider"]
	return null

func _set_facing(dir: Vector2) -> void:
	_facing = dir
	# Determine direction category with hysteresis to prevent jitter
	var new_cat: String
	var new_flip: bool = false
	if abs(dir.x) > abs(dir.y) * 0.6:
		new_cat = "side"
		new_flip = dir.x < 0
	elif dir.y < -0.3:
		new_cat = "up"
	else:
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
	# Prefer held arrow/WASD keys, fall back to last facing direction
	var input_raw = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_raw.length() > 0.25:
		return input_raw.normalized()
	return _facing

func _use_ability(ability_key: String) -> void:
	var ability_data = ability_mgr.use_ability(ability_key, self)
	if ability_data.is_empty():
		return

	# Capture aim direction NOW (before the delay), so held keys at cast time matter
	var aim_dir = _get_aim_direction()

	# Face the aim direction
	_set_facing(aim_dir)

	# SC:BW trigger delay feel
	await get_tree().create_timer(0.3).timeout
	if ability_data.has("damage_multiplier") and ability_data.has("radius"):
		_execute_aoe_ability(ability_data, aim_dir)
	elif ability_data.has("projectile_count"):
		_execute_projectile_ability(ability_data, aim_dir)
	elif ability_data.has("armor_bonus"):
		ability_mgr.apply_buff("armor", ability_data["armor_bonus"], ability_data["duration"])
		_spawn_buff_vfx(Color(0.4, 0.6, 1.0, 0.4), ability_data["duration"])
		GameManager.game_message.emit("Shield Wall! +%d Armor" % int(ability_data["armor_bonus"]), Color(0.4, 0.7, 1.0))
	elif ability_data.has("dodge_bonus"):
		ability_mgr.apply_buff("dodge", ability_data["dodge_bonus"], ability_data["duration"])
		_spawn_buff_vfx(Color(0.2, 1.0, 0.4, 0.3), ability_data["duration"])
		GameManager.game_message.emit("Evasion! +%d%% Dodge" % int(ability_data["dodge_bonus"] * 100), Color(0.3, 1.0, 0.5))

func _execute_aoe_ability(ability_data: Dictionary, aim_dir: Vector2) -> void:
	var radius = ability_data.get("radius", 80.0)
	var arc = deg_to_rad(ability_data.get("arc_degrees", 120.0))

	_spawn_slash_vfx(aim_dir, radius, 1.5)

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to_enemy = enemy.global_position - global_position
		if to_enemy.length() > radius:
			continue
		var angle_diff = abs(aim_dir.angle_to(to_enemy.normalized()))
		if angle_diff > arc / 2.0:
			continue
		var result = CombatManager.calculate_damage(stats.get_stats_dict(), enemy.get_stats_dict(), ability_data["damage_multiplier"])
		enemy.take_damage(result["damage"], result["is_crit"])
	_do_screen_shake(4.0)

func _execute_projectile_ability(ability_data: Dictionary, aim_dir: Vector2) -> void:
	var base_dir = aim_dir
	var count = ability_data.get("projectile_count", 3)
	var spread = deg_to_rad(ability_data.get("spread_degrees", 30.0))
	var speed = ability_data.get("projectile_speed", 400.0)
	var proj_range = ability_data.get("projectile_range", 300.0)
	var dmg_mult = ability_data.get("damage_multiplier", 0.8)

	for i in range(count):
		var angle_offset = lerp(-spread / 2.0, spread / 2.0, float(i) / max(1, count - 1))
		var dir = base_dir.rotated(angle_offset)
		_spawn_projectile(dir, speed, proj_range, dmg_mult)

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

	var tween = create_tween()
	var end_pos = global_position + direction * max_range
	var travel_time = max_range / speed
	tween.tween_property(projectile, "position", end_pos, travel_time)
	tween.tween_callback(projectile.queue_free)

	projectile.body_entered.connect(func(body: Node2D):
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var result = CombatManager.calculate_damage(stats.get_stats_dict(), body.get_stats_dict(), dmg_mult)
			body.take_damage(result["damage"], result["is_crit"])
			_spawn_impact_vfx(body.global_position)
			projectile.queue_free()
	)


func _perform_attack(target: Node2D, attack_dir: Vector2 = Vector2.RIGHT) -> void:
	_is_attack_animating = true
	attacked.emit(target)

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
	var cur_cat = _get_dir_category(dir)
	var swing_idx = _pick_combo_swing(cur_cat)
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
			_do_screen_shake(2.5 if not result["is_crit"] else 5.0)
			_do_hit_freeze(result["is_crit"])
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
			_do_screen_shake(4.0 if not result["is_crit"] else 7.0)
			_do_hit_freeze(result["is_crit"])
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
			_do_screen_shake(3.0 if not result["is_crit"] else 6.0)
			_do_hit_freeze(result["is_crit"])
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
			_do_screen_shake(5.0 if not result["is_crit"] else 8.0)
			_do_hit_freeze(result["is_crit"])
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
				_do_screen_shake(1.5 if not result["is_crit"] else 3.5)
				_do_hit_freeze(result["is_crit"])
			arrow.queue_free()
		)
	)
	tween.tween_interval(0.2)
	tween.tween_callback(func(): _is_attack_animating = false)

func _spawn_slash_vfx(direction: Vector2, radius: float, scale_mult: float) -> void:
	var slash = Sprite2D.new()
	slash.texture = SpriteGenerator.get_texture("slash_arc")
	slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	tween.tween_callback(slash.queue_free)

func _spawn_impact_vfx(pos: Vector2, is_crit: bool = false) -> void:
	var spark_count = 6 if is_crit else 3
	var spread = 28.0 if is_crit else 18.0
	for i in range(spark_count):
		var spark = Sprite2D.new()
		spark.texture = SpriteGenerator.get_texture("crystal_white")
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spark.global_position = pos
		var sc = randf_range(0.3, 0.7) if not is_crit else randf_range(0.5, 1.0)
		spark.scale = Vector2(sc, sc)
		# Orange-red sparks, brighter on crit
		var r = randf_range(0.9, 1.0)
		var g = randf_range(0.2, 0.5) if not is_crit else randf_range(0.6, 0.9)
		spark.modulate = Color(r, g, 0.1, 1.0)
		spark.z_index = 12
		_get_world_node().add_child(spark)
		var dir = Vector2.from_angle(randf() * TAU) * randf_range(spread * 0.4, spread)
		var dur = randf_range(0.12, 0.22)
		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + dir, dur)
		tween.tween_property(spark, "modulate:a", 0.0, dur)
		tween.tween_property(spark, "scale", Vector2.ZERO, dur)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

	# White flash ring at impact centre
	var flash = Sprite2D.new()
	flash.texture = SpriteGenerator.get_texture("selection_red")
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.modulate = Color(1.0, 0.9, 0.5, 0.9) if not is_crit else Color(1.0, 0.3, 0.1, 1.0)
	flash.scale = Vector2(0.2, 0.2)
	flash.z_index = 13
	flash.global_position = pos
	_get_world_node().add_child(flash)
	var ft = flash.create_tween()
	ft.set_parallel(true)
	ft.tween_property(flash, "scale", Vector2(1.2, 1.2) if not is_crit else Vector2(2.0, 2.0), 0.1)
	ft.tween_property(flash, "modulate:a", 0.0, 0.12)
	ft.set_parallel(false)
	ft.tween_callback(flash.queue_free)

func _do_hit_freeze(is_crit: bool) -> void:
	if _hit_freeze_active:
		return  # Don't stack freezes
	_hit_freeze_active = true
	# Brief time-scale dip — 1-2 real frames, not seconds
	Engine.time_scale = 0.1
	var freeze_dur = 0.03 if not is_crit else 0.05
	# process_always so the timer isn't dilated by the time_scale we just set
	var timer = get_tree().create_timer(freeze_dur, true, false, true)
	await timer.timeout
	Engine.time_scale = 1.0
	_hit_freeze_active = false

func _do_screen_shake(intensity: float) -> void:
	# Kill any running shake so they don't fight over the offset
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		camera.offset = Vector2.ZERO
	_shake_tween = create_tween()
	for i in range(4):
		var decay = 1.0 - float(i) / 4.0
		var shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * intensity * decay
		_shake_tween.tween_property(camera, "offset", shake, 0.02)
	_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)

func _spawn_auto_attack_projectile(target: Node2D) -> void:
	pass  # Handled by _do_ranged_attack now

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		_enemies_in_range.append(body)

func _on_attack_area_body_exited(body: Node2D) -> void:
	_enemies_in_range.erase(body)

# Walk-over pickup for items/gold dropped on the ground
func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("ground_items"):
		var item = area.get_meta("item_data", {})
		if item.is_empty():
			return
		if item.get("id") == "_gold":
			GameManager.add_gold(item.get("gold_amount", 0))
			GameManager.game_message.emit("+ %s" % item.get("name", "Gold"), Color(0.3, 0.6, 1.0))
			area.queue_free()
			return
		if inventory.add_item(item):
			GameManager.game_message.emit("+ %s" % item.get("name", "Item"), Color(0.2, 1.0, 0.2))
			area.queue_free()

func _spawn_buff_vfx(color: Color, duration: float) -> void:
	var vfx = Sprite2D.new()
	vfx.texture = SpriteGenerator.get_texture("beacon_blue")
	vfx.modulate = color
	vfx.z_index = -1
	add_child(vfx)

	var tween = create_tween()
	tween.tween_property(vfx, "modulate:a", 0.15, duration * 0.8)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.2)
	tween.tween_callback(vfx.queue_free)

func _spawn_move_indicator(pos: Vector2) -> void:
	var indicator = Sprite2D.new()
	indicator.texture = SpriteGenerator.get_texture("beacon_green")
	indicator.scale = Vector2(0.3, 0.3)
	indicator.global_position = pos
	indicator.modulate.a = 0.7
	_get_world_node().add_child(indicator)
	var tween = indicator.create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
	tween.tween_callback(indicator.queue_free)

func _get_world_node() -> Node:
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		return world[0]
	return get_tree().current_scene

func get_stats_dict() -> Dictionary:
	return stats.get_stats_dict()

func take_damage(amount: int, is_crit: bool = false) -> void:
	stats.take_damage(amount)
	_spawn_damage_number(amount, is_crit)
	_do_hit_flash()

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	var label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10), -35)
	var settings = LabelSettings.new()
	settings.font_size = 14 if not is_crit else 22
	settings.font_color = Color(1.0, 0.3, 0.3) if not is_crit else Color(1.0, 0.1, 0.1)
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _do_hit_flash() -> void:
	sprite.modulate = Color(1, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

## Sprite upgrade at level milestones (5, 10, 15, ... 50)
func _on_level_up_sprite_upgrade(new_level: int) -> void:
	_sync_to_death_counters()
	# Check if we hit a sprite upgrade tier
	var tier = 0
	for threshold in SPRITE_UPGRADE_LEVELS:
		if new_level >= threshold:
			tier += 1
	if tier > _current_sprite_tier:
		_current_sprite_tier = tier
		_apply_sprite_upgrade(tier)
		GameManager.game_message.emit("LEVEL UP!", Color(1.0, 0.9, 0.2))

func _apply_sprite_upgrade(tier: int) -> void:
	# Try to load tier-specific texture: e.g. blade_knight_t2
	var tier_key = "%s_t%d" % [hero_class, tier]
	var tex = SpriteGenerator.get_texture(tier_key)
	if tex:
		sprite.texture = tex
		_idle_texture = tex
		_dir_textures["down"] = tex
	# Also try tier-specific directional sprites
	for dir_key in ["down", "up", "side"]:
		var dtex = SpriteGenerator.get_texture("%s_t%d_dir_%s" % [hero_class, tier, dir_key])
		if dtex:
			_dir_textures[dir_key] = dtex

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
