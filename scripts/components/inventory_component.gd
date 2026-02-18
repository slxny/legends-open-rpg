class_name InventoryComponent
extends Node

signal inventory_changed
signal equipment_changed

const MAX_BAG_SLOTS = 16
const MAX_CONSUMABLE_SLOTS = 4

# Equipment: slot_name -> item dict (or empty dict)
var equipment: Dictionary = {
	"weapon": {},
	"armor": {},
	"helm": {},
	"boots": {},
	"ring": {},
	"amulet": {},
}

# Bag: array of item dicts
var bag: Array[Dictionary] = []

# Consumable quick-slots
var consumables: Array[Dictionary] = []

var stats_component: StatsComponent

func _ready() -> void:
	# Initialize empty consumable slots
	for i in range(MAX_CONSUMABLE_SLOTS):
		consumables.append({})

func setup(stats: StatsComponent) -> void:
	stats_component = stats

func add_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	# Consumables go to consumable slots first
	if item.get("slot") == ItemData.Slot.CONSUMABLE:
		for i in range(consumables.size()):
			if consumables[i].is_empty():
				consumables[i] = item
				inventory_changed.emit()
				return true
	# Otherwise goes to bag
	if bag.size() < MAX_BAG_SLOTS:
		bag.append(item)
		inventory_changed.emit()
		return true
	return false  # Bag full

func remove_item_from_bag(index: int) -> Dictionary:
	if index < 0 or index >= bag.size():
		return {}
	var item = bag[index]
	bag.remove_at(index)
	inventory_changed.emit()
	return item

func remove_consumable(index: int) -> Dictionary:
	if index < 0 or index >= consumables.size():
		return {}
	var item = consumables[index]
	consumables[index] = {}
	inventory_changed.emit()
	return item

func equip_from_bag(bag_index: int) -> void:
	if bag_index < 0 or bag_index >= bag.size():
		return
	var item = bag[bag_index]
	var slot_name = _get_slot_name(item.get("slot", -1))
	if slot_name.is_empty():
		return
	# Check level requirement
	if stats_component and item.get("level_req", 1) > stats_component.level:
		return
	# Swap with current equipment
	var old_item = equipment[slot_name]
	equipment[slot_name] = item
	bag.remove_at(bag_index)
	if not old_item.is_empty():
		bag.append(old_item)
	_apply_equipment_stats()
	equipment_changed.emit()
	inventory_changed.emit()

func unequip(slot_name: String) -> void:
	if not equipment.has(slot_name):
		return
	var item = equipment[slot_name]
	if item.is_empty():
		return
	if bag.size() >= MAX_BAG_SLOTS:
		return  # Bag full
	bag.append(item)
	equipment[slot_name] = {}
	_apply_equipment_stats()
	equipment_changed.emit()
	inventory_changed.emit()

func use_consumable(index: int) -> void:
	if index < 0 or index >= consumables.size():
		return
	var item = consumables[index]
	if item.is_empty():
		return
	if not stats_component:
		return
	var effect = item.get("effect", "")
	match effect:
		"heal":
			stats_component.heal(item.get("heal_amount", 0))
		"restore_mana":
			stats_component.restore_mana(item.get("mana_amount", 0))
	consumables[index] = {}
	inventory_changed.emit()

func _apply_equipment_stats() -> void:
	if not stats_component:
		return
	# Reset bonuses
	stats_component.weapon_damage = 0
	stats_component.bonus_armor = 0
	stats_component.bonus_max_hp = 0
	stats_component.bonus_max_mana = 0
	stats_component.bonus_move_speed = 0.0
	stats_component.bonus_strength = 0
	stats_component.bonus_agility = 0
	stats_component.bonus_intelligence = 0
	# Sum from all equipment
	for slot_name in equipment:
		var item = equipment[slot_name]
		if item.is_empty():
			continue
		var stats = item.get("stats", {})
		stats_component.weapon_damage += stats.get("attack_damage", 0)
		stats_component.bonus_armor += stats.get("armor", 0)
		stats_component.bonus_max_hp += stats.get("max_hp", 0)
		stats_component.bonus_max_mana += stats.get("max_mana", 0)
		stats_component.bonus_move_speed += stats.get("move_speed", 0)
		stats_component.bonus_strength += stats.get("strength", 0)
		stats_component.bonus_agility += stats.get("agility", 0)
		stats_component.bonus_intelligence += stats.get("intelligence", 0)
	stats_component._emit_all()

func _get_slot_name(slot: int) -> String:
	match slot:
		ItemData.Slot.WEAPON: return "weapon"
		ItemData.Slot.ARMOR: return "armor"
		ItemData.Slot.HELM: return "helm"
		ItemData.Slot.BOOTS: return "boots"
		ItemData.Slot.RING: return "ring"
		ItemData.Slot.AMULET: return "amulet"
		_: return ""
