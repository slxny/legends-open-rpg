extends Node
class_name HitReactionComponent

## Phase 1B.3: enemy hit-reaction component (plan §6 Stage 1B.3, corr. 9/10).
##
## Attach as a child of an enemy node. Owner code calls react(hit_event,
## was_crit) when CombatManager.hit_resolved is emitted for that enemy.
##
## Three independent layers (plan §3):
##   1. Visual flinch — squash/stretch + rotation + modulate on
##      `reaction_pivot`. No reparenting. If no pivot is assigned the
##      component falls back to transform-only writes on the pivot it
##      finds (typically the existing main Sprite2D). Original transform
##      captured on first reaction, restored exactly on completion.
##   2. Physical knockback — emits `knockback_requested(direction,
##      force)`. Owner code is the sole writer of velocity; the component
##      never touches CharacterBody2D directly.
##   3. AI stagger — emits `stagger_requested(duration_ms)` and
##      `stagger_ended()`. Owner code decides whether to interrupt and
##      what state to enter next. Per plan corr. 10 the stagger-end
##      handler MUST re-evaluate the appropriate state from current
##      conditions, not blindly restore the prior state.
##
## Repeated-hit dampening: within profile.min_interval_ms only a reduced
## visual flash fires. Knockback and stagger are skipped until the
## interval elapses, so rapid hits cannot stun-lock an enemy beyond
## the design.
##
## Death override: when the owner enters a dying state it should call
## cancel_reaction() so any in-flight tween restores the pivot to its
## original transform and the death sequence takes over.

signal knockback_requested(direction: Vector2, force: float)
signal stagger_requested(duration_ms: int)
signal stagger_ended()
signal reaction_visual_finished()

@export var reaction_pivot: Node2D
@export var profile: Resource  # HitReactionData; falls back to LIGHT preset

const HitReactionDataCls := preload("res://scripts/data/hit_reaction_data.gd")

var _generation: int = 0
var _last_reaction_usec: int = 0
var _in_stagger: bool = false
var _orig_position: Vector2 = Vector2.ZERO
var _orig_scale: Vector2 = Vector2.ONE
var _orig_rotation: float = 0.0
var _orig_modulate: Color = Color.WHITE
var _orig_captured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if profile == null:
		profile = HitReactionDataCls.new().apply_preset(0)  # Tier.LIGHT = 0
	if reaction_pivot != null:
		_capture_originals()


## Owner calls this after CombatManager.hit_resolved fires for this
## enemy. `direction` is the world-space hit direction (will be
## normalized). `incoming_force` is the attack's raw knockback force;
## profile applies knockback_scalar and resistance.
func react(direction: Vector2, incoming_force: float, was_crit: bool, was_heavy: bool) -> void:
	if reaction_pivot == null:
		return
	if profile == null:
		return
	if not _orig_captured:
		_capture_originals()

	var now: int = Time.get_ticks_usec()
	var since_ms: int = (now - _last_reaction_usec) / 1000
	var dampened: bool = since_ms < int(profile.min_interval_ms) and _last_reaction_usec > 0
	_last_reaction_usec = now

	# Visual layer always runs; dampening just shortens it.
	_play_visual(direction, dampened, was_crit)

	if dampened:
		# Skip the physical and stagger layers — prevents stun lock.
		return

	# Physical layer — emit, owner applies (per plan: component does not
	# write velocity).
	var force_out: float = incoming_force * float(profile.knockback_scalar) * (1.0 - float(profile.knockback_resistance))
	if force_out > 0.01 and direction.length() > 0.01:
		knockback_requested.emit(direction.normalized(), force_out)

	# Stagger layer.
	var should_stagger: bool = int(profile.stagger_ms) > 0
	if should_stagger and bool(profile.stagger_only_heavy) and not (was_crit or was_heavy):
		should_stagger = false
	if should_stagger and float(profile.stagger_resistance) >= 1.0:
		should_stagger = false
	if should_stagger and float(profile.stagger_resistance) > 0.0:
		# Probabilistic resistance: weak hits more likely to be resisted.
		var resist_roll: float = randf()
		if resist_roll < float(profile.stagger_resistance):
			should_stagger = false
	if should_stagger:
		_begin_stagger(int(profile.stagger_ms))


## Owner code calls this when transitioning into death animation so the
## flinch tween doesn't fight death visuals. Returns the pivot to its
## captured original transform.
func cancel_reaction() -> void:
	_generation += 1
	if _orig_captured and reaction_pivot != null and is_instance_valid(reaction_pivot):
		reaction_pivot.position = _orig_position
		reaction_pivot.scale = _orig_scale
		reaction_pivot.rotation = _orig_rotation
		reaction_pivot.modulate = _orig_modulate
	if _in_stagger:
		_in_stagger = false
		stagger_ended.emit()


func is_staggered() -> bool:
	return _in_stagger


func _capture_originals() -> void:
	if reaction_pivot == null or not is_instance_valid(reaction_pivot):
		return
	_orig_position = reaction_pivot.position
	_orig_scale = reaction_pivot.scale
	_orig_rotation = reaction_pivot.rotation
	_orig_modulate = reaction_pivot.modulate
	_orig_captured = true


func _play_visual(direction: Vector2, dampened: bool, was_crit: bool) -> void:
	_generation += 1
	var gen: int = _generation

	var dur: float = float(profile.visual_duration_sec)
	if dampened:
		dur *= 0.35

	var recoil_distance: float = float(profile.visual_recoil_distance)
	var recoil_dir: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
	var squash: Vector2 = profile.visual_squash
	var rot: float = float(profile.visual_rotation_rad)
	var flash: float = float(profile.hit_flash_strength)

	if dampened:
		recoil_distance *= 0.4
		squash = Vector2(1.0 + (squash.x - 1.0) * 0.4, 1.0 + (squash.y - 1.0) * 0.4)
		rot *= 0.4

	var target_pos := _orig_position + recoil_dir * recoil_distance
	var target_rot := _orig_rotation + (rot if recoil_dir.x >= 0.0 else -rot)
	var flash_color := Color(_orig_modulate.r * flash, _orig_modulate.g * flash, _orig_modulate.b * flash, _orig_modulate.a)

	var pivot: Node2D = reaction_pivot
	if pivot == null:
		return

	# Instant snap to recoil pose then tween back to original. Generation
	# guard prevents a newer reaction's restoration from being overwritten
	# by an older one.
	pivot.position = target_pos
	pivot.scale = squash
	pivot.rotation = target_rot
	pivot.modulate = flash_color

	var t := pivot.create_tween()
	t.set_parallel(true)
	t.tween_property(pivot, "position", _orig_position, dur)
	t.tween_property(pivot, "scale", _orig_scale, dur)
	t.tween_property(pivot, "rotation", _orig_rotation, dur)
	t.tween_property(pivot, "modulate", _orig_modulate, dur * 0.7)
	t.set_parallel(false)
	t.tween_callback(func() -> void:
		if gen != _generation:
			return
		if pivot != null and is_instance_valid(pivot):
			pivot.position = _orig_position
			pivot.scale = _orig_scale
			pivot.rotation = _orig_rotation
			pivot.modulate = _orig_modulate
		reaction_visual_finished.emit())


func _begin_stagger(duration_ms: int) -> void:
	if _in_stagger:
		# Replace: longer wins.
		stagger_requested.emit(duration_ms)
		return
	_in_stagger = true
	stagger_requested.emit(duration_ms)
	# Schedule end via SceneTreeTimer on wall-clock; this is "gameplay"
	# stagger, so it follows the engine's pausable time.
	get_tree().create_timer(float(duration_ms) / 1000.0).timeout.connect(func() -> void:
		_in_stagger = false
		stagger_ended.emit())
