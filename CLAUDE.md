# Project Guidelines

## Changelog & Versioning

Every commit must include an update to `scenes/ui/changelog_dialog.gd`:
- Bump `GAME_VERSION` (patch for fixes, minor for features)
- Add a new entry to the top of the `CHANGELOG` array with version, title, date, and entries
- Date format: "YYYY-MM-DD" or "YYYY-MM-DD HH:MM"

The hero select screen (`scenes/hero_select/hero_select.gd`) reads `GAME_VERSION`
automatically via preload — no need to update it separately.
