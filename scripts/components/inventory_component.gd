class_name InventoryComponent
extends Node

signal inventory_changed
signal equipment_changed

const MAX_BAG_SLOTS = 16
const MAX_CONSUMABLE_SLOTS = 3
const MAX_POTION_STACK = 99
const POTION_IDS: Array[String] = ["potion_small", "potion_medium", "potion_great"]

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

# Potion stack counts: [small, medium, great]
var potion_counts: Array[int] = [0, 0, 0]

var stats_component: StatsComponent

func _ready() -> void:
	pass

func setup(stats: StatsComponent) -> void:
	stats_component = stats

func add_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	# Potions go to their dedicated stack
	if item.get("slot") == ItemData.Slot.CONSUMABLE:
		var item_id = item.get("id", "")
		var potion_index = POTION_IDS.find(item_id)
		if potion_index >= 0:
			if potion_counts[potion_index] >= MAX_POTION_STACK:
				GameManager.game_message.emit("Potion stack full! (99)", Color(1.0, 0.8, 0.3))
				return false
			potion_counts[potion_index] += 1
			inventory_changed.emit()
			return true
		# Unknown consumable — fall through to bag
	# Non-consumable items go to bag
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

func use_consumable(index: int) -> void:
	if index < 0 or index >= MAX_CONSUMABLE_SLOTS:
		return
	if potion_counts[index] <= 0:
		GameManager.game_message.emit("No potions in slot %d" % (index + 1), Color(1.0, 0.8, 0.3))
		return
	if not stats_component:
		return
	if stats_component.current_hp >= stats_component.get_total_max_hp():
		GameManager.game_message.emit("Already at full health!", Color(0.8, 0.8, 0.4))
		return
	var potion_id = POTION_IDS[index]
	var potion_data = ItemData.get_item(potion_id)
	var heal_pct = potion_data.get("heal_percent", 0.33)
	var max_hp = stats_component.get_total_max_hp()
	var heal_amount = int(max_hp * heal_pct)
	stats_component.heal(heal_amount)
	potion_counts[index] -= 1
	AudioManager.play_sfx("potion_heal")
	GameManager.game_message.emit("Used %s (+%d HP)" % [potion_data.get("name", "Potion"), heal_amount], Color(0.5, 1.0, 0.5))
	inventory_changed.emit()

func equip_from_bag(bag_index: int) -> void:
	if bag_index < 0 or bag_index >= bag.size():
		return
	var item = bag[bag_index]
	var slot_name = _get_slot_name(item.get("slot", -1))
	if slot_name.is_empty():
		return
	# Check level requirement
	if stats_component and item.get("level_req", 1) > stats_component.level:
		GameManager.game_message.emit("Requires level %d to equip!" % item["level_req"], Color(1.0, 0.3, 0.3))
		return
	# Swap with current equipment
	var old_item = equipment[slot_name]
	equipment[slot_name] = item
	bag.remove_at(bag_index)
	if not old_item.is_empty():
		bag.append(old_item)
	_apply_equipment_stats()
	AudioManager.play_sfx("equip_" + slot_name)
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
