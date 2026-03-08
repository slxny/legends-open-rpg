extends StaticBody2D

## Watchtower — player-built defensive structure with archers.
## Attacks nearby enemies, grants XP to the player for kills.
## Walk near and click (or press E) to repair with wood. Upgraded via woodworker.

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

# Heal cost: wood per repair
const HEAL_WOOD_COST: int = 2
const HEAL_AMOUNT: int = 40
const HEAL_RANGE_SQ: float = 14400.0  # 120px
const REPAIR_COOLDOWN: float = 0.4
var _repair_timer: float = 0.0

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

func setup(level: int, hp: int = -1) -> void:
	tower_level = level
	_apply_level_stats()
	if hp >= 0:
		current_hp = min(hp, max_hp)
	else:
		current_hp = max_hp
	_update_hp_bar()

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
	if current_hp >= max_hp:
		if _repair_prompt_visible:
			_repair_label.visible = false
			_repair_prompt_visible = false
		return
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	var should_show = dist_sq <= HEAL_RANGE_SQ
	if should_show != _repair_prompt_visible:
		_repair_prompt_visible = should_show
		_repair_label.visible = should_show

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
			Color(1.0, 0.9, 0.4)
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
	_save_hp()

	# Green flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 1.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

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

func _do_hit_flash() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_destroyed:
		return
	var clicked = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true

	if clicked:
		_try_heal()

func _unhandled_input(event: InputEvent) -> void:
	if _is_destroyed or not _repair_prompt_visible:
		return
	# E key to repair when near
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_heal()
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

func _get_player() -> Node2D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		return _cached_player
	return null
