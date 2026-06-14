extends RefCounted
class_name AttackClock

## Phase 1A.4: normalized attack-progress driver (per plan corr. 7).
##
## A single Tween writes `progress` from 0.0 → 1.0 over the attack's
## *total gameplay duration* (wind-up + active + recovery). The visual
## sprite/Tween animations are independent — they may be longer, shorter,
## or staggered. All gameplay windows (contact, active hitbox, combo,
## dodge-cancel, etc.) are evaluated against `progress`, never against
## the visual Tween's elapsed time.
##
## Why: the audit found damage was fired via a `tween_callback` on the
## visual Tween's elapsed time, which decouples gameplay from the
## visible weapon contact frame and is fragile under speed scaling.
##
## Usage:
##   var clock := AttackClock.new()
##   clock.start(get_tree().create_tween(), 0.30, attack_speed_scalar)
##   # later, every frame:
##   if not last_was_in_active and clock.is_in_window(timing.active_window_start, timing.active_window_end):
##       enable_hitbox(...)
##   # on combo step requested:
##   if clock.is_in_window(timing.combo_window_start, timing.combo_window_end):
##       queue_next_step()
##
## Owner is responsible for cancelling on interrupt; cancel() also
## stops the underlying Tween if one was bound.

signal progress_changed(progress: float)
signal finished()
signal cancelled()

var progress: float = 0.0
var active: bool = false
var _tween: Tween
var _generation: int = 0
var _attack_id: StringName = &""


func start(tween: Tween, duration_sec: float, speed_scalar: float = 1.0, attack_id: StringName = &"") -> void:
	cancel()  # bump generation, drop any in-flight write
	_attack_id = attack_id
	progress = 0.0
	active = true
	var effective_duration: float = max(0.0001, duration_sec / max(0.01, speed_scalar))
	_tween = tween
	var gen: int = _generation
	# Inline closures capture `gen` and `self` so a stale tween cannot
	# corrupt a newer clock state. The active-flag guard covers cancel.
	_tween.tween_method(
		func(p: float) -> void:
			if gen != _generation:
				return
			if not active:
				return
			progress = clamp(p, 0.0, 1.0)
			emit_signal("progress_changed", progress),
		0.0, 1.0, effective_duration)
	_tween.finished.connect(
		func() -> void:
			if gen != _generation:
				return
			if not active:
				return
			progress = 1.0
			active = false
			_tween = null
			emit_signal("finished"))


func cancel() -> void:
	_generation += 1  # invalidates pending callbacks
	if active:
		active = false
		emit_signal("cancelled")
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func is_in_window(window_start: float, window_end: float) -> bool:
	if not active:
		return false
	return progress >= window_start and progress < window_end


func has_passed(threshold: float) -> bool:
	return progress >= threshold


func attack_id() -> StringName:
	return _attack_id


func _apply_progress(p: float, gen: int) -> void:
	if gen != _generation:
		return
	progress = clamp(p, 0.0, 1.0)
	emit_signal("progress_changed", progress)


func _on_tween_finished(gen: int) -> void:
	if gen != _generation:
		return
	if not active:
		return
	progress = 1.0
	active = false
	_tween = null
	emit_signal("finished")
