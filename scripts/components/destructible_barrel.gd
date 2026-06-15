extends Node2D
class_name DestructibleBarrel

## Phase 7 — explosive barrel. Hit it to break it; explosion damages
## any nearby enemies. Knockback can be used to push enemies INTO the
## barrel which is the most satisfying use.
##
## Joins the "enemies" group so the player's attack auto-targets work
## on it; minimal stub take_damage / apply_knockback / get_stats_dict
## interface so the existing damage pipeline works without changes.

const MAX_HP: int = 18
const EXPLOSION_RADIUS: float = 110.0
const EXPLOSION_DAMAGE: int = 28
const KNOCKBACK_FORCE: float = 130.0

@onready var sprite: Sprite2D = Sprite2D.new()
@onready var area: Area2D = Area2D.new()

var _hp: int = MAX_HP
var _is_dead: bool = false
var _is_sleeping: bool = false  # for compatibility with enemy queries
var _knockback_velocity: Vector2 = Vector2.ZERO
var stats: Object = null  # set in _ready


func _ready() -> void:
	add_to_group("enemies")  # so player's _enemies_in_range picks us up
	add_to_group("destructible_barrels")

	# Visual: small barrel made from crystal_teal texture tinted brown.
	var tex = SpriteGenerator.get_texture("crystal_teal")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(0.85, 0.55, 0.25)  # warm wood
	sprite.scale = Vector2(1.4, 1.7)
	sprite.z_index = 1
	add_child(sprite)

	# Collision shape for player swing hit detection.
	area.collision_layer = 2  # enemy layer so attack_area picks us up
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

	# Stub stats so CombatManager / poise / status systems don't error.
	stats = _BarrelStats.new()
	stats.current_hp = MAX_HP
	stats.max_hp = MAX_HP
	stats.attack_damage = 0
	stats.armor = 0
	stats.weapon_damage = 0
	stats.agility = 0
	stats.strength = 0
	stats.intelligence = 0


# Stat-component stub — barrels don't have a real StatsComponent.
class _BarrelStats:
	extends RefCounted
	var current_hp: int = 18
	var max_hp: int = 18
	var attack_damage: int = 0
	var armor: int = 0
	var weapon_damage: int = 0
	var agility: int = 0
	var strength: int = 0
	var intelligence: int = 0

	func take_damage(amount: int) -> void:
		current_hp = max(0, current_hp - amount)


# Compatibility surface — mirrors the enemy.gd interface used by
# CombatManager / player / etc.

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return
	_hp = max(0, _hp - amount)
	stats.current_hp = _hp
	# Brief flash for feedback.
	var t := sprite.create_tween()
	t.tween_property(sprite, "modulate", Color(1.5, 1.0, 0.5), 0.05)
	t.tween_property(sprite, "modulate", Color(0.85, 0.55, 0.25), 0.12)
	if _hp <= 0:
		_explode()


func apply_knockback(direction: Vector2, force: float) -> void:
	# Barrels can be shoved (toward enemies, even into explosives).
	if _is_dead:
		return
	_knockback_velocity = direction.normalized() * force


func get_stats_dict() -> Dictionary:
	return {
		"attack_damage": 0,
		"primary_stat": "strength",
		"strength": 0,
		"agility": 0,
		"intelligence": 0,
		"weapon_damage": 0,
		"armor": 0,
	}


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _knockback_velocity.length_squared() > 4.0:
		global_position += _knockback_velocity * delta
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)


func _explode() -> void:
	_is_dead = true
	# Visual: big orange ring + flash.
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("crystal_white")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.global_position = global_position
		ring.modulate = Color(1.7, 0.7, 0.15, 0.95)
		ring.scale = Vector2(0.6, 0.6)
		ring.z_index = 6
		get_parent().add_child(ring)
		var t := ring.create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(EXPLOSION_RADIUS / 16.0, EXPLOSION_RADIUS / 16.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)

	# Wooden chunks for visual variety.
	var chunk_tex = SpriteGenerator.get_texture("rat_gib")
	if chunk_tex != null:
		for _i in range(randi_range(10, 16)):
			var chunk := Sprite2D.new()
			chunk.texture = chunk_tex
			chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			chunk.global_position = global_position
			chunk.modulate = Color(0.7, 0.45, 0.2, 0.9)  # wooden brown
			chunk.scale = Vector2(randf_range(0.6, 1.2), randf_range(0.6, 1.2))
			chunk.z_index = 1
			get_parent().add_child(chunk)
			var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var force := randf_range(60, 140)
			var apex := chunk.global_position + dir * force * 0.5 + Vector2(0, -randf_range(15, 35))
			var dest := chunk.global_position + dir * force + Vector2(0, randf_range(8, 18))
			var ct := chunk.create_tween()
			ct.set_parallel(true)
			ct.tween_property(chunk, "global_position", apex, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ct.tween_property(chunk, "rotation", randf_range(-10.0, 10.0), 0.4)
			ct.set_parallel(false)
			ct.tween_property(chunk, "global_position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			ct.tween_property(chunk, "modulate:a", 0.0, 0.6)
			ct.tween_callback(chunk.queue_free)

	# Damage all enemies within radius (including OTHER destructibles
	# — chain reactions). Also knock them away.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		var is_dead = e.get("_is_dead")
		if is_dead:
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length_squared() > EXPLOSION_RADIUS * EXPLOSION_RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(EXPLOSION_DAMAGE, false)
		if to_e.length() > 0.01 and e.has_method("apply_knockback"):
			e.apply_knockback(to_e.normalized(), KNOCKBACK_FORCE)

	# Hit the player too if they're standing on it.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0]
		if is_instance_valid(player) and player.global_position.distance_squared_to(global_position) <= EXPLOSION_RADIUS * EXPLOSION_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(int(EXPLOSION_DAMAGE * 0.5), false)  # half damage to player

	# Screen shake.
	if not players.is_empty():
		var player2: Node2D = players[0]
		if is_instance_valid(player2) and player2.has_method("_do_screen_shake"):
			player2._do_screen_shake(7.0)

	# Audio.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", 1.5)

	queue_free()
