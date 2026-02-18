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

# Equipment bonuses (added on top of base)
var weapon_damage: int = 0
var bonus_armor: int = 0
var bonus_max_hp: int = 0
var bonus_max_mana: int = 0
var bonus_move_speed: float = 0.0
var bonus_strength: int = 0
var bonus_agility: int = 0
var bonus_intelligence: int = 0

# Temporary buffs
var temp_armor: int = 0
var temp_dodge: float = 0.0

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
	return armor + bonus_armor + temp_armor

func get_total_move_speed() -> float:
	return move_speed + bonus_move_speed

func get_total_max_hp() -> int:
	return max_hp + bonus_max_hp

func get_total_max_mana() -> int:
	return max_mana + bonus_max_mana

func get_stats_dict() -> Dictionary:
	return {
		"attack_damage": attack_damage + weapon_damage,
		"weapon_damage": weapon_damage,
		"armor": get_total_armor(),
		"strength": strength + bonus_strength,
		"agility": agility + bonus_agility,
		"intelligence": intelligence + bonus_intelligence,
		"primary_stat": primary_stat,
		"dodge": temp_dodge,
	}

func take_damage(amount: int) -> void:
	# Check dodge
	if temp_dodge > 0.0 and randf() < temp_dodge:
		# Dodged!
		return
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, get_total_max_hp())
	if current_hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	current_hp = min(get_total_max_hp(), current_hp + amount)
	hp_changed.emit(current_hp, get_total_max_hp())

func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, get_total_max_mana())
		return true
	return false

func restore_mana(amount: int) -> void:
	current_mana = min(get_total_max_mana(), current_mana + amount)
	mana_changed.emit(current_mana, get_total_max_mana())

func add_xp(amount: int) -> void:
	xp += amount
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
	level += 1
	skill_points += 1
	var data = HeroData.get_hero(hero_class)
	if data.is_empty():
		return
	var growth = data["growth_per_level"]
	max_hp += int(growth.get("max_hp", 0))
	max_mana += int(growth.get("max_mana", 0))
	strength += int(growth.get("strength", 0))
	agility += int(growth.get("agility", 0))
	intelligence += int(growth.get("intelligence", 0))
	armor += int(growth.get("armor", 0))
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
		# HP regen: 1% + STR/20 per second
		var hp_regen = max(1, int(get_total_max_hp() * 0.01 + (strength + bonus_strength) / 20.0))
		if current_hp < get_total_max_hp():
			heal(hp_regen)
		# Mana regen: 2% + INT/15 per second
		var mana_regen = max(1, int(get_total_max_mana() * 0.02 + (intelligence + bonus_intelligence) / 15.0))
		if current_mana < get_total_max_mana():
			restore_mana(mana_regen)
