# VISUAL_REFERENCE.md — Exact Visual Specs From Real Legends Open RPG Screenshots

Claude Code: THIS is what the game must look like. Every detail below comes from actual screenshots of the game we're replicating. When in doubt, match these specs exactly.

---

## 1. THE SC:BW UI FRAME (the bottom panel)

The UI is NOT a flat rectangle. It's a **decorative metallic frame** that wraps the bottom and sides of the screen.

### Layout (from screenshots):
```
Screen top-left:  "🟥 53 Kills" — red square + kill counter, white text, always visible
Screen top-right: "💎 38739  🟢 30000  📦 0/8" — minerals, gas, supply icons + numbers

Game viewport takes up ~70% of screen height

Bottom frame:
┌─────────────┬────────────────────────────┬──────────────────┐
│  MINIMAP     │    UNIT INFO PANEL          │  COMMAND BUTTONS  │
│  (square,    │                             │                   │
│  dark,       │  Unit Name (colored)        │  MENU button      │
│  shows       │  Class/Title                │                   │
│  terrain     │  Kills: 0                   │  Action buttons   │
│  as tiny     │                             │  (yellow circles  │
│  colored     │  [Wireframe   ] [Item][Item]│   with arrows/X)  │
│  pixels)     │  [Portrait    ] [ 0 ][ 0 ] │                   │
│              │  HP: 500/500 (colored)      │  [Portrait of     │
│              │                             │   advisor/face]   │
└─────────────┴────────────────────────────┴──────────────────┘
```

### Frame visual style:
- **NOT flat colored panels** — it's a textured metallic blue/gold SC:BW Remastered frame
- Dark blue-black base (#0a0f2a) with **gold/bronze trim** along all edges
- The frame has **beveled 3D metallic edges** — raised gold bars separating sections
- Top of the frame has a **decorative gold zigzag/crown pattern** (visible in all 3 screenshots as the gold sawtooth strip along the top edge of the panel)
- The minimap area has its own recessed dark box
- The unit info area has a recessed dark box with slight blue tint
- The command area has a recessed dark box

### For our Godot game:
- Create a **PNG frame image** (or 9-patch) that mimics this look
- The frame sits on a CanvasLayer, always on top
- Game viewport renders BEHIND the frame in the open area
- Use a dark blue-black base with gold/bronze accent lines
- The aesthetic is "sci-fi military console" not "fantasy parchment"

---

## 2. UNIT INFO PANEL (bottom center)

### What it shows (from Screenshot 2 - "Pernon the Poisonous"):
- **Unit name:** "Pernon the Poisonous" — the word "Poi" is in RED text, rest is white. Names can have colored substrings for emphasis.
- **Wireframe portrait:** LEFT side shows a green wireframe drawing of the unit (like SC:BW's unit wireframe — NOT a photo, NOT pixel art face. It's a technical line drawing showing the unit's silhouette in green (#00ff00) lines on black background)
- **HP display:** Below portrait: "500/500" in RED text (SC:BW shows Zerg HP in red, Terran in green, Protoss in blue/cyan)
- **Kills counter:** "Kills: 0" in white text
- **Item slots:** Two small square boxes to the right of the portrait, each showing a small icon and a "0" count below. These are inventory/equipment slots.

### What it shows (from Screenshot 3 - "Goblin Marshal"):
- **Name:** "Goblin" in GREEN text (unit's player color)
- **Title:** "Marshal" on second line, white
- **Kills:** "0" 
- **Wireframe:** Green SC Marine wireframe (because the Goblin unit is using a Marine sprite)
- **HP:** "123/123" in green (Terran-style)
- **Item slots:** Two slots, both showing "0"

### What it shows (from Screenshot 1 - "Townsman"):
- **Name:** "Townsman" in white
- **Wireframe:** Green Marine wireframe
- **HP:** Single blue bar (looks like a small health segment indicator)
- **One item slot** visible with "0"

### For our Godot game:
- Unit portrait = a **wireframe-style line drawing** of the unit, green lines on black. This can be a pre-drawn sprite per unit type, or even just the unit's sprite rendered in monochrome green.
- HP shown as colored text "current/max" — color matches faction (green for human heroes, red for monster heroes)
- Kill counter always visible
- 2-4 item/ability slots shown as small dark squares with icons

---

## 3. TOP-LEFT: KILL COUNTER
- Small colored square (player's color — red in screenshots) + "X Kills" in white text
- Always visible, top-left corner
- Updates immediately on kill

## 4. TOP-RIGHT: RESOURCES
- **Minerals icon** (blue crystal) + number (e.g., "38739") — this is GOLD in our game
- **Gas icon** (green gas) + number (e.g., "30000") — this is MANA or secondary resource
- **Supply icon** (box/crate) + "0/8" — this is unit count / max units
- All white text, right-aligned, with small icons before each number
- In SC:BW Remastered these icons are small colored sprites (~16x16)

---

## 5. COMMAND BUTTONS (bottom right)

### From the screenshots:
- **"MENU" text** in white, centered above the button area
- **Large circular buttons** with symbols:
  - Yellow circle with green RIGHT ARROW (➡) = Move/Patrol
  - Yellow circle with red X (✕) = Stop/Cancel
  - More buttons below in a grid
- **Advisor portrait:** Bottom-right corner shows a realistic face portrait (Jim Raynor, Overmind advisor, etc.) — in SC:BW this is the race advisor. For our game this would be the hero's face portrait.
- Buttons are arranged in roughly a 2x3 or 3x3 grid

### For our Godot game:
- Bottom-right section has **circular** or **rounded square** ability buttons (not flat squares)
- Each button has a small icon inside (sword, shield, potion, etc.)
- A character portrait in the bottom-right corner (drawn pixel art face of current hero)
- "MENU" button for game options

---

## 6. TERRAIN — What the Ground Actually Looks Like

### Screenshot 1 (Ice/Snow area):
- **Base terrain:** White/light gray snow with subtle texture variation — NOT flat white, has bumps and shadows making it look like real snow cover
- **Cliff faces:** Dark gray-brown rock walls running diagonally (NE-SW direction). The cliffs have clear **vertical face** sprites showing rock layers, with snow on top.
- **Cliff shadows:** Darker area at the base of cliffs
- **Ground is NOT a grid of obvious tiles** — the terrain blends smoothly between tiles. Tile edges are invisible. It looks like one continuous painted surface.

### Screenshot 2 (Dirt/Badlands area):
- **Base terrain:** Brown dirt/mud (#6b5b3a to #8a7a5a) with heavy texture — cracks, pebbles, grain visible
- **Grass patches:** Small green grass tufts (#3a5a2a) scattered irregularly on the dirt
- **Snow patches:** White blobs along the bottom edge (terrain transition between biomes)
- **Structures:** A large Zerg Hatchery (dark organic shape) in top-left, with a blue beacon glow near it
- **Terrain is richly textured** — every tile has internal detail, not flat colored diamonds

### Screenshot 3 (Mixed Ice/Dirt with Cliffs):
- **Two terrain types meeting:** Brown dirt (bottom-left) transitions into white snow (right side)
- **Cliff faces:** VERY prominent dark gray/charcoal stone cliffs with jagged edges, icicles hanging from top edges, snow accumulated on ledges
- **Dead trees:** Bare black tree trunks/branches as doodads on the snow, ~48px tall
- **Broken pillars/logs:** Brown cylindrical objects on the ground (doodads)
- **Blood splatter:** Red sprites on the ground where enemies died — small (16x16) red blobs that persist for a while
- **Water/ice:** Dark teal area visible in bottom-left (frozen lake or dark water edge)

### CRITICAL terrain rule:
**The terrain does NOT look like a grid of colored diamonds.** It looks like a painting. Tiles blend into each other with smooth transitions. The isometric grid is invisible to the player — you only see natural-looking terrain. This means:
- Tiles need **edge-blending/transition tiles** between terrain types (grass-to-dirt, snow-to-dirt, etc.)
- Each tile type needs 4-8 variants to avoid repetition
- Cliff faces are drawn as **separate sprites** overlaid on the cliff-top tiles

---

## 7. UNITS — What Characters Look Like

### From the screenshots:

**Hero unit (Screenshot 2 — "Pernon the Poisonous"):**
- It's a Zerg Mutalisk sprite — medium sized (~40x40px at native res), red-colored (player color)
- Has a **green selection circle** (flat ellipse) on the ground beneath it
- Has a **green HP bar** below the selection circle — small, segmented, bright green
- The unit sprite is detailed pre-rendered pixel art — not flat vector shapes

**Hero unit (Screenshot 3 — "Goblin Marshal"):**
- Uses SC Marine sprites, but colored green/dark (custom color)
- Multiple marines in a group — these are the player's army units
- Each has selection circles and HP bars
- Weapons visible (gun sprite held by marine)
- Scale: ~32x32px per unit at native resolution

**Enemy units (Screenshot 2 — Blue Marines):**
- Blue-colored Marine sprites scattered around the map
- Groups of 3-5 standing idle
- NO selection circles visible (enemies don't show circles until you click them)
- They're just standing in the world, menacingly

**Hero selection units (Screenshot 1):**
- Zealots (large gold/yellow armored figures, ~40x48px)
- Goliaths (smaller mechanical walkers)
- Marines
- A flying unit (Mutalisk) in top-left
- Each standing near a beacon

**Dead units (Screenshot 3):**
- Red blood splatter sprites on the ground (~16x24px)
- Corpse sprites (collapsed unit shapes) visible briefly before fading to just blood

### CRITICAL unit rule:
**Units are pre-rendered 3D-looking pixel art, NOT flat colored shapes.** They have shading, highlights, metallic reflections, organic textures. Even as placeholder art in Godot, aim for at least recognizable silhouettes with some internal shading — not just colored rectangles.

---

## 8. BEACONS — The Big Glowing Pads

### From Screenshot 1 (clearest view):
These are **LARGE** — much bigger than I described before. Each beacon is roughly **96x48 pixels** at native resolution (about 1.5 tiles wide).

**Beacon visual details:**
- **Oval/elliptical shape** matching the isometric ground plane
- **Metallic/technological look** — NOT a simple colored circle
- Dark brown/bronze base with **glowing cyan/teal energy lines** (#00ccff) running in a pattern (cross/diamond pattern visible in the center)
- **Four spherical "nodes"** at the N/S/E/W points of the ellipse — dark metallic balls with cyan glow
- The cyan glow **pulses/animates** — gives off light
- **Overall impression:** Looks like a futuristic teleportation pad or landing platform

### For our Godot game:
- Beacons should be **large, detailed oval sprites** (~96x48px) sitting on the ground
- They should look technological/magical — glowing energy patterns on a metal base
- Color the glow based on beacon type (cyan for selection, green for heal, yellow for shop, red for danger)
- Animate the glow (pulse brightness) with a 1-2 second cycle
- They should be obvious and inviting — these are the main interaction points, players need to see them immediately

---

## 9. TRIGGER TEXT (center screen messages)

### From Screenshot 2:
- "Cheat Enabled" appears as **white text, centered horizontally, at roughly 60% down the viewport** (just above the UI frame)
- The text is SC:BW's standard message font — medium size, clean pixel font
- **No background box** — text floats directly over the game world
- **Black outline/shadow** on the text for readability over any terrain

### For our Godot game:
- Trigger text = white (or colored) pixel font text, centered, no background
- Position: center-screen horizontally, upper-middle vertically (above the action but below the resource bar)
- 2px black outline for readability
- Fades after 3-4 seconds

---

## 10. MINIMAP (bottom-left)

### From all screenshots:
- Small dark recessed square, roughly 128x128px in the frame
- Shows the **entire map as tiny colored pixels:**
  - Terrain colors compressed (brown = dirt, white = snow, green = grass, dark = cliffs)
  - Your units show as small bright dots (green/white)
  - Enemies show as red dots
  - The currently visible viewport is shown as a small **white rectangle outline**
- Very simple, very functional, exactly like SC:BW

---

## SUMMARY: Top 10 Visual Rules for Claude Code

1. **The UI frame is metallic blue/gold SC:BW style** — NOT flat colored panels. It has beveled edges, gold trim, and decorative sawtooth patterns. Create it as a PNG overlay.

2. **Terrain looks painted, not gridded.** Tiles must blend seamlessly. Use transition tiles. Each terrain type needs multiple variants. The isometric grid should be invisible.

3. **Units are detailed pixel-art sprites** with shading and highlights, NOT flat colored shapes. They cast shadows and have selection circles + HP bars on the ground beneath them.

4. **Beacons are large (96x48px), ornate, glowing oval pads** — NOT small simple circles. They look technological with metallic base + glowing energy patterns.

5. **Wireframe portrait** in the unit info — green lines on black background showing the unit's shape. NOT a photo or pixel art face.

6. **HP shown as colored text** ("500/500") below the wireframe. NOT just a bar.

7. **Kill counter always visible** in top-left. Resources always visible in top-right (minerals icon + number, gas icon + number, supply).

8. **Blood/corpse sprites** remain on the ground where enemies die. They persist for 15-30 seconds before fading.

9. **Trigger text floats over the game** with no background box — just outlined text, centered.

10. **Cliff faces are prominent vertical rock walls** with detail (layers, shadows, icicles/vines). They're a major part of the landscape, not just elevation changes.