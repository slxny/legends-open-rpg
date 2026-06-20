# Godot Visual Overhaul State

## Objective
Transform Legends Open RPG (Godot 4.6.3 top-down fantasy ARPG, GL Compatibility renderer, main scene `res://scenes/main.tscn`) into a polished, atmospheric, commercially-presented modern indie game with the lush-fantasy painterly pixel-art direction established in v0.93.3. Existing combat, progression, save/load, hero select, regions, and HUD bindings stay intact; presentation is layered around them.

## Current Milestone
Post-v0.93.4 living-world polish complete. The persistent-memory infrastructure (CLAUDE.md marker, `.claude/rules/godot-visual-overhaul.md`, this state file) is now established and self-sustaining. Next-session work would be: regression sweep through pause/death/respawn/save-load + manual world traversal screenshots.

## Completed
- v0.92.9 — Torch-vignette CanvasLayer follows the player; 4 drifting fog ribbons; AttackClock lifetime leak fixed via tween-meta pin; `havens_rest.gd:672` parse error fixed.
- v0.93.0 — Desktop HUD polish: TopBarFrame Panel + gold-leaf inset rule + warm-leather command-card buttons (normal/hover/pressed/disabled) + minimap gold frame.
- v0.93.1 — Hero select atmosphere: torch-vignette CanvasLayer behind cards + 36 ember GPUParticles2D + gold title pulse. Pause menu Backdrop + panel pop-in animation + stronger StyleBoxFlat.
- v0.93.2 — Dungeon Crypt atmosphere: cold ambient (0.46/0.46/0.62) + 14 flickering candle pools + 3 cold fog ribbons + 48 camp blood spatters + 10 cracked-bone debris piles.
- v0.93.3 — Lush fantasy pivot: warm ambient (1.02/1.00/0.88); softer painterly vignette; 3 GIANT ancient trees + 1 floating arch shrine; atmospheric haze stripes hugging every world edge; reduced + softened blood spatter; carved-wood + gold-leaf HUD bottom panel & top-bar layered frame.
- v0.93.4 — Living world: grass / flower / mushroom per-instance wind sway tween; canopy bulb sway on scenic ancient trees; 90-particle ambient pollen GPUParticles2D across the playable area; heal-beacon CYAN halo + 18-particle drifting mote field aura.

## Decisions
- **Art direction**: painterly modern pixel art, lush fantasy ARPG. No mimicry of commercial games.
- **Top-down "sky"**: world bounds get atmospheric haze stripes + mountain horizon silhouettes; there is no vertical sky layer.
- **Ambient**: `BrutalAmbient` CanvasModulate is the global tint knob. Current value warm `(1.02, 1.00, 0.88)`.
- **Vignette**: full-screen `torch_vignette.gdshader` on `CanvasLayer layer=5` (below HUD at 10) tracks player screen-pos via `_process`.
- **HUD chrome**: warm-leather panel + gold border, runtime polish via `_apply_desktop_polish` in `hud.gd` (desktop only — mobile path unchanged).
- **Z-index layering** documented in `.claude/rules/godot-visual-overhaul.md`.
- **Landmarks**: composed from `crystal_white` blob with scale/rotation/modulate. No new generated textures required.
- **AttackClock fix**: RefCounted clocks pinned on `tween.set_meta("_attack_clock_pin", self)`.

## Changed Files
- `scenes/world/world.gd` — torch vignette, fog bands, cloud shadows, edge indicators, brutal ambient grade.
- `scenes/world/torch_vignette.gdshader` — radial vignette, follows player.
- `scenes/world/regions/havens_rest.gd` — river+ponds, dirt paths, mountain horizon, rock outcrops, blood+scorch, scenic landmarks (giant trees + floating arch), atmospheric haze.
- `scenes/world/regions/dungeon_crypt.gd` — cold ambient + candle pools + fog ribbons + bone debris + blood spatter.
- `scripts/components/edge_indicator_layer.gd` — aggro filter + closest-first cap.
- `scripts/combat/attack_clock.gd` — tween-meta lifetime pin.
- `scripts/ui/sc_bar.gd` — rounded bars + sheen + glow rim + pulse.
- `scenes/ui/hud.gd`, `scenes/ui/hud.tscn` — top-bar frame, leather command card, minimap frame, deeper bottom panel.
- `scenes/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn` — backdrop + pop-in animation + StyleBoxFlat upgrade.
- `scenes/hero_select/hero_select.gd` — atmosphere CanvasLayer + embers + title pulse.
- `scenes/enemies/enemy.gd` — outline shader, drop shadow, type halo, idle breathe + wobble, halo combat flare, brutal hit VFX, enemy chromatic variance.
- `scenes/player/player.gd`, `scenes/player/player.tscn`, `scenes/player/hero_outline.gdshader` — outline shader thickness + top-light + rim, hero halo, sparkle trail, drop shadow, camera zoom 4.5x.
- `scripts/autoloads/sprite_generator.gd` — `ground_jungle` 1024² brighter palette, `ground_stone` 512² organic patches, brighter tree canopies.
- `scenes/ui/changelog_dialog.gd` — version bumps and entries through v0.93.3.

## Verified Scenes and States
- Main scene boot through MCP `run_project` → hero select reached. Verified 5× across sessions with no `ERROR:` lines in debug output.
- Game launches into `havens_rest` (player picks hero → main.gd transitions). Combat + drops + minimap minimap.gd region setup all reachable.
- `dungeon_crypt` instantiated by `world.tscn` at world position (0, 15000), reached via fog-of-war traversal.
- Pause menu open/close + animation tested via code path (Backdrop + Panel pop-in).

## Known Issues
- Camera2D physics-interpolation warning at runtime — benign Godot informational.
- Pre-existing GDScript style warnings (integer division, unused vars) in many scripts — not introduced this session.
- Visual verification of in-game world (post-hero-select) requires manual play via MCP launched window; not screenshottable via current MCP API. Trust path: code review + clean debug output.

## Next Actions
1. Run main scene through MCP, drive into gameplay manually, and capture player-walked screenshots of: spawn area, river bend, giant tree landmark, floating arch shrine, mountain horizon, dungeon crypt.
2. Verify HUD layout at 1280×960 (default), 1920×1080, and 720×1280 (mobile-portrait) via project.godot viewport overrides if needed.
3. Polish any inconsistencies surfaced by inspection (texture seams, halo overlap, foreground obstructions of player).
4. Consider a Region 3 (e.g. a sun-touched coastal cliffs biome) only if scope expands; otherwise close the overhaul.

## Last Updated
2026-06-20 — v0.93.4 LIVING WORLD pass shipped & pushed to `origin/main`. Persistent memory infrastructure established and reused.
