extends Area2D
class_name CombatPickup

## Phase 2.12: drop-on-kill pickup. Floats with a bob, magnetizes to the
## player within MAGNET_RADIUS, fades after LIFETIME_SEC if uncollected.
##
## Types: &"momentum" / &"health" / &"cooldown_orb"
## Each type applies a different effect when collected.
##
## Spawned by enemy.gd._die() with a per-type roll. No spawner autoload —
## the enemy is the spawner.

const MAGNET_RADIUS_SQ: float = 90.0 * 90.0
const COLLECT_RADIUS_SQ: float = 14.0 * 14.0
const MAGNET_SPEED: float = 320.0
const LIFETIME_SEC: float = 9.0
const BOB_AMPLITUDE: float = 3.0
const BOB_PERIOD_SEC: float = 0.7

@export var pickup_type: StringName = &"momentum"
@export var magnitude: float = 15.0

var _bob_phase: float = 0.0
var _spawn_msec: int = 0
var _visual: Sprite2D = null
var _collected: bool = false
var _base_y: float = 0.0


func _ready() -> void:
	collision_layer = 64  # match the existing ground_items convention
	collision_mask = 0
	monitoring = false
	monitorable = false
	# Build collision shape.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	# Build visual.
	_visual = Sprite2D.new()
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match pickup_type:
		&"momentum":
			_visual.texture = SpriteGenerator.get_texture("crystal_teal")
			if _visual.texture == null:
				_visual.texture = SpriteGenerator.get_texture("crystal_white")
			_visual.modulate = Color(1.3, 0.85, 0.2)
		&"health":
			_visual.texture = SpriteGenerator.get_texture("crystal_white")
			_visual.modulate = Color(1.5, 0.35, 0.35)
		&"cooldown_orb":
			_visual.texture = SpriteGenerator.get_texture("crystal_white")
			_visual.modulate = Color(0.5, 1.1, 1.6)
		_:
			_visual.texture = SpriteGenerator.get_texture("crystal_white")
			_visual.modulate = Color.WHITE
	_visual.scale = Vector2(0.9, 0.9)
	add_child(_visual)
	# Glow pulse loop on the visual.
	var pulse := _visual.create_tween().set_loops()
	pulse.tween_property(_visual, "scale", Vector2(1.1, 1.1), 0.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_visual, "scale", Vector2(0.9, 0.9), 0.4).set_trans(Tween.TRANS_SINE)
	_spawn_msec = Time.get_ticks_msec()
	_base_y = position.y


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_bob_phase += delta / BOB_PERIOD_SEC
	if _visual != null:
		_visual.position.y = sin(_bob_phase * TAU) * BOB_AMPLITUDE

	# Lifetime / fade.
	var age_msec: int = Time.get_ticks_msec() - _spawn_msec
	if float(age_msec) / 1000.0 > LIFETIME_SEC:
		queue_free()
		return
	# Last 1.5s: fade.
	var fade_start_ms: int = int((LIFETIME_SEC - 1.5) * 1000.0)
	if age_msec > fade_start_ms and _visual != null:
		var t: float = (float(age_msec) - float(fade_start_ms)) / 1500.0
		_visual.modulate.a = clamp(1.0 - t, 0.0, 1.0)

	# Find player and check magnet / collect range.
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0] as Node2D
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var d_sq: float = to_player.length_squared()
	if d_sq < COLLECT_RADIUS_SQ:
		_collect(player)
		return
	if d_sq < MAGNET_RADIUS_SQ:
		# Magnet snap with eased acceleration.
		var step: float = MAGNET_SPEED * delta
		if to_player.length() > step:
			global_position += to_player.normalized() * step
		else:
			global_position = player.global_position


func _collect(player: Node2D) -> void:
	_collected = true
	# Apply the effect.
	match pickup_type:
		&"momentum":
			var mom = player.get_node_or_null("MomentumComponent")
			if mom != null and mom.has_method("add_bonus"):
				mom.add_bonus(float(magnitude), &"pickup_momentum")
		&"health":
			# Heal a flat amount via stats.
			if player.has_method("heal"):
				player.heal(int(magnitude))
			elif "stats" in player:
				var s = player.get("stats")
				if s != null and s.has_method("take_damage"):
					# take_damage with negative is a hack; rely on stat fields instead.
					if "current_hp" in s and "max_hp" in s:
						s.current_hp = min(int(s.max_hp), int(s.current_hp) + int(magnitude))
		&"cooldown_orb":
			# Clear the dodge cooldown.
			var dc = player.get_node_or_null("DodgeController")
			if dc != null and dc.has_method("force_reset"):
				dc.force_reset()
	# Audio + visual burst.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", -2.0)
	if _visual != null:
		var t := _visual.create_tween()
		t.set_parallel(true)
		t.tween_property(_visual, "scale", Vector2(2.5, 2.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_visual, "modulate:a", 0.0, 0.2)
		t.set_parallel(false)
		t.tween_callback(queue_free)
	else:
		queue_free()
