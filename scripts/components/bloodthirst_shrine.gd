extends Node2D
class_name BloodthirstShrine

## Phase 3.8 F11 — encounter modifier: bloodthirst shrine.
## Pulses a 220 px aura of warm red. All enemies within deal +25% damage
## while the shrine is intact. Take it down (3 hits) and the modifier
## drops + bonus momentum is granted as the reward.
##
## Spawned by world generation at sparse locations.
##
## Joins "enemies" group so player attacks auto-target work. Tracks
## buffed enemies and clears their buff on death (via group cleanup).

const SHRINE_HP: int = 24
const AURA_RADIUS: float = 220.0
const AURA_RADIUS_SQ: float = AURA_RADIUS * AURA_RADIUS
const BUFF_DAMAGE_MULT: float = 1.25
const REWARD_MOMENTUM: float = 25.0

var _hp: int = SHRINE_HP
var _is_dead: bool = false
var _is_sleeping: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var stats: Object = null
@onready var sprite: Sprite2D = Sprite2D.new()
@onready var aura: Sprite2D = Sprite2D.new()
@onready var area: Area2D = Area2D.new()
var _aura_tween: Tween = null
var _buff_tween: Tween = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bloodthirst_shrines")

	# Aura — large pulsing ring beneath sprite.
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("crystal_white")
	aura.texture = ring_tex
	aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	aura.modulate = Color(1.6, 0.25, 0.15, 0.5)
	aura.scale = Vector2(AURA_RADIUS / 12.0, AURA_RADIUS / 12.0)
	aura.z_index = -2
	add_child(aura)
	_aura_tween = aura.create_tween().set_loops()
	_aura_tween.tween_property(aura, "scale", Vector2((AURA_RADIUS + 18) / 12.0, (AURA_RADIUS + 18) / 12.0), 0.9).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(aura, "scale", Vector2(AURA_RADIUS / 12.0, AURA_RADIUS / 12.0), 0.9).set_trans(Tween.TRANS_SINE)

	# Shrine sprite — tall red crystal-like object.
	var shrine_tex = SpriteGenerator.get_texture("crystal_white")
	if shrine_tex == null:
		shrine_tex = SpriteGenerator.get_texture("crystal_teal")
	sprite.texture = shrine_tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(1.4, 0.18, 0.18)
	sprite.scale = Vector2(1.8, 2.4)
	sprite.z_index = 1
	add_child(sprite)
	# Brief pulse loop on the shrine itself.
	_buff_tween = sprite.create_tween().set_loops()
	_buff_tween.tween_property(sprite, "modulate", Color(1.8, 0.4, 0.3), 0.5).set_trans(Tween.TRANS_SINE)
	_buff_tween.tween_property(sprite, "modulate", Color(1.4, 0.18, 0.18), 0.5).set_trans(Tween.TRANS_SINE)

	# Collision area for player attack hit detection.
	area.collision_layer = 2
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

	stats = _ShrineStats.new()
	stats.current_hp = SHRINE_HP
	stats.max_hp = SHRINE_HP


class _ShrineStats:
	extends RefCounted
	var current_hp: int = 24
	var max_hp: int = 24
	var attack_damage: int = 0
	var armor: int = 0
	var weapon_damage: int = 0
	var agility: int = 0
	var strength: int = 0
	var intelligence: int = 0
	func take_damage(amount: int) -> void:
		current_hp = max(0, current_hp - amount)


func take_damage(amount: int, _is_crit: bool = false) -> void:
	if _is_dead:
		return
	_hp = max(0, _hp - amount)
	stats.current_hp = _hp
	# Flash + shrink tick.
	if is_instance_valid(sprite):
		var prev_scale = sprite.scale
		var t := sprite.create_tween()
		t.tween_property(sprite, "scale", prev_scale * 0.92, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "scale", prev_scale, 0.10)
	if _hp <= 0:
		_break_shrine()


func apply_knockback(_direction: Vector2, _force: float) -> void:
	pass  # Shrines are immovable


func get_stats_dict() -> Dictionary:
	return {
		"attack_damage": 0, "primary_stat": "strength",
		"strength": 0, "agility": 0, "intelligence": 0,
		"weapon_damage": 0, "armor": 0,
	}


# Per-frame check from enemy.gd — they query is_shrine_buff_active.
# Cheap function any enemy can call to see if they should buff their
# damage. Keeps this system decoupled from enemy.gd internals.
func is_position_inside_aura(world_pos: Vector2) -> bool:
	if _is_dead:
		return false
	return global_position.distance_squared_to(world_pos) <= AURA_RADIUS_SQ


# Static helper: any nearby enemy can call to ask whether any active
# shrine boosts their position.
static func get_active_buff_multiplier(world_pos: Vector2, tree: SceneTree) -> float:
	for s in tree.get_nodes_in_group("bloodthirst_shrines"):
		if not is_instance_valid(s):
			continue
		if s.get("_is_dead"):
			continue
		if s.is_position_inside_aura(world_pos):
			return BUFF_DAMAGE_MULT
	return 1.0


func _break_shrine() -> void:
	_is_dead = true
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	if _buff_tween != null and _buff_tween.is_valid():
		_buff_tween.kill()

	# Reward: player momentum bonus.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0]
		if is_instance_valid(player):
			var mom = player.get_node_or_null("MomentumComponent")
			if mom != null and mom.has_method("add_bonus"):
				mom.add_bonus(REWARD_MOMENTUM, &"shrine_break")
			if player.has_method("_do_screen_shake"):
				player._do_screen_shake(9.0)

	# Visual: big red shockwave + collapse.
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("crystal_white")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.global_position = global_position
		ring.modulate = Color(1.7, 0.2, 0.2, 0.95)
		ring.scale = Vector2(0.6, 0.6)
		ring.z_index = 6
		get_parent().add_child(ring)
		var t := ring.create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(AURA_RADIUS / 10.0, AURA_RADIUS / 10.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)

	# Aura fades.
	if is_instance_valid(aura):
		var at := aura.create_tween()
		at.tween_property(aura, "modulate:a", 0.0, 0.4)

	# Shrine sprite shatters.
	if is_instance_valid(sprite):
		var st := sprite.create_tween()
		st.set_parallel(true)
		st.tween_property(sprite, "scale", sprite.scale * Vector2(1.4, 0.2), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(sprite, "modulate:a", 0.0, 0.30)
		st.set_parallel(false)
		st.tween_callback(queue_free)

	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", 2.5)
