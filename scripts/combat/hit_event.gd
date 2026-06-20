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
# v0.93.8 — ARPG damage typing. Pool: physical / fire / frost / lightning /
# poison / shadow / arcane. Defaults to physical so existing call sites
# don't need to change. CombatManager.resolve_hit looks up the victim's
# resistance via Enemy.get_resistance(damage_type) which returns a damage
# multiplier (1.0 = neutral, <1.0 = resist, >1.0 = vulnerable, 0.0 = immune).
@export var damage_type: StringName = &"physical"

## Optional overrides — null means CombatManager picks defaults by weight.
@export var feedback_profile: Resource
@export var reaction_profile_override: Resource
