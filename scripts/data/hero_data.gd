class_name HeroData

# Hero class definitions for Phase 1: Blade Knight and Shadow Ranger

const HEROES = {
	"blade_knight": {
		"name": "Blade Knight",
		"description": "A melee bruiser with high HP and devastating cleave attacks.",
		"primary_stat": "strength",
		"base_stats": {
			"max_hp": 120,
			"max_mana": 40,
			"strength": 12,
			"agility": 6,
			"intelligence": 4,
			"armor": 3,
			"attack_damage": 14,
			"attack_range": 40.0,
			"attack_speed": 1.0,  # attacks per second
			"move_speed": 150.0,
		},
		"growth_per_level": {
			"max_hp": 15,
			"max_mana": 4,
			"strength": 3,
			"agility": 1,
			"intelligence": 1,
			"armor": 0.5,
			"attack_damage": 2,
		},
		"abilities": {
			"ability_1": {
				"name": "Cleave",
				"description": "A wide melee swing that damages all enemies in front.",
				"cooldown": 4.0,
				"mana_cost": 15,
				"damage_multiplier": 1.8,
				"radius": 80.0,
				"arc_degrees": 120.0,
			},
			"ability_2": {
				"name": "Shield Wall",
				"description": "Raise your shield, gaining bonus armor for 5 seconds.",
				"cooldown": 12.0,
				"mana_cost": 20,
				"armor_bonus": 10,
				"duration": 5.0,
			},
		},
		"color": Color(0.2, 0.4, 0.9),  # Blue-ish knight
	},
	"shadow_ranger": {
		"name": "Shadow Ranger",
		"description": "A fast ranged DPS with deadly multi-shot and evasive maneuvers.",
		"primary_stat": "agility",
		"base_stats": {
			"max_hp": 80,
			"max_mana": 60,
			"strength": 5,
			"agility": 12,
			"intelligence": 6,
			"armor": 1,
			"attack_damage": 11,
			"attack_range": 200.0,
			"attack_speed": 1.4,
			"move_speed": 180.0,
		},
		"growth_per_level": {
			"max_hp": 8,
			"max_mana": 6,
			"strength": 1,
			"agility": 3,
			"intelligence": 1,
			"armor": 0.3,
			"attack_damage": 2,
		},
		"abilities": {
			"ability_1": {
				"name": "Multi-Shot",
				"description": "Fire 3 arrows in a spread, each dealing damage.",
				"cooldown": 5.0,
				"mana_cost": 20,
				"damage_multiplier": 0.8,
				"projectile_count": 3,
				"spread_degrees": 30.0,
				"projectile_speed": 400.0,
				"projectile_range": 300.0,
			},
			"ability_2": {
				"name": "Evasion",
				"description": "Enter a state of heightened reflexes, gaining dodge chance for 4 seconds.",
				"cooldown": 14.0,
				"mana_cost": 25,
				"dodge_bonus": 0.4,
				"duration": 4.0,
			},
		},
		"color": Color(0.2, 0.7, 0.3),  # Green ranger
	},
}

static func get_hero(hero_class: String) -> Dictionary:
	return HEROES.get(hero_class, {})

static func get_all_hero_keys() -> Array:
	return HEROES.keys()
