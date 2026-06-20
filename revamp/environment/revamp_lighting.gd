extends CanvasModulate

## Global tint for the slice — a dusk-storm palette. Warmer than the existing
## havens' "sun" lighting, with a violet undertone so the storm magic + arcane
## VFX read against the sky band.

const PALETTE_BASE := Color(0.82, 0.82, 1.04)
const PALETTE_BOSS := Color(0.62, 0.58, 0.95)
const PALETTE_LOOT := Color(1.08, 1.02, 0.78)

var _t: float = 0.0
var _mode: StringName = &"base"


func _ready() -> void:
	color = PALETTE_BASE


func _process(delta: float) -> void:
	_t += delta
	# Subtle breathe so the scene isn't perfectly static — ±2% on a slow sine.
	var breathe: float = sin(_t * 0.55) * 0.012 + 1.0
	var target: Color
	match _mode:
		&"boss":
			target = PALETTE_BOSS
		&"loot":
			target = PALETTE_LOOT
		_:
			target = PALETTE_BASE
	color = color.lerp(target * breathe, delta * 1.4)


func set_mode(m: StringName) -> void:
	_mode = m
