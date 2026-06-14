extends RefCounted
class_name AttackTimings

## Phase 1A.4: programmatic AttackTimingData library for the existing
## player attacks. Calibrated against the audit checklist
## (docs/combat/PHASE_1A_0_BEHAVIORAL_CHECKLIST.md) so Stage 1A.5
## migration is a direct lift.
##
## Values may be converted to res://data/attacks/*.tres later for
## inspector tuning. Keeping them in code for now keeps the diff small
## and centralizes the calibration constants.

const AttackTimingDataCls := preload("res://scripts/data/attack_timing_data.gd")


static func _make(id: StringName, rhythm: int, dur: float, contact: float,
		active_start: float, active_end: float,
		combo_start: float, combo_end: float,
		dodge_cancel: float, move_cancel: float,
		max_hits: int = 1, wide: bool = false,
		unstoppable: bool = false) -> Resource:
	var t: Resource = AttackTimingDataCls.new()
	t.attack_id = id
	t.rhythm_class = rhythm
	t.duration_sec = dur
	t.contact_event = contact
	t.active_window_start = active_start
	t.active_window_end = active_end
	t.combo_window_start = combo_start
	t.combo_window_end = combo_end
	t.special_branch_start = combo_start
	t.special_branch_end = combo_end
	t.dodge_cancel_start = dodge_cancel
	t.movement_cancel_start = move_cancel
	t.recovery_end = 1.0
	t.max_hits_per_target = max_hits
	t.wide_attack = wide
	t.unstoppable = unstoppable
	return t


# ---- Core A -> B -> C ----------------------------------------------------

static func swing_a() -> Resource:
	# Horizontal left-to-right. Audit: damage @ 0.55 of 0.31s.
	return _make(&"swing_a", AttackTimingDataCls.RhythmClass.CORE_A,
		0.31, 0.55, 0.48, 0.62, 0.55, 0.95, 0.70, 0.85)


static func swing_b() -> Resource:
	# Horizontal backhand. Audit: damage @ 0.55 of 0.31s.
	return _make(&"swing_b", AttackTimingDataCls.RhythmClass.CORE_B,
		0.31, 0.55, 0.48, 0.62, 0.55, 0.95, 0.70, 0.85)


static func swing_c() -> Resource:
	# Overhead chop — Phase 1 finisher (plan corr. 1).
	# Slightly slower, longer combo window, late dodge-cancel (commitment).
	# Audit: damage @ 0.58 of 0.33s. Knockback 55 (vs 40 baseline).
	return _make(&"swing_c", AttackTimingDataCls.RhythmClass.FINISHER_C,
		0.33, 0.58, 0.50, 0.65, 0.62, 1.0, 0.78, 0.88)


# ---- Optional extensions -------------------------------------------------

static func swing_d() -> Resource:
	# Upward thrust extension. Audit: damage @ 0.55 of 0.29s. Higher commitment.
	return _make(&"swing_d", AttackTimingDataCls.RhythmClass.EXTENSION_D,
		0.29, 0.55, 0.48, 0.62, 0.55, 0.95, 0.75, 0.88)


static func swing_e() -> Resource:
	# Spin slash extension — wide attack, multi-hit. Audit: 0.60 of 0.40s.
	return _make(&"swing_e", AttackTimingDataCls.RhythmClass.EXTENSION_E,
		0.40, 0.60, 0.45, 0.78, 0.62, 0.95, 0.80, 0.90,
		3, true)  # max 3 hits per target across spin


# ---- Directional branches ------------------------------------------------

static func branch_slam() -> Resource:
	# horizontal -> down replacement (becomes overhead-like slam variant).
	return _make(&"branch_slam", AttackTimingDataCls.RhythmClass.BRANCH_SLAM,
		0.33, 0.58, 0.50, 0.65, 0.62, 1.0, 0.78, 0.88)


static func branch_uppercut() -> Resource:
	# down -> up replacement (launching-ish).
	return _make(&"branch_uppercut", AttackTimingDataCls.RhythmClass.BRANCH_UPPERCUT,
		0.29, 0.55, 0.48, 0.62, 0.55, 0.95, 0.75, 0.88)


static func branch_spin() -> Resource:
	# any -> diagonal replacement. Wide.
	return _make(&"branch_spin", AttackTimingDataCls.RhythmClass.BRANCH_SPIN,
		0.40, 0.60, 0.45, 0.78, 0.62, 0.95, 0.80, 0.90,
		3, true)


# ---- Specials ------------------------------------------------------------

static func power_strike() -> Resource:
	# Audit: 0.25 lunge + impact callbacks. ~0.30 total. Hits a cone.
	# Stronger commitment — late dodge cancel, no special branch.
	var t := _make(&"power_strike", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.30, 0.50, 0.45, 0.62, 0.65, 0.95, 0.80, 0.90,
		5, true, true)  # max 5 enemies, wide, unstoppable
	return t


static func whirlwind() -> Resource:
	# Audit: 0.50s with 720° spin midpoint. Hits all in range.
	var t := _make(&"whirlwind", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.50, 0.55, 0.30, 0.78, 0.70, 0.95, 0.85, 0.92,
		3, true, true)
	return t


static func charged_slash() -> Resource:
	# Variable dash. Use a representative total of 0.45s (windup + 0.25 dash + recover).
	# Contact occurs post-dash at ~0.65.
	var t := _make(&"charged_slash", AttackTimingDataCls.RhythmClass.CHARGED,
		0.45, 0.65, 0.50, 0.78, 0.75, 0.95, 0.85, 0.92,
		3, true, true)
	return t


static func dash_strike() -> Resource:
	# Audit: 0.37s. Contact post-dash.
	var t := _make(&"dash_strike", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.37, 0.55, 0.50, 0.65, 0.65, 0.95, 0.80, 0.90,
		3, true, true)
	return t


# ---- Ranged class --------------------------------------------------------

static func piercing_shot() -> Resource:
	return _make(&"piercing_shot", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.32, 0.45, 0.40, 0.55, 0.55, 0.95, 0.70, 0.85)


static func arrow_rain() -> Resource:
	return _make(&"arrow_rain", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.55, 0.40, 0.35, 0.85, 0.70, 0.95, 0.85, 0.92,
		5, true, true)


static func sniper_shot() -> Resource:
	return _make(&"sniper_shot", AttackTimingDataCls.RhythmClass.CHARGED,
		0.42, 0.65, 0.60, 0.75, 0.70, 0.95, 0.80, 0.90,
		1, false, true)


static func shadow_step() -> Resource:
	return _make(&"shadow_step", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.40, 0.55, 0.50, 0.65, 0.65, 0.95, 0.80, 0.90,
		3, true, true)


## Look up by attack_id. Returns null if unknown.
static func by_id(id: StringName) -> Resource:
	match id:
		&"swing_a": return swing_a()
		&"swing_b": return swing_b()
		&"swing_c": return swing_c()
		&"swing_d": return swing_d()
		&"swing_e": return swing_e()
		&"branch_slam": return branch_slam()
		&"branch_uppercut": return branch_uppercut()
		&"branch_spin": return branch_spin()
		&"power_strike": return power_strike()
		&"whirlwind": return whirlwind()
		&"charged_slash": return charged_slash()
		&"dash_strike": return dash_strike()
		&"piercing_shot": return piercing_shot()
		&"arrow_rain": return arrow_rain()
		&"sniper_shot": return sniper_shot()
		&"shadow_step": return shadow_step()
	return null


static func all_ids() -> Array[StringName]:
	return [
		&"swing_a", &"swing_b", &"swing_c", &"swing_d", &"swing_e",
		&"branch_slam", &"branch_uppercut", &"branch_spin",
		&"power_strike", &"whirlwind", &"charged_slash", &"dash_strike",
		&"piercing_shot", &"arrow_rain", &"sniper_shot", &"shadow_step",
	]
