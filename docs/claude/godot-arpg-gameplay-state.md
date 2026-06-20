# Godot ARPG Gameplay Overhaul State

## Objective
Legends Open RPG (Godot 4.6.3, GL Compatibility) is already a working top-down loot-driven action RPG with combat, classes, skills, items, regions, save/load, and progression. The "ARPG gameplay overhaul" reduces to gap-filling on the existing systems — specifically surfacing buried skills via a 1-4 hot-bar with on-HUD cooldowns, adding damage-type tagging, skill-rank progression, difficulty scaling, multi-phase bosses, calculated-value tooltips, and rare-loot pickup beams.

## Current Milestone
v0.93.5 shipped. Next milestone: damage-type tagging + per-skill cooldowns + tooltip overlay on the skill bar.

## Completed and Verified
- v0.92.5 → v0.92.8: combat brutalisation pass — bigger sparks, blood gibs, shockwave rings on crit, harder camera shake, charged slash rework (3× / 360 knockback / golden shockwave), enemy HP at 65 %.
- v0.93.0 → v0.93.4: visual / atmosphere passes shipping the lush-fantasy direction (scenic landmarks, atmospheric haze, carved-wood HUD, wind sway, ambient pollen, heal-beacon aura, AttackClock lifetime fix).
- All boots verified clean via Godot MCP `run_project` + `get_debug_output` after each commit.

## Gameplay Decisions
- ARPG identity: top-down, mouse-aim, WASD movement, stamina-gated mash, perfect-dodge counter, panic-button shockwave.
- Loot: gold auto-magnet within 105 px; pickup beam reserved for future rare/epic+ drops.
- Damage pipeline authoritative through `CombatManager.resolve_hit`. Positional multiplier baked in (back 1.5×, flank 1.25×).
- Hit-stop owner: `HitStopController` → `TimeManager`. Single Engine.time_scale writer.
- Visual direction: painterly modern pixel-art lush fantasy. Decided in `docs/claude/godot-visual-overhaul-state.md`.

## Changed Files
- See `docs/claude/godot-visual-overhaul-state.md` for the visual-overhaul changelog of files.
- `CLAUDE.md`, `.claude/rules/godot-arpg-gameplay.md`, this file — added this session.

## Test Content
- `tests/smoke/combat_smoke.tscn` — headless combat regression (HitEvent / status / power_strike consumes exposed). Must keep passing.
- Two playable regions: `havens_rest` (outdoor melee + ranged) and `dungeon_crypt` (lvl 10+ dungeon with elites + mini-bosses).
- Multiple hero classes via `HeroData`.

## Verified Scenarios
- Main scene boot → hero select reached — every commit this session.
- Combat smoke test passes (`combat_smoke.gd` PASS lines + final `[combat_smoke] OK`).
- Player + enemy spawn, HP/Mana/XP bars render at gameplay zoom, atmosphere layers (vignette / fog / motes / pollen) all instantiated without errors.

## Known Issues
- Damage type field present on `HitEvent` but most attacks pass empty / `physical`.
- Skill bar shows a SHARED cooldown overlay (driven by `_attack_cooldown`), not per-skill cooldowns. Adequate for v0.93.5; per-skill needed for richer build feel.
- Skill names on the hot-bar slots are generic ("Strike / Whirl / Dash / Heavy") — should be derived from `hero_class` so ranger shows "Pierce / Rain / Dash / Snipe".
- Pre-existing GDScript style warnings (integer division, unused vars) are not regressions.

## Next Actions
1. Per-skill cooldown tracking: add a `_skill_cooldowns: Dictionary[SpecialAttack, float]` in `player.gd`, tick it in `_physics_process`, and surface remaining seconds to the HUD via a public getter.
2. HUD skill bar: read those per-skill values + render a CCW radial sweep or fill bar instead of the current shared dim.
3. Localise the slot names per hero class so the labels match what fires.
4. Damage-type tagging: enumerate `physical / fire / frost / lightning / poison / shadow / arcane` in `combat_manager.gd`, assign per-AttackTimings, plumb resistances on `enemy.gd`.

## Last Updated
2026-06-20 — v0.93.5 ARPG HOT-BAR shipped: Z/X/C/V skill keys + on-HUD skill bar with cooldown dim. Memory infrastructure complete.
