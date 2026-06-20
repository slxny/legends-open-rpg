extends CharacterBody2D

# Phase 1B.6b — visual hit reactions via component (no class_name to keep
# autoload boot order safe).
const HitReactionComponentCls = preload("res://scripts/components/hit_reaction_component.gd")
const HitReactionDataCls = preload("res://scripts/data/hit_reaction_data.gd")
const PoiseComponentCls = preload("res://scripts/components/poise_component.gd")
const PoiseProfileCls = preload("res://scripts/data/poise_profile.gd")
const StatusEffectComponentCls = preload("res://scripts/components/status_effect_component.gd")
const CombatPickupCls = preload("res://scripts/components/combat_pickup.gd")
const BloodthirstShrineCls = preload("res://scripts/components/bloodthirst_shrine.gd")

signal died(enemy: Node2D, xp_reward: int, gold_reward: int)

@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: SCBar = $HPBar
@onready var stats: StatsComponent = $StatsComponent
@onready var name_label: Label = $NameLabel

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }

var current_state: State = State.IDLE
var home_position: Vector2 = Vector2.ZERO
var target: Node2D = null

# Enemy config
var enemy_name: String = "Enemy"
var enemy_level: int = 1
var aggro_range: float = 120.0
var chase_range: float = 400.0
var attack_cooldown: float = 1.2
var xp_reward: int = 15
var gold_reward: int = 5
var drop_table: String = ""
var sprite_type: String = "goblin"
var is_mini_boss: bool = false

var _attack_timer: float = 0.0
var _is_dead: bool = false
var _shadow: Sprite2D = null
var _is_selected: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _cached_player: Node2D = null  # Cached player reference to avoid per-frame group lookups
var _cached_world_node: Node = null  # Cached world node for VFX spawning
var _base_scale: Vector2 = Vector2(1.0, 1.0)  # Resting sprite scale (1.5 for mini-bosses)
var _base_modulate: Color = Color.WHITE  # Resting sprite tint (reddish for mini-bosses)

# Outline shader for hover highlighting (shared across all enemies)
static var _outline_shader: Shader = null
static var _info_label_settings: LabelSettings = null
# Shared zoom compensation cache — computed once per frame, reused by all enemies
static var _zoom_comp_frame: int = -1
static var _zoom_comp_value: float = 1.0
var _info_label: Label = null
var _last_zoom_comp: float = -1.0  # Last applied zoom compensation (skip redundant updates)

# Distance-based sleep/wake — enemies far from the player disable physics processing
var _is_sleeping: bool = false
var _sleep_check_timer: float = 0.0
const SLEEP_DISTANCE_SQ: float = 640000.0  # 800^2 — sleep when player is >800px away
const WAKE_DISTANCE_SQ: float = 490000.0   # 700^2 — wake when player is <700px (hysteresis)
const SLEEP_CHECK_INTERVAL: float = 0.4    # Check sleep/wake ~2.5x per second
const LABEL_VISIBLE_DISTANCE_SQ: float = 22500.0  # 150^2 — show name when player is close
const ZOOM_REF := 3.0  # Reference zoom level where font sizes are calibrated
var _cached_camera: Camera2D = null
var _cached_zoom_comp: float = 1.0
var _zoom_check_timer: float = 0.0
const ZOOM_CHECK_INTERVAL: float = 0.25  # Update zoom compensation 4x/sec, not every frame

# Patrol state
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_radius: float = 150.0
var _patrol_wait_timer: float = 0.0
var _patrol_speed_factor: float = 0.65  # Patrol at 65% of move speed — more active roaming
var movement_bounds: Rect2 = Rect2()  # If has_area(), clamp position after movement

# Random alert aggro — periodic chance to notice the player at extended range
var _alert_check_timer: float = 0.0
const ALERT_CHECK_INTERVAL: float = 1.5  # Roll alert every 1.5 seconds
const ALERT_RANGE_MULTIPLIER: float = 2.0  # Alert detection at 2x normal aggro range
const ALERT_CHANCE: float = 0.3  # 30% chance per check to aggro at extended range
var _alert_range_sq: float = 0.0  # Pre-computed squared alert range

# Pre-computed squared distances to avoid sqrt in hot path
var _aggro_range_sq: float = 14400.0   # aggro_range^2
var _chase_range_sq: float = 160000.0  # chase_range^2
var _attack_range_sq: float = 1225.0   # attack_range^2
var _attack_disengage_sq: float = 2756.25  # (attack_range * 1.5)^2

# Effect proc chances (rare — 8-12% per attack depending on type)
var _effect_chance: float = 0.0  # Overall chance this unit has any effect
var _effect_type: String = ""    # "knockback", "paralyze", or "slow"

# Pre-allocated label settings for damage numbers (avoid LabelSettings.new() per hit)
static var _dmg_settings_normal: LabelSettings = null
static var _dmg_settings_crit: LabelSettings = null
# Shared damage label pool (avoids Label.new() per hit across all enemies)
static var _dmg_label_pool: Array[Label] = []
const DMG_LABEL_POOL_MAX: int = 30
# Shared drop node pool (avoids Area2D+CollisionShape2D+Sprite2D per drop)
static var _drop_pool: Array[Area2D] = []
const DROP_POOL_MAX: int = 20
# Global rat squeal cooldown — prevents overlapping squeals from swarms
static var _last_rat_squeal_msec: int = 0
const RAT_SQUEAL_INTERVAL: float = 0.8
# Multi-kill stagger — desynchronize simultaneous deaths
static var _last_global_death_msec: int = 0

# Killing blow info for death animation selection
var _last_hit_was_crit: bool = false
var _overkill_ratio: float = 0.0

# Phase 3.4b — ELITE MODIFIERS. Random regular enemies become elites with
# a modifier that changes their combat behavior, giving encounters
# variety without authoring new enemy types. Mini-bosses never become
# additional elites (they're already special).
const ELITE_CHANCE: float = 0.085  # ~8.5% of regular enemies become elite
# Phase 5.0 — killing attack id, set by hit_resolved before the death
# animation runs. Drives death-by-attack-type variants.
var _killing_attack_id: StringName = &""
var _killing_hit_direction: Vector2 = Vector2.ZERO
var _elite_modifier: StringName = &""   # "" / haste / armored / exploder / berserker / healer / shocking
var _elite_aura: Sprite2D = null
var _elite_aura_tween: Tween = null
var _healer_tick_accum: float = 0.0
# Phase 6.0a — damage number COMBO ACCUMULATION. Hits within
# DMG_STACK_WINDOW_MS on this enemy merge into the existing floating
# label, growing the number rather than cluttering with new labels.
const DMG_STACK_WINDOW_MS: int = 450
var _active_dmg_label: Label = null
var _active_dmg_value: int = 0
var _active_dmg_label_until_msec: int = 0
var _active_dmg_label_tween: Tween = null
# Phase 3.0a — enemy attack telegraph. Tracks whether the wind-up visual
# has fired for the current attack cycle. The actual damage still applies
# when _attack_timer hits 0; this just adds a visible anticipation phase
# so the player can read incoming attacks and dodge / counter.
const _WINDUP_BASE_SEC: float = 0.35  # default; per-sprite override
var _windup_started: bool = false
var _windup_tween: Tween = null
var _telegraph_arc: Sprite2D = null
var _reserved_token_cost: int = 0  # 0 = not holding a token

# Phase 3.5 — VULNERABILITY WINDOW. When a heavy enemy whiffs their big
# telegraphed attack OR gets staggered mid-windup, they're exposed for a
# brief moment. Taking damage during this window deals +50% and the
# reaction tier is forced one step heavier so the punish reads as huge.
var _vulnerable_until_usec: int = 0
var _vulnerability_glow_tween: Tween = null

func _is_in_vulnerability_window() -> bool:
	return _vulnerable_until_usec > 0 and Time.get_ticks_usec() < _vulnerable_until_usec

# Phase 3.4 — per-enemy attack PATTERNS.
#   "standard"    — single strike (default)
#   "triple_stab" — rat: 3 quick stabs, lower damage each
#   "slam"        — troll/ogre/golem: radial AoE around enemy
var _stabs_remaining: int = 0
var _slam_telegraph: Sprite2D = null

var _pattern_override: StringName = &""

func _get_attack_pattern() -> StringName:
	if _pattern_override != &"":
		return _pattern_override
	if sprite_type == "rat":
		return &"triple_stab"
	if sprite_type == "troll" or sprite_type == "ogre" or sprite_type == "ancient_golem":
		return &"slam"
	if sprite_type == "wolf":
		return &"charge"
	return &"standard"

# v0.90.2 — at windup time, give standard-pattern medium/heavy enemies a chance
# to surprise-roll into a SLAM (telegraphed radial AOE). Adds a real
# spacing/dodge decision to every encounter, not just troll/ogre fights.
# Rats and wolves keep their identities; goblins/bandits/skeletons/spiders/
# dark_mage/scorpion can roll into a slam.
func _maybe_roll_pattern_override() -> void:
	_pattern_override = &""
	if sprite_type == "rat" or sprite_type == "wolf":
		return
	if sprite_type == "troll" or sprite_type == "ogre" or sprite_type == "ancient_golem":
		return  # already always-slam
	# 22% chance per attack — frequent enough you'll see it within a fight,
	# rare enough that it stays a surprise beat.
	if randf() < 0.22:
		_pattern_override = &"slam"

const _CHARGE_SPEED: float = 320.0
const _CHARGE_DAMAGE_MULT: float = 1.30
const _CHARGE_KNOCKBACK: float = 90.0

# Phase 3.3 — global ATTACK COORDINATOR (danger budget).
# Limits how many enemies can be in attack wind-up at any time so groups
# apply pressure without all swinging at once. Static so all enemies
# share state without a new autoload.
# Token costs per enemy tier:
#   LIGHT (rat, skeleton, goblin)         — 1
#   MEDIUM (bandit, wolf, spider)         — 2
#   HEAVY (troll, ogre, ancient_golem)    — 3
#   ELITE / mini_boss                     — 4
# Default budget: 5 tokens shared globally → roughly 2 light + 1 heavy or
# 2 medium + 1 light simultaneous attackers. Tunable.
static var _attack_tokens_used: int = 0
const _ATTACK_TOKEN_BUDGET_BASE: int = 5
const _ATTACK_TOKEN_BUDGET_HEATED: int = 7   # +2 when player is HEATED
const _ATTACK_TOKEN_BUDGET_FRENZY: int = 9   # +4 when player is FRENZY


# Phase 3.10 — adaptive intensity. The coordinator budget rises when
# the player is on a high-momentum run so enemies apply MORE pressure
# when the player is dominating. Drops back to base after they cool.
static func _current_attack_budget() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _ATTACK_TOKEN_BUDGET_BASE
	var players: Array = tree.get_nodes_in_group("player")
	if players.is_empty():
		return _ATTACK_TOKEN_BUDGET_BASE
	var player = players[0]
	if not is_instance_valid(player):
		return _ATTACK_TOKEN_BUDGET_BASE
	var mom = player.get_node_or_null("MomentumComponent")
	if mom == null or not mom.has_method("current_threshold_name"):
		return _ATTACK_TOKEN_BUDGET_BASE
	var thr: StringName = mom.current_threshold_name()
	if thr == &"frenzy":
		return _ATTACK_TOKEN_BUDGET_FRENZY
	if thr == &"heated":
		return _ATTACK_TOKEN_BUDGET_HEATED
	return _ATTACK_TOKEN_BUDGET_BASE


static func _try_reserve_attack_token(cost: int) -> bool:
	if _attack_tokens_used + cost > _current_attack_budget():
		return false
	_attack_tokens_used += cost
	return true

static func _release_attack_token(cost: int) -> void:
	_attack_tokens_used = max(0, _attack_tokens_used - cost)
# Phase 1B.6b — visual hit-reaction component. Created in _ready, profile
# selected from enemy tier (mini_boss / heavy sprites → tougher reaction
# tier). Knockback/stagger emissions are intentionally NOT connected this
# stage — the existing apply_knockback path stays the sole writer of
# _knockback_velocity. 1B.7 reconciles the dual paths.
var _hit_reaction: Node = null
# Phase 2.0 — poise component. Created in _ready; tier preset mirrors
# the HitReaction tier so light enemies break easily, bosses don't.
var _poise: Node = null
# Phase 2.6 — status effects on this enemy.
var _statuses: Node = null

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	var tex = SpriteGenerator.get_texture(sprite_type)
	if tex:
		sprite.texture = tex
	hp_bar.visible = false
	name_label.visible = false

	# Phase 1B.6b — visual hit reaction component.
	_hit_reaction = HitReactionComponentCls.new()
	_hit_reaction.name = "HitReactionComponent"
	_hit_reaction.reaction_pivot = sprite
	var tier_int: int = _pick_reaction_tier()  # 0=LIGHT...4=BOSS
	_hit_reaction.profile = HitReactionDataCls.new().apply_preset(tier_int)
	# Existing _do_hit_flash owns the modulate flash; the component
	# handles position/scale/rotation only this stage.
	_hit_reaction.profile.hit_flash_strength = 1.0
	add_child(_hit_reaction)
	# Subscribe to confirmed hits — fires visual flinch only this stage.
	# Knockback emissions from the component are intentionally NOT
	# connected; the existing apply_knockback path stays the sole writer
	# of _knockback_velocity.
	if CombatManager.has_signal("hit_resolved"):
		CombatManager.hit_resolved.connect(_on_hit_resolved_for_reaction)
	# Phase 1B.6e: stagger wiring. The component decides WHEN to stagger
	# (tier resistance, stagger_only_heavy, repeated-hit dampening); we
	# decide WHAT it does to AI here.
	if _hit_reaction.has_signal("stagger_requested"):
		_hit_reaction.stagger_requested.connect(_on_stagger_requested)
	if _hit_reaction.has_signal("stagger_ended"):
		_hit_reaction.stagger_ended.connect(_on_stagger_ended)

	# Phase 2.0 — poise component. Same tier mapping as HitReaction so
	# the heaviest enemies are also the toughest to break.
	_poise = PoiseComponentCls.new()
	_poise.name = "PoiseComponent"
	_poise.profile = PoiseProfileCls.new().apply_preset(tier_int)
	add_child(_poise)
	if _poise.has_signal("poise_broken"):
		_poise.poise_broken.connect(_on_poise_broken)
	if _poise.has_signal("poise_recovered"):
		_poise.poise_recovered.connect(_on_poise_recovered)
	if _poise.has_signal("poise_changed"):
		_poise.poise_changed.connect(_on_poise_changed)
	# Phase 6.x — build the poise bar (hidden until first damage).
	_build_poise_bar()

	# Phase 2.6 — status effects.
	_statuses = StatusEffectComponentCls.new()
	_statuses.name = "StatusEffectComponent"
	add_child(_statuses)

	# Phase 3.4b — roll for elite modifier on regular (non-boss) enemies.
	if not is_mini_boss and randf() < ELITE_CHANCE:
		_roll_elite_modifier()
	# Visual: pulse the sprite slightly while "exposed" is active so the
	# player sees they earned a damage bonus. Hooked via signals.
	if _statuses.has_signal("status_applied"):
		_statuses.status_applied.connect(_on_status_applied)
	if _statuses.has_signal("status_expired"):
		_statuses.status_expired.connect(_on_status_expired)
	# Detect mobile for font scaling
	var vp_size = get_viewport().get_visible_rect().size
	var is_mobile = GameManager.is_mobile_device()
	# Scale enemy name label for mobile — larger font, moved higher so it
	# doesn't overlap the sprite and block taps
	if is_mobile:
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.position = Vector2(-60, -78)
		name_label.size = Vector2(120, 36)
	# Initialize shared label settings once (static, shared across all enemies)
	if not _dmg_settings_normal:
		_dmg_settings_normal = LabelSettings.new()
		_dmg_settings_normal.font_size = 40 if is_mobile else 14
		_dmg_settings_normal.font_color = Color.WHITE
		_dmg_settings_normal.outline_size = 4 if is_mobile else 2
		_dmg_settings_normal.outline_color = Color.BLACK
	if not _dmg_settings_crit:
		_dmg_settings_crit = LabelSettings.new()
		_dmg_settings_crit.font_size = 56 if is_mobile else 28
		_dmg_settings_crit.font_color = Color(1.0, 0.95, 0.1)
		_dmg_settings_crit.outline_size = 5 if is_mobile else 3
		_dmg_settings_crit.outline_color = Color.BLACK

	# Set pivot for zoom compensation (scale from center, not top-left)
	name_label.pivot_offset = name_label.size / 2.0
	hp_bar.pivot_offset = hp_bar.size / 2.0

	# Shadow
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)
	_shadow.move_to_front()
	move_child(_shadow, 0)

	# Enable mouse hover/click detection
	input_pickable = true
	# Outline shader (shared across all enemies, initialized once)
	if not _outline_shader:
		_outline_shader = Shader.new()
		# v0.92.4 — THICKER outline (samples 2-pixel ring) + MUCH stronger
		# top-light (top_lift 0.40, bottom_dim 0.26) for that pronounced
		# Stardew/HLD pixel-art pop. Bonus: warm RIM at top-left edge for
		# directional sun feel.
		_outline_shader.code = "shader_type canvas_item;
uniform bool enabled = false;
uniform vec4 line_color : source_color = vec4(1.0, 0.3, 0.3, 0.85);
uniform float top_lift = 0.40;
uniform float bottom_dim = 0.26;
uniform vec3 rim_color : source_color = vec3(1.10, 0.95, 0.65);
uniform float rim_strength = 0.45;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (enabled && tex.a < 0.1) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		// Thicker outline: 2-pixel ring, 8 + 8 samples.
		for (int dx = -2; dx <= 2; dx++) {
			for (int dy = -2; dy <= 2; dy++) {
				if (dx == 0 && dy == 0) continue;
				float dist_sq = float(dx * dx + dy * dy);
				if (dist_sq > 5.0) continue;
				a += texture(TEXTURE, UV + vec2(float(dx) * ps.x, float(dy) * ps.y)).a;
			}
		}
		if (a > 0.0) {
			COLOR = line_color;
		} else {
			COLOR = tex;
		}
	} else {
		float lift = top_lift * (1.0 - UV.y);
		float dim = bottom_dim * UV.y;
		vec3 lit = tex.rgb + vec3(lift) - vec3(dim);
		// Warm rim along the top edge — sun-touched highlight.
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float above = texture(TEXTURE, UV + vec2(0.0, -ps.y * 2.0)).a;
		float rim_mask = (1.0 - above) * step(UV.y, 0.32);
		lit += rim_color * rim_mask * rim_strength;
		COLOR = vec4(clamp(lit, 0.0, 2.0), tex.a);
	}
}
"
	if not _info_label_settings:
		_info_label_settings = LabelSettings.new()
		_info_label_settings.font_size = 32 if is_mobile else 11
		_info_label_settings.font_color = Color(1.0, 0.6, 0.6)
		_info_label_settings.outline_size = 4 if is_mobile else 2
		_info_label_settings.outline_color = Color.BLACK
	# v0.90.3 — default outline ON (black) so all enemies pop visually.
	_ensure_outline_material()
	# v0.91.2 — modern pixel-art DROP SHADOW under every character.
	_ensure_drop_shadow()
	# v0.92.4 — TYPE-COLORED AMBIENT HALO under every enemy. Identity glow
	# that pulses slowly. Makes every character feel like an entity with
	# presence instead of a sprite sitting on the ground.
	_ensure_type_halo()
	# v0.91.7 — per-instance chromatic variance. Every enemy of the same type
	# now picks a slight tint shift so a group of 6 goblins doesn't look like
	# 6 clones. Bypassed for mini-bosses (they have their own identity tint).
	if not is_mini_boss:
		var jitter_r: float = randf_range(0.88, 1.08)
		var jitter_g: float = randf_range(0.90, 1.06)
		var jitter_b: float = randf_range(0.85, 1.05)
		_base_modulate = Color(jitter_r, jitter_g, jitter_b, 1.0)
		if sprite != null:
			sprite.modulate = _base_modulate
	# v0.91.7 — gentle idle BREATHE: slight vertical scale pulse so enemies
	# don't read as static cardboard cutouts when idling.
	_start_enemy_idle_breathe()
	# Connect mouse hover signals for outline (swaps color to red on hover)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Start with a short random idle delay before first patrol
	_patrol_wait_timer = randf_range(0.3, 1.5)

	# Stagger sleep checks so not all enemies check on the same frame
	_sleep_check_timer = randf_range(0.0, SLEEP_CHECK_INTERVAL)
	# Stagger alert checks across enemies
	_alert_check_timer = randf_range(0.0, ALERT_CHECK_INTERVAL)


func initialize(config: Dictionary) -> void:
	enemy_name = config.get("name", "Enemy")
	enemy_level = config.get("level", 1)
	aggro_range = config.get("aggro_range", 120.0)
	xp_reward = config.get("xp_reward", 15)
	gold_reward = config.get("gold_reward", 5)
	drop_table = config.get("drop_table", "")
	sprite_type = config.get("sprite_type", "goblin")
	is_mini_boss = config.get("is_mini_boss", false)

	# Use stats_level for attribute scaling (dampened when boosted above natural range)
	# while enemy_level is the display level shown to the player
	var sl = config.get("stats_level", enemy_level)
	# v0.90.1 — global pacing pass: enemies have ~65% of prior HP so swings
	# actually feel like they're chewing through bodies. Player damage and
	# elite scaling are unchanged.
	stats.max_hp = 20 + sl * 10
	stats.current_hp = stats.max_hp
	stats.strength = 5 + sl * 2
	stats.agility = 3 + sl
	stats.intelligence = 2 + sl
	stats.armor = sl
	stats.attack_damage = config.get("attack_damage", 5 + sl * 3)
	stats.attack_range = config.get("attack_range", 35.0)
	stats.move_speed = config.get("move_speed", 80.0)
	stats.primary_stat = "strength"
	attack_cooldown = config.get("attack_cooldown", 1.2)

	# Scale patrol radius with move speed — faster enemies roam much further
	_patrol_radius = 300.0 + stats.move_speed * 3.0
	if is_mini_boss:
		# Minibosses roam much wider — aggressive territorial patrol
		_patrol_radius = 1200.0 + stats.move_speed * 5.0
		_patrol_speed_factor = 0.85  # Minibosses patrol faster (85% vs 65%)
	chase_range = _patrol_radius + 350.0

	# Pre-compute squared distances (avoids sqrt every frame in hot path)
	_aggro_range_sq = aggro_range * aggro_range
	_chase_range_sq = chase_range * chase_range
	_attack_range_sq = stats.attack_range * stats.attack_range
	var disengage = stats.attack_range * 1.8
	_attack_disengage_sq = disengage * disengage
	var alert_range = aggro_range * ALERT_RANGE_MULTIPLIER
	_alert_range_sq = alert_range * alert_range

	# Rats always have bleeding at 2% per hit
	if sprite_type == "rat":
		_effect_type = "bleeding"
		_effect_chance = 0.02
	# Other enemies: randomly assign an effect (~25% of enemies have an effect proc)
	elif randf() < 0.25:
		const EFFECT_TYPES = ["knockback", "paralyze", "slow"]
		_effect_type = EFFECT_TYPES[randi() % EFFECT_TYPES.size()]
		match _effect_type:
			"knockback":
				_effect_chance = 0.12  # 12% per hit
			"paralyze":
				_effect_chance = 0.08  # 8% per hit — rarer, strong
			"slow":
				_effect_chance = 0.10  # 10% per hit

	if is_inside_tree():
		var tex = SpriteGenerator.get_texture(sprite_type)
		if tex:
			sprite.texture = tex
		name_label.text = "%s Lv%d" % [enemy_name, enemy_level]
		_update_hp_bar()

func show_selection() -> void:
	_is_selected = true
	hp_bar.visible = true
	name_label.visible = true

func hide_selection() -> void:
	_is_selected = false
	if stats.current_hp >= stats.max_hp and current_state == State.IDLE:
		hp_bar.visible = false
		name_label.visible = false

var _idle_breathe_tween: Tween = null
var _idle_wobble_tween: Tween = null
var _halo_tween: Tween = null
var _was_aggrod_last_tick: bool = false

func _flare_type_halo() -> void:
	# Bright punch when an enemy first notices the player. Halo briefly
	# triples in alpha + scales up 1.5×, then settles back to the slow pulse.
	var halo: Sprite2D = get_node_or_null("TypeHalo") as Sprite2D
	if halo == null:
		return
	# Kill the slow pulse for a beat so it can flare cleanly.
	if _halo_tween != null and _halo_tween.is_valid():
		_halo_tween.kill()
	var c: Color = _halo_color()
	var base_scale_x: float = halo.scale.x
	var base_scale_y: float = halo.scale.y
	halo.modulate = Color(c.r, c.g, c.b, 0.95)
	halo.scale = Vector2(base_scale_x * 1.6, base_scale_y * 1.6)
	var flare := halo.create_tween()
	flare.set_parallel(true)
	flare.tween_property(halo, "scale", Vector2(base_scale_x, base_scale_y), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flare.tween_property(halo, "modulate:a", 0.45, 0.45)
	flare.chain().tween_callback(_restart_halo_pulse.bind(halo, base_scale_x, base_scale_y))

func _restart_halo_pulse(halo: Sprite2D, sx: float, sy: float) -> void:
	if halo == null or not is_instance_valid(halo):
		return
	halo.scale = Vector2(sx, sy)
	var pulse_dur: float = randf_range(1.3, 1.9)
	_halo_tween = halo.create_tween().set_loops()
	_halo_tween.tween_property(halo, "modulate:a", 0.55, pulse_dur).set_trans(Tween.TRANS_SINE)
	_halo_tween.tween_property(halo, "modulate:a", 0.30, pulse_dur).set_trans(Tween.TRANS_SINE)

func _halo_color() -> Color:
	# Identity color per enemy type. Saturated, recognizable, fun.
	if is_mini_boss:
		return Color(1.8, 0.35, 0.25, 1.0)  # blazing crimson — boss energy
	match sprite_type:
		"rat": return Color(1.2, 0.4, 0.5, 1.0)         # dusty pink
		"goblin": return Color(0.5, 1.6, 0.35, 1.0)     # acid green
		"wolf": return Color(1.3, 0.85, 0.45, 1.0)      # warm umber
		"skeleton": return Color(0.9, 1.3, 1.6, 1.0)    # icy blue-white
		"spider": return Color(1.4, 0.55, 1.6, 1.0)     # toxic magenta
		"bandit": return Color(1.5, 0.7, 0.3, 1.0)      # rusty orange
		"troll": return Color(0.6, 1.3, 0.7, 1.0)       # mossy teal
		"dark_mage": return Color(1.4, 0.4, 1.7, 1.0)   # arcane violet
		"ogre": return Color(1.3, 0.6, 0.2, 1.0)        # ember
		"scorpion": return Color(1.6, 0.9, 0.2, 1.0)    # venom gold
	return Color(1.2, 1.0, 0.6, 1.0)  # default warm

func _ensure_type_halo() -> void:
	if has_node("TypeHalo"):
		return
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var halo := Sprite2D.new()
	halo.name = "TypeHalo"
	halo.texture = tex
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var c: Color = _halo_color()
	c.a = 0.42
	halo.modulate = c
	# Halo size scales with enemy weight class.
	var s_base: float = 2.6
	if _get_token_cost() >= 3:
		s_base = 3.6
	elif _get_token_cost() >= 2:
		s_base = 3.0
	halo.scale = Vector2(s_base, s_base * 0.65)
	halo.position = Vector2(0, 0)
	halo.z_index = -4  # Below drop shadow (-3) so shadow stays solid on top.
	add_child(halo)
	move_child(halo, 0)
	# Slow alpha pulse for life. Random phase per enemy so packs don't sync.
	var pulse_dur: float = randf_range(1.3, 1.9)
	var low_a: float = 0.30
	var high_a: float = 0.55
	_halo_tween = halo.create_tween().set_loops()
	_halo_tween.tween_property(halo, "modulate:a", high_a, pulse_dur).set_trans(Tween.TRANS_SINE)
	_halo_tween.tween_property(halo, "modulate:a", low_a, pulse_dur).set_trans(Tween.TRANS_SINE)

func _start_enemy_idle_breathe() -> void:
	if sprite == null:
		return
	if _idle_breathe_tween != null and _idle_breathe_tween.is_valid():
		return
	# v0.92.4 — bumped pulse amplitude (was 1.025/0.965, now 1.05/0.94) so
	# the breath is actually noticeable instead of subliminal.
	var dur: float = randf_range(1.6, 2.4)
	var bx: float = _base_scale.x
	var by: float = _base_scale.y
	var pulse_x: float = bx * 1.05
	var pulse_y: float = by * 0.94
	_idle_breathe_tween = create_tween().set_loops()
	_idle_breathe_tween.tween_property(sprite, "scale", Vector2(pulse_x, pulse_y), dur).set_trans(Tween.TRANS_SINE)
	_idle_breathe_tween.tween_property(sprite, "scale", _base_scale, dur).set_trans(Tween.TRANS_SINE)
	# v0.92.5 — side-to-side WOBBLE on top of breathe. Adds a Wildfrost
	# bouncy feel to every enemy at rest. Wobble runs at a slightly
	# different frequency so it doesn't sync with the breathe.
	var wobble_dur: float = randf_range(1.1, 1.6)
	var wobble_amount: float = 1.2  # pixels
	_idle_wobble_tween = sprite.create_tween().set_loops()
	_idle_wobble_tween.tween_property(sprite, "position:x", wobble_amount, wobble_dur).set_trans(Tween.TRANS_SINE)
	_idle_wobble_tween.tween_property(sprite, "position:x", -wobble_amount, wobble_dur).set_trans(Tween.TRANS_SINE)

func _ensure_drop_shadow() -> void:
	# v0.91.2 — mascara-thick black elliptical shadow disc baked under the
	# character so they read as grounded (Stardew/HLD-style). Uses the
	# crystal_white texture as a simple disc; scaled wide-and-short and
	# tinted near-pure-black with alpha. Width scales with token cost so
	# heavies cast bigger shadows.
	if has_node("DropShadow"):
		return
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var s := Sprite2D.new()
	s.name = "DropShadow"
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = Color(0.0, 0.0, 0.0, 0.55)
	var width: float = 1.6
	if _get_token_cost() >= 3:
		width = 2.3
	elif _get_token_cost() >= 2:
		width = 1.9
	s.scale = Vector2(width, 0.55)
	s.position = Vector2(0, 2)
	s.z_index = -3
	add_child(s)
	move_child(s, 0)  # Render behind sprite.

func _ensure_outline_material() -> void:
	# v0.90.3 — every enemy gets a permanent BLACK outline by default so
	# they read as drawn pixel-art instead of procedural-blob silhouettes.
	# Hover swaps the color to red; mouse_exit restores black.
	if sprite == null or _outline_shader == null:
		return
	if sprite.material == null:
		var mat = ShaderMaterial.new()
		mat.shader = _outline_shader
		mat.set_shader_parameter("line_color", Color(0.05, 0.05, 0.08, 0.95))
		mat.set_shader_parameter("enabled", true)
		sprite.material = mat

func _on_mouse_entered() -> void:
	if not _is_dead and sprite and _outline_shader:
		_ensure_outline_material()
		sprite.material.set_shader_parameter("line_color", Color(1.0, 0.3, 0.3, 0.95))
		sprite.material.set_shader_parameter("enabled", true)

func _on_mouse_exited() -> void:
	if sprite and sprite.material != null:
		sprite.material.set_shader_parameter("line_color", Color(0.05, 0.05, 0.08, 0.95))
		sprite.material.set_shader_parameter("enabled", true)

func show_info() -> void:
	if _is_dead:
		return
	# Show name + HP bar
	show_selection()
	# Remove existing info label if any
	if _info_label and is_instance_valid(_info_label):
		_info_label.queue_free()
	_info_label = Label.new()
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_parts: Array[String] = []
	info_parts.append("HP %d/%d  ATK %d  ARM %d" % [stats.current_hp, stats.max_hp, stats.attack_damage, stats.armor])
	if _effect_type != "":
		info_parts.append("Effect: %s" % _effect_type.capitalize())
	_info_label.text = "\n".join(info_parts)
	_info_label.label_settings = _info_label_settings
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(-55, -58)
	var _zc = _get_zoom_compensation()
	_info_label.scale = Vector2(_zc, _zc)
	add_child(_info_label)
	# Fade out after a moment
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_info_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if _info_label and is_instance_valid(_info_label):
			_info_label.queue_free()
			_info_label = null
		hide_selection()
	)

func _get_zoom_compensation() -> float:
	var frame = Engine.get_process_frames()
	if _zoom_comp_frame == frame:
		return _zoom_comp_value
	_zoom_comp_frame = frame
	var cam = get_viewport().get_camera_2d()
	if cam:
		_zoom_comp_value = ZOOM_REF / cam.zoom.x
	else:
		_zoom_comp_value = 1.0
	return _zoom_comp_value

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# v0.92.5 — detect aggro transition: if we just entered CHASE/ATTACK,
	# flare the type halo. Visual feedback so the player feels every enemy
	# notice them.
	if (current_state == State.CHASE or current_state == State.ATTACK) and not _was_aggrod_last_tick:
		_flare_type_halo()
	_was_aggrod_last_tick = (current_state == State.CHASE or current_state == State.ATTACK)

	# Phase 3.4b — Vampiric (healer) elite regen: ~4 HP/sec.
	if _elite_modifier == &"healer" and stats.current_hp < stats.max_hp:
		_healer_tick_accum += delta
		while _healer_tick_accum >= 0.25:
			_healer_tick_accum -= 0.25
			stats.current_hp = min(stats.max_hp, stats.current_hp + 1)
			_update_hp_bar()

	# Phase 1B.6c: hit-stop. Skip AI + movement while frozen so the
	# impact has weight. Knockback is intentionally NOT skipped — the
	# decay still ticks below so freeze doesn't lock physics state.
	if HitStopController != null and HitStopController.is_frozen(self):
		# Keep the knockback decay running so we don't get stuck moving.
		if _knockback_velocity.length_squared() > 4.0:
			velocity = _knockback_velocity
			_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)
			move_and_slide()
		return

	# Distance-based sleep/wake check (throttled) — only for awake enemies.
	# Sleeping enemies have physics_process disabled; creep_camp handles their wake check.
	_sleep_check_timer -= delta
	if _sleep_check_timer <= 0.0:
		_sleep_check_timer = SLEEP_CHECK_INTERVAL
		_update_sleep_state()

	# Apply knockback impulse — overrides state machine until it decays
	if _knockback_velocity.length_squared() > 4.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 14.0)
		move_and_slide()
		return
	# After knockback ends, if we were fighting, extend chase range so we don't
	# immediately deaggro just because knockback pushed us far from home
	if _knockback_velocity != Vector2.ZERO and (current_state == State.CHASE or current_state == State.ATTACK):
		var dist_sq_from_home = global_position.distance_squared_to(home_position)
		if dist_sq_from_home > _chase_range_sq * 0.8:
			_chase_range_sq = dist_sq_from_home + _aggro_range_sq
	_knockback_velocity = Vector2.ZERO

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RETURN:
			_process_return(delta)

	# Clamp position to movement bounds (dungeon walls etc.)
	if movement_bounds.has_area():
		global_position = global_position.clamp(movement_bounds.position, movement_bounds.end)

	# Zoom-compensate in-world labels so text stays readable at all zoom levels
	# Only update when zoom actually changed (avoids redundant property sets)
	if name_label.visible or hp_bar.visible:
		var _zc = _get_zoom_compensation()
		if absf(_zc - _last_zoom_comp) > 0.001:
			_last_zoom_comp = _zc
			var _zs = Vector2(_zc, _zc)
			if name_label.visible:
				name_label.scale = _zs
			if hp_bar.visible:
				hp_bar.scale = _zs
			if _info_label and is_instance_valid(_info_label):
				_info_label.scale = _zs

func _check_watchtower_aggro() -> bool:
	# Enemies also aggro on nearby watchtower
	var towers = get_tree().get_nodes_in_group("watchtower")
	for tower in towers:
		if not is_instance_valid(tower) or tower._is_destroyed:
			continue
		var dist_sq = global_position.distance_squared_to(tower.global_position)
		if dist_sq < _aggro_range_sq:
			target = tower
			current_state = State.CHASE
			name_label.visible = true
			return true
	return false

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	# Check for player aggro (squared distance avoids sqrt)
	var player = _get_player()
	if player:
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return
		# Random alert: chance to notice the player at extended range
		if _try_alert_aggro(delta, player, dist_sq):
			return
	# Check watchtower aggro
	if _check_watchtower_aggro():
		return

	# Count down idle pause, then pick a patrol waypoint
	_patrol_wait_timer -= delta
	if _patrol_wait_timer <= 0:
		_pick_patrol_target()
		current_state = State.PATROL

func _pick_patrol_target() -> void:
	# Choose a random point within patrol radius of home
	var angle = randf() * TAU
	var dist = randf_range(_patrol_radius * 0.3, _patrol_radius)
	_patrol_target = home_position + Vector2(cos(angle), sin(angle)) * dist
	# Minibosses avoid town center — re-roll if target is too close to origin
	if is_mini_boss:
		for _i in range(3):
			if _patrol_target.length() < 900.0:
				angle = randf() * TAU
				dist = randf_range(_patrol_radius * 0.3, _patrol_radius)
				_patrol_target = home_position + Vector2(cos(angle), sin(angle)) * dist
			else:
				break

func _try_alert_aggro(delta: float, player: Node2D, dist_sq: float) -> bool:
	# Periodic random chance to detect the player at extended range (2x aggro range).
	# Creates unpredictable aggression — enemies sometimes notice you from further away.
	_alert_check_timer -= delta
	if _alert_check_timer > 0.0:
		return false
	_alert_check_timer = ALERT_CHECK_INTERVAL
	if dist_sq < _alert_range_sq and randf() < ALERT_CHANCE:
		target = player
		current_state = State.CHASE
		name_label.visible = true
		return true
	return false

func _process_patrol(delta: float) -> void:
	# Check for player aggro even while patrolling (squared distance avoids sqrt)
	var player = _get_player()
	if player:
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return
		# Random alert: chance to notice the player at extended range
		if _try_alert_aggro(delta, player, dist_sq):
			return
	# Check watchtower aggro
	if _check_watchtower_aggro():
		return

	var dist_sq_to_target = global_position.distance_squared_to(_patrol_target)
	if dist_sq_to_target < 64.0:  # 8^2
		# Reached patrol waypoint — short pause then go idle
		velocity = Vector2.ZERO
		current_state = State.IDLE
		# Minibosses idle briefly — restless, always on the move
		_patrol_wait_timer = randf_range(0.2, 0.8) if is_mini_boss else randf_range(0.5, 2.0)
		return

	var dir = (_patrol_target - global_position).normalized()
	velocity = dir * stats.move_speed * _patrol_speed_factor
	# Flip sprite based on movement direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

var _cached_sep_push: Vector2 = Vector2.ZERO
var _sep_push_skip: int = 0  # Skip counter — recompute every 3rd frame

func _get_separation_push(in_attack: bool = false) -> Vector2:
	# Throttle: recompute every 3 physics frames, reuse cache otherwise
	_sep_push_skip += 1
	if _sep_push_skip < 3:
		return _cached_sep_push
	_sep_push_skip = 0
	# Proximity-based soft separation — enemies repel each other without hard collisions
	# Optimized: only check camp-mates (parent's children) instead of all enemies globally
	var push = Vector2.ZERO
	var pos = global_position
	var check_radius: float = 30.0
	var check_radius_sq: float = check_radius * check_radius
	var parent = get_parent()
	if not parent:
		_cached_sep_push = push
		return push
	for other in parent.get_children():
		if other == self:
			continue
		if not other.is_in_group("enemies") or other._is_dead:
			continue
		var diff = pos - other.global_position
		var dist_sq = diff.length_squared()
		if dist_sq < check_radius_sq and dist_sq > 0.1:
			# Push strength falls off with distance; direction from diff/dist_sq
			# is slightly biased toward closer enemies (intentional — stronger repel)
			var strength = (1.0 - dist_sq / check_radius_sq) * 150.0
			push += diff * (strength / check_radius)
	# Push away from the player to prevent piling on top of them
	if is_instance_valid(target):
		var player_diff = pos - target.global_position
		var player_dist_sq = player_diff.length_squared()
		var player_push_radius_sq: float = 900.0  # 30.0 * 30.0
		if player_dist_sq < player_push_radius_sq and player_dist_sq > 0.1:
			var strength = (1.0 - player_dist_sq / player_push_radius_sq) * 200.0
			push += player_diff * (strength / 30.0)
	# Softer cap during attack so combat positioning isn't disrupted
	var max_push = 70.0 if in_attack else 120.0
	var max_push_sq = max_push * max_push
	var push_len_sq = push.length_squared()
	if push_len_sq > max_push_sq:
		push *= max_push / sqrt(push_len_sq)  # Only sqrt when actually clamping
	_cached_sep_push = push
	return push

func _process_chase(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	var dist_sq_to_target = global_position.distance_squared_to(target.global_position)
	var dist_sq_from_home = global_position.distance_squared_to(home_position)

	if dist_sq_from_home > _chase_range_sq:
		current_state = State.RETURN
		target = null
		return

	if dist_sq_to_target <= _attack_range_sq:
		current_state = State.ATTACK
		return

	# Keep attack timer ticking while chasing so enemies pushed out of attack
	# range by sibling separation don't lose all their attack progress
	if _attack_timer > 0.0:
		_attack_timer -= delta * 0.5  # Tick at half rate while closing in

	var dir = (target.global_position - global_position).normalized()
	velocity = dir * stats.move_speed + _get_separation_push()
	# Flip sprite based on movement direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	move_and_slide()

func _process_attack(delta: float) -> void:
	if not is_instance_valid(target):
		current_state = State.RETURN
		return

	var dist_sq = global_position.distance_squared_to(target.global_position)
	if dist_sq > _attack_disengage_sq:
		current_state = State.CHASE
		return

	# Face the target
	var to_target = target.global_position - global_position
	if to_target.x < -0.1:
		sprite.flip_h = true
	elif to_target.x > 0.1:
		sprite.flip_h = false

	# Keep enemies spread apart and maintain comfortable combat distance
	var sep = _get_separation_push(true)
	var to_target_dist_sq = to_target.length_squared()
	var ideal_dist = stats.attack_range * 0.85
	var ideal_dist_sq = ideal_dist * ideal_dist
	var move_toward = Vector2.ZERO
	if to_target_dist_sq > 0.01:
		var ideal_plus_5_sq = (ideal_dist + 5.0) * (ideal_dist + 5.0)
		# Only compute sqrt when we actually need to adjust position
		if to_target_dist_sq < ideal_dist_sq or to_target_dist_sq > ideal_plus_5_sq:
			var dist = sqrt(to_target_dist_sq)
			var dir_to_target = to_target / dist  # normalized without second sqrt
			if dist < ideal_dist:
				move_toward = -dir_to_target * stats.move_speed * 0.15
			else:
				var urgency = clampf((dist - ideal_dist) / (stats.attack_range * 0.5), 0.1, 0.3)
				move_toward = dir_to_target * stats.move_speed * urgency
			var perp = Vector2(-dir_to_target.y, dir_to_target.x)
			sep = perp * sep.dot(perp)
		else:
			# In ideal range — just project separation perpendicular
			var inv_dist = 1.0 / sqrt(to_target_dist_sq)
			var dir_to_target = to_target * inv_dist
			var perp = Vector2(-dir_to_target.y, dir_to_target.x)
			sep = perp * sep.dot(perp)

	# Phase 3.4 — CHARGE pattern: during windup, the wolf dashes toward the
	# target at high speed instead of maintaining ideal distance. Body
	# physics still respects collision, so charging into a wall stops
	# them — perfect for vulnerability punish.
	if _windup_started and _get_attack_pattern() == &"charge" and is_instance_valid(target):
		var dir_to_t: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir_to_t * _CHARGE_SPEED
		move_and_slide()
		# Optional: spawn a brief afterimage every couple frames for
		# motion-blur readability.
		if randf() < 0.4:
			_spawn_charge_afterimage()
	else:
		velocity = move_toward + sep
		move_and_slide()

	_attack_timer -= delta
	# Phase 3.0a — telegraph wind-up. As the attack timer drops past the
	# enemy's wind-up threshold, request a danger token from the global
	# coordinator. If granted, fire the anticipation visual; if denied,
	# keep ticking (we'll try again at the next wind-up boundary).
	var windup_sec: float = _get_windup_sec()
	if not _windup_started and _attack_timer <= windup_sec and _attack_timer > 0.0:
		var token_cost: int = _get_token_cost()
		if _try_reserve_attack_token(token_cost):
			_reserved_token_cost = token_cost
			_windup_started = true
			_begin_attack_windup()
		else:
			# No budget — defer this attack by half a cooldown so the
			# enemy circles / postures instead of clogging the queue.
			_attack_timer = attack_cooldown * 0.5
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		_windup_started = false
		_release_attack_token(_reserved_token_cost)
		_reserved_token_cost = 0
		_end_attack_windup()
		# Only deal damage if still close enough to actually hit
		var hit_range_sq = stats.attack_range * stats.attack_range * 2.25  # 1.5x range
		if dist_sq > hit_range_sq:
			# Phase 3.5 — WHIFF! Heavy enemies are vulnerable after a missed
			# telegraph (medium enemies too, briefer). Punish window opens.
			_trigger_vulnerability_window(&"whiff")
			return
		if target.has_method("take_damage"):
			var pattern: StringName = _get_attack_pattern()
			# SLAM: radial AoE around enemy regardless of facing. Damages
			# anyone within slam_radius. Big telegraph already shown.
			if pattern == &"slam":
				_resolve_slam_strike(dist_sq <= hit_range_sq)
				return
			# CHARGE: high-speed dash already happened during windup. Now
			# resolve the impact. If the wolf reached the target → big
			# damage + knockback. If it didn't → wall collision, vulnerability.
			if pattern == &"charge":
				_resolve_charge_strike(dist_sq)
				return
			# Skip non-slam/charge if out of range — already handled above as whiff.
			if dist_sq > hit_range_sq:
				return
			# TRIPLE STAB: 3 quick hits per attack cycle, lower per-hit damage.
			if pattern == &"triple_stab":
				_resolve_stab_strike()
				return
			# STANDARD: one strike + 15% special chance.
			var is_special = randf() < 0.15
			var dmg_mult = 1.0
			if is_special:
				dmg_mult = _get_special_attack_mult()
				_attack_timer = attack_cooldown * 1.3  # Slightly longer recovery after special
			# Phase 3.8 — bloodthirst shrine aura: +25% damage if inside.
			var shrine_mult: float = BloodthirstShrineCls.get_active_buff_multiplier(global_position, get_tree())
			var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict(), dmg_mult * _elite_damage_dealt_mult() * shrine_mult)
			target.take_damage(result["damage"], result["is_crit"])
			_do_attack_lunge(is_special)
			# Rare effect proc
			if _effect_chance > 0.0 and randf() < _effect_chance:
				_apply_effect_to_target(target)

func _try_rat_squeal() -> void:
	var now_msec = Time.get_ticks_msec()
	if now_msec - _last_rat_squeal_msec < int(RAT_SQUEAL_INTERVAL * 1000.0):
		return
	_last_rat_squeal_msec = now_msec
	var variant = randi_range(1, 3)
	AudioManager.play_sfx("rat_squeal_%d" % variant, -8.0)

func _process_return(delta: float) -> void:
	var dist_sq = global_position.distance_squared_to(home_position)
	if dist_sq < 25.0:  # 5^2
		velocity = Vector2.ZERO
		current_state = State.IDLE
		stats.current_hp = stats.max_hp
		_update_hp_bar()
		_patrol_wait_timer = randf_range(0.3, 1.0)
		if not _is_selected:
			name_label.visible = false
		return

	# Re-aggro if player walks into aggro range while returning
	var player = _get_player()
	if player:
		var dist_sq_to_player = global_position.distance_squared_to(player.global_position)
		if dist_sq_to_player < _aggro_range_sq:
			target = player
			current_state = State.CHASE
			name_label.visible = true
			return

	var dir = (home_position - global_position).normalized()
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false
	velocity = dir * stats.move_speed * 1.8
	move_and_slide()

func _apply_effect_to_target(t: Node2D) -> void:
	if not is_instance_valid(t):
		return
	match _effect_type:
		"knockback":
			if t.has_method("apply_knockback_effect"):
				var dir = (t.global_position - global_position).normalized()
				t.apply_knockback_effect(dir, 280.0)
		"paralyze":
			if t.has_method("apply_effect"):
				t.apply_effect("paralyze", 2.0)
		"slow":
			if t.has_method("apply_effect"):
				t.apply_effect("slow", 3.0)
		"bleeding":
			if t.has_method("apply_effect"):
				t.apply_effect("bleeding", 5.0, 2.0)  # 5s duration, 2 dmg per tick

func take_damage(amount: int, is_crit: bool = false) -> void:
	if _is_dead:
		return
	# Force wake if sleeping (player somehow hit us at range)
	if _is_sleeping:
		_is_sleeping = false
		visible = true
	# Phase 3.4b — armored elite reduces incoming damage.
	if _elite_modifier != &"":
		amount = int(float(amount) * _elite_damage_taken_mult())
	# Phase 3.5 — vulnerability window: +50% damage taken + force-crit
	# visual reaction. Consumes the vulnerability on first hit landed.
	if _is_in_vulnerability_window():
		amount = int(float(amount) * 1.5)
		is_crit = true  # promote to crit-tier feedback regardless of roll
		_clear_vulnerability_window()
	_last_hit_was_crit = is_crit
	var hp_before = stats.current_hp
	stats.take_damage(amount)
	_update_hp_bar()
	hp_bar.visible = true
	name_label.visible = true
	_spawn_damage_number(amount, is_crit)
	_do_hit_flash()
	if is_crit:
		AudioManager.play_sfx("crit_hit")
	else:
		AudioManager.play_sfx("hit_impact", -2.0)

	if stats.current_hp <= 0:
		_overkill_ratio = float(amount - hp_before) / float(max(stats.max_hp, 1))
		_die()
	elif current_state == State.IDLE or current_state == State.PATROL or current_state == State.RETURN:
		var player = _get_player()
		if player:
			target = player
			current_state = State.CHASE

func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	# Phase 3.3 — release any held coordinator token so the budget frees
	# up immediately when this attacker dies mid-windup.
	if _reserved_token_cost > 0:
		_release_attack_token(_reserved_token_cost)
		_reserved_token_cost = 0
		_windup_started = false
		_cancel_attack_windup()
	# Phase 3.4b — exploder elite detonates on death.
	if _elite_modifier == &"exploder":
		_elite_exploder_burst()
	# Stop the elite aura pulse + free the aura sprite.
	if _elite_aura_tween != null and _elite_aura_tween.is_valid():
		_elite_aura_tween.kill()
	if _elite_aura != null and is_instance_valid(_elite_aura):
		var ta := _elite_aura.create_tween()
		ta.tween_property(_elite_aura, "modulate:a", 0.0, 0.25)
		ta.tween_callback(_elite_aura.queue_free)
		_elite_aura = null
	if sprite:
		sprite.material = null
	var death_sfx = "death_" + sprite_type
	if AudioManager.get_sfx(death_sfx):
		AudioManager.play_sfx(death_sfx, -3.0)
	else:
		AudioManager.play_sfx("enemy_death", -3.0)
	died.emit(self, xp_reward, gold_reward)
	_spawn_gold_drop(gold_reward)
	if not drop_table.is_empty():
		var item = ItemData.roll_item_drop(drop_table)
		if not item.is_empty():
			_spawn_item_drop_dict(item)
	# Phase 2.12 — combat pickups on death. Roll types independently;
	# elites/mini-bosses get slightly higher rolls.
	_roll_combat_pickup()
	# Phase 3.10 — LAST-ENEMY CINEMATIC. If this was the last awake
	# enemy near the player, trigger a brief slow-mo so the kill feels
	# like the finale of an encounter.
	_maybe_play_last_enemy_cinematic()
	# Phase 5.x — leave a blood puddle on the ground. Persistent reminder
	# of battles fought. Fades over LIFETIME_SEC.
	_spawn_blood_puddle()
	hp_bar.visible = false
	name_label.visible = false
	if _shadow:
		_shadow.visible = false

	# Multi-kill stagger: if another enemy died within 150ms, delay this death anim
	var now_msec = Time.get_ticks_msec()
	var stagger_delay = 0.0
	if now_msec - _last_global_death_msec < 150:
		stagger_delay = randf_range(0.03, 0.1)
	_last_global_death_msec = now_msec

	if stagger_delay > 0.0:
		get_tree().create_timer(stagger_delay).timeout.connect(_play_death_animation)
	else:
		_play_death_animation()

func _play_death_animation() -> void:
	if is_mini_boss:
		_spawn_blood_splatter()
		_die_boss()
		return
	# Universal MEGA-DEATH chance — extends the rat-explode pattern to
	# any enemy. 4% base rate, +crit/overkill chance, so big hits feel
	# rewarding even against tougher targets.
	var mega_chance: float = 0.04
	if _last_hit_was_crit:
		mega_chance += 0.08
	if _overkill_ratio > 0.5:
		mega_chance += 0.12
	if sprite_type != "rat" and randf() < mega_chance:
		_die_universal_mega_explode()
		return
	# Phase 5.0 — death-by-killing-attack variants. Reads
	# _killing_attack_id set by _on_hit_resolved_for_reaction. Skipped
	# for rats (their own pattern is louder anyway) and for unknown ids
	# (falls through to per-sprite_type match).
	if sprite_type != "rat" and _try_play_killing_attack_death():
		return
	match sprite_type:
		"skeleton":
			_die_crumble()
		"rat":
			_die_rat_select_variant()
		"tree_god_elk":
			_die_elk_collapse()
		"goblin":
			_die_goblin()
		"wolf":
			_die_wolf()
		"bandit":
			_die_bandit()
		"spider":
			_die_spider()
		"troll":
			_die_troll()
		"dark_mage":
			_die_dark_mage()
		"ogre", "ogre_boss":
			_die_ogre()
		"demon_knight":
			_die_demon_knight()
		"ancient_golem":
			_die_ancient_golem()
		"shadow_wraith":
			_die_shadow_wraith()
		"dragon_whelp":
			_die_dragon_whelp()
		"infernal":
			_die_infernal()
		"cave_snake":
			_die_cave_snake()
		"dungeon_bat":
			_die_dungeon_bat()
		"vampire_bat":
			_die_vampire_bat()
		"flan":
			_die_flan()
		"mimic":
			_die_mimic()
		"ghoul":
			_die_ghoul()
		"crypt_knight":
			_die_crypt_knight()
		"lich":
			_die_lich()
		_:
			_die_default_select_variant()

func _die_default_select_variant() -> void:
	_spawn_blood_splatter()
	if _last_hit_was_crit or _overkill_ratio > 0.5:
		_die_default_crit()
	elif randf() < 0.3:
		_die_default_knockback()
	else:
		_die_default()

func _die_default() -> void:
	# Normal: pop, fall & rotate 85°, fade
	var base_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -6), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.05)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "rotation", deg_to_rad(85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 10), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_default_crit() -> void:
	# Critical: bright white flash, bigger rotation (120°), faster fall, scatter fragments
	_spawn_death_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Bright white flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.05)
	# Fast fall with big rotation
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(sprite, "rotation", deg_to_rad(120), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 12), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.25)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_default_knockback() -> void:
	# Knockback: slide backward 15-25px from player before falling
	var player = _get_player()
	var slide_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		slide_dir = (global_position - player.global_position).normalized()
	var slide_dist = randf_range(15, 25)
	var base_pos = sprite.position
	var slide_dest = base_pos + slide_dir * slide_dist
	var tween = create_tween()
	# Slide backward
	tween.tween_property(sprite, "position", slide_dest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Then fall and fade (same as normal but from slid position)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_property(sprite, "rotation", deg_to_rad(85), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", slide_dest + Vector2(0, 10), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _spawn_death_fragments() -> void:
	# Small fragments that scatter on critical kills
	var gib_tex = SpriteGenerator.get_texture("rat_gib")  # Reuse gib texture as generic fragment
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(3, 5)):
		var frag = Sprite2D.new()
		frag.texture = gib_tex
		frag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frag.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		frag.rotation = randf() * TAU
		frag.scale = Vector2(randf_range(0.4, 0.8), randf_range(0.4, 0.8))
		frag.z_index = -1
		frag.modulate = Color(
			randf_range(0.7, 1.0),
			randf_range(0.5, 0.8),
			randf_range(0.5, 0.8),
			randf_range(0.7, 1.0)
		)
		world.add_child(frag)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = frag.global_position + dir * randf_range(12, 30)
		var t = frag.create_tween()
		t.set_parallel(true)
		t.tween_property(frag, "global_position", dest, randf_range(0.2, 0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(frag, "rotation", frag.rotation + randf_range(-4.0, 4.0), 0.35)
		t.set_parallel(false)
		t.tween_interval(randf_range(0.8, 1.5))
		t.tween_property(frag, "modulate:a", 0.0, 0.5)
		t.tween_callback(frag.queue_free)

func _die_crumble() -> void:
	# Skeleton crumble: shake, squash down, scatter bone fragments
	_spawn_bone_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Rapid shake (3 oscillations)
	for i in range(3):
		var offset = Vector2(randf_range(-3, 3), 0)
		tween.tween_property(sprite, "position", base_pos + offset, 0.03)
	# Squash down — skeleton collapses into a pile
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Fade the flattened remains
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _die_rat_select_variant() -> void:
	# 12% MEGA EXPLODE — independent of crit roll, takes priority over
	# everything because rats are tiny meatbags and this is hilarious.
	if randf() < 0.12:
		_die_rat_mega_explode()
		return
	if _last_hit_was_crit or _overkill_ratio > 0.5:
		_die_rat_crit_explode()
	else:
		var roll = randf()
		if roll < 0.5:
			_die_rat_explode()
		elif roll < 0.75:
			_die_rat_fling()
		else:
			_die_rat_squish()


# RATS EXPLODE. CRANKED 10×. Massive cloud of gibs, multiple splatters,
# huge shockwave, big shake, brief time dip — AND a hail of gore that
# flies directly at the player and STICKS to them for several seconds.
# Gated to 12% in _die_rat_select_variant so this is a rare cathartic
# moment, not a constant stutter.
func _die_rat_mega_explode() -> void:
	# 25-40 blood splatters scattered around the corpse (was 4-6).
	for _i in range(randi_range(25, 40)):
		_spawn_blood_splatter()
	# 150-220 gibs in a cloud (was 15-22).
	_spawn_rat_gibs_mega()
	# Player gore-coat: extra gibs that fly TO the player and stick.
	_spray_gore_on_player()

	# Bright white flash then red wash on the sprite itself — bigger pop.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0), 0.04)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 6.0, 0.04)
	tween.tween_property(sprite, "modulate", Color(3.0, 0.4, 0.4), 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 7.0, _base_scale.y * 0.18), 0.03)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.04)
	tween.tween_callback(queue_free)

	# Expanding red shockwave ring — much bigger and longer.
	var world := _get_world_node()
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("rat_gib")
	if ring_tex != null:
		# Spawn a primary fast ring and a slower secondary ring for depth.
		for ring_idx in range(2):
			var ring := Sprite2D.new()
			ring.texture = ring_tex
			ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ring.global_position = global_position
			ring.modulate = Color(1.8, 0.18, 0.18, 0.95 if ring_idx == 0 else 0.65)
			ring.scale = Vector2(0.4, 0.4)
			ring.z_index = -2
			world.add_child(ring)
			var rt := ring.create_tween()
			rt.set_parallel(true)
			var final_scale: float = 24.0 if ring_idx == 0 else 32.0
			var duration: float = 0.7 if ring_idx == 0 else 1.1
			rt.tween_property(ring, "scale", Vector2(final_scale, final_scale), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rt.tween_property(ring, "modulate:a", 0.0, duration + 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			rt.set_parallel(false)
			rt.tween_callback(ring.queue_free)

	# Massive screen shake — only if a player is nearby (don't rattle the
	# camera over a far-off rat death).
	var player := _get_player()
	if player and is_instance_valid(player):
		var dist_sq: float = player.global_position.distance_squared_to(global_position)
		if dist_sq < 900.0 * 900.0:
			if player.has_method("_do_screen_shake"):
				player._do_screen_shake(18.0)

	# Brief global time dip — slower + slightly longer than before for a
	# heavier punctuation. Routes through HitStopController so attack_id
	# dedupe coalesces concurrent explosions into ONE dip.
	if HitStopController != null and HitStopController.has_method("request_global_dip"):
		HitStopController.request_global_dip(0.20, 110, 3, &"rat_mega_explode")

	# Audio: louder + double-tap for "BOOM-splat" feel.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", 5.0)
		# Tiny delayed wet impact for the splatter.
		var splat_call := func() -> void:
			if AudioManager != null and AudioManager.has_method("play_sfx"):
				AudioManager.play_sfx("hit_impact", 3.0)
		get_tree().create_timer(0.06).timeout.connect(splat_call)


func _spawn_rat_gibs_mega() -> void:
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if not gib_tex:
		return
	var world = _get_world_node()
	var count: int = randi_range(150, 220)  # was 15-22
	for _i in range(count):
		var gib = Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gib.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-14, 6))
		gib.rotation = randf() * TAU
		# Varied chunk sizes — some big juicy ones, some tiny bits.
		gib.scale = Vector2(randf_range(0.6, 2.4), randf_range(0.6, 2.4))
		gib.z_index = -1
		gib.modulate = Color(
			randf_range(0.9, 1.5),
			randf_range(0.25, 0.7),
			randf_range(0.25, 0.6),
			randf_range(0.85, 1.0)
		)
		world.add_child(gib)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var force = randf_range(120, 320)  # 10x reach — was 45-95
		# Arc upward then settle.
		var apex = gib.global_position + dir * force * 0.55 + Vector2(0, -randf_range(20, 70))
		var dest = gib.global_position + dir * force + Vector2(0, randf_range(12, 35))
		var t = gib.create_tween()
		t.set_parallel(true)
		t.tween_property(gib, "global_position", apex, randf_range(0.14, 0.26)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(gib, "rotation", gib.rotation + randf_range(-16.0, 16.0), 0.55)
		t.set_parallel(false)
		t.tween_property(gib, "global_position", dest, randf_range(0.20, 0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_interval(randf_range(2.5, 5.0))  # Linger on the ground longer.
		t.tween_property(gib, "modulate:a", 0.0, 1.0)
		t.tween_callback(gib.queue_free)


# Splatter a hail of gibs DIRECTLY onto the player and stick them there.
# The gibs reparent to the player sprite (so they follow movement) and
# fade after a few seconds. Tasteful, not screen-blocking — distributed
# over the sprite bounds.
func _spray_gore_on_player() -> void:
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_squared_to(global_position) > 900.0 * 900.0:
		return  # Too far — don't gore-coat from across the map.
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if gib_tex == null:
		return
	var splat_count: int = randi_range(20, 32)
	for _i in range(splat_count):
		var gib := Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Spawn at the rat (so we see it fly) and tween toward player.
		gib.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		gib.rotation = randf() * TAU
		gib.scale = Vector2(randf_range(0.5, 1.4), randf_range(0.5, 1.4))
		gib.z_index = 5  # In front of the player sprite.
		gib.modulate = Color(
			randf_range(0.9, 1.4),
			randf_range(0.25, 0.55),
			randf_range(0.25, 0.55),
			randf_range(0.85, 1.0)
		)
		# Add to world first so the flight is visible.
		var world := _get_world_node()
		world.add_child(gib)
		# Random landing spot on the player's body — clustered near center.
		var landing_offset := Vector2(randf_range(-14, 14), randf_range(-22, 6))
		var flight := gib.create_tween()
		flight.set_parallel(true)
		flight.tween_property(gib, "global_position", player.global_position + landing_offset, randf_range(0.08, 0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flight.tween_property(gib, "rotation", gib.rotation + randf_range(-8.0, 8.0), 0.2)
		flight.set_parallel(false)
		# On landing, reparent to player so we stick + follow movement.
		var stick_call := func() -> void:
			if not is_instance_valid(gib):
				return
			if not is_instance_valid(player):
				return
			# Reparent to player while preserving global pos via offset.
			var local_offset: Vector2 = gib.global_position - player.global_position
			gib.get_parent().remove_child(gib)
			player.add_child(gib)
			gib.position = local_offset
			# Linger for 3-5 sec then fade.
			var fade := gib.create_tween()
			fade.tween_interval(randf_range(3.0, 5.0))
			fade.tween_property(gib, "modulate:a", 0.0, 1.2)
			fade.tween_callback(gib.queue_free)
		flight.tween_callback(stick_call)

func _die_rat_explode() -> void:
	# Normal pop: quick swell, pop flash, gibs scatter
	_spawn_rat_gibs()
	_spawn_blood_splatter()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", _base_scale * 1.4, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.7, 0.7), 0.04)
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.8), 0.02)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 1.8, _base_scale.y * 0.3), 0.02)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.03)
	tween.tween_callback(queue_free)

func _die_rat_crit_explode() -> void:
	# Critical/overkill: more gibs, wider scatter, bright white flash, bigger pop
	_spawn_rat_gibs_crit()
	for _i in range(randi_range(2, 3)):
		_spawn_blood_splatter()
	var tween = create_tween()
	# Bright white flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 2.2, 0.05)
	# POP — explode outward
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.8), 0.02)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 2.5, _base_scale.y * 0.2), 0.02)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.03)
	tween.tween_callback(queue_free)

func _die_rat_fling() -> void:
	# Fling: rat launches sideways, spins, shrinks, fades
	_spawn_blood_splatter()
	var player = _get_player()
	var fling_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		fling_dir = (global_position - player.global_position).normalized()
	var fling_dist = randf_range(30, 50)
	var dest = sprite.position + fling_dir * fling_dist
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", TAU * 2.0 * sign(fling_dir.x + 0.01), 0.35)
	tween.tween_property(sprite, "scale", _base_scale * 0.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_rat_squish() -> void:
	# Squish: rat flattens with a comic pop, then fades
	_spawn_blood_splatter()
	var tween = create_tween()
	# Squash flat
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.8, _base_scale.y * 0.1), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, 4), 0.08)
	# Brief hold, then fade
	tween.tween_interval(0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _spawn_rat_gibs() -> void:
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(3, 5)):
		var gib = Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gib.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-6, 2))
		gib.rotation = randf() * TAU
		gib.scale = Vector2(randf_range(0.6, 1.2), randf_range(0.6, 1.2))
		gib.z_index = -1
		gib.modulate = Color(
			randf_range(0.8, 1.2),
			randf_range(0.6, 0.9),
			randf_range(0.6, 0.9),
			randf_range(0.7, 1.0)
		)
		world.add_child(gib)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var force = randf_range(18, 40)
		var dest = gib.global_position + dir * force + Vector2(0, randf_range(4, 12))
		var t = gib.create_tween()
		t.set_parallel(true)
		t.tween_property(gib, "global_position", dest, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(gib, "rotation", gib.rotation + randf_range(-6.0, 6.0), 0.3)
		t.set_parallel(false)
		t.tween_interval(randf_range(1.0, 2.5))
		t.tween_property(gib, "modulate:a", 0.0, 0.6)
		t.tween_callback(gib.queue_free)

func _spawn_rat_gibs_crit() -> void:
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if not gib_tex:
		return
	var world = _get_world_node()
	for _i in range(randi_range(5, 8)):
		var gib = Sprite2D.new()
		gib.texture = gib_tex
		gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gib.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-6, 2))
		gib.rotation = randf() * TAU
		gib.scale = Vector2(randf_range(0.6, 1.2), randf_range(0.6, 1.2))
		gib.z_index = -1
		gib.modulate = Color(
			randf_range(0.8, 1.2),
			randf_range(0.6, 0.9),
			randf_range(0.6, 0.9),
			randf_range(0.7, 1.0)
		)
		world.add_child(gib)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var force = randf_range(25, 55)
		var dest = gib.global_position + dir * force + Vector2(0, randf_range(4, 12))
		var t = gib.create_tween()
		t.set_parallel(true)
		t.tween_property(gib, "global_position", dest, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(gib, "rotation", gib.rotation + randf_range(-6.0, 6.0), 0.3)
		t.set_parallel(false)
		t.tween_interval(randf_range(1.0, 2.5))
		t.tween_property(gib, "modulate:a", 0.0, 0.6)
		t.tween_callback(gib.queue_free)

func _die_elk_collapse() -> void:
	# Nature collapse: stagger wobble, root tendrils grow outward, collapse sideways, green fade
	var base_pos = sprite.position
	var tween = create_tween()
	# Phase 1: Stagger wobble — 3 side-to-side sways, green glow fades
	tween.tween_property(sprite, "position", base_pos + Vector2(-4, 0), 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 1.2, 0.5), 0.12)
	tween.tween_property(sprite, "position", base_pos + Vector2(5, 0), 0.12)
	tween.tween_property(sprite, "position", base_pos + Vector2(-3, 0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.0, 0.4), 0.1)
	# Phase 2: Spawn root/vine tendrils growing outward
	tween.tween_callback(_spawn_elk_root_tendrils)
	# Phase 3: Collapse sideways with rotation
	tween.tween_property(sprite, "rotation", 1.2, 0.3)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(8, 6), 0.3)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.8), 0.3)
	# Phase 4: Fade to green-tinted transparent
	tween.tween_property(sprite, "modulate", Color(0.3, 0.7, 0.2, 0.0), 0.5)
	tween.tween_callback(queue_free)

func _spawn_elk_root_tendrils() -> void:
	var world = _get_world_node()
	for _i in range(randi_range(3, 4)):
		var tendril = Sprite2D.new()
		# Use vines texture as root tendril
		var tex = SpriteGenerator.get_texture("vines")
		if tex:
			tendril.texture = tex
		tendril.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tendril.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		tendril.rotation = randf() * TAU
		tendril.scale = Vector2(0.1, 0.1)
		tendril.modulate = Color(0.4, 0.7, 0.2, 0.9)
		tendril.z_index = -1
		world.add_child(tendril)
		# Grow outward
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = tendril.global_position + dir * randf_range(15, 35)
		var t = tendril.create_tween()
		t.set_parallel(true)
		t.tween_property(tendril, "global_position", dest, randf_range(0.3, 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(tendril, "scale", Vector2(randf_range(0.6, 1.0), randf_range(0.6, 1.0)), 0.4)
		t.set_parallel(false)
		# Linger then fade
		t.tween_interval(randf_range(1.5, 3.0))
		t.tween_property(tendril, "modulate:a", 0.0, 0.8)
		t.tween_callback(tendril.queue_free)

func _die_boss() -> void:
	# Dramatic mini-boss death: expand, flash bright, shake violently, explode outward
	var base_pos = sprite.position
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Flash bright and swell
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 1.4), 0.08)
	# Violent shake (6 jitters)
	for i in range(6):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.03)
	# Pulsing flash — alternate bright/dim
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.3), 0.06)
	tween.tween_property(sprite, "modulate", Color(2.5, 2.0, 1.5), 0.06)
	# Explode outward — scale up fast then shrink to nothing
	tween.tween_property(sprite, "scale", Vector2(sx * 2.0, sy * 2.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(sprite, "position", base_pos, 0.08)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.1, sy * 0.1), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func start_boss_pulse() -> void:
	# Looping idle breathing animation for mini-bosses — subtle scale + modulate pulse
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(sx * 1.06, sy * 0.96), 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "modulate", Color(_base_modulate.r * 1.1, _base_modulate.g * 0.9, _base_modulate.b * 0.9), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.96, sy * 1.06), 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.8).set_trans(Tween.TRANS_SINE)

func _spawn_bone_fragments() -> void:
	var bone_tex = SpriteGenerator.get_texture("bone_fragment")
	if not bone_tex:
		return
	var world = _get_world_node()
	for i in range(randi_range(3, 5)):
		var bone = Sprite2D.new()
		bone.texture = bone_tex
		bone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bone.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-8, 4))
		bone.rotation = randf() * TAU
		bone.z_index = -1
		world.add_child(bone)
		# Scatter outward then fade
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = bone.global_position + dir * randf_range(10, 25) + Vector2(0, randf_range(2, 8))
		var t = bone.create_tween()
		t.set_parallel(true)
		t.tween_property(bone, "global_position", dest, randf_range(0.25, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(bone, "rotation", bone.rotation + randf_range(-4.0, 4.0), 0.4)
		t.set_parallel(false)
		t.tween_interval(randf_range(0.8, 1.5))
		t.tween_property(bone, "modulate:a", 0.0, 0.5)
		t.tween_callback(bone.queue_free)

# ============================================================
# UNIQUE DEATH ANIMATIONS PER ENEMY TYPE
# ============================================================

func _die_goblin() -> void:
	# Sneaky escape fail: goblin tries to flee, stumbles, faceplants
	_spawn_blood_splatter()
	var player = _get_player()
	var flee_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		flee_dir = (global_position - player.global_position).normalized()
	var base_pos = sprite.position
	var tween = create_tween()
	# Panic hop backward
	tween.tween_property(sprite, "position", base_pos + flee_dir * 8 + Vector2(0, -6), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 0.8, _base_scale.y * 1.3), 0.08)
	# Stumble — tilt forward
	tween.tween_property(sprite, "rotation", deg_to_rad(-20), 0.06)
	tween.parallel().tween_property(sprite, "position", base_pos + flee_dir * 12, 0.06)
	# Faceplant — slam flat
	tween.tween_property(sprite, "rotation", deg_to_rad(90), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + flee_dir * 14 + Vector2(0, 6), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 1.2, _base_scale.y * 0.5), 0.1)
	# Brief hold then fade
	tween.tween_interval(0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _die_wolf() -> void:
	# Wounded yelp: wolf recoils, rolls sideways, legs-up fade
	_spawn_blood_splatter()
	var player = _get_player()
	var away_dir = Vector2.RIGHT
	if player and is_instance_valid(player):
		away_dir = (global_position - player.global_position).normalized()
	var base_pos = sprite.position
	var tween = create_tween()
	# Recoil hop
	tween.tween_property(sprite, "position", base_pos + away_dir * 6 + Vector2(0, -4), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.3, 0.9, 0.9), 0.06)
	# Roll sideways
	var roll_sign = 1.0 if away_dir.x >= 0 else -1.0
	tween.tween_property(sprite, "rotation", deg_to_rad(180 * roll_sign), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position", base_pos + away_dir * 18 + Vector2(0, 4), 0.2)
	# Legs-up settle
	tween.tween_property(sprite, "rotation", deg_to_rad(160 * roll_sign), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 0.9, _base_scale.y * 0.7), 0.08)
	# Fade
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _die_bandit() -> void:
	# Dramatic stagger: clutch wound, stagger 2 steps, collapse
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Clutch wound — brief freeze, red flash
	tween.tween_property(sprite, "modulate", Color(1.5, 0.6, 0.6), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 1.1, _base_scale.y * 0.9), 0.06)
	# Stagger step 1
	tween.tween_property(sprite, "position", base_pos + Vector2(-4, 0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(-8), 0.1)
	# Stagger step 2
	tween.tween_property(sprite, "position", base_pos + Vector2(3, 0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(12), 0.1)
	# Knees buckle — squash down
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.3, _base_scale.y * 0.4), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(2, 8), 0.12)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(25), 0.12)
	# Collapse forward and fade
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _die_spider() -> void:
	# Curl and shrivel: legs curl inward, flip upside down, shrink
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Recoil flash — green venom burst
	tween.tween_property(sprite, "modulate", Color(0.8, 1.4, 0.6), 0.05)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.2, 0.05)
	# Flip upside-down — legs curl
	tween.tween_property(sprite, "rotation", deg_to_rad(180), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -4), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.5, 0.4), 0.2)
	# Shrivel — curl into ball
	tween.tween_property(sprite, "scale", _base_scale * 0.3, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.2)
	# Fade the curled husk
	tween.tween_interval(0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _die_troll() -> void:
	# Mighty timber: troll wobbles, tips over like a falling tree, ground impact
	_spawn_blood_splatter()
	_spawn_death_fragments()
	var base_pos = sprite.position
	var fall_dir = 1.0 if randf() > 0.5 else -1.0
	var tween = create_tween()
	# Stunned wobble
	tween.tween_property(sprite, "position", base_pos + Vector2(-3 * fall_dir, 0), 0.08)
	tween.tween_property(sprite, "position", base_pos + Vector2(4 * fall_dir, 0), 0.08)
	tween.tween_property(sprite, "position", base_pos + Vector2(-2 * fall_dir, 0), 0.06)
	# Timber! — slow tip then accelerating fall
	tween.tween_property(sprite, "rotation", deg_to_rad(15 * fall_dir), 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "rotation", deg_to_rad(85 * fall_dir), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(12 * fall_dir, 6), 0.2)
	# Ground impact — squash and camera shake feel
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.3, _base_scale.y * 0.6), 0.05)
	tween.tween_property(sprite, "scale", _base_scale * 0.9, 0.08)
	# Fade the fallen troll
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _die_dark_mage() -> void:
	# Arcane unraveling: dark energy pulses out, mage dissolves into void wisps
	var base_pos = sprite.position
	var tween = create_tween()
	# Dark energy surge — purple flash
	tween.tween_property(sprite, "modulate", Color(1.2, 0.4, 1.5), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.3, 0.08)
	# Flicker between visible and translucent
	for i in range(4):
		tween.tween_property(sprite, "modulate:a", 0.2, 0.04)
		tween.tween_property(sprite, "modulate:a", 0.9, 0.04)
	# Spawn void wisps
	tween.tween_callback(_spawn_void_wisps)
	# Implode — shrink to point with purple glow
	tween.tween_property(sprite, "scale", _base_scale * 0.05, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.2, 1.2, 0.0), 0.25)
	tween.parallel().tween_property(sprite, "rotation", TAU * 1.5, 0.25)
	tween.tween_callback(queue_free)

func _spawn_void_wisps() -> void:
	var world = _get_world_node()
	for _i in range(randi_range(4, 6)):
		var wisp = Sprite2D.new()
		var tex = SpriteGenerator.get_texture("rat_gib")
		if tex:
			wisp.texture = tex
		wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wisp.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		wisp.scale = Vector2(randf_range(0.3, 0.6), randf_range(0.3, 0.6))
		wisp.modulate = Color(0.6, 0.2, 0.9, 0.8)
		wisp.z_index = -1
		world.add_child(wisp)
		var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dest = wisp.global_position + dir * randf_range(20, 40) + Vector2(0, randf_range(-15, -5))
		var t = wisp.create_tween()
		t.set_parallel(true)
		t.tween_property(wisp, "global_position", dest, randf_range(0.4, 0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(wisp, "scale", Vector2(0.05, 0.05), 0.6)
		t.tween_property(wisp, "rotation", randf_range(-TAU, TAU), 0.6)
		t.set_parallel(false)
		t.tween_property(wisp, "modulate:a", 0.0, 0.3)
		t.tween_callback(wisp.queue_free)

func _die_ogre() -> void:
	# Heavy topple: ogre sways, slams face-first with ground shake
	_spawn_blood_splatter()
	_spawn_death_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Dazed sway
	tween.tween_property(sprite, "rotation", deg_to_rad(-10), 0.1)
	tween.tween_property(sprite, "rotation", deg_to_rad(8), 0.1)
	# Heavy forward slam
	tween.tween_property(sprite, "rotation", deg_to_rad(95), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(6, 10), 0.25)
	# Impact squash — heavy thud
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.4, _base_scale.y * 0.5), 0.05)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.1, _base_scale.y * 0.7), 0.08)
	# Slow fade — heavy body lingers
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _die_demon_knight() -> void:
	# Hellfire collapse: armor cracks with fire flashes, collapses in embers
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Armor crack flashes — alternating red/orange
	tween.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.2), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.1), 0.05)
	tween.tween_property(sprite, "modulate", Color(2.0, 0.8, 0.3), 0.05)
	# Violent shudder
	for i in range(4):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.03)
	# Spawn ember fragments
	tween.tween_callback(_spawn_ember_fragments)
	# Collapse — armor falls apart
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.2, _base_scale.y * 0.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 8), 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.4, 0.1, 0.6), 0.15)
	# Smolder out
	tween.tween_property(sprite, "modulate", Color(0.3, 0.1, 0.05, 0.0), 0.4)
	tween.tween_callback(queue_free)

func _spawn_ember_fragments() -> void:
	var world = _get_world_node()
	var tex = SpriteGenerator.get_texture("rat_gib")
	if not tex:
		return
	for _i in range(randi_range(4, 7)):
		var ember = Sprite2D.new()
		ember.texture = tex
		ember.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ember.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(-6, 2))
		ember.scale = Vector2(randf_range(0.2, 0.5), randf_range(0.2, 0.5))
		ember.modulate = Color(
			randf_range(1.2, 2.0),
			randf_range(0.4, 0.8),
			randf_range(0.1, 0.3),
			0.9
		)
		ember.z_index = -1
		world.add_child(ember)
		# Float upward like embers
		var dest = ember.global_position + Vector2(randf_range(-12, 12), randf_range(-25, -10))
		var t = ember.create_tween()
		t.set_parallel(true)
		t.tween_property(ember, "global_position", dest, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ember, "scale", Vector2(0.05, 0.05), 0.8)
		t.tween_property(ember, "rotation", randf_range(-TAU, TAU), 0.8)
		t.set_parallel(false)
		t.tween_property(ember, "modulate:a", 0.0, 0.3)
		t.tween_callback(ember.queue_free)

func _die_ancient_golem() -> void:
	# Crumbling monument: cracks spread, pieces break off, collapses into rubble
	_spawn_death_fragments()
	_spawn_death_fragments()  # Double fragments for large body
	var base_pos = sprite.position
	var tween = create_tween()
	# Stone crack flash — gray-white
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.4), 0.06)
	# Shudder as cracks form
	for i in range(5):
		var offset = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", base_pos + offset, 0.04)
	# Pieces break off — scale down in steps
	tween.tween_property(sprite, "scale", _base_scale * 0.85, 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.75, 0.65), 0.1)
	tween.tween_property(sprite, "scale", _base_scale * 0.65, 0.1)
	# Final collapse — squash into rubble pile
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.6, _base_scale.y * 0.2), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 10), 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.55, 0.45), 0.15)
	# Dust settle fade
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _die_shadow_wraith() -> void:
	# Spectral dissipation: wraith flickers, splits into ghost wisps, evaporates
	var base_pos = sprite.position
	var tween = create_tween()
	# Ethereal flicker — phase in/out rapidly
	for i in range(6):
		tween.tween_property(sprite, "modulate:a", randf_range(0.1, 0.3), 0.03)
		tween.parallel().tween_property(sprite, "position", base_pos + Vector2(randf_range(-5, 5), randf_range(-3, 3)), 0.03)
		tween.tween_property(sprite, "modulate:a", randf_range(0.6, 0.9), 0.03)
	# Stretch upward — soul escaping
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.5, _base_scale.y * 1.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -12), 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color(0.5, 0.6, 1.2, 0.5), 0.2)
	# Spawn ghost wisps
	tween.tween_callback(_spawn_ghost_wisps)
	# Final evaporate
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.1, _base_scale.y * 2.5), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _spawn_ghost_wisps() -> void:
	var world = _get_world_node()
	var tex = SpriteGenerator.get_texture("rat_gib")
	if not tex:
		return
	for _i in range(randi_range(3, 5)):
		var wisp = Sprite2D.new()
		wisp.texture = tex
		wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wisp.global_position = global_position + Vector2(randf_range(-3, 3), randf_range(-8, 0))
		wisp.scale = Vector2(randf_range(0.3, 0.6), randf_range(0.3, 0.6))
		wisp.modulate = Color(0.5, 0.6, 1.0, 0.6)
		wisp.z_index = -1
		world.add_child(wisp)
		# Float upward and scatter
		var dest = wisp.global_position + Vector2(randf_range(-15, 15), randf_range(-30, -15))
		var t = wisp.create_tween()
		t.set_parallel(true)
		t.tween_property(wisp, "global_position", dest, randf_range(0.5, 0.8)).set_trans(Tween.TRANS_SINE)
		t.tween_property(wisp, "scale", Vector2(0.05, 0.05), 0.7)
		t.set_parallel(false)
		t.tween_property(wisp, "modulate:a", 0.0, 0.3)
		t.tween_callback(wisp.queue_free)

func _die_dragon_whelp() -> void:
	# Fiery demise: flame burst, spiral fall with trailing embers
	_spawn_ember_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Flame burst — bright orange flash
	tween.tween_property(sprite, "modulate", Color(2.0, 1.2, 0.3), 0.06)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.3, 0.06)
	# Spiral fall — wings folding
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", TAU * 1.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-10, 10), 15), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", _base_scale * 0.3, 0.4)
	tween.tween_property(sprite, "modulate", Color(1.5, 0.6, 0.1, 0.0), 0.45)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _die_infernal() -> void:
	# Banishment: dark implosion, inverse explosion, demonic runes scatter
	var base_pos = sprite.position
	var tween = create_tween()
	# Demonic glow intensifies
	tween.tween_property(sprite, "modulate", Color(1.8, 0.3, 0.1), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.2, 0.08)
	# Reality tear — rapid size oscillation
	tween.tween_property(sprite, "scale", _base_scale * 0.6, 0.06)
	tween.tween_property(sprite, "scale", _base_scale * 1.5, 0.06)
	tween.tween_property(sprite, "scale", _base_scale * 0.4, 0.06)
	# Spawn dark rune fragments
	tween.tween_callback(_spawn_void_wisps)
	# Implosion — crush to center point
	tween.tween_property(sprite, "scale", Vector2(0.02, 0.02), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(2.0, 0.1, 0.0, 0.0), 0.2)
	tween.parallel().tween_property(sprite, "rotation", -TAU, 0.2)
	tween.tween_callback(queue_free)

func _die_cave_snake() -> void:
	# Coil and collapse: snake coils up, spasms, goes limp
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Recoil — stretch horizontally (body extending)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.5, _base_scale.y * 0.7), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.2, 1.0, 0.8), 0.08)
	# Coil up — compress into tight ball
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.6, _base_scale.y * 1.1), 0.1)
	# Spasm — quick jitters
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
		tween.parallel().tween_property(sprite, "rotation", deg_to_rad(randf_range(-15, 15)), 0.03)
	# Go limp — uncoil and flatten
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.3, _base_scale.y * 0.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(randf_range(30, 60)), 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.15)
	# Fade
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _die_dungeon_bat() -> void:
	# Wing fold plummet: wings fold, plummets straight down, poof
	var base_pos = sprite.position
	var tween = create_tween()
	# Wings fold — squeeze narrow
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.4, _base_scale.y * 1.3), 0.08)
	# Plummet straight down
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 20), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(randf_range(-30, 30)), 0.15)
	# Impact poof — sudden expand then vanish
	tween.tween_property(sprite, "scale", _base_scale * 1.5, 0.04)
	tween.parallel().tween_property(sprite, "modulate:a", 0.3, 0.04)
	tween.tween_property(sprite, "scale", _base_scale * 0.1, 0.08)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _die_vampire_bat() -> void:
	# Blood drain reversal: turns red, swells, blood bursts out, shrivels
	_spawn_blood_splatter()
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Blood overload — swell with deep red
	tween.tween_property(sprite, "modulate", Color(1.5, 0.2, 0.2), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.5, 0.1)
	# Brief hold — about to burst
	tween.tween_interval(0.08)
	# Burst — rapid shrink with blood spray
	tween.tween_property(sprite, "scale", _base_scale * 0.3, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.1, 0.1), 0.06)
	# Shrivel and fade
	tween.tween_property(sprite, "scale", _base_scale * 0.15, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 6), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _die_flan() -> void:
	# Jelly splat: wobbles wildly, flattens into puddle, dissolves
	var base_pos = sprite.position
	var tween = create_tween()
	# Frantic wobble — elastic bouncing
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.5, _base_scale.y * 0.6), 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.6, _base_scale.y * 1.5), 0.06).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.3, _base_scale.y * 0.7), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.8, _base_scale.y * 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	# SPLAT — flatten completely into puddle
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 2.2, _base_scale.y * 0.1), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 8), 0.08)
	# Puddle color shift and dissolve
	tween.tween_property(sprite, "modulate", Color(0.7, 0.9, 0.5, 0.6), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _die_mimic() -> void:
	# Chest slam shut: snaps open wide, tongue lashes, slams shut, crumbles
	_spawn_death_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Snap open wide — mouth agape
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.1, _base_scale.y * 1.5), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.8, 0.8), 0.06)
	# Tongue lash — quick horizontal stretch
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.6, _base_scale.y * 0.8), 0.05)
	# SLAM shut — violent compress
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 0.8, _base_scale.y * 0.5), 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.04)
	# Crack and crumble — jittery break apart
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-3, 3), 4 + randf_range(-2, 2)), 0.04)
	tween.tween_property(sprite, "modulate", Color(0.6, 0.5, 0.4), 0.1)
	# Collapse into fragments
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.4, _base_scale.y * 0.15), 0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _die_ghoul() -> void:
	# Rotting collapse: flesh sloughs off, staggers, melts into ground
	_spawn_blood_splatter()
	var base_pos = sprite.position
	var tween = create_tween()
	# Sickly green flash — toxin release
	tween.tween_property(sprite, "modulate", Color(0.6, 1.2, 0.4), 0.06)
	# Stagger with pieces falling off (scale shrinking in steps)
	tween.tween_property(sprite, "position", base_pos + Vector2(-3, 2), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 0.9, 0.08)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(-5), 0.08)
	tween.tween_property(sprite, "position", base_pos + Vector2(2, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 0.75, 0.08)
	tween.parallel().tween_property(sprite, "rotation", deg_to_rad(8), 0.08)
	# Melt into ground — wide puddle
	tween.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.6, _base_scale.y * 0.15), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, 10), 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color(0.3, 0.5, 0.2, 0.6), 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	# Dissolve
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _die_crypt_knight() -> void:
	# Armor shatter: freezes, cracks appear (flash), pieces fly off, empty armor falls
	_spawn_bone_fragments()
	_spawn_death_fragments()
	var base_pos = sprite.position
	var tween = create_tween()
	# Freeze frame — bright metallic flash
	tween.tween_property(sprite, "modulate", Color(1.8, 1.8, 2.0), 0.06)
	tween.tween_interval(0.08)
	# Crack flickers
	tween.tween_property(sprite, "modulate", Color(1.0, 0.9, 1.2), 0.04)
	tween.tween_property(sprite, "modulate", Color(1.6, 1.6, 1.8), 0.04)
	tween.tween_property(sprite, "modulate", Color(0.8, 0.8, 1.0), 0.04)
	# Armor shatters — brief expand then hollow collapse
	tween.tween_property(sprite, "scale", _base_scale * 1.2, 0.05)
	tween.tween_property(sprite, "scale", _base_scale * 0.7, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(0.5, 0.5, 0.6), 0.08)
	# Empty armor falls sideways
	tween.tween_property(sprite, "rotation", deg_to_rad(75), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(6, 8), 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 1.1, _base_scale.y * 0.6), 0.2)
	# Clatter fade
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _die_lich() -> void:
	# Phylactery shatter: soul scream (expand), arcane explosion, fragments ascend
	var base_pos = sprite.position
	var tween = create_tween()
	# Soul scream — expand with blue-white glow
	tween.tween_property(sprite, "modulate", Color(0.6, 0.8, 2.0), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.4, 0.1)
	# Violent convulsion
	for i in range(5):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.03)
	# Arcane explosion flash
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 3.0), 0.04)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 1.8, 0.04)
	# Spawn ascending soul fragments
	tween.tween_callback(_spawn_soul_fragments)
	# Implode and disintegrate
	tween.tween_property(sprite, "scale", _base_scale * 0.05, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "rotation", TAU * 2.0, 0.25)
	tween.parallel().tween_property(sprite, "modulate", Color(0.4, 0.5, 1.5, 0.0), 0.25)
	tween.tween_callback(queue_free)

func _spawn_soul_fragments() -> void:
	var world = _get_world_node()
	var tex = SpriteGenerator.get_texture("bone_fragment")
	if not tex:
		tex = SpriteGenerator.get_texture("rat_gib")
	if not tex:
		return
	for _i in range(randi_range(5, 8)):
		var frag = Sprite2D.new()
		frag.texture = tex
		frag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frag.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		frag.scale = Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
		frag.modulate = Color(
			randf_range(0.4, 0.7),
			randf_range(0.5, 0.8),
			randf_range(1.2, 2.0),
			0.8
		)
		frag.z_index = -1
		world.add_child(frag)
		# Ascend upward in spiraling pattern
		var x_drift = randf_range(-20, 20)
		var dest = frag.global_position + Vector2(x_drift, randf_range(-40, -20))
		var t = frag.create_tween()
		t.set_parallel(true)
		t.tween_property(frag, "global_position", dest, randf_range(0.6, 1.0)).set_trans(Tween.TRANS_SINE)
		t.tween_property(frag, "rotation", randf_range(-TAU * 2, TAU * 2), 0.9)
		t.tween_property(frag, "scale", Vector2(0.05, 0.05), 0.9)
		t.set_parallel(false)
		t.tween_property(frag, "modulate:a", 0.0, 0.3)
		t.tween_callback(frag.queue_free)

func apply_knockback(dir: Vector2, force: float) -> void:
	if _is_dead:
		return
	_knockback_velocity = dir * force

func _do_hit_flash() -> void:
	# Bright white flash + squash on hit. Crits flash MUCH brighter + bigger squash.
	var flash_col: Color = Color(2.4, 2.4, 2.4) if _last_hit_was_crit else Color(1.7, 1.7, 1.7)
	var squash_x: float = 1.45 if _last_hit_was_crit else 1.3
	var squash_y: float = 0.6 if _last_hit_was_crit else 0.7
	var decay: float = 0.22 if _last_hit_was_crit else 0.18
	sprite.modulate = flash_col
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", _base_modulate, decay)
	var sx = _base_scale.x
	var sy = _base_scale.y
	tween.tween_property(sprite, "scale", Vector2(sx * squash_x, sy * squash_y), 0.05)
	tween.set_parallel(false)
	tween.tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.2), 0.06)
	tween.tween_property(sprite, "scale", _base_scale, 0.08)

func _get_special_attack_mult() -> float:
	# Damage multiplier for special attacks — varies by enemy type
	match sprite_type:
		"rat": return 1.15        # Frenzy bite
		"goblin": return 1.2      # Backstab
		"wolf": return 1.25       # Savage lunge
		"skeleton": return 1.2    # Overhead cleave
		"spider": return 1.3      # Venom strike
		"bandit": return 1.25     # Cross slash
		"troll": return 1.4       # Mega punch
		"dark_mage": return 1.3   # Dark blast
		"ogre": return 1.35       # Ground pound
		"tree_god_elk": return 1.3 # Antler toss
		"cave_snake": return 1.25 # Constrict
		"dungeon_bat": return 1.2 # Dive bomb
		"vampire_bat": return 1.3 # Drain bite
		"flan": return 1.25       # Body slam
		"mimic": return 1.4       # Devour
		"ghoul": return 1.3       # Rend
		"crypt_knight": return 1.35 # Shield bash
		_: return 1.2

func _do_attack_lunge(is_special: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var dir = (target.global_position - global_position).normalized()
	var base_pos = sprite.position
	if is_mini_boss:
		match sprite_type:
			"ogre_boss":
				_anim_boss_ground_slam(dir, base_pos)
			"demon_knight":
				_anim_boss_charge_slash(dir, base_pos)
			"dragon_whelp":
				_anim_boss_fire_breath(dir, base_pos)
			"infernal":
				_anim_boss_doom_strike(dir, base_pos)
			"wolf":
				_anim_boss_savage_pounce(dir, base_pos)
			"spider":
				_anim_boss_venom_barrage(dir, base_pos)
			"skeleton":
				_anim_boss_death_cleave(dir, base_pos)
			_:
				_anim_boss_ground_slam(dir, base_pos)
		return
	match sprite_type:
		"rat":
			if is_special: _anim_rat_frenzy(dir, base_pos)
			else: _anim_rat_bite(dir, base_pos)
		"goblin":
			if is_special: _anim_goblin_backstab(dir, base_pos)
			else: _anim_goblin_swing(dir, base_pos)
		"wolf":
			if is_special: _anim_wolf_savage_lunge(dir, base_pos)
			else: _anim_wolf_bite(dir, base_pos)
		"skeleton":
			if is_special: _anim_skeleton_cleave(dir, base_pos)
			else: _anim_skeleton_slash(dir, base_pos)
		"spider":
			if is_special: _anim_spider_venom(dir, base_pos)
			else: _anim_spider_fang(dir, base_pos)
		"bandit":
			if is_special: _anim_bandit_cross_slash(dir, base_pos)
			else: _anim_bandit_slash(dir, base_pos)
		"troll":
			if is_special: _anim_troll_mega_punch(dir, base_pos)
			else: _anim_troll_slam(dir, base_pos)
		"dark_mage":
			if is_special: _anim_mage_dark_blast(dir, base_pos)
			else: _anim_mage_bolt(dir, base_pos)
		"ogre":
			if is_special: _anim_ogre_ground_pound(dir, base_pos)
			else: _anim_ogre_fist(dir, base_pos)
		"tree_god_elk":
			if is_special: _anim_elk_toss(dir, base_pos)
			else: _anim_elk_charge(dir, base_pos)
		"cave_snake":
			if is_special: _anim_snake_constrict(dir, base_pos)
			else: _anim_snake_strike(dir, base_pos)
		"dungeon_bat":
			if is_special: _anim_bat_divebomb(dir, base_pos)
			else: _anim_bat_swoop(dir, base_pos)
		"vampire_bat":
			if is_special: _anim_vbat_drain(dir, base_pos)
			else: _anim_bat_swoop(dir, base_pos)
		"flan":
			if is_special: _anim_flan_bodyslam(dir, base_pos)
			else: _anim_flan_bounce(dir, base_pos)
		"mimic":
			if is_special: _anim_mimic_devour(dir, base_pos)
			else: _anim_mimic_chomp(dir, base_pos)
		"ghoul":
			if is_special: _anim_ghoul_rend(dir, base_pos)
			else: _anim_ghoul_claw(dir, base_pos)
		"crypt_knight":
			if is_special: _anim_cknight_bash(dir, base_pos)
			else: _anim_cknight_swing(dir, base_pos)
		_:
			_anim_generic_lunge(dir, base_pos)

# ============================================================
# NORMAL ATTACK ANIMATIONS
# ============================================================

func _anim_rat_bite(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.7), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.04)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.8, 0.8))
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.03)
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_goblin_swing(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -3), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.9))
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 2), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.25, 0.8), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.07)

func _anim_wolf_bite(dir: Vector2, base_pos: Vector2) -> void:
	# Wolf lunges with jaws open, snaps shut — fast predator bite
	var tween = create_tween()
	# Crouch low — coiling muscles
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.06)
	# Pounce forward — jaws open (stretch long and thin)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, -2), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.75, 1.25), 0.05)
	# Jaws snap shut — quick squash on contact
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.9, 0.8))
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.03)
	# Head shake — wolf shakes prey side to side
	var perp = Vector2(-dir.y, dir.x)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + perp * 3.0, 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 - perp * 3.0, 0.04)
	# Release and hop back
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_skeleton_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Rattling sword swing — jerky, mechanical, bones clatter
	var tween = create_tween()
	# Raise sword — stiff pull-up
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -4), 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.07)
	# Slash across — diagonal sweep with rotation
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.2, 1.0))
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.2, 0.05)
	# Clatter on follow-through — tiny jitter
	tween.tween_property(sprite, "position", base_pos + dir * 9.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.03)
	# Return stiffly
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_spider_fang(dir: Vector2, base_pos: Vector2) -> void:
	# Quick scuttle forward, fangs stab down, skitter back
	var tween = create_tween()
	# Scuttle forward — low and wide
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.04)
	# Fangs strike down — vertical stab motion
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 3), 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.03)
	tween.tween_callback(func(): sprite.modulate = Color(0.9, 1.2, 0.8))
	# Pull fangs out with tiny hop
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -2), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.04)
	# Skitter backwards
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.04)

func _anim_bandit_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Quick sword slash — step in, cut diagonally, step back
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# Step forward into stance
	tween.tween_property(sprite, "position", base_pos + dir * 4.0 + perp * 2.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.05)
	# Slash diagonally across — rotation for sword arc
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.0, 0.9))
	tween.tween_property(sprite, "position", base_pos + dir * 11.0 - perp * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.04)
	tween.parallel().tween_property(sprite, "rotation", -dir.angle() * 0.2, 0.04)
	# Quick recovery — bandits are nimble
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.06)

func _anim_troll_slam(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, -6), 0.25)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.8, 1.3), 0.25)
	tween.tween_interval(0.12)
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 1.0, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(0, 4), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.35, 0.7), 0.1)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.2, 0.1)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 4), 0.06)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-2, 2), 4), 0.06)
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 6.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.95), 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)

func _anim_mage_bolt(dir: Vector2, base_pos: Vector2) -> void:
	# Staff thrust — lean back gathering energy, thrust forward with purple flash
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Gather energy — lean back, purple glow
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.9, 0.6, 1.3) * base_mod, 0.1)
	# Thrust staff forward — bolt release
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color(1.2, 0.8, 1.4) * base_mod, 0.05)
	# Recoil — magic pushback
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.97), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.08)

func _anim_ogre_fist(dir: Vector2, base_pos: Vector2) -> void:
	# Massive fist slam — wind up overhead, smash down
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Rear up — raise fist high
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -8), 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.85, 1.25), 0.15)
	# Smash down — heavy squash
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.3, 0.75), 0.08)
	# Impact shake
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(randf_range(-2, 2), 4), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 3), 0.04)
	# Lumber back
	tween.tween_property(sprite, "modulate", base_mod, 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.97), 0.15)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.15)
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)

func _anim_elk_charge(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.85, 1.3), 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 1.2, 0.7) * base_mod, 0.2)
	tween.tween_interval(0.1)
	tween.tween_callback(func(): sprite.modulate = Color(1.1, 1.3, 0.8) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, 3), 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.3, 0.75), 0.1)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.1)
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, -5), 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.9, 1.15), 0.08)
	tween.parallel().tween_property(sprite, "rotation", -0.15, 0.08)
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 5.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.95), 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.15)

func _anim_snake_strike(dir: Vector2, base_pos: Vector2) -> void:
	# Coil and lightning-fast strike — serpentine motion
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	# S-curve coil back
	tween.tween_property(sprite, "position", base_pos - dir * 5.0 + perp * 2.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	# Lightning strike forward
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.03)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 0.8))
	# Quick retract
	tween.tween_property(sprite, "position", base_pos + dir * 4.0 - perp * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_bat_swoop(dir: Vector2, base_pos: Vector2) -> void:
	# Dive-swoop — arc down from above, claw at target, fly back up
	var tween = create_tween()
	# Rise up — wings spread
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.05)
	# Dive down toward target
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 4), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.04)
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 0.9, 0.9))
	# Pull up from dive
	tween.tween_property(sprite, "position", base_pos + dir * 6.0 + Vector2(0, -4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.05)
	# Settle back
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)

func _anim_flan_bounce(dir: Vector2, base_pos: Vector2) -> void:
	# Gelatinous bounce — compress, spring up, slam down on target
	var tween = create_tween()
	# Compress flat — storing energy
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.1)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 3), 0.05)
	# Spring up and forward
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -6), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06)
	# Splat down on target
	tween.tween_callback(func(): sprite.modulate = Color(1.1, 1.2, 0.8))
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 2), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.04)
	# Jelly wobble recovery
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _anim_mimic_chomp(dir: Vector2, base_pos: Vector2) -> void:
	# Chest lid opens wide, snaps shut — terrifying surprise attack
	var tween = create_tween()
	# Lid opens — stretch tall (mouth opening)
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.08)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -3), 0.08)
	# Lunge forward with jaws wide
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.1), 0.05)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.8, 0.8))
	# CHOMP shut — fast squash
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.03)
	# Jaw clatter
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.04)
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.04)
	# Settle back
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_ghoul_claw(dir: Vector2, base_pos: Vector2) -> void:
	# Shambling claw swipe — lurching forward, raking claws
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Lurch forward
	tween.tween_property(sprite, "position", base_pos + dir * 5.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.08)
	# Claw swipe across — diagonal motion
	tween.tween_callback(func(): sprite.modulate = Color(0.8, 1.1, 0.7) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.15, 0.04)
	# Second rake in opposite direction
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 4.0, 0.05)
	tween.parallel().tween_property(sprite, "rotation", -0.15, 0.05)
	# Stumble back
	tween.tween_property(sprite, "position", base_pos + dir * 3.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.07)

func _anim_cknight_swing(dir: Vector2, base_pos: Vector2) -> void:
	# Armored sword swing — deliberate, powerful, heavy follow-through
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Raise weapon — steady wind-up
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -5), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.1)
	# Heavy downward slash
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.1, 1.0) * base_mod)
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.06)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.15, 0.06)
	# Impact hold — heavy weapon plants
	tween.tween_interval(0.04)
	# Methodical recovery
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.08)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.08)
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)

func _anim_generic_lunge(dir: Vector2, base_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "position", base_pos - dir * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.04)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

# ============================================================
# SPECIAL ATTACK ANIMATIONS (15% chance, bonus damage)
# ============================================================

func _anim_rat_frenzy(dir: Vector2, base_pos: Vector2) -> void:
	# Frenzy bite — rapid triple chomp
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.7, 0.7))
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 11.0, 0.03)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.03)
		tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.03)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.03)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_goblin_backstab(dir: Vector2, base_pos: Vector2) -> void:
	# Sneaky backstab — dodge to side, stab from flank
	var perp = Vector2(-dir.y, dir.x)
	var side = perp if randf() > 0.5 else -perp
	var tween = create_tween()
	# Sidestep
	tween.tween_property(sprite, "position", base_pos + side * 8.0 - dir * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.1), 0.06)
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.6))
	# Stab from flank
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.75, 1.25), 0.04)
	# Twist
	tween.tween_property(sprite, "rotation", 0.3, 0.03)
	tween.tween_property(sprite, "rotation", 0.0, 0.04)
	# Hop back
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)

func _anim_wolf_savage_lunge(dir: Vector2, base_pos: Vector2) -> void:
	# Savage lunge — bigger leap, more violent head shake
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.8, 0.7))
	# Deep crouch
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.08)
	# Massive pounce
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, -4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.05)
	# Violent shake — 4 rapid side-to-side
	for i in range(4):
		var s = perp * 4.0 if i % 2 == 0 else -perp * 4.0
		tween.tween_property(sprite, "position", base_pos + dir * 16.0 + s, 0.025)
	# Release with snarl
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)
	tween.tween_property(sprite, "position", base_pos, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)

func _anim_skeleton_cleave(dir: Vector2, base_pos: Vector2) -> void:
	# Overhead two-handed cleave — dramatic raise, pause, slam
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.2, 0.8))
	# Raise high
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, -8), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.35), 0.12)
	# Menacing pause
	tween.tween_interval(0.06)
	# Crushing downward cleave
	tween.tween_property(sprite, "position", base_pos + dir * 13.0 + Vector2(0, 4), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.25, 0.05)
	# Bone rattle impact
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 13.0 + Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _anim_spider_venom(dir: Vector2, base_pos: Vector2) -> void:
	# Venom strike — rear up, stab with glowing green fangs
	var tween = create_tween()
	# Rear up threateningly
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -5), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 1.4, 0.5), 0.08)
	# Rapid venom stab
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, 4), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.04)
	# Hold — injecting venom
	tween.tween_interval(0.06)
	# Retract with green trail
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.95), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_bandit_cross_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Cross slash — two rapid diagonal cuts forming an X
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.0, 0.7))
	# First diagonal slash
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.3, 0.04)
	# Second diagonal — opposite direction
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 4.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", -0.3, 0.04)
	# Center hit
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.03)
	# Quick escape back
	tween.tween_property(sprite, "position", base_pos - dir * 3.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.95, 1.05), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_troll_mega_punch(dir: Vector2, base_pos: Vector2) -> void:
	# MEGA PUNCH — troll drops club, winds up massive fist, devastating haymaker
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Roar and rear way back — charging fist
	tween.tween_callback(func(): sprite.modulate = Color(1.5, 0.8, 0.6) * base_mod)
	tween.tween_property(sprite, "position", base_pos - dir * 10.0 + Vector2(0, -4), 0.3)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.75, 1.35), 0.3)
	# Menacing pause — fist cocked back
	tween.tween_interval(0.15)
	# MASSIVE forward haymaker — explosive
	tween.tween_property(sprite, "position", base_pos + dir * 22.0 + Vector2(0, 5), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.5, 0.6), 0.08)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.25, 0.08)
	# Devastating impact — heavy shake
	for i in range(4):
		var jitter = Vector2(randf_range(-3, 3), randf_range(-2, 2))
		tween.tween_property(sprite, "position", base_pos + dir * 20.0 + jitter + Vector2(0, 5), 0.03)
	# Very slow recovery — exhausted
	tween.tween_property(sprite, "modulate", base_mod, 0.2)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 8.0, 0.25)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.1, 0.95), 0.25)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.25)
	tween.tween_property(sprite, "position", base_pos, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)

func _anim_mage_dark_blast(dir: Vector2, base_pos: Vector2) -> void:
	# Dark blast — gather dark energy, release explosive burst
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	# Gather — pull inward, dark purple glow intensifies
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -3), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.3, 1.0) * base_mod, 0.12)
	# Pulse — energy overload
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.5, 1.5) * base_mod, 0.06)
	# Release — blast forward
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.04)
	# Recoil from blast
	tween.tween_property(sprite, "position", base_pos - dir * 5.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.06)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.1)

func _anim_ogre_ground_pound(dir: Vector2, base_pos: Vector2) -> void:
	# Ground pound — both fists overhead, massive slam, earth shakes
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.9, 0.7) * base_mod)
	# Rise up high — both fists raised
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -12), 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.75, 1.4), 0.2)
	# Hang at apex
	tween.tween_interval(0.1)
	# SLAM down — massive impact
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, 6), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.5, 0.6), 0.06)
	# Ground shake — heavy tremor
	for i in range(5):
		var jitter = Vector2(randf_range(-3, 3), randf_range(-1, 2))
		tween.tween_property(sprite, "position", base_pos + dir * 7.0 + jitter + Vector2(0, 6), 0.025)
	# Slow heavy recovery
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 3.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.05, 0.97), 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.15)

func _anim_elk_toss(dir: Vector2, base_pos: Vector2) -> void:
	# Antler toss — charges in, flicks head up violently to throw target
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(0.7, 1.4, 0.5) * base_mod)
	# Lower head — aiming antlers
	tween.tween_property(sprite, "position", base_pos - dir * 4.0 + Vector2(0, 4), 0.15)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.2, 0.8), 0.15)
	# Explosive charge
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.9, 1.0), 0.08)
	# Violent upward toss — flick head skyward
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + Vector2(0, -10), 0.06)
	tween.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.8, 1.35), 0.06)
	tween.parallel().tween_property(sprite, "rotation", -0.3, 0.06)
	# Settle back with majesty
	tween.tween_property(sprite, "modulate", base_mod, 0.15)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.2)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.tween_property(sprite, "position", base_pos, 0.12)

func _anim_snake_constrict(dir: Vector2, base_pos: Vector2) -> void:
	# Constrict — wraps around target, squeezes, releases
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.1, 0.7))
	# Lunge to target
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.4), 0.04)
	# Wrap — circle around (3 positions)
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + perp * 5.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 - perp * 5.0, 0.05)
	tween.tween_property(sprite, "position", base_pos + dir * 9.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.04)
	# Squeeze pulse
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.04)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.04)
	# Release and slither back
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_bat_divebomb(dir: Vector2, base_pos: Vector2) -> void:
	# Dive bomb — fly high, plummet down at speed
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 0.7, 0.7))
	# Fly up high
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -14), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.08)
	# Brief hover
	tween.tween_interval(0.04)
	# Dive bomb — fast straight down at target
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 5), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.04)
	# Bounce off impact
	tween.tween_property(sprite, "position", base_pos + dir * 8.0 + Vector2(0, -6), 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	# Flutter back
	tween.tween_property(sprite, "position", base_pos, 0.07)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.07)

func _anim_vbat_drain(dir: Vector2, base_pos: Vector2) -> void:
	# Drain bite — latch on, pulse red as draining, release
	var tween = create_tween()
	# Swoop in
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05)
	# Latch — pressed against target
	tween.tween_property(sprite, "position", base_pos + dir * 12.0, 0.03)
	# Drain pulses — red glow intensifies
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.08)
	tween.tween_property(sprite, "modulate", Color(1.8, 0.3, 0.3), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.08)
	# Release — satisfied, hop back
	tween.tween_property(sprite, "position", base_pos - dir * 3.0 + Vector2(0, -4), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.95), 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _anim_flan_bodyslam(dir: Vector2, base_pos: Vector2) -> void:
	# Body slam — compress way down, launch high, slam full weight
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.3, 1.2, 0.6))
	# Deep compression
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.4), 0.15)
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.05)
	# Launch high
	tween.tween_property(sprite, "position", base_pos + dir * 6.0 + Vector2(0, -12), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 1.5), 0.06)
	# SLAM full weight
	tween.tween_property(sprite, "position", base_pos + dir * 10.0 + Vector2(0, 4), 0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.6, 0.5), 0.04)
	# Jelly splat wobble
	tween.tween_property(sprite, "scale", Vector2(0.7, 1.4), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.75), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.95, 1.1), 0.05)
	# Settle
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _anim_mimic_devour(dir: Vector2, base_pos: Vector2) -> void:
	# Devour — lid opens WIDE, lunges to swallow, chomps multiple times
	var tween = create_tween()
	tween.tween_callback(func(): sprite.modulate = Color(1.4, 0.7, 0.6))
	# Lid flies open — massive stretch
	tween.tween_property(sprite, "scale", Vector2(0.7, 1.5), 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + Vector2(0, -5), 0.1)
	# Engulf lunge
	tween.tween_property(sprite, "position", base_pos + dir * 14.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
	# Rapid chomps — 3 bites
	for i in range(3):
		tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.03)
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.03)
	# Spit out — disgusted
	tween.tween_property(sprite, "position", base_pos + dir * 6.0, 0.05)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _anim_ghoul_rend(dir: Vector2, base_pos: Vector2) -> void:
	# Rend — frenzied double claw rake with lurching forward
	var perp = Vector2(-dir.y, dir.x)
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(0.7, 1.3, 0.5) * base_mod)
	# Lurch forward aggressively
	tween.tween_property(sprite, "position", base_pos + dir * 8.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.06)
	# First rake — right claw
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 + perp * 5.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.2, 0.04)
	# Second rake — left claw
	tween.tween_property(sprite, "position", base_pos + dir * 12.0 - perp * 5.0, 0.04)
	tween.parallel().tween_property(sprite, "rotation", -0.2, 0.04)
	# Third rake — center downward
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 3), 0.04)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.04)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.04)
	# Stumble back — spent
	tween.tween_property(sprite, "position", base_pos + dir * 4.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", base_mod, 0.06)
	tween.tween_property(sprite, "position", base_pos, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

func _anim_cknight_bash(dir: Vector2, base_pos: Vector2) -> void:
	# Shield bash — brace behind shield, charge forward, slam with shield edge
	var tween = create_tween()
	var base_mod = _base_modulate if _base_modulate else Color.WHITE
	tween.tween_callback(func(): sprite.modulate = Color(1.2, 1.2, 1.0) * base_mod)
	# Brace — hide behind shield (compress wide)
	tween.tween_property(sprite, "position", base_pos - dir * 4.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 0.85), 0.1)
	# Brief brace hold
	tween.tween_interval(0.05)
	# Charge forward — explosive
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.06)
	# Shield impact — heavy squash
	tween.tween_property(sprite, "scale", Vector2(1.35, 0.75), 0.03)
	# Impact jitter
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-2, 2), 0), 0.03)
	tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-2, 2), 0), 0.03)
	# Deliberate step back
	tween.tween_property(sprite, "modulate", base_mod, 0.1)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 4.0, 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.05, 0.97), 0.12)
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

# ---- Mini-boss attack animations ----

func _anim_boss_ground_slam(dir: Vector2, base_pos: Vector2) -> void:
	# Ravager / Ogre Boss: rear up high, slam the ground with a shockwave squash
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Wind-up — rear back and stretch tall
	tween.tween_property(sprite, "position", base_pos - dir * 6.0 + Vector2(0, -10), 0.12)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.8, sy * 1.35), 0.12)
	# Hang at apex briefly
	tween.tween_interval(0.06)
	# Slam down — fast, heavy
	tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(0, 4), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.5, sy * 0.6), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 1.0, 0.7), 0.06)
	# Impact — screen-shake feel via rapid position jitter
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 14.0 + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_charge_slash(dir: Vector2, base_pos: Vector2) -> void:
	# Dread Knight: fast charge forward with sweeping rotation slash
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Coil — pull back, lean into direction
	tween.tween_property(sprite, "position", base_pos - dir * 8.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.2, sy * 0.85), 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.7, 0.7), 0.08)
	# Dash forward — explosive speed
	tween.tween_property(sprite, "position", base_pos + dir * 20.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.7, sy * 1.3), 0.06)
	tween.parallel().tween_property(sprite, "rotation", dir.angle() * 0.4, 0.06)
	# Sweeping slash arc — rotate through
	tween.tween_property(sprite, "rotation", -dir.angle() * 0.3, 0.08)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.9, 0.9), 0.04)
	# Skid to a stop
	tween.tween_property(sprite, "position", base_pos + dir * 10.0, 0.06)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.06)
	# Return
	tween.tween_property(sprite, "position", base_pos, 0.1)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)

func _anim_boss_fire_breath(dir: Vector2, base_pos: Vector2) -> void:
	# Elder Drake: rear up, puff out, lunge with fiery tint
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rear up — inhale
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.15, sy * 1.25), 0.1)
	# Puff — swell out
	tween.tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 1.1), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.8, 0.3), 0.06)
	# Breath lunge — snap forward with fire tint
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.3), 0.07)
	tween.parallel().tween_property(sprite, "modulate", Color(1.8, 0.6, 0.2), 0.07)
	# Hold the flame
	tween.tween_interval(0.08)
	# Cool down — pull back, tint fades
	tween.tween_property(sprite, "position", base_pos, 0.14)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.14)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.14)

func _anim_boss_doom_strike(dir: Vector2, base_pos: Vector2) -> void:
	# Abyssal Lord: spin-up whirlwind then devastating overhead slam
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Spin-up — rapid full rotations with growing intensity
	tween.tween_property(sprite, "rotation", TAU, 0.15)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.4, 0.8), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 1.3), 0.15)
	tween.tween_property(sprite, "rotation", TAU * 2.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", Color(1.4, 0.3, 1.0), 0.12)
	# Release — slam forward
	tween.tween_property(sprite, "position", base_pos + dir * 18.0, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.6, sy * 0.5), 0.05)
	tween.parallel().tween_property(sprite, "rotation", TAU * 2.0 + dir.angle() * 0.3, 0.05)
	# Impact jitter
	for i in range(4):
		tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(randf_range(-5, 5), randf_range(-3, 3)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.14)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.14)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.14)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.14)

func _anim_boss_savage_pounce(dir: Vector2, base_pos: Vector2) -> void:
	# Shadow Fang: crouch low, explosive leap, snap bite, land heavy
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Crouch low — compress and widen
	tween.tween_property(sprite, "position", base_pos + Vector2(0, 4), 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 0.6), 0.08)
	# Explosive leap forward
	tween.tween_property(sprite, "position", base_pos + dir * 22.0, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.7, sy * 1.4), 0.05)
	# Snap bite flash
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.04)
	# Land heavy with jitter
	tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(0, 3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 0.75), 0.06)
	for i in range(2):
		tween.tween_property(sprite, "position", base_pos + dir * 18.0 + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_venom_barrage(dir: Vector2, base_pos: Vector2) -> void:
	# War Spider: rear up with green tint, 3 rapid jabs, toxic burst
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rear up — green venom tint
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -6), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.9, sy * 1.3), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.6, 1.4, 0.5), 0.1)
	# 3 rapid forward jabs with alternating rotation
	for i in range(3):
		var rot = 0.15 if i % 2 == 0 else -0.15
		tween.tween_property(sprite, "position", base_pos + dir * (10.0 + i * 4.0), 0.04)
		tween.parallel().tween_property(sprite, "rotation", rot, 0.04)
	# Toxic burst — green flash
	tween.tween_property(sprite, "modulate", Color(0.3, 2.0, 0.3), 0.06)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 1.3, sy * 1.3), 0.06)
	# Settle
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _anim_boss_death_cleave(dir: Vector2, base_pos: Vector2) -> void:
	# Bone Lord: rise tall, spinning cleave with forward dash, slam down
	var sx = _base_scale.x
	var sy = _base_scale.y
	var tween = create_tween()
	# Rise tall — pale blue tint
	tween.tween_property(sprite, "position", base_pos + Vector2(0, -8), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2(sx * 0.85, sy * 1.3), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.8, 1.4), 0.1)
	# Spinning cleave — full rotation + forward dash
	tween.tween_property(sprite, "position", base_pos + dir * 16.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", TAU, 0.1)
	# Slam down — wide and flat
	tween.tween_property(sprite, "scale", Vector2(sx * 1.4, sy * 0.7), 0.05)
	tween.parallel().tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(0, 4), 0.05)
	# Impact jitter with dark purple flash
	tween.tween_property(sprite, "modulate", Color(0.8, 0.3, 1.2), 0.06)
	for i in range(3):
		tween.tween_property(sprite, "position", base_pos + dir * 16.0 + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.02)
	# Recover
	tween.tween_property(sprite, "position", base_pos, 0.12)
	tween.parallel().tween_property(sprite, "scale", _base_scale, 0.12)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.12)
	tween.parallel().tween_property(sprite, "modulate", _base_modulate, 0.12)

func _spawn_blood_splatter() -> void:
	var blood_tex = SpriteGenerator.get_texture("blood_splatter")
	if not blood_tex:
		return
	var blood = Sprite2D.new()
	blood.texture = blood_tex
	blood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blood.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	blood.rotation = randf() * TAU
	blood.scale = Vector2(randf_range(0.8, 1.5), randf_range(0.8, 1.5))
	blood.z_index = -2
	blood.modulate.a = randf_range(0.6, 0.9)
	_get_world_node().add_child(blood)
	var fade_tween = blood.create_tween()
	fade_tween.tween_interval(randf_range(3.0, 5.0))
	fade_tween.tween_property(blood, "modulate:a", 0.0, 1.0)
	fade_tween.tween_callback(blood.queue_free)

static func _get_pooled_drop() -> Area2D:
	if _drop_pool.size() > 0:
		var drop = _drop_pool.pop_back()
		# Kill any leftover tweens
		for child in drop.get_children():
			if child is Sprite2D:
				child.position = Vector2.ZERO
				child.modulate = Color.WHITE
		return drop
	# Build a new drop: Area2D -> CollisionShape2D + Sprite2D
	var drop = Area2D.new()
	drop.collision_layer = 32
	drop.collision_mask = 0
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape_node.shape = circle
	drop.add_child(shape_node)
	var visual = Sprite2D.new()
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.name = "Visual"
	drop.add_child(visual)
	return drop

static func recycle_drop(drop: Area2D) -> void:
	if is_instance_valid(drop):
		drop.remove_from_group("ground_items")
		drop.get_parent().remove_child(drop)
		if _drop_pool.size() < DROP_POOL_MAX:
			_drop_pool.append(drop)
		else:
			drop.queue_free()

func _spawn_gold_drop(amount: int) -> void:
	var drop = _get_pooled_drop()
	drop.position = global_position
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", {"id": "_gold", "name": "%d Gold" % amount, "gold_amount": amount})

	var visual = drop.get_node("Visual") as Sprite2D
	visual.texture = SpriteGenerator.get_texture("crystal_blue" if amount >= 10 else "crystal_white")
	visual.modulate = Color.WHITE

	_get_world_node().add_child(drop)
	# Tween must be created after add_child (node needs to be in tree)
	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _spawn_item_drop(item_id: String) -> void:
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		return
	_spawn_item_drop_dict(item)

func _spawn_item_drop_dict(item: Dictionary) -> void:
	var drop = _get_pooled_drop()
	drop.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", item)

	var visual = drop.get_node("Visual") as Sprite2D
	visual.texture = SpriteGenerator.get_texture("crystal_teal")
	var rarity = item.get("rarity", 0)
	visual.modulate = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)

	_get_world_node().add_child(drop)
	# Tween must be created after add_child (node needs to be in tree)
	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	# Announce rare+ drops
	var rarity_name = ItemData.RARITY_NAMES.get(rarity, "")
	if rarity >= ItemData.Rarity.RARE:
		var color = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)
		GameManager.game_message.emit("%s %s dropped!" % [rarity_name, item.get("name", "Item")], color)

func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	var _zc = _get_zoom_compensation()
	var now_msec: int = Time.get_ticks_msec()
	# Phase 6.0a — combo accumulation: stack into existing active label
	# if we're inside the stacking window.
	if _active_dmg_label != null and is_instance_valid(_active_dmg_label) and now_msec < _active_dmg_label_until_msec:
		_active_dmg_value += amount
		_active_dmg_label.text = str(_active_dmg_value) + ("!" if is_crit else "")
		# Promote to crit settings if this hit was a crit.
		if is_crit:
			_active_dmg_label.label_settings = _dmg_settings_crit
		# Kill old fade tween and restart with a fresh window. Each stack
		# grows the label by 12% for a satisfying escalation.
		if _active_dmg_label_tween != null and _active_dmg_label_tween.is_valid():
			_active_dmg_label_tween.kill()
		_active_dmg_label.modulate.a = 1.0
		_active_dmg_label.scale = _active_dmg_label.scale * 1.12
		# Cap growth so the label doesn't fill the screen.
		var max_s: float = _zc * (2.0 if is_crit else 1.7)
		if _active_dmg_label.scale.x > max_s:
			_active_dmg_label.scale = Vector2(max_s, max_s)
		# Brief "pop" tween then fresh fade.
		var stack_tween := create_tween()
		stack_tween.tween_property(_active_dmg_label, "scale", _active_dmg_label.scale * 1.05, 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stack_tween.tween_property(_active_dmg_label, "scale", _active_dmg_label.scale, 0.04)
		stack_tween.set_parallel(true)
		stack_tween.tween_property(_active_dmg_label, "position:y", _active_dmg_label.position.y - 8, 0.5)
		stack_tween.tween_property(_active_dmg_label, "modulate:a", 0.0, 0.55).set_delay(0.2)
		stack_tween.set_parallel(false)
		stack_tween.tween_callback(_finalize_stack_label.bind(_active_dmg_label))
		_active_dmg_label_until_msec = now_msec + DMG_STACK_WINDOW_MS
		_active_dmg_label_tween = stack_tween
		return
	# No active label — spawn a fresh one and record it for future stacks.
	var label: Label
	if _dmg_label_pool.size() > 0:
		label = _dmg_label_pool.pop_back()
	else:
		label = Label.new()
	label.text = str(amount) + ("!" if is_crit else "")
	label.position = Vector2(randf_range(-10, 10) if not is_crit else randf_range(-6, 6), -30)
	label.label_settings = _dmg_settings_crit if is_crit else _dmg_settings_normal
	label.modulate.a = 1.0
	label.scale = Vector2(_zc, _zc)
	add_child(label)
	_active_dmg_label = label
	_active_dmg_value = amount
	_active_dmg_label_until_msec = now_msec + DMG_STACK_WINDOW_MS
	var tween = create_tween()
	if is_crit:
		label.scale = Vector2(0.4 * _zc, 0.4 * _zc)
		tween.tween_property(label, "scale", Vector2(1.3 * _zc, 1.3 * _zc), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(_zc, _zc), 0.05)
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 40, 0.7)
		tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
		tween.set_parallel(false)
	else:
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 28, 0.55)
		tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
		tween.set_parallel(false)
	_active_dmg_label_tween = tween
	tween.tween_callback(_finalize_stack_label.bind(label))


# Phase 6.0a — finalize a damage label. Clears the active reference
# (if this was the active one) and recycles into the pool.
func _finalize_stack_label(label: Label) -> void:
	if _active_dmg_label == label:
		_active_dmg_label = null
		_active_dmg_value = 0
		_active_dmg_label_tween = null
	_recycle_dmg_label(label)


static func _recycle_dmg_label(label: Label) -> void:
	if is_instance_valid(label):
		label.get_parent().remove_child(label)
		if _dmg_label_pool.size() < DMG_LABEL_POOL_MAX:
			_dmg_label_pool.append(label)
		else:
			label.queue_free()

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.set_value(stats.current_hp, stats.max_hp)
		if not _is_selected:
			hp_bar.visible = stats.current_hp < stats.max_hp
		# Phase 6.x — brief white flash on HP bar when damage is taken so
		# the change is visible at a glance.
		var prev_mod := hp_bar.modulate
		hp_bar.modulate = Color(2.0, 2.0, 2.0, prev_mod.a)
		var t := hp_bar.create_tween()
		t.tween_property(hp_bar, "modulate", prev_mod, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# v0.91.2 — HP-tint bloodying removed during visual revamp. The procedural
	# tint shift fought the new modern-pixel-art direction; kept as no-op for
	# now (HP bar remains the readability surface).
	pass

func _apply_hp_tint() -> void:
	if _is_dead or sprite == null:
		return
	if _captured_pristine_modulate == null:
		# First-call capture: store whatever base color the enemy started with
		# (mini-boss reddish tint, elite tints, plain WHITE, etc.).
		_captured_pristine_modulate = _base_modulate
		_last_set_base_modulate = _base_modulate
	var hp_max: int = max(1, int(stats.max_hp))
	var pct: float = clamp(float(stats.current_hp) / float(hp_max), 0.0, 1.0)
	# Pristine = original color; bloodied = darker + redder.
	var pristine: Color = _captured_pristine_modulate
	var bloodied: Color = Color(pristine.r * 1.10, pristine.g * 0.55, pristine.b * 0.50, pristine.a)
	# Below 33% HP, lerp fully toward bloodied. Between 33%–66% partial.
	var lerp_t: float = 1.0 - smoothstep(0.33, 0.85, pct)
	var new_base: Color = pristine.lerp(bloodied, lerp_t)
	_base_modulate = new_base
	# If no active flash tween is running, snap sprite to the new base.
	if sprite.modulate.is_equal_approx(_last_set_base_modulate):
		sprite.modulate = new_base
	_last_set_base_modulate = new_base

var _captured_pristine_modulate: Variant = null
var _last_set_base_modulate: Color = Color.WHITE

func get_stats_dict() -> Dictionary:
	return stats.get_stats_dict()

func _get_player() -> Node2D:
	if _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		return _cached_player
	return null

func _update_sleep_state() -> void:
	var player = _get_player()
	if not player:
		return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	if _is_sleeping:
		# Wake up when player gets close enough (with hysteresis to avoid flicker)
		if dist_sq < WAKE_DISTANCE_SQ:
			_is_sleeping = false
			visible = true
			set_physics_process(true)
	else:
		# Fall asleep when player is far away (only if not in combat)
		if dist_sq > SLEEP_DISTANCE_SQ and current_state != State.CHASE and current_state != State.ATTACK and current_state != State.RETURN:
			_is_sleeping = true
			visible = false
			velocity = Vector2.ZERO
			set_physics_process(false)
	# Proximity-based label visibility for non-combat states
	if not _is_selected and current_state != State.CHASE and current_state != State.ATTACK:
		name_label.visible = dist_sq < LABEL_VISIBLE_DISTANCE_SQ

func _get_world_node() -> Node:
	if _cached_world_node and is_instance_valid(_cached_world_node):
		return _cached_world_node
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		_cached_world_node = world[0]
	else:
		_cached_world_node = get_tree().current_scene
	return _cached_world_node


# Phase 1B.6b — visual hit reaction wiring.
# Heuristic tier mapping: mini-bosses → ELITE; specific tough sprites →
# HEAVY; everything else → LIGHT. Tuning expected at 1B.7.
# Returns the int matching HitReactionData.Tier (LIGHT=0..BOSS=4).
func _pick_reaction_tier() -> int:
	if is_mini_boss:
		return 3  # ELITE
	match sprite_type:
		"troll", "ogre":
			return 2  # HEAVY
		"bandit", "wolf":
			return 1  # MEDIUM
		_:
			return 0  # LIGHT


# Phase 5.0 — death reactions per killing-attack-type.
# Returns true if a custom death variant fired; false to fall through to
# the standard per-sprite_type death.
func _try_play_killing_attack_death() -> bool:
	match _killing_attack_id:
		&"swing_c", &"branch_slam":
			_die_ground_press()
			return true
		&"branch_uppercut":
			_die_uppercut_launch()
			return true
		&"branch_spin", &"whirlwind":
			_die_spin_collapse()
			return true
		&"charged_slash", &"sniper_shot":
			_die_directional_fling()
			return true
		&"power_strike", &"dash_strike":
			_die_knockback_tumble()
			return true
	return false


# Ground press: sprite squashes flat with a small bounce-back and an
# extra dust/ring at the impact point.
func _die_ground_press() -> void:
	_spawn_blood_splatter()
	if is_instance_valid(sprite):
		var t := sprite.create_tween()
		t.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.5, _base_scale.y * 0.10), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "scale", Vector2(_base_scale.x * 1.3, _base_scale.y * 0.18), 0.10)
		t.tween_property(sprite, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)
	# Ground impact ring.
	_spawn_dramatic_death_ring(Color(1.5, 0.7, 0.15, 0.9), 5.0, 0.32)


# Uppercut launch: sprite jumps up, spins once, then falls.
func _die_uppercut_launch() -> void:
	_spawn_blood_splatter()
	if is_instance_valid(sprite):
		var base_pos := sprite.position
		var t := sprite.create_tween()
		t.set_parallel(true)
		t.tween_property(sprite, "position:y", base_pos.y - 40.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "rotation", TAU, 0.30)
		t.set_parallel(false)
		t.tween_property(sprite, "position:y", base_pos.y + 8.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(sprite, "modulate:a", 0.0, 0.15)
		t.tween_callback(queue_free)
	_spawn_dramatic_death_ring(Color(1.3, 0.85, 0.4, 0.85), 4.2, 0.28)


# Spin collapse: sprite spins multiple times while shrinking.
func _die_spin_collapse() -> void:
	_spawn_blood_splatter()
	if is_instance_valid(sprite):
		var t := sprite.create_tween()
		t.set_parallel(true)
		t.tween_property(sprite, "rotation", TAU * 2.5, 0.40)
		t.tween_property(sprite, "scale", _base_scale * 0.15, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(sprite, "modulate:a", 0.0, 0.40)
		t.set_parallel(false)
		t.tween_callback(queue_free)
	_spawn_dramatic_death_ring(Color(0.85, 0.5, 1.3, 0.85), 4.5, 0.30)


# Directional fling: sprite launches away from attacker, spinning.
func _die_directional_fling() -> void:
	_spawn_blood_splatter()
	if is_instance_valid(sprite):
		var fling_dir: Vector2 = _killing_hit_direction
		if fling_dir.length() < 0.01:
			fling_dir = Vector2.RIGHT
		var base_pos := sprite.position
		var dest: Vector2 = base_pos + fling_dir.normalized() * 70.0 + Vector2(0, -10)
		var t := sprite.create_tween()
		t.set_parallel(true)
		t.tween_property(sprite, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "rotation", TAU * 1.5 * sign(fling_dir.x + 0.01), 0.35)
		t.tween_property(sprite, "scale", _base_scale * 0.25, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(sprite, "modulate:a", 0.0, 0.40)
		t.set_parallel(false)
		t.tween_callback(queue_free)
	_spawn_dramatic_death_ring(Color(1.5, 1.3, 0.3, 0.85), 4.0, 0.28)


# Knockback tumble: launch away + tumble + shrink.
func _die_knockback_tumble() -> void:
	_spawn_blood_splatter()
	if is_instance_valid(sprite):
		var fling_dir: Vector2 = _killing_hit_direction
		if fling_dir.length() < 0.01:
			fling_dir = Vector2.RIGHT
		var base_pos := sprite.position
		var dest: Vector2 = base_pos + fling_dir.normalized() * 55.0 + Vector2(0, -4)
		var t := sprite.create_tween()
		t.set_parallel(true)
		t.tween_property(sprite, "position", dest, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "rotation", TAU * 0.8 * sign(fling_dir.x + 0.01), 0.30)
		t.tween_property(sprite, "scale", _base_scale * Vector2(1.4, 0.55), 0.10)
		t.set_parallel(false)
		t.tween_property(sprite, "scale", _base_scale * 0.2, 0.20)
		t.tween_property(sprite, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)
	_spawn_dramatic_death_ring(Color(1.4, 0.5, 0.15, 0.85), 4.2, 0.30)


func _spawn_dramatic_death_ring(color: Color, final_scale: float, duration: float) -> void:
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.global_position = global_position
	ring.modulate = color
	ring.scale = Vector2(0.5, 0.5)
	ring.z_index = -1
	_get_world_node().add_child(ring)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(final_scale, final_scale), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, duration * 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(ring.queue_free)


# Universal mega-explode: smaller scale of the rat MEGA but applies to
# ANY enemy. Triggered with low-but-real chance from _play_death_animation.
# Cranks the existing blood splatter + rat-gib texture into a big fan +
# ring + shake regardless of sprite type. Player still gets a brief gore
# coat (reduced from rat scale).
func _die_universal_mega_explode() -> void:
	# Blood splatters — scaled to enemy size.
	for _i in range(randi_range(8, 14)):
		_spawn_blood_splatter()
	# Generic gib cloud using the rat_gib texture (universal red chunk).
	var gib_tex = SpriteGenerator.get_texture("rat_gib")
	if gib_tex != null:
		var world = _get_world_node()
		var count: int = randi_range(40, 70)
		for _i in range(count):
			var gib = Sprite2D.new()
			gib.texture = gib_tex
			gib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			gib.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-10, 4))
			gib.rotation = randf() * TAU
			gib.scale = Vector2(randf_range(0.7, 1.8), randf_range(0.7, 1.8))
			gib.z_index = -1
			gib.modulate = Color(
				randf_range(0.9, 1.3),
				randf_range(0.3, 0.65),
				randf_range(0.3, 0.55),
				randf_range(0.85, 1.0)
			)
			world.add_child(gib)
			var dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var force = randf_range(70, 180)
			var apex = gib.global_position + dir * force * 0.55 + Vector2(0, -randf_range(15, 45))
			var dest = gib.global_position + dir * force + Vector2(0, randf_range(8, 25))
			var t = gib.create_tween()
			t.set_parallel(true)
			t.tween_property(gib, "global_position", apex, randf_range(0.12, 0.20)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(gib, "rotation", gib.rotation + randf_range(-12.0, 12.0), 0.45)
			t.set_parallel(false)
			t.tween_property(gib, "global_position", dest, randf_range(0.18, 0.28)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_interval(randf_range(2.0, 4.0))
			t.tween_property(gib, "modulate:a", 0.0, 0.8)
			t.tween_callback(gib.queue_free)

	# Sprite goes white-flash then deep red wash and explodes outward.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(3.5, 3.5, 3.5), 0.04)
	tween.parallel().tween_property(sprite, "scale", _base_scale * 4.5, 0.04)
	tween.tween_property(sprite, "modulate", Color(2.8, 0.4, 0.4), 0.03)
	tween.parallel().tween_property(sprite, "scale", Vector2(_base_scale.x * 5.5, _base_scale.y * 0.15), 0.03)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.04)
	tween.tween_callback(queue_free)

	# Shockwave ring.
	var world := _get_world_node()
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("rat_gib")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.global_position = global_position
		ring.modulate = Color(1.7, 0.2, 0.2, 0.9)
		ring.scale = Vector2(0.4, 0.4)
		ring.z_index = -2
		world.add_child(ring)
		var rt := ring.create_tween()
		rt.set_parallel(true)
		rt.tween_property(ring, "scale", Vector2(18.0, 18.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.tween_property(ring, "modulate:a", 0.0, 0.60).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rt.set_parallel(false)
		rt.tween_callback(ring.queue_free)

	# Screen shake + global dip — punchy but smaller than rat MEGA.
	var player := _get_player()
	if player and is_instance_valid(player):
		if player.global_position.distance_squared_to(global_position) < 700.0 * 700.0:
			if player.has_method("_do_screen_shake"):
				player._do_screen_shake(14.0)
	if HitStopController != null and HitStopController.has_method("request_global_dip"):
		HitStopController.request_global_dip(0.25, 90, 2, &"universal_mega")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", 4.0)


# Phase 3.4b — Elite modifier system.
# Picks a random modifier, applies stat changes, and spawns a colored
# aura sprite that follows the enemy so the player can recognize them
# at a glance.
#
# Modifiers:
#   haste     — attacks 30% faster, moves 20% faster (cyan aura)
#   armored   — takes 35% less damage (gray aura)
#   exploder  — detonates on death dealing radial damage (orange aura)
#   berserker — 70% HP, +40% damage (deep red aura)
#   healer    — regenerates HP slowly while alive (green aura)
#   shocking  — every 3rd hit chains lightning to a nearby enemy (purple aura)
const _ELITE_MODIFIERS: Array[StringName] = [
	&"haste", &"armored", &"exploder", &"berserker", &"healer", &"shocking"
]
func _roll_elite_modifier() -> void:
	_elite_modifier = _ELITE_MODIFIERS[randi() % _ELITE_MODIFIERS.size()]
	# Apply stat tweaks.
	match _elite_modifier:
		&"haste":
			attack_cooldown = attack_cooldown * 0.70
			stats.move_speed = stats.move_speed * 1.20
		&"armored":
			# Damage reduction applied at take_damage time.
			pass
		&"exploder":
			pass  # Effect on death.
		&"berserker":
			stats.max_hp = int(stats.max_hp * 0.70)
			stats.current_hp = stats.max_hp
			# Damage applied at attack-resolve via _get_special_attack_mult-like
			# adjustment — see _process_attack callers.
		&"healer":
			pass  # Regen handled in _physics_process.
		&"shocking":
			pass  # Effect on hit landed by player (via signals later) — for
			# simplicity, we use a counter on take_damage.
	# Visual aura.
	_spawn_elite_aura(_get_elite_color())
	# Promote name with [E:Modifier] suffix.
	if name_label != null:
		var prefix := _get_elite_prefix()
		if prefix != "":
			name_label.text = prefix + " " + enemy_name
	# Bump XP / gold reward for the extra effort.
	xp_reward = int(float(xp_reward) * 1.5)
	gold_reward = int(float(gold_reward) * 1.5)


func _get_elite_color() -> Color:
	match _elite_modifier:
		&"haste":
			return Color(0.4, 1.4, 1.6, 0.6)
		&"armored":
			return Color(0.9, 0.9, 1.0, 0.6)
		&"exploder":
			return Color(1.7, 0.6, 0.15, 0.65)
		&"berserker":
			return Color(1.8, 0.2, 0.2, 0.65)
		&"healer":
			return Color(0.3, 1.7, 0.5, 0.6)
		&"shocking":
			return Color(1.3, 0.5, 1.7, 0.65)
	return Color(1.5, 1.2, 0.4, 0.6)


func _get_elite_prefix() -> String:
	match _elite_modifier:
		&"haste":
			return "Hasted"
		&"armored":
			return "Armored"
		&"exploder":
			return "Volatile"
		&"berserker":
			return "Berserker"
		&"healer":
			return "Vampiric"
		&"shocking":
			return "Shocking"
	return ""


func _spawn_elite_aura(color: Color) -> void:
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	_elite_aura = Sprite2D.new()
	_elite_aura.texture = tex
	_elite_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_elite_aura.modulate = color
	_elite_aura.scale = Vector2(1.6, 1.6)
	_elite_aura.z_index = -2
	add_child(_elite_aura)
	# Slow pulse loop so it reads as "alive".
	_elite_aura_tween = _elite_aura.create_tween().set_loops()
	_elite_aura_tween.tween_property(_elite_aura, "scale", Vector2(2.0, 2.0), 0.7).set_trans(Tween.TRANS_SINE)
	_elite_aura_tween.tween_property(_elite_aura, "scale", Vector2(1.6, 1.6), 0.7).set_trans(Tween.TRANS_SINE)


# Damage modifier from elite (applied in player damage path via override).
func _elite_damage_taken_mult() -> float:
	if _elite_modifier == &"armored":
		return 0.65
	return 1.0


func _elite_damage_dealt_mult() -> float:
	if _elite_modifier == &"berserker":
		return 1.40
	return 1.0


# Phase 3.4b — exploder death AoE. Called from _die before the death
# animation when applicable.
const _EXPLODER_RADIUS: float = 90.0
const _EXPLODER_DAMAGE: int = 25
func _elite_exploder_burst() -> void:
	# Visual ring like a small bomb.
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		return
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.global_position = global_position
	ring.modulate = Color(1.7, 0.6, 0.1, 0.95)
	ring.scale = Vector2(0.5, 0.5)
	ring.z_index = 5
	_get_world_node().add_child(ring)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(_EXPLODER_RADIUS / 14.0, _EXPLODER_RADIUS / 14.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(ring.queue_free)
	# Damage the player if in range.
	var player := _get_player()
	if player != null and is_instance_valid(player):
		if player.global_position.distance_squared_to(global_position) <= _EXPLODER_RADIUS * _EXPLODER_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(_EXPLODER_DAMAGE, false)
	# Damage other enemies too (friendly fire on volatile).
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or e.get("_is_dead"):
			continue
		if e.global_position.distance_squared_to(global_position) <= _EXPLODER_RADIUS * _EXPLODER_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(int(_EXPLODER_DAMAGE * 0.6), false)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", 1.0)


# Phase 5.x — persistent blood puddle on the ground at the death site.
# Fades over 25 seconds. Uses existing crystal_white texture tinted dark
# red so no new asset needed.
const _BLOOD_PUDDLE_LIFETIME_SEC: float = 25.0
func _spawn_blood_puddle() -> void:
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var puddle := Sprite2D.new()
	puddle.texture = tex
	puddle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Multiple small ellipses overlap for organic shape.
	puddle.global_position = global_position + Vector2(randf_range(-3, 3), 6)
	puddle.modulate = Color(0.35, 0.05, 0.05, 0.75)
	puddle.scale = Vector2(randf_range(1.4, 2.2), randf_range(0.6, 1.0))
	puddle.rotation = randf() * TAU
	puddle.z_index = -2  # ground level
	_get_world_node().add_child(puddle)
	# Fade tween.
	var t: Tween = puddle.create_tween()
	t.tween_interval(_BLOOD_PUDDLE_LIFETIME_SEC - 3.0)
	t.tween_property(puddle, "modulate:a", 0.0, 3.0)
	t.tween_callback(puddle.queue_free)


# Phase 3.10 — last-enemy cinematic. After this enemy dies, check for
# other AWAKE non-dead enemies within encounter radius of the player.
# If none, request a brief global time dip via HitStopController for a
# satisfying "fight is over" beat. Skipped during boss fights so the
# boss doesn't trigger it every time their last grunt dies.
const _LAST_ENEMY_RADIUS_SQ: float = 700.0 * 700.0
const _LAST_ENEMY_DIP_MS: int = 180
func _maybe_play_last_enemy_cinematic() -> void:
	# Don't fire for mini-boss death — too much overlap with boss dramatic
	# death animation. Don't fire if the player isn't around.
	if is_mini_boss:
		return
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return
	# Count awake non-dead enemies near the player (excluding self).
	var others := get_tree().get_nodes_in_group("enemies")
	var survivor_count: int = 0
	for e in others:
		if e == self or not is_instance_valid(e):
			continue
		if e.get("_is_dead"):
			continue
		if e.get("_is_sleeping"):
			continue
		if e.global_position.distance_squared_to(player.global_position) > _LAST_ENEMY_RADIUS_SQ:
			continue
		survivor_count += 1
		if survivor_count >= 1:
			break  # only need to know there's at least one
	if survivor_count > 0:
		return
	# We're the last one. Dramatic finale.
	if HitStopController != null and HitStopController.has_method("request_global_dip"):
		HitStopController.request_global_dip(0.28, _LAST_ENEMY_DIP_MS, 3, &"last_enemy_cinematic")
	# Small bonus to player momentum as a "well fought" pat on the back.
	var mom = player.get_node_or_null("MomentumComponent")
	if mom != null and mom.has_method("add_bonus"):
		mom.add_bonus(10.0, &"encounter_clear")


# Phase 2.12 — combat pickup drop roll. Rates are independent so one
# enemy could drop multiple, but realistically you'll see one per ~6
# kills. Mini-bosses get a guaranteed pickup.
const _PICKUP_RATE_MOMENTUM: float = 0.14
const _PICKUP_RATE_HEALTH: float = 0.06
const _PICKUP_RATE_COOLDOWN: float = 0.015
func _roll_combat_pickup() -> void:
	var rate_mom: float = _PICKUP_RATE_MOMENTUM
	var rate_hp: float = _PICKUP_RATE_HEALTH
	var rate_cd: float = _PICKUP_RATE_COOLDOWN
	if is_mini_boss:
		rate_mom = 1.0
		rate_hp = 0.5
		rate_cd = 0.3
	if randf() < rate_mom:
		_spawn_pickup(&"momentum", 15.0)
	if randf() < rate_hp:
		_spawn_pickup(&"health", 20.0)
	if randf() < rate_cd:
		_spawn_pickup(&"cooldown_orb", 0.0)


func _spawn_pickup(pickup_type: StringName, magnitude: float) -> void:
	var pickup = CombatPickupCls.new()
	pickup.pickup_type = pickup_type
	pickup.magnitude = magnitude
	var jitter := Vector2(randf_range(-10, 10), randf_range(-8, 4))
	pickup.global_position = global_position + jitter
	var world := _get_world_node()
	if world == null:
		queue_free()
		return
	world.add_child(pickup)
	# Small spawn-arc tween so the pickup feels ejected from the corpse.
	var dest: Vector2 = pickup.global_position + Vector2(randf_range(-20, 20), randf_range(-18, -4))
	var t := pickup.create_tween()
	t.tween_property(pickup, "global_position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Phase 2.6/2.7 — status effect visuals.
# When "exposed" is applied, give the sprite a subtle warm tint that
# pulses slightly so the player can see the special damage bonus is
# available. On expire, restore the original modulate.
# Phase 5.2 — also spawn a floating status ICON above the enemy so the
# player can spot active statuses across a crowded fight at a glance.
var _exposed_pulse_tween: Tween = null
var _status_icons: Dictionary = {}  # StringName -> Sprite2D
# Phase 6.x — visible poise bar above the enemy.
var _poise_bar_bg: ColorRect = null
var _poise_bar_fill: ColorRect = null
var _poise_bar_hide_timer: float = 0.0

func _on_status_applied(id: StringName, _source: Node, _stacks: int) -> void:
	if _is_dead:
		return
	if id == &"exposed":
		_exposed_pulse_tween = sprite.create_tween().set_loops()
		_exposed_pulse_tween.tween_property(sprite, "modulate", Color(1.25, 1.05, 0.85), 0.5)
		_exposed_pulse_tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	_spawn_status_icon(id)


func _on_status_expired(id: StringName) -> void:
	if id == &"exposed":
		if _exposed_pulse_tween != null and _exposed_pulse_tween.is_valid():
			_exposed_pulse_tween.kill()
		_exposed_pulse_tween = null
		if not _is_dead and is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
	_remove_status_icon(id)


# Phase 5.2 — status icon above enemy. Bobs up/down + pulses. Per-status
# color so multiple statuses are readable.
func _spawn_status_icon(id: StringName) -> void:
	if _is_dead:
		return
	if _status_icons.has(id) and is_instance_valid(_status_icons[id]):
		return  # already showing
	var icon_color: Color = Color.WHITE
	match id:
		&"exposed":
			icon_color = Color(1.5, 0.8, 0.2)
		&"bleed":
			icon_color = Color(1.5, 0.2, 0.2)
		&"mark":
			icon_color = Color(1.0, 0.6, 1.5)
		_:
			icon_color = Color(0.9, 0.9, 1.0)
	var icon := Sprite2D.new()
	var tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		tex = SpriteGenerator.get_texture("rat_gib")
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = icon_color
	icon.scale = Vector2(0.4, 0.4)
	# Position above the sprite, offset by the count of already-shown icons.
	var x_offset: float = -8.0 + float(_status_icons.size()) * 10.0
	icon.position = Vector2(x_offset, -34.0)
	icon.z_index = 5
	add_child(icon)
	# Bob up/down loop.
	var bob := icon.create_tween().set_loops()
	bob.tween_property(icon, "position:y", icon.position.y - 4.0, 0.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(icon, "position:y", icon.position.y, 0.4).set_trans(Tween.TRANS_SINE)
	_status_icons[id] = icon


# Phase 6.x — poise bar visualization above enemy.
const _POISE_BAR_WIDTH: float = 32.0
const _POISE_BAR_HEIGHT: float = 3.0
func _build_poise_bar() -> void:
	_poise_bar_bg = ColorRect.new()
	_poise_bar_bg.color = Color(0.06, 0.04, 0.05, 0.75)
	_poise_bar_bg.position = Vector2(-_POISE_BAR_WIDTH / 2.0, -42.0)
	_poise_bar_bg.size = Vector2(_POISE_BAR_WIDTH, _POISE_BAR_HEIGHT)
	_poise_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poise_bar_bg.visible = false
	add_child(_poise_bar_bg)
	_poise_bar_fill = ColorRect.new()
	_poise_bar_fill.color = Color(0.4, 0.8, 1.0, 0.95)
	_poise_bar_fill.position = Vector2(1.0, 0.5)
	_poise_bar_fill.size = Vector2(_POISE_BAR_WIDTH - 2.0, _POISE_BAR_HEIGHT - 1.0)
	_poise_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poise_bar_bg.add_child(_poise_bar_fill)


func _on_poise_changed(current: float, max_poise: int) -> void:
	if _is_dead or _poise_bar_bg == null or _poise_bar_fill == null:
		return
	var ratio: float = clamp(current / max(1.0, float(max_poise)), 0.0, 1.0)
	_poise_bar_fill.size.x = max(0.0, (_POISE_BAR_WIDTH - 2.0) * ratio)
	# Color shifts by remaining poise.
	if ratio > 0.66:
		_poise_bar_fill.color = Color(0.4, 0.8, 1.0, 0.95)
	elif ratio > 0.33:
		_poise_bar_fill.color = Color(1.0, 0.8, 0.3, 0.95)
	else:
		_poise_bar_fill.color = Color(1.4, 0.35, 0.2, 0.95)
	# Hide when full (no damage taken yet); show otherwise.
	_poise_bar_bg.visible = ratio < 0.99


func _remove_status_icon(id: StringName) -> void:
	if not _status_icons.has(id):
		return
	var icon = _status_icons[id]
	_status_icons.erase(id)
	if not is_instance_valid(icon):
		return
	var fade_tween: Tween = icon.create_tween()
	fade_tween.tween_property(icon, "modulate:a", 0.0, 0.18)
	fade_tween.tween_callback(icon.queue_free)


# Phase 2.0 — poise break handler. Poise break is bigger than stagger:
#   - cancels current attack like stagger does
#   - extends freeze for the full vulnerability window
#   - feeds back into HitReaction as a forced "heavy" reaction visually
# enemy.gd does NOT respond to small poise hits — only break and recovery.
func _on_poise_broken(vulnerability_ms: int) -> void:
	if _is_dead:
		return
	if current_state == State.ATTACK:
		_attack_timer = attack_cooldown
	if HitStopController != null and vulnerability_ms > 0:
		HitStopController.freeze_target(self, vulnerability_ms, 1)  # VICTIM
	# Phase 6.x — POISE BREAK VISUAL: yellow flash ring + BREAK! pop above
	# the enemy so the player sees the satisfying moment clearly.
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.global_position = global_position
		ring.modulate = Color(1.7, 1.4, 0.3, 0.95)
		ring.scale = Vector2(0.5, 0.5)
		ring.z_index = 5
		_get_world_node().add_child(ring)
		var t: Tween = ring.create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(5.5, 5.5), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)
	# Quick audio cue at peak.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("crit_hit", -2.0)
	# Strong visual: instant deeper recoil pose via the reaction component.
	# We synthesize a reaction with no incoming force (already frozen) but
	# strong visual tier by temporarily swapping the profile to ELITE for
	# one react() call.
	if _hit_reaction != null and is_instance_valid(_hit_reaction):
		var prev_profile = _hit_reaction.profile
		_hit_reaction.profile = HitReactionDataCls.new().apply_preset(3)  # ELITE
		# Use the existing facing as the recoil direction.
		var d := -velocity.normalized() if velocity.length() > 0.01 else Vector2.RIGHT
		_hit_reaction.react(d, 0.0, true, true)
		# Restore tier-appropriate profile on next idle frame.
		var owner_ref := self
		var restore_call := func() -> void:
			if is_instance_valid(_hit_reaction):
				_hit_reaction.profile = prev_profile
		# A short SceneTreeTimer ensures restoration outlives the freeze.
		get_tree().create_timer(0.4).timeout.connect(restore_call)


# Poise window ended — pool restored, post-break immunity now active for
# a moment. Plan §2.0 acceptance criterion.
func _on_poise_recovered() -> void:
	if _is_dead:
		return
	# After break, switch to CHASE so the enemy doesn't immediately swing
	# without re-evaluating the situation (plan corr. 10).
	if current_state == State.ATTACK:
		current_state = State.CHASE
		_attack_timer = max(_attack_timer, attack_cooldown * 0.6)


# Phase 1B.6e — stagger handlers.
# HitReactionComponent fires stagger_requested when the hit is strong
# enough (tier-dependent, with profile.stagger_only_heavy gating).
# Owner code decides what stagger means to the AI. We:
#   - cancel any in-flight attack
#   - extend the hit-stop freeze for the full stagger duration so
#     _physics_process keeps skipping
func _on_stagger_requested(duration_ms: int) -> void:
	if _is_dead:
		return
	# Interrupt the attack so the enemy can't immediately re-strike on
	# resume (plan corr. 10: don't blindly restore prior state).
	if current_state == State.ATTACK:
		_attack_timer = attack_cooldown * 0.5
	# Phase 3.0a — cancel any in-flight attack wind-up so a staggered
	# enemy doesn't keep their telegraph mid-air. Phase 3.3 — release
	# the coordinator token so other enemies get to attack.
	if _windup_started:
		_windup_started = false
		_release_attack_token(_reserved_token_cost)
		_reserved_token_cost = 0
		_cancel_attack_windup()
		# Phase 3.5 — interrupted heavy attacks leave the enemy vulnerable.
		# Players punish them HARD.
		_trigger_vulnerability_window(&"interrupted")
	if HitStopController != null and duration_ms > 0:
		HitStopController.freeze_target(self, duration_ms, 1)  # VICTIM


# Phase 3.0a/3.1 — per-enemy wind-up duration. Rats jab fast; trolls
# telegraph a long heavy. Encodes enemy identity at attack time without
# needing a separate Resource per type.
func _get_windup_sec() -> float:
	if is_mini_boss:
		return 0.75
	match sprite_type:
		"rat":
			return 0.18
		"skeleton", "goblin":
			return 0.32
		"bandit", "wolf", "spider", "ghoul":
			return 0.40
		"dark_mage", "shadow_wraith", "lich", "vampire_bat":
			return 0.50
		"troll", "ogre", "ancient_golem", "crypt_knight", "demon_knight":
			return 0.65
		"dragon_whelp", "infernal":
			return 0.55
		_:
			return _WINDUP_BASE_SEC


# Phase 3.3 — coordinator token cost by enemy tier.
func _get_token_cost() -> int:
	if is_mini_boss:
		return 4
	match sprite_type:
		"rat", "skeleton", "goblin", "dungeon_bat":
			return 1
		"bandit", "wolf", "spider", "ghoul", "cave_snake":
			return 2
		"troll", "ogre", "ancient_golem", "crypt_knight", "demon_knight":
			return 3
		"dragon_whelp", "infernal", "lich":
			return 3
		_:
			return 2


# Phase 3.1 — telegraph severity. Yellow for light, orange for medium,
# red for heavy / mini-boss. Lets the player visually triage incoming
# attacks in a busy fight.
func _get_telegraph_severity_color() -> Color:
	if is_mini_boss:
		return Color(1.7, 0.15, 0.55, 0.5)  # magenta — boss-tier
	match sprite_type:
		"rat", "skeleton", "goblin", "dungeon_bat":
			return Color(1.6, 1.4, 0.3, 0.45)  # yellow — light
		"bandit", "wolf", "spider", "ghoul", "cave_snake":
			return Color(1.6, 0.8, 0.2, 0.5)   # orange — medium
		"troll", "ogre", "ancient_golem", "crypt_knight", "demon_knight":
			return Color(1.7, 0.25, 0.2, 0.55) # deep red — heavy
		_:
			return Color(1.5, 0.5, 0.3, 0.5)


# Phase 3.0a — enemy attack telegraph.
# Anticipation: sprite squashes + tilts back, red modulate tint, brief
# floor arc towards the target. Lasts roughly windup_sec before damage
# resolves. Skilled players can dodge / interrupt during this window.
func _begin_attack_windup() -> void:
	if _is_dead or not is_instance_valid(sprite):
		return
	# v0.90.2 — roll for surprise slam telegraph BEFORE other windup logic
	# so _get_attack_pattern() reflects it for all downstream branches.
	_maybe_roll_pattern_override()
	# Kill any leftover wind-up tween.
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	var windup: float = _get_windup_sec()
	# Wind-up pose: lean back + warning tint + squash. Heavier enemies
	# lean back further as part of their identity.
	var lean_dist: float = 4.0
	var squash := Vector2(1.18, 0.85)
	if _get_token_cost() >= 3:
		lean_dist = 8.0
		squash = Vector2(1.25, 0.78)
	var back_dir: Vector2 = Vector2.RIGHT
	if is_instance_valid(target):
		back_dir = (global_position - target.global_position).normalized()
	var tint: Color = _get_telegraph_severity_color()
	# Sprite modulate uses the severity color tinted toward white.
	var sprite_tint := Color(min(2.5, tint.r * 1.0), tint.g * 0.7 + 0.2, tint.b * 0.7 + 0.2, 1.0)
	_windup_tween = sprite.create_tween().set_parallel(true)
	_windup_tween.tween_property(sprite, "scale", squash, windup * 0.75)
	_windup_tween.tween_property(sprite, "modulate", sprite_tint, windup * 0.6)
	_windup_tween.tween_property(sprite, "position", back_dir * lean_dist, windup * 0.8)
	# Floor telegraph. Slam pattern uses a radial circle; others use the
	# directional arc.
	if is_instance_valid(target):
		if _get_attack_pattern() == &"slam":
			_spawn_slam_telegraph()
		else:
			_spawn_telegraph_arc(target.global_position)

	# Phase 5.1 — telegraph audio cue. Heavy/boss attacks get a low
	# warning sound so the player notices even if they're not looking.
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		var cost: int = _get_token_cost()
		if is_mini_boss:
			AudioManager.play_sfx("charge_release", -6.0)
		elif cost >= 3:
			AudioManager.play_sfx("crit_hit", -10.0)
		elif cost == 2:
			AudioManager.play_sfx("hit_impact", -16.0)

	# Phase 5.1 — schedule apex flash just before strike lands. The flash
	# is a brief expanding ring at the enemy's position that peaks right
	# before the strike resolves, giving a visible "about to attack" beat.
	_schedule_telegraph_apex_flash()


# Striking phase: snap forward, normal colour. _end_attack_windup runs
# even if the strike misses (range check fails), so visuals always reset.
func _end_attack_windup() -> void:
	# v0.90.2 — pattern override expires with the swing it was rolled for.
	_pattern_override = &""
	if not is_instance_valid(sprite):
		return
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	var t := sprite.create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", _base_scale, 0.09)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.10)
	t.tween_property(sprite, "position", Vector2.ZERO, 0.09)
	_clear_telegraph_arc()
	_clear_slam_telegraph()


# Cancel: restore the sprite immediately (no strike happens).
func _cancel_attack_windup() -> void:
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	if is_instance_valid(sprite):
		sprite.scale = _base_scale
		sprite.modulate = Color.WHITE
		sprite.position = Vector2.ZERO
	_clear_telegraph_arc()
	_clear_slam_telegraph()


func _spawn_telegraph_arc(toward_pos: Vector2) -> void:
	var tex = SpriteGenerator.get_texture("slash_arc")
	if tex == null:
		tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		return
	_clear_telegraph_arc()
	_telegraph_arc = Sprite2D.new()
	_telegraph_arc.texture = tex
	_telegraph_arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var to_t: Vector2 = toward_pos - global_position
	if to_t.length() < 1.0:
		return
	_telegraph_arc.global_position = global_position + to_t.normalized() * (to_t.length() * 0.55)
	_telegraph_arc.rotation = to_t.angle()
	# Bar thickness scales with token cost (= danger). Heavy attacks look
	# WIDE and stay on screen longer.
	var thickness: float = 0.30 + 0.10 * float(_get_token_cost())
	_telegraph_arc.scale = Vector2(to_t.length() / 70.0, thickness)
	var sev: Color = _get_telegraph_severity_color()
	_telegraph_arc.modulate = sev
	_telegraph_arc.z_index = -1  # on the ground beneath sprites
	_get_world_node().add_child(_telegraph_arc)
	var t := _telegraph_arc.create_tween()
	# Telegraph alpha ramps to peak just before the strike lands.
	var windup: float = _get_windup_sec()
	t.tween_property(_telegraph_arc, "modulate:a", sev.a + 0.4, windup * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _clear_telegraph_arc() -> void:
	if _telegraph_arc != null and is_instance_valid(_telegraph_arc):
		_telegraph_arc.queue_free()
	_telegraph_arc = null


# Phase 5.1 — schedule a brief apex flash 70% through the wind-up so the
# player sees an unmissable "about to strike" cue. Different intensity
# per enemy tier.
func _schedule_telegraph_apex_flash() -> void:
	var windup: float = _get_windup_sec()
	var delay: float = windup * 0.7
	var owner_ref := self
	var sev: Color = _get_telegraph_severity_color()
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(owner_ref) or owner_ref._is_dead:
			return
		if not owner_ref._windup_started:
			return  # wind-up was cancelled mid-flight
		owner_ref._spawn_apex_flash(sev))


func _spawn_apex_flash(severity: Color) -> void:
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		return
	var flash := Sprite2D.new()
	flash.texture = tex
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.global_position = global_position
	flash.modulate = Color(severity.r * 1.4, severity.g * 1.4, severity.b * 1.4, 0.85)
	flash.scale = Vector2(0.4, 0.4)
	flash.z_index = 4
	_get_world_node().add_child(flash)
	var t: Tween = flash.create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(flash.queue_free)


# Phase 3.5 — open the vulnerability window. Heavier enemies stay open
# longer (they over-committed). Visual: warm yellow glow on the sprite
# + slight slump tilt that reads as "off-balance".
const _VULN_DURATION_LIGHT_MS: int = 350
const _VULN_DURATION_MEDIUM_MS: int = 550
const _VULN_DURATION_HEAVY_MS: int = 850
const _VULN_DURATION_BOSS_MS: int = 1200
func _trigger_vulnerability_window(_reason: StringName) -> void:
	if _is_dead:
		return
	var cost: int = _get_token_cost()
	var dur_ms: int = _VULN_DURATION_LIGHT_MS
	if is_mini_boss:
		dur_ms = _VULN_DURATION_BOSS_MS
	elif cost >= 3:
		dur_ms = _VULN_DURATION_HEAVY_MS
	elif cost == 2:
		dur_ms = _VULN_DURATION_MEDIUM_MS
	_vulnerable_until_usec = Time.get_ticks_usec() + dur_ms * 1000
	# Visual: warm yellow pulse on the sprite + small downward droop.
	if is_instance_valid(sprite):
		if _vulnerability_glow_tween != null and _vulnerability_glow_tween.is_valid():
			_vulnerability_glow_tween.kill()
		_vulnerability_glow_tween = sprite.create_tween().set_loops()
		_vulnerability_glow_tween.tween_property(sprite, "modulate", Color(1.4, 1.25, 0.55), 0.18).set_trans(Tween.TRANS_SINE)
		_vulnerability_glow_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE)
	# Schedule auto-clear so the glow stops even if the player never hits.
	var owner_ref := self
	get_tree().create_timer(float(dur_ms) / 1000.0).timeout.connect(func() -> void:
		if is_instance_valid(owner_ref) and not owner_ref._is_dead:
			owner_ref._clear_vulnerability_window())


# Phase 3.4 — TRIPLE STAB. Rat fires 3 quick stabs per attack cycle.
# Each stab does ~60% of normal damage, total ~180%. Between stabs the
# windup is very short so the player needs to dodge once but cleanly.
const _STAB_TOTAL: int = 3
const _STAB_DAMAGE_MULT: float = 0.60
const _STAB_GAP_SEC: float = 0.22
func _resolve_stab_strike() -> void:
	if _stabs_remaining <= 0:
		_stabs_remaining = _STAB_TOTAL
	# Deal damage.
	var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict(), _STAB_DAMAGE_MULT)
	target.take_damage(result["damage"], result["is_crit"])
	_do_attack_lunge(false)
	if randf() < 0.3:
		_try_rat_squeal()
	_stabs_remaining -= 1
	if _stabs_remaining > 0:
		# Schedule next stab quickly — shorter wind-up, no token re-reserve.
		_attack_timer = _STAB_GAP_SEC
	else:
		# Full combo recovery.
		_attack_timer = attack_cooldown * 1.4


# Phase 3.4 — CHARGE STRIKE. Wolf dashed during windup; resolve impact
# now. dist_sq is the current distance to player. If in melee range,
# bigger hit + knockback. If they got blocked by a wall (charge speed
# > 0 but distance never closed) → vulnerability window opens auto.
func _resolve_charge_strike(dist_sq: float) -> void:
	var hit_range_sq: float = stats.attack_range * stats.attack_range * 2.25
	if dist_sq <= hit_range_sq and is_instance_valid(target) and target.has_method("take_damage"):
		var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict(), _CHARGE_DAMAGE_MULT * _elite_damage_dealt_mult())
		target.take_damage(result["damage"], result["is_crit"])
		# Big knockback away from the wolf.
		if target.has_method("apply_knockback"):
			var kb_dir: Vector2 = (target.global_position - global_position)
			if kb_dir.length() > 0.01:
				target.apply_knockback(kb_dir.normalized(), _CHARGE_KNOCKBACK)
		_do_attack_lunge(true)
		_attack_timer = attack_cooldown * 1.6
	else:
		# WALL-CHARGE / MISS — wolf is stunned and vulnerable.
		_trigger_vulnerability_window(&"wall_charge")
		_attack_timer = attack_cooldown * 2.0
		# Visual: brief knock-back stumble.
		if is_instance_valid(sprite):
			var st := sprite.create_tween()
			st.tween_property(sprite, "position", Vector2(-6, 0), 0.08)
			st.tween_property(sprite, "position", Vector2.ZERO, 0.14)


# Phase 3.4 — afterimage during charge for motion-blur readability.
func _spawn_charge_afterimage() -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.4, 1.2, 1.5, 0.45)  # cyan ghost
	ghost.z_index = -1
	_get_world_node().add_child(ghost)
	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.22)
	t.tween_callback(ghost.queue_free)


# Phase 3.4 — SLAM. Troll/ogre fires a radial AoE that hits anyone in
# slam_radius regardless of facing. The telegraph is a big yellow circle
# on the ground around the enemy. Players must MOVE AWAY, not just dodge
# the direction. Heavy damage but slow recovery.
const _SLAM_RADIUS: float = 95.0
const _SLAM_DAMAGE_MULT: float = 1.5
func _resolve_slam_strike(_target_in_range: bool) -> void:
	_clear_slam_telegraph()
	# Visual: large white-orange impact ring.
	var world := _get_world_node()
	var ring_tex = SpriteGenerator.get_texture("ring_flash")
	if ring_tex == null:
		ring_tex = SpriteGenerator.get_texture("crystal_white")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.global_position = global_position
		ring.modulate = Color(1.7, 0.7, 0.2, 0.95)
		ring.scale = Vector2(0.6, 0.6)
		ring.z_index = -1
		world.add_child(ring)
		var t := ring.create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(_SLAM_RADIUS / 16.0, _SLAM_RADIUS / 16.0), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)
	# Damage anyone within radius.
	var slam_radius_sq: float = _SLAM_RADIUS * _SLAM_RADIUS
	if is_instance_valid(target) and target.has_method("take_damage"):
		if global_position.distance_squared_to(target.global_position) <= slam_radius_sq:
			var result = CombatManager.calculate_damage(get_stats_dict(), target.get_stats_dict(), _SLAM_DAMAGE_MULT)
			target.take_damage(result["damage"], result["is_crit"])
	_do_attack_lunge(true)
	_attack_timer = attack_cooldown * 1.5  # Longer recovery after slam.


func _spawn_slam_telegraph() -> void:
	_clear_slam_telegraph()
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	_slam_telegraph = Sprite2D.new()
	_slam_telegraph.texture = tex
	_slam_telegraph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slam_telegraph.global_position = global_position
	# Big circle indicating the slam radius.
	_slam_telegraph.scale = Vector2(_SLAM_RADIUS / 24.0, _SLAM_RADIUS / 24.0)
	_slam_telegraph.modulate = Color(1.6, 0.6, 0.15, 0.4)
	_slam_telegraph.z_index = -2
	_get_world_node().add_child(_slam_telegraph)
	var windup: float = _get_windup_sec()
	var t := _slam_telegraph.create_tween()
	t.tween_property(_slam_telegraph, "modulate:a", 0.85, windup * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _clear_slam_telegraph() -> void:
	if _slam_telegraph != null and is_instance_valid(_slam_telegraph):
		_slam_telegraph.queue_free()
	_slam_telegraph = null


func _clear_vulnerability_window() -> void:
	_vulnerable_until_usec = 0
	if _vulnerability_glow_tween != null and _vulnerability_glow_tween.is_valid():
		_vulnerability_glow_tween.kill()
		_vulnerability_glow_tween = null
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


# Plan corr. 10: after stagger, re-evaluate state from CURRENT conditions
# rather than blindly resuming ATTACK.
func _on_stagger_ended() -> void:
	if _is_dead:
		return
	if current_state == State.ATTACK:
		current_state = State.CHASE
		_attack_timer = max(_attack_timer, attack_cooldown * 0.4)


# Fires for every confirmed hit anywhere in the world. Cheap filter so
# unrelated hits don't trigger this enemy's flinch.
func _on_hit_resolved_for_reaction(result: Resource) -> void:
	if result == null or _is_dead:
		return
	var event = result.event
	if event == null:
		return
	if event.victim != self:
		return
	if _hit_reaction == null or not is_instance_valid(_hit_reaction):
		return
	var dir: Vector2 = event.direction
	# Phase 5.0 — store killing attack info for death animation routing.
	if bool(result.was_lethal):
		_killing_attack_id = StringName(event.attack_id)
		_killing_hit_direction = dir
	# force = 0 → component skips emitting knockback_requested (still
	# disconnected this stage anyway). Visual flinch + flash still runs.
	# Note (1B.6d): victim freeze is now dispatched by CombatManager from
	# result.final_feedback.victim_freeze_ms — no per-enemy freeze call here.
	# Phase 1B.6e: derive was_heavy from the chosen profile so stagger can
	# fire for HEAVY/FINISHER/CRIT/ELITE/BOSS-weight hits. Light/medium
	# attacks don't pass was_heavy=true, so heavy-only tiers (HEAVY, ELITE,
	# BOSS) won't stagger on a basic A/B swing.
	var was_heavy: bool = false
	var feedback = result.final_feedback
	if feedback != null:
		var w: int = int(feedback.get("weight"))
		# Weight enum: HEAVY=2, FINISHER=3, CRIT=4, ELITE_KILL=5, BOSS_EVENT=6
		was_heavy = w >= 2
	_hit_reaction.react(dir, 0.0, bool(result.was_crit), was_heavy)
