extends RefCounted
class_name AttackIntent

## Phase 1A.3: typed interpretation of buffered combat inputs.
## Produced by AttackIntentResolver.tick(); consumed by CombatController
## (Phase 1C) to decide which animation / attack to actually fire.

enum Kind {
	NONE,
	BASIC_SWING,        # A/B/C/D/E selection driven by branch_hint + combo step
	POWER_STRIKE,       # melee: 2 taps + moving
	WHIRLWIND,          # melee: 3+ taps
	CHARGED_SLASH,      # melee: hold release
	DASH_STRIKE,        # melee: diagonal + attack
	RANGED_BASIC,
	PIERCING_SHOT,      # ranged: 2 taps + moving
	ARROW_RAIN,         # ranged: 3+ taps
	SNIPER_SHOT,        # ranged: hold release
	SHADOW_STEP,        # ranged: diagonal + attack
	DODGE,
}

## Branch hint preserves the existing 5-swing directional behavior:
## last direction → next direction determines which of A/B/C/D/E plays.
## CombatController applies this only when kind == BASIC_SWING.
enum BranchHint {
	NONE,
	HORIZONTAL,
	OVERHEAD,    # was: horizontal->down or down->up swap to overhead chop
	THRUST,      # was: ->up
	SPIN,        # was: ->diagonal
}

var kind: int = Kind.NONE
var direction: Vector2 = Vector2.ZERO
var branch_hint: int = BranchHint.NONE
var charge_duration_ms: int = 0  # for CHARGED_SLASH / SNIPER_SHOT
var tap_count: int = 0           # for POWER_STRIKE / WHIRLWIND classification
var trace: String = ""           # debug label


func is_attack() -> bool:
	return kind != Kind.NONE and kind != Kind.DODGE


func is_special() -> bool:
	match kind:
		Kind.POWER_STRIKE, Kind.WHIRLWIND, Kind.CHARGED_SLASH, Kind.DASH_STRIKE, \
		Kind.PIERCING_SHOT, Kind.ARROW_RAIN, Kind.SNIPER_SHOT, Kind.SHADOW_STEP:
			return true
	return false
