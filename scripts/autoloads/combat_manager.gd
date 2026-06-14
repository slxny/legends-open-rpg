extends Node

const HitEventCls := preload("res://scripts/combat/hit_event.gd")
const HitResultCls := preload("res://scripts/combat/hit_result.gd")

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

	emit_signal("hit_resolved", result)
	return result
