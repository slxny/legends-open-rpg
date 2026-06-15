extends Node
class_name DodgeController

## Phase 2.3: dodge state + i-frames + perfect-dodge detection.
##
## Plan corr.: introduction, not extraction — no dodge exists today.
## player.gd remains the sole writer of CharacterBody2D.velocity. This
## controller exposes a velocity OVERLAY that the player applies and
## a query (is_iframes_active) the take_damage path consults.
##
## Perfect-dodge detection only — the reward (momentum refund, attacker
## slow, counterattack) ships in Phase 2.5 once Momentum exists.
##
## Process mode = PAUSABLE so pause halts the dodge naturally.

signal dodge_started(direction: Vector2)
signal dodge_ended()
signal iframes_changed(active: bool)
## Emitted when a hit lands while the player is in the perfect-dodge
## window. Subscribers (Phase 2.5) award momentum / slow the attacker.
signal perfect_dodge_executed(against_attack_id: StringName)

@export var data: Resource  # DodgeData

const DodgeDataCls := preload("res://scripts/data/dodge_data.gd")

var _active: bool = false
var _direction: Vector2 = Vector2.ZERO
var _start_usec: int = 0
var _cooldown_until_usec: int = 0
var _iframes_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if data == null:
		data = DodgeDataCls.new()


func _process(_delta: float) -> void:
	if not _active:
		return
	var now: int = Time.get_ticks_usec()
	var elapsed_ms: int = (now - _start_usec) / 1000

	# Toggle i-frames off at the configured threshold (still during dodge
	# motion). Emits change signal for UI / sfx subscribers.
	if _iframes_active and elapsed_ms >= int(data.iframes_ms):
		_iframes_active = false
		iframes_changed.emit(false)

	# End dodge.
	if elapsed_ms >= int(data.duration_ms):
		_active = false
		_direction = Vector2.ZERO
		if _iframes_active:
			_iframes_active = false
			iframes_changed.emit(false)
		_cooldown_until_usec = now + int(data.cooldown_ms) * 1000
		dodge_ended.emit()


## Owner code calls this on the dodge input press. `direction` is the
## player's current movement direction (or facing fallback). Returns true
## if accepted, false if on cooldown or already active.
func request_dodge(direction: Vector2) -> bool:
	if _active:
		return false
	var now: int = Time.get_ticks_usec()
	if now < _cooldown_until_usec:
		return false
	if direction.length() < 0.05:
		# Default forward when no direction input.
		direction = Vector2(1, 0)
	_direction = direction.normalized()
	_active = true
	_iframes_active = true
	_start_usec = now
	dodge_started.emit(_direction)
	iframes_changed.emit(true)
	return true


## Velocity overlay for the current dodge tick. player.gd writes this
## directly into `velocity` (replacing movement input for the duration).
func get_velocity_overlay() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var now: int = Time.get_ticks_usec()
	var elapsed_ms: int = (now - _start_usec) / 1000
	var t: float = clamp(float(elapsed_ms) / max(1.0, float(data.duration_ms)), 0.0, 1.0)
	var k: float
	var curve = data.velocity_curve
	if curve != null:
		k = clamp(curve.sample(t), 0.0, 1.0)
	else:
		# Analytical ease-out: starts at 60% of peak so the first frame
		# already feels punchy (no zero-velocity transient), ramps to
		# peak around t = 0.25, then decays smoothly to 0 at t = 1.
		if t < 0.25:
			k = 0.6 + 0.4 * (t / 0.25)
		else:
			k = 1.0 - smoothstep(0.25, 1.0, t)
	return _direction * float(data.max_speed) * k


func is_active() -> bool:
	return _active


func is_iframes_active() -> bool:
	return _iframes_active


func is_perfect_window() -> bool:
	if not _active:
		return false
	var elapsed_ms: int = (Time.get_ticks_usec() - _start_usec) / 1000
	return elapsed_ms <= int(data.perfect_window_ms)


## Owner calls this from take_damage BEFORE applying damage.
##   - returns true if the damage should be absorbed (i-frames active)
##   - emits perfect_dodge_executed when the hit lands in the perfect window
func on_incoming_hit(attack_id: StringName) -> bool:
	if not _iframes_active:
		return false
	if is_perfect_window():
		perfect_dodge_executed.emit(attack_id)
	return true


## Idempotent — used on death / scene change.
func force_reset() -> void:
	if _active or _iframes_active:
		_active = false
		_iframes_active = false
		_direction = Vector2.ZERO
		iframes_changed.emit(false)
		dodge_ended.emit()
	_cooldown_until_usec = 0
