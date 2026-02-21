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

# Distance-based sleep/wake — enemies far from the player disable physics processing
var _is_sleeping: bool = false
var _sleep_check_timer: float = 0.0
const SLEEP_DISTANCE_SQ: float = 640000.0  # 800^2 — sleep when player is >800px away
const WAKE_DISTANCE_SQ: float = 490000.0   # 700^2 — wake when player is <700px (hysteresis)
const SLEEP_CHECK_INTERVAL: float = 0.4    # Check sleep/wake ~2.5x per second

# Patrol state
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_radius: float = 150.0
var _patrol_wait_timer: float = 0.0
var _patrol_speed_factor: float = 0.65  # Patrol at 65% of move speed — more active roaming

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

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	var tex = SpriteGenerator.get_texture(sprite_type)
	if tex:
		sprite.texture = tex
	hp_bar.visible = false
	name_label.visible = false
	# Initialize shared label settings once (static, shared across all enemies)
	if not _dmg_settings_normal:
		_dmg_settings_normal = LabelSettings.new()
		_dmg_settings_normal.font_size = 14
		_dmg_settings_normal.font_color = Color.WHITE
		_dmg_settings_normal.outline_size = 2
		_dmg_settings_normal.outline_color = Color.BLACK
	if not _dmg_settings_crit:
		_dmg_settings_crit = LabelSettings.new()
		_dmg_settings_crit.font_size = 28
		_dmg_settings_crit.font_color = Color(1.0, 0.95, 0.1)
		_dmg_settings_crit.outline_size = 3
		_dmg_settings_crit.outline_color = Color.BLACK

	# Shadow
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)
	_shadow.move_to_front()
	move_child(_shadow, 0)

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

	stats.max_hp = 30 + enemy_level * 15
	stats.current_hp = stats.max_hp
	stats.strength = 5 + enemy_level * 2
	stats.agility = 3 + enemy_level
	stats.intelligence = 2 + enemy_level
	stats.armor = enemy_level
	stats.attack_damage = 5 + enemy_level * 3
	stats.attack_range = config.get("attack_range", 35.0)
	stats.move_speed = config.get("move_speed", 80.0)
	stats.primary_stat = "strength"

	# Scale patrol radius with move speed — faster enemies roam much further
	_patrol_radius = 300.0 + stats.move_speed * 3.0
	chase_range = _patrol_radius + 350.0

	# Pre-compute squared distances (avoids sqrt every frame in hot path)
	_aggro_range_sq = aggro_range * aggro_range
	_chase_range_sq = chase_range * chase_range
	_attack_range_sq = stats.attack_range * stats.attack_range
	var disengage = stats.attack_range * 1.5
	_attack_disengage_sq = disengage * disengage
	var alert_range = aggro_range * ALERT_RANGE_MULTIPLIER
	_alert_range_sq = alert_range * alert_range

	# Randomly assign an effect to some units (~25% of enemies have an effect proc)
	const EFFECT_TYPES = ["knockback", "paralyze", "slow"]
	if randf() < 0.25:
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

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Distance-based sleep/wake check (throttled)
	_sleep_check_timer -= delta
	if _sleep_check_timer <= 0.0:
		_sleep_check_timer = SLEEP_CHECK_INTERVAL
		_update_sleep_state()
		if _is_sleeping:
			return
	elif _is_sleeping:
		return

	# Apply knockback impulse — overrides state machine until it decays
	if _knockback_velocity.length_squared() > 4.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)
		move_and_slide()
		return
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

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
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
		move_and_slide()
		current_state = State.IDLE
		_patrol_wait_timer = randf_range(0.5, 2.0)
		return

	var dir = (_patrol_target - global_position).normalized()
	velocity = dir * stats.move_speed * _patrol_speed_factor + _get_separation_push()
	# Flip sprite based on movement direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

func _get_separation_push() -> Vector2:
	var push = Vector2.ZERO
	for slide_idx in range(get_slide_collision_count()):
		var col = get_slide_collision(slide_idx)
		if col and col.get_collider() and col.get_collider().is_in_group("enemies"):
			push -= col.get_normal() * 60.0
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

	# Keep enemies spread apart even while attacking
	velocity = _get_separation_push()
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		if target.has_method("take_damage"):
			var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict())
			target.take_damage(result["damage"], result["is_crit"])
			_do_attack_lunge()
			# Rare effect proc
			if _effect_chance > 0.0 and randf() < _effect_chance:
				_apply_effect_to_target(target)

func _process_return(delta: float) -> void:
	var dist_sq = global_position.distance_squared_to(home_position)
	if dist_sq < 25.0:  # 5^2
		velocity = Vector2.ZERO
		move_and_slide()
		current_state = State.IDLE
		stats.current_hp = stats.max_hp
		_update_hp_bar()
		_patrol_wait_timer = randf_range(0.3, 1.0)
		if not _is_selected:
			name_label.visible = false
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

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return
	# Force wake if sleeping (player somehow hit us at range)
	if _is_sleeping:
		_is_sleeping = false
		visible = true
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
		_die()
	elif current_state == State.IDLE or current_state == State.PATROL:
		var player = _get_player()
		if player:
			target = player
			current_state = State.CHASE

func _die() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
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

	if sprite_type == "skeleton":
		_die_crumble()
	else:
		_spawn_blood_splatter()
		_die_default()

func _die_default() -> void:
	# Death animation: pop, fall, fade
	var tween = create_tween()
	# Brief upward pop
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, -6), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.05)
	# Fall and fade simultaneously
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "rotation", deg_to_rad(85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, 10), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

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

func _spawn_bone_fragments() -> void:
	var bone_tex = SpriteGenerator.get_texture("bone_fragment")
	if not bone_tex:
		return
	var world = _get_world_node()
	for i in range(randi_range(4, 7)):
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
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	# Squash: squeeze horizontally, stretch vertically, then bounce back
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.set_parallel(false)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _do_attack_lunge() -> void:
	if not is_instance_valid(target):
		return
	var dir = (target.global_position - global_position).normalized()
	var base_pos = sprite.position
	match sprite_type:
		"rat":
			_anim_rat_bite(dir, base_pos)
		"goblin":
			_anim_goblin_swing(dir, base_pos)
		_:
			_anim_generic_lunge(dir, base_pos)

func _anim_rat_bite(dir: Vector2, base_pos: Vector2) -> void:
	# Quick coil-and-snap bite — rats are fast and twitchy
	var tween = create_tween()
	# Coil back and flatten
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.7), 0.04)
	# Snap forward — fast lunging bite
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.04)
	# Tint red on contact
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.8, 0.8))
	# Quick chomp — tiny oscillation at the bite point
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.03)
	# Recoil back
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	# Settle
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_goblin_swing(dir: Vector2, base_pos: Vector2) -> void:
	# Club overhead swing — wind up then slam down
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# Wind-up: pull back and stretch tall (raising club)
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -3), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	# Slam forward — fast and heavy
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.9))
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 2), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.05)
	# Slight rotation on impact for follow-through
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.05)
	# Impact bounce
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.04)
	# Return to idle
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.07)

func _anim_generic_lunge(dir: Vector2, base_pos: Vector2) -> void:
	# Standard lunge with squash-stretch for weight
	var tween = create_tween()
	# Brief anticipation
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	# Lunge
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.06)
	# Return
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

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
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10) if not is_crit else randf_range(-6, 6), -30)
	label.label_settings = _dmg_settings_crit if is_crit else _dmg_settings_normal
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	add_child(label)
	var tween = create_tween()
	if is_crit:
		label.scale = Vector2(0.4, 0.4)
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.05)
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
	else:
		# Fall asleep when player is far away (only if not in combat)
		if dist_sq > SLEEP_DISTANCE_SQ and current_state != State.CHASE and current_state != State.ATTACK:
			_is_sleeping = true
			visible = false
			velocity = Vector2.ZERO

func _get_world_node() -> Node:
	if _cached_world_node and is_instance_valid(_cached_world_node):
		return _cached_world_node
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		_cached_world_node = world[0]
	else:
		_cached_world_node = get_tree().current_scene
	return _cached_world_node
