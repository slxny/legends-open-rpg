extends Resource
class_name AttackTimingData

## Phase 1A.4: per-attack gameplay-timing data (plan §4).
##
## All windows are normalized to AttackClock.progress (0.0–1.0). They
## describe gameplay behavior; visual Tween durations are independent.
## Authoring rule: keep contact_event close to the visible weapon
## contact frame so Phase 1B feedback (hit-stop, shake, audio) fires
## at the right beat.

enum RhythmClass {
	CORE_A,          # first swing of A->B->C core
	CORE_B,          # second swing
	FINISHER_C,      # the satisfying C mini-finisher (plan corr. 1)
	EXTENSION_D,     # optional higher-commitment extension
	EXTENSION_E,     # optional wider extension
	BRANCH_SLAM,     # directional replacement
	BRANCH_UPPERCUT,
	BRANCH_SPIN,
	SPECIAL,         # power_strike / whirlwind / dash_strike / piercing / arrow_rain / shadow_step
	CHARGED,         # charged_slash / sniper_shot
}

@export var attack_id: StringName = &""
@export var rhythm_class: int = RhythmClass.CORE_A

## Total gameplay duration in seconds (wind-up + active + recovery).
## Visual Tween durations are independent and may be shorter or longer.
@export var duration_sec: float = 0.30

## Single contact-event moment (0.0–1.0). Phase 1B fires hit-stop /
## shake / audio impact / enemy reaction here on a confirmed hit.
@export var contact_event: float = 0.55

## Active hitbox window — Area2D monitoring is enabled while
## progress ∈ [active_window_start, active_window_end).
@export var active_window_start: float = 0.45
@export var active_window_end: float = 0.65

## Combo-input acceptance window — when CombatController may queue
## the next combo step.
@export var combo_window_start: float = 0.55
@export var combo_window_end: float = 0.95

## Dodge may cancel from this point onward (typically late recovery).
@export var dodge_cancel_start: float = 0.70

## Movement may cancel from this point onward.
@export var movement_cancel_start: float = 0.85

## Special-branch acceptance window — when tap-buffer specials or
## charged release may interrupt to a special.
@export var special_branch_start: float = 0.55
@export var special_branch_end: float = 0.95

## End of recovery — by this point the attack is over.
@export var recovery_end: float = 1.0

## Hitbox profile — how many enemies may be hit per attack.
@export var max_hits_per_target: int = 1
@export var wide_attack: bool = false  # true for spin / whirlwind / charged dash

## Phase 1B references — left as Resource so this file can preload
## before CombatFeedbackProfile etc. are written.
@export var feedback_profile: Resource

## If true, hit reactions cannot interrupt this attack.
@export var unstoppable: bool = false

## Phase 2.0 — base poise damage dealt by a single confirmed hit of this
## attack. Multiplied by 1.5 on a crit by CombatManager. Wide attacks
## that hit multiple targets deal this per-target.
@export var poise_damage: int = 5


func is_in_active_window(progress: float) -> bool:
	return progress >= active_window_start and progress < active_window_end


func is_in_combo_window(progress: float) -> bool:
	return progress >= combo_window_start and progress < combo_window_end


func is_in_dodge_cancel_window(progress: float) -> bool:
	return progress >= dodge_cancel_start


func is_in_movement_cancel_window(progress: float) -> bool:
	return progress >= movement_cancel_start


func is_in_special_branch_window(progress: float) -> bool:
	return progress >= special_branch_start and progress < special_branch_end


func has_passed_contact(progress: float) -> bool:
	return progress >= contact_event
