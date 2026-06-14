extends Resource
class_name HitResult

## Typed result emitted by CombatManager.resolve_hit() after damage applies.
## Phase 1B onward: feedback systems (hit-stop, camera shake, audio, VFX,
## enemy reaction) trigger from a confirmed HitResult, never from contact
## timing alone.

@export var event: Resource  # HitEvent (declared as Resource to avoid cyclic class load)
@export var damage_dealt: int = 0
@export var was_crit: bool = false
@export var was_lethal: bool = false
@export var was_blocked: bool = false
@export var was_dodged: bool = false

@export var final_reaction: Resource  # HitReactionData (Phase 1B)
@export var final_feedback: Resource  # CombatFeedbackProfile (Phase 1B)

func is_confirmed_hit() -> bool:
	return damage_dealt > 0 and not was_blocked and not was_dodged
