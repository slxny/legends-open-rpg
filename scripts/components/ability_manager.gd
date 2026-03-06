class_name AbilityManager
extends Node

signal ability_used(ability_index: int, ability_name: String)
signal ability_cooldown_updated(ability_index: int, remaining: float, total: float)

var stats_component: StatsComponent
var hero_class: String = ""
var abilities: Dictionary = {}

# Cooldown tracking
var cooldowns: Dictionary = {"ability_1": 0.0, "ability_2": 0.0}

# Buff tracking
var _active_buffs: Array[Dictionary] = []

func setup(stats: StatsComponent, hero_class_key: String) -> void:
	stats_component = stats
	hero_class = hero_class_key
	var data = HeroData.get_hero(hero_class_key)
	if data.has("abilities"):
		abilities = data["abilities"]

func _process(delta: float) -> void:
	var has_active_cooldowns := cooldowns["ability_1"] > 0 or cooldowns["ability_2"] > 0
	var has_active_buffs := _active_buffs.size() > 0

	# Early-out: nothing to tick
	if not has_active_cooldowns and not has_active_buffs:
		return

	# Tick cooldowns — only iterate keys with remaining time
	if has_active_cooldowns:
		for key in cooldowns:
			if cooldowns[key] > 0:
				cooldowns[key] = max(0, cooldowns[key] - delta)
				var total = 0.0
				if abilities.has(key):
					total = abilities[key].get("cooldown", 0)
				var idx = 0 if key == "ability_1" else 1
				ability_cooldown_updated.emit(idx, cooldowns[key], total)

	# Tick buffs
	if has_active_buffs:
		var expired: Array[int] = []
		for i in range(_active_buffs.size()):
			_active_buffs[i]["remaining"] -= delta
			if _active_buffs[i]["remaining"] <= 0:
				expired.append(i)
		# Remove expired buffs (reverse order)
		expired.reverse()
		for i in expired:
			_remove_buff(_active_buffs[i])
			_active_buffs.remove_at(i)

func can_use_ability(ability_key: String) -> bool:
	if not abilities.has(ability_key):
		return false
	if cooldowns.get(ability_key, 0) > 0:
		return false
	var mana_cost = abilities[ability_key].get("mana_cost", 0)
	if stats_component and stats_component.current_mana < mana_cost:
		return false
	return true

func use_ability(ability_key: String, user: Node2D) -> Dictionary:
	if not can_use_ability(ability_key):
		return {}
	var ability = abilities[ability_key]
	# Spend mana
	if stats_component:
		stats_component.use_mana(ability.get("mana_cost", 0))
	# Start cooldown
	cooldowns[ability_key] = ability.get("cooldown", 1.0)
	var idx = 0 if ability_key == "ability_1" else 1
	ability_used.emit(idx, ability.get("name", ""))

	# Return ability data so the player/entity can execute the effect
	return ability.duplicate(true)

func apply_buff(buff_type: String, value: float, duration: float) -> void:
	var buff = {"type": buff_type, "value": value, "remaining": duration}
	_active_buffs.append(buff)
	match buff_type:
		"armor":
			if stats_component:
				stats_component.temp_armor += int(value)
		"dodge":
			if stats_component:
				stats_component.temp_dodge += value

func _remove_buff(buff: Dictionary) -> void:
	match buff["type"]:
		"armor":
			if stats_component:
				stats_component.temp_armor -= int(buff["value"])
		"dodge":
			if stats_component:
				stats_component.temp_dodge -= buff["value"]

func get_ability_info(ability_key: String) -> Dictionary:
	return abilities.get(ability_key, {})
