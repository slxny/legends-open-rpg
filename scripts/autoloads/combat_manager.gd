extends Node

const HitEventCls := preload("res://scripts/combat/hit_event.gd")
const HitResultCls := preload("res://scripts/combat/hit_result.gd")
const AttackTimingsCls := preload("res://scripts/data/attack_timings.gd")
const AttackTimingDataCls := preload("res://scripts/data/attack_timing_data.gd")
const CombatFeedbackProfileCls := preload("res://scripts/data/combat_feedback_profile.gd")

# Phase 1B.6d feedback dispatch — profile per weight class. Cached so we
# don't allocate a Resource per hit.
var _profile_cache: Dictionary = {}

# CombatFeedbackProfile.Weight values inlined to avoid a class_name lookup.
const _W_LIGHT := 0
const _W_MEDIUM := 1
const _W_HEAVY := 2
const _W_FINISHER := 3
const _W_CRIT := 4
const _W_ELITE_KILL := 5
const _W_BOSS_EVENT := 6

# AttackTimingData.RhythmClass values inlined.
const _R_CORE_A := 0
const _R_CORE_B := 1
const _R_FINISHER_C := 2
const _R_EXTENSION_D := 3
const _R_EXTENSION_E := 4
const _R_BRANCH_SLAM := 5
const _R_BRANCH_UPPERCUT := 6
const _R_BRANCH_SPIN := 7
const _R_SPECIAL := 8
const _R_CHARGED := 9

signal damage_dealt(target: Node, amount: int, is_crit: bool)

## Emitted after every typed hit resolves. Phase 1B feedback systems
## (hit-stop, camera shake, audio, VFX, enemy reaction) subscribe here.
## Unused in Phase 1A — no subscribers yet.
signal hit_resolved(result: Resource)

func calculate_damage(attacker_stats: Dictionary, defender_stats: Dictionary, ability_multiplier: float = 1.0) -> Dictionary:
	var base_attack = attacker_stats.get("attack_damage", 10)
	var stat_bonus = 0.0

	# Stat bonus depends on attacker's primary stat
	if attacker_stats.has("primary_stat"):
		match attacker_stats["primary_stat"]:
			"strength":
				stat_bonus = attacker_stats.get("strength", 0) * 0.5
			"agility":
				stat_bonus = attacker_stats.get("agility", 0) * 0.5
			"intelligence":
				stat_bonus = attacker_stats.get("intelligence", 0) * 0.5

	var weapon_damage = attacker_stats.get("weapon_damage", 0)
	var target_armor = defender_stats.get("armor", 0)

	var raw_damage = (base_attack + stat_bonus + weapon_damage) * ability_multiplier - target_armor
	var final_damage = max(1, int(raw_damage))

	# Crit check
	var agi = attacker_stats.get("agility", 0)
	var crit_chance = min(agi / 200.0, 0.4)
	var is_crit = randf() < crit_chance

	if is_crit:
		final_damage = int(final_damage * 2.0)

	return {"damage": final_damage, "is_crit": is_crit}


## Typed resolution path. Phase 1A.1 introduces the API; legacy callers
## continue to call calculate_damage() unchanged. Later stages migrate
## individual attacks to build a HitEvent and call resolve_hit() instead.
##
## victim_takes_damage: when true (default), this also calls
## event.victim.take_damage(damage, is_crit) so a migrated caller does not
## need to repeat that step. When false, the caller applies damage itself
## (useful for AoE pre-checks or test harnesses).
func resolve_hit(event: Resource, attacker_stats: Dictionary, defender_stats: Dictionary, victim_takes_damage: bool = true) -> Resource:
	var result: Resource = HitResultCls.new()
	result.event = event

	if event == null:
		push_error("CombatManager.resolve_hit: null event")
		return result

	var ability_mult: float = float(event.get("ability_multiplier"))
	var calc := calculate_damage(attacker_stats, defender_stats, ability_mult)
	var damage: int = calc["damage"]
	var rolled_crit: bool = calc["is_crit"]
	var forced_crit: bool = bool(event.get("force_crit"))
	var is_crit: bool = rolled_crit or forced_crit

	if forced_crit and not rolled_crit:
		damage = int(damage * 2.0)

	result.damage_dealt = damage
	result.was_crit = is_crit

	var victim: Node = event.get("victim") as Node
	if victim_takes_damage and is_instance_valid(victim) and victim.has_method("take_damage"):
		var stats_node = null
		if "stats" in victim:
			stats_node = victim.get("stats")
		var hp_before: int = -1
		if stats_node != null and "current_hp" in stats_node:
			hp_before = int(stats_node.get("current_hp"))
		victim.take_damage(damage, is_crit)
		if hp_before > 0 and stats_node != null and "current_hp" in stats_node:
			result.was_lethal = int(stats_node.get("current_hp")) <= 0

	# Phase 1B.6d: profile-driven feedback dispatch. Weight is derived from
	# the attack's rhythm class (lookup via AttackTimings.by_id) and crit
	# state. Finisher (C) gets its own stronger profile distinct from crit.
	var profile: Resource = _select_profile_for(event, result)
	result.final_feedback = profile

	# Phase 2.0: poise damage. Looked up from the attack's AttackTimingData;
	# crits multiply by 1.5; routed to the victim's PoiseComponent if it
	# has one. Heavy/finisher/crit hits count as "heavy" for boss tier
	# heavy_only gate.
	if is_instance_valid(event.victim):
		var timing: Resource = AttackTimingsCls.by_id(event.attack_id)
		if timing != null and int(timing.poise_damage) > 0:
			var poise_node = event.victim.get_node_or_null("PoiseComponent")
			if poise_node != null and poise_node.has_method("take_poise_damage"):
				var amt: float = float(timing.poise_damage) * (1.5 if is_crit else 1.0)
				var is_heavy: bool = int(profile.weight) >= 2  # HEAVY/FINISHER/CRIT/ELITE/BOSS
				poise_node.take_poise_damage(amt, is_heavy)

	emit_signal("hit_resolved", result)

	if profile != null and HitStopController != null:
		# Localized victim freeze.
		if is_instance_valid(event.victim) and int(profile.victim_freeze_ms) > 0:
			HitStopController.freeze_target(event.victim, int(profile.victim_freeze_ms), 1)  # VICTIM
		# Optional global dip — only crit/elite-kill/boss profiles have
		# dip_ms > 0. attack_id dedupe at the HitStop layer means a wide
		# attack hitting 5 enemies still fires ONE dip.
		if int(profile.dip_ms) > 0 and event.attack_id != &"":
			HitStopController.request_global_dip(float(profile.dip_scale), int(profile.dip_ms), int(profile.dip_priority), event.attack_id)

	return result


## Pick (or lazily build + cache) the feedback profile for this hit.
func _select_profile_for(event: Resource, result: Resource) -> Resource:
	var crit: bool = bool(result.was_crit)
	var weight: int = _weight_for(event.attack_id, crit)
	if not _profile_cache.has(weight):
		_profile_cache[weight] = CombatFeedbackProfileCls.new().apply_preset(weight)
	return _profile_cache[weight]


## Map (attack_id, was_crit) → CombatFeedbackProfile.Weight.
## Crit always wins over basic weights but loses to FINISHER on a C-finisher
## landing a crit (we still gate global dip via crit profile because that's
## the player-facing reward for landing crits).
func _weight_for(attack_id: StringName, is_crit: bool) -> int:
	# Crit takes precedence — it's what players notice as "big" feedback.
	if is_crit:
		return _W_CRIT
	if attack_id == &"":
		return _W_LIGHT
	var timing: Resource = AttackTimingsCls.by_id(attack_id)
	if timing == null:
		return _W_LIGHT
	match int(timing.rhythm_class):
		_R_CORE_A, _R_CORE_B:
			return _W_LIGHT
		_R_FINISHER_C:
			return _W_FINISHER
		_R_EXTENSION_D, _R_EXTENSION_E:
			return _W_HEAVY
		_R_BRANCH_SLAM, _R_BRANCH_UPPERCUT, _R_BRANCH_SPIN:
			return _W_HEAVY
		_R_SPECIAL, _R_CHARGED:
			return _W_HEAVY
	return _W_MEDIUM
