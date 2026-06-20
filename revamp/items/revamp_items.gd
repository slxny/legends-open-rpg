extends RefCounted

## Tiny revamp-only item catalog. Items can carry `ability_mods` that change
## an ability's behavior — this is how the boss drop visibly changes gameplay.

const RevampItem := preload("res://revamp/items/revamp_item.gd")

const CATALOG := {
	"minor_voltrune": {
		"id": "minor_voltrune",
		"name": "Minor Voltrune",
		"rarity": 2,  # RARE
		"slot": "trinket",
		"stats": {"max_hp": 30},
		"ability_mods": {
			"bolt": {"pierce": 1},  # Bolts pierce 1 extra enemy
		},
		"description": "A small humming stone. Arcane Bolt pierces +1 enemy.",
		"flavor": "It tugs at the air around it, sharpening every projectile.",
	},
	"ember_circlet": {
		"id": "ember_circlet",
		"name": "Ember Circlet of the Storm",
		"rarity": 4,  # LEGENDARY
		"slot": "head",
		"stats": {"max_hp": 80},
		"ability_mods": {
			"burst": {"extra_wave": true},   # Storm Burst gains a 6-strike ring around player
			"step": {"damaging_trail": true, "distance_mult": 1.15},  # Aether Step leaves damage trail + longer
			"bolt": {"twin": true},          # Arcane Bolt fires a tri-shot spread
		},
		"description": "All three core abilities are transformed:\n• Storm Burst adds a 6-strike personal ring.\n• Aether Step leaves a damaging trail and reaches farther.\n• Arcane Bolt fans into a tri-shot.",
		"flavor": "The Ember Lord wore this to wake the storms beneath the world. Now it answers to a new hand.",
	},
}


static func get_item(item_id: String) -> Dictionary:
	return CATALOG.get(item_id, {})


static func make_item(item_id: String) -> RefCounted:
	var data: Dictionary = CATALOG.get(item_id, {})
	if data.is_empty():
		return null
	var r := RevampItem.new()
	r.id = String(data.get("id", item_id))
	r.display_name = String(data.get("name", item_id))
	r.rarity = int(data.get("rarity", 0))
	r.slot = String(data.get("slot", "trinket"))
	r.stats = (data.get("stats", {}) as Dictionary).duplicate(true)
	r.ability_mods = (data.get("ability_mods", {}) as Dictionary).duplicate(true)
	r.description = String(data.get("description", ""))
	r.flavor = String(data.get("flavor", ""))
	return r
