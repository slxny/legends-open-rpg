extends Resource
class_name RevampItem

## Self-contained item carrying stat bumps + ability mod dictionary.

const RARITY_COLORS := {
	0: Color(0.92, 0.92, 0.92),  # common
	1: Color(0.30, 0.95, 0.40),  # uncommon
	2: Color(0.40, 0.65, 1.0),   # rare
	3: Color(0.78, 0.40, 0.95),  # epic
	4: Color(1.0, 0.65, 0.18),   # legendary
}

const RARITY_NAMES := {
	0: "Common", 1: "Uncommon", 2: "Rare", 3: "Epic", 4: "Legendary",
}

@export var id: String = ""
@export var display_name: String = ""
@export var rarity: int = 0
@export var slot: String = "trinket"
@export var stats: Dictionary = {}
@export var ability_mods: Dictionary = {}
@export var description: String = ""
@export var flavor: String = ""


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "Unknown")


func tooltip_text() -> String:
	var lines: Array = []
	lines.append("%s" % display_name)
	lines.append("%s — %s" % [rarity_name(), slot.capitalize()])
	for key in stats.keys():
		lines.append("+%s %s" % [str(stats[key]), String(key).replace("_", " ")])
	lines.append("")
	lines.append(description)
	if flavor != "":
		lines.append("")
		lines.append("\"%s\"" % flavor)
	return "\n".join(lines)
