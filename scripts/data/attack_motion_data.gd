extends Resource
class_name AttackMotionData

## Phase 2.1: per-attack target-assist + forward-motion data (plan §5 2.1).
##
## Drives two systems at swing start:
##   1. Magnetism — slightly rotate the swing direction toward a scored
##      target so attacks that *should* land actually land.
##   2. Lean-in motion — short collision-aware Tween on global_position
##      so the attack feels committed instead of "stopping just outside
##      contact range".
##
## player.gd remains the sole writer of CharacterBody2D.velocity /
## move_and_slide(). The Tween writes global_position with a raycast
## guard against walls — never penetrates collision.

@export var max_magnetism_angle_deg: float = 45.0  # cone half-angle for target selection
@export var max_magnetism_range_mul: float = 1.5   # × stats.attack_range
## 0 = no aim bias, 1 = full snap to target. 0.45 is a comfortable assist.
@export_range(0.0, 1.0) var aim_bias: float = 0.45
@export var motion_distance: float = 22.0          # pixels of forward lean-in
@export var motion_duration_sec: float = 0.10
## Only apply motion if the player-to-target distance exceeds this. Stops
## the swing from sliding past an enemy who is already in contact range.
@export var motion_min_gap: float = 18.0
## After this progress threshold the attack is committed — no further
## steering / motion applies. Unused by the basic swings (motion is
## front-loaded), present for completeness.
@export_range(0.0, 1.0) var commitment_progress: float = 0.55
## Walls block lean-in. When false, motion fires regardless of obstacles.
@export var raycast_check_walls: bool = true


# Per-attack defaults — tuned so the lean-in is just visible without
# turning every swing into a dash. apply_preset chooses by rhythm class.
func apply_preset(rhythm_class: int) -> AttackMotionData:
	# RhythmClass: CORE_A=0, CORE_B=1, FINISHER_C=2, EXTENSION_D=3,
	#              EXTENSION_E=4, BRANCH_SLAM=5, BRANCH_UPPERCUT=6,
	#              BRANCH_SPIN=7, SPECIAL=8, CHARGED=9.
	match rhythm_class:
		0, 1:  # A, B — small lean-in
			motion_distance = 18.0
			motion_duration_sec = 0.08
			aim_bias = 0.45
		2:  # C finisher — slightly stronger lean-in
			motion_distance = 28.0
			motion_duration_sec = 0.10
			aim_bias = 0.55
		3:  # D thrust — strongest forward
			motion_distance = 30.0
			motion_duration_sec = 0.10
			aim_bias = 0.55
		4:  # E spin — wide, less forward (pivot in place)
			motion_distance = 12.0
			motion_duration_sec = 0.08
			aim_bias = 0.30
		5:  # slam — strong vertical commitment
			motion_distance = 26.0
			motion_duration_sec = 0.10
			aim_bias = 0.55
		6:  # uppercut
			motion_distance = 22.0
			motion_duration_sec = 0.10
			aim_bias = 0.55
		7:  # branch spin
			motion_distance = 14.0
			motion_duration_sec = 0.08
			aim_bias = 0.35
		_:
			# Specials / charged already do their own physics-aware
			# movement. Suppress generic motion.
			motion_distance = 0.0
			motion_duration_sec = 0.05
			aim_bias = 0.20
	return self
