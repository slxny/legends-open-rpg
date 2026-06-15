extends Node
class_name PoiseComponent

## Phase 2.0: enemy poise pool component.
##
## Owner code (enemy.gd) creates this in _ready and assigns a profile.
## CombatManager.resolve_hit pumps poise damage in via take_poise_damage.
##
## Lifecycle:
##   capacity 100 → take_poise_damage(40) → 60
##   → no damage for regen_delay_ms → regen starts
##   → damage drops poise to 0 → poise_broken(break_vulnerability_ms)
##   → enemy enters vulnerability window
##   → break_vulnerability_ms passes → poise restored to capacity
##   → post_break_immune_ms passes → take_poise_damage works again
##
## process_mode = PROCESS_MODE_PAUSABLE — poise pauses with the game.

signal poise_changed(current: float, max: int)
signal poise_broken(vulnerability_ms: int)
signal poise_recovered()  # fires when break window ends

@export var profile: Resource  # PoiseProfile

const PoiseProfileCls := preload("res://scripts/data/poise_profile.gd")

var _current: float = 0.0
var _last_damage_usec: int = 0
var _is_broken: bool = false
var _post_break_immune_until_usec: int = 0
var _broken_until_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if profile == null:
		profile = PoiseProfileCls.new().apply_preset(0)
	_current = float(profile.capacity)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()

	# End broken window — restore full poise + start immunity timer.
	if _is_broken and now >= _broken_until_usec:
		_is_broken = false
		_current = float(profile.capacity)
		_post_break_immune_until_usec = now + int(profile.post_break_immune_ms) * 1000
		poise_recovered.emit()
		poise_changed.emit(_current, int(profile.capacity))
		return

	if _is_broken:
		return

	# Regen after no-damage window — wall-clock so it doesn't depend on
	# Engine.time_scale (which can dip during crits).
	if _current >= float(profile.capacity):
		return
	var since_damage_ms: int = (now - _last_damage_usec) / 1000
	if since_damage_ms < int(profile.regen_delay_ms):
		return
	_current = min(float(profile.capacity), _current + float(profile.regen_per_sec) * delta)
	poise_changed.emit(_current, int(profile.capacity))


## Owner calls this when CombatManager.hit_resolved fires for the owner.
## `is_heavy` is true for HEAVY/FINISHER/CRIT/ELITE/BOSS feedback weights.
## Returns true if the hit broke poise.
func take_poise_damage(amount: float, is_heavy: bool) -> bool:
	if profile == null:
		return false
	if amount <= 0.0:
		return false
	var now: int = Time.get_ticks_usec()
	if now < _post_break_immune_until_usec:
		return false  # ignored — chained attacks can't perma-stagger
	if _is_broken:
		return false  # already broken, ignore further damage until recovery
	if bool(profile.heavy_only) and not is_heavy:
		return false  # boss/elite shrug off light pokes
	var effective: float = amount * (1.0 - float(profile.poise_resistance))
	if effective <= 0.0:
		return false
	_current = max(0.0, _current - effective)
	_last_damage_usec = now
	poise_changed.emit(_current, int(profile.capacity))
	if _current <= 0.0:
		_is_broken = true
		_broken_until_usec = now + int(profile.break_vulnerability_ms) * 1000
		poise_broken.emit(int(profile.break_vulnerability_ms))
		return true
	return false


## True while inside the post-break vulnerability window — owner code can
## upgrade the next hit reaction to a heavier tier visually.
func is_vulnerable() -> bool:
	return _is_broken


func current() -> float:
	return _current


func capacity() -> int:
	return 0 if profile == null else int(profile.capacity)


func ratio() -> float:
	if profile == null or int(profile.capacity) <= 0:
		return 1.0
	return _current / float(profile.capacity)


func force_reset() -> void:
	if profile != null:
		_current = float(profile.capacity)
	_is_broken = false
	_post_break_immune_until_usec = 0
	_broken_until_usec = 0
	poise_changed.emit(_current, capacity())
