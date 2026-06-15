extends Node
class_name UpgradeManager

## Phase 6.2 — behavior-changing combat upgrades.
##
## Tracks the player's owned upgrade IDs. Auto-grants one random
## unowned upgrade per level-up. Persists via SaveLoadManager —
## see attack_upgrades field.
##
## Player code queries via has(&"upgrade_id") to branch attack behavior.
##
## Available upgrades (Phase 6.2 set):
##   slam_shockwave    — branch_slam fires an extra outer shockwave
##   spin_radius_boost — branch_spin/whirlwind radius +50%
##   charged_pierce    — charged_slash damage +30% + bigger arc
##   execution_lifted  — execution variant triggers at <=35% HP (was 25%)
##   dodge_afterimage  — dodge afterimages damage enemies on contact
##   crit_refund       — crit hits credit +5 momentum and reduce dodge cooldown
##   uppercut_bonus    — branch_uppercut deals +50% damage and double poise

signal upgrade_granted(upgrade_id: StringName)

const AVAILABLE_UPGRADES: Array[StringName] = [
	&"slam_shockwave",
	&"spin_radius_boost",
	&"charged_pierce",
	&"execution_lifted",
	&"dodge_afterimage",
	&"crit_refund",
	&"uppercut_bonus",
]

var _owned: Dictionary = {}  # StringName -> true


func has(upgrade_id: StringName) -> bool:
	return _owned.has(upgrade_id)


func owned_count() -> int:
	return _owned.size()


func owned_list() -> Array[String]:
	var out: Array[String] = []
	for id in _owned.keys():
		out.append(String(id))
	return out


func grant(upgrade_id: StringName) -> bool:
	if _owned.has(upgrade_id):
		return false
	_owned[upgrade_id] = true
	upgrade_granted.emit(upgrade_id)
	return true


# Pick a random unowned upgrade. Returns &"" if all already owned.
func grant_random_unowned() -> StringName:
	var pool: Array[StringName] = []
	for id in AVAILABLE_UPGRADES:
		if not _owned.has(id):
			pool.append(id)
	if pool.is_empty():
		return &""
	var chosen: StringName = pool[randi() % pool.size()]
	grant(chosen)
	return chosen


# Save/load support.
func to_save() -> Array[String]:
	return owned_list()


func from_save(arr: Array) -> void:
	_owned.clear()
	for v in arr:
		_owned[StringName(String(v))] = true


func clear_all() -> void:
	_owned.clear()


# Human-readable display name for a granted upgrade.
static func display_name(upgrade_id: StringName) -> String:
	match upgrade_id:
		&"slam_shockwave":
			return "Slam Shockwave"
		&"spin_radius_boost":
			return "Spin: Wider Radius"
		&"charged_pierce":
			return "Charged: Devastating Slash"
		&"execution_lifted":
			return "Execution: Death Sentence"
		&"dodge_afterimage":
			return "Dodge: Phantom Strike"
		&"crit_refund":
			return "Crit: Adrenaline Surge"
		&"uppercut_bonus":
			return "Uppercut: Skybreaker"
	return String(upgrade_id)
