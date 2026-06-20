# Godot ARPG Gameplay Overhaul — Operating Rules

The project is ALREADY a working top-down loot-driven action RPG (Godot 4.6.3,
GL Compatibility renderer). Treat all "convert to ARPG" framing as gap-filling
on existing systems, never rebuild from scratch.

## Existing systems (do not duplicate)

- **Movement**: WASD 8-direction in `scenes/player/player.gd`. Mouse aiming + tap-aim. Camera follow at 4.5× zoom.
- **Combat**: tap Space = basic strike. Hold Space ≥ 0.8 s = CHARGED_SLASH (3× damage, 360 knockback, golden shockwave). Tap directional combos trigger specials: POWER_STRIKE, WHIRLWIND, DASH_STRIKE, ARROW_RAIN, PIERCING_SHOT, SNIPER_SHOT, plus class-specific kits.
- **Resource**: STAMINA (max 100, regen 26/s + 50 % idle bonus, swing cost 18). Exhausted swings 40 % damage + 70 % slower with "EXHAUSTED!" popup.
- **Evade**: dodge controller in `scenes/player/dodge_controller.gd`. Shift / right-trigger. Perfect-dodge window opens a 1 s counter-window (+60 % damage, kill-chain target lock).
- **Panic button**: Q = SHOCKWAVE PULSE (220 px AOE knockback, 0.45 s i-frames, 6 s cooldown).
- **Positional damage**: behind-hit forces crit + 1.5×, flank hit +1.25×, frontal baseline (`combat_manager.gd resolve_hit`).
- **Damage pipeline**: `scripts/autoloads/combat_manager.gd` is authoritative. `HitEvent` + `HitResult` Resources. Use `CombatManager.resolve_hit(event, attacker_stats, defender_stats)`.
- **Status effects**: exposed / bleed / mark via `scripts/components/status_effect_component.gd` + `apply_status` / `consume_status_tier`.
- **Hit-stop**: `HitStopController` autoload routes through `TimeManager` (single Engine.time_scale owner).
- **Enemies**: `scenes/enemies/enemy.gd` shared script. 17+ types. Elite system: haste / armored / exploder / berserker / healer / shocking. Mini-boss tier. Attack patterns: standard / triple_stab / slam / charge. AttackCoordinator token-budget prevents synchronous swings.
- **Telegraphs**: floor arc / radial circle, 22 % chance per-swing for medium enemies to surprise-roll into a slam.
- **Loot**: gold pickup + item drops with `ground_items` group. Auto-magnet 105 px / 480 px/s.
- **Items**: `scripts/data/item_data.gd` + rarity tiers (RARITY_COLORS map). Affix system via `ItemData`.
- **Inventory**: `scripts/components/inventory_component.gd`. Slots + equipment.
- **Stats**: `scripts/components/stats_component.gd` aggregates base + equipment + buffs.
- **Progression**: XP / level via `GameManager` + `UpgradeManager` (1 random behavior-changing upgrade per level).
- **Regions**: `havens_rest` (outdoor combat) + `dungeon_crypt` (lvl 10+ underground).
- **Save/load**: `scripts/autoloads/save_load_manager.gd`.
- **HUD**: `scenes/ui/hud.tscn` + `hud.gd`. HP/Mana/XP bars (rounded sc_bar.gd with sheen + glow + pulse). Command card with potion slots + inventory/save/load. Minimap. Combat juice layer overlays combo counter + momentum bar + floating text.
- **Hero select**: `scenes/hero_select/hero_select.gd` with multiple `HeroData` classes.
- **Audio**: `AudioManager` autoload with per-sound cooldowns + pitch jitter + volume offsets + reactive music intensity ducking.

## Genuine gaps to close

- **Hot-bar 1-4** keys with on-HUD cooldown overlay. Specials are currently buried behind input-direction taps.
- **Damage type tagging** on attacks + resistances on enemies (the pipeline supports it; the data isn't populated).
- **Skill-rank progression**: pick which special to upgrade on level-up.
- **Difficulty scaling**: enemy density / elite rate / loot quality knob.
- **Per-region boss encounter** with multi-phase patterns.
- **Tooltip system** that surfaces calculated values (damage / cost / cooldown).
- **Loot beam** + minimap pin for rare drops.

## Implementation discipline

- Add NEW gameplay layers on top of existing autoloads and components. Don't rebuild `combat_manager.gd`, `enemy.gd`, `player.gd`.
- New input actions go in `project.godot` AND `_input` handling in `player.gd` (preserve `_input_unhandled` separation if it exists).
- New skills should be `AttackTimings` resources + an entry in `SpecialAttack` enum + a branch in `_try_special_attack` (or via a dedicated dispatcher).
- Bump `GAME_VERSION` + changelog per CLAUDE.md.

## Verification

- Run via Godot MCP after each meaningful change.
- Watch debug output for `ERROR:` lines only — pre-existing warnings are noise.
- Smoke test at `tests/smoke/combat_smoke.tscn` must keep passing.
- Grep guard: only `TimeManager` may write `Engine.time_scale`.

## Save compatibility

- Versioned save data via `save_load_manager.gd`. When adding new fields (e.g. hot-bar binding), default safely on missing keys.
- Never wipe an existing save during migration.
