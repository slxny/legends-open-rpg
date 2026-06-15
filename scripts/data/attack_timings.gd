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
		unstoppable: bool = false, poise: int = 5) -> Resource:
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
	t.poise_damage = poise
	return t


# ---- Core A -> B -> C ----------------------------------------------------

static func swing_a() -> Resource:
	# Horizontal left-to-right. Audit: damage @ 0.55 of 0.31s. Light poise chip.
	return _make(&"swing_a", AttackTimingDataCls.RhythmClass.CORE_A,
		0.31, 0.55, 0.48, 0.62, 0.55, 0.95, 0.70, 0.85,
		1, false, false, 5)


static func swing_b() -> Resource:
	# Horizontal backhand. Audit: damage @ 0.55 of 0.31s.
	return _make(&"swing_b", AttackTimingDataCls.RhythmClass.CORE_B,
		0.31, 0.55, 0.48, 0.62, 0.55, 0.95, 0.70, 0.85,
		1, false, false, 6)


static func swing_c() -> Resource:
	# Overhead chop — A→B→C finisher. Applies "exposed" status (Phase 2.7).
	var t := _make(&"swing_c", AttackTimingDataCls.RhythmClass.FINISHER_C,
		0.33, 0.58, 0.50, 0.65, 0.62, 1.0, 0.78, 0.88,
		1, false, false, 15)
	t.apply_status = &"exposed"
	return t


# ---- Optional extensions -------------------------------------------------

static func swing_d() -> Resource:
	# Upward thrust extension. Higher commitment → more poise damage.
	return _make(&"swing_d", AttackTimingDataCls.RhythmClass.EXTENSION_D,
		0.29, 0.55, 0.48, 0.62, 0.55, 0.95, 0.75, 0.88,
		1, false, false, 12)


static func swing_e() -> Resource:
	# Spin slash extension — wide attack, multi-hit. Per-target poise low.
	return _make(&"swing_e", AttackTimingDataCls.RhythmClass.EXTENSION_E,
		0.40, 0.60, 0.45, 0.78, 0.62, 0.95, 0.80, 0.90,
		3, true, false, 10)


# ---- Directional branches ------------------------------------------------

static func branch_slam() -> Resource:
	# horizontal -> down replacement. Plan §2.2: slam = strong poise damage.
	# Phase 2.7 — also applies "exposed".
	var t := _make(&"branch_slam", AttackTimingDataCls.RhythmClass.BRANCH_SLAM,
		0.33, 0.58, 0.50, 0.65, 0.62, 1.0, 0.78, 0.88,
		1, false, false, 20)
	t.apply_status = &"exposed"
	return t


static func branch_uppercut() -> Resource:
	# down -> up replacement. Plan §2.2: uppercut = launch + poise.
	return _make(&"branch_uppercut", AttackTimingDataCls.RhythmClass.BRANCH_UPPERCUT,
		0.29, 0.55, 0.48, 0.62, 0.55, 0.95, 0.75, 0.88,
		1, false, false, 15)


static func branch_spin() -> Resource:
	# any -> diagonal replacement. Wide CC, per-target poise low.
	return _make(&"branch_spin", AttackTimingDataCls.RhythmClass.BRANCH_SPIN,
		0.40, 0.60, 0.45, 0.78, 0.62, 0.95, 0.80, 0.90,
		3, true, false, 10)


# ---- Specials ------------------------------------------------------------

static func power_strike() -> Resource:
	# Heavy poise damage per cone target — meant to break.
	# Phase 2.7 — consumes "exposed" for +50% damage.
	var t := _make(&"power_strike", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.30, 0.50, 0.45, 0.62, 0.65, 0.95, 0.80, 0.90,
		5, true, true, 25)
	t.consume_status_tier = &"exposed"
	t.consume_damage_mult = 1.5
	return t


static func whirlwind() -> Resource:
	# Many targets, modest per-target poise so it doesn't perma-stagger a group.
	var t := _make(&"whirlwind", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.50, 0.55, 0.30, 0.78, 0.70, 0.95, 0.85, 0.92,
		3, true, true, 8)
	return t


static func charged_slash() -> Resource:
	# Heaviest single-target poise — primary boss-break tool.
	# Phase 2.7 — consumes "exposed" for +50% damage.
	var t := _make(&"charged_slash", AttackTimingDataCls.RhythmClass.CHARGED,
		0.45, 0.65, 0.50, 0.78, 0.75, 0.95, 0.85, 0.92,
		3, true, true, 40)
	t.consume_status_tier = &"exposed"
	t.consume_damage_mult = 1.5
	return t


static func dash_strike() -> Resource:
	# Phase 2.7 — consumes "exposed".
	var t := _make(&"dash_strike", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.37, 0.55, 0.50, 0.65, 0.65, 0.95, 0.80, 0.90,
		3, true, true, 15)
	t.consume_status_tier = &"exposed"
	t.consume_damage_mult = 1.5
	return t


# ---- Ranged class --------------------------------------------------------

static func piercing_shot() -> Resource:
	return _make(&"piercing_shot", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.32, 0.45, 0.40, 0.55, 0.55, 0.95, 0.70, 0.85,
		1, false, false, 12)


static func arrow_rain() -> Resource:
	return _make(&"arrow_rain", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.55, 0.40, 0.35, 0.85, 0.70, 0.95, 0.85, 0.92,
		5, true, true, 6)


static func sniper_shot() -> Resource:
	return _make(&"sniper_shot", AttackTimingDataCls.RhythmClass.CHARGED,
		0.42, 0.65, 0.60, 0.75, 0.70, 0.95, 0.80, 0.90,
		1, false, true, 30)


static func shadow_step() -> Resource:
	return _make(&"shadow_step", AttackTimingDataCls.RhythmClass.SPECIAL,
		0.40, 0.55, 0.50, 0.65, 0.65, 0.95, 0.80, 0.90,
		3, true, true, 10)


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
