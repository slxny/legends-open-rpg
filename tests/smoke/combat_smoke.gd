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
const InputBufferCls := preload("res://scripts/combat/input_buffer.gd")

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

	_test_input_buffer()

	if _errors.is_empty():
		print("[combat_smoke] OK")
		get_tree().quit(0)
	else:
		for e in _errors:
			printerr("[combat_smoke] FAIL: ", e)
		get_tree().quit(1)


func _test_input_buffer() -> void:
	var buf = InputBufferCls.new()
	var now: int = 1_000_000_000  # arbitrary base in usec
	var rec_attack = buf.push(&"attack", now)
	_check("InputBuffer push records exist", buf.size() == 1)
	_check("InputBuffer peek returns the record", buf.peek(&"attack", now) == rec_attack)
	_check("InputBuffer take consumes the record", buf.take(&"attack", now) == rec_attack)
	_check("InputBuffer peek after consume returns null", buf.peek(&"attack", now) == null)
	_check("InputBuffer second consume returns false", not buf.consume(rec_attack, now))

	# TTL expiry — default attack TTL is 140 ms
	var rec_expire = buf.push(&"attack", now)
	var later: int = now + 200_000  # +200 ms in usec
	_check("InputBuffer record expires past TTL", rec_expire.is_expired(later))
	_check("InputBuffer peek skips expired record", buf.peek(&"attack", later) == null)

	# Generation increments
	var g1 = buf.push(&"dodge", now)
	var g2 = buf.push(&"dodge", now)
	_check("InputBuffer generation increments on re-press", g2.generation == g1.generation + 1)

	# Hold-indefinite (charge_press) does not expire
	var hold = buf.push(&"charge_press", now)
	var much_later: int = now + 10_000_000  # +10s
	_check("InputBuffer charge_press does not expire", not hold.is_expired(much_later))
	buf.release(&"charge_press")
	_check("InputBuffer release marks charge_press consumed", buf.peek(&"charge_press", much_later) == null)

	# Action-specific TTL respected
	var dir = buf.push(&"direction_intent", now)
	var dir_age = now + 170_000  # 170 ms < 180 ms default
	_check("InputBuffer direction_intent alive at 170ms", not dir.is_expired(dir_age))
	var dir_late = now + 190_000
	_check("InputBuffer direction_intent expired at 190ms", dir.is_expired(dir_late))

	# Clear drops everything
	buf.push(&"attack", now)
	buf.push(&"dodge", now)
	buf.clear()
	_check("InputBuffer clear empties records", buf.size() == 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("[combat_smoke] PASS: ", label)
	else:
		_errors.append(label)
