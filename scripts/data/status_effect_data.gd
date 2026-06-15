extends Resource
class_name StatusEffectData

## Phase 2.6: per-status configuration (plan §5 Phase 2.6).
##
## Status effects are time-bounded markers / DoTs / vulnerabilities on a
## target. They are applied by HitEvents and processed by the target's
## StatusEffectComponent. Each Status has an id; the component tracks
## one record per id. Re-applying refreshes duration (default stacking
## rule) or stacks count up to a cap (when stack_cap > 1).

@export var id: StringName = &""
@export var duration_ms: int = 3000
@export var tick_interval_ms: int = 0   # 0 = no DoT
@export var per_tick_damage: int = 0
## Defines how re-applying behaves while the status is already active:
##   "refresh"  — extend to full duration_ms
##   "ignore"   — silent no-op
##   "stack"    — increment stack count up to stack_cap
@export var stack_rule: StringName = &"refresh"
@export var stack_cap: int = 1
## Tier label for grouping ("bleed", "chill", "mark", "armor_break",
## "burn", "exposed"). Used by ability interactions (Phase 2.7) to
## identify what to consume.
@export var tier: StringName = &""


## Phase 2.6/2.7 baked-in presets.
func apply_preset(preset_id: StringName) -> StatusEffectData:
	id = preset_id
	match preset_id:
		&"exposed":
			# Applied by C-finisher / branch_slam. Specials that hit an
			# exposed target deal +50% damage and consume the status.
			duration_ms = 3000
			tick_interval_ms = 0
			per_tick_damage = 0
			stack_rule = &"refresh"
			stack_cap = 1
			tier = &"exposed"
		&"bleed":
			duration_ms = 4000
			tick_interval_ms = 600
			per_tick_damage = 3
			stack_rule = &"stack"
			stack_cap = 5
			tier = &"bleed"
		&"mark":
			duration_ms = 6000
			tick_interval_ms = 0
			per_tick_damage = 0
			stack_rule = &"refresh"
			stack_cap = 1
			tier = &"mark"
		_:
			pass
	return self
