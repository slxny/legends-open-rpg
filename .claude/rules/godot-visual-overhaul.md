# Godot Visual Overhaul — Operating Rules

Durable standards for the ongoing visual transformation of this top-down Godot 4
fantasy ARPG (Godot 4.6.3, GL Compatibility renderer, main scene `res://scenes/main.tscn`).

## Mode of work

- Implementation first. Avoid producing audits, plans, or proposals unless asked.
- Inspect only enough of the scene/script/resource you are about to change.
- Use Godot MCP (`mcp__godot__run_project`, `get_debug_output`, `stop_project`) to verify every meaningful visual change. A change isn't done until it has been run.
- After each verified milestone, update `docs/claude/godot-visual-overhaul-state.md`.
- Before ending a session, leave the state file accurate.

## Preserve gameplay

- Never break: controls, physics, collision, combat (stamina/positional/charged slash/shockwave), abilities, enemies, hazards, drops, progression, save/load, scene transitions, hero select flow.
- Do not change node paths or unique names that `hud.gd`, `player.gd`, `world.gd`, region scripts, or autoloads depend on. When in doubt, layer new visual nodes around stable gameplay nodes.
- Never alter gameplay numbers (HP, damage, cooldowns, speeds) without an explicit user ask.

## Visual direction

- One coherent art language: painterly modern pixel art, original fantasy ARPG identity.
- No copies of existing commercial games' characters, landmarks, or compositions.
- Reserve highest contrast + accent saturation for player, enemies, hazards, interactables, key HUD.
- Distant scenery: lower contrast, lower saturation, softer edges, cool atmospheric tint.
- Top-down genre: "sky" = atmospheric haze + sky-band gradient at world bounds above mountain horizon silhouettes. There is no true vertical sky.

## Scene composition

- Layer the world: ground tile → painted blob overlays → blood/scorch/decor → cloud shadows → rocks/landmarks → mountain horizon → atmospheric haze → torch vignette → HUD.
- Z-index conventions in use (havens_rest):
  - `-10` ground tile
  - `-9` creep / blood / dirt patches
  - `-8` river/pond/water-blob, ambient blood blobs
  - `-7` foliage decor, atmospheric haze, mountain far layer
  - `-6` cloud shadow, mountain haze layer, decor shadow puddles, candle pools
  - `-5` rock outcrops, tree trunks
  - `-4` halos, tree canopy bulbs
  - `-3` drop shadows
  - `0..5` gameplay actors
- Region `_generate_terrain_async` already awaits frames between batches. Keep that batching when adding new scatter passes.

## Player & enemy presentation

- Both use the `_outline_shader` / `hero_outline.gdshader` pair: 2-px outline + top-light (top_lift / bottom_dim) + warm sun rim. Don't replace; tune uniforms.
- Drop shadow + type halo + idle breathe + wobble + sparkle trail are wired in `enemy.gd._ready` and `player.gd._ready`. Don't duplicate.
- `_ensure_outline_material`, `_ensure_drop_shadow`, `_ensure_type_halo`, `_start_enemy_idle_breathe` are idempotent — extend rather than recreate.

## HUD & menus

- HUD chrome: warm-leather panel (`StyleBoxFlat_panel` in `hud.tscn`) + gold border + drop shadow. Bars use rounded `sc_bar.gd` with gradient fill, sheen, glow rim, low-HP pulse. Don't reintroduce flat default Godot styling.
- Top bar uses runtime `_apply_desktop_polish` to add a TopBarFrame + gold-leaf inset and skin the command-card buttons. Mobile path is separate; preserve it.
- Pause menu uses `Backdrop` ColorRect + pop-in animation. Keep.

## Lighting & atmosphere

- Ambient is controlled by `BrutalAmbient` CanvasModulate in `world.gd`. Current target: painterly sun-touched `(1.02, 1.00, 0.88)`. Keep it warm.
- Torch vignette is a screen-space shader on a `CanvasLayer layer=5` (below HUD at 10). Don't move above HUD.
- Region modulate is the fastest way to give a region biome identity (e.g. `dungeon_crypt.gd modulate = Color(0.46, 0.46, 0.62)` for cold crypt). Use it.

## Performance discipline

- Renderer is GL Compatibility (web/mobile friendly). Avoid Forward+-only features.
- Reuse `crystal_white` + `terrain_blob` + existing generated textures with scale/rotation/modulate before generating new textures.
- GPU particles capped (motes 80, sparkles 24, embers 36). Don't push counts up without reason.
- Texture sizes: `ground_jungle` 1024² and `ground_stone` 512² are the current ceiling. Going larger doubles VRAM.
- Use `await get_tree().process_frame` inside long scatter loops (already the convention in `_generate_terrain_async`).

## Bug-fix conventions

- `AttackClock` (RefCounted) must be pinned via `tween.set_meta("_attack_clock_pin", self)` to avoid "Lambda capture at index 2 was freed".
- Camera2D physics-interpolation warning is benign.
- Pre-existing GDScript style warnings (integer division, unused-vars) are not regressions; only fix ones I introduce.

## Version control

- Check `git status` before broad edits.
- Bump `GAME_VERSION` + add a CHANGELOG entry in `scenes/ui/changelog_dialog.gd` per CLAUDE.md.
- Push to `origin/main` (the user has authorized this in active sessions; ask if classifier blocks).
- Never `git reset --hard`, `git push --force`, or wipe untracked files.

## Useful repo facts

- Godot version: **4.6.3 stable, GL Compatibility renderer**.
- Main scene: `res://scenes/main.tscn`. Boot order: `main.tscn` → `hero_select.tscn` → `world.tscn` (instances `havens_rest.tscn` + `dungeon_crypt.tscn`).
- Player has its own camera (`scenes/player/player.tscn Camera2D zoom = 4.5`).
- Edge indicator layer (`scripts/components/edge_indicator_layer.gd`) shows red arrows for aggro'd enemies only (CHASE/ATTACK), capped at 5 closest, radius 720 px².
- Region scene script entry points: `_generate_terrain_async` (havens) and `_generate_terrain` / `_spawn_dungeon_atmosphere` (crypt).
