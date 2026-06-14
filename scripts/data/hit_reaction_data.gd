extends Resource
class_name HitReactionData

## Phase 1B.3: per-enemy-tier reaction profile (plan §4).
##
## Three reaction layers stay independent (plan §3 "Three reaction
## layers"): visual flinch, physical knockback, AI stagger. A boss
## may take visual recoil only; a light enemy may take all three.

enum Tier {
	LIGHT,
	MEDIUM,
	HEAVY,
	ELITE,
	BOSS,
}

@export var tier: int = Tier.LIGHT

# --- Visual layer ---------------------------------------------------------
@export var visual_recoil_distance: float = 4.0      # pixels
@export var visual_squash: Vector2 = Vector2(1.20, 0.85)
@export var visual_rotation_rad: float = 0.10
@export var visual_duration_sec: float = 0.18
@export var hit_flash_strength: float = 1.5          # modulate multiplier
@export var custom_animation: StringName = &""       # optional override

# --- Physical layer -------------------------------------------------------
@export var knockback_scalar: float = 1.0            # × incoming force
@export var knockback_resistance: float = 0.0        # 0 = none, 1 = full immunity

# --- Stagger layer --------------------------------------------------------
@export var stagger_ms: int = 220
@export var stagger_resistance: float = 0.0          # 0 = none, 1 = full immunity
@export var stagger_only_heavy: bool = false         # heavy/crit attacks only

# --- Repeated-hit dampening ----------------------------------------------
@export var min_interval_ms: int = 120


## Apply one of the Phase 1B presets to THIS instance. Returns self for
## chaining. Use this rather than static factory methods — static methods
## on preloaded GDScript constants are not always callable on first
## headless boot (the class_name registry may not be populated yet).
## Usage:
##     var d := HitReactionData.new().apply_preset(HitReactionData.Tier.LIGHT)
func apply_preset(t: int) -> HitReactionData:
	tier = t
	match t:
		Tier.LIGHT:
			visual_recoil_distance = 4.0
			visual_squash = Vector2(1.20, 0.85)
			visual_rotation_rad = 0.10
			knockback_scalar = 1.00
			knockback_resistance = 0.0
			stagger_ms = 220
			stagger_resistance = 0.0
			stagger_only_heavy = false
			min_interval_ms = 120
		Tier.MEDIUM:
			visual_recoil_distance = 3.0
			visual_squash = Vector2(1.15, 0.88)
			visual_rotation_rad = 0.08
			knockback_scalar = 0.75
			knockback_resistance = 0.0
			stagger_ms = 160
			stagger_resistance = 0.0
			stagger_only_heavy = false
			min_interval_ms = 160
		Tier.HEAVY:
			visual_recoil_distance = 2.0
			visual_squash = Vector2(1.10, 0.92)
			visual_rotation_rad = 0.06
			knockback_scalar = 0.50
			knockback_resistance = 0.0
			stagger_ms = 110
			stagger_resistance = 0.0
			stagger_only_heavy = true
			min_interval_ms = 200
		Tier.ELITE:
			visual_recoil_distance = 1.0
			visual_squash = Vector2(1.06, 0.95)
			visual_rotation_rad = 0.04
			knockback_scalar = 0.30
			knockback_resistance = 0.5
			stagger_ms = 90
			stagger_resistance = 0.6
			stagger_only_heavy = true
			min_interval_ms = 260
		Tier.BOSS:
			visual_recoil_distance = 0.0
			visual_squash = Vector2(1.03, 0.98)
			visual_rotation_rad = 0.0
			knockback_scalar = 0.0
			knockback_resistance = 1.0
			stagger_ms = 0
			stagger_resistance = 1.0
			stagger_only_heavy = true
			min_interval_ms = 320
	return self
