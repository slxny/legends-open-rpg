extends CharacterBody2D

signal died(enemy: Node2D, xp_reward: int, gold_reward: int)

@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: SCBar = $HPBar
@onready var stats: StatsComponent = $StatsComponent
@onready var name_label: Label = $NameLabel

enum State { IDLE, CHASE, ATTACK, RETURN }

var current_state: State = State.IDLE
var home_position: Vector2 = Vector2.ZERO
var target: Node2D = null

# Enemy config
var enemy_name: String = "Enemy"
var enemy_level: int = 1
var aggro_range: float = 120.0
var chase_range: float = 250.0
var attack_cooldown: float = 1.2
var xp_reward: int = 15
var gold_reward: int = 5
var drop_table: String = ""
var sprite_type: String = "goblin"

var _attack_timer: float = 0.0
var _is_dead: bool = false
var _shadow: Sprite2D = null
var _is_selected: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	var tex = SpriteGenerator.get_texture(sprite_type)
	if tex:
		sprite.texture = tex
	hp_bar.visible = false
	name_label.visible = false

	# Isometric shadow
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)
	_shadow.move_to_front()
	move_child(_shadow, 0)

	# Counter-transform sprite, shadow, HP bar, and label so they render
	# upright despite the isometric projection on the World node.
	var ct = IsometricHelper.get_sprite_counter_transform()
	sprite.transform = ct
	_shadow.transform = ct
	hp_bar.transform = ct
	name_label.transform = ct

func initialize(config: Dictionary) -> void:
	enemy_name = config.get("name", "Enemy")
	enemy_level = config.get("level", 1)
	aggro_range = config.get("aggro_range", 120.0)
	xp_reward = config.get("xp_reward", 15)
	gold_reward = config.get("gold_reward", 5)
	drop_table = config.get("drop_table", "")
	sprite_type = config.get("sprite_type", "goblin")

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

	# Apply knockback impulse — overrides state machine until it decays
	if _knockback_velocity.length() > 2.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)
		move_and_slide()
		return
	_knockback_velocity = Vector2.ZERO

	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RETURN:
			_process_return(delta)

func _process_idle() -> void:
	var player = _get_player()
	if player and global_position.distance_to(player.global_position) < aggro_range:
		target = player
		current_state = State.CHASE
		name_label.visible = true

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

	var dist_to_target = global_position.distance_to(target.global_position)
	var dist_from_home = global_position.distance_to(home_position)

	if dist_from_home > chase_range:
		current_state = State.RETURN
		target = null
		return

	if dist_to_target <= stats.attack_range:
		current_state = State.ATTACK
		return

	var dir = (target.global_position - global_position).normalized()
	velocity = dir * stats.move_speed + _get_separation_push()
	# Flip sprite based on screen-space movement direction
	var screen_dir = IsometricHelper.get_iso_transform().basis_xform(dir)
	if screen_dir.x < -0.1:
		sprite.flip_h = true
	elif screen_dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

func _process_attack(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	var dist = global_position.distance_to(target.global_position)
	if dist > stats.attack_range * 1.5:
		current_state = State.CHASE
		return

	# Keep enemies spread apart even while attacking
	var sep = _get_separation_push()
	if sep != Vector2.ZERO:
		velocity = sep
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		if target.has_method("take_damage"):
			var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict())
			target.take_damage(result["damage"], result["is_crit"])
			_do_attack_lunge()

func _process_return(delta: float) -> void:
	var dist = global_position.distance_to(home_position)
	if dist < 5.0:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		stats.current_hp = stats.max_hp
		_update_hp_bar()
		if not _is_selected:
			name_label.visible = false
		return

	var dir = (home_position - global_position).normalized()
	var screen_dir = IsometricHelper.get_iso_transform().basis_xform(dir)
	if screen_dir.x < -0.1:
		sprite.flip_h = true
	elif screen_dir.x > 0.1:
		sprite.flip_h = false
	velocity = dir * stats.move_speed * 1.5
	move_and_slide()

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return
	stats.take_damage(amount)
	_update_hp_bar()
	hp_bar.visible = true
	name_label.visible = true
	_spawn_damage_number(amount, is_crit)
	_do_hit_flash()

	if stats.current_hp <= 0:
		_die()
	elif current_state == State.IDLE:
		var player = _get_player()
		if player:
			target = player
			current_state = State.CHASE

func _die() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	died.emit(self, xp_reward, gold_reward)
	_spawn_gold_drop(gold_reward)
	_spawn_blood_splatter()
	if not drop_table.is_empty():
		var item_id = ItemData.roll_drop(drop_table)
		if not item_id.is_empty():
			_spawn_item_drop(item_id)
	# Death animation: pop, fall, fade
	hp_bar.visible = false
	name_label.visible = false
	if _shadow:
		_shadow.visible = false
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
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)

func _spawn_blood_splatter() -> void:
	var blood_tex = SpriteGenerator.get_texture("blood_splatter")
	if not blood_tex:
		return
	# Spawn 2-4 blood splatters around the death position
	for _i in range(randi_range(2, 4)):
		var blood = Sprite2D.new()
		blood.texture = blood_tex
		blood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		blood.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		blood.rotation = randf() * TAU
		blood.scale = Vector2(randf_range(0.8, 1.5), randf_range(0.8, 1.5))
		blood.z_index = -2
		blood.modulate.a = randf_range(0.6, 0.9)
		_get_world_node().add_child(blood)
		# Fade out after 8-12 seconds
		var fade_tween = blood.create_tween()
		fade_tween.tween_interval(randf_range(8.0, 12.0))
		fade_tween.tween_property(blood, "modulate:a", 0.0, 2.0)
		fade_tween.tween_callback(blood.queue_free)

func _spawn_gold_drop(amount: int) -> void:
	var drop = Area2D.new()
	drop.position = global_position
	drop.collision_layer = 32
	drop.collision_mask = 0
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", {"id": "_gold", "name": "%d Gold" % amount, "gold_amount": amount})

	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape_node.shape = circle
	drop.add_child(shape_node)

	var visual = Sprite2D.new()
	visual.texture = SpriteGenerator.get_texture("crystal_blue" if amount >= 10 else "crystal_white")
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drop.add_child(visual)

	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	_get_world_node().add_child(drop)

func _spawn_item_drop(item_id: String) -> void:
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		return

	var drop = Area2D.new()
	drop.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	drop.collision_layer = 32
	drop.collision_mask = 0
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", item)

	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape_node.shape = circle
	drop.add_child(shape_node)

	var visual = Sprite2D.new()
	visual.texture = SpriteGenerator.get_texture("crystal_teal")
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rarity = item.get("rarity", 0)
	visual.modulate = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)
	drop.add_child(visual)

	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	_get_world_node().add_child(drop)

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	var label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10) if not is_crit else randf_range(-6, 6), -30)
	var settings = LabelSettings.new()
	settings.font_size = 14 if not is_crit else 28
	settings.font_color = Color.WHITE if not is_crit else Color(1.0, 0.95, 0.1)
	settings.outline_size = 2 if not is_crit else 3
	settings.outline_color = Color.BLACK
	label.label_settings = settings
	label.transform = IsometricHelper.get_sprite_counter_transform()
	add_child(label)
	var tween = create_tween()
	if is_crit:
		# Pop scale in, then float up and fade
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
	tween.tween_callback(label.queue_free)

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.set_value(stats.current_hp, stats.max_hp)
		if not _is_selected:
			hp_bar.visible = stats.current_hp < stats.max_hp

func get_stats_dict() -> Dictionary:
	return stats.get_stats_dict()

func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _get_world_node() -> Node:
	# Return the World node (holds the iso transform) so spawned objects
	# appear at the correct isometric position.
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		return world[0]
	return get_tree().current_scene
