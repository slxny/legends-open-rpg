extends Resource
class_name CombatFeedbackProfile

## Phase 1B: per-attack-weight feedback bundle (plan §4).
##
## A profile says HOW hard a confirmed hit should feel: hit-stop ms for
## attacker and victim, camera trauma, audio group ids, particle preset
## ids, and an optional global Engine.time_scale dip routed through
## HitStopController.request_global_dip (which in turn routes through
## TimeManager — never written directly).
##
## Profiles are attached to a HitEvent (event.feedback_profile) so
## Phase 1B.6 subscribers to CombatManager.hit_resolved know which preset
## to apply without re-deriving from attack_id.

enum Weight {
	LIGHT,
	MEDIUM,
	HEAVY,
	FINISHER,    # A→B→C finisher feel
	CRIT,
	ELITE_KILL,
	BOSS_EVENT,
}

@export var weight: int = Weight.LIGHT

# --- Hit-stop (HitStopController.freeze_target) -------------------------
@export var attacker_freeze_ms: int = 30
@export var victim_freeze_ms: int = 35

# --- Camera shake (CameraShake2D.add_trauma) ----------------------------
@export_range(0.0, 1.0) var camera_trauma: float = 0.18
@export var camera_impulse_strength: float = 1.0  # multiplier on hit direction

# --- Global time dilation (HitStopController.request_global_dip) -------
## scale ∈ (0, 1). dip_ms ≤ 0 disables. priority follows TimeManager rules
## (higher wins, equal/lower during active rejected). Light/medium/heavy/
## finisher leave dip_ms = 0 — only crit/elite-kill/boss profiles dip.
@export_range(0.05, 0.99) var dip_scale: float = 0.35
@export var dip_ms: int = 0
@export var dip_priority: int = 0

# --- Audio (CombatAudioComponent.play) -----------------------------------
@export var audio_swing: StringName = &""
@export var audio_impact: StringName = &"hit_impact"
@export var audio_body: StringName = &""
@export var audio_armor: StringName = &""
@export var audio_magical: StringName = &""
@export var audio_kill: StringName = &""

# --- VFX (sprite pool entries, Phase 1B uses existing pool only) -------
@export var vfx_contact_id: StringName = &"impact"
@export var vfx_flash_color: Color = Color(1.5, 1.5, 1.5, 1.0)
@export var vfx_flash_strength: float = 1.0

# --- Hit reaction tier override (optional) ------------------------------
## If set, overrides the enemy's default HitReactionData tier on this hit.
## Useful for special attacks that should treat all enemies as if a heavier
## tier (e.g. finisher applies HEAVY profile reaction).
@export var reaction_tier_override: int = -1


func apply_preset(w: int) -> CombatFeedbackProfile:
	weight = w
	match w:
		Weight.LIGHT:
			attacker_freeze_ms = 30
			victim_freeze_ms = 35
			camera_trauma = 0.18
			dip_ms = 0
			dip_priority = 0
			audio_impact = &"hit_impact"
		Weight.MEDIUM:
			attacker_freeze_ms = 50
			victim_freeze_ms = 55
			camera_trauma = 0.30
			dip_ms = 0
			dip_priority = 0
			audio_impact = &"hit_impact"
		Weight.HEAVY:
			attacker_freeze_ms = 75
			victim_freeze_ms = 85
			camera_trauma = 0.45
			dip_ms = 0
			dip_priority = 0
			audio_impact = &"hit_impact"
		Weight.FINISHER:
			attacker_freeze_ms = 95
			victim_freeze_ms = 105
			camera_trauma = 0.55
			dip_ms = 0
			dip_priority = 0
			audio_impact = &"hit_impact"
		Weight.CRIT:
			attacker_freeze_ms = 70
			victim_freeze_ms = 90
			camera_trauma = 0.55
			dip_scale = 0.35
			dip_ms = 50
			dip_priority = 2
			audio_impact = &"crit_hit"
		Weight.ELITE_KILL:
			attacker_freeze_ms = 100
			victim_freeze_ms = 120
			camera_trauma = 0.70
			dip_scale = 0.30
			dip_ms = 60
			dip_priority = 3
			audio_impact = &"crit_hit"
		Weight.BOSS_EVENT:
			attacker_freeze_ms = 120
			victim_freeze_ms = 140
			camera_trauma = 0.85
			dip_scale = 0.25
			dip_ms = 70
			dip_priority = 4
			audio_impact = &"crit_hit"
	return self
