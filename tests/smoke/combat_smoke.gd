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
const AttackClockCls := preload("res://scripts/combat/attack_clock.gd")
const AttackTimingDataCls := preload("res://scripts/data/attack_timing_data.gd")
const AttackTimingsCls := preload("res://scripts/data/attack_timings.gd")
const CameraShakeCls := preload("res://scripts/combat/camera_shake_2d.gd")
const HitReactionDataCls := preload("res://scripts/data/hit_reaction_data.gd")
const HitReactionComponentCls := preload("res://scripts/components/hit_reaction_component.gd")
const CombatFeedbackProfileCls := preload("res://scripts/data/combat_feedback_profile.gd")
const CombatAudioComponentCls := preload("res://scripts/components/combat_audio_component.gd")

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

	# Phase 1B.6c: crits now dispatch a 50ms global dip via HitStopController.
	# Reset and verify time_scale returns to 1.0 cleanly before subsequent tests.
	TimeManager.force_reset()
	_check("time_scale restorable after crit dip path", abs(Engine.time_scale - 1.0) < 0.0001)

	_test_input_buffer()
	_test_intent_resolver()
	_test_attack_timings()
	await _test_attack_clock()
	await _test_time_manager()
	await _test_hit_stop_controller()
	await _test_camera_shake()
	await _test_hit_reaction()
	_test_feedback_profiles()

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


func _test_attack_timings() -> void:
	# Every advertised attack has a timing entry, and windows are sane.
	var ids = AttackTimingsCls.all_ids()
	_check("AttackTimings exposes 16 attacks", ids.size() == 16)
	var ok_all := true
	for id in ids:
		var t = AttackTimingsCls.by_id(id)
		if t == null:
			_check("AttackTimings.by_id(" + str(id) + ") not null", false)
			ok_all = false
			continue
		var sane: bool = (
			t.duration_sec > 0.0
			and t.active_window_start >= 0.0 and t.active_window_end <= 1.0
			and t.active_window_start < t.active_window_end
			and t.contact_event >= t.active_window_start and t.contact_event <= t.active_window_end
			and t.combo_window_start < t.combo_window_end
			and t.recovery_end == 1.0
			and t.dodge_cancel_start <= t.recovery_end
			and t.movement_cancel_start <= t.recovery_end
		)
		if not sane:
			_check("Timing windows sane for " + str(id), false)
			ok_all = false
	_check("All 16 attack timings have sane windows", ok_all)

	# C is the finisher (per plan corr. 1).
	var c = AttackTimingsCls.swing_c()
	_check("swing_c is FINISHER_C", c.rhythm_class == AttackTimingDataCls.RhythmClass.FINISHER_C)
	# Wide/multi-hit flags set on the right specials.
	_check("spin is wide", AttackTimingsCls.swing_e().wide_attack)
	_check("whirlwind is wide+unstoppable", AttackTimingsCls.whirlwind().wide_attack and AttackTimingsCls.whirlwind().unstoppable)
	_check("dash_strike is unstoppable", AttackTimingsCls.dash_strike().unstoppable)
	_check("piercing_shot single-target", not AttackTimingsCls.piercing_shot().wide_attack)


func _test_attack_clock() -> void:
	# Live clock test inside a SceneTree — we drive a Tween created on
	# `self` and confirm progress + signals fire.
	var clock = AttackClockCls.new()
	var saw_finish := [false]
	clock.finished.connect(func(): saw_finish[0] = true)

	var tween := create_tween()
	clock.start(tween, 0.10, 1.0, &"swing_a")
	_check("AttackClock active after start", clock.active)
	_check("AttackClock starts at progress 0", clock.progress < 0.01)

	# Headless frame rate is slower than wall time — wait generously.
	await get_tree().create_timer(0.40).timeout
	_check("AttackClock reaches 1.0 after duration", clock.progress >= 0.999)
	_check("AttackClock fires finished()", saw_finish[0])
	_check("AttackClock inactive after finish", not clock.active)

	# Cancel mid-flight invalidates pending writes.
	clock = AttackClockCls.new()
	var saw_cancel := [false]
	clock.cancelled.connect(func(): saw_cancel[0] = true)
	var tween2 := create_tween()
	clock.start(tween2, 0.50, 1.0, &"swing_b")
	await get_tree().create_timer(0.10).timeout
	clock.cancel()
	_check("AttackClock cancelled emits signal", saw_cancel[0])
	_check("AttackClock inactive after cancel", not clock.active)
	var p_after: float = clock.progress
	await get_tree().create_timer(0.20).timeout
	_check("AttackClock progress frozen after cancel", abs(clock.progress - p_after) < 0.001)

	# is_in_window basic.
	clock = AttackClockCls.new()
	var tween3 := create_tween()
	clock.start(tween3, 0.50, 1.0, &"swing_c")
	_check("is_in_window false before window", not clock.is_in_window(0.5, 0.6))
	await get_tree().create_timer(0.40).timeout  # well into the tween
	_check("is_in_window true in window", clock.is_in_window(0.3, 0.95))
	clock.cancel()


func _test_time_manager() -> void:
	_check("TimeManager exposes returning_to_menu signal", GameManager.has_signal("returning_to_menu"))
	_check("TimeManager exposes save_about_to_load signal", SaveLoadManager.has_signal("save_about_to_load"))
	_check("TimeManager has request_time_scale method", TimeManager.has_method("request_time_scale"))
	_check("TimeManager has force_reset method", TimeManager.has_method("force_reset"))
	_check("Engine.time_scale starts at 1.0", abs(Engine.time_scale - 1.0) < 0.0001)
	_check("TimeManager.is_time_dilated false at rest", not TimeManager.is_time_dilated())

	# Request scale 1.0+ rejected (no-op)
	_check("request scale >= 1.0 rejected", not TimeManager.request_time_scale(1.0, 50, 2, &"test_noop"))
	_check("Engine.time_scale unchanged after no-op request", abs(Engine.time_scale - 1.0) < 0.0001)

	# Normal request accepted
	var accepted = TimeManager.request_time_scale(0.3, 50, 2, &"smoke_crit")
	_check("normal time-scale request accepted", accepted)
	_check("Engine.time_scale set to 0.3", abs(Engine.time_scale - 0.3) < 0.0001)
	_check("is_time_dilated true while active", TimeManager.is_time_dilated())

	# Lower-priority during active rejected
	_check("lower-priority during active rejected", not TimeManager.request_time_scale(0.2, 100, 1, &"smoke_weak"))
	_check("Engine.time_scale unchanged after rejection", abs(Engine.time_scale - 0.3) < 0.0001)

	# Equal-priority during active rejected
	_check("equal-priority during active rejected", not TimeManager.request_time_scale(0.1, 200, 2, &"smoke_equal"))

	# Higher-priority during active replaces
	_check("higher-priority replaces active", TimeManager.request_time_scale(0.25, 50, 4, &"smoke_boss"))
	_check("Engine.time_scale now 0.25", abs(Engine.time_scale - 0.25) < 0.0001)

	# Recovery on deadline expiry — wall-time, needs real-time wait
	await get_tree().create_timer(0.40).timeout
	_check("Engine.time_scale restored to 1.0 after deadline", abs(Engine.time_scale - 1.0) < 0.0001)
	_check("is_time_dilated false after recovery", not TimeManager.is_time_dilated())

	# Force reset works even when active
	TimeManager.request_time_scale(0.4, 1000, 2, &"smoke_force")
	_check("Engine.time_scale 0.4 mid-flight", abs(Engine.time_scale - 0.4) < 0.0001)
	TimeManager.force_reset()
	_check("force_reset restores time_scale", abs(Engine.time_scale - 1.0) < 0.0001)
	_check("force_reset clears active", not TimeManager.is_time_dilated())

	# Sole-owner grep guard: no other .gd file writes Engine.time_scale.
	# (Validated externally by the build script; here we just confirm the
	# guard intent in case anyone wires up a writer mid-development.)
	_check("time_scale back to 1.0 after all tests", abs(Engine.time_scale - 1.0) < 0.0001)


func _test_hit_stop_controller() -> void:
	_check("HitStopController autoload reachable", get_node_or_null("/root/HitStopController") != null)
	_check("HitStopController.is_frozen on null returns false", not HitStopController.is_frozen(null))
	_check("HitStopController.active_freeze_count starts 0", HitStopController.active_freeze_count() == 0)

	# Use this scene's own node as a dummy freeze target.
	var dummy := Node.new()
	dummy.name = "FreezeDummy"
	add_child(dummy)
	_check("freeze_target accepts node", HitStopController.freeze_target(dummy, 200, 1))
	_check("is_frozen true while in window", HitStopController.is_frozen(dummy))
	_check("active_freeze_count is 1", HitStopController.active_freeze_count() == 1)

	# A shorter re-freeze does NOT cut the existing deadline.
	HitStopController.freeze_target(dummy, 5, 1)
	_check("shorter re-freeze keeps longer deadline", HitStopController.is_frozen(dummy))
	_check("re-freeze count still 1", HitStopController.active_freeze_count() == 1)

	# Wait past expiry (headless time is slow — wait generously).
	await get_tree().create_timer(1.0).timeout
	_check("is_frozen false after deadline", not HitStopController.is_frozen(dummy))
	_check("active_freeze_count cleaned up to 0", HitStopController.active_freeze_count() == 0)

	# force_reset clears everything.
	HitStopController.freeze_target(dummy, 5000, 1)
	HitStopController.force_reset()
	_check("force_reset clears freezes", not HitStopController.is_frozen(dummy))
	_check("force_reset clears count", HitStopController.active_freeze_count() == 0)

	# Global dip routing — strongest-wins via attack_id dedupe.
	var ok_a = HitStopController.request_global_dip(0.3, 60, 2, &"smoke_attack_1")
	_check("request_global_dip accepted (priority 2)", ok_a)
	_check("Engine.time_scale 0.3 after dip request", abs(Engine.time_scale - 0.3) < 0.0001)
	# Same attack_id within window is deduped at HitStop layer.
	var ok_dup = HitStopController.request_global_dip(0.3, 60, 2, &"smoke_attack_1")
	_check("duplicate attack_id dedupe rejects second call", not ok_dup)
	# Different attack_id with HIGHER priority replaces.
	var ok_b = HitStopController.request_global_dip(0.2, 60, 4, &"smoke_attack_2")
	_check("higher-priority different attack_id accepted", ok_b)
	_check("Engine.time_scale 0.2 after replace", abs(Engine.time_scale - 0.2) < 0.0001)

	# Wait for recovery via TimeManager (wall clock).
	await get_tree().create_timer(0.40).timeout
	_check("time_scale restored to 1.0 after dip deadline", abs(Engine.time_scale - 1.0) < 0.0001)

	dummy.queue_free()


func _test_camera_shake() -> void:
	# Build a tiny camera + shake-component pair to exercise the
	# trauma-driven offset writeback.
	var cam := Camera2D.new()
	add_child(cam)
	var shake = CameraShakeCls.new()
	cam.add_child(shake)
	# Allow the engine to call _ready on the shake node.
	await get_tree().process_frame
	_check("CameraShake2D trauma starts at 0", shake.current_trauma() < 0.001)
	_check("camera offset starts at Vector2.ZERO", cam.offset == Vector2.ZERO)

	shake.add_trauma(0.6, Vector2.RIGHT)
	_check("CameraShake2D trauma after add ~ 0.6", abs(shake.current_trauma() - 0.6) < 0.01)
	# Allow process_mode=ALWAYS to apply offset.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("camera.offset moved off zero", cam.offset != Vector2.ZERO)

	# Negative impulse is a no-op.
	var t_before: float = shake.current_trauma()
	shake.add_trauma(-1.0, Vector2.ZERO)
	_check("negative trauma is no-op", abs(shake.current_trauma() - t_before) < 0.001)

	# Decay returns to zero — wait generously since headless ticks slow.
	await get_tree().create_timer(0.9).timeout
	_check("CameraShake2D trauma decays to 0", shake.current_trauma() < 0.001)
	_check("camera.offset returns to ZERO after decay", cam.offset == Vector2.ZERO)

	# force_reset is idempotent.
	shake.add_trauma(0.4, Vector2.UP)
	shake.force_reset()
	_check("force_reset clears trauma", shake.current_trauma() < 0.001)
	_check("force_reset zeros camera offset", cam.offset == Vector2.ZERO)

	# Accessibility scalar 0.0 disables visible shake but trauma still
	# applies — gameplay events stay decoupled.
	shake.intensity_scalar = 0.0
	shake.add_trauma(0.8, Vector2.RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("intensity_scalar=0 produces zero offset", cam.offset == Vector2.ZERO)
	shake.intensity_scalar = 1.0

	cam.queue_free()


func _test_hit_reaction() -> void:
	# Presets sanity — via instance.apply_preset(Tier) which works on
	# first headless boot. Tier enum values: LIGHT=0, MEDIUM=1, HEAVY=2,
	# ELITE=3, BOSS=4.
	var light = HitReactionDataCls.new().apply_preset(0)
	var boss = HitReactionDataCls.new().apply_preset(4)
	_check("light preset has knockback", light.knockback_scalar > 0.5)
	_check("boss preset immune to knockback", boss.knockback_scalar == 0.0)
	_check("boss preset immune to stagger", boss.stagger_resistance >= 1.0)
	var elite = HitReactionDataCls.new().apply_preset(3)
	_check("elite preset gated to heavy attacks", elite.stagger_only_heavy)

	# Build a sprite + component pair.
	var pivot := Sprite2D.new()
	pivot.name = "ReactPivot"
	add_child(pivot)
	var comp = HitReactionComponentCls.new()
	comp.reaction_pivot = pivot
	comp.profile = HitReactionDataCls.new().apply_preset(0)
	add_child(comp)
	await get_tree().process_frame

	var kb_fired := [false]
	var kb_force := [0.0]
	var stagger_fired := [false]
	var stagger_ended_fired := [false]
	comp.knockback_requested.connect(func(_dir: Vector2, force: float) -> void:
		kb_fired[0] = true
		kb_force[0] = force)
	comp.stagger_requested.connect(func(_ms: int) -> void: stagger_fired[0] = true)
	comp.stagger_ended.connect(func() -> void: stagger_ended_fired[0] = true)

	comp.react(Vector2.RIGHT, 40.0, false, false)
	_check("react fires knockback_requested", kb_fired[0])
	_check("knockback force = incoming * scalar (40 * 1.0)", abs(kb_force[0] - 40.0) < 0.01)
	_check("react fires stagger_requested (light tier)", stagger_fired[0])
	_check("is_staggered while in window", comp.is_staggered())

	# Repeated hit within min_interval → dampened (no second knockback / stagger).
	kb_fired[0] = false
	stagger_fired[0] = false
	comp.react(Vector2.RIGHT, 40.0, false, false)
	_check("dampened hit does NOT fire knockback again", not kb_fired[0])
	_check("dampened hit does NOT fire stagger again", not stagger_fired[0])

	# cancel_reaction clears stagger.
	comp.cancel_reaction()
	_check("cancel_reaction clears stagger", not comp.is_staggered())

	# Boss tier — no knockback, no stagger.
	kb_fired[0] = false
	stagger_fired[0] = false
	var boss_pivot := Sprite2D.new()
	add_child(boss_pivot)
	var boss_comp = HitReactionComponentCls.new()
	boss_comp.reaction_pivot = boss_pivot
	boss_comp.profile = HitReactionDataCls.new().apply_preset(4)
	add_child(boss_comp)
	await get_tree().process_frame
	boss_comp.knockback_requested.connect(func(_d, _f): kb_fired[0] = true)
	boss_comp.stagger_requested.connect(func(_ms): stagger_fired[0] = true)
	boss_comp.react(Vector2.RIGHT, 100.0, true, true)
	_check("boss tier emits no knockback", not kb_fired[0])
	_check("boss tier emits no stagger", not stagger_fired[0])

	# Original transform restored after visual tween — wait for full duration + slack.
	await get_tree().create_timer(0.50).timeout
	_check("pivot.scale returned to Vector2.ONE", pivot.scale.is_equal_approx(Vector2.ONE))
	_check("pivot.rotation returned to 0", abs(pivot.rotation) < 0.001)

	pivot.queue_free()
	comp.queue_free()
	boss_pivot.queue_free()
	boss_comp.queue_free()


func _test_feedback_profiles() -> void:
	# Weights: LIGHT=0, MEDIUM=1, HEAVY=2, FINISHER=3, CRIT=4, ELITE_KILL=5, BOSS_EVENT=6
	var light = CombatFeedbackProfileCls.new().apply_preset(0)
	var crit = CombatFeedbackProfileCls.new().apply_preset(4)
	var boss = CombatFeedbackProfileCls.new().apply_preset(6)
	_check("LIGHT profile no global dip", light.dip_ms == 0)
	_check("CRIT profile has global dip", crit.dip_ms > 0)
	_check("CRIT trauma > LIGHT trauma", crit.camera_trauma > light.camera_trauma)
	_check("BOSS_EVENT highest priority", boss.dip_priority > crit.dip_priority)
	_check("FINISHER no global dip", CombatFeedbackProfileCls.new().apply_preset(3).dip_ms == 0)
	_check("BOSS_EVENT longer victim freeze", boss.victim_freeze_ms > light.victim_freeze_ms)

	# CombatAudioComponent — verify it exists and can be instantiated.
	var audio = CombatAudioComponentCls.new()
	_check("CombatAudioComponent has play_swing", audio.has_method("play_swing"))
	_check("CombatAudioComponent has play_impact", audio.has_method("play_impact"))
	_check("CombatAudioComponent has play_kill", audio.has_method("play_kill"))
	# Call with null profile must be safe (no crash).
	audio.play_swing(null)
	audio.play_impact(null, &"body")
	audio.play_kill(null)
	_check("CombatAudio handles null profile without crash", true)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("[combat_smoke] PASS: ", label)
	else:
		_errors.append(label)
