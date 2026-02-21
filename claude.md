# CLAUDE.md

Godot 4.x isometric pixel-art RPG. Looks/plays like StarCraft Brood War UMS maps.

## Design Docs — YOU MUST read before coding
- Game systems, economy, world: `GDD.md`
- Visual specs, enemies, items, bosses: `GDD_ADDENDUM_SC_AUTHENTICITY_V2.md`
- **CRITICAL** — Exact visual look to replicate: `VISUAL_REFERENCE.md` (from real game screenshots)

## IMPORTANT: Godot Project Settings (set FIRST)
- Rendering > Textures > Default Texture Filter = **Nearest**
- Rendering > 2D > Snap 2D Transforms to Pixel = **true**
- Rendering > 2D > Snap 2D Vertices to Pixel = **true**
- Display > Window > Viewport Width=640, Height=480
- Display > Window > Stretch Mode=viewport, Aspect=keep

## IMPORTANT: Isometric TileMap
- TileMapLayer: Tile Shape=Isometric, Layout=Diamond Down, Size=64x32
- Y Sort Enabled=true on EVERY TileMapLayer AND parent Node2D
- Layers: Ground(terrain), Objects(trees/walls), Entities(units as Node2D children)

## IMPORTANT: Art Rules
- ALL sprites nearest-neighbor. NO bilinear. NO anti-aliasing. Hard pixel edges.
- Characters: 48x48px, 8 directions. idle=3fr@300ms, walk=6fr@100ms, attack=5fr@80ms
- Hit flash: white shader for 100ms. Shadow ellipse under every unit. Selection circle on ground.

## IMPORTANT: Controls
- Click-to-move (right-click=move/attack). NOT WASD.
- Beacons (colored ground circles) trigger on walk-over with 0.3s delay

## IMPORTANT: UI
- Bottom 25% = dark panel. Left=minimap, Center=portrait+HP/MP, Right=3x3 command card
- Trigger text messages: centered top-screen, colored, fade after 3s

## IMPORTANT: Combat
- damage = ATK - ARMOR (min 1). Zones have FIXED enemy levels. No scaling.

## IMPORTANT: Version & Changelog (do this on EVERY commit)
- **Always** bump the patch version in `scenes/ui/changelog_dialog.gd` (`GAME_VERSION`) and `scenes/hero_select/hero_select.gd` (version button text)
- **Always** add a new entry to the `CHANGELOG` array at the top with a summary of changes
- **Always** include a `"date"` field with today's date (YYYY-MM-DD) on every new changelog entry

## Do NOT
- Use smooth/vector art
- Add quest markers or waypoints
- Scale enemies to player level
- Use WASD as default
- Skip reading GDD.md and GDD_ADDENDUM_SC_AUTHENTICITY_V2.md