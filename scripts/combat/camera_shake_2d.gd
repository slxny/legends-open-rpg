extends Node2D
class_name CameraShake2D

## Phase 1B.2: trauma-model camera shake (plan §3 / §6 Stage 1B.2).
##
## Attach as a child of the Camera2D (Stage 1B.6 wires this into
## player.tscn). The shake node writes the camera's `offset` directly.
##
## Trauma model (Squirrel Eiserloh): trauma in [0, 1]. Offset = max_offset
## * trauma² * noise(t). Trauma decays linearly at trauma_decay per
## second. Squaring makes light impulses feel light and crit/finisher
## impulses feel proportionally heavier without a hard discontinuity.
##
## Directional impulse: an optional unit Vector2 nudges the noise center
## slightly toward the incoming hit direction so the shake feels
## "pushed" rather than radially symmetric.
##
## Accessibility: `intensity_scalar` ∈ [0, 1] applies to the final offset
## so the player can dial shake down without disabling the gameplay
## events themselves. 0 disables shake entirely.
##
## Drift guard: offset returns exactly to Vector2.ZERO when trauma <= 0.

@export var max_offset: Vector2 = Vector2(12.0, 12.0)
@export var trauma_decay: float = 2.5
@export_range(0.0, 1.0) var intensity_scalar: float = 1.0
@export var noise_speed: float = 35.0
@export var directional_push: float = 0.35  # 0 = pure radial, 1 = fully aligned

var _trauma: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _target: Node2D = null  # Camera2D parent — set on _ready


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_parent() as Node2D


## Add trauma. `amount` is unclamped here but `_trauma` is clamped to 1.0.
## `direction` is the hit's world-space direction (will be normalized).
func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0.0:
		return
	_trauma = clamp(_trauma + amount, 0.0, 1.0)
	if direction.length() > 0.01:
		# Blend toward the new direction so multiple hits in similar
		# directions reinforce, opposite hits cancel toward radial.
		var d := direction.normalized()
		_direction = (_direction + d * amount).normalized() if _direction.length() > 0.01 else d


## Idempotent. Resets trauma to 0 and restores the parent camera offset.
func force_reset() -> void:
	_trauma = 0.0
	_direction = Vector2.ZERO
	if _target != null and is_instance_valid(_target):
		# Don't blindly write — only if we've been writing to it.
		if _target is Camera2D:
			(_target as Camera2D).offset = Vector2.ZERO


func current_trauma() -> float:
	return _trauma


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		# Snap parent camera offset back to zero on the transition.
		if _target is Camera2D and (_target as Camera2D).offset != Vector2.ZERO:
			(_target as Camera2D).offset = Vector2.ZERO
		return

	_t += delta * noise_speed
	var s: float = _trauma * _trauma
	# Pseudo-noise via sin combinations — deterministic, no allocation.
	var nx: float = sin(_t * 1.0)
	var ny: float = sin(_t * 1.7 + 1.3)
	var radial := Vector2(nx, ny)
	var directional := _direction * directional_push if _direction.length() > 0.01 else Vector2.ZERO
	var raw := (radial + directional).limit_length(1.0)
	var offset := Vector2(max_offset.x * s * raw.x, max_offset.y * s * raw.y) * intensity_scalar

	if _target is Camera2D:
		(_target as Camera2D).offset = offset

	_trauma = max(0.0, _trauma - trauma_decay * delta)
	if _trauma <= 0.0:
		_direction = Vector2.ZERO
		if _target is Camera2D:
			(_target as Camera2D).offset = Vector2.ZERO


# --- Trauma presets used by CombatFeedbackProfile (Phase 1B later). ---
# Light hit feel: 0.18 trauma, fast decay.
# Crit / finisher: ~0.55. Boss event: ~0.85.
const TRAUMA_LIGHT := 0.18
const TRAUMA_MEDIUM := 0.30
const TRAUMA_HEAVY := 0.45
const TRAUMA_FINISHER := 0.55
const TRAUMA_CRIT := 0.55
const TRAUMA_ELITE_KILL := 0.70
const TRAUMA_BOSS_EVENT := 0.85
