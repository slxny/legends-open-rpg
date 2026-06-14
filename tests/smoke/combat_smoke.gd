extends Node

## Phase 1A.1 headless smoke. Run via:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless \
##     --path /Users/steve/Code/legends-open-rpg \
##     res://tests/smoke/combat_smoke.tscn
##
## Validates:
##   - Project parses and autoloads boot
##   - HitEvent / HitResult Resources instantiate
##   - CombatManager.calculate_damage still returns the legacy shape
##   - CombatManager.resolve_hit produces a populated HitResult
##   - Engine.time_scale is 1.0 throughout
##
## Grows with each later stage. Phase 1B adds time-scale ownership
## checks; Phase 1C adds scripted combat sequence.

const HitEventCls := preload("res://scripts/combat/hit_event.gd")
const HitResultCls := preload("res://scripts/combat/hit_result.gd")

var _errors: Array[String] = []

func _ready() -> void:
	_check("Engine.time_scale starts at 1.0", abs(Engine.time_scale - 1.0) < 0.0001)
	_check("CombatManager autoload reachable", get_node_or_null("/root/CombatManager") != null)

	# Legacy damage path
	var attacker := {
		"attack_damage": 20,
		"primary_stat": "strength",
		"strength": 10,
		"weapon_damage": 5,
		"agility": 0,
	}
	var defender := {"armor": 3}
	var legacy = CombatManager.calculate_damage(attacker, defender, 1.0)
	_check("Legacy calculate_damage returns Dictionary", legacy is Dictionary)
	_check("Legacy result has 'damage'", legacy.has("damage"))
	_check("Legacy result has 'is_crit'", legacy.has("is_crit"))
	_check("Legacy damage > 0", int(legacy.get("damage", 0)) > 0)

	# Typed path
	var event: Resource = HitEventCls.new()
	event.attacker = self
	event.victim = null  # no real victim — should still produce a result, no damage applied
	event.direction = Vector2.RIGHT
	event.weight = 0  # Weight.LIGHT
	event.ability_multiplier = 1.0
	event.attack_id = &"smoke_test"

	var result: Resource = CombatManager.resolve_hit(event, attacker, defender, false)
	_check("resolve_hit returns a Resource", result != null)
	_check("HitResult.event is the input event", result.event == event)
	_check("HitResult.damage_dealt > 0 when no victim damage applied", int(result.damage_dealt) > 0)

	# Force-crit path
	event.force_crit = true
	var crit_result: Resource = CombatManager.resolve_hit(event, attacker, defender, false)
	_check("force_crit produces was_crit=true", bool(crit_result.was_crit))
	_check("force_crit damage >= base damage", int(crit_result.damage_dealt) >= int(result.damage_dealt))

	_check("Engine.time_scale still 1.0 after resolves", abs(Engine.time_scale - 1.0) < 0.0001)

	if _errors.is_empty():
		print("[combat_smoke] OK")
		get_tree().quit(0)
	else:
		for e in _errors:
			printerr("[combat_smoke] FAIL: ", e)
		get_tree().quit(1)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("[combat_smoke] PASS: ", label)
	else:
		_errors.append(label)
