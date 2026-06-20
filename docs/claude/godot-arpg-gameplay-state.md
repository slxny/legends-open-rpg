# Godot ARPG Gameplay Overhaul State

## Objective
Comprehensively revise, deepen, polish, rebalance, and expand the existing top-down ARPG (Legends Open RPG, Godot 4.6.3, GL Compatibility) until the moment-to-moment experience approaches the responsiveness, density, build depth, encounter quality, loot satisfaction, dungeon pacing, and replayability expected from a polished modern hack-and-slash. Existing systems count as a BASELINE only; each must be inspected, tested in real gameplay, weaknesses identified, and improvements made & re-verified before being counted complete.

## Current Milestone
Milestone 1 — individual skill architecture. Replacing the shared `_attack_cooldown` shortcut with real per-skill runtime state, per-class hot-bar labels, and per-skill HUD readouts. Subsequent milestones (combat feel, class kits, enemy revision, elite, boss, loot, progression, dungeon pacing, difficulty, HUD integration, audio/effects, save compatibility) explicitly NOT YET STARTED.

## Completed and Verified
(Only systems tested during actual gameplay and confirmed correct. No entries should land here based on clean boot alone.)

- *None for the gameplay overhaul yet.* Prior visual / atmospheric / hit-FX commits (v0.92.9 … v0.93.4) shipped & MCP-clean-boot-verified, but those are out of scope for this overhaul; they are documented in `docs/claude/godot-visual-overhaul-state.md`.

## Preliminary changes (NOT verified in gameplay)
- v0.93.5 added Z X C V input actions firing the existing `SpecialAttack` enum via `_try_special_attack`, plus 4 HUD slots with a SHARED cooldown dim overlay. Status:
  - Code path exists and parses (MCP `run_project` → hero select reached, zero `ERROR:` lines).
  - Direct in-game test of pressing Z/X/C/V during combat: **not performed**; MCP can launch but cannot drive input.
  - Skill labels are class-agnostic placeholder strings ("Strike / Whirl / Dash / Heavy") — wrong for ranger.
  - Cooldown UI is shared, not per-skill — temporary shortcut.

## Gameplay Decisions
- ARPG identity preserved: top-down, mouse-aim, WASD movement, stamina-gated mash, perfect-dodge counter, panic-button shockwave (Q).
- Damage pipeline authoritative through `CombatManager.resolve_hit`. Positional multiplier baked in (back 1.5×, flank 1.25×).
- Hit-stop owner: `HitStopController` → `TimeManager`. Single Engine.time_scale writer (verified via grep guard).
- Hot-bar keys: Z X C V (chosen because 1/2/3 already bind to potion consumables in `player.gd._input`).

## Existing systems inventory (baseline)
See `.claude/rules/godot-arpg-gameplay.md` for the durable list. Headline entries:
- Player controller, dodge, charged slash, shockwave, status effects, hit-stop.
- 17+ enemy types, elite modifiers (haste / armored / exploder / berserker / healer / shocking), attack patterns (standard / triple_stab / slam / charge), AttackCoordinator token budget.
- Item rarity tiers (`ItemData.RARITY_COLORS`), affix system, inventory, equipment, stat aggregation.
- XP / level / UpgradeManager (1 random behaviour-changing upgrade per level).
- Two playable regions: `havens_rest` outdoor + `dungeon_crypt` underground.
- Save/load via `save_load_manager.gd`.
- HUD with HP/Mana/XP rounded bars + command card + minimap.

## Changed Files
- Visual overhaul commits: documented in `docs/claude/godot-visual-overhaul-state.md`.
- v0.93.5 gameplay-preliminary: `project.godot`, `scenes/player/player.gd`, `scenes/ui/hud.gd`, `scenes/ui/changelog_dialog.gd`, this state file, `.claude/rules/godot-arpg-gameplay.md`, `CLAUDE.md`.

## Test Content
- `tests/smoke/combat_smoke.tscn` — headless combat regression (HitEvent / status / power_strike consumes exposed). Currently passes.
- Two playable regions in real game (`havens_rest`, `dungeon_crypt`).

## Verified Scenarios
(Each row should include: scene, mechanics, expected, observed, debugger result.)

| When | Scene | Mechanic | Method | Result |
|---|---|---|---|---|
| v0.93.5 | main.tscn → hero_select.tscn | Project parse + autoload init | MCP `run_project` + `get_debug_output` | Reaches hero select. Zero `ERROR:` lines. Pre-existing `WARNING:` lines only. |
| v0.93.5 | Skill input bindings | Press Z/X/C/V in combat | NOT PERFORMED (MCP can't drive input) | Pending user playtest or scripted input harness. |
| v0.93.5 | HUD skill bar | Cooldown dim toggles on swing | NOT PERFORMED | Pending user playtest. |

## Known Issues / Honest Limitations
- **MCP launch ≠ gameplay validation.** Godot MCP `run_project` opens the editor-driven debug runtime but does not accept programmatic input. Real combat behaviour testing requires the user playing the running window or a scripted input harness that I have not yet built.
- **Shared `_attack_cooldown` on specials is wrong.** Once any special fires, all four hot-bar skills appear unavailable for the same duration. Foundational fix needed before further build-depth work.
- **Skill labels in the hot-bar are class-agnostic placeholders.** The ranger should see PIERCE / RAIN / DASH / SNIPE not STRIKE / WHIRL / DASH / HEAVY.
- **No actual gameplay testing has yet been performed against** normal packs, dense packs, ranged-heavy packs, elites with modifier combinations, the boss, dungeon traversal, death/respawn, loot drops, item comparison, save reload of generated items, controller input, multiple viewport sizes.
- **Damage type field on `HitEvent` is unpopulated.** Pipeline supports it; no skill data carries it; enemies have no resistance tables.
- **Enemy attack-pattern review pending** — current pattern set is the baseline triple_stab / slam / charge; no per-family role composition exists (swarm/melee/ranged/heavy/support/controller).
- **No multi-phase boss encounter exists.** Lich / dungeon mini-bosses are buffed standard enemies.
- **No difficulty scaler** beyond enemy-level scaling.
- **No tooltip system** surfaces calculated values.
- **No loot beam** for rare drops.

## Active milestones
1. **In progress** — per-skill cooldown architecture in `player.gd` (this session).
2. **In progress** — per-class hot-bar labels + per-skill HUD readout.
3. Pending — combat feel / responsiveness audit (animation cancel windows, input buffer tuning, attack startup/recovery).
4. Pending — enemy behaviour revision (separation, telegraph accuracy, role composition per pack).
5. Pending — elite modifier audit + new modifiers + counterplay testing.
6. Pending — boss revision (multi-phase, telegraphs, anti-stunlock).
7. Pending — loot / item-power / affix / build-power audit + revision.
8. Pending — progression: skill ranks, passives, build paths × 3 per class.
9. Pending — dungeon pacing revision (encounter composition, checkpoint placement, objective clarity).
10. Pending — difficulty scaler revision (density / elite freq / loot quality / boss patterns).
11. Pending — HUD integration (real skill names + per-skill cooldowns + tooltips).
12. Pending — audio / effect differentiation (light hit vs heavy vs crit vs elite vs boss).
13. Pending — save versioning + generated-item persistence verification.

## Next Actions
1. Implement `_skill_cooldowns: Dictionary[StringName, float]` + `_skill_max_cooldowns` in `player.gd`. Per-special duration sourced from `AttackTimingsCls.<id>().duration_sec` where available; falls back to a constant table for the few that don't (e.g. `whirlwind` already returns it).
2. Tick all skill cooldowns in `_physics_process(delta)`.
3. Add `get_hotbar_skill_ids()` and `get_hotbar_skill_labels()` returning class-branched arrays.
4. Modify `_try_special_attack(special)` to check the per-skill cooldown not the shared `_attack_cooldown`. Pop a floating "READY IN X.Xs" when blocked.
5. Update each `_execute_<special>` to record the cooldown in `_skill_cooldowns` after firing.
6. Update HUD to read skill IDs/labels from player and render per-slot vertical fill from bottom (full = cooldown start, empty = ready) using the existing ColorRect; add a small label showing remaining seconds.
7. MCP `run_project` + `get_debug_output` to confirm clean parse / clean boot.
8. Document explicitly which scenarios remain unverified due to MCP input limitations.

## Last Updated
2026-06-20 — Retracted premature completion language. v0.93.5 reclassified as preliminary patch. Began Milestone 1.
