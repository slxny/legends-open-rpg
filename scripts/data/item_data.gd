class_name ItemData

enum Slot { WEAPON, ARMOR, HELM, BOOTS, RING, AMULET, CONSUMABLE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS = {
	Rarity.COMMON: Color(1, 1, 1),
	Rarity.UNCOMMON: Color(0.2, 0.9, 0.2),
	Rarity.RARE: Color(0.3, 0.5, 1.0),
	Rarity.EPIC: Color(0.7, 0.3, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.1),
}

const RARITY_NAMES = {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}

# Item template: {name, slot, rarity, level_req, buy_price, stats: {}, description}
const ITEMS = {
	# ==================== WEAPONS ====================
	"rusty_sword": {
		"name": "Rusty Sword", "slot": Slot.WEAPON, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 15,
		"stats": {"attack_damage": 3},
		"description": "A dull blade, but better than bare fists.",
	},
	"short_bow": {
		"name": "Short Bow", "slot": Slot.WEAPON, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 15,
		"stats": {"attack_damage": 2, "agility": 1},
		"description": "A simple hunting bow.",
	},
	"bone_dagger": {
		"name": "Bone Dagger", "slot": Slot.WEAPON, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 12,
		"stats": {"attack_damage": 2, "agility": 1},
		"description": "Carved from a beast's rib.",
	},
	"wooden_staff": {
		"name": "Wooden Staff", "slot": Slot.WEAPON, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 14,
		"stats": {"attack_damage": 2, "intelligence": 1},
		"description": "A sturdy branch shaped for casting.",
	},
	"iron_sword": {
		"name": "Iron Sword", "slot": Slot.WEAPON, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 50,
		"stats": {"attack_damage": 6, "strength": 1},
		"description": "A well-forged iron blade.",
	},
	"hunters_longbow": {
		"name": "Hunter's Longbow", "slot": Slot.WEAPON, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 50,
		"stats": {"attack_damage": 5, "agility": 2},
		"description": "A sturdy longbow favored by scouts.",
	},
	"battle_axe": {
		"name": "Battle Axe", "slot": Slot.WEAPON, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 55,
		"stats": {"attack_damage": 7, "strength": 1},
		"description": "Heavy-headed and brutal.",
	},
	"serrated_knife": {
		"name": "Serrated Knife", "slot": Slot.WEAPON, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 45,
		"stats": {"attack_damage": 4, "agility": 2},
		"description": "Jagged edges that tear flesh.",
	},
	"oak_staff": {
		"name": "Oak Staff", "slot": Slot.WEAPON, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 48,
		"stats": {"attack_damage": 4, "intelligence": 2},
		"description": "Hardened oak channels magic well.",
	},
	"steel_sword": {
		"name": "Steel Sword", "slot": Slot.WEAPON, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 120,
		"stats": {"attack_damage": 10, "strength": 2},
		"description": "Masterwork steel, razor-sharp.",
	},
	"venom_bow": {
		"name": "Venom Bow", "slot": Slot.WEAPON, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 110,
		"stats": {"attack_damage": 8, "agility": 3},
		"description": "Tips coated in spider venom.",
	},
	"shadow_dagger": {
		"name": "Shadow Dagger", "slot": Slot.WEAPON, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 115,
		"stats": {"attack_damage": 7, "agility": 3, "move_speed": 10},
		"description": "Whisper-thin blade that finds gaps.",
	},
	"warlords_mace": {
		"name": "Warlord's Mace", "slot": Slot.WEAPON, "rarity": Rarity.RARE,
		"level_req": 7, "buy_price": 160,
		"stats": {"attack_damage": 13, "strength": 3},
		"description": "Shatters shields and bones alike.",
	},
	"arcane_staff": {
		"name": "Arcane Staff", "slot": Slot.WEAPON, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 130,
		"stats": {"attack_damage": 6, "intelligence": 4, "max_mana": 20},
		"description": "Pulses with stored magical energy.",
	},
	"flamebrand": {
		"name": "Flamebrand", "slot": Slot.WEAPON, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 300,
		"stats": {"attack_damage": 16, "strength": 4, "max_hp": 20},
		"description": "The blade smolders with inner fire.",
	},
	"stormbringer": {
		"name": "Stormbringer", "slot": Slot.WEAPON, "rarity": Rarity.EPIC,
		"level_req": 10, "buy_price": 400,
		"stats": {"attack_damage": 20, "agility": 4, "intelligence": 3},
		"description": "Lightning arcs between its limbs.",
	},
	"doomhammer": {
		"name": "Doomhammer", "slot": Slot.WEAPON, "rarity": Rarity.LEGENDARY,
		"level_req": 12, "buy_price": 800,
		"stats": {"attack_damage": 28, "strength": 6, "max_hp": 30},
		"description": "The earth trembles at each swing.",
	},
	# Mini-boss exclusive weapons
	"ravagers_cleaver": {
		"name": "Ravager's Cleaver", "slot": Slot.WEAPON, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 350,
		"stats": {"attack_damage": 18, "strength": 5, "max_hp": 25},
		"description": "Crude but devastating. Torn from a Ravager's grip.",
	},
	"dread_edge": {
		"name": "Dread Edge", "slot": Slot.WEAPON, "rarity": Rarity.EPIC,
		"level_req": 14, "buy_price": 500,
		"stats": {"attack_damage": 24, "strength": 4, "agility": 4, "move_speed": 10},
		"description": "A cursed blade that hungers for battle.",
	},
	"drakes_fury": {
		"name": "Drake's Fury", "slot": Slot.WEAPON, "rarity": Rarity.LEGENDARY,
		"level_req": 20, "buy_price": 1200,
		"stats": {"attack_damage": 35, "agility": 6, "strength": 4, "max_hp": 40},
		"description": "Forged in dragonfire, sharp as a fang.",
	},
	"abyssal_scepter": {
		"name": "Abyssal Scepter", "slot": Slot.WEAPON, "rarity": Rarity.LEGENDARY,
		"level_req": 26, "buy_price": 1800,
		"stats": {"attack_damage": 42, "intelligence": 8, "strength": 6, "max_hp": 50, "max_mana": 40},
		"description": "Channels the void between worlds.",
	},

	# ==================== ARMOR ====================
	"cloth_tunic": {
		"name": "Cloth Tunic", "slot": Slot.ARMOR, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 10,
		"stats": {"armor": 1, "max_hp": 5},
		"description": "Basic cloth armor.",
	},
	"leather_vest": {
		"name": "Leather Vest", "slot": Slot.ARMOR, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 20,
		"stats": {"armor": 2, "max_hp": 10},
		"description": "Sturdy leather protection.",
	},
	"chainmail": {
		"name": "Chainmail", "slot": Slot.ARMOR, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 60,
		"stats": {"armor": 4, "max_hp": 15},
		"description": "Interlocking metal rings provide decent defense.",
	},
	"studded_armor": {
		"name": "Studded Armor", "slot": Slot.ARMOR, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 55,
		"stats": {"armor": 3, "max_hp": 20, "strength": 1},
		"description": "Leather reinforced with iron studs.",
	},
	"scale_mail": {
		"name": "Scale Mail", "slot": Slot.ARMOR, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 140,
		"stats": {"armor": 6, "max_hp": 25},
		"description": "Overlapping metal scales deflect blows.",
	},
	"plate_armor": {
		"name": "Plate Armor", "slot": Slot.ARMOR, "rarity": Rarity.RARE,
		"level_req": 7, "buy_price": 200,
		"stats": {"armor": 9, "max_hp": 30, "strength": 2},
		"description": "Full plate, forged for war.",
	},
	"shadow_cloak": {
		"name": "Shadow Cloak", "slot": Slot.ARMOR, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 350,
		"stats": {"armor": 5, "max_hp": 20, "agility": 4, "move_speed": 15},
		"description": "Woven from dark threads that bend light.",
	},
	"dragon_scale": {
		"name": "Dragon Scale Armor", "slot": Slot.ARMOR, "rarity": Rarity.LEGENDARY,
		"level_req": 12, "buy_price": 750,
		"stats": {"armor": 14, "max_hp": 50, "strength": 4},
		"description": "Scales of an ancient wyrm, nearly indestructible.",
	},
	# Mini-boss exclusive armor
	"ravager_hide": {
		"name": "Ravager Hide", "slot": Slot.ARMOR, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 380,
		"stats": {"armor": 8, "max_hp": 35, "strength": 3},
		"description": "Thick beast hide, still warm from the kill.",
	},
	"abyssal_plate": {
		"name": "Abyssal Plate", "slot": Slot.ARMOR, "rarity": Rarity.LEGENDARY,
		"level_req": 26, "buy_price": 1600,
		"stats": {"armor": 18, "max_hp": 70, "strength": 6, "agility": 3},
		"description": "Armor from beyond the veil, darker than shadow.",
	},

	# ==================== HELMS ====================
	"leather_cap": {
		"name": "Leather Cap", "slot": Slot.HELM, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 8,
		"stats": {"armor": 1},
		"description": "A simple leather cap.",
	},
	"iron_helm": {
		"name": "Iron Helm", "slot": Slot.HELM, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 35,
		"stats": {"armor": 2, "max_hp": 10},
		"description": "Heavy but protective.",
	},
	"war_helm": {
		"name": "War Helm", "slot": Slot.HELM, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 90,
		"stats": {"armor": 4, "max_hp": 15, "strength": 1},
		"description": "Battle-scarred and formidable.",
	},
	"hood_of_shadows": {
		"name": "Hood of Shadows", "slot": Slot.HELM, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 85,
		"stats": {"armor": 2, "agility": 3, "move_speed": 10},
		"description": "Hides the wearer in darkness.",
	},
	"crown_of_thorns": {
		"name": "Crown of Thorns", "slot": Slot.HELM, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 280,
		"stats": {"armor": 5, "max_hp": 25, "strength": 3, "intelligence": 2},
		"description": "Power demands sacrifice.",
	},
	# Mini-boss exclusive helm
	"abyssal_crown": {
		"name": "Abyssal Crown", "slot": Slot.HELM, "rarity": Rarity.LEGENDARY,
		"level_req": 26, "buy_price": 1400,
		"stats": {"armor": 8, "max_hp": 45, "strength": 5, "intelligence": 5, "agility": 3},
		"description": "The weight of the abyss presses down, yet empowers.",
	},

	# ==================== BOOTS ====================
	"worn_boots": {
		"name": "Worn Boots", "slot": Slot.BOOTS, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 8,
		"stats": {"move_speed": 10},
		"description": "Better than going barefoot.",
	},
	"swift_boots": {
		"name": "Swift Boots", "slot": Slot.BOOTS, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 40,
		"stats": {"move_speed": 20, "agility": 1},
		"description": "Light boots that quicken your step.",
	},
	"iron_greaves": {
		"name": "Iron Greaves", "slot": Slot.BOOTS, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 100,
		"stats": {"armor": 3, "move_speed": 15, "max_hp": 10},
		"description": "Armored boots that don't slow you down much.",
	},
	"windwalkers": {
		"name": "Windwalkers", "slot": Slot.BOOTS, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 260,
		"stats": {"move_speed": 35, "agility": 3},
		"description": "Your feet barely touch the ground.",
	},
	"shadowstep_boots": {
		"name": "Shadowstep Boots", "slot": Slot.BOOTS, "rarity": Rarity.LEGENDARY,
		"level_req": 10, "buy_price": 600,
		"stats": {"move_speed": 45, "agility": 5, "armor": 4},
		"description": "Move between shadows, faster than sight.",
	},

	# ==================== RINGS ====================
	"copper_ring": {
		"name": "Copper Ring", "slot": Slot.RING, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 12,
		"stats": {"strength": 1},
		"description": "A simple copper band.",
	},
	"silver_ring": {
		"name": "Silver Ring", "slot": Slot.RING, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 38,
		"stats": {"agility": 2},
		"description": "Polished silver catches the light.",
	},
	"ruby_ring": {
		"name": "Ruby Ring", "slot": Slot.RING, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 110,
		"stats": {"strength": 3, "attack_damage": 4},
		"description": "The ruby burns with inner fire.",
	},
	"emerald_ring": {
		"name": "Emerald Ring", "slot": Slot.RING, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 105,
		"stats": {"agility": 3, "max_hp": 15},
		"description": "Green as a forest canopy.",
	},
	"ring_of_power": {
		"name": "Ring of Power", "slot": Slot.RING, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 300,
		"stats": {"strength": 4, "attack_damage": 6, "max_hp": 20},
		"description": "Hums with barely contained force.",
	},
	"band_of_ancients": {
		"name": "Band of the Ancients", "slot": Slot.RING, "rarity": Rarity.LEGENDARY,
		"level_req": 12, "buy_price": 700,
		"stats": {"strength": 5, "agility": 5, "intelligence": 5, "max_hp": 30},
		"description": "Forged before memory, holds all power.",
	},
	# Mini-boss exclusive ring
	"infernal_signet": {
		"name": "Infernal Signet", "slot": Slot.RING, "rarity": Rarity.LEGENDARY,
		"level_req": 26, "buy_price": 1500,
		"stats": {"strength": 7, "agility": 5, "attack_damage": 10, "max_hp": 40},
		"description": "Burns the finger, empowers the fist.",
	},

	# ==================== AMULETS ====================
	"bone_amulet": {
		"name": "Bone Amulet", "slot": Slot.AMULET, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 10,
		"stats": {"max_hp": 8},
		"description": "Rattles faintly when danger is near.",
	},
	"jade_pendant": {
		"name": "Jade Pendant", "slot": Slot.AMULET, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 42,
		"stats": {"intelligence": 2, "max_mana": 15},
		"description": "Cool jade that focuses the mind.",
	},
	"wolf_fang_necklace": {
		"name": "Wolf Fang Necklace", "slot": Slot.AMULET, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 40,
		"stats": {"strength": 1, "agility": 1, "max_hp": 10},
		"description": "Fangs of a great wolf, strung on sinew.",
	},
	"sapphire_amulet": {
		"name": "Sapphire Amulet", "slot": Slot.AMULET, "rarity": Rarity.RARE,
		"level_req": 5, "buy_price": 120,
		"stats": {"intelligence": 3, "max_mana": 25, "max_hp": 10},
		"description": "Deep blue clarity enhances spellwork.",
	},
	"amulet_of_fury": {
		"name": "Amulet of Fury", "slot": Slot.AMULET, "rarity": Rarity.EPIC,
		"level_req": 8, "buy_price": 320,
		"stats": {"strength": 4, "attack_damage": 5, "agility": 2},
		"description": "Rage burns in its crimson core.",
	},
	"heart_of_the_world": {
		"name": "Heart of the World", "slot": Slot.AMULET, "rarity": Rarity.LEGENDARY,
		"level_req": 10, "buy_price": 650,
		"stats": {"max_hp": 50, "max_mana": 40, "armor": 5, "intelligence": 4},
		"description": "Beats with the pulse of the earth itself.",
	},

	# ==================== CONSUMABLES ====================
	"health_potion_small": {
		"name": "Small Health Potion", "slot": Slot.CONSUMABLE, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 10,
		"stats": {}, "effect": "heal", "heal_amount": 40,
		"description": "Restores 40 HP.",
	},
	"health_potion_medium": {
		"name": "Medium Health Potion", "slot": Slot.CONSUMABLE, "rarity": Rarity.COMMON,
		"level_req": 3, "buy_price": 25,
		"stats": {}, "effect": "heal", "heal_amount": 80,
		"description": "Restores 80 HP.",
	},
	"health_potion_large": {
		"name": "Large Health Potion", "slot": Slot.CONSUMABLE, "rarity": Rarity.UNCOMMON,
		"level_req": 5, "buy_price": 50,
		"stats": {}, "effect": "heal", "heal_amount": 150,
		"description": "Restores 150 HP.",
	},
	"mana_potion_small": {
		"name": "Small Mana Potion", "slot": Slot.CONSUMABLE, "rarity": Rarity.COMMON,
		"level_req": 1, "buy_price": 10,
		"stats": {}, "effect": "restore_mana", "mana_amount": 30,
		"description": "Restores 30 Mana.",
	},
	"mana_potion_medium": {
		"name": "Medium Mana Potion", "slot": Slot.CONSUMABLE, "rarity": Rarity.COMMON,
		"level_req": 3, "buy_price": 25,
		"stats": {}, "effect": "restore_mana", "mana_amount": 60,
		"description": "Restores 60 Mana.",
	},
	"elixir_of_might": {
		"name": "Elixir of Might", "slot": Slot.CONSUMABLE, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 35,
		"stats": {}, "effect": "buff_strength", "buff_amount": 5, "buff_duration": 30.0,
		"description": "+5 Strength for 30 seconds.",
	},
	"elixir_of_speed": {
		"name": "Elixir of Speed", "slot": Slot.CONSUMABLE, "rarity": Rarity.UNCOMMON,
		"level_req": 3, "buy_price": 35,
		"stats": {}, "effect": "buff_speed", "buff_amount": 30, "buff_duration": 30.0,
		"description": "+30 Move Speed for 30 seconds.",
	},
}

# ============================================================
# RANDOM AFFIX SYSTEM
# Dropped items roll bonus stats based on rarity.
# Higher rarity = more affixes with bigger rolls.
# ============================================================

# {stat_key: [min_value, max_value]} — ranges per affix
const AFFIX_POOL = {
	"attack_damage": [1, 8],
	"armor": [1, 5],
	"max_hp": [5, 40],
	"max_mana": [5, 25],
	"strength": [1, 4],
	"agility": [1, 4],
	"intelligence": [1, 4],
	"move_speed": [5, 20],
}

# Number of bonus affixes by rarity
const AFFIX_COUNT = {
	Rarity.COMMON: [0, 0],
	Rarity.UNCOMMON: [0, 1],
	Rarity.RARE: [1, 2],
	Rarity.EPIC: [2, 3],
	Rarity.LEGENDARY: [3, 4],
}

# Level scaling factor: affixes are stronger on higher-level items
static func _roll_affixes(item: Dictionary) -> void:
	var rarity = item.get("rarity", Rarity.COMMON)
	var counts = AFFIX_COUNT.get(rarity, [0, 0])
	var num_affixes = randi_range(counts[0], counts[1])
	if num_affixes <= 0:
		return

	var level = item.get("level_req", 1)
	# Scale factor: items at level 10 get ~2x the min affix rolls
	var level_scale = 1.0 + (level - 1) * 0.12

	var available_stats = AFFIX_POOL.keys().duplicate()
	# Don't re-roll stats the item already has (avoid confusion)
	# Instead, affixes stack on top of base stats
	available_stats.shuffle()

	var bonus_names: Array[String] = []
	for i in range(min(num_affixes, available_stats.size())):
		var stat_key: String = available_stats[i]
		var range_arr = AFFIX_POOL[stat_key]
		var base_min: float = range_arr[0] * level_scale
		var base_max: float = range_arr[1] * level_scale
		var value: int = int(randf_range(base_min, base_max))
		if value < 1:
			value = 1
		# Stack onto existing stats
		var current = item["stats"].get(stat_key, 0)
		item["stats"][stat_key] = current + value
		bonus_names.append("+%d %s" % [value, stat_key.replace("_", " ")])

	# Append affix summary to description
	if bonus_names.size() > 0:
		item["affix_text"] = ", ".join(bonus_names)
		item["description"] = item.get("description", "") + "\n" + item["affix_text"]
	# Increase sell value for affix items
	item["buy_price"] = int(item.get("buy_price", 10) * (1.0 + num_affixes * 0.3))

# Drop tables for creep camps
const DROP_TABLES = {
	"rat": {
		"drop_chance": 0.10,
		"items": ["health_potion_small", "bone_amulet"],
		"weights": [80, 20],
	},
	"goblin": {
		"drop_chance": 0.28,
		"items": ["rusty_sword", "cloth_tunic", "leather_cap", "copper_ring", "bone_amulet", "bone_dagger", "health_potion_small"],
		"weights": [12, 12, 12, 10, 8, 12, 34],
	},
	"wolf": {
		"drop_chance": 0.25,
		"items": ["leather_vest", "worn_boots", "swift_boots", "wolf_fang_necklace", "health_potion_small"],
		"weights": [22, 25, 12, 16, 25],
	},
	"bandit": {
		"drop_chance": 0.32,
		"items": ["iron_sword", "hunters_longbow", "chainmail", "swift_boots", "silver_ring", "serrated_knife", "health_potion_medium"],
		"weights": [12, 12, 12, 10, 10, 12, 32],
	},
	"skeleton": {
		"drop_chance": 0.30,
		"items": ["iron_helm", "battle_axe", "studded_armor", "bone_dagger", "bone_amulet", "health_potion_medium"],
		"weights": [15, 15, 15, 12, 13, 30],
	},
	"spider": {
		"drop_chance": 0.28,
		"items": ["shadow_dagger", "venom_bow", "swift_boots", "emerald_ring", "hood_of_shadows", "health_potion_medium"],
		"weights": [14, 14, 12, 14, 14, 32],
	},
	"troll": {
		"drop_chance": 0.35,
		"items": ["warlords_mace", "plate_armor", "war_helm", "iron_greaves", "ruby_ring", "health_potion_large"],
		"weights": [14, 14, 14, 12, 14, 32],
	},
	"dark_mage": {
		"drop_chance": 0.35,
		"items": ["arcane_staff", "sapphire_amulet", "jade_pendant", "shadow_cloak", "oak_staff", "mana_potion_medium"],
		"weights": [16, 16, 12, 14, 14, 28],
	},
	"ogre": {
		"drop_chance": 0.45,
		"items": ["flamebrand", "stormbringer", "crown_of_thorns", "ring_of_power", "amulet_of_fury", "windwalkers", "health_potion_large"],
		"weights": [12, 12, 12, 12, 12, 12, 28],
	},
	"ogre_boss": {
		"drop_chance": 0.70,
		"items": ["doomhammer", "dragon_scale", "shadowstep_boots", "band_of_ancients", "heart_of_the_world", "health_potion_large"],
		"weights": [15, 15, 14, 14, 14, 28],
	},
	# ---- Mini-boss drop tables (guaranteed drops, boss-exclusive loot) ----
	"mini_boss_ravager": {
		"drop_chance": 1.0,
		"items": ["ravagers_cleaver", "ravager_hide", "flamebrand", "crown_of_thorns", "ring_of_power", "windwalkers"],
		"weights": [22, 22, 16, 14, 14, 12],
	},
	"mini_boss_dread_knight": {
		"drop_chance": 1.0,
		"items": ["dread_edge", "shadow_cloak", "stormbringer", "amulet_of_fury", "shadowstep_boots", "doomhammer"],
		"weights": [25, 15, 15, 15, 15, 15],
	},
	"mini_boss_elder_drake": {
		"drop_chance": 1.0,
		"items": ["drakes_fury", "dragon_scale", "doomhammer", "band_of_ancients", "heart_of_the_world", "shadowstep_boots"],
		"weights": [25, 18, 15, 14, 14, 14],
	},
	"mini_boss_abyssal_lord": {
		"drop_chance": 1.0,
		"items": ["abyssal_scepter", "abyssal_plate", "abyssal_crown", "infernal_signet", "drakes_fury", "band_of_ancients"],
		"weights": [20, 18, 18, 18, 13, 13],
	},
}

static func get_item(item_id: String) -> Dictionary:
	var item = ITEMS.get(item_id, {}).duplicate(true)
	if item.size() > 0:
		item["id"] = item_id
	return item

static func get_sell_price(item_id: String) -> int:
	var item = ITEMS.get(item_id, {})
	return int(item.get("buy_price", 0) * 0.4)

static func roll_drop(drop_table_name: String) -> String:
	var table = DROP_TABLES.get(drop_table_name, {})
	if table.is_empty():
		return ""
	if randf() > table["drop_chance"]:
		return ""
	# Weighted random selection
	var items = table["items"]
	var weights = table["weights"]
	var total_weight = 0
	for w in weights:
		total_weight += w
	var roll = randi() % total_weight
	var cumulative = 0
	for i in range(items.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return items[i]
	return items[0]

## Roll a complete item with random affixes applied. Returns {} if no drop.
static func roll_item_drop(drop_table_name: String) -> Dictionary:
	var item_id = roll_drop(drop_table_name)
	if item_id.is_empty():
		return {}
	var item = get_item(item_id)
	if item.is_empty():
		return {}
	# Apply random affixes based on rarity
	_roll_affixes(item)
	return item
