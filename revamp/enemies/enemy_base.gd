extends CharacterBody2D
class_name RevampEnemy

## Shared base for all revamp enemies. Owns HP, hit-flash, knockback,
## death pop, a tiny FSM (idle / pursue / attack / wind-up / recover),
## damage-type resistance hook for CombatManager.

signal hp_changed(current: float, maximum: float)
signal died()

const RESIST_DEFAULT := {}
const KNOCKBACK_DECAY := 6.5
const SEPARATION_RADIUS := 36.0
const SEPARATION_FORCE := 220.0

@export var max_hp: float = 60.0
@export var damage: float = 14.0
@export var move_speed: float = 110.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.4
@export var aggro_range: float = 520.0
@export var color_primary: Color = Color(0.45, 0.30, 0.60)
@export var color_secondary: Color = Color(0.18, 0.12, 0.22)
@export var glow_color: Color = Color(0.6, 0.4, 1.0)
@export var family: StringName = &"cultist"
@export var xp_value: int = 20

var current_hp: float = 0.0
var state: StringName = &"idle"
var target: Node2D
var _attack_ready_at: float = 0.0
var _hit_flash_until_ms: int = 0
var _knockback: Vector2 = Vector2.ZERO
var _external_motion: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.RIGHT
var _t: float = 0.0
var _wind_up_until: float = 0.0
var _recover_until: float = 0.0
var _bob_phase: float = 0.0
var _facing_x: float = 1.0


func _ready() -> void:
	current_hp = max_hp
	add_to_group("revamp_enemies")
	add_to_group("enemies")
	collision_layer = 1 << 1
	collision_mask = (1 << 2) | (1 << 1)  # environment + other enemies
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 32.0
	shape.shape = cap
	add_child(shape)
	z_index = 3
	_bob_phase = randf() * TAU
	_build_visual()
	hp_changed.emit(current_hp, max_hp)


func _build_visual() -> void:
	# Drop shadow
	var sh := Polygon2D.new()
	sh.color = Color(0, 0, 0, 0.4)
	sh.polygon = _ellipse(Vector2(0, 20), 22, 8, 16)
	sh.z_index = -1
	add_child(sh)
	# Override in subclasses for distinct silhouettes.


func _physics_process(delta: float) -> void:
	_t += delta
	var now_s: float = Time.get_ticks_msec() * 0.001
	_update_target()
	_run_fsm(now_s, delta)
	_apply_motion(delta)
	_facing_from_velocity()


func _update_target() -> void:
	if not is_instance_valid(target):
		var tree := get_tree()
		if tree:
			var players := tree.get_nodes_in_group("revamp_player")
			if players.size() > 0:
				target = players[0]


func _run_fsm(now_s: float, delta: float) -> void:
	if not is_instance_valid(target):
		state = &"idle"
		velocity = Vector2.ZERO
		return
	var dist: float = global_position.distance_to(target.global_position)
	match state:
		&"idle":
			if dist < aggro_range:
				state = &"pursue"
		&"pursue":
			_pursue_logic(dist)
			if dist <= attack_range and now_s >= _attack_ready_at:
				_begin_attack(now_s)
		&"wind_up":
			velocity = Vector2.ZERO
			if now_s >= _wind_up_until:
				_release_attack()
				_recover_until = now_s + 0.35
				state = &"recover"
		&"recover":
			velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
			if now_s >= _recover_until:
				_attack_ready_at = now_s + attack_cooldown
				state = &"pursue"


func _pursue_logic(_dist: float) -> void:
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	_aim = to_target
	var sep: Vector2 = _separation_offset()
	velocity = (to_target + sep).normalized() * move_speed


func _separation_offset() -> Vector2:
	# Push away from nearby allies so packs don't collapse to a point.
	var push: Vector2 = Vector2.ZERO
	var tree := get_tree()
	if tree == null:
		return push
	for e in tree.get_nodes_in_group("revamp_enemies"):
		if e == self or not (e is Node2D):
			continue
		var d: Vector2 = global_position - e.global_position
		var dist: float = d.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			push += d.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return push * 0.6


func _begin_attack(now_s: float) -> void:
	_wind_up_until = now_s + windup_seconds()
	state = &"wind_up"
	_on_windup_begin()


func windup_seconds() -> float:
	return 0.35


func _on_windup_begin() -> void:
	pass


func _release_attack() -> void:
	# Default melee swing
	if not is_instance_valid(target):
		return
	var dist: float = global_position.distance_to(target.global_position)
	if dist <= attack_range * 1.15 and target.has_method("take_damage"):
		target.take_damage(damage, false)


func _apply_motion(delta: float) -> void:
	# Knockback overlay
	_knockback = _knockback.lerp(Vector2.ZERO, clampf(delta * KNOCKBACK_DECAY, 0.0, 1.0))
	# External motion (gravity sigil pull)
	var ext: Vector2 = _external_motion
	_external_motion = Vector2.ZERO
	velocity += _knockback + ext
	move_and_slide()


func _facing_from_velocity() -> void:
	if absf(velocity.x) > 6.0:
		_facing_x = signf(velocity.x)


func get_facing_x() -> float:
	return _facing_x


# === Damage / death ===

func take_damage(amount: float, is_crit: bool = false) -> void:
	current_hp = maxf(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	_hit_flash_until_ms = Time.get_ticks_msec() + 110
	# Knockback toward away-from-attacker (use last hit dir approximation via aim)
	var kb_dir: Vector2 = -_aim
	if is_instance_valid(target):
		kb_dir = (global_position - target.global_position).normalized()
	_knockback += kb_dir * (160.0 if is_crit else 90.0)
	if current_hp <= 0.0:
		_on_death()


func apply_external_motion(v: Vector2) -> void:
	_external_motion += v


func _on_death() -> void:
	died.emit()
	# Pop visual
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 0.0), 0.18)
	tw.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.18)
	tw.tween_callback(queue_free)
	_drop_xp_orb()


func _drop_xp_orb() -> void:
	# Lightweight XP orb that floats to the player.
	const XPOrb := preload("res://revamp/effects/xp_orb.gd")
	var orb := XPOrb.new()
	orb.global_position = global_position
	orb.value = xp_value
	get_parent().add_child(orb)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _hit_flash_until_ms:
		modulate = Color(2.4, 2.0, 2.0)
	else:
		modulate = Color.WHITE
	# subtle bob from base
	var body: Node = get_node_or_null("Body")
	if body and body is Node2D:
		body.position.y = sin(_t * 4.5 + _bob_phase) * 1.6


func get_defense_stats() -> Dictionary:
	return {"armor": 0}


func get_resistance(damage_type: StringName) -> float:
	# Per-family resist hook. CombatManager multiplies damage by this.
	return float(RESIST_DEFAULT.get(damage_type, 1.0))


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return arr


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr
