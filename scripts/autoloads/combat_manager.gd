extends Node

signal damage_dealt(target: Node, amount: int, is_crit: bool)

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
