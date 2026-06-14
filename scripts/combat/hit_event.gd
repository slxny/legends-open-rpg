extends Resource
class_name HitEvent

## Typed combat-hit request. Built by an attacker before damage resolves.
## Consumed by CombatManager.resolve_hit() which emits a HitResult.
## Phase 1A.1: structure only — no callers wired yet beyond the smoke test.

enum Weight {
	LIGHT,
	MEDIUM,
	HEAVY,
	FINISHER,
	CRIT,
	ELITE_KILL,
	BOSS_EVENT,
}

var attacker: Node
var victim: Node
@export var direction: Vector2 = Vector2.ZERO
@export var weight: int = Weight.LIGHT
@export var attack_id: StringName = &""
@export var ability_multiplier: float = 1.0
@export var force_crit: bool = false
@export var armor_break: bool = false
@export var unblockable: bool = false

## Optional overrides — null means CombatManager picks defaults by weight.
@export var feedback_profile: Resource
@export var reaction_profile_override: Resource
