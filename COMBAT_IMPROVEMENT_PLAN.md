# Combat Improvement Plan

**Project:** Legends Open RPG (Godot 4.6, top-down action RPG)
**Goal:** Diablo-IV-grade game feel — responsive, fluid, powerful, readable — while preserving the game's identity and the existing 5-swing directional combat system. No copyrighted assets, abilities, characters, UI, or visual designs.
**Date:** 2026-06-14
**Authoring rule:** Each commit bumps `GAME_VERSION` (patch) in `scenes/ui/changelog_dialog.gd` and adds a `CHANGELOG` entry. Phase 1 lands across many patch commits; the final minor-version bump is decided at Phase 1C close, not pre-committed (see §11).

---

## 1. Current combat architecture (audit summary)

### Engine & autoloads
- Godot **4.6**, GL Compatibility renderer (`project.godot:19`).
- Autoloads: `SpriteGenerator`, `GameManager`, `CombatManager`, `DeathCounterSystem`, `TriggerEngine`, **`TimeManager`** (14 lines — SC:BW-style trigger-tick scheduler, **not currently a `time_scale` owner**), `EconomyManager`, `AlignmentManager`, `SettlementManager`, `BeaconManager`, `FogOfWarManager`, `RespawnManager`, `SaveLoadManager`, `AudioManager` (2,888 lines).

### Player (`scenes/player/player.gd`, 3,464 lines)
- All input, movement, attack animation, combo state, abilities, VFX spawning, UI updates live here.
- No formal state machine — state is flag-based (`_is_attack_animating`, `_is_charging`, `_combo_index`, `_combo_timer`, `_attack_cooldown`).
- **Five swing types**: A (left→right), B (right→left backhand), C (overhead chop), D (upward thrust), E (spin slash). Picked by `_pick_combo_swing()` (line 2582).
- **Directional branches**: up→down = slam, down→up = uppercut, diagonal = spin.
- **Tap-buffer specials** (`_tap_count`, `_tap_resolve_timer` 0.18 s): 2 = power strike, 3 = whirlwind.
- **Charged slash**: hold ≥ `CHARGE_THRESHOLD = 1.5 s`.
- **Damage timing is tween-callback based** (e.g. `_anim_swing_horizontal()` fires damage at line 2667 via `tween.tween_callback()` mid-tween). No AnimationPlayer method tracks.
- Hitbox: single `Area2D` `AttackArea`, radius = `stats.attack_range`.

### Abilities, weapons, stats
- `AbilityManager` (`scripts/components/ability_manager.gd`, 102 lines) tracks cooldowns from `HeroData`.
- No `WeaponData` Resource — weapon damage on `stats.weapon_damage` (`StatsComponent`, 267 lines).

### Enemies (`scenes/enemies/enemy.gd`, 2,849 lines)
- State machine `IDLE / PATROL / CHASE / ATTACK / RETURN`. Sleeps when player > 800 px.
- Attacks resolve instantly on cooldown expiry (line 626) — no anim-driven contact.
- `apply_knockback(dir, force)` sets `_knockback_velocity`, decays over ~0.07 s (line 343–346).
- Death pipeline supports per-sprite cinematics with 30–100 ms inter-death stagger.

### Camera, audio, VFX, UI
- Camera2D is a child of player. **Procedural screen shake** — direct intensity, random offset decay (line 568–574). No trauma model.
- Audio centralized in `AudioManager` (2,888 lines). Per-enemy SFX cooldowns; pitch randomization sparse.
- VFX: **sprite-only pool, cap 40** (line 130) — slash arcs, sparks, flash rings, afterimages. Bleed uses CPUParticles2D separately. **No Line2D or particle nodes in the sprite pool.**
- Damage numbers: pooled `Label` (player 30, enemy 30); zoom-compensated HP bars.
- Hit flash: red modulate + squash on player damage (line 3107). Enemies have `_do_hit_flash()` but no flinch animation.

### Save system (`scripts/autoloads/save_load_manager.gd`, 317 lines)
- File `user://savegame.json`. **Phase 1 must not change save format.**

### Coupling / risk hotspots
- `player.gd` 3,464 lines, `enemy.gd` 2,849 lines.
- Tween-callback damage decoupled from visible contact.
- Attack cooldown (`0.5 / attack_speed`) decoupled from animation duration.
- Status effects are loose flags.
- Hard-coded shake values (basic 1.5–2.0, crit 4–6, specials 3–10) with a flat-to-screen-filling gap.

---

## 2. Why combat currently feels boring

1. Damage lands on a tween callback, not a visible contact frame.
2. No enemy flinch / stagger animation — hits feel ignored.
3. No hit-stop on the victim side.
4. Knockback is instant velocity, no impact squash/stretch.
5. Non-crit basic attacks have no juice.
6. Combo-window resets are invisible.
7. Attack cooldown unrelated to animation duration.
8. Screen-shake values are flat and scattered.
9. No input buffering across the combo seam.
10. No identity per swing — A/B/C/D/E differ visually but produce identical impact feedback.

---

## 3. Design direction (decisions reached)

### Combo identity (correction 1)
- **Preserve all five swings.** Restructure the **rhythm**, not the count.
- **A → B → C** is the **three-hit core**. **C is a satisfying mini-finisher** — distinct VFX, audio, camera trauma, and a stronger hit-reaction tier. After C the combo can reset cleanly or extend.
- **D and E are optional higher-commitment extensions**, gated by directional input or a longer combo-window press. They are not mandatory weak steps in between; if the player stops after C, the combo ended properly. D's profile is a launching/displacement extension; E is a wider/AoE extension. Both carry longer recovery and stronger reactions than B.
- **Directional branches** (slam / uppercut / spin) remain available at any compatible step and replace the next step's animation while preserving the rhythm class (e.g. slam replacing C still behaves as a finisher).
- **Tap-buffer specials and charged slash** are preserved unchanged.

### Architecture
- **Targeted, staged extraction** from `player.gd` / `enemy.gd`. No big-bang rewrite. Movement & physics stay in `player.gd`.
- Phase 1 is split into **1A → 1B → 1C** (§5).

### Time-scale ownership (correction 2)
- **`TimeManager` becomes the singular owner of `Engine.time_scale`.** Today it is a 14-line trigger-tick scheduler; we extend it with a priority-ranked time-scale request API. **No other code writes `Engine.time_scale`.**
- **`HitStopController` does not own `Engine.time_scale`.** It routes global-dip requests through `TimeManager.request_time_scale(scale, duration_ms, priority, source_id)`. `TimeManager` resolves competing requests (higher priority wins; equal-or-lower ignored during an active stronger request; stronger replaces, weak hits never extend strong dips).

### Reset sources (correction 3)
- `TimeManager` and `HitStopController` reset on **explicit signals only**, not `SceneTree.tree_changed` (which fires on any descendant change).
- Reset sources, all explicit:
  - `SceneTree.scene_changed` (Godot 4.4+ scene-root swap).
  - `GameManager.player_died`.
  - `SaveLoadManager.save_loaded`, `SaveLoadManager.save_about_to_load`.
  - `GameManager.returning_to_menu`.
  - `SceneTree.tree_exiting` (shutdown).
- Each subsystem owns idempotent reset methods (`force_reset()`). The plan documents which autoload emits each signal; any missing signals are added as part of Stage 1B.1.

### Hit-stop timing source (correction 4)
- **No `Timer` nodes for short freezes (30–150 ms).** Freeze durations use **monotonic real-time deadlines** stored as `Time.get_ticks_usec()` targets, evaluated in a single lightweight `HitStopController._process(delta)` that reads `delta` from `OS`-real time, not engine-scaled time.
- **Recovery timer during global slowdown ignores `time_scale`.** The controller's `_process` runs in `PROCESS_MODE_ALWAYS`, but freeze comparisons use `Time.get_ticks_usec()` (monotonic wall clock), not `delta` accumulation. Global-dip duration is also a wall-clock deadline.
- One controller owns all active freeze deadlines (attacker / victim / global). Per-frame cost when no freezes are active is one timestamp comparison.

### Damage timing (correction 7)
- **Audit fact:** the project uses **no** `AnimationPlayer` or `AnimationTree` for combat today. All attacks are Tween-driven sprite-frame swaps, position/scale/rotation tweens, and modulate tweens.
- **Preference order for the contact event**:
  1. `AnimationPlayer` method-track event `contact_event` — applicable only to any AnimationPlayer animations we add in Phase 4 (animation polish). Not used by Phase 1 attacks.
  2. **Dedicated normalized attack clock** for the current Tween-driven attacks: `CombatController` exposes `attack_progress: float` (0.0 → 1.0) driven by a single `Tween.tween_method` writing that property. All gameplay windows (contact, active, combo, dodge-cancel, special-branch, recovery) are evaluated against `attack_progress`, **not** the visual Tween's elapsed time. **This is the path Phase 1 uses for every existing attack.**
  3. Absolute seconds **forbidden** in new code. Existing legacy seconds become normalized values during migration.
- This decouples gameplay timing from any visual Tween's chained durations and from changes to animation speed.

### Typed combat events (correction 8)
- Introduce typed classes:
  - `class_name HitEvent` — `attacker`, `victim`, `direction: Vector2`, `weight: int` (enum), `is_crit: bool`, `attack_id: StringName`, `feedback_profile: CombatFeedbackProfile`, `reaction_profile_override: HitReactionData`, `damage_request: int`, `armor_break: bool`, `unblockable: bool`.
  - `class_name HitResult` — emitted only by `CombatManager` after damage resolves: `event: HitEvent`, `damage_dealt: int`, `was_lethal: bool`, `was_blocked: bool`, `was_dodged: bool`, `final_reaction: HitReactionData`, `final_feedback: CombatFeedbackProfile`.
- **All feedback (hit-stop, camera shake, audio impact layer, enemy reaction, VFX) is triggered from a confirmed `HitResult`**, never from contact-frame timing alone.
- Wide-attack aggregation: multiple `HitResult`s within a single `attack_id` instance are coalesced for global-dip and camera-shake selection (primary = highest-weight, or lethal/crit).
- No further expansion of damage dictionaries.

### Enemy reaction root (correction 9)
- **No automatic reparenting of enemy sprites.**
- `HitReactionComponent` exports a `@export var reaction_pivot: Node2D` reference. The base enemy scene gains a `ReactionPivot` child (Node2D wrapping the existing sprite) only where it is **safe to add by hand**: when no animation, no script, no exported NodePath, and no shader uses the sprite's transform directly.
- For any enemy where the audit cannot guarantee safety, the reaction targets the existing sprite directly with **transform-only** changes (rotation/scale/modulate) — never reparenting, never offsetting the collision body.
- Original transform values are captured on first reaction and restored exactly on completion.

### Stagger recovery (correction 10)
- After stagger ends, the enemy **does not blindly restore the prior state**. `HitReactionComponent` emits `stagger_ended(enemy)`. `enemy.gd` re-evaluates its appropriate AI state based on **current** conditions: player distance, sight, current HP, enemy archetype, group state, target alive, navigation reachability.
- If the prior state is no longer valid (e.g. target dead, player out of sleep range), the enemy transitions to the correct new state (CHASE / RETURN / IDLE) rather than ATTACK.

### Input buffer scope (correction 6)
- `InputBuffer` stores **raw input events with monotonic timestamps and per-action TTL**. That is its entire job. It does not know about tap counts, specials, charge, or priority.
- A new `AttackIntentResolver` (inside `CombatController`) reads the buffer and turns events into intents: tap-count interpretation, special selection, charge resolution, directional-branch selection, combat input priority (e.g. dodge > attack at a window boundary).
- This keeps the buffer reusable and the interpretation testable in isolation.
- **Audit fact:** the existing tap-buffer drives both melee (POWER_STRIKE, WHIRLWIND, CHARGED_SLASH, DASH_STRIKE) **and ranged class moves** (PIERCING_SHOT, ARROW_RAIN, SNIPER_SHOT, SHADOW_STEP). `AttackIntentResolver` must produce class-appropriate intents driven by hero class, not assume melee.

### Combat audio scope (correction 11)
- **Do not expand `AudioManager`** (already 2,888 lines) with combat selection logic.
- `AudioManager` keeps responsibility for: playback, pooling, bus routing, pitch jitter, last-N variation guard. Its public API gains at most a `play_variant(group: StringName, position: Vector2, pitch_jitter: float)` helper if one is missing.
- A new small **`CombatAudioComponent`** (per-player, per-enemy) selects which audio group plays for swing / impact / body / armor / magical / kill, driven by `CombatFeedbackProfile` and `HitResult`. It calls into `AudioManager` for actual playback.

### Phase 1 VFX scope (correction 12)
- Phase 1 VFX **uses the existing 40-sprite pool only**. No new pooled types are added.
- Weapon trails in Phase 1 reuse the existing rotated-arc sprite pattern, not Line2D.
- New particle effects (`GPUParticles2D`) and Line2D trails are explicitly **Phase 5 work**, listed under "out of scope for Phase 1" (§13).
- Crit / kill variants are achieved by tinting + scaling the existing pooled sprites and emitting an additional flash-ring entry from the same pool.

### Save format
- **Unchanged in all of Phase 1.**

---

## 4. New systems & files

### New scripts (Phase 1)
| File | Type | Purpose |
|---|---|---|
| `scripts/combat/hit_event.gd` (`class_name HitEvent`) | Resource | Typed hit-request object (§3 corr. 8). |
| `scripts/combat/hit_result.gd` (`class_name HitResult`) | Resource | Typed post-resolve event; feedback trigger. |
| `scripts/components/input_buffer.gd` | RefCounted | Raw event buffer with TTL only. No interpretation. |
| `scripts/combat/attack_intent_resolver.gd` | RefCounted | Reads `InputBuffer`; produces typed intents (tap-count, special, charge, directional branch, priority). Owned by `CombatController`. |
| `scripts/combat/attack_clock.gd` | RefCounted | Normalized `attack_progress: float` driver. Single Tween writes the property; windows are evaluated against progress. |
| `scenes/player/combat_controller.gd` | Node child of Player | Owns combo step, rhythm class (A/B/C-finisher / D / E / branches / specials / charged), cancellation rules; emits requests; never moves the body. |
| `scenes/player/dodge_controller.gd` | Node child of Player | **Introduces** a new dodge action (no dodge exists today). State, i-frames, accel/decel curve, perfect-dodge window (detect-only). `player.gd` still owns `velocity`. A new input action `dodge` is added in `project.godot`. |
| `scripts/autoloads/hit_stop_controller.gd` | Autoload | Monotonic real-time deadlines for attacker/victim freeze. Routes global-dip requests **through** `TimeManager`. Explicit `force_reset()`. |
| `scripts/combat/camera_shake_2d.gd` | Node on player Camera2D | Trauma model (`offset = max * trauma² * noise`), directional impulse, max-clamp, accessibility scale, drift-free. |
| `scripts/components/hit_reaction_component.gd` | Node child of enemy | Visual recoil on exported `reaction_pivot`; knockback request to `enemy.gd.apply_knockback`; stagger request; re-evaluates AI state on stagger end. |
| `scripts/components/combat_audio_component.gd` | Node | Combat-specific audio selection. Calls into `AudioManager` for playback. |

### New Resources (Phase 1)
| File | Purpose |
|---|---|
| `scripts/data/attack_timing_data.gd` + `res://data/attacks/*.tres` | Per attack: animation source (method-track id OR normalized-progress windows), active hitbox window, combo window, dodge-cancel window, special-branch window, max-hits-per-target, hitbox profile id, movement-impulse window, feedback profile id, rhythm class (`core_1` / `core_2` / `finisher` / `extension_d` / `extension_e` / `branch_slam` / `branch_uppercut` / `branch_spin` / `special_*` / `charged`), `unstoppable: bool`. |
| `scripts/data/hit_reaction_data.gd` + `res://data/reactions/*.tres` | Tier profile: visual recoil magnitude, squash/stretch curve, rotation, knockback magnitude, knockback resistance, stagger duration, stagger resistance, repeated-hit min interval, optional custom-animation name. |
| `scripts/data/combat_feedback_profile.gd` + `res://data/feedback/*.tres` | Per weight class: attacker freeze ms, victim freeze ms, camera trauma, camera impulse, audio group ids, vfx pool entries, flash color/strength, knockback scalar, optional global-dip (scale, ms, priority). |

### Files to extend (no renames, no formatting churn)
- `scripts/autoloads/time_manager.gd` — extend to be sole owner of `Engine.time_scale` (see §3 corr. 2 + §6 Stage 1B.0).
- `scripts/autoloads/combat_manager.gd` — extend to emit `HitResult` from `HitEvent`; dispatch feedback.
- `scripts/autoloads/audio_manager.gd` — add `play_variant(group, position, pitch_jitter)` helper if missing; **no combat selection logic added**.
- `scenes/player/player.gd` — delegate combat decisions to `CombatController`; preserve forwarding methods for AnimationPlayer method tracks.
- `scenes/enemies/enemy.gd` — add child `HitReactionComponent`; `take_damage()` builds `HitEvent` and hands it to `CombatManager`; implement stagger re-evaluation hook (§3 corr. 10).
- `scenes/player/player.tscn`, base `enemy.tscn` — add child component nodes.
- `scenes/ui/changelog_dialog.gd` — bump `GAME_VERSION` and entries per commit.

---

## 5. Phased roadmap (Phase 1 split — correction 5)

### Phase 0 — Audit & plan
- This document. No behavior change.

### Phase 1A — Foundations: typed events, input, attack timing
- Typed `HitEvent` / `HitResult`.
- `InputBuffer` (raw events only) + `AttackIntentResolver`.
- `AttackTimingData` + `attack_clock.gd` normalized-progress system.
- Migrate every attack's contact event and gameplay windows to the new clock or to AnimationPlayer method tracks.
- Synchronize attack cooldown with animation duration (cooldown is no longer set instantly to a constant decoupled from anim length).
- `CombatManager` produces `HitResult` from `HitEvent`. Existing damage numbers / sounds keep working (legacy paths read `HitResult.damage_dealt`).
- **No new feedback systems in 1A.** Behavior should feel the same or slightly more responsive (buffered inputs, contact-aligned damage) but not visually different yet.

### Phase 1B — Feedback: hit reactions, freeze, shake, audio, VFX
- Extend `TimeManager` to be sole `time_scale` owner + add explicit reset hooks.
- `HitStopController` (monotonic deadlines, routes global dip through `TimeManager`).
- `CameraShake2D` on player Camera2D.
- `HitReactionComponent` on enemies (visual + knockback + stagger; stagger-end re-evaluates AI state).
- `CombatAudioComponent` selecting layered impact audio; `AudioManager` only plays.
- `CombatFeedbackProfile` Resources authored for every weight class.
- VFX uses **existing sprite pool only**; new pool types are out of scope.
- C-finisher rhythm class produces the stronger feedback profile (corr. 1).

### Phase 1C — Extraction & cleanup
- `CombatController` extraction completes: combo step, branching, charge resolution, cancellation rules move out of `player.gd`.
- `DodgeController` extraction.
- Remove all obsolete combat code from `player.gd` — no parallel-active legacy paths remain.
- Verify `player.gd` line count drops meaningfully.
- Final acceptance pass + summary.

### Phase 2 — Combat rhythm, ability interactions, build depth *(later)*
Resource cost system, cooldowns/charges, combo finishers beyond C, held-input attacks, ability chaining, status application & consumption, vulnerability / armor break, behavior-changing upgrades, reward the perfect-dodge window detected in 1C.

### Phase 3 — Enemy behavior & encounter design *(later)*
Roles, telegraphs, group-attack limits, flanking, repositioning, mixed encounters, ambushes, environmental hazards. Event-driven AI.

### Phase 4 — Animation polish & procedural motion *(later)*
AnimationTree transitions, attack/movement blending, directional anims, anticipation poses, additive recoil, squash/stretch refinement, footstep sync. No skeletal features incompatible with current sprites.

### Phase 5 — VFX / shaders / audio / screen feedback *(later)*
`GPUParticles2D` impacts, `Line2D` projectile/weapon trails, ground indicators, status visuals, dissolve shaders, scorch/ice/poison surfaces, audio variation pools, bus ducking, elite cues. **All new pool types live here.**

### Phase 6 — Damage presentation, UI, progression feedback *(later)*

### Phase 7 — Environment interaction *(later)*

### Phase 8 — Performance, accessibility, final tuning *(later)*

---

## 6. Phase 1 — staged execution plan

Each stage is one or more discrete commits. Each leaves the game playable. Each ends with a behavioral checklist re-run.

### Stage 1A.0 — Behavioral checklist *(no behavior change)*
- Map combat variables, methods, signals, timers, animation-track callbacks, NodePaths, autoload dependencies, external callers of `player.gd` / `enemy.gd` combat APIs.
- Document the 5-swing sequence, directional branches, tap-buffer specials, charged slash, dodge cancel windows.
- Produce a manual test checklist re-runnable after each stage.

### Stage 1A.1 — Typed `HitEvent` / `HitResult` + CombatManager rewire
- Introduce both classes. `CombatManager.calculate_damage` is wrapped/extended to accept `HitEvent` and emit `HitResult`. Legacy callers continue to work via a thin adapter.
- No feedback wiring yet — feedback hooks exist but are no-ops.

### Stage 1A.2 — `InputBuffer` (raw events only)
- New `InputBuffer` stores `InputEventRecord {action: StringName, timestamp_usec: int, ttl_ms: int, consumed: bool}`.
- Per-action TTL defaults: `attack=140`, `dodge=120`, `direction_intent=180`, `special_tap=180`, `charge_press=indefinite-until-release`.
- Single-consume tokens; controller, keyboard, mouse share the buffer.
- Debug overlay toggle.

### Stage 1A.3 — `AttackIntentResolver`
- Reads `InputBuffer`; produces typed `AttackIntent` (tap-count → special / basic, charge resolution, directional-branch, priority dodge > attack).
- Replaces `_tap_count`, `_tap_resolve_timer`, charge tracking inside `player.gd`. `player.gd` retains a forwarding shim for any external code that read those flags.

### Stage 1A.4 — `attack_clock.gd` + `AttackTimingData`
- `AttackClock` exposes `attack_progress: float` (0.0–1.0) driven by a single `Tween.tween_method`.
- `AttackTimingData` Resources authored for every attack:
  - A, B, **C (finisher)**, D (extension), E (extension), slam, uppercut, spin, each tap-buffer special, charged slash.
  - Each defines windows in normalized progress: `contact_event`, `active_window_start/end`, `combo_window_start/end`, `dodge_cancel_start`, `special_branch_start/end`, `movement_cancel_start`, `recovery_end`, `max_hits_per_target`, `rhythm_class`, `unstoppable`.
- Where an AnimationPlayer animation already exists, add a `contact_event` method track and use it in place of normalized progress.

### Stage 1A.5 — Per-attack contact migration
- For each attack, atomic commit: new timing data activated, legacy tween-callback damage removed for that attack in the same commit.
- Active hitbox window enforced via `Area2D.monitoring`; per-target hit-once via target-id set cleared on window end or cancel.
- Cooldown is derived from `recovery_end` and current attack-speed scalar — never set instantly to a constant.

### Stage 1A.6 — Combo rhythm restructure (correction 1)
- **A → B → C** is the core. C is a mini-finisher: stronger feedback profile, larger camera trauma, "heavy" reaction tier; clean reset window after C.
- **D and E are optional extensions** committed via a longer combo window or directional input after C. They carry larger commitment (longer recovery, lower dodge-cancel availability).
- Directional branches replace the next step's animation while preserving rhythm class.
- Tap-buffer specials and charged slash unchanged in identity.

### Stage 1B.0 — `TimeManager` extension (corr. 2 + 3 + 4)
- Add to `TimeManager`:
  - `request_time_scale(scale: float, duration_ms: int, priority: int, source_id: StringName) -> bool`
  - `force_reset()` — restores `Engine.time_scale = 1.0` and clears the active request.
  - `time_scale_changed(new_scale: float)` signal.
  - Internal: monotonic real-time deadline via `Time.get_ticks_usec()`; `_process` runs always.
  - Conflict policy: higher priority always wins; equal or lower priority during an active request is ignored unless the active request expires first.
- Connect explicit reset sources (corr. 3). Audit confirmed which exist today:
  - `SceneTree.scene_changed` — exists (engine).
  - `RespawnManager.player_died(player_id: int)` — **exists** (`respawn_manager.gd:6`). Connect to this; do NOT re-emit a duplicate from `GameManager`.
  - `GameManager.returning_to_menu` — **does not exist**; add as part of this stage. Emitted by whatever code transitions to the menu scene.
  - `SaveLoadManager.game_loaded` — exists (`save_load_manager.gd:11`). `save_about_to_load` — **does not exist**; add and emit at the top of the load path.
  - `SceneTree.tree_exiting` — exists (engine).
- **No other code writes `Engine.time_scale` after this stage.** Grep guard documented in §9.

### Stage 1B.1 — `HitStopController`
- Autoload, `PROCESS_MODE_ALWAYS`.
- Maintains a small array of active freezes `{target, restore_speed, deadline_usec, generation}`.
- Per-frame: one `Time.get_ticks_usec()` comparison per active entry; no work when empty.
- `freeze_attacker(node, ms)` / `freeze_victim(node, ms)` — sets `AnimationPlayer.speed_scale = 0.0` (or Tween pause) for `node`, schedules restore by deadline. Generation token guards against stale restores.
- `request_global_dip(profile)` → calls `TimeManager.request_time_scale(profile.dip_scale, profile.dip_ms, profile.dip_priority, "hitstop")`. **Never writes `Engine.time_scale` directly.**
- Coalesces wide-attack `HitResult` bursts: a per-attack-id window deduplicates global-dip requests; only the strongest survives.
- `force_reset()` connected to the same explicit reset sources as `TimeManager`.

### Stage 1B.2 — `CameraShake2D`
- New node on player Camera2D.
- Trauma model: `trauma += impulse`, clamped to 1.0; `offset = max_offset * trauma² * noise(t)`; trauma decays at configurable rate.
- Directional impulse: trauma vector pushed slightly along hit direction.
- Accessibility scalar.
- Resets on the same explicit signals as above.

### Stage 1B.3 — `HitReactionComponent` (corr. 9 + 10)
- Component attached as child of enemy.
- `@export var reaction_pivot: Node2D` — must be assigned. Falls back to the enemy's main sprite (transform-only changes) if no pivot is assigned.
- Visual layer: token-guarded squash/stretch + rotation + modulate on `reaction_pivot`. Original transform captured on first reaction, restored exactly on completion.
- Physical layer: delegates to existing `enemy.apply_knockback(dir, force * resistance_scalar)`.
- Stagger layer: emits `request_stagger(duration)` — `enemy.gd` cancels current attack, enters stagger state.
- On stagger end: emits `stagger_ended(enemy)`. `enemy.gd` **re-evaluates** the appropriate AI state from current conditions (player distance, sight, HP, target alive), then transitions accordingly. Does not blindly restore the prior state.
- Death overrides flinch; death animation preempts cleanly.
- Repeated-hit dampening per `HitReactionData.min_interval_ms`.

### Stage 1B.4 — `CombatAudioComponent` (corr. 11)
- Per-player and per-enemy component.
- Selects audio group ids from `CombatFeedbackProfile` and target tags (body / armor / magical).
- Calls `AudioManager.play_variant(group, position, pitch_jitter)`.
- `AudioManager` gains only the small `play_variant` helper if not already present; no selection logic moves into `AudioManager`.

### Stage 1B.5 — VFX wiring (corr. 12)
- All Phase 1 impact VFX uses the **existing 40-sprite pool**.
- Per-profile VFX entries are recipes for sprite-pool requests (texture, color, scale, lifetime).
- No Line2D, no GPUParticles2D added in Phase 1.
- Crit / kill variants = tinted + scaled pooled sprites + additional flash-ring entry.

### Stage 1B.6 — Feedback hookup
- `HitResult` from `CombatManager` triggers, in this order:
  1. `HitStopController.freeze_attacker` + `freeze_victim`
  2. `HitStopController.request_global_dip` (only for crit / finisher / elite-kill / boss-event profiles)
  3. `CameraShake2D` impulse
  4. `CombatAudioComponent` impact layer
  5. `HitReactionComponent` (visual + knockback + stagger)
  6. VFX pool entries

### Stage 1C.0 — `CombatController` shell (delegates only)
- Add child node in `player.tscn`; combat decisions route through it but call back into existing `player.gd` for animation playback. Behavior identical.

### Stage 1C.1 — Move combo state into `CombatController`
- Combo index, combo timer, rhythm class, cancellation matrix, special-branch resolution, charge-vs-tap decision migrate. `player.gd` still plays animations.

### Stage 1C.2 — `DodgeController` introduction
- **No prior dodge code exists** (audit confirmed). Component introduces a new dodge action.
- Add `dodge` to `project.godot` input map (default: `Shift` on keyboard, right stick click or B on controller — exact bindings deferred to first run).
- Component owns dodge state, i-frames (default 220 ms), accel/decel `Curve`, perfect-dodge window (detection-only).
- `player.gd` remains the sole writer of `CharacterBody2D.velocity`; dodge writes a request, player applies.

### Stage 1C.3 — Obsolete-code cleanup
- Remove every legacy combat path now dead. No parallel-active code remains. Confirmed by grep guard.
- Measure `player.gd` line count delta and document.

### Stage 1C.4 — Acceptance, summary, version
- Run §8 tests. Run §10 headless smoke tests.
- Produce the Phase 1 summary: files created/modified, systems introduced, tunable values, tests completed, errors fixed, known issues, recommended Phase 2 tasks. **Stop. No Phase 2 without approval.**

---

## 7. Tunable values introduced in Phase 1 (defaults — iterate from)

### Input buffer (ms)
Attack 140 / Direction-intent 180 / Special-tap 180 / Dodge 120.

### Hit-stop (`CombatFeedbackProfile`, ms — monotonic deadlines)
| Weight | Attacker freeze | Victim freeze | Global dip (via TimeManager) |
|---|---|---|---|
| Light | 30 | 35 | none |
| Medium | 50 | 55 | none |
| Heavy | 75 | 85 | none |
| Combo finisher (C) | 95 | 105 | none |
| Crit | 70 | 90 | 50 ms @ 0.35, priority 2 |
| Elite kill | 100 | 120 | 60 ms @ 0.30, priority 3 |
| Boss event | 120 | 140 | 70 ms @ 0.25, priority 4 |

Priority 0 = none, 1 = weak, 2 = crit, 3 = elite kill, 4 = boss event. Higher always wins.

### Camera shake (trauma 0–1, decay s⁻¹)
| Weight | Trauma | Decay |
|---|---|---|
| Light | 0.18 | 3.0 |
| Medium | 0.30 | 2.8 |
| Heavy | 0.45 | 2.5 |
| Finisher (C) | 0.55 | 2.3 |
| Crit | 0.55 | 2.3 |
| Elite kill | 0.70 | 2.0 |
| Boss event | 0.85 | 1.7 |

### Knockback / stagger (`HitReactionData`)
| Tier | Knockback × | Stagger ms | Repeated-hit min interval ms |
|---|---|---|---|
| Light enemy | 1.00 | 220 | 120 |
| Medium enemy | 0.75 | 160 | 160 |
| Heavy enemy | 0.50 | 110 (heavy attacks only) | 200 |
| Elite enemy | 0.30 | 90 (heavy / crit only) | 260 |
| Boss enemy | 0.00 (default immune) | 0 (default immune) | 320 |

### Dodge (`DodgeController`)
i-frames 220 ms; perfect-dodge window 80 ms (detect-only); accel curve 0→1 over first 60 ms, hold to 180 ms, 1→0 to end; afterimage interval 18 ms.

### Accessibility scalars
Camera shake 1.0, hit-stop 1.0, global dip enabled, all range 0.0–1.0.

---

## 8. Manual testing instructions (Phase 1 acceptance)

Run after every stage; full list before declaring Phase 1 complete.

**Core combat**
1. A → B → C combo executes reliably; C feels like a satisfying finisher.
2. Combo can end cleanly after C (no forced D / E).
3. D and E require explicit longer-window press or directional intent — they are not auto-included.
4. Inputs buffered at the seam produce the next step every time.
5. Combo resets after combo window, dodge, damage, intentional stop.
6. Directional branches (slam / uppercut / spin) fire from correct inputs and preserve their rhythm class.
7. Tap-buffer specials (power strike, whirlwind) still trigger from rapid taps.
8. Charged slash still triggers on hold ≥ 1.5 s.
9. Damage lands on the visible contact frame.
10. Hitbox inactive outside its active window (debug overlay).
11. Each target hit at most the configured number of times per swing.
12. Attack cooldown matches animation length under varying attack-speed.

**Dodge**
13. Dodge fires immediately, including mid-recovery when window allows.
14. Dodge blocked during disallowed windows.
15. i-frames work against a clearly timed hit.
16. No stuck dodge near walls; no stacked dodges from a single press.

**Hit-stop / time-scale (single owner)**
17. Light / medium / heavy hits feel progressively heavier.
18. Crit triggers a noticeable brief global slowdown.
19. Multiple kills within ~100 ms produce one global dip, not stacked.
20. Pause / resume during a hit-stop returns to time-scale 1.0.
21. Save / load during or after hit-stop returns to time-scale 1.0.
22. Player death during hit-stop returns to time-scale 1.0.
23. Scene change during hit-stop returns to time-scale 1.0.
24. Quit-to-menu during hit-stop returns to time-scale 1.0.
25. Accessibility scalar 0.0 disables global dip without breaking other systems.
26. `Engine.time_scale` write grep finds only `TimeManager` (§9 guard).

**Camera shake**
27. No drift — camera returns precisely to follow position.
28. Mid-tier punch present (not flat → screen-filling).
29. Accessibility scalar 0.0 disables shake without breaking gameplay.

**Enemy reactions**
30. Every enemy reacts visibly to every hit.
31. Tier-appropriate physical response (light knocked, heavy resists, boss visual only).
32. Knockback respects walls.
33. Repeated rapid hits do not stun-lock or visually break.
34. Enemies killed during flinch transition cleanly into death.
35. Stagger interrupts attacks per data; uninterruptible attacks complete.
36. **After stagger, enemy re-evaluates state**: if target now dead or out of range, transitions to CHASE / RETURN / IDLE instead of resuming ATTACK.

**Audio / VFX**
37. Combat audio selection lives outside `AudioManager` (`CombatAudioComponent`).
38. `AudioManager` line count not meaningfully increased (Phase 1 only adds small `play_variant` helper if missing).
39. All Phase 1 VFX served by the existing sprite pool; no new pool types.

**Integration / regression**
40. All existing abilities still function.
41. All existing enemy types still function (skeleton, rat, goblin, wolf, bandit, troll, ogre).
42. No new parser errors at startup.
43. No recurring runtime errors during 5 min of mixed combat.
44. Performance acceptable with ~8 enemies on screen.
45. Save format unchanged; pre-Phase-1 save loads correctly.
46. Keyboard, mouse, controller all drive combat correctly.
47. Pause menu opens and resumes cleanly in every combat state.

---

## 9. Risks & rollback considerations

- **Animation method tracks** in existing AnimationPlayer nodes call methods that may move. Mitigation: forwarding methods on `player.gd` with original signatures kept until 1C.3 cleanup; cleanup commit verifies no track still points at a removed method.
- **Two scripts touching `CharacterBody2D.velocity`** (movement + dodge). Mitigation: `DodgeController` writes a request; `player.gd` is the sole writer.
- **`await` callbacks** outliving cancelled state. Mitigation: generation-token guard on every state entry.
- **`Engine.time_scale` getting stuck below 1.0.** Mitigation: `TimeManager` is the only writer (grep guard in CI/manual). Explicit `force_reset()` on all reset sources listed in §3 corr. 3.
- **Grep guard**: a documented one-liner check that no file other than `time_manager.gd` writes `Engine.time_scale`. Run as part of acceptance.
- **Tween / freeze interaction**: paused Tween must resume to the same `attack_progress`; generation-token covers this.
- **Stagger restoring an inappropriate state.** Mitigation: stagger-end re-evaluation hook (corr. 10) — tested at #36.
- **Reaction pivot reparenting risk.** Mitigation: pivot is added by hand only where safe; otherwise transform-only on the existing sprite (corr. 9).
- **Save format drift.** Mitigation: Phase 1 does not touch `SaveLoadManager`.
- **Combo divergence between old and new during 1A.5.** Mitigation: per-attack atomic migration; no parallel-active legacy/new paths in the same commit.

**Per-stage rollback:** every stage is one or a few commits. Reverting any single commit yields a fully playable previous state.

---

## 10. Headless smoke tests (correction 14)

A repeatable automated step run from the command line in addition to manual testing.

### 10.1 Project-parse check
```bash
godot --headless --quit --path /Users/steve/Code/legends-open-rpg 2>&1 | tee /tmp/legends_parse.log
test $(grep -cE "SCRIPT ERROR|Parser Error|ERROR" /tmp/legends_parse.log) -eq 0
```
Run at the end of every stage.

### 10.2 Combat smoke test scene
Add `tests/smoke/combat_smoke.tscn` + `combat_smoke.gd`:
- Instances the player scene.
- Instances one representative enemy scene (skeleton).
- Drives the player through a scripted sequence: A → B → C, dodge, charged release, tap-buffer special, crit-forced hit.
- Asserts no recurring runtime errors over 5 seconds.
- Asserts `Engine.time_scale == 1.0` at end.
- Asserts no orphan nodes leaked.
- Exits with code 0 on success, non-zero on failure.

Run:
```bash
godot --headless --quit-after 600 --path /Users/steve/Code/legends-open-rpg \
  res://tests/smoke/combat_smoke.tscn 2>&1 | tee /tmp/legends_smoke.log
test $(grep -cE "SCRIPT ERROR|ERROR|push_error" /tmp/legends_smoke.log) -eq 0
```

### 10.3 Time-scale ownership grep
```bash
! grep -rn "Engine\.time_scale\s*=" /Users/steve/Code/legends-open-rpg \
  --include="*.gd" | grep -v "scripts/autoloads/time_manager.gd"
```
Exits 0 only when `TimeManager` is the sole writer.

All three run at the end of every stage and at Phase 1 close.

---

## 11. Versioning (correction 13)

- **Every commit bumps `GAME_VERSION` patch** in `scenes/ui/changelog_dialog.gd` and adds one `CHANGELOG` entry, per `CLAUDE.md`.
- Patch-only across all Phase 1 stages — many small bumps from `v0.83.4` upward.
- **No pre-committed minor-version bump.** The decision to mint `v0.84.0` or hold at the next patch happens at Phase 1C close, in the same commit that ships the cleanup + summary. The plan does not contradict the patch-per-commit rule.

---

## 12. Project rules respected

- Patch bump + `CHANGELOG` entry per commit (§11).
- Single new autoload (`HitStopController`); time-scale ownership remains a single autoload (`TimeManager`).
- No mass renames, no formatting churn, no asset modifications.
- `SaveLoadManager` schema unchanged in Phase 1.
- Typed GDScript throughout new code.
- `AudioManager` does not grow combat selection logic (corr. 11).

---

## 13. Out of scope for Phase 1

- New abilities, weapons, enemies, encounters.
- Resource/cost system, status-effect rewrite, vulnerability / armor-break gameplay.
- AnimationTree overhaul, new directional animations.
- **`GPUParticles2D` and `Line2D` effect systems** — Phase 5.
- New particle / trail pool types beyond the existing sprite pool — Phase 5.
- UI / HUD changes beyond damage-number tier tweaks.
- Environment interaction, breakables, hazards.
- Performance profiling sweep (Phase 8).
- Accessibility settings UI (scalars exist; settings screen ships in Phase 8).
- Hand-authored per-enemy flinch animations beyond at most one cheap proof of extensibility.
- Perfect-dodge rewards (detection only in 1C; reward in Phase 2).
