class_name StatsComponent
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal mana_changed(current_mana: int, max_mana: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal leveled_up(new_level: int)
signal died

var hero_class: String = ""
var primary_stat: String = "strength"

# Core stats
var level: int = 1
var xp: int = 0
var skill_points: int = 0

var max_hp: int = 100
var current_hp: int = 100
var max_mana: int = 50
var current_mana: int = 50

var strength: int = 10
var agility: int = 10
var intelligence: int = 10
var armor: int = 0
var attack_damage: int = 10
var attack_range: float = 40.0
var attack_speed: float = 1.0
var move_speed: float = 150.0
var _armor_growth_accum: float = 0.0

# Equipment bonuses (added on top of base)
var weapon_damage: int = 0
var bonus_armor: int = 0
var bonus_max_hp: int = 0
var bonus_max_mana: int = 0
var bonus_move_speed: float = 0.0
var bonus_strength: int = 0
var bonus_agility: int = 0
var bonus_intelligence: int = 0

# Armory upgrade bonuses
var armory_weapon_bonus: int = 0
var armory_armor_bonus: int = 0
var armory_hp_bonus: int = 0

# Woodworking upgrade bonuses
var woodwork_attack_bonus: int = 0
var woodwork_armor_bonus: int = 0
var woodwork_hp_bonus: int = 0
var woodwork_xp_mult: float = 0.0  # Extra XP multiplier from watchtower

# Temporary buffs
var temp_armor: int = 0
var temp_dodge: float = 0.0

# Timed buff/debuff system — each entry: { "id": String, "stat": String, "amount": int/float, "time_left": float, "is_debuff": bool }
var _active_buffs: Array[Dictionary] = []
signal buff_applied(buff_name: String, is_debuff: bool, duration: float)
signal buff_expired(buff_name: String)

func initialize_from_hero(hero_class_key: String) -> void:
	hero_class = hero_class_key
	var data = HeroData.get_hero(hero_class_key)
	if data.is_empty():
		return
	primary_stat = data["primary_stat"]
	var base = data["base_stats"]
	max_hp = base["max_hp"]
	current_hp = max_hp
	max_mana = base["max_mana"]
	current_mana = max_mana
	strength = base["strength"]
	agility = base["agility"]
	intelligence = base["intelligence"]
	armor = base["armor"]
	attack_damage = base["attack_damage"]
	attack_range = base["attack_range"]
	attack_speed = base["attack_speed"]
	move_speed = base["move_speed"]
	_emit_all()

func get_total_armor() -> int:
	return armor + bonus_armor + temp_armor + armory_armor_bonus + woodwork_armor_bonus

func get_total_move_speed() -> float:
	return move_speed + bonus_move_speed

func get_total_max_hp() -> int:
	return max_hp + bonus_max_hp + armory_hp_bonus + woodwork_hp_bonus

func get_total_max_mana() -> int:
	return max_mana + bonus_max_mana

func get_stats_dict() -> Dictionary:
	return {
		"attack_damage": attack_damage + weapon_damage + armory_weapon_bonus + woodwork_attack_bonus,
		"weapon_damage": weapon_damage,
		"armor": get_total_armor(),
		"strength": strength + bonus_strength,
		"agility": agility + bonus_agility,
		"intelligence": intelligence + bonus_intelligence,
		"primary_stat": primary_stat,
		"dodge": temp_dodge,
	}

func take_damage(amount: int) -> void:
	# Beacon immunity — owner on heal beacon blocks all damage
	if owner and owner.get("is_on_heal_beacon"):
		return
	# Check dodge
	if temp_dodge > 0.0 and randf() < temp_dodge:
		# Dodged!
		return
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, get_total_max_hp())
	if current_hp <= 0:
		died.emit()

func heal(amount: int) -> bool:
	if current_hp >= get_total_max_hp():
		return false
	current_hp = min(get_total_max_hp(), current_hp + amount)
	hp_changed.emit(current_hp, get_total_max_hp())
	return true

func use_mana(amount: int) -> bool:
	# Beacon immunity — free mana while on heal beacon
	if owner and owner.get("is_on_heal_beacon"):
		return true  # Allow ability but don't spend mana
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, get_total_max_mana())
		return true
	return false

func restore_mana(amount: int) -> void:
	current_mana = min(get_total_max_mana(), current_mana + amount)
	mana_changed.emit(current_mana, get_total_max_mana())

func add_xp(amount: int) -> void:
	# Woodwork watchtower bonus: extra XP %
	var effective = amount
	if woodwork_xp_mult > 0.0:
		effective = int(amount * (1.0 + woodwork_xp_mult))
	xp += effective
	var xp_needed = get_xp_to_next_level()
	while xp >= xp_needed and level < 50:
		xp -= xp_needed
		_level_up()
		xp_needed = get_xp_to_next_level()
	xp_changed.emit(xp, get_xp_to_next_level())

func get_xp_to_next_level() -> int:
	# Exponential XP curve
	return int(50 * pow(level, 1.5))

func _level_up() -> void:
	var data = HeroData.get_hero(hero_class)
	if data.is_empty():
		return
	level += 1
	skill_points += 1
	var growth = data["growth_per_level"]
	max_hp += int(growth.get("max_hp", 0))
	max_mana += int(growth.get("max_mana", 0))
	strength += int(growth.get("strength", 0))
	agility += int(growth.get("agility", 0))
	intelligence += int(growth.get("intelligence", 0))
	_armor_growth_accum += growth.get("armor", 0.0)
	if _armor_growth_accum >= 1.0:
		var gain = int(_armor_growth_accum)
		armor += gain
		_armor_growth_accum -= gain
	attack_damage += int(growth.get("attack_damage", 0))
	# Heal to full on level up
	current_hp = get_total_max_hp()
	current_mana = get_total_max_mana()
	leveled_up.emit(level)
	_emit_all()

func _emit_all() -> void:
	hp_changed.emit(current_hp, get_total_max_hp())
	mana_changed.emit(current_mana, get_total_max_mana())
	xp_changed.emit(xp, get_xp_to_next_level())

# Natural regen (call from _process)
var _regen_timer: float = 0.0

func process_regen(delta: float) -> void:
	_regen_timer += delta
	if _regen_timer >= 1.0:
		_regen_timer -= 1.0
		# Mana regen: 2% + INT/15 per second
		var mana_regen = max(1, int(get_total_max_mana() * 0.02 + (intelligence + bonus_intelligence) / 15.0))
		if current_mana < get_total_max_mana():
			restore_mana(mana_regen)

	# Tick down active buffs/debuffs
	_process_buffs(delta)

func apply_timed_buff(buff_id: String, stat: String, amount, duration: float, is_debuff: bool = false) -> void:
	# Remove existing buff with same id (no stacking)
	remove_buff(buff_id)
	var buff = {
		"id": buff_id,
		"stat": stat,
		"amount": amount,
		"time_left": duration,
		"is_debuff": is_debuff,
	}
	_active_buffs.append(buff)
	_apply_buff_stat(stat, amount)
	buff_applied.emit(buff_id, is_debuff, duration)
	if is_debuff:
		AudioManager.play_sfx("debuff_apply")

func remove_buff(buff_id: String) -> void:
	for i in range(_active_buffs.size() - 1, -1, -1):
		if _active_buffs[i]["id"] == buff_id:
			_unapply_buff_stat(_active_buffs[i]["stat"], _active_buffs[i]["amount"])
			buff_expired.emit(_active_buffs[i]["id"])
			_active_buffs.remove_at(i)

func has_buff(buff_id: String) -> bool:
	for b in _active_buffs:
		if b["id"] == buff_id:
			return true
	return false

func get_active_buffs() -> Array[Dictionary]:
	return _active_buffs

func _process_buffs(delta: float) -> void:
	for i in range(_active_buffs.size() - 1, -1, -1):
		_active_buffs[i]["time_left"] -= delta
		if _active_buffs[i]["time_left"] <= 0.0:
			_unapply_buff_stat(_active_buffs[i]["stat"], _active_buffs[i]["amount"])
			buff_expired.emit(_active_buffs[i]["id"])
			_active_buffs.remove_at(i)

func _apply_buff_stat(stat: String, amount) -> void:
	match stat:
		"strength": bonus_strength += int(amount)
		"agility": bonus_agility += int(amount)
		"intelligence": bonus_intelligence += int(amount)
		"armor": temp_armor += int(amount)
		"max_hp": bonus_max_hp += int(amount)
		"max_mana": bonus_max_mana += int(amount)
		"move_speed": bonus_move_speed += float(amount)
		"attack_damage": weapon_damage += int(amount)
		"dodge": temp_dodge += float(amount)
	_emit_all()

func _unapply_buff_stat(stat: String, amount) -> void:
	match stat:
		"strength": bonus_strength -= int(amount)
		"agility": bonus_agility -= int(amount)
		"intelligence": bonus_intelligence -= int(amount)
		"armor": temp_armor -= int(amount)
		"max_hp": bonus_max_hp -= int(amount)
		"max_mana": bonus_max_mana -= int(amount)
		"move_speed": bonus_move_speed -= float(amount)
		"attack_damage": weapon_damage -= int(amount)
		"dodge": temp_dodge -= float(amount)
	_emit_all()
