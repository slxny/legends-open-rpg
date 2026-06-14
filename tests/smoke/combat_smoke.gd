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
const AttackIntentCls := preload("res://scripts/combat/attack_intent.gd")
const AttackIntentResolverCls := preload("res://scripts/combat/attack_intent_resolver.gd")

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
	_test_intent_resolver()

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


func _test_intent_resolver() -> void:
	var Kind = AttackIntentCls.Kind
	var Branch = AttackIntentCls.BranchHint
	var WIN_USEC := AttackIntentResolverCls.TAP_RESOLVE_MS * 1000

	# 1. Single tap, horizontal direction, no movement → BASIC_SWING
	var r = AttackIntentResolverCls.new()
	var t := 1_000_000_000
	r.notify_attack_press(t, Vector2.RIGHT, false)
	_check("Resolver pending intent before window expires", r.tick(t + 50_000, Vector2.RIGHT, false) == null)
	var intent = r.tick(t + WIN_USEC + 1000, Vector2.RIGHT, false)
	_check("Resolver single tap classifies BASIC_SWING", intent != null and intent.kind == Kind.BASIC_SWING)

	# 2. Double tap while moving → POWER_STRIKE
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, true)
	r.notify_attack_press(t + 50_000, Vector2.RIGHT, true)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2.RIGHT, true)
	_check("Resolver double-tap moving = POWER_STRIKE", intent != null and intent.kind == Kind.POWER_STRIKE)

	# 3. Double tap stationary → BASIC_SWING (not power strike)
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	r.notify_attack_press(t + 50_000, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2.RIGHT, false)
	_check("Resolver double-tap stationary = BASIC_SWING", intent != null and intent.kind == Kind.BASIC_SWING)

	# 4. Triple tap → WHIRLWIND
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	r.notify_attack_press(t + 20_000, Vector2.RIGHT, false)
	r.notify_attack_press(t + 40_000, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2.RIGHT, false)
	_check("Resolver triple-tap = WHIRLWIND", intent != null and intent.kind == Kind.WHIRLWIND)

	# 5. Diagonal single tap → DASH_STRIKE
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2(1, 1).normalized(), true)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2(1, 1).normalized(), true)
	_check("Resolver diagonal single tap = DASH_STRIKE", intent != null and intent.kind == Kind.DASH_STRIKE)

	# 6. Charge held past threshold → CHARGED_SLASH on release
	r = AttackIntentResolverCls.new()
	r.notify_charge_press(t)
	r.notify_charge_release(t + 1_600_000)  # 1.6s > 1.5s threshold
	intent = r.tick(t + 1_700_000, Vector2.RIGHT, false)
	_check("Resolver charge release past threshold = CHARGED_SLASH", intent != null and intent.kind == Kind.CHARGED_SLASH)
	_check("Resolver CHARGED_SLASH carries duration_ms ~1600", intent != null and abs(intent.charge_duration_ms - 1600) < 50)

	# 7. Dodge priority over pending attack
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	r.notify_dodge_press()
	intent = r.tick(t + 1000, Vector2.RIGHT, false)
	_check("Resolver dodge fires before tap window closes", intent != null and intent.kind == Kind.DODGE)

	# 8. Branch hint: horizontal then down → OVERHEAD
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 1000, Vector2.RIGHT, false)
	r.notify_attack_press(t + WIN_USEC + 2000, Vector2.DOWN, false)
	intent = r.tick(t + 2 * WIN_USEC + 100_000, Vector2.DOWN, false)
	_check("Resolver horizontal->down hint = OVERHEAD", intent != null and intent.branch_hint == Branch.OVERHEAD)

	# 9. Branch hint: any → up → THRUST
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 1000, Vector2.RIGHT, false)
	r.notify_attack_press(t + WIN_USEC + 2000, Vector2.UP, false)
	intent = r.tick(t + 2 * WIN_USEC + 100_000, Vector2.UP, false)
	_check("Resolver any->up hint = THRUST", intent != null and intent.branch_hint == Branch.THRUST)

	# 10. Branch hint: any → diagonal-up → SPIN (diagonal beats up check)
	# Note: diagonal single tap maps to DASH_STRIKE, not BASIC_SWING.
	# So this checks classification ordering — diagonal goes to dash before branch_hint applies.
	r = AttackIntentResolverCls.new()
	r.notify_attack_press(t, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 1000, Vector2.RIGHT, false)
	r.notify_attack_press(t + WIN_USEC + 2000, Vector2(1, -1).normalized(), false)
	intent = r.tick(t + 2 * WIN_USEC + 100_000, Vector2(1, -1).normalized(), false)
	_check("Resolver diagonal beats branch_hint via DASH_STRIKE", intent != null and intent.kind == Kind.DASH_STRIKE)

	# 11. Ranged class: triple tap = ARROW_RAIN
	r = AttackIntentResolverCls.new()
	r.set_hero_class(AttackIntentResolverCls.HeroClass.RANGED)
	r.notify_attack_press(t, Vector2.RIGHT, false)
	r.notify_attack_press(t + 20_000, Vector2.RIGHT, false)
	r.notify_attack_press(t + 40_000, Vector2.RIGHT, false)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2.RIGHT, false)
	_check("Resolver ranged triple-tap = ARROW_RAIN", intent != null and intent.kind == Kind.ARROW_RAIN)

	# 12. Ranged class: 2 taps moving = PIERCING_SHOT
	r = AttackIntentResolverCls.new()
	r.set_hero_class(AttackIntentResolverCls.HeroClass.RANGED)
	r.notify_attack_press(t, Vector2.RIGHT, true)
	r.notify_attack_press(t + 30_000, Vector2.RIGHT, true)
	intent = r.tick(t + WIN_USEC + 100_000, Vector2.RIGHT, true)
	_check("Resolver ranged double-tap moving = PIERCING_SHOT", intent != null and intent.kind == Kind.PIERCING_SHOT)

	# 13. Charge below threshold falls through to tap classification (no charged_slash)
	r = AttackIntentResolverCls.new()
	r.notify_charge_press(t)
	r.notify_attack_press(t, Vector2.RIGHT, false)
	r.notify_charge_release(t + 800_000)  # 0.8s < 1.5s
	intent = r.tick(t + WIN_USEC + 1_000_000, Vector2.RIGHT, false)
	_check("Resolver sub-threshold release = BASIC_SWING (not CHARGED)", intent != null and intent.kind == Kind.BASIC_SWING)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("[combat_smoke] PASS: ", label)
	else:
		_errors.append(label)
