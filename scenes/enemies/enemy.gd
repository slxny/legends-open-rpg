extends CharacterBody2D

signal died(enemy: Node2D, xp_reward: int, gold_reward: int)

@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: SCBar = $HPBar
@onready var stats: StatsComponent = $StatsComponent
@onready var name_label: Label = $NameLabel

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }

var current_state: State = State.IDLE
var home_position: Vector2 = Vector2.ZERO
var target: Node2D = null

# Enemy config
var enemy_name: String = "Enemy"
var enemy_level: int = 1
var aggro_range: float = 120.0
var chase_range: float = 400.0
var attack_cooldown: float = 1.2
var xp_reward: int = 15
var gold_reward: int = 5
var drop_table: String = ""
var sprite_type: String = "goblin"
var is_mini_boss: bool = false

var _attack_timer: float = 0.0
var _is_dead: bool = false
var _shadow: Sprite2D = null
var _is_selected: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _cached_player: Node2D = null  # Cached player reference to avoid per-frame group lookups
var _cached_world_node: Node = null  # Cached world node for VFX spawning
var _base_scale: Vector2 = Vector2(1.0, 1.0)  # Resting sprite scale (1.5 for mini-bosses)
var _base_modulate: Color = Color.WHITE  # Resting sprite tint (reddish for mini-bosses)

# Outline shader for hover highlighting (shared across all enemies)
static var _outline_shader: Shader = null
static var _info_label_settings: LabelSettings = null
# Shared zoom compensation cache — computed once per frame, reused by all enemies
static var _zoom_comp_frame: int = -1
static var _zoom_comp_value: float = 1.0
var _info_label: Label = null
var _last_zoom_comp: float = -1.0  # Last applied zoom compensation (skip redundant updates)

# Distance-based sleep/wake — enemies far from the player disable physics processing
var _is_sleeping: bool = false
var _sleep_check_timer: float = 0.0
const SLEEP_DISTANCE_SQ: float = 640000.0  # 800^2 — sleep when player is >800px away
const WAKE_DISTANCE_SQ: float = 490000.0   # 700^2 — wake when player is <700px (hysteresis)
const SLEEP_CHECK_INTERVAL: float = 0.4    # Check sleep/wake ~2.5x per second
const LABEL_VISIBLE_DISTANCE_SQ: float = 22500.0  # 150^2 — show name when player is close
const ZOOM_REF := 3.0  # Reference zoom level where font sizes are calibrated

# Patrol state
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_radius: float = 150.0
var _patrol_wait_timer: float = 0.0
var _patrol_speed_factor: float = 0.65  # Patrol at 65% of move speed — more active roaming
var movement_bounds: Rect2 = Rect2()  # If has_area(), clamp position after movement

# Random alert aggro — periodic chance to notice the player at extended range
var _alert_check_timer: float = 0.0
const ALERT_CHECK_INTERVAL: float = 1.5  # Roll alert every 1.5 seconds
const ALERT_RANGE_MULTIPLIER: float = 2.0  # Alert detection at 2x normal aggro range
const ALERT_CHANCE: float = 0.3  # 30% chance per check to aggro at extended range
var _alert_range_sq: float = 0.0  # Pre-computed squared alert range

# Pre-computed squared distances to avoid sqrt in hot path
var _aggro_range_sq: float = 14400.0   # aggro_range^2
var _chase_range_sq: float = 160000.0  # chase_range^2
var _attack_range_sq: float = 1225.0   # attack_range^2
var _attack_disengage_sq: float = 2756.25  # (attack_range * 1.5)^2

# Effect proc chances (rare — 8-12% per attack depending on type)
var _effect_chance: float = 0.0  # Overall chance this unit has any effect
var _effect_type: String = ""    # "knockback", "paralyze", or "slow"

# Pre-allocated label settings for damage numbers (avoid LabelSettings.new() per hit)
static var _dmg_settings_normal: LabelSettings = null
static var _dmg_settings_crit: LabelSettings = null
# Shared damage label pool (avoids Label.new() per hit across all enemies)
static var _dmg_label_pool: Array[Label] = []
const DMG_LABEL_POOL_MAX: int = 30
# Shared drop node pool (avoids Area2D+CollisionShape2D+Sprite2D per drop)
static var _drop_pool: Array[Area2D] = []
const DROP_POOL_MAX: int = 20
# Global rat squeal cooldown — prevents overlapping squeals from swarms
static var _last_rat_squeal_msec: int = 0
const RAT_SQUEAL_INTERVAL: float = 0.8
# Multi-kill stagger — desynchronize simultaneous deaths
static var _last_global_death_msec: int = 0

# Killing blow info for death animation selection
var _last_hit_was_crit: bool = false
var _overkill_ratio: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	var tex = SpriteGenerator.get_texture(sprite_type)
	if tex:
		sprite.texture = tex
	hp_bar.visible = false
	name_label.visible = false
	# Detect mobile for font scaling
	var vp_size = get_viewport().get_visible_rect().size
	var is_mobile = GameManager.is_mobile_device()
	# Scale enemy name label for mobile — larger font, moved higher so it
	# doesn't overlap the sprite and block taps
	if is_mobile:
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.position = Vector2(-60, -78)
		name_label.size = Vector2(120, 36)
	# Initialize shared label settings once (static, shared across all enemies)
	if not _dmg_settings_normal:
		_dmg_settings_normal = LabelSettings.new()
		_dmg_settings_normal.font_size = 40 if is_mobile else 14
		_dmg_settings_normal.font_color = Color.WHITE
		_dmg_settings_normal.outline_size = 4 if is_mobile else 2
		_dmg_settings_normal.outline_color = Color.BLACK
	if not _dmg_settings_crit:
		_dmg_settings_crit = LabelSettings.new()
		_dmg_settings_crit.font_size = 56 if is_mobile else 28
		_dmg_settings_crit.font_color = Color(1.0, 0.95, 0.1)
		_dmg_settings_crit.outline_size = 5 if is_mobile else 3
		_dmg_settings_crit.outline_color = Color.BLACK

	# Set pivot for zoom compensation (scale from center, not top-left)
	name_label.pivot_offset = name_label.size / 2.0
	hp_bar.pivot_offset = hp_bar.size / 2.0

	# Shadow
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)
	_shadow.move_to_front()
	move_child(_shadow, 0)

	# Enable mouse hover/click detection
	input_pickable = true
	# Outline shader (shared across all enemies, initialized once)
	if not _outline_shader:
		_outline_shader = Shader.new()
		_outline_shader.code = "shader_type canvas_item;
uniform bool enabled = false;
uniform vec4 line_color : source_color = vec4(1.0, 0.3, 0.3, 0.85);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (enabled && tex.a < 0.1) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		a += texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
		a += texture(TEXTURE, UV + vec2(ps.x, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a;
		if (a > 0.0) {
			COLOR = line_color;
		} else {
			COLOR = tex;
		}
	} else {
		COLOR = tex;
	}
}
"
	if not _info_label_settings:
		_info_label_settings = LabelSettings.new()
		_info_label_settings.font_size = 32 if is_mobile else 11
		_info_label_settings.font_color = Color(1.0, 0.6, 0.6)
		_info_label_settings.outline_size = 4 if is_mobile else 2
		_info_label_settings.outline_color = Color.BLACK
	# Outline shader is applied on-demand (hover only) to avoid per-frame shader cost
	# Connect mouse hover signals for outline
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Start with a short random idle delay before first patrol
	_patrol_wait_timer = randf_range(0.3, 1.5)

	# Stagger sleep checks so not all enemies check on the same frame
	_sleep_check_timer = randf_range(0.0, SLEEP_CHECK_INTERVAL)
	# Stagger alert checks across enemies
	_alert_check_timer = randf_range(0.0, ALERT_CHECK_INTERVAL)


func initialize(config: Dictionary) -> void:
	enemy_name = config.get("name", "Enemy")
	enemy_level = config.get("level", 1)
	aggro_range = config.get("aggro_range", 120.0)
	xp_reward = config.get("xp_reward", 15)
	gold_reward = config.get("gold_reward", 5)
	drop_table = config.get("drop_table", "")
	sprite_type = config.get("sprite_type", "goblin")
	is_mini_boss = config.get("is_mini_boss", false)

	# Use stats_level for attribute scaling (dampened when boosted above natural range)
	# while enemy_level is the display level shown to the player
	var sl = config.get("stats_level", enemy_level)
	stats.max_hp = 30 + sl * 15
	stats.current_hp = stats.max_hp
	stats.strength = 5 + sl * 2
	stats.agility = 3 + sl
	stats.intelligence = 2 + sl
	stats.armor = sl
	stats.attack_damage = config.get("attack_damage", 5 + sl * 3)
	stats.attack_range = config.get("attack_range", 35.0)
	stats.move_speed = config.get("move_speed", 80.0)
	stats.primary_stat = "strength"
	attack_cooldown = config.get("attack_cooldown", 1.2)

	# Scale patrol radius with move speed — faster enemies roam much further
	_patrol_radius = 300.0 + stats.move_speed * 3.0
	if is_mini_boss:
		# Minibosses roam much wider — aggressive territorial patrol
		_patrol_radius = 1200.0 + stats.move_speed * 5.0
		_patrol_speed_factor = 0.85  # Minibosses patrol faster (85% vs 65%)
	chase_range = _patrol_radius + 350.0

	# Pre-compute squared distances (avoids sqrt every frame in hot path)
	_aggro_range_sq = aggro_range * aggro_range
	_chase_range_sq = chase_range * chase_range
	_attack_range_sq = stats.attack_range * stats.attack_range
	var disengage = stats.attack_range * 1.8
	_attack_disengage_sq = disengage * disengage
	var alert_range = aggro_range * ALERT_RANGE_MULTIPLIER
	_alert_range_sq = alert_range * alert_range

	# Rats always have bleeding at 2% per hit
	if sprite_type == "rat":
		_effect_type = "bleeding"
		_effect_chance = 0.02
	# Other enemies: randomly assign an effect (~25% of enemies have an effect proc)
	elif randf() < 0.25:
		const EFFECT_TYPES = ["knockback", "paralyze", "slow"]
		_effect_type = EFFECT_TYPES[randi() % EFFECT_TYPES.size()]
		match _effect_type:
			"knockback":
				_effect_chance = 0.12  # 12% per hit
			"paralyze":
				_effect_chance = 0.08  # 8% per hit — rarer, strong
			"slow":
				_effect_chance = 0.10  # 10% per hit

	if is_inside_tree():
		var tex = SpriteGenerator.get_texture(sprite_type)
		if tex:
			sprite.texture = tex
		name_label.text = "%s Lv%d" % [enemy_name, enemy_level]
		_update_hp_bar()

func show_selection() -> void:
	_is_selected = true
	hp_bar.visible = true
	name_label.visible = true

func hide_selection() -> void:
	_is_selected = false
	if stats.current_hp >= stats.max_hp and current_state == State.IDLE:
		hp_bar.visible = false
		name_label.visible = false

func _on_mouse_entered() -> void:
	if not _is_dead and sprite and _outline_shader:
		if not sprite.material:
			var mat = ShaderMaterial.new()
			mat.shader = _outline_shader
			mat.set_shader_parameter("line_color", Color(1.0, 0.3, 0.3, 0.85))
			sprite.material = mat
		sprite.material.set_shader_parameter("enabled", true)

func _on_mouse_exited() -> void:
	if sprite:
		sprite.material = null

func show_info() -> void:
	if _is_dead:
		return
	# Show name + HP bar
	show_selection()
	# Remove existing info label if any
	if _info_label and is_instance_valid(_info_label):
		_info_label.queue_free()
	_info_label = Label.new()
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_parts: Array[String] = []
	info_parts.append("HP %d/%d  ATK %d  ARM %d" % [stats.current_hp, stats.max_hp, stats.attack_damage, stats.armor])
	if _effect_type != "":
		info_parts.append("Effect: %s" % _effect_type.capitalize())
	_info_label.text = "\n".join(info_parts)
	_info_label.label_settings = _info_label_settings
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(-55, -58)
	var _zc = _get_zoom_compensation()
	_info_label.scale = Vector2(_zc, _zc)
	add_child(_info_label)
	# Fade out after a moment
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_info_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if _info_label and is_instance_valid(_info_label):
			_info_label.queue_free()
			_info_label = null
		hide_selection()
	)

func _get_zoom_compensation() -> float:
	var frame = Engine.get_process_frames()
	if _zoom_comp_frame == frame:
		return _zoom_comp_value
	_zoom_comp_frame = frame
	var cam = get_viewport().get_camera_2d()
	if cam:
		_zoom_comp_value = ZOOM_REF / cam.zoom.x
	else:
		_zoom_comp_value = 1.0
	return _zoom_comp_value

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Distance-based sleep/wake check (throttled) — only for awake enemies.
	# Sleeping enemies have physics_process disabled; creep_camp handles their wake check.
	_sleep_check_timer -= delta
	if _sleep_check_timer <= 0.0:
		_sleep_check_timer = SLEEP_CHECK_INTERVAL
		_update_sleep_state()

	# Apply knockback impulse — overrides state machine until it decays
	if _knockback_velocity.length_squared() > 4.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)
		move_and_slide()
		return
	# After knockback ends, if we were fighting, extend chase range so we don't
	# immediately deaggro just because knockback pushed us far from home
	if _knockback_velocity != Vector2.ZERO and (current_state == State.CHASE or current_state == State.ATTACK):
		var dist_sq_from_home = global_position.distance_squared_to(home_position)
		if dist_sq_from_home > _chase_range_sq * 0.8:
			_chase_range_sq = dist_sq_from_home + _aggro_range_sq
	_knockback_velocity = Vector2.ZERO

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RETURN:
			_process_return(delta)

	# Clamp position to movement bounds (dungeon walls etc.)
	if movement_bounds.has_area():
		global_position = global_position.clamp(movement_bounds.position, movement_bounds.end)

	# Zoom-compensate in-world labels so text stays readable at all zoom levels
	# Only update when zoom actually changed (avoids redundant property sets)
	if name_label.visible or hp_bar.visible:
		var _zc = _get_zoom_compensation()
		if absf(_zc - _last_zoom_comp) > 0.001:
			_last_zoom_comp = _zc
			var _zs = Vector2(_zc, _zc)
			if name_label.visible:
				name_label.scale = _zs
			if hp_bar.visible:
				hp_bar.scale = _zs
			if _info_label and is_instance_valid(_info_label):
				_info_label.scale = _zs

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	# Check for player aggro (squared distance avoids sqrt)
	var player = _get_player()
	if player:
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return
		# Random alert: chance to notice the player at extended range
		if _try_alert_aggro(delta, player, dist_sq):
			return

	# Count down idle pause, then pick a patrol waypoint
	_patrol_wait_timer -= delta
	if _patrol_wait_timer <= 0:
		_pick_patrol_target()
		current_state = State.PATROL

func _pick_patrol_target() -> void:
	# Choose a random point within patrol radius of home
	var angle = randf() * TAU
	var dist = randf_range(_patrol_radius * 0.3, _patrol_radius)
	_patrol_target = home_position + Vector2(cos(angle), sin(angle)) * dist
	# Minibosses avoid town center — re-roll if target is too close to origin
	if is_mini_boss:
		for _i in range(3):
			if _patrol_target.length() < 900.0:
				angle = randf() * TAU
				dist = randf_range(_patrol_radius * 0.3, _patrol_radius)
				_patrol_target = home_position + Vector2(cos(angle), sin(angle)) * dist
			else:
				break

func _try_alert_aggro(delta: float, player: Node2D, dist_sq: float) -> bool:
	# Periodic random chance to detect the player at extended range (2x aggro range).
	# Creates unpredictable aggression — enemies sometimes notice you from further away.
	_alert_check_timer -= delta
	if _alert_check_timer > 0.0:
		return false
	_alert_check_timer = ALERT_CHECK_INTERVAL
	if dist_sq < _alert_range_sq and randf() < ALERT_CHANCE:
		target = player
		current_state = State.CHASE
		name_label.visible = true
		return true
	return false

func _process_patrol(delta: float) -> void:
	# Check for player aggro even while patrolling (squared distance avoids sqrt)
	var player = _get_player()
	if player:
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return
		# Random alert: chance to notice the player at extended range
		if _try_alert_aggro(delta, player, dist_sq):
			return

	var dist_sq_to_target = global_position.distance_squared_to(_patrol_target)
	if dist_sq_to_target < 64.0:  # 8^2
		# Reached patrol waypoint — short pause then go idle
		velocity = Vector2.ZERO
		current_state = State.IDLE
		# Minibosses idle briefly — restless, always on the move
		_patrol_wait_timer = randf_range(0.2, 0.8) if is_mini_boss else randf_range(0.5, 2.0)
		return

	var dir = (_patrol_target - global_position).normalized()
	velocity = dir * stats.move_speed * _patrol_speed_factor
	# Flip sprite based on movement direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

var _cached_sep_push: Vector2 = Vector2.ZERO
var _sep_push_skip: int = 0  # Skip counter — recompute every 3rd frame

func _get_separation_push(in_attack: bool = false) -> Vector2:
	# Throttle: recompute every 3 physics frames, reuse cache otherwise
	_sep_push_skip += 1
	if _sep_push_skip < 3:
		return _cached_sep_push
	_sep_push_skip = 0
	# Proximity-based soft separation — enemies repel each other without hard collisions
	# Optimized: only check camp-mates (parent's children) instead of all enemies globally
	var push = Vector2.ZERO
	var pos = global_position
	var check_radius: float = 30.0
	var check_radius_sq: float = check_radius * check_radius
	var parent = get_parent()
	if not parent:
		_cached_sep_push = push
		return push
	for other in parent.get_children():
		if other == self:
			continue
		if not other.is_in_group("enemies") or other._is_dead:
			continue
		var diff = pos - other.global_position
		var dist_sq = diff.length_squared()
		if dist_sq < check_radius_sq and dist_sq > 0.1:
			# Push strength falls off with distance; direction from diff/dist_sq
			# is slightly biased toward closer enemies (intentional — stronger repel)
			var strength = (1.0 - dist_sq / check_radius_sq) * 150.0
			push += diff * (strength / check_radius)
	# Push away from the player to prevent piling on top of them
	if is_instance_valid(target):
		var player_diff = pos - target.global_position
		var player_dist_sq = player_diff.length_squared()
		var player_push_radius_sq: float = 900.0  # 30.0 * 30.0
		if player_dist_sq < player_push_radius_sq and player_dist_sq > 0.1:
			var strength = (1.0 - player_dist_sq / player_push_radius_sq) * 200.0
			push += player_diff * (strength / 30.0)
	# Softer cap during attack so combat positioning isn't disrupted
	var max_push = 70.0 if in_attack else 120.0
	var max_push_sq = max_push * max_push
	var push_len_sq = push.length_squared()
	if push_len_sq > max_push_sq:
		push *= max_push / sqrt(push_len_sq)  # Only sqrt when actually clamping
	_cached_sep_push = push
	return push

func _process_chase(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	var dist_sq_to_target = global_position.distance_squared_to(target.global_position)
	var dist_sq_from_home = global_position.distance_squared_to(home_position)

	if dist_sq_from_home > _chase_range_sq:
		current_state = State.RETURN
		target = null
		return

	if dist_sq_to_target <= _attack_range_sq:
		current_state = State.ATTACK
		return

	# Keep attack timer ticking while chasing so enemies pushed out of attack
	# range by sibling separation don't lose all their attack progress
	if _attack_timer > 0.0:
		_attack_timer -= delta * 0.5  # Tick at half rate while closing in

	var dir = (target.global_position - global_position).normalized()
	velocity = dir * stats.move_speed + _get_separation_push()
	# Flip sprite based on movement direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

func _process_attack(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	var dist_sq = global_position.distance_squared_to(target.global_position)
	if dist_sq > _attack_disengage_sq:
		current_state = State.CHASE
		return

	# Face the target
	var to_target = target.global_position - global_position
	if to_target.x < -0.1:
		sprite.flip_h = true
	elif to_target.x > 0.1:
		sprite.flip_h = false

	# Keep enemies spread apart and maintain comfortable combat distance
	var sep = _get_separation_push(true)
	var to_target_dist_sq = to_target.length_squared()
	var ideal_dist = stats.attack_range * 0.85
	var ideal_dist_sq = ideal_dist * ideal_dist
	var move_toward = Vector2.ZERO
	if to_target_dist_sq > 0.01:
		var ideal_plus_5_sq = (ideal_dist + 5.0) * (ideal_dist + 5.0)
		# Only compute sqrt when we actually need to adjust position
		if to_target_dist_sq < ideal_dist_sq or to_target_dist_sq > ideal_plus_5_sq:
			var dist = sqrt(to_target_dist_sq)
			var dir_to_target = to_target / dist  # normalized without second sqrt
			if dist < ideal_dist:
				move_toward = -dir_to_target * stats.move_speed * 0.15
			else:
				var urgency = clampf((dist - ideal_dist) / (stats.attack_range * 0.5), 0.1, 0.3)
				move_toward = dir_to_target * stats.move_speed * urgency
			var perp = Vector2(-dir_to_target.y, dir_to_target.x)
			sep = perp * sep.dot(perp)
		else:
			# In ideal range — just project separation perpendicular
			var inv_dist = 1.0 / sqrt(to_target_dist_sq)
			var dir_to_target = to_target * inv_dist
			var perp = Vector2(-dir_to_target.y, dir_to_target.x)
			sep = perp * sep.dot(perp)

	velocity = move_toward + sep
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		# Only deal damage if still close enough to actually hit
		var hit_range_sq = stats.attack_range * stats.attack_range * 2.25  # 1.5x range
		if dist_sq <= hit_range_sq and target.has_method("take_damage"):
			# Roll for special attack (15% chance, type-specific)
			var is_special = randf() < 0.15
			var dmg_mult = 1.0
			if is_special:
				dmg_mult = _get_special_attack_mult()
				_attack_timer = attack_cooldown * 1.3  # Slightly longer recovery after special
			var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict(), dmg_mult)
			target.take_damage(result["damage"], result["is_crit"])
			_do_attack_lunge(is_special)
			if sprite_type == "rat" and randf() < 0.3:
				_try_rat_squeal()
			# Rare effect proc
			if _effect_chance > 0.0 and randf() < _effect_chance:
				_apply_effect_to_target(target)

func _try_rat_squeal() -> void:
	var now_msec = Time.get_ticks_msec()
	if now_msec - _last_rat_squeal_msec < int(RAT_SQUEAL_INTERVAL * 1000.0):
		return
	_last_rat_squeal_msec = now_msec
	var variant = randi_range(1, 3)
	AudioManager.play_sfx("rat_squeal_%d" % variant, -8.0)

func _process_return(delta: float) -> void:
	var dist_sq = global_position.distance_squared_to(home_position)
	if dist_sq < 25.0:  # 5^2
		velocity = Vector2.ZERO
		current_state = State.IDLE
		stats.current_hp = stats.max_hp
		_update_hp_bar()
		_patrol_wait_timer = randf_range(0.3, 1.0)
		if not _is_selected:
			name_label.visible = false
		return

	# Re-aggro if player walks into aggro range while returning
	var player = _get_player()
	if player:
		var dist_sq_to_player = global_position.distance_squared_to(player.global_position)
		if dist_sq_to_player < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return

	var dir = (home_position - global_position).normalized()
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	velocity = dir * stats.move_speed * 1.8
	move_and_slide()

func _apply_effect_to_target(t: Node2D) -> void:
	if not is_instance_valid(t):
		return
	match _effect_type:
		"knockback":
			if t.has_method("apply_knockback_effect"):
				var dir = (t.global_position - global_position).normalized()
				t.apply_knockback_effect(dir, 280.0)
		"paralyze":
			if t.has_method("apply_effect"):
				t.apply_effect("paralyze", 2.0)
		"slow":
			if t.has_method("apply_effect"):
				t.apply_effect("slow", 3.0)
		"bleeding":
			if t.has_method("apply_effect"):
				t.apply_effect("bleeding", 5.0, 2.0)  # 5s duration, 2 dmg per tick

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return
	# Force wake if sleeping (player somehow hit us at range)
	if _is_sleeping:
		_is_sleeping = false
		visible = true
	_last_hit_was_crit = is_crit
	var hp_before = stats.current_hp
	stats.take_damage(amount)
	_update_hp_bar()
	hp_bar.visible = true
	name_label.visible = true
	_spawn_damage_number(amount, is_crit)
	_do_hit_flash()
	if is_crit:
		AudioManager.play_sfx("crit_hit")
	else:
		AudioManager.play_sfx("hit_impact", -2.0)

	if stats.current_hp <= 0:
		_overkill_ratio = float(amount - hp_before) / float(max(stats.max_hp, 1))
		_die()
	elif current_state == State.IDLE or current_state == State.PATROL or current_state == State.RETURN:
		var player = _get_player()
		if player:
			target = player
			current_state = State.CHASE

func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	if sprite:
		sprite.material = null
	var death_sfx = "death_" + sprite_type
	if AudioManager.get_sfx(death_sfx):
		AudioManager.play_sfx(death_sfx, -3.0)
	else:
		AudioManager.play_sfx("enemy_death", -3.0)
	died.emit(self, xp_reward, gold_reward)
	_spawn_gold_drop(gold_reward)
	if not drop_table.is_empty():
		var item = ItemData.roll_item_drop(drop_table)
		if not item.is_empty():
			_spawn_item_drop_dict(item)
	hp_bar.visible = false
	name_label.visible = false
	if _shadow:
		_shadow.visible = false

	# Multi-kill stagger: if another enemy died within 150ms, delay this death anim
	var now_msec = Time.get_ticks_msec()
	var stagger_delay = 0.0
	if now_msec - _last_global_death_msec < 150:
		stagger_delay = randf_range(0.03, 0.1)
	_last_global_death_msec = now_msec

	if stagger_delay > 0.0:
		get_tree().create_timer(stagger_delay).timeout.connect(_play_death_animation)
	else:
		_play_death_animation()

func _play_death_animation() -> void:
	if sprite_type == "skeleton":
		_die_crumble()
	elif sprite_type == "rat":
		_die_rat_select_variant()
	elif sprite_type == "tree_god_elk":
		_die_elk_collapse()
	elif is_mini_boss:
		_spawn_blood_splatter()
		_die_boss()
	else:
		_die_default_select_variant()

func _die_default_select_variant() -> void:
	_spawn_blood_splatter()
	if _last_hit_was_crit or _overkill_ratio > 0.5:
		_die_default_crit()
	elif randf() < 0.3:
		_die_default_knockback()
	else:
		_die_default()

func _die_default() -> void:
	# Normal: pop, fall & rotate 85°, fade
	var base_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -6), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.05)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "rotation", deg_to_rad(85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 10), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_default_crit() -> void:
	# Critical: bright white flash, bigger rotation (120°), faster fall, scatter fragments
	_spawn_death_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Bright white flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.05)
	# Fast fall with big rotation
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(sprite, "rotation", deg_to_rad(120), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 12), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.25)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_default_knockback() -> void:
	# Knockback: slide backward 15-25px from player before falling
	var player = _get_player()
	var slide_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		slide_dir = (global_position - player.global_position).normalized()
	var slide_dist = randf_range(15, 25)
	var base_pos = sprite.position
	var slide_dest = base_pos + slide_dir * slide_dist
	var tween = create_tween()
	# Slide backward
	tween.tween_property(sprite, "position", slide_dest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Then fall and fade (same as normal but from slid position)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "rotation", deg_to_rad(85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", slide_dest + Vector2(0, 10), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _spawn_death_fragments() -> void:
	# Small fragments that scatter on critical kills
	var gib_tex = SpriteGenerator.get_texture("rat_gib")  # Reuse gib texture as generic fragment
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(3, 5)):
		var frag = Sprite2D.new()
		frag.texture = gib_tex
		frag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frag.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		frag.rotation = randf() * TAU
		frag.scale = Vector2(randf_range(0.4, 0.8), randf_range(0.4, 0.8))
		frag.z_index = -1
		frag.modulate = Color(
			randf_range(0.7, 1.0),
			randf_range(0.5, 0.8),
			randf_range(0.5, 0.8),
			randf_range(0.7, 1.0)
		)
		world.add_child(frag)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = frag.global_position + dir * randf_range(12, 30)
		var t = frag.create_tween()
		t.set_parallel(true)
		t.tween_property(frag, "global_position", dest, randf_range(0.2, 0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(frag, "rotation", frag.rotation + randf_range(-4.0, 4.0), 0.35)
		t.set_parallel(false)
		t.tween_interval(randf_range(0.8, 1.5))
		t.tween_property(frag, "modulate:a", 0.0, 0.5)
		t.tween_callback(frag.queue_free)

func _die_crumble() -> void:
	# Skeleton crumble: shake, squash down, scatter bone fragments
	_spawn_bone_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Rapid shake (3 oscillations)
	for i in range(3):
		var offset = Vector2(randf_range(-3, 3), 0)
		tween.tween_property(sprite, "position", base_pos + offset, 0.03)
	# Squash down — skeleton collapses into a pile
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Fade the flattened remains
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _die_rat_select_variant() -> void:
	if _last_hit_was_crit or _overkill_ratio > 0.5:
		_die_rat_crit_explode()
	else:
		var roll = randf()
		if roll < 0.5:
			_die_rat_explode()
		elif roll < 0.75:
			_die_rat_fling()
		else:
			_die_rat_squish()

func _die_rat_explode() -> void:
	# Normal pop: quick swell, pop flash, gibs scatter
	_spawn_rat_gibs()
	_spawn_blood_splatter()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", _base_scale * 1.4, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.7, 0.7), 0.04)
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.8), 0.02)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 1.8, _base_scale.y * 0.3), 0.02)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.03)
	tween.tween_callback(queue_free)

func _die_rat_crit_explode() -> void:
	# Critical/overkill: more gibs, wider scatter, bright white flash, bigger pop
	_spawn_rat_gibs_crit()
	for _i in range(randi_range(2, 3)):
		_spawn_blood_splatter()
	var tween = create_tween()
	# Bright white flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 2.2, 0.05)
	# POP — explode outward
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.8), 0.02)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 2.5, _base_scale.y * 0.2), 0.02)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.03)
	tween.tween_callback(queue_free)

func _die_rat_fling() -> void:
	# Fling: rat launches sideways, spins, shrinks, fades
	_spawn_blood_splatter()
	var player = _get_player()
	var fling_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		fling_dir = (global_position - player.global_position).normalized()
	var fling_dist = randf_range(30, 50)
	var dest = sprite.position + fling_dir * fling_dist
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", TAU * 2.0 * sign(fling_dir.x + 0.01), 0.35)
	tween.tween_property(sprite, "scale", _base_scale * 0.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_rat_squish() -> void:
	# Squish: rat flattens with a comic pop, then fades
	_spawn_blood_splatter()
	var tween = create_tween()
	# Squash flat
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.8, _base_scale.y * 0.1), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, 4), 0.08)
	# Brief hold, then fade
	tween.tween_interval(0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _spawn_rat_gibs() -> void:
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(3, 5)):
		var gib = Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gib.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-6, 2))
		gib.rotation = randf() * TAU
		gib.scale = Vector2(randf_range(0.6, 1.2), randf_range(0.6, 1.2))
		gib.z_index = -1
		gib.modulate = Color(
			randf_range(0.8, 1.2),
			randf_range(0.6, 0.9),
			randf_range(0.6, 0.9),
			randf_range(0.7, 1.0)
		)
		world.add_child(gib)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var force = randf_range(18, 40)
		var dest = gib.global_position + dir * force + Vector2(0, randf_range(4, 12))
		var t = gib.create_tween()
		t.set_parallel(true)
		t.tween_property(gib, "global_position", dest, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(gib, "rotation", gib.rotation + randf_range(-6.0, 6.0), 0.3)
		t.set_parallel(false)
		t.tween_interval(randf_range(1.0, 2.5))
		t.tween_property(gib, "modulate:a", 0.0, 0.6)
		t.tween_callback(gib.queue_free)

func _spawn_rat_gibs_crit() -> void:
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(5, 8)):
		var gib = Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gib.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-6, 2))
		gib.rotation = randf() * TAU
		gib.scale = Vector2(randf_range(0.6, 1.2), randf_range(0.6, 1.2))
		gib.z_index = -1
		gib.modulate = Color(
			randf_range(0.8, 1.2),
			randf_range(0.6, 0.9),
			randf_range(0.6, 0.9),
			randf_range(0.7, 1.0)
		)
		world.add_child(gib)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var force = randf_range(25, 55)
		var dest = gib.global_position + dir * force + Vector2(0, randf_range(4, 12))
		var t = gib.create_tween()
		t.set_parallel(true)
		t.tween_property(gib, "global_position", dest, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(gib, "rotation", gib.rotation + randf_range(-6.0, 6.0), 0.3)
		t.set_parallel(false)
		t.tween_interval(randf_range(1.0, 2.5))
		t.tween_property(gib, "modulate:a", 0.0, 0.6)
		t.tween_callback(gib.queue_free)

func _die_elk_collapse() -> void:
	# Nature collapse: stagger wobble, root tendrils grow outward, collapse sideways, green fade
	var base_pos = sprite.position
	var tween = create_tween()
	# Phase 1: Stagger wobble — 3 side-to-side sways, green glow fades
	tween.tween_property(sprite, "position", base_pos + Vector2(-4, 0), 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 1.2, 0.5), 0.12)
	tween.tween_property(sprite, "position", base_pos + Vector2(5, 0), 0.12)
	tween.tween_property(sprite, "position", base_pos + Vector2(-3, 0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.0, 0.4), 0.1)
	# Phase 2: Spawn root/vine tendrils growing outward
	tween.tween_callback(_spawn_elk_root_tendrils)
	# Phase 3: Collapse sideways with rotation
	tween.tween_property(sprite, "rotation", 1.2, 0.3)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(8, 6), 0.3)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.8), 0.3)
	# Phase 4: Fade to green-tinted transparent
	tween.tween_property(sprite, "modulate", Color(0.3, 0.7, 0.2, 0.0), 0.5)
	tween.tween_callback(queue_free)

func _spawn_elk_root_tendrils() -> void:
	var world = _get_world_node()
	for _i in range(randi_range(3, 4)):
		var tendril = Sprite2D.new()
		# Use vines texture as root tendril
		var tex = SpriteGenerator.get_texture("vines")
		if tex:
			tendril.texture = tex
		tendril.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tendril.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		tendril.rotation = randf() * TAU
		tendril.scale = Vector2(0.1, 0.1)
		tendril.modulate = Color(0.4, 0.7, 0.2, 0.9)
		tendril.z_index = -1
		world.add_child(tendril)
		# Grow outward
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = tendril.global_position + dir * randf_range(15, 35)
		var t = tendril.create_tween()
		t.set_parallel(true)
		t.tween_property(tendril, "global_position", dest, randf_range(0.3, 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(tendril, "scale", Vector2(randf_range(0.6, 1.0), randf_range(0.6, 1.0)), 0.4)
		t.set_parallel(false)
		# Linger then fade
		t.tween_interval(randf_range(1.5, 3.0))
		t.tween_property(tendril, "modulate:a", 0.0, 0.8)
		t.tween_callback(tendril.queue_free)

func _die_boss() -> void:
	# Dramatic mini-boss death: expand, flash bright, shake violently, explode outward
	var base_pos = sprite.position
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Flash bright and swell
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 1.4), 0.08)
	# Violent shake (6 jitters)
	for i in range(6):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.03)
	# Pulsing flash — alternate bright/dim
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.3), 0.06)
	tween.tween_property(sprite, "modulate", Color(2.5, 2.0, 1.5), 0.06)
	# Explode outward — scale up fast then shrink to nothing
	tween.tween_property(sprite, "scale", Vector2(sx * 2.0, sy * 2.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(sprite, "position", base_pos, 0.08)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.1, sy * 0.1), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func start_boss_pulse() -> void:
	# Looping idle breathing animation for mini-bosses — subtle scale + modulate pulse
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(sx * 1.06, sy * 0.96), 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "modulate", Color(_base_modulate.r * 1.1, _base_modulate.g * 0.9, _base_modulate.b * 0.9), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.96, sy * 1.06), 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.8).set_trans(Tween.TRANS_SINE)

func _spawn_bone_fragments() -> void:
	var bone_tex = SpriteGenerator.get_texture("bone_fragment")
	if not bone_tex:
		return
	var world = _get_world_node()
	for i in range(randi_range(3, 5)):
		var bone = Sprite2D.new()
		bone.texture = bone_tex
		bone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bone.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-8, 4))
		bone.rotation = randf() * TAU
		bone.z_index = -1
		world.add_child(bone)
		# Scatter outward then fade
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = bone.global_position + dir * randf_range(10, 25) + Vector2(0, randf_range(2, 8))
		var t = bone.create_tween()
		t.set_parallel(true)
		t.tween_property(bone, "global_position", dest, randf_range(0.25, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(bone, "rotation", bone.rotation + randf_range(-4.0, 4.0), 0.4)
		t.set_parallel(false)
		t.tween_interval(randf_range(0.8, 1.5))
		t.tween_property(bone, "modulate:a", 0.0, 0.5)
		t.tween_callback(bone.queue_free)

func apply_knockback(dir: Vector2, force: float) -> void:
	if _is_dead:
		return
	_knockback_velocity = dir * force

func _do_hit_flash() -> void:
	# Bright white flash + squash on hit
	sprite.modulate = Color(1.5, 1.5, 1.5)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", _base_modulate, 0.18)
	# Squash: squeeze horizontally, stretch vertically, then bounce back
	var sx = _base_scale.x
	var sy = _base_scale.y
	tween.tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 0.7), 0.05)
	tween.set_parallel(false)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.2), 0.06)
	tween.tween_property(sprite, "scale", _base_scale, 0.08)

func _get_special_attack_mult() -> float:
	# Damage multiplier for special attacks — varies by enemy type
	match sprite_type:
		"rat": return 1.15        # Frenzy bite
		"goblin": return 1.2      # Backstab
		"wolf": return 1.25       # Savage lunge
		"skeleton": return 1.2    # Overhead cleave
		"spider": return 1.3      # Venom strike
		"bandit": return 1.25     # Cross slash
		"troll": return 1.4       # Mega punch
		"dark_mage": return 1.3   # Dark blast
		"ogre": return 1.35       # Ground pound
		"tree_god_elk": return 1.3 # Antler toss
		"cave_snake": return 1.25 # Constrict
		"dungeon_bat": return 1.2 # Dive bomb
		"vampire_bat": return 1.3 # Drain bite
		"flan": return 1.25       # Body slam
		"mimic": return 1.4       # Devour
		"ghoul": return 1.3       # Rend
		"crypt_knight": return 1.35 # Shield bash
		_: return 1.2

func _do_attack_lunge(is_special: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var dir = (target.global_position - global_position).normalized()
	var base_pos = sprite.position
	if is_mini_boss:
		match sprite_type:
			"ogre_boss":
				_anim_boss_ground_slam(dir, base_pos)
			"demon_knight":
				_anim_boss_charge_slash(dir, base_pos)
			"dragon_whelp":
				_anim_boss_fire_breath(dir, base_pos)
			"infernal":
				_anim_boss_doom_strike(dir, base_pos)
			"wolf":
				_anim_boss_savage_pounce(dir, base_pos)
			"spider":
				_anim_boss_venom_barrage(dir, base_pos)
			"skeleton":
				_anim_boss_death_cleave(dir, base_pos)
			_:
				_anim_boss_ground_slam(dir, base_pos)
		return
	match sprite_type:
		"rat":
			if is_special: _anim_rat_frenzy(dir, base_pos)
			else: _anim_rat_bite(dir, base_pos)
		"goblin":
			if is_special: _anim_goblin_backstab(dir, base_pos)
			else: _anim_goblin_swing(dir, base_pos)
		"wolf":
			if is_special: _anim_wolf_savage_lunge(dir, base_pos)
			else: _anim_wolf_bite(dir, base_pos)
		"skeleton":
			if is_special: _anim_skeleton_cleave(dir, base_pos)
			else: _anim_skeleton_slash(dir, base_pos)
		"spider":
			if is_special: _anim_spider_venom(dir, base_pos)
			else: _anim_spider_fang(dir, base_pos)
		"bandit":
			if is_special: _anim_bandit_cross_slash(dir, base_pos)
			else: _anim_bandit_slash(dir, base_pos)
		"troll":
			if is_special: _anim_troll_mega_punch(dir, base_pos)
			else: _anim_troll_slam(dir, base_pos)
		"dark_mage":
			if is_special: _anim_mage_dark_blast(dir, base_pos)
			else: _anim_mage_bolt(dir, base_pos)
		"ogre":
			if is_special: _anim_ogre_ground_pound(dir, base_pos)
			else: _anim_ogre_fist(dir, base_pos)
		"tree_god_elk":
			if is_special: _anim_elk_toss(dir, base_pos)
			else: _anim_elk_charge(dir, base_pos)
		"cave_snake":
			if is_special: _anim_snake_constrict(dir, base_pos)
			else: _anim_snake_strike(dir, base_pos)
		"dungeon_bat":
			if is_special: _anim_bat_divebomb(dir, base_pos)
			else: _anim_bat_swoop(dir, base_pos)
		"vampire_bat":
			if is_special: _anim_vbat_drain(dir, base_pos)
			else: _anim_bat_swoop(dir, base_pos)
		"flan":
			if is_special: _anim_flan_bodyslam(dir, base_pos)
			else: _anim_flan_bounce(dir, base_pos)
		"mimic":
			if is_special: _anim_mimic_devour(dir, base_pos)
			else: _anim_mimic_chomp(dir, base_pos)
		"ghoul":
			if is_special: _anim_ghoul_rend(dir, base_pos)
			else: _anim_ghoul_claw(dir, base_pos)
		"crypt_knight":
			if is_special: _anim_cknight_bash(dir, base_pos)
			else: _anim_cknight_swing(dir, base_pos)
		_:
			_anim_generic_lunge(dir, base_pos)

# ============================================================
# NORMAL ATTACK ANIMATIONS
# ============================================================

func _anim_rat_bite(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.7), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.04)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.8, 0.8))
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.03)
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_goblin_swing(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -3), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.9))
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 2), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.07)

func _anim_wolf_bite(dir: Vector2, base_pos: Vector2) -> void:
	# Wolf lunges with jaws open, snaps shut — fast predator bite
	var tween = create_tween()
	# Crouch low — coiling muscles
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.06)
	# Pounce forward — jaws open (stretch long and thin)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, -2), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.75, 1.25), 0.05)
	# Jaws snap shut — quick squash on contact
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.9, 0.8))
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.03)
	# Head shake — wolf shakes prey side to side
	var perp = Vector2(-dir.y, dir.x)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + perp * 3.0, 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 - perp * 3.0, 0.04)
	# Release and hop back
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_skeleton_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Rattling sword swing — jerky, mechanical, bones clatter
	var tween = create_tween()
	# Raise sword — stiff pull-up
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -4), 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.07)
	# Slash across — diagonal sweep with rotation
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.2, 1.0))
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.2, 0.05)
	# Clatter on follow-through — tiny jitter
	tween.tween_property(sprite, "position", base_pos + dir * 9.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.03)
	# Return stiffly
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_spider_fang(dir: Vector2, base_pos: Vector2) -> void:
	# Quick scuttle forward, fangs stab down, skitter back
	var tween = create_tween()
	# Scuttle forward — low and wide
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.04)
	# Fangs strike down — vertical stab motion
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 3), 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.03)
	tween.tween_callback(func(): sprite.modulate = Color(0.9, 1.2, 0.8))
	# Pull fangs out with tiny hop
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -2), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.04)
	# Skitter backwards
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.04)

func _anim_bandit_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Quick sword slash — step in, cut diagonally, step back
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# Step forward into stance
	tween.tween_property(sprite, "position", base_pos + dir * 4.0 + perp * 2.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.05)
	# Slash diagonally across — rotation for sword arc
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.0, 0.9))
	tween.tween_property(sprite, "position", base_pos + dir * 11.0 - perp * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.04)
	tween.parallel().tween_property(sprite, "rotation", -dir.angle() * 0.2, 0.04)
	# Quick recovery — bandits are nimble
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.06)

func _anim_troll_slam(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, -6), 0.25)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.8, 1.3), 0.25)
	tween.tween_interval(0.12)
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 1.0, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(0, 4), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.35, 0.7), 0.1)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.2, 0.1)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 4), 0.06)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-2, 2), 4), 0.06)
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 6.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.95), 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)

func _anim_mage_bolt(dir: Vector2, base_pos: Vector2) -> void:
	# Staff thrust — lean back gathering energy, thrust forward with purple flash
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Gather energy — lean back, purple glow
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.9, 0.6, 1.3) * base_mod, 0.1)
	# Thrust staff forward — bolt release
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.8, 1.4) * base_mod, 0.05)
	# Recoil — magic pushback
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.97), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.08)

func _anim_ogre_fist(dir: Vector2, base_pos: Vector2) -> void:
	# Massive fist slam — wind up overhead, smash down
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Rear up — raise fist high
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -8), 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.85, 1.25), 0.15)
	# Smash down — heavy squash
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.3, 0.75), 0.08)
	# Impact shake
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(randf_range(-2, 2), 4), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 3), 0.04)
	# Lumber back
	tween.tween_property(sprite, "modulate", base_mod, 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.97), 0.15)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.15)
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)

func _anim_elk_charge(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.85, 1.3), 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 1.2, 0.7) * base_mod, 0.2)
	tween.tween_interval(0.1)
	tween.tween_callback(func(): sprite.modulate = Color(1.1, 1.3, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, 3), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.3, 0.75), 0.1)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.1)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, -5), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.9, 1.15), 0.08)
	tween.parallel().tween_property(sprite, "rotation", -0.15, 0.08)
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 5.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.95), 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.15)

func _anim_snake_strike(dir: Vector2, base_pos: Vector2) -> void:
	# Coil and lightning-fast strike — serpentine motion
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# S-curve coil back
	tween.tween_property(sprite, "position", base_pos - dir * 5.0 + perp * 2.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	# Lightning strike forward
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.03)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.8))
	# Quick retract
	tween.tween_property(sprite, "position", base_pos + dir * 4.0 - perp * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_bat_swoop(dir: Vector2, base_pos: Vector2) -> void:
	# Dive-swoop — arc down from above, claw at target, fly back up
	var tween = create_tween()
	# Rise up — wings spread
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.05)
	# Dive down toward target
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 4), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.04)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 0.9, 0.9))
	# Pull up from dive
	tween.tween_property(sprite, "position", base_pos + dir * 6.0 + Vector2(0, -4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.05)
	# Settle back
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)

func _anim_flan_bounce(dir: Vector2, base_pos: Vector2) -> void:
	# Gelatinous bounce — compress, spring up, slam down on target
	var tween = create_tween()
	# Compress flat — storing energy
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.1)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 3), 0.05)
	# Spring up and forward
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -6), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06)
	# Splat down on target
	tween.tween_callback(func(): sprite.modulate = Color(1.1, 1.2, 0.8))
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 2), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.04)
	# Jelly wobble recovery
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _anim_mimic_chomp(dir: Vector2, base_pos: Vector2) -> void:
	# Chest lid opens wide, snaps shut — terrifying surprise attack
	var tween = create_tween()
	# Lid opens — stretch tall (mouth opening)
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.08)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -3), 0.08)
	# Lunge forward with jaws wide
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.1), 0.05)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.8, 0.8))
	# CHOMP shut — fast squash
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.03)
	# Jaw clatter
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.04)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.04)
	# Settle back
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_ghoul_claw(dir: Vector2, base_pos: Vector2) -> void:
	# Shambling claw swipe — lurching forward, raking claws
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Lurch forward
	tween.tween_property(sprite, "position", base_pos + dir * 5.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.08)
	# Claw swipe across — diagonal motion
	tween.tween_callback(func(): sprite.modulate = Color(0.8, 1.1, 0.7) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.15, 0.04)
	# Second rake in opposite direction
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 4.0, 0.05)
	tween.parallel().tween_property(sprite, "rotation", -0.15, 0.05)
	# Stumble back
	tween.tween_property(sprite, "position", base_pos + dir * 3.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.07)

func _anim_cknight_swing(dir: Vector2, base_pos: Vector2) -> void:
	# Armored sword swing — deliberate, powerful, heavy follow-through
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Raise weapon — steady wind-up
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -5), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.1)
	# Heavy downward slash
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 1.0) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.06)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.06)
	# Impact hold — heavy weapon plants
	tween.tween_interval(0.04)
	# Methodical recovery
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.08)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.08)
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)

func _anim_generic_lunge(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

# ============================================================
# SPECIAL ATTACK ANIMATIONS (15% chance, bonus damage)
# ============================================================

func _anim_rat_frenzy(dir: Vector2, base_pos: Vector2) -> void:
	# Frenzy bite — rapid triple chomp
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.7, 0.7))
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 11.0, 0.03)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.03)
		tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.03)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.03)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_goblin_backstab(dir: Vector2, base_pos: Vector2) -> void:
	# Sneaky backstab — dodge to side, stab from flank
	var perp = Vector2(-dir.y, dir.x)
	var side = perp if randf() > 0.5 else -perp
	var tween = create_tween()
	# Sidestep
	tween.tween_property(sprite, "position", base_pos + side * 8.0 - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.1), 0.06)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.6))
	# Stab from flank
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.75, 1.25), 0.04)
	# Twist
	tween.tween_property(sprite, "rotation", 0.3, 0.03)
	tween.tween_property(sprite, "rotation", 0.0, 0.04)
	# Hop back
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)

func _anim_wolf_savage_lunge(dir: Vector2, base_pos: Vector2) -> void:
	# Savage lunge — bigger leap, more violent head shake
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.8, 0.7))
	# Deep crouch
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.08)
	# Massive pounce
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, -4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.05)
	# Violent shake — 4 rapid side-to-side
	for i in range(4):
		var s = perp * 4.0 if i % 2 == 0 else -perp * 4.0
		tween.tween_property(sprite, "position", base_pos + dir * 16.0 + s, 0.025)
	# Release with snarl
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_skeleton_cleave(dir: Vector2, base_pos: Vector2) -> void:
	# Overhead two-handed cleave — dramatic raise, pause, slam
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.2, 0.8))
	# Raise high
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -8), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.35), 0.12)
	# Menacing pause
	tween.tween_interval(0.06)
	# Crushing downward cleave
	tween.tween_property(sprite, "position", base_pos + dir * 13.0 + Vector2(0, 4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.25, 0.05)
	# Bone rattle impact
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 13.0 + Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _anim_spider_venom(dir: Vector2, base_pos: Vector2) -> void:
	# Venom strike — rear up, stab with glowing green fangs
	var tween = create_tween()
	# Rear up threateningly
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -5), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 1.4, 0.5), 0.08)
	# Rapid venom stab
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 4), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.04)
	# Hold — injecting venom
	tween.tween_interval(0.06)
	# Retract with green trail
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_bandit_cross_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Cross slash — two rapid diagonal cuts forming an X
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.7))
	# First diagonal slash
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.3, 0.04)
	# Second diagonal — opposite direction
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", -0.3, 0.04)
	# Center hit
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.03)
	# Quick escape back
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.95, 1.05), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_troll_mega_punch(dir: Vector2, base_pos: Vector2) -> void:
	# MEGA PUNCH — troll drops club, winds up massive fist, devastating haymaker
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Roar and rear way back — charging fist
	tween.tween_callback(func(): sprite.modulate = Color(1.5, 0.8, 0.6) * base_mod)
	tween.tween_property(sprite, "position", base_pos - dir * 10.0 + Vector2(0, -4), 0.3)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.75, 1.35), 0.3)
	# Menacing pause — fist cocked back
	tween.tween_interval(0.15)
	# MASSIVE forward haymaker — explosive
	tween.tween_property(sprite, "position", base_pos + dir * 22.0 + Vector2(0, 5), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.5, 0.6), 0.08)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.25, 0.08)
	# Devastating impact — heavy shake
	for i in range(4):
		var jitter = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", base_pos + dir * 20.0 + jitter + Vector2(0, 5), 0.03)
	# Very slow recovery — exhausted
	tween.tween_property(sprite, "modulate", base_mod, 0.2)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 8.0, 0.25)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.95), 0.25)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.25)
	tween.tween_property(sprite, "position", base_pos, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)

func _anim_mage_dark_blast(dir: Vector2, base_pos: Vector2) -> void:
	# Dark blast — gather dark energy, release explosive burst
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Gather — pull inward, dark purple glow intensifies
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -3), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.3, 1.0) * base_mod, 0.12)
	# Pulse — energy overload
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.5, 1.5) * base_mod, 0.06)
	# Release — blast forward
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.04)
	# Recoil from blast
	tween.tween_property(sprite, "position", base_pos - dir * 5.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.06)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.1)

func _anim_ogre_ground_pound(dir: Vector2, base_pos: Vector2) -> void:
	# Ground pound — both fists overhead, massive slam, earth shakes
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.9, 0.7) * base_mod)
	# Rise up high — both fists raised
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -12), 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.75, 1.4), 0.2)
	# Hang at apex
	tween.tween_interval(0.1)
	# SLAM down — massive impact
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, 6), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.5, 0.6), 0.06)
	# Ground shake — heavy tremor
	for i in range(5):
		var jitter = Vector2(randf_range(-3, 3), randf_range(-1, 2))
		tween.tween_property(sprite, "position", base_pos + dir * 7.0 + jitter + Vector2(0, 6), 0.025)
	# Slow heavy recovery
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 3.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.97), 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.15)

func _anim_elk_toss(dir: Vector2, base_pos: Vector2) -> void:
	# Antler toss — charges in, flicks head up violently to throw target
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(0.7, 1.4, 0.5) * base_mod)
	# Lower head — aiming antlers
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, 4), 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.2, 0.8), 0.15)
	# Explosive charge
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.9, 1.0), 0.08)
	# Violent upward toss — flick head skyward
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, -10), 0.06)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.8, 1.35), 0.06)
	tween.parallel().tween_property(sprite, "rotation", -0.3, 0.06)
	# Settle back with majesty
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.12)

func _anim_snake_constrict(dir: Vector2, base_pos: Vector2) -> void:
	# Constrict — wraps around target, squeezes, releases
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.1, 0.7))
	# Lunge to target
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.04)
	# Wrap — circle around (3 positions)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + perp * 5.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 5.0, 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 9.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.04)
	# Squeeze pulse
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.04)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.04)
	# Release and slither back
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_bat_divebomb(dir: Vector2, base_pos: Vector2) -> void:
	# Dive bomb — fly high, plummet down at speed
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.7, 0.7))
	# Fly up high
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -14), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.08)
	# Brief hover
	tween.tween_interval(0.04)
	# Dive bomb — fast straight down at target
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 5), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.04)
	# Bounce off impact
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -6), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	# Flutter back
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)

func _anim_vbat_drain(dir: Vector2, base_pos: Vector2) -> void:
	# Drain bite — latch on, pulse red as draining, release
	var tween = create_tween()
	# Swoop in
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05)
	# Latch — pressed against target
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	# Drain pulses — red glow intensifies
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.08)
	tween.tween_property(sprite, "modulate", Color(1.8, 0.3, 0.3), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.08)
	# Release — satisfied, hop back
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -4), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_flan_bodyslam(dir: Vector2, base_pos: Vector2) -> void:
	# Body slam — compress way down, launch high, slam full weight
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.2, 0.6))
	# Deep compression
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.4), 0.15)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.05)
	# Launch high
	tween.tween_property(sprite, "position", base_pos + dir * 6.0 + Vector2(0, -12), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.5), 0.06)
	# SLAM full weight
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 4), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.6, 0.5), 0.04)
	# Jelly splat wobble
	tween.tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.75), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.95, 1.1), 0.05)
	# Settle
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _anim_mimic_devour(dir: Vector2, base_pos: Vector2) -> void:
	# Devour — lid opens WIDE, lunges to swallow, chomps multiple times
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.7, 0.6))
	# Lid flies open — massive stretch
	tween.tween_property(sprite, "scale", Vector2(0.7, 1.5), 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -5), 0.1)
	# Engulf lunge
	tween.tween_property(sprite, "position", base_pos + dir * 14.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
	# Rapid chomps — 3 bites
	for i in range(3):
		tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.03)
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.03)
	# Spit out — disgusted
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_ghoul_rend(dir: Vector2, base_pos: Vector2) -> void:
	# Rend — frenzied double claw rake with lurching forward
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(0.7, 1.3, 0.5) * base_mod)
	# Lurch forward aggressively
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.06)
	# First rake — right claw
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + perp * 5.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.2, 0.04)
	# Second rake — left claw
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 - perp * 5.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", -0.2, 0.04)
	# Third rake — center downward
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 3), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.04)
	# Stumble back — spent
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _anim_cknight_bash(dir: Vector2, base_pos: Vector2) -> void:
	# Shield bash — brace behind shield, charge forward, slam with shield edge
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.2, 1.0) * base_mod)
	# Brace — hide behind shield (compress wide)
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.85), 0.1)
	# Brief brace hold
	tween.tween_interval(0.05)
	# Charge forward — explosive
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.06)
	# Shield impact — heavy squash
	tween.tween_property(sprite, "scale", Vector2(1.35, 0.75), 0.03)
	# Impact jitter
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 0), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-2, 2), 0), 0.03)
	# Deliberate step back
	tween.tween_property(sprite, "modulate", base_mod, 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.97), 0.12)
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ---- Mini-boss attack animations ----

func _anim_boss_ground_slam(dir: Vector2, base_pos: Vector2) -> void:
	# Ravager / Ogre Boss: rear up high, slam the ground with a shockwave squash
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Wind-up — rear back and stretch tall
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, -10), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.8, sy * 1.35), 0.12)
	# Hang at apex briefly
	tween.tween_interval(0.06)
	# Slam down — fast, heavy
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 4), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.5, sy * 0.6), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 1.0, 0.7), 0.06)
	# Impact — screen-shake feel via rapid position jitter
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_charge_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Dread Knight: fast charge forward with sweeping rotation slash
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Coil — pull back, lean into direction
	tween.tween_property(sprite, "position", base_pos - dir * 8.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.2, sy * 0.85), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.7, 0.7), 0.08)
	# Dash forward — explosive speed
	tween.tween_property(sprite, "position", base_pos + dir * 20.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.7, sy * 1.3), 0.06)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.4, 0.06)
	# Sweeping slash arc — rotate through
	tween.tween_property(sprite, "rotation", -dir.angle() * 0.3, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.9, 0.9), 0.04)
	# Skid to a stop
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.06)
	# Return
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)

func _anim_boss_fire_breath(dir: Vector2, base_pos: Vector2) -> void:
	# Elder Drake: rear up, puff out, lunge with fiery tint
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rear up — inhale
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.15, sy * 1.25), 0.1)
	# Puff — swell out
	tween.tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 1.1), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.8, 0.3), 0.06)
	# Breath lunge — snap forward with fire tint
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.3), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.6, 0.2), 0.07)
	# Hold the flame
	tween.tween_interval(0.08)
	# Cool down — pull back, tint fades
	tween.tween_property(sprite, "position", base_pos, 0.14)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.14)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.14)

func _anim_boss_doom_strike(dir: Vector2, base_pos: Vector2) -> void:
	# Abyssal Lord: spin-up whirlwind then devastating overhead slam
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Spin-up — rapid full rotations with growing intensity
	tween.tween_property(sprite, "rotation", TAU, 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.4, 0.8), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 1.3), 0.15)
	tween.tween_property(sprite, "rotation", TAU * 2.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.3, 1.0), 0.12)
	# Release — slam forward
	tween.tween_property(sprite, "position", base_pos + dir * 18.0, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.6, sy * 0.5), 0.05)
	tween.parallel().tween_property(sprite, "rotation", TAU * 2.0 + dir.angle() * 0.3, 0.05)
	# Impact jitter
	for i in range(4):
		tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(randf_range(-5, 5), randf_range(-3, 3)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.14)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.14)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.14)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.14)

func _anim_boss_savage_pounce(dir: Vector2, base_pos: Vector2) -> void:
	# Shadow Fang: crouch low, explosive leap, snap bite, land heavy
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Crouch low — compress and widen
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 0.6), 0.08)
	# Explosive leap forward
	tween.tween_property(sprite, "position", base_pos + dir * 22.0, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.7, sy * 1.4), 0.05)
	# Snap bite flash
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.04)
	# Land heavy with jitter
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 0.75), 0.06)
	for i in range(2):
		tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_venom_barrage(dir: Vector2, base_pos: Vector2) -> void:
	# War Spider: rear up with green tint, 3 rapid jabs, toxic burst
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rear up — green venom tint
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -6), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.9, sy * 1.3), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.4, 0.5), 0.1)
	# 3 rapid forward jabs with alternating rotation
	for i in range(3):
		var rot = 0.15 if i % 2 == 0 else -0.15
		tween.tween_property(sprite, "position", base_pos + dir * (10.0 + i * 4.0), 0.04)
		tween.parallel().tween_property(sprite, "rotation", rot, 0.04)
	# Toxic burst — green flash
	tween.tween_property(sprite, "modulate", Color(0.3, 2.0, 0.3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 1.3), 0.06)
	# Settle
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_death_cleave(dir: Vector2, base_pos: Vector2) -> void:
	# Bone Lord: rise tall, spinning cleave with forward dash, slam down
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rise tall — pale blue tint
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.3), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.8, 1.4), 0.1)
	# Spinning cleave — full rotation + forward dash
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", TAU, 0.1)
	# Slam down — wide and flat
	tween.tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 0.7), 0.05)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(0, 4), 0.05)
	# Impact jitter with dark purple flash
	tween.tween_property(sprite, "modulate", Color(0.8, 0.3, 1.2), 0.06)
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _spawn_blood_splatter() -> void:
	var blood_tex = SpriteGenerator.get_texture("blood_splatter")
	if not blood_tex:
		return
	var blood = Sprite2D.new()
	blood.texture = blood_tex
	blood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blood.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	blood.rotation = randf() * TAU
	blood.scale = Vector2(randf_range(0.8, 1.5), randf_range(0.8, 1.5))
	blood.z_index = -2
	blood.modulate.a = randf_range(0.6, 0.9)
	_get_world_node().add_child(blood)
	var fade_tween = blood.create_tween()
	fade_tween.tween_interval(randf_range(3.0, 5.0))
	fade_tween.tween_property(blood, "modulate:a", 0.0, 1.0)
	fade_tween.tween_callback(blood.queue_free)

static func _get_pooled_drop() -> Area2D:
	if _drop_pool.size() > 0:
		var drop = _drop_pool.pop_back()
		# Kill any leftover tweens
		for child in drop.get_children():
			if child is Sprite2D:
				child.position = Vector2.ZERO
				child.modulate = Color.WHITE
		return drop
	# Build a new drop: Area2D -> CollisionShape2D + Sprite2D
	var drop = Area2D.new()
	drop.collision_layer = 32
	drop.collision_mask = 0
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape_node.shape = circle
	drop.add_child(shape_node)
	var visual = Sprite2D.new()
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.name = "Visual"
	drop.add_child(visual)
	return drop

static func recycle_drop(drop: Area2D) -> void:
	if is_instance_valid(drop):
		drop.remove_from_group("ground_items")
		drop.get_parent().remove_child(drop)
		if _drop_pool.size() < DROP_POOL_MAX:
			_drop_pool.append(drop)
		else:
			drop.queue_free()

func _spawn_gold_drop(amount: int) -> void:
	var drop = _get_pooled_drop()
	drop.position = global_position
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", {"id": "_gold", "name": "%d Gold" % amount, "gold_amount": amount})

	var visual = drop.get_node("Visual") as Sprite2D
	visual.texture = SpriteGenerator.get_texture("crystal_blue" if amount >= 10 else "crystal_white")
	visual.modulate = Color.WHITE

	_get_world_node().add_child(drop)
	# Tween must be created after add_child (node needs to be in tree)
	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _spawn_item_drop(item_id: String) -> void:
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		return
	_spawn_item_drop_dict(item)

func _spawn_item_drop_dict(item: Dictionary) -> void:
	var drop = _get_pooled_drop()
	drop.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", item)

	var visual = drop.get_node("Visual") as Sprite2D
	visual.texture = SpriteGenerator.get_texture("crystal_teal")
	var rarity = item.get("rarity", 0)
	visual.modulate = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)

	_get_world_node().add_child(drop)
	# Tween must be created after add_child (node needs to be in tree)
	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	# Announce rare+ drops
	var rarity_name = ItemData.RARITY_NAMES.get(rarity, "")
	if rarity >= ItemData.Rarity.RARE:
		var color = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)
		GameManager.game_message.emit("%s %s dropped!" % [rarity_name, item.get("name", "Item")], color)

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	var label: Label
	if _dmg_label_pool.size() > 0:
		label = _dmg_label_pool.pop_back()
	else:
		label = Label.new()
	var _zc = _get_zoom_compensation()
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10) if not is_crit else randf_range(-6, 6), -30)
	label.label_settings = _dmg_settings_crit if is_crit else _dmg_settings_normal
	label.modulate.a = 1.0
	label.scale = Vector2(_zc, _zc)
	add_child(label)
	var tween = create_tween()
	if is_crit:
		label.scale = Vector2(0.4 * _zc, 0.4 * _zc)
		tween.tween_property(label, "scale", Vector2(1.3 * _zc, 1.3 * _zc), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(_zc, _zc), 0.05)
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 40, 0.7)
		tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
		tween.set_parallel(false)
	else:
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 28, 0.55)
		tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
		tween.set_parallel(false)
	tween.tween_callback(_recycle_dmg_label.bind(label))

static func _recycle_dmg_label(label: Label) -> void:
	if is_instance_valid(label):
		label.get_parent().remove_child(label)
		if _dmg_label_pool.size() < DMG_LABEL_POOL_MAX:
			_dmg_label_pool.append(label)
		else:
			label.queue_free()

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.set_value(stats.current_hp, stats.max_hp)
		if not _is_selected:
			hp_bar.visible = stats.current_hp < stats.max_hp

func get_stats_dict() -> Dictionary:
	return stats.get_stats_dict()

func _get_player() -> Node2D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		return _cached_player
	return null

func _update_sleep_state() -> void:
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	if _is_sleeping:
		# Wake up when player gets close enough (with hysteresis to avoid flicker)
		if dist_sq < WAKE_DISTANCE_SQ:
			_is_sleeping = false
			visible = true
			set_physics_process(true)
	else:
		# Fall asleep when player is far away (only if not in combat)
		if dist_sq > SLEEP_DISTANCE_SQ and current_state != State.CHASE and current_state != State.ATTACK and current_state != State.RETURN:
			_is_sleeping = true
			visible = false
			velocity = Vector2.ZERO
			set_physics_process(false)
	# Proximity-based label visibility for non-combat states
	if not _is_selected and current_state != State.CHASE and current_state != State.ATTACK:
		name_label.visible = dist_sq < LABEL_VISIBLE_DISTANCE_SQ

func _get_world_node() -> Node:
	if _cached_world_node and is_instance_valid(_cached_world_node):
		return _cached_world_node
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		_cached_world_node = world[0]
	else:
		_cached_world_node = get_tree().current_scene
	return _cached_world_node
