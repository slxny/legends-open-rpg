# Phase 1A.0 — Behavioral Characterization & Regression Checklist

**Stage:** 1A.0 (Phase 1A — Foundations)
**Goal:** Capture exact current combat behavior so every later stage can be re-checked against this baseline.
**Status:** No behavior change. Documentation only.
**Last run:** 2026-06-14 (initial authorship)

This document is **re-run at the end of every Phase 1 stage** to detect regressions.

---

## 1. Hero classes & input map

- **Melee class**: triggers swings A–E, POWER_STRIKE, WHIRLWIND, CHARGED_SLASH, DASH_STRIKE.
- **Ranged class**: triggers PIERCING_SHOT, ARROW_RAIN, SNIPER_SHOT, SHADOW_STEP (Shadow Ranger).
- **No dodge action exists today.** Phase 1C.2 introduces it.
- Active input actions (used by combat): `move_left`, `move_right`, `move_up`, `move_down`, `attack`. Potion slots: KEY_1/2/3 (not combat).

---

## 2. Player attack inventory (current ground truth)

For every attack, the columns below are the values to compare against after each stage.

| Attack | Entry fn (line) | Anim fn (line) | Tween total (s) | Damage callback @ progress | Move forward | Knockback force | Shake (hit / crit) | Mult | Audio | Cooldown |
|---|---|---|---|---|---|---|---|---|---|---|
| Swing A (h) | `_do_melee_attack` (2610) sw=0 | `_anim_swing_horizontal` (2650) side=+1 | ~0.31 | line 2667 ≈ 0.17 / 0.31 = **0.55** | sprite +10 / +12 | 40 | 1.5 / 1.5 | 1.0 | sword_swing | 0.5/atk_spd |
| Swing B (h back) | `_do_melee_attack` (2610) sw=1 | `_anim_swing_horizontal` (2650) side=-1 | ~0.31 | 2667 ≈ **0.55** | sprite +10 / +12 | 40 | 1.5 / 1.5 | 1.0 | sword_swing | 0.5/atk_spd |
| Swing C (overhead) | branch `_pick_combo_swing` → idx 2 | `_anim_overhead_chop` (2681) | ~0.33 | 2700 ≈ 0.19 / 0.33 = **0.58** | sprite +8 / +14 | 55 | 2.0 / 5.0 | 1.0 | sword_swing | 0.5/atk_spd |
| Swing D (thrust) | branch → idx 3 | `_anim_upward_thrust` (2714) | ~0.29 | 2732 ≈ 0.16 / 0.29 = **0.55** | sprite +10 +(0,-6) → +12 +(0,-8) | 30 | 1.5 / 5.0 | 1.0 | sword_swing | 0.5/atk_spd |
| Swing E (spin) | branch → idx 4 | `_anim_spin_slash` (2746) | ~0.40 | 2763 ≈ 0.24 / 0.40 = **0.60** | sprite +12 over 0.18 | 60 | 2.0 / 6.0 | 1.0 | sword_swing | 0.5/atk_spd |
| POWER_STRIKE | `_execute_power_strike` (1361) | inline (1394+) | ~0.25 + impact | 1431 (lunge cb) | body +80 (line 1416) | 120 | 5.0 / 10.0 | 1.5 | power_strike | 0.8/atk_spd |
| WHIRLWIND | `_execute_whirlwind` (1466) | inline (1477+) | ~0.50 | 1507 (mid-spin) | sprite +6 | 70 | 3.0 / 8.0 | 1.2 | whirlwind | 1.0/atk_spd |
| CHARGED_SLASH | `_execute_charged_slash` (1525) | inline (1565+) | ~0.04 + 0.15–0.40 dash + 0.18 recover | 1661 (post-dash impact) | body = `attack_range × 3.5` | 140 | 5.0 / 10.0 | 1.6 | dash_swoosh + charge_release | 0.8/atk_spd |
| DASH_STRIKE | `_execute_dash_strike` (1677) | inline (1708+) | ~0.37 | 1737 (post-dash impact) | body +60 (line 1722) | 75 | 2.0 / 6.0 | 1.3 | dash_swoosh | 0.6/atk_spd |
| Ranged (PIERCING etc.) | `_try_special_attack` (1345) | inline | varies | 1781, 1856, 1961, 2009 | varies | varies | 2–7 / 4–7 | 1.1–1.4 | varies | varies |

**Damage @ progress** is the legacy tween-callback firing point expressed as a fraction of total tween duration — Phase 1A.5 migrates each to `attack_progress` and adjusts so contact aligns with the visible weapon contact frame.

### Directional branch table (current)
- `[horizontal, down]` → idx 2 (C overhead)
- `[down, up]` → idx 3 (D thrust) — line 2602
- `[_, "diagonal"]` → idx 4 (E spin) — line 2587
- `[_, "up"]` → idx 3 (D thrust) — line 2590
- Vertical → horizontal transitions → idx 4 (E spin) — lines 2604–2605

After Phase 1A.6 (combo rhythm restructure):
- A → B → C remains the core. C is the finisher.
- D and E become optional extensions, gated by a longer input or explicit directional intent.
- The branch table above is preserved as the *directional-replacement* layer on top of rhythm class.

---

## 3. Player state flags inventory

Watch these after every stage. Any value left non-zero / `true` after combat ends is a regression.

| Flag | Type | Should be after combat ends |
|---|---|---|
| `_is_attack_animating` | bool | `false` |
| `_is_charging` | bool | `false` |
| `_charge_time` | float | `0.0` |
| `_is_paralyzed` | bool | `false` (after paralyze timer) |
| `_paralyze_timer` | float | `0.0` |
| `_slow_factor` | float | `1.0` |
| `_slow_timer` | float | `0.0` |
| `_is_bleeding` | bool | `false` after bleed |
| `_bleed_timer` | float | `0.0` |
| `_tap_count` | int | `0` after tap-resolve |
| `_tap_resolve_timer` | float | `0.0` |
| `_tap_resolved` | bool | `false` between attacks |
| `_combo_index` | int | resets to `0` after `COMBO_WINDOW` (1.8 s) |
| `_combo_timer` | float | grows then resets |
| `_attack_cooldown` | float | reaches `0.0` after attack |
| `_hit_freeze_active` | bool | `false` after freeze duration |
| `Engine.time_scale` | float | **always 1.0** at rest (Phase 1B onward enforces) |

---

## 4. Enemy reaction inventory (current ground truth)

| Behavior | Code | Notes |
|---|---|---|
| `take_damage(amount, is_crit)` | `enemy.gd:690` | Damage → HP bar update → damage number → flash → audio → death check → CHASE if mid-state |
| Hit flash | `_do_hit_flash` (1694) | Modulate `(1.5,1.5,1.5)` instant; 0.18 s back to base; squash 1.3/0.7 over 0.05+0.06+0.08 s |
| Knockback | `apply_knockback(dir, force)` (1689) | Sets `_knockback_velocity`; decays via velocity damp (~0.07 s effective) |
| State transition on hit | line 713–717 | If not IDLE/PATROL/RETURN, transitions to CHASE — **does not interrupt enemy attack** |
| Death | `_die` (719) | Disables collision, plays SFX, emits `died`, spawns drops, plays per-sprite death animation |
| Death stagger | line 743–753 | 0–100 ms inter-death stagger when concurrent kills |

**No flinch animation, no AI stagger, no directional recoil exists today.** Phase 1B.3 introduces all three via `HitReactionComponent`.

---

## 5. Camera shake current call sites

`_do_screen_shake(intensity)` at `player.gd:2896`, `SHAKE_DURATION = 0.11 s` (line 161).

Already characterized in §2 columns (Shake hit/crit). After Phase 1B.2 every value here is replaced by a `CombatFeedbackProfile.camera_trauma` lookup. The table above is the **baseline** to compare new values against — no swing should feel weaker than its baseline.

---

## 6. Time-scale baseline

`grep -rn "Engine\.time_scale" --include="*.gd" /Users/steve/Code/legends-open-rpg`

**Today: zero writers, zero readers.** This is the baseline. After Stage 1B.0:
- Only `scripts/autoloads/time_manager.gd` may write `Engine.time_scale`.
- The headless smoke (§9.3) enforces this every stage.

---

## 7. Signals expected by reset hookup

| Signal | Owner today | Action in Stage 1B.0 |
|---|---|---|
| `SceneTree.scene_changed` | engine | connect |
| `RespawnManager.player_died(player_id: int)` | `respawn_manager.gd:6` | connect |
| `GameManager.returning_to_menu` | **missing** | add + emit from menu-transition site |
| `SaveLoadManager.game_loaded` | `save_load_manager.gd:11` | connect |
| `SaveLoadManager.save_about_to_load` | **missing** | add + emit at top of load path |
| `SceneTree.tree_exiting` | engine | connect |

---

## 8. Manual regression checklist (run after every Phase 1 stage)

Print this as a small printable list. Each item should produce identical behavior to baseline unless the stage explicitly changed it.

### Smoke (run first)
1. Project launches without parser or runtime errors.
2. Player spawns at expected location after save load.
3. WASD / joystick / mouse move the player correctly.
4. Attack input fires Swing A on a single press.

### Combo core
5. Single tap → Swing A only.
6. Two taps while moving → POWER_STRIKE (melee) or PIERCING_SHOT (ranged).
7. Three taps → WHIRLWIND (melee) or ARROW_RAIN (ranged).
8. Holding attack ≥ 1.5 s with `_tap_resolved == true` → CHARGED_SLASH on release.
9. Diagonal direction + attack → DASH_STRIKE.
10. Continuous attack with held button performs A → B → C cycle and visually distinct swings.

### Directional branches
11. Holding `down` + attack chains into Swing C (overhead) per current branch table.
12. Vertical → horizontal direction change yields Swing E (spin).
13. After C, combo can end cleanly; D and E are reachable via additional input (post-1A.6: explicit input required, not auto).

### Timing
14. Damage lands on the visible weapon contact frame for every attack (post-1A.5).
15. Attack cooldown is proportional to the attack's recovery, not a hardcoded constant (post-1A.5).
16. `_combo_timer` resets to 0 after 1.8 s of no input; next attack starts at A.

### Status / state
17. After every combat exchange: every flag in §3 returns to its rest value.
18. After every combat exchange: `Engine.time_scale == 1.0`.
19. Paralyze, slow, bleed effects still apply and expire cleanly.
20. Player can move freely after the last attack and dodge completes.

### Enemies
21. Skeleton, rat, goblin, wolf, bandit, troll, ogre all take damage, hit-flash, die, drop loot.
22. Knockback respects walls (no enemies passing through geometry).
23. Death animations play to completion; concurrent kills stagger correctly.
24. Post-1B.3: hit reaction visually distinguishes light vs heavy vs crit; boss tier shows visual response only.
25. Post-1B.3: enemy re-evaluates AI state after stagger; does not blindly return to ATTACK.

### Feedback (post-1B)
26. Light / medium / heavy / finisher / crit hit-stops feel progressively heavier.
27. Crit / elite-kill / boss-event trigger brief global slowdown only.
28. Pause, scene change, save load, player death, quit-to-menu all reset `time_scale` to 1.0.
29. Camera never drifts after any combat sequence.
30. Accessibility scalars at 0.0 disable shake / hit-stop / dip without breaking other systems.

### Class coverage
31. Melee class combat path complete (all swings, all specials, charged slash).
32. Ranged class combat path complete (PIERCING / ARROW_RAIN / SNIPER / SHADOW_STEP) — Phase 1 must not regress ranged class behavior.

---

## 9. Headless verification (run after every stage)

### 9.1 Project-parse check
```bash
godot --headless --quit --path /Users/steve/Code/legends-open-rpg 2>&1 | tee /tmp/legends_parse.log
test $(grep -cE "SCRIPT ERROR|Parser Error|^ERROR" /tmp/legends_parse.log) -eq 0
```

### 9.2 Combat smoke test scene (added in Stage 1A.1 deliverable)
```bash
godot --headless --quit-after 600 --path /Users/steve/Code/legends-open-rpg \
  res://tests/smoke/combat_smoke.tscn 2>&1 | tee /tmp/legends_smoke.log
test $(grep -cE "SCRIPT ERROR|^ERROR|push_error" /tmp/legends_smoke.log) -eq 0
```

### 9.3 Time-scale ownership grep (active from Stage 1B.0 onward)
```bash
! grep -rn "Engine\.time_scale\s*=" /Users/steve/Code/legends-open-rpg \
  --include="*.gd" | grep -v "scripts/autoloads/time_manager.gd"
```

---

## 10. Files / signals to add in later stages (collected here for visibility)

- `GameManager.returning_to_menu` signal (Stage 1B.0).
- `SaveLoadManager.save_about_to_load` signal (Stage 1B.0).
- `dodge` input action in `project.godot` (Stage 1C.2).
- `tests/smoke/combat_smoke.tscn` + `.gd` (Stage 1A.1).
