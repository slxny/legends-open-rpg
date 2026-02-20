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
	# --- Weapons ---
	"rusty_sword": {
		"name": "Rusty Sword",
		"slot": Slot.WEAPON,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 15,
		"stats": {"attack_damage": 3},
		"description": "A dull blade, but better than bare fists.",
	},
	"short_bow": {
		"name": "Short Bow",
		"slot": Slot.WEAPON,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 15,
		"stats": {"attack_damage": 2, "agility": 1},
		"description": "A simple hunting bow.",
	},
	"iron_sword": {
		"name": "Iron Sword",
		"slot": Slot.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"level_req": 3,
		"buy_price": 50,
		"stats": {"attack_damage": 6, "strength": 1},
		"description": "A well-forged iron blade.",
	},
	"hunters_longbow": {
		"name": "Hunter's Longbow",
		"slot": Slot.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"level_req": 3,
		"buy_price": 50,
		"stats": {"attack_damage": 5, "agility": 2},
		"description": "A sturdy longbow favored by scouts.",
	},
	# --- Armor ---
	"cloth_tunic": {
		"name": "Cloth Tunic",
		"slot": Slot.ARMOR,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 10,
		"stats": {"armor": 1, "max_hp": 5},
		"description": "Basic cloth armor.",
	},
	"leather_vest": {
		"name": "Leather Vest",
		"slot": Slot.ARMOR,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 20,
		"stats": {"armor": 2, "max_hp": 10},
		"description": "Sturdy leather protection.",
	},
	"chainmail": {
		"name": "Chainmail",
		"slot": Slot.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"level_req": 3,
		"buy_price": 60,
		"stats": {"armor": 4, "max_hp": 15},
		"description": "Interlocking metal rings provide decent defense.",
	},
	# --- Helm ---
	"leather_cap": {
		"name": "Leather Cap",
		"slot": Slot.HELM,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 8,
		"stats": {"armor": 1},
		"description": "A simple leather cap.",
	},
	# --- Boots ---
	"worn_boots": {
		"name": "Worn Boots",
		"slot": Slot.BOOTS,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 8,
		"stats": {"move_speed": 10},
		"description": "Better than going barefoot.",
	},
	"swift_boots": {
		"name": "Swift Boots",
		"slot": Slot.BOOTS,
		"rarity": Rarity.UNCOMMON,
		"level_req": 3,
		"buy_price": 40,
		"stats": {"move_speed": 20, "agility": 1},
		"description": "Light boots that quicken your step.",
	},
	# --- Ring ---
	"copper_ring": {
		"name": "Copper Ring",
		"slot": Slot.RING,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 12,
		"stats": {"strength": 1},
		"description": "A simple copper band.",
	},
	# --- Consumables ---
	"health_potion_small": {
		"name": "Small Health Potion",
		"slot": Slot.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 10,
		"stats": {},
		"effect": "heal",
		"heal_amount": 40,
		"description": "Restores 40 HP.",
	},
	"health_potion_medium": {
		"name": "Medium Health Potion",
		"slot": Slot.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"level_req": 3,
		"buy_price": 25,
		"stats": {},
		"effect": "heal",
		"heal_amount": 80,
		"description": "Restores 80 HP.",
	},
	"mana_potion_small": {
		"name": "Small Mana Potion",
		"slot": Slot.CONSUMABLE,
		"rarity": Rarity.COMMON,
		"level_req": 1,
		"buy_price": 10,
		"stats": {},
		"effect": "restore_mana",
		"mana_amount": 30,
		"description": "Restores 30 Mana.",
	},
}

# Drop tables for creep camps
const DROP_TABLES = {
	"rat": {
		"drop_chance": 0.08,
		"items": ["health_potion_small"],
		"weights": [100],
	},
	"goblin": {
		"drop_chance": 0.25,
		"items": ["rusty_sword", "cloth_tunic", "leather_cap", "copper_ring", "health_potion_small"],
		"weights": [15, 15, 15, 10, 45],
	},
	"wolf": {
		"drop_chance": 0.2,
		"items": ["leather_vest", "worn_boots", "swift_boots", "health_potion_small"],
		"weights": [25, 30, 10, 35],
	},
	"bandit": {
		"drop_chance": 0.3,
		"items": ["iron_sword", "hunters_longbow", "chainmail", "swift_boots", "health_potion_medium"],
		"weights": [15, 15, 15, 15, 40],
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
