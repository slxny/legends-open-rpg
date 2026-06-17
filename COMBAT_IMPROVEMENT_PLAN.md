# Combat Improvement Plan

**Project:** Legends Open RPG (Godot 4.6, top-down action RPG)
**Goal:** Diablo-IV-grade game feel — responsive, fluid, powerful, readable — while preserving the game's identity and the existing 5-swing directional combat system. No copyrighted assets, abilities, characters, UI, or visual designs.
**Date:** 2026-06-14
**Authoring rule:** Each phase ships in independent commits, leaves the game fully playable, bumps `GAME_VERSION` in `scenes/ui/changelog_dialog.gd`, and ends in a summary before the next phase begins.

---

## 1. Current combat architecture (audit summary)

### Engine & autoloads
- Godot **4.6**, GL Compatibility renderer (`project.godot:19`).
- Autoloads: `SpriteGenerator`, `GameManager`, `CombatManager`, `DeathCounterSystem`, `TriggerEngine`, `TimeManager`, `EconomyManager`, `AlignmentManager`, `SettlementManager`, `BeaconManager`, `FogOfWarManager`, `RespawnManager`, `SaveLoadManager`, `AudioManager` (2,888 lines).

### Player (`scenes/player/player.gd`, 3,464 lines — god-script)
- All input, movement, attack animation, combo state, abilities, VFX spawning, UI updates live here.
- No formal state machine — state is implicit in flags (`_is_attack_animating`, `_is_charging`, `_combo_index`, `_combo_timer`, `_attack_cooldown`, status flags).
- **Five swing types** (A: left→right, B: right→left backhand, C: overhead chop, D: upward thrust, E: spin slash) selected by `_pick_combo_swing()` (line 2582).
- **Directional branches** at runtime: up→down = slam, down→up = uppercut, diagonal = spin, etc.
- **Tap-buffer specials** via `_tap_count` / `_tap_resolve_timer` (0.18 s window, line 155): 2 taps = power strike, 3 taps = whirlwind.
- **Charged slash** via `_is_charging` over `CHARGE_THRESHOLD = 1.5 s` (line 156).
- **Combo window** `COMBO_WINDOW = 1.8 s` (line 107).
- **Damage timing is tween-callback based** (e.g. `_anim_swing_horizontal()` at line 2650 fires damage at line 2667 via `tween.tween_callback()` ~0.06 s into a 0.17 s swing). No AnimationPlayer method tracks for contact. No frame-index contact data.
- Attack hitbox is a single `Area2D` `AttackArea` (radius = `stats.attack_range`); damage payload is `{damage, is_crit}`; `_enemies_in_range` list updated each frame.

### Abilities, weapons, stats
- `AbilityManager` (`scripts/components/ability_manager.gd`, 102 lines) tracks cooldowns; data from `HeroData.get_hero(hero_class)["abilities"]`.
- No `WeaponData` Resource — weapon damage is on `stats.weapon_damage` inside `StatsComponent` (267 lines).
- Single hero archetype per save; "classes" are dict differences in `HeroData`.

### Enemies (`scenes/enemies/enemy.gd`, 2,849 lines)
- Real state machine: `IDLE / PATROL / CHASE / ATTACK / RETURN` (line 10).
- Sleep when player > 800 px away.
- Attacks resolve instantly on cooldown expiry (line 626) — no enemy attack animation tied to damage.
- `apply_knockback(dir, force)` sets `_knockback_velocity` and decays it over ~0.07 s (line 343–346).
- Death pipeline supports per-sprite cinematics with 30–100 ms stagger between simultaneous deaths.

### Camera, audio, VFX, UI
- Camera2D is a child of player. **Procedural screen shake** via `_do_screen_shake(intensity)` with random offset decay (line 568–574). No trauma model.
- Audio centralized in `AudioManager` (2,888 lines). Per-enemy SFX cooldowns (e.g. rat squeal 0.8 s min interval). Pitch randomization is sparse.
- VFX is a pooled sprite system (max 40, line 130): slash arcs, impact sparks, flash rings, afterimage ghosts. Bleed uses CPUParticles2D.
- Damage numbers: pooled `Label` (player pool 30, enemy pool 30); yellow/gold for crit. Zoom-compensated HP bars.
- Hit flash: red-tinted modulate + squash on player damage (line 3107). Enemies have `_do_hit_flash()` but no flinch animation.

### Save system (`scripts/autoloads/save_load_manager.gd`, 317 lines)
- File: `user://savegame.json`.
- Persists stats/inventory/position/status/equipment/owned towns/explored tiles/death counters/upgrade levels.
- **Phase 1 must not change save format.**

### Coupling / risk hotspots
- `player.gd` 3,464 lines and `enemy.gd` 2,849 lines — both god-scripts.
- Damage fires on tween callbacks, not on the visible contact frame → hits feel disconnected from animation.
- Attack cooldown (`0.5 / attack_speed`) is decoupled from animation duration; high attack-speed lets the next input fire while the previous swing is still tweening.
- Status effects (`_is_paralyzed`, `_is_bleeding`, `_slow_factor`) are loose flags — no effect manager.
- Screen shake intensity is hard-coded per call site (basic 1.5–2.0, crit 4–6, specials 3–10). No graduation, no profile.

---

## 2. Why combat currently feels boring (concrete observations)

1. **Damage lands on a tween callback, not a contact frame** → visual swing and the moment a hit "registers" are decoupled.
2. **No enemy flinch / stagger animation** — enemies sprite-flash but keep attacking; hits feel ignored.
3. **No hit-stop on the victim side** — only the player gets sprite freeze on crit; defenders absorb hits without weight transfer.
4. **Knockback is instant velocity with no wind-up squash/stretch** — enemies slide, they don't get *hit*.
5. **Non-crit basic attacks have no juice** — no screen shake, no contact particle, no audio layering.
6. **Combo window resets are invisible** — the player has no idea when the chain ends.
7. **Attack cooldown unrelated to animation duration** — input can outrun the visual.
8. **Screen-shake values are flat & scattered**, with a large gap between subtle (~2) and screen-filling (~10).
9. **No input buffering across the combo** — inputs at the seam between swings are dropped.
10. **No combo identity per swing** — A/B/C/D/E differ in animation but produce identical impact feedback.

---

## 3. Design direction (decisions reached during brainstorming)

- **Keep the 5-swing directional combat system + tap-buffer specials + charged slash unchanged in behavior.** Polish, do not replace.
- **Targeted, staged extraction** of new components from `player.gd` / `enemy.gd` — never a big-bang rewrite. New systems live in dedicated components or autoloads; movement and physics stay in `player.gd`.
- **Hit-stop:** localized freeze (attacker animation + victim sprite/AI) for all hits; very brief, tightly guarded `Engine.time_scale` dip only for crit / finisher / elite-kill / boss-event. Profile values: time scale 0.25–0.4, real-time duration 40–70 ms, accessibility-scalable.
- **Damage timing:** migrate every player attack to data-driven contact windows. Prefer AnimationPlayer method-track events when available, normalized animation progress otherwise, absolute seconds only as a last fallback. The animation is the source of truth for when contact happens.
- **Enemy reactions:** one reusable `HitReactionComponent` driving procedural visual recoil + squash/stretch + knockback + AI stagger via `HitReactionData` Resource tiers (light/medium/heavy/elite/boss). Optional per-enemy custom animation hook (not authored in Phase 1).
- **Visual reaction touches a visual root only**, never the `CharacterBody2D`, `CollisionShape2D`, `NavigationAgent2D`, or hitboxes.
- **Three reaction layers are independent**: visual flinch, physical knockback, AI stagger. A boss can take visual recoil with no knockback and no stagger; a small enemy can take all three.
- **All tuning values live in Resources**, not magic numbers.

---

## 4. New systems & files

### New scripts
| File | Type | Purpose |
|---|---|---|
| `scenes/player/combat_controller.gd` | Node child of Player | Owns combo step, branching, charge resolution, cancellation rules; emits requests, never moves the body. |
| `scripts/components/input_buffer.gd` | RefCounted | Time-stamped buffer for attack / direction-intent / special / charged / dodge inputs. Single-consume tokens; per-action TTL. |
| `scripts/autoloads/hit_stop_controller.gd` | Autoload | Central hit-stop request API. Localized freeze + optional global dip. Real-time recovery; scene-change/pause/death reset. ID-token ownership. |
| `scenes/player/camera_shake_2d.gd` | Node on player Camera2D | Trauma model (`shake = trauma²`), directional impulse, max-clamp, accessibility scale, drift-free recovery. |
| `scripts/components/hit_reaction_component.gd` | Node child of enemy | Visual recoil + knockback request + AI stagger request driven by `HitReactionData`. Token-guarded tweens; repeated-hit dampening. |
| `scripts/components/dodge_controller.gd` *(if extraction is clean)* | Node child of Player | Owns dodge timing, i-frames, cancellation windows, perfect-dodge window (defined, unrewarded in Phase 1). `player.gd` still applies velocity. |

### New Resources
| File | Purpose |
|---|---|
| `scripts/data/attack_timing_data.gd` + `res://data/attacks/*.tres` | Per attack: animation name, contact event id OR normalized contact window, active hitbox window, combo window, dodge-cancel window, movement-cancel window, special-branch window, max-hits-per-target, hitbox profile id, movement-impulse timing, feedback profile id, debug flags. |
| `scripts/data/hit_reaction_data.gd` + `res://data/reactions/*.tres` | Tier profile: visual recoil magnitude, squash/stretch curve, rotation/tilt, knockback magnitude, knockback resistance/mass, stagger duration, stagger resistance, repeated-hit min interval, optional custom animation name. |
| `scripts/data/combat_feedback_profile.gd` + `res://data/feedback/*.tres` | One per attack weight class (light/medium/heavy/finisher/crit/elite-kill/boss): hit-stop ms (attacker + victim), camera trauma value, camera impulse, audio layer set, particle preset id, flash color/strength, knockback scalar, optional global-dip parameters. |

### Files to extend (no renames, no formatting churn)
- `scenes/player/player.gd` — delegate combat decisions to `CombatController`; preserve forwarding methods for AnimationPlayer method tracks.
- `scenes/enemies/enemy.gd` — child `HitReactionComponent`; `take_damage()` builds a hit event and hands it over.
- `scripts/autoloads/combat_manager.gd` — extend damage payload with attack weight + feedback profile id; dispatch to `HitStopController`; emit one `hit_confirmed` signal.
- `scripts/autoloads/audio_manager.gd` — add weight-aware layered playback (swing/impact/body/armor/magical/kill), restrained pitch variance, no-repeat last-N pool.
- `scenes/ui/changelog_dialog.gd` — bump `GAME_VERSION` every commit (project rule).

---

## 5. Phased roadmap (high-level — details locked phase-by-phase)

### Phase 0 — Audit & plan
- Audit complete. This document is the artifact. No behavior change.

### Phase 1 — Responsiveness and immediate hit feel
- Staged extraction (CombatController shell → InputBuffer → Contact-frame migration → Combo state → Dodge state → Hit-stop + camera shake → Enemy HitReactionComponent → Audio + VFX layering → Acceptance pass). See §6.

### Phase 2 — Combat rhythm, ability interactions, build depth *(later)*
- Resource generation/spending, cooldowns/charges, combo finishers, held-input attacks, ability chaining, status application & consumption, vulnerability/armor break, behavior-changing upgrades, reward perfect-dodge window from Phase 1.
- Builds on `AttackTimingData`, `CombatFeedbackProfile`, `HitReactionData`, plus new `AbilityData` / `StatusEffectData` / `ProjectileData` Resources only where the project lacks equivalents.

### Phase 3 — Enemy behavior & encounter design *(later)*
- Roles (basic/ranged/charger/tank/support/summoner/assassin/CC/elite), telegraphs, attack-cooldowns, group attack limits, flanking, repositioning, mixed encounters, ambushes, reinforcements, environmental hazards. Staggered AI updates, distance thresholds — never every-frame heavy logic.

### Phase 4 — Animation polish & procedural motion *(later)*
- AnimationTree transitions, attack/movement blending, directional attack anims, anticipation poses, additive recoil, procedural weapon trails, squash/stretch, footstep sync, animation-speed scaling. No skeletal features incompatible with current sprites.

### Phase 5 — VFX / shaders / audio / screen feedback *(later)*
- GPUParticles2D impacts, projectile trails, ground indicators, status visuals, dissolve shaders, scorch/ice/poison surfaces, audio variation pools, bus ducking, elite cues. Readability over particle quantity.

### Phase 6 — Damage presentation, UI, progression feedback *(later)*
- Floating-number grouping, crit presentation, vulnerability/armor-break indicators, boss stagger bars, cooldown clarity, behavior-changing upgrade previews.

### Phase 7 — Environment interaction *(later)*
- Breakable props, explosives, traps, knockback hazards, dust/debris, foliage, wall impacts, elemental surfaces. Pooling + lifetime caps.

### Phase 8 — Performance, accessibility, final tuning *(later)*
- Profiling sweep across AI / navigation / collision / particles / projectiles / damage numbers / audio / status; accessibility settings (shake/hit-stop/flash/particle density/aim assist/vibration/high-contrast telegraphs/reduced motion); centralized combat tuning Resources.

---

## 6. Phase 1 — staged execution plan

Each stage is a discrete commit. Each stage leaves the game playable. Each stage ends with a manual test pass.

### Stage 1.0 — Pre-flight & behavioral checklist *(no behavior change)*
- Map every combat variable, method, signal, timer, animation-track callback, NodePath, autoload dependency, and external caller of `player.gd` / `enemy.gd` combat APIs.
- Document 5-swing sequence, directional branch table, tap-buffer specials, charged slash, dodge cancel windows.
- Produce a behavioral checklist re-runnable after each stage (manual list of test scenarios).

### Stage 1.1 — CombatController shell *(delegates only)*
- Add empty `CombatController` child node in `player.tscn`.
- Add `request_attack(direction)`, `request_dodge(direction)`, `notify_anim_event(name, payload)` public API that **calls back into existing `player.gd` methods**. Behavior must be identical.

### Stage 1.2 — InputBuffer
- Replace `_tap_count`, `_tap_resolve_timer`, charge-start tracking with `InputBuffer` instance owned by `CombatController`.
- TTLs (initial defaults, all in `CombatFeedbackProfile`-adjacent constants):
  - Attack: **140 ms**
  - Directional intent: **180 ms**
  - Special tap-buffer: **180 ms** (matches existing `_tap_resolve_timer`)
  - Charged release: track press time, no TTL on release
  - Dodge: **120 ms**
- Token model: each buffered input has a generation id; consumed once. Controller, keyboard, mouse share the same buffer.
- Debug toggle prints active buffers.

### Stage 1.3 — Contact-frame migration
- Author one `AttackTimingData` per attack: A, B, C, D, E, slam, uppercut, spin, each tap-buffer special, charged slash.
- Contact source priority:
  1. `AnimationPlayer` method-track event named `contact_event` (preferred when an AnimationPlayer animation exists).
  2. Normalized progress (0.0–1.0) on the existing Tween — read via Tween's elapsed/duration.
  3. Absolute seconds only as last resort.
- Active window: `Area2D` hitbox is monitoring only between window start/end. Per-target hit-once enforced by a target-id set cleared on window end or cancel.
- Migration is **per attack**, atomic: legacy `tween_callback` damage disabled for that attack *in the same commit* as its new timing data lands. No double-fire window.
- Hit confirmation (not contact frame) triggers hit-stop / camera shake / audio impact layer / enemy reaction. Swing audio + weapon trail can still fire on contact whether the hit landed or not.

### Stage 1.4 — Move combo state into CombatController
- Migrate: combo index, combo timer, directional branch table, cancellation matrix, special-branch resolution, charge-vs-tap decision.
- `player.gd` still plays the animations. `CombatController` decides which one and when.
- Cancellation matrix is data-driven in `AttackTimingData`:
  - Movement-cancel after `recovery_start`.
  - Dodge-cancel from `dodge_cancel_start` (typically mid-recovery; some heavies don't allow it).
  - Special-branch from `special_branch_start` until `combo_window_end`.
  - Hit-react interrupts unless attack flagged `unstoppable`.

### Stage 1.5 — Dodge state migration
- New `DodgeController` (component on player) or `CombatController` sub-state. It owns:
  - Immediate response (consumes buffered input, even mid-recovery if dodge-cancel window allows).
  - i-frames (configurable duration, default 220 ms).
  - Accel/decel curve (`Curve` Resource).
  - Trail/afterimage via existing sprite VFX pool.
  - Perfect-dodge window defined in data, **detection only** (signal emitted, no reward yet) — Phase 2 will reward it.
- `player.gd` keeps `velocity` / `move_and_slide()` ownership; dodge controller writes a `dodge_velocity_request` that `player.gd` applies.

### Stage 1.6 — Hit-stop + camera shake
- `HitStopController` autoload:
  - **Localized API:** `freeze_attacker(node, ms)`, `freeze_victim(node, ms)` — pauses `AnimationPlayer.speed_scale` / Tween / AI for the given real-time ms, restored via generation-token guard.
  - **Global API (guarded):** `request_global_dip(profile)` — sets `Engine.time_scale` to 0.25–0.4 for 40–70 ms; uses a `Timer` with `process_mode = PROCESS_MODE_ALWAYS` and ignores incoming requests of equal or lesser strength while active. Stronger requests replace, never extend on weak hits.
  - **Safety:** force-reset on scene change (`SceneTree.tree_changed`), pause, player death, save load, error recovery.
  - **Accessibility:** intensity scalar 0.0–1.0; 0.0 disables global dip entirely.
  - **Multi-hit aggregation:** wide attacks select a single primary impact event for feedback; per-target damage still applies.
- `CameraShake2D` on player Camera2D:
  - Trauma model: `offset = max_offset * trauma² * noise`, trauma decays at configurable rate.
  - Directional impulse: pushes trauma vector slightly along the hit direction.
  - Hard max clamp on offset.
  - Accessibility scalar.
  - On scene change / death: trauma forced to 0.

### Stage 1.7 — Enemy HitReactionComponent
- Add `HitReactionComponent` as a child node on the base enemy scene.
- `enemy.gd.take_damage()` constructs a `HitEvent {direction, weight, profile_id, is_crit, attacker}` and hands it to the component. **Existing `take_damage` signature unchanged for external callers.**
- Component:
  - Selects `HitReactionData` by tier (light/medium/heavy/elite/boss) configured on the enemy.
  - **Visual layer:** squash/stretch + tiny rotation + modulate flash on a dedicated visual root (the existing main `Sprite2D` if present; otherwise wrap in a `Node2D` visual root introduced for this enemy).
  - **Physical layer:** delegates to `enemy.apply_knockback(dir, force * resistance_scalar)` — existing code is already collision-aware via `_knockback_velocity`.
  - **Stagger layer:** emits a `request_stagger(duration)` signal; `enemy.gd` cancels its current attack and enters a brief stagger state, then restores prior AI state cleanly.
  - **Token-guarded tweens** — newer reactions replace older ones; original transform values are stored on first reaction, restored exactly on completion.
  - **Repeated-hit dampening** — minimum interval between full reactions; repeated hits within the interval do reduced visual recoil only.
  - **Death override** — when the enemy dies during a reaction, the death pipeline preempts cleanly.
- Boss tier: visual hit-flash only by default; knockback and stagger immune unless the attack carries an `armor_break` or `boss_vulnerable_window` flag (defined now, unused until Phase 3 unless an existing boss already supports it).

### Stage 1.8 — Audio + impact VFX layering
- Extend `AudioManager` with a weight-aware `play_impact(profile_id, position)` that mixes:
  - Swing layer (already played on attack start).
  - Impact layer (on confirmed hit).
  - Body/armor/magical layer (chosen by target tags — defaults to "body" if untagged).
  - Kill layer (on `enemy.died` signal).
- Pitch variance ±5% within a profile; no-repeat last-N variant pool.
- Visual impact: extend the existing 40-sprite VFX pool with contact particle presets per `CombatFeedbackProfile`. Weapon trail uses `Line2D` on the swing sprite for swings without an existing arc; otherwise keep the current rotated-texture arc.
- Crit and kill variants add an extra flash ring + slightly larger particle burst.

### Stage 1.9 — Acceptance pass, summary, version bump
- Run the full test list from §8.
- Bump `GAME_VERSION` in `scenes/ui/changelog_dialog.gd` to `v0.84.0` (minor — combat overhaul Phase 1).
- Add a changelog entry summarizing the systems introduced.
- Produce the Phase 1 summary: files created, files modified, systems introduced, tunable values, tests completed, errors found and fixed, known issues, recommended Phase 2 tasks. **Stop. Do not proceed to Phase 2 without approval.**

---

## 7. Tunable values introduced in Phase 1 (defaults)

All values are exposed via `@export` properties on the relevant component or on a Resource referenced by the component. The defaults below are starting points to iterate from.

### Input buffer (per-action TTL, ms)
- Attack: **140**
- Directional intent: **180**
- Special tap-buffer: **180** (preserves existing feel)
- Dodge: **120**

### Hit-stop (`CombatFeedbackProfile`, ms)
| Weight | Attacker freeze | Victim freeze | Global dip |
|---|---|---|---|
| Light | 30 | 35 | none |
| Medium | 50 | 55 | none |
| Heavy | 75 | 85 | none |
| Combo finisher | 95 | 105 | none |
| Crit | 70 | 90 | 50 ms @ 0.35 time-scale |
| Elite kill | 100 | 120 | 60 ms @ 0.30 time-scale |
| Boss event | 120 | 140 | 70 ms @ 0.25 time-scale |

### Camera shake (trauma values 0–1, decay s⁻¹)
| Weight | Trauma | Decay |
|---|---|---|
| Light | 0.18 | 3.0 |
| Medium | 0.30 | 2.8 |
| Heavy | 0.45 | 2.5 |
| Finisher | 0.55 | 2.3 |
| Crit | 0.55 | 2.3 |
| Elite kill | 0.70 | 2.0 |
| Boss event | 0.85 | 1.7 |

### Knockback (`HitReactionData`, scalar applied to attack force)
| Tier | Knockback × | Stagger duration (ms) | Repeated-hit min interval (ms) |
|---|---|---|---|
| Light enemy | 1.00 | 220 | 120 |
| Medium enemy | 0.75 | 160 | 160 |
| Heavy enemy | 0.50 | 110 (heavy attacks only) | 200 |
| Elite enemy | 0.30 | 90 (heavy / crit only) | 260 |
| Boss enemy | 0.00 (immune by default) | 0 (immune by default) | 320 |

### Dodge (`DodgeController`)
- i-frames: **220 ms**
- Accel curve: 0 → 1 over first 60 ms, hold to 180 ms, 1 → 0 over remaining
- Trail interval: **18 ms**
- Perfect-dodge window: **80 ms** (detection only, no reward in Phase 1)

### Attack timing (`AttackTimingData`) — initial calibration to match existing tween offsets, then adjusted to land on the visible contact frame. Per-attack values authored during Stage 1.3.

### Accessibility scalars
- Camera shake intensity: **1.0** (range 0.0–1.0)
- Hit-stop intensity: **1.0** (range 0.0–1.0)
- Global dip enabled: **true**

---

## 8. Manual testing instructions (Phase 1 acceptance)

Run after every stage; run the full list before declaring Phase 1 complete.

**Core combat**
1. Five-swing combo A→B→C→D→E executes reliably with normal input pacing.
2. Inputs buffered at the seam between swings produce the next swing every time (no dropped inputs).
3. Combo resets correctly after the combo window elapses, after dodge, after taking damage, after stopping input.
4. Player can intentionally stop after any swing (no forced auto-chain).
5. Directional branches fire correctly: up→down = slam, down→up = uppercut, diagonal = spin.
6. Tap-buffer specials (power strike, whirlwind) still trigger from rapid taps and resolve via the new buffer.
7. Charged slash still triggers on hold ≥ 1.5 s and releases correctly.
8. Damage lands on the visible contact frame, not earlier and not later, for every player attack.
9. Each swing's hitbox is inactive outside its active window (verified with debug overlay).
10. Each target is hit at most the configured number of times per swing (default 1 for narrow swings, multiple for spin/AoE per their data).

**Dodge**
11. Dodge fires immediately on input, including mid-recovery when dodge-cancel window allows.
12. Dodge cannot fire during disallowed windows (e.g. mid-active-frames of unstoppable swings).
13. i-frames protect from a clearly timed enemy hit.
14. Dodge cannot get stuck; pressing dodge near a wall produces deliberate collision behavior.
15. Repeated rapid dodge input does not produce stacked dodges from a single press.

**Hit-stop**
16. Light, medium, heavy hits feel progressively heavier.
17. Crit produces a noticeable brief global slowdown.
18. Multiple enemies killed within ~100 ms do **not** stack global dips — only one event fires.
19. Pausing the game during a hit-stop and resuming returns to a fully responsive state.
20. Saving / loading during or right after hit-stop does not leave the time scale below 1.0.
21. Dying during a hit-stop does not leave the time scale below 1.0.
22. Scene reload during hit-stop does not leave the time scale below 1.0.
23. Accessibility scalar set to 0.0 disables global dip without breaking any other system.

**Camera shake**
24. Camera shake never drifts — after each impact, the camera returns precisely to follow position.
25. Heavy attacks shake more than light attacks; mid-tier punch is present (not "barely there → screen-fills").
26. Accessibility scalar set to 0.0 disables shake without breaking gameplay.

**Enemy reactions**
27. Every enemy reacts visibly to every hit (recoil + flash, even if knockback is zero).
28. Light enemies are clearly knocked back; heavy/elite are visibly more resistant; boss reacts visually but not physically.
29. Knockback respects walls — enemies do not pass through geometry.
30. Repeated rapid hits do not permanently stun-lock or visually break enemies.
31. Enemies killed during a flinch transition cleanly into death; visual transform restores to a valid state.
32. Stagger interrupts an enemy's current attack only when allowed by its data; uninterruptible attacks complete.

**Integration / regression**
33. All existing abilities still function.
34. All existing enemy types still function — skeleton, rat, goblin, wolf, bandit, troll, ogre at minimum.
35. No new parser errors at startup.
36. No recurring runtime errors during 5 minutes of combat against mixed enemies.
37. Performance remains acceptable with a normal group (~8 enemies on screen).
38. Save format unchanged — loading a pre-Phase-1 save works.
39. Keyboard, mouse, and controller (if supported) all drive combat correctly.
40. Pause menu opens and resumes cleanly during any combat state.

---

## 9. Risks & rollback considerations

- **Animation method tracks** in existing AnimationPlayer nodes may call methods that get moved. Mitigation: keep forwarding methods on `player.gd` with the original signatures.
- **Two scripts touching `CharacterBody2D.velocity`** (movement + dodge). Mitigation: `DodgeController` writes a request; `player.gd` is the sole writer of `velocity`.
- **`await` callbacks** outliving cancelled state. Mitigation: generation-token guard on every state entry; callbacks compare token before acting.
- **`Engine.time_scale` getting stuck below 1.0.** Mitigation: forced reset on `SceneTree.tree_changed`, pause/resume, player death, save load; single-owner authority in `HitStopController`.
- **Multiple tweens permanently distorting an enemy.** Mitigation: store original transform on first reaction, restore on completion, replace (not stack) on new reaction.
- **Crowd combat triggering stacked global dips.** Mitigation: dip request aggregator — equal or weaker requests during an active dip are ignored.
- **Save format drift.** Mitigation: Phase 1 does not touch `SaveLoadManager`.
- **Combo-state divergence between old and new paths during Stage 1.4.** Mitigation: extraction is atomic per system; no parallel-active legacy/new combo state in the same commit.

**Per-stage rollback:** every stage is a separate commit. If a stage regresses, revert that single commit; the previous commit is a fully-playable checkpoint.

---

## 10. Performance considerations

- `HitStopController` uses a single `Timer` with `PROCESS_MODE_ALWAYS` for global dip recovery — no per-frame work when inactive.
- Localized freeze toggles `AnimationPlayer.speed_scale` and a flag on AI; no per-frame work.
- `CameraShake2D` recomputes offset only while `trauma > 0`.
- `HitReactionComponent` uses tweens, not `_process`; idle cost is zero.
- VFX continues to use the existing pooled-sprite pool (cap 40). New particle presets remain in this pool; no new every-frame spawning.
- Audio: weight-aware playback reuses existing `AudioManager` pool; no new per-frame allocations.
- Enemy reactions are event-driven (on `take_damage`), not per-frame.

---

## 11. Project rules respected

- Every commit bumps `GAME_VERSION` in `scenes/ui/changelog_dialog.gd` and adds a `CHANGELOG` entry (per `CLAUDE.md`).
- No new global autoloads beyond `HitStopController` (justified — global time-scale ownership must be singular).
- No mass renames, no formatting churn on unrelated files, no asset modifications.
- `SaveLoadManager` save schema unchanged in Phase 1.
- Typed GDScript throughout new code.

---

## 12. Out of scope for Phase 1

- New abilities, new weapons, new enemies, new encounters.
- Resource/cost system, status-effect rewrite, vulnerability/armor-break gameplay.
- AnimationTree overhaul, new directional animations.
- New particle systems beyond the existing pool.
- UI/HUD changes beyond damage-number tier tweaks already planned.
- Environment interaction, breakables, hazards. 
- Performance profiling sweep (Phase 8).
- Accessibility settings UI (the scalars exist; the settings screen comes in Phase 8).
