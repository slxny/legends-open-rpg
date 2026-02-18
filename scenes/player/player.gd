extends CharacterBody2D

signal attacked(target: Node2D)

@onready var stats: StatsComponent = $StatsComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var ability_mgr: AbilityManager = $AbilityManager
@onready var sprite: Sprite2D = $Sprite
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer
@onready var camera: Camera2D = $Camera2D
@onready var pickup_area: Area2D = $PickupArea

var hero_class: String = ""
var _enemies_in_range: Array[Node2D] = []

# Click-to-move
var _move_target: Vector2 = Vector2.ZERO
var _is_moving_to_target: bool = false
var _attack_target: Node2D = null
var _is_attacking_target: bool = false

# Selection
var _selected_enemy: Node2D = null
var _selection_circle: Sprite2D = null
var _player_selection: Sprite2D = null

# Isometric shadow
var _shadow: Sprite2D = null

# Attack animation state
var _is_attack_animating: bool = false

# Melee combo system
# 5 swing types: a=left-to-right, b=right-to-left backhand, c=overhead chop,
#                d=upward thrust, e=spin slash
# Each swing has 3 frames [wind-up, mid-swing, follow-through]
var _combo_swings: Array = []  # Array of Arrays: [[f1,f2,f3], [f1,f2,f3], ...]
var _idle_texture: Texture2D = null
var _combo_index: int = 0       # Which swing we're on in the current combo
var _combo_timer: float = 0.0   # Time since last hit — resets combo if too long
const COMBO_WINDOW: float = 1.8 # Seconds before combo resets
const COMBO_SEQUENCE: Array = [0, 1, 0, 1, 2, 3, 4]  # a,b,a,b,c,d,e then loop

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

	attack_timer.wait_time = 1.0 / stats.attack_speed
	attack_timer.start()

	var shape = attack_area.get_node("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = stats.attack_range

	# Isometric shadow under hero
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)

	# Green selection circle under player (always visible)
	_player_selection = Sprite2D.new()
	_player_selection.texture = SpriteGenerator.get_texture("selection_green")
	_player_selection.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_selection.z_index = -1
	add_child(_player_selection)

func _physics_process(delta: float) -> void:
	# WASD movement overrides click-to-move
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 0:
		_is_moving_to_target = false
		_is_attacking_target = false
		velocity = input_dir.normalized() * stats.get_total_move_speed()
	elif _is_attacking_target and is_instance_valid(_attack_target):
		var dist = global_position.distance_to(_attack_target.global_position)
		if dist <= stats.attack_range:
			velocity = Vector2.ZERO
		else:
			var dir = (_attack_target.global_position - global_position).normalized()
			velocity = dir * stats.get_total_move_speed()
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

	# Combo timer — reset combo if no attack within window
	if _combo_index > 0:
		_combo_timer += delta
		if _combo_timer >= COMBO_WINDOW:
			_combo_index = 0
			_combo_timer = 0.0

	# Flip sprite based on movement direction
	if velocity.x < -5:
		sprite.flip_h = true
	elif velocity.x > 5:
		sprite.flip_h = false

	# Update selection circle on selected enemy
	_update_selection_circle()

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

		if event.button_index == MOUSE_BUTTON_LEFT:
			# Left-click: select enemy and attack-move, OR move to position
			var target = _get_clickable_at_mouse()
			if target and target.is_in_group("enemies") and not target.get("_is_dead"):
				_select_enemy(target)
				_attack_target = target
				_is_attacking_target = true
				_is_moving_to_target = false
			else:
				_deselect_enemy()
				_move_target = _get_world_mouse_pos()
				_is_moving_to_target = true
				_is_attacking_target = false
				_attack_target = null
				_spawn_move_indicator(_move_target)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click: attack-move to target or position
			var target = _get_clickable_at_mouse()
			if target and target.is_in_group("enemies") and not target.get("_is_dead"):
				_select_enemy(target)
				_attack_target = target
				_is_attacking_target = true
				_is_moving_to_target = false
			elif target and target.has_method("interact"):
				_move_target = target.global_position
				_is_moving_to_target = true
			else:
				_move_target = _get_world_mouse_pos()
				_is_moving_to_target = true

	# Window controls
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var mode = DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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

func _select_enemy(enemy: Node2D) -> void:
	if _selected_enemy == enemy:
		return  # Already selected
	_deselect_enemy()
	_selected_enemy = enemy
	if enemy.has_method("show_selection"):
		enemy.show_selection()
	# Juicy click feedback
	_spawn_select_pop(enemy)
	_create_selection_circle()
	# Highlight enemy sprite
	if enemy.has_node("Sprite"):
		var enemy_sprite = enemy.get_node("Sprite")
		enemy_sprite.modulate = Color(1.3, 1.1, 1.1)

func _deselect_enemy() -> void:
	if is_instance_valid(_selected_enemy):
		if _selected_enemy.has_method("hide_selection"):
			_selected_enemy.hide_selection()
		# Remove highlight
		if _selected_enemy.has_node("Sprite"):
			var enemy_sprite = _selected_enemy.get_node("Sprite")
			enemy_sprite.modulate = Color.WHITE
	_selected_enemy = null
	_destroy_selection_circle()

func _create_selection_circle() -> void:
	_destroy_selection_circle()
	_selection_circle = Sprite2D.new()
	_selection_circle.texture = SpriteGenerator.get_texture("selection_red")
	_selection_circle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selection_circle.z_index = 1
	_selection_circle.scale = Vector2(2.0, 2.0)
	get_tree().current_scene.add_child(_selection_circle)
	# Pop in then pulse — chained so they don't fight over scale
	var tween = _selection_circle.create_tween()
	tween.tween_property(_selection_circle, "scale", Vector2(2.6, 2.6), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_selection_circle, "scale", Vector2(2.0, 2.0), 0.06)
	tween.tween_callback(func():
		if not is_instance_valid(_selection_circle):
			return
		var pulse = _selection_circle.create_tween().set_loops()
		pulse.tween_property(_selection_circle, "scale", Vector2(2.2, 2.2), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(_selection_circle, "scale", Vector2(1.9, 1.9), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

func _destroy_selection_circle() -> void:
	if _selection_circle and is_instance_valid(_selection_circle):
		_selection_circle.queue_free()
	_selection_circle = null

func _spawn_select_pop(enemy: Node2D) -> void:
	# Ring burst expanding outward from enemy
	var ring = Sprite2D.new()
	ring.texture = SpriteGenerator.get_texture("selection_red")
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.global_position = enemy.global_position
	ring.scale = Vector2(0.5, 0.5)
	ring.z_index = 10
	get_tree().current_scene.add_child(ring)
	var ring_tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(ring.queue_free)

	# Enemy sprite punch (quick scale bounce)
	if enemy.has_node("Sprite"):
		var enemy_sprite = enemy.get_node("Sprite")
		var punch_tween = enemy_sprite.create_tween()
		punch_tween.tween_property(enemy_sprite, "scale", Vector2(1.25, 0.85), 0.06)
		punch_tween.tween_property(enemy_sprite, "scale", Vector2(0.9, 1.15), 0.06)
		punch_tween.tween_property(enemy_sprite, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Quick crosshair flash at click point
	for i in range(4):
		var spark = Sprite2D.new()
		spark.texture = SpriteGenerator.get_texture("crystal_white")
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spark.global_position = enemy.global_position
		spark.scale = Vector2(0.3, 0.3)
		spark.modulate = Color(1.0, 0.4, 0.3, 0.9)
		spark.z_index = 11
		get_tree().current_scene.add_child(spark)
		# Cardinal directions burst
		var burst_dir = Vector2.from_angle(i * PI * 0.5) * 14.0
		var spark_tween = spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", enemy.global_position + burst_dir, 0.15)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		spark_tween.tween_property(spark, "scale", Vector2(0.1, 0.1), 0.2)
		spark_tween.set_parallel(false)
		spark_tween.tween_callback(spark.queue_free)

func _update_selection_circle() -> void:
	# Clean up if enemy is dead/invalid
	if is_instance_valid(_selected_enemy) and _selected_enemy.get("_is_dead"):
		_deselect_enemy()
		return

	if not is_instance_valid(_selected_enemy):
		_destroy_selection_circle()
		return

	# Update selection circle position under the targeted enemy
	if _selection_circle and is_instance_valid(_selection_circle):
		_selection_circle.global_position = _selected_enemy.global_position

func _get_world_mouse_pos() -> Vector2:
	return get_global_mouse_position()

func _get_clickable_at_mouse() -> Node2D:
	var mouse_pos = _get_world_mouse_pos()
	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collision_mask = 2 | 4  # Enemies + NPCs
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
	get_tree().current_scene.add_child(projectile)

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

# Auto-attack: only attack the explicitly selected enemy
func _on_attack_timer_timeout() -> void:
	if _is_attack_animating:
		return
	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.get("_is_dead"))

	# Only attack if player has selected an enemy
	if not is_instance_valid(_selected_enemy):
		return
	if _selected_enemy not in _enemies_in_range:
		return

	if _selected_enemy.has_method("take_damage"):
		_perform_attack(_selected_enemy)

func _perform_attack(target: Node2D) -> void:
	_is_attack_animating = true
	var result = CombatManager.calculate_damage(stats.get_stats_dict(), target.get_stats_dict())
	attacked.emit(target)

	# Face the target
	if target.global_position.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	var hero_data = HeroData.get_hero(hero_class)
	if hero_data.get("primary_stat") == "agility":
		# Ranged attack: bow draw + arrow
		_do_ranged_attack(target, result)
	else:
		# Melee attack: lunge + slash
		_do_melee_attack(target, result)

func _do_melee_attack(target: Node2D, result: Dictionary) -> void:
	if not is_instance_valid(target):
		_is_attack_animating = false
		return

	var dir = (target.global_position - global_position).normalized()
	var perp = Vector2(-dir.y, dir.x)  # Perpendicular for lateral swings
	var base_pos = sprite.position

	# Pick the current swing type from the combo sequence
	var swing_idx = COMBO_SEQUENCE[_combo_index % COMBO_SEQUENCE.size()]
	var has_frames = swing_idx < _combo_swings.size()
	var frames = _combo_swings[swing_idx] if has_frames else []

	# Advance combo for next attack
	_combo_index += 1
	_combo_timer = 0.0

	# Each swing type has unique choreography
	var tween = create_tween()
	match swing_idx:
		0:  # Swing A: Left-to-right slash
			_anim_swing_horizontal(tween, frames, base_pos, dir, perp, target, result, 1.0)
		1:  # Swing B: Right-to-left backhand
			_anim_swing_horizontal(tween, frames, base_pos, dir, perp, target, result, -1.0)
		2:  # Swing C: Overhead chop (finisher)
			_anim_overhead_chop(tween, frames, base_pos, dir, target, result)
		3:  # Swing D: Upward thrust
			_anim_upward_thrust(tween, frames, base_pos, dir, target, result)
		4:  # Swing E: Spin slash
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
			_spawn_slash_vfx(dir.rotated(side * 0.3), 35.0, 1.0)
			_spawn_impact_vfx(target.global_position)
			_do_screen_shake(2.5 if not result["is_crit"] else 5.0)
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
			_spawn_slash_vfx(dir, 40.0, 1.4)
			_spawn_impact_vfx(target.global_position)
			_do_screen_shake(4.0 if not result["is_crit"] else 7.0)
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
			_spawn_slash_vfx(dir.rotated(-0.4), 30.0, 1.0)
			_spawn_impact_vfx(target.global_position)
			_do_screen_shake(3.0 if not result["is_crit"] else 6.0)
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
			# Wide slash VFX — hits in a circle
			_spawn_slash_vfx(dir, 40.0, 1.6)
			_spawn_slash_vfx(dir.rotated(PI * 0.5), 35.0, 1.2)
			_spawn_slash_vfx(dir.rotated(-PI * 0.5), 35.0, 1.2)
			_spawn_impact_vfx(target.global_position)
			_do_screen_shake(5.0 if not result["is_crit"] else 8.0)
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
		get_tree().current_scene.add_child(arrow)

		var arrow_tween = arrow.create_tween()
		arrow_tween.tween_property(arrow, "global_position", target.global_position, 0.12)
		arrow_tween.tween_callback(func():
			if is_instance_valid(target):
				target.take_damage(result["damage"], result["is_crit"])
				_spawn_impact_vfx(target.global_position)
				_do_screen_shake(1.5 if not result["is_crit"] else 3.5)
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
	get_tree().current_scene.add_child(slash)

	var tween = slash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "scale", slash.scale * 1.4, 0.15)
	tween.tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(slash.queue_free)

func _spawn_impact_vfx(pos: Vector2) -> void:
	# White flash burst at impact point
	for i in range(4):
		var spark = Sprite2D.new()
		spark.texture = SpriteGenerator.get_texture("crystal_white")
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spark.global_position = pos
		spark.scale = Vector2(0.4, 0.4)
		spark.modulate = Color(1.0, 1.0, 0.8, 0.9)
		get_tree().current_scene.add_child(spark)

		var dir = Vector2.from_angle(randf() * TAU) * randf_range(8, 16)
		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + dir, 0.15)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.tween_property(spark, "scale", Vector2.ZERO, 0.2)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func _do_screen_shake(intensity: float) -> void:
	var original_offset = camera.offset
	var tween = create_tween()
	for i in range(4):
		var shake = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", original_offset + shake, 0.03)
	tween.tween_property(camera, "offset", original_offset, 0.03)

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
	get_tree().current_scene.add_child(indicator)
	var tween = indicator.create_tween()
	tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
	tween.tween_callback(indicator.queue_free)

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
