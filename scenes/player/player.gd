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
var _enemies_in_range: Array[Node2D] = []

# Click-to-move
var _move_target: Vector2 = Vector2.ZERO
var _is_moving_to_target: bool = false

# Isometric shadow
var _shadow: Sprite2D = null

# Attack state
var _is_attack_animating: bool = false
var _attack_cooldown: float = 0.0

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

	# Isometric shadow under hero
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)

	# Counter-transform sprite and shadow so they render upright despite the
	# isometric projection applied to the World node.
	var ct = IsometricHelper.get_sprite_counter_transform()
	sprite.transform = ct
	_shadow.transform = ct

func _physics_process(delta: float) -> void:
	# WASD movement overrides click-to-move.
	# Screen directions need to be converted to world-space through the
	# inverse isometric transform so W=up-on-screen, D=right-on-screen, etc.
	var screen_dir = Vector2.ZERO
	screen_dir.x = Input.get_axis("move_left", "move_right")
	screen_dir.y = Input.get_axis("move_up", "move_down")

	var input_dir = Vector2.ZERO
	if screen_dir.length() > 0:
		input_dir = IsometricHelper.get_iso_inverse().basis_xform(screen_dir).normalized()

	if input_dir.length() > 0:
		_is_moving_to_target = false
		velocity = input_dir * stats.get_total_move_speed()
	elif _is_moving_to_target:
		var dist = global_position.distance_to(_move_target)
		if dist < 5.0:
			_is_moving_to_target = false
			velocity = Vector2.ZERO
		else:
			var dir = (_move_target - global_position).normalized()
			velocity = dir * stats.get_total_move_speed()
	else:
		velocity = Vector2.ZERO

	move_and_slide()
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

	# Flip sprite based on screen-space movement direction.
	# Convert world velocity to screen space via the iso transform basis.
	var screen_vel = IsometricHelper.get_iso_transform().basis_xform(velocity)
	if screen_vel.x < -5:
		sprite.flip_h = true
	elif screen_vel.x > 5:
		sprite.flip_h = false

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

	# Attack — Space bar
	if event.is_action_pressed("attack"):
		_try_manual_attack()

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

	_attack_cooldown = 0.5 / stats.attack_speed  # 50% faster than base

	# Determine attack direction from held movement input (screen → world)
	var input_raw = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var attack_dir: Vector2
	if input_raw.length() > 0.25:
		attack_dir = IsometricHelper.get_iso_inverse().basis_xform(input_raw).normalized()
	else:
		attack_dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT

	# Update sprite facing based on screen-space attack direction
	var screen_attack = IsometricHelper.get_iso_transform().basis_xform(attack_dir)
	if screen_attack.x < -0.1:
		sprite.flip_h = true
	elif screen_attack.x > 0.1:
		sprite.flip_h = false

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

func _use_ability(ability_key: String) -> void:
	var ability_data = ability_mgr.use_ability(ability_key, self)
	if ability_data.is_empty():
		return
	# SC:BW trigger delay feel
	await get_tree().create_timer(0.3).timeout
	if ability_data.has("damage_multiplier") and ability_data.has("radius"):
		_execute_aoe_ability(ability_data)
	elif ability_data.has("projectile_count"):
		_execute_projectile_ability(ability_data)
	elif ability_data.has("armor_bonus"):
		ability_mgr.apply_buff("armor", ability_data["armor_bonus"], ability_data["duration"])
		_spawn_buff_vfx(Color(0.4, 0.6, 1.0, 0.4), ability_data["duration"])
		GameManager.game_message.emit("Shield Wall! +%d Armor" % int(ability_data["armor_bonus"]), Color(0.4, 0.7, 1.0))
	elif ability_data.has("dodge_bonus"):
		ability_mgr.apply_buff("dodge", ability_data["dodge_bonus"], ability_data["duration"])
		_spawn_buff_vfx(Color(0.2, 1.0, 0.4, 0.3), ability_data["duration"])
		GameManager.game_message.emit("Evasion! +%d%% Dodge" % int(ability_data["dodge_bonus"] * 100), Color(0.3, 1.0, 0.5))

func _execute_aoe_ability(ability_data: Dictionary) -> void:
	var mouse_dir = (_get_world_mouse_pos() - global_position).normalized()
	var radius = ability_data.get("radius", 80.0)
	var arc = deg_to_rad(ability_data.get("arc_degrees", 120.0))

	_spawn_slash_vfx(mouse_dir, radius, 1.5)

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to_enemy = enemy.global_position - global_position
		if to_enemy.length() > radius:
			continue
		var angle_diff = abs(mouse_dir.angle_to(to_enemy.normalized()))
		if angle_diff > arc / 2.0:
			continue
		var result = CombatManager.calculate_damage(stats.get_stats_dict(), enemy.get_stats_dict(), ability_data["damage_multiplier"])
		enemy.take_damage(result["damage"], result["is_crit"])
	_do_screen_shake(4.0)

func _execute_projectile_ability(ability_data: Dictionary) -> void:
	var base_dir = (_get_world_mouse_pos() - global_position).normalized()
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
	var result = CombatManager.calculate_damage(stats.get_stats_dict(), target.get_stats_dict())
	attacked.emit(target)

	var hero_data = HeroData.get_hero(hero_class)
	if hero_data.get("primary_stat") == "agility":
		_do_ranged_attack(target, result)
	else:
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
	var spark_count = 12 if is_crit else 8
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
	# Brief time-scale dip for punch impact feel
	var freeze_dur = 0.06 if not is_crit else 0.12
	Engine.time_scale = 0.05
	await get_tree().create_timer(freeze_dur * 0.05).timeout
	Engine.time_scale = 1.0

func _do_screen_shake(intensity: float) -> void:
	var original_offset = camera.offset
	var tween = create_tween()
	# Fast burst of shakes then settle
	for i in range(6):
		var decay = 1.0 - float(i) / 6.0
		var shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * intensity * decay
		tween.tween_property(camera, "offset", original_offset + shake, 0.025)
	tween.tween_property(camera, "offset", original_offset, 0.04)

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
	var settings = LabelSettings.new()
	settings.font_size = 14 if not is_crit else 22
	settings.font_color = Color(1.0, 0.3, 0.3) if not is_crit else Color(1.0, 0.1, 0.1)
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	var start_pos = Vector2(randf_range(-10, 10), -35)
	var wrapper = IsometricHelper.counter_transform_wrap(label, start_pos)
	add_child(wrapper)
	var tween = create_tween()
	tween.tween_property(wrapper, "position:y", wrapper.position.y - 30, 0.6)
	tween.parallel().tween_property(wrapper, "modulate:a", 0.0, 0.6)
	tween.tween_callback(wrapper.queue_free)

func _do_hit_flash() -> void:
	sprite.modulate = Color(1, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
