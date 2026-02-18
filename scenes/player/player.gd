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

# Melee attack frame textures (cached on ready for melee heroes)
var _atk_frames: Array = []  # [atk1, atk2, atk3]
var _idle_texture: Texture2D = null

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

	# Cache melee attack frames if available
	var atk1 = SpriteGenerator.get_texture(hero_class + "_atk1")
	var atk2 = SpriteGenerator.get_texture(hero_class + "_atk2")
	var atk3 = SpriteGenerator.get_texture(hero_class + "_atk3")
	if atk1 and atk2 and atk3:
		_atk_frames = [atk1, atk2, atk3]

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

	# Flip sprite based on movement direction
	if velocity.x < -5:
		sprite.flip_h = true
	elif velocity.x > 5:
		sprite.flip_h = false

	# Update selection circle on selected enemy
	_update_selection_circle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
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
				_move_target = get_global_mouse_position()
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
				_move_target = get_global_mouse_position()
				_is_moving_to_target = true

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
	_selected_enemy = enemy
	# Show enemy info
	if enemy.has_method("show_selection"):
		enemy.show_selection()

func _deselect_enemy() -> void:
	if is_instance_valid(_selected_enemy) and _selected_enemy.has_method("hide_selection"):
		_selected_enemy.hide_selection()
	_selected_enemy = null

func _update_selection_circle() -> void:
	# Clean up if enemy is dead/invalid
	if is_instance_valid(_selected_enemy) and _selected_enemy.get("_is_dead"):
		_deselect_enemy()

	if _selection_circle and not is_instance_valid(_selected_enemy):
		_selection_circle.queue_free()
		_selection_circle = null
		return

	if is_instance_valid(_selected_enemy):
		if not _selection_circle or not is_instance_valid(_selection_circle):
			_selection_circle = Sprite2D.new()
			_selection_circle.texture = SpriteGenerator.get_texture("selection_red")
			_selection_circle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_selection_circle.z_index = -1
			get_tree().current_scene.add_child(_selection_circle)
		_selection_circle.global_position = _selected_enemy.global_position

func _get_clickable_at_mouse() -> Node2D:
	var mouse_pos = get_global_mouse_position()
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
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
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
	var base_dir = (get_global_mouse_position() - global_position).normalized()
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

# Auto-attack: prioritize selected enemy, then nearest in range
func _on_attack_timer_timeout() -> void:
	if _is_attack_animating:
		return
	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.get("_is_dead"))

	# Prioritize selected enemy if in range
	var attack_target: Node2D = null
	if is_instance_valid(_selected_enemy) and _selected_enemy in _enemies_in_range:
		attack_target = _selected_enemy
	elif is_instance_valid(_attack_target) and _attack_target in _enemies_in_range:
		attack_target = _attack_target
	else:
		# Find nearest
		var nearest_dist = INF
		for enemy in _enemies_in_range:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				attack_target = enemy

	if attack_target and attack_target.has_method("take_damage"):
		_perform_attack(attack_target)

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
	var base_pos = sprite.position
	var has_frames = _atk_frames.size() >= 3

	var tween = create_tween()

	# Frame 1: Wind-up — sword raised, pull back
	if has_frames:
		tween.tween_callback(func(): sprite.texture = _atk_frames[0])
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.08)

	# Frame 2: Mid-swing — lunge forward
	if has_frames:
		tween.tween_callback(func(): sprite.texture = _atk_frames[1])
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)

	# Frame 3: Impact — sword extended, deal damage
	if has_frames:
		tween.tween_callback(func(): sprite.texture = _atk_frames[2])
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.04)
	tween.tween_callback(func():
		if is_instance_valid(target):
			target.take_damage(result["damage"], result["is_crit"])
			_spawn_slash_vfx(dir, 35.0, 1.0)
			_spawn_impact_vfx(target.global_position)
			_do_screen_shake(2.5 if not result["is_crit"] else 5.0)
	)

	# Return to idle
	tween.tween_interval(0.06)
	tween.tween_callback(func():
		if _idle_texture:
			sprite.texture = _idle_texture
	)
	tween.tween_property(sprite, "position", base_pos, 0.1)
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
