extends RefCounted
class_name AttackIntentResolver

## Phase 1A.3: turns buffered raw inputs into typed AttackIntent.
##
## Mirrors the existing player.gd tap-buffer + charge + branch behavior so
## CombatController (Phase 1C) can drop this in without changing felt
## behavior, then we can remove the duplicated player.gd logic atomically.
##
## What lives here (per plan corr. 6):
##   - tap-count interpretation (1 = basic, 2 + moving = power/piercing,
##     3+ = whirlwind/arrow_rain)
##   - charge resolution (press/release/threshold)
##   - diagonal+attack → dash_strike / shadow_step
##   - direction-branch hint for basic-swing chains
##   - dodge > attack priority at the boundary
##
## What does NOT live here:
##   - the actual swing/animation playback (player.gd / CombatController)
##   - raw event storage (InputBuffer)
##   - damage (CombatManager)

const AttackIntentCls := preload("res://scripts/combat/attack_intent.gd")

enum HeroClass {
	MELEE,
	RANGED,
}

const TAP_RESOLVE_MS := 180  # matches existing TAP_RESOLVE_TIME = 0.18s
const CHARGE_THRESHOLD_MS := 1500  # matches existing CHARGE_THRESHOLD = 1.5s

var hero_class: int = HeroClass.MELEE

# Tap-window state
var _tap_count: int = 0
var _tap_window_deadline_usec: int = 0
var _tap_resolved: bool = true  # true between tap-windows; false while accumulating

# Charge state
var _charge_pressed_usec: int = 0  # 0 = not pressed
var _charge_pending_release: bool = false
var _charge_release_usec: int = 0

# Last direction the player attacked in — used for branch_hint
var _last_attack_dir: Vector2 = Vector2.ZERO

# Pending dodge intent (priority over attack)
var _pending_dodge: bool = false


func set_hero_class(c: int) -> void:
	hero_class = c


## Caller hands us a fresh attack press. `direction` is the player's
## current aim/move direction at the moment of the press. `moving` is
## true when the player has nonzero movement input.
func notify_attack_press(now_usec: int, direction: Vector2, _moving: bool) -> void:
	# Reset window if first press
	if _tap_resolved or _tap_window_deadline_usec <= now_usec:
		_tap_count = 0
		_tap_resolved = false
	_tap_count += 1
	_tap_window_deadline_usec = now_usec + TAP_RESOLVE_MS * 1000
	# direction is intentionally NOT written to _last_attack_dir here —
	# _classify_tap needs the *previous* attack's direction for branch_hint.
	# _last_attack_dir is updated only after a BASIC_SWING classification.


func notify_dodge_press() -> void:
	_pending_dodge = true


func notify_charge_press(now_usec: int) -> void:
	_charge_pressed_usec = now_usec
	_charge_pending_release = false


func notify_charge_release(now_usec: int) -> void:
	if _charge_pressed_usec == 0:
		return
	_charge_pending_release = true
	_charge_release_usec = now_usec


func clear() -> void:
	_tap_count = 0
	_tap_window_deadline_usec = 0
	_tap_resolved = true
	_charge_pressed_usec = 0
	_charge_pending_release = false
	_pending_dodge = false


## Per-frame tick. May return null (no resolved intent yet) or an
## AttackIntent ready to act on. Caller is responsible for clearing
## buffered raw events tied to the returned intent.
## Return type is RefCounted (not AttackIntent) so this file can be
## preloaded from autoloads before the class_name registry is built.
func tick(now_usec: int, current_direction: Vector2, moving: bool) -> RefCounted:
	# 1. Dodge priority: always wins at the boundary
	if _pending_dodge:
		_pending_dodge = false
		var di := AttackIntentCls.new()
		di.kind = AttackIntentCls.Kind.DODGE
		di.direction = current_direction
		di.trace = "dodge"
		return di

	# 2. Charge release outranks tap classification (player released the hold)
	if _charge_pending_release:
		var press := _charge_pressed_usec
		var rel := _charge_release_usec
		var dur_ms := int((rel - press) / 1000)
		_charge_pressed_usec = 0
		_charge_pending_release = false
		if dur_ms >= CHARGE_THRESHOLD_MS:
			var ci := AttackIntentCls.new()
			ci.kind = AttackIntentCls.Kind.CHARGED_SLASH if hero_class == HeroClass.MELEE else AttackIntentCls.Kind.SNIPER_SHOT
			ci.direction = current_direction if current_direction.length() > 0.01 else _last_attack_dir
			ci.charge_duration_ms = dur_ms
			ci.trace = "charge_release"
			return ci
		# Short release while a tap window is open — falls through to tap resolution

	# 3. Tap window expired → classify
	if not _tap_resolved and now_usec >= _tap_window_deadline_usec:
		var intent := _classify_tap(current_direction, moving)
		_tap_resolved = true
		_tap_count = 0
		return intent

	return null


func _classify_tap(current_direction: Vector2, moving: bool) -> RefCounted:
	var dir := current_direction if current_direction.length() > 0.01 else _last_attack_dir
	var intent := AttackIntentCls.new()
	intent.direction = dir
	intent.tap_count = _tap_count

	# Diagonal + single attack press → dash_strike / shadow_step
	if _tap_count == 1 and _is_diagonal(dir):
		intent.kind = AttackIntentCls.Kind.DASH_STRIKE if hero_class == HeroClass.MELEE else AttackIntentCls.Kind.SHADOW_STEP
		intent.trace = "diagonal_dash"
		return intent

	if _tap_count >= 3:
		intent.kind = AttackIntentCls.Kind.WHIRLWIND if hero_class == HeroClass.MELEE else AttackIntentCls.Kind.ARROW_RAIN
		intent.trace = "triple_tap"
		return intent

	if _tap_count == 2 and moving:
		intent.kind = AttackIntentCls.Kind.POWER_STRIKE if hero_class == HeroClass.MELEE else AttackIntentCls.Kind.PIERCING_SHOT
		intent.trace = "double_tap_moving"
		return intent

	intent.kind = AttackIntentCls.Kind.BASIC_SWING if hero_class == HeroClass.MELEE else AttackIntentCls.Kind.RANGED_BASIC
	intent.branch_hint = _branch_hint_from_directions(_last_attack_dir, dir)
	if dir.length() > 0.01:
		_last_attack_dir = dir.normalized()
	intent.trace = "basic"
	return intent


## Diagonal: both axes have meaningful magnitude (not purely horizontal/vertical).
func _is_diagonal(dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return false
	var n := dir.normalized()
	return abs(n.x) > 0.35 and abs(n.y) > 0.35


## Encodes the existing 5-swing branch table:
##   horizontal -> down            : OVERHEAD (C)
##   down       -> up              : THRUST   (D)
##   any        -> up              : THRUST   (D)
##   any        -> diagonal        : SPIN     (E)
##   vertical   -> horizontal flip : SPIN     (E)
##   otherwise                     : HORIZONTAL (A/B alternation handled by combo step)
func _branch_hint_from_directions(prev: Vector2, next: Vector2) -> int:
	if next.length() < 0.01:
		return AttackIntentCls.BranchHint.HORIZONTAL
	if _is_diagonal(next):
		return AttackIntentCls.BranchHint.SPIN
	if _is_vertical_up(next):
		return AttackIntentCls.BranchHint.THRUST
	if _is_horizontal(prev) and _is_vertical_down(next):
		return AttackIntentCls.BranchHint.OVERHEAD
	if _is_vertical(prev) and _is_horizontal(next):
		return AttackIntentCls.BranchHint.SPIN
	return AttackIntentCls.BranchHint.HORIZONTAL


func _is_horizontal(d: Vector2) -> bool:
	if d.length() < 0.01:
		return false
	var n := d.normalized()
	return abs(n.x) > 0.85


func _is_vertical(d: Vector2) -> bool:
	if d.length() < 0.01:
		return false
	var n := d.normalized()
	return abs(n.y) > 0.85


func _is_vertical_up(d: Vector2) -> bool:
	if d.length() < 0.01:
		return false
	var n := d.normalized()
	return n.y < -0.85


func _is_vertical_down(d: Vector2) -> bool:
	if d.length() < 0.01:
		return false
	var n := d.normalized()
	return n.y > 0.85
