extends StaticBody2D

## Watchtower — player-built defensive structure with archers.
## Attacks nearby enemies, grants XP to the player for kills.
## Walk near and click (or press E) to repair with wood. Press Q to upgrade directly.

signal destroyed

@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: ProgressBar = $HPBar

var tower_level: int = 1
var tower_index: int = 0  # Which slot (0-3) this tower occupies
var max_hp: int = 200
var current_hp: int = 200
var attack_damage: int = 8
var attack_range: float = 180.0
var attack_cooldown: float = 1.8
var _attack_timer: float = 0.0
var _is_destroyed: bool = false
var _cached_player: Node2D = null
var _target_scan_timer: float = 0.0
var _current_target: Node2D = null
var _is_mobile: bool = false
var _repair_prompt_visible: bool = false
var _repair_label: Label = null
var _upgrade_label: Label = null
var _upgrade_prompt_visible: bool = false

# Visual damage state
var _damage_tint: Color = Color.WHITE
var _smoke_timer: float = 0.0
var _smoke_active: bool = false
const SMOKE_INTERVAL: float = 0.35

# Heal cost: wood per repair
const HEAL_WOOD_COST: int = 2
const HEAL_AMOUNT: int = 40
const HEAL_RANGE_SQ: float = 14400.0  # 120px
const REPAIR_COOLDOWN: float = 0.4
var _repair_timer: float = 0.0

# Upgrade constants
const UPGRADE_BASE_COST: int = 15
const MAX_TOWER_LEVEL: int = 50
const UPGRADE_COOLDOWN: float = 0.5
var _upgrade_timer: float = 0.0

# Scan for enemies every 0.5s (not every frame)
const TARGET_SCAN_INTERVAL: float = 0.5

func _ready() -> void:
	add_to_group("watchtower")
	collision_layer = 4  # Environment
	collision_mask = 0
	_is_mobile = GameManager.is_mobile_device()

	# Sprite
	sprite.texture = SpriteGenerator.get_texture("watch_tower")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# HP bar setup
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.size = Vector2(56, 6)
	hp_bar.position = Vector2(-28, -72)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.7, 0.2)
	bar_style.set_corner_radius_all(1)
	hp_bar.add_theme_stylebox_override("fill", bar_style)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.12, 0.1, 0.8)
	bar_bg.set_corner_radius_all(1)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_bar.show_percentage = false

	# Shadow
	var shadow = Sprite2D.new()
	shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_index = -1
	add_child(shadow)

	# Clickable for healing
	input_pickable = true
	input_event.connect(_on_input_event)

	# Repair prompt label (shows when player is near and tower is damaged)
	_repair_label = Label.new()
	_repair_label.text = "[E] Repair (2 wood)" if not _is_mobile else "Tap to Repair"
	_repair_label.add_theme_font_size_override("font_size", 28 if _is_mobile else 11)
	_repair_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 0.9))
	_repair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_label.position = Vector2(-50, -84)
	_repair_label.visible = false
	add_child(_repair_label)

	# Upgrade prompt label (shows when player is near)
	_upgrade_label = Label.new()
	_upgrade_label.add_theme_font_size_override("font_size", 28 if _is_mobile else 11)
	_upgrade_label.add_theme_color_override("font_color", Color(0.18, 0.82, 0.44, 0.9))
	_upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_label.position = Vector2(-50, -96)
	_upgrade_label.visible = false
	add_child(_upgrade_label)
	_refresh_upgrade_label()

func setup(level: int, hp: int = -1, extra_levels: int = 0) -> void:
	tower_level = level + extra_levels
	_apply_level_stats()
	if hp >= 0:
		current_hp = min(hp, max_hp)
	else:
		current_hp = max_hp
	_update_hp_bar()
	_update_damage_visuals()
	if _upgrade_label:
		_refresh_upgrade_label()

func _apply_level_stats() -> void:
	# Each level: +30 HP, +3 ATK, +10 range (capped), -0.05s cooldown (capped)
	max_hp = 200 + (tower_level - 1) * 30
	attack_damage = 8 + (tower_level - 1) * 3
	attack_range = min(180.0 + (tower_level - 1) * 10.0, 350.0)
	attack_cooldown = max(1.8 - (tower_level - 1) * 0.05, 0.6)

func _process(delta: float) -> void:
	if _is_destroyed:
		return

	_attack_timer -= delta
	_target_scan_timer -= delta
	if _repair_timer > 0.0:
		_repair_timer -= delta
	if _upgrade_timer > 0.0:
		_upgrade_timer -= delta

	# Smoke puffs when critically damaged
	if _smoke_active:
		_smoke_timer -= delta
		if _smoke_timer <= 0.0:
			_smoke_timer = SMOKE_INTERVAL + randf_range(-0.1, 0.1)
			_spawn_smoke_puff()

	# Scan for targets periodically
	if _target_scan_timer <= 0.0:
		_target_scan_timer = TARGET_SCAN_INTERVAL
		_find_target()
		_update_repair_prompt()

	# Attack current target
	if _current_target and is_instance_valid(_current_target) and _attack_timer <= 0.0:
		var dist_sq = global_position.distance_squared_to(_current_target.global_position)
		var range_sq = attack_range * attack_range
		if dist_sq <= range_sq:
			_shoot_arrow(_current_target)
			_attack_timer = attack_cooldown
		else:
			_current_target = null

func _update_repair_prompt() -> void:
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	var near = dist_sq <= HEAL_RANGE_SQ

	# Repair prompt: only when damaged and near
	var show_repair = near and current_hp < max_hp
	if show_repair != _repair_prompt_visible:
		_repair_prompt_visible = show_repair
		_repair_label.visible = show_repair

	# Upgrade prompt: when near and not at max level
	var show_upgrade = near and _get_tower_extra_levels() < MAX_TOWER_LEVEL
	if show_upgrade != _upgrade_prompt_visible:
		_upgrade_prompt_visible = show_upgrade
		_upgrade_label.visible = show_upgrade

func _find_target() -> void:
	_current_target = null
	var range_sq = attack_range * attack_range
	var best_dist_sq = range_sq + 1.0
	var pos = global_position

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy._is_dead:
			continue
		var dist_sq = pos.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			_current_target = enemy

func _shoot_arrow(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Create arrow projectile visual
	var arrow = Sprite2D.new()
	arrow.texture = SpriteGenerator.get_texture("arrow_projectile")
	if not arrow.texture:
		# Fallback: small colored rect
		var img = Image.create(6, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.7, 0.5, 0.2))
		arrow.texture = ImageTexture.create_from_image(img)
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.z_index = 10
	arrow.global_position = global_position + Vector2(0, -48)  # Fire from top of tower

	# Rotate arrow toward target
	var dir = (target.global_position - arrow.global_position).normalized()
	arrow.rotation = dir.angle()

	# Add to world
	var world = get_parent()
	if world:
		world.add_child(arrow)
	else:
		arrow.queue_free()
		return

	# Tween arrow to target
	var flight_time = 0.15
	var tween = arrow.create_tween()
	var target_pos = target.global_position
	tween.tween_property(arrow, "global_position", target_pos, flight_time)
	tween.tween_callback(func():
		# Deal damage on arrival
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(attack_damage, false)
			# Check if kill — grant XP to player
			if target.stats and target.stats.current_hp <= 0:
				_grant_xp(target)
		arrow.queue_free()
	)

	AudioManager.play_sfx("arrow_shoot", -6.0)

func _grant_xp(enemy: Node2D) -> void:
	var player = _get_player()
	if player and player.stats:
		var xp = enemy.xp_reward if "xp_reward" in enemy else 10
		player.stats.add_xp(xp)
		GameManager.game_message.emit(
			"Watchtower kill! +%d XP" % xp,
			Color(0.25, 0.9, 0.5)
		)

func get_stats_dict() -> Dictionary:
	# Minimal stats dict for CombatManager.calculate_damage() compatibility
	return {
		"armor": tower_level * 2,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"dodge": 0.0,
		"strength": 0,
		"agility": 0,
		"intelligence": 0,
	}

func take_damage(amount: int, _is_crit: bool = false) -> void:
	if _is_destroyed:
		return
	current_hp = max(0, current_hp - amount)
	_update_hp_bar()
	_update_damage_visuals()
	_do_hit_flash()
	_save_hp()

	if current_hp <= 0:
		_destroy()

func _save_hp() -> void:
	# Update the multi-tower array
	if tower_index >= 0 and tower_index < GameManager.watchtowers.size():
		GameManager.watchtowers[tower_index]["hp"] = current_hp
	# Legacy single-tower field
	GameManager.watchtower_hp = current_hp

func _destroy() -> void:
	_is_destroyed = true
	# Mark slot as not built
	if tower_index >= 0 and tower_index < GameManager.watchtowers.size():
		GameManager.watchtowers[tower_index]["built"] = false
	# Legacy: if no towers remain, clear the flag
	if GameManager.get_watchtower_count() == 0:
		GameManager.watchtower_built = false
	GameManager.game_message.emit("A Watchtower has been destroyed!", Color(1.0, 0.3, 0.3))
	destroyed.emit()

	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)
	tween.tween_callback(queue_free)

func heal(amount: int) -> void:
	if _is_destroyed:
		return
	current_hp = min(current_hp + amount, max_hp)
	_update_hp_bar()
	_update_damage_visuals()
	_save_hp()

	# Green flash — returns to damage tint
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", _damage_tint, 0.2)

func _update_hp_bar() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	# Color based on HP percentage
	var pct = float(current_hp) / float(max_hp)
	var fill_style = StyleBoxFlat.new()
	fill_style.set_corner_radius_all(1)
	if pct > 0.6:
		fill_style.bg_color = Color(0.1, 0.7, 0.2)
	elif pct > 0.3:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.9, 0.2, 0.1)
	hp_bar.add_theme_stylebox_override("fill", fill_style)

func _update_damage_visuals() -> void:
	var pct = float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	if pct > 0.75:
		# Healthy — clean white
		_damage_tint = Color.WHITE
	elif pct > 0.5:
		# Light damage — slight darken, warm soot tint
		var t = inverse_lerp(0.75, 0.5, pct)
		_damage_tint = Color.WHITE.lerp(Color(0.85, 0.78, 0.7), t)
	elif pct > 0.3:
		# Moderate damage — noticeable darken, brownish char
		var t = inverse_lerp(0.5, 0.3, pct)
		_damage_tint = Color(0.85, 0.78, 0.7).lerp(Color(0.65, 0.55, 0.45), t)
	else:
		# Critical — dark scorched look
		var t = inverse_lerp(0.3, 0.0, pct)
		_damage_tint = Color(0.65, 0.55, 0.45).lerp(Color(0.45, 0.35, 0.3), t)
	sprite.modulate = _damage_tint
	# Toggle smoke
	_smoke_active = pct <= 0.3

func _spawn_smoke_puff() -> void:
	var world_nodes = get_tree().get_nodes_in_group("world")
	var world = world_nodes[0] if world_nodes.size() > 0 else get_tree().current_scene
	if not world:
		return
	var puff = Sprite2D.new()
	var tex = SpriteGenerator.get_texture("iso_shadow")
	if tex:
		puff.texture = tex
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puff.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-50, -35))
	puff.scale = Vector2(randf_range(0.3, 0.5), randf_range(0.3, 0.5))
	puff.modulate = Color(0.3, 0.3, 0.3, randf_range(0.4, 0.6))
	puff.z_index = 1
	world.add_child(puff)
	var dest = puff.global_position + Vector2(randf_range(-6, 6), randf_range(-18, -10))
	var t = puff.create_tween()
	t.set_parallel(true)
	t.tween_property(puff, "global_position", dest, randf_range(0.6, 1.0)).set_trans(Tween.TRANS_SINE)
	t.tween_property(puff, "scale", Vector2(randf_range(0.7, 1.0), randf_range(0.7, 1.0)), 0.8)
	t.tween_property(puff, "modulate:a", 0.0, 0.9)
	t.set_parallel(false)
	t.tween_callback(puff.queue_free)

func _do_hit_flash() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.08)
	tween.tween_property(sprite, "modulate", _damage_tint, 0.15)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_destroyed:
		return
	var clicked = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true

	if clicked:
		if current_hp < max_hp:
			_try_heal()
		else:
			_try_upgrade()

func _unhandled_input(event: InputEvent) -> void:
	if _is_destroyed:
		return
	if not event is InputEventKey or not event.pressed:
		return
	# E key to repair when near
	if event.keycode == KEY_E and _repair_prompt_visible:
		_try_heal()
		get_viewport().set_input_as_handled()
	# Q key to upgrade when near
	elif event.keycode == KEY_Q and _upgrade_prompt_visible:
		_try_upgrade()
		get_viewport().set_input_as_handled()

func _try_heal() -> void:
	if _repair_timer > 0.0:
		return
	if current_hp >= max_hp:
		GameManager.game_message.emit("Watchtower is at full health!", Color(0.7, 0.7, 0.7))
		return
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	if dist_sq > HEAL_RANGE_SQ:
		GameManager.game_message.emit("Too far to repair!", Color(1.0, 0.5, 0.3))
		return
	if not GameManager.spend_wood(HEAL_WOOD_COST):
		GameManager.game_message.emit("Need %d wood to repair!" % HEAL_WOOD_COST, Color(1.0, 0.3, 0.3))
		return
	heal(HEAL_AMOUNT)
	_repair_timer = REPAIR_COOLDOWN
	AudioManager.play_sfx("woodwork_bow", -6.0)
	GameManager.game_message.emit("Watchtower repaired! (+%d HP, -%d wood)" % [HEAL_AMOUNT, HEAL_WOOD_COST], Color(0.5, 1.0, 0.5))

func _get_tower_extra_levels() -> int:
	if tower_index >= 0 and tower_index < GameManager.watchtowers.size():
		return GameManager.watchtowers[tower_index].get("level", 0)
	return 0

func _get_upgrade_cost() -> int:
	var extra = _get_tower_extra_levels()
	return int(UPGRADE_BASE_COST * pow(extra + 1, 1.3))

func _refresh_upgrade_label() -> void:
	if not _upgrade_label:
		return
	var extra = _get_tower_extra_levels()
	var cost = _get_upgrade_cost()
	if _is_mobile:
		_upgrade_label.text = "Tap to Upgrade (Lv %d, %d wood)" % [extra + 1, cost]
	else:
		_upgrade_label.text = "[Q] Upgrade Lv %d (%d wood)" % [extra + 1, cost]

func _try_upgrade() -> void:
	if _upgrade_timer > 0.0:
		return
	var extra = _get_tower_extra_levels()
	if extra >= MAX_TOWER_LEVEL:
		GameManager.game_message.emit("Watchtower is at max upgrade level!", Color(0.7, 0.7, 0.7))
		return
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	if dist_sq > HEAL_RANGE_SQ:
		GameManager.game_message.emit("Too far to upgrade!", Color(1.0, 0.5, 0.3))
		return
	var cost = _get_upgrade_cost()
	if not GameManager.spend_wood(cost):
		GameManager.game_message.emit("Need %d wood to upgrade!" % cost, Color(1.0, 0.3, 0.3))
		return
	# Apply upgrade
	var new_extra = extra + 1
	if tower_index >= 0 and tower_index < GameManager.watchtowers.size():
		GameManager.watchtowers[tower_index]["level"] = new_extra
	var old_hp_pct = float(current_hp) / float(max_hp)
	tower_level = GameManager.woodwork_watchtower_level + new_extra
	_apply_level_stats()
	# Scale current HP proportionally so upgrade heals the new HP portion
	current_hp = int(old_hp_pct * max_hp) + 30
	current_hp = min(current_hp, max_hp)
	_update_hp_bar()
	_save_hp()
	_upgrade_timer = UPGRADE_COOLDOWN
	_refresh_upgrade_label()
	AudioManager.play_sfx("woodwork_bow", -6.0)
	_update_damage_visuals()
	# Emerald flash — returns to damage tint
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.4, 1.4, 0.55), 0.1)
	tween.tween_property(sprite, "modulate", _damage_tint, 0.25)
	GameManager.game_message.emit(
		"Watchtower upgraded to Lv %d! (+HP, +ATK, -%d wood)" % [new_extra, cost],
		Color(0.18, 0.82, 0.44)
	)

func _get_player() -> Node2D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		return _cached_player
	return null
