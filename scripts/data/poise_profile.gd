extends Resource
class_name PoiseProfile

## Phase 2.0: per-enemy-tier poise pool (plan §5 Phase 2.0).
##
## Poise is a separate resource from HP. Damage to poise accumulates;
## when it reaches 0 the enemy enters a vulnerability window
## (poise_broken). After regen_delay_ms of no damage, poise regenerates
## at regen_per_sec. Tier presets keep the system data-driven.

enum Tier {
	LIGHT,
	MEDIUM,
	HEAVY,
	ELITE,
	BOSS,
}

@export var tier: int = Tier.LIGHT

@export var capacity: int = 15           # max poise
@export var regen_per_sec: float = 10.0  # restored per second after delay
@export var regen_delay_ms: int = 1200   # no-damage window before regen starts
@export var break_vulnerability_ms: int = 600
## After a poise break the enemy is briefly poise-immune so chained
## attacks can't perma-stagger it.
@export var post_break_immune_ms: int = 600
## Multiplier on incoming poise damage. Light = 1.0, boss = 0.4, etc.
@export var poise_resistance: float = 0.0  # 0 = none, 1 = full immunity
## When true, only heavy/finisher/crit attacks chip poise. Smaller
## attacks do nothing — used for boss-class targets.
@export var heavy_only: bool = false


func apply_preset(t: int) -> PoiseProfile:
	tier = t
	match t:
		Tier.LIGHT:
			capacity = 15
			regen_per_sec = 10.0
			regen_delay_ms = 1100
			break_vulnerability_ms = 600
			post_break_immune_ms = 600
			poise_resistance = 0.0
			heavy_only = false
		Tier.MEDIUM:
			capacity = 40
			regen_per_sec = 14.0
			regen_delay_ms = 1300
			break_vulnerability_ms = 700
			post_break_immune_ms = 700
			poise_resistance = 0.0
			heavy_only = false
		Tier.HEAVY:
			capacity = 80
			regen_per_sec = 20.0
			regen_delay_ms = 1500
			break_vulnerability_ms = 800
			post_break_immune_ms = 900
			poise_resistance = 0.2
			heavy_only = false
		Tier.ELITE:
			capacity = 120
			regen_per_sec = 24.0
			regen_delay_ms = 1700
			break_vulnerability_ms = 900
			post_break_immune_ms = 1200
			poise_resistance = 0.45
			heavy_only = true
		Tier.BOSS:
			capacity = 300
			regen_per_sec = 30.0
			regen_delay_ms = 2000
			break_vulnerability_ms = 1200
			post_break_immune_ms = 1800
			poise_resistance = 0.6
			heavy_only = true
	return self
