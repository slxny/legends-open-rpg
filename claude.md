# Project Guidelines

## Changelog & Versioning

Every commit must include an update to `scenes/ui/changelog_dialog.gd`:
- Bump `GAME_VERSION` (patch for fixes, minor for features)
- Add a new entry to the top of the `CHANGELOG` array with version, title, date, and entries
- Date format: "YYYY-MM-DD" or "YYYY-MM-DD HH:MM"

The hero select screen (`scenes/hero_select/hero_select.gd`) reads `GAME_VERSION`
automatically via preload — no need to update it separately.

<!-- BEGIN GODOT VISUAL OVERHAUL -->

## Godot Visual Overhaul

- Use Godot MCP to run, inspect, screenshot, and debug every substantial visual change.
- Favor direct implementation over planning or recommendations.
- Preserve established gameplay, controls, collisions, progression, save compatibility, and scene behavior.
- Never declare visual work complete without running and visually checking the affected scene.
- Maintain one coherent fantasy art direction across gameplay, UI, effects, and menus.
- Preserve unrelated user changes and avoid destructive Git operations.
- Read `docs/claude/godot-visual-overhaul-state.md` before continuing this redesign.
- Update that state file after each completed milestone and before ending a session.
- Follow `.claude/rules/godot-visual-overhaul.md` for detailed visual and technical standards.

<!-- END GODOT VISUAL OVERHAUL -->

<!-- BEGIN GODOT ARPG GAMEPLAY OVERHAUL -->

## Godot ARPG Gameplay Overhaul

- The project IS already a fast top-down loot-driven action RPG (Diablo / Torchlight family). The gameplay overhaul is an incremental gap-fill, not a conversion.
- Use Godot MCP to run and validate every substantial gameplay change.
- Combat must prioritize responsiveness, clear telegraphs, enemy density, build variety, loot excitement, and strong feedback.
- Preserve unrelated project work and avoid destructive Git operations.
- Do not claim a system is complete until it has been tested during actual gameplay.
- Read `.claude/rules/godot-arpg-gameplay.md` before continuing gameplay work.
- Read `docs/claude/godot-arpg-gameplay-state.md` before resuming the overhaul.
- Update the gameplay state file after each verified milestone and before ending a session.

<!-- END GODOT ARPG GAMEPLAY OVERHAUL -->


