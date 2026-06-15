extends Resource
class_name DodgeData

## Phase 2.3: dodge tuning (plan §5 Phase 2.3 — "DodgeController introduction").
##
## The project audit (1A.0) confirmed no existing dodge — this is a clean
## introduction. Values below are the Phase 1 defaults from the plan §7.

@export var max_speed: float = 600.0           # peak velocity during dodge
@export var duration_ms: int = 250             # full dodge time
@export var iframes_ms: int = 220              # i-frames cover most of the dodge
@export var perfect_window_ms: int = 80        # at the very start, perfect-dodge window
@export var cooldown_ms: int = 350             # time between consecutive dodges
@export var afterimage_interval_ms: int = 18   # trail spawn cadence

## Optional movement curve — 0 → 1 over the dodge so the impulse feels
## punchy at the start and decays at the end. When null, an analytical
## ease-out is used.
@export var velocity_curve: Curve
