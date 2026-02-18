# GDD ADDENDUM: StarCraft Brood War UMS Authenticity Guide

**Purpose:** This document expands the main GDD.md to make the game visually and mechanically faithful to how StarCraft: Brood War UMS RPG maps (specifically Legends Open RPG) actually looked, felt, and played. Claude Code should read this alongside GDD.md.

---

## A. VISUAL AUTHENTICITY — What SC:BW UMS RPGs Actually Looked Like

### A.1 The Camera & Perspective
- **Strict top-down isometric** — NOT free-rotating. The camera angle is FIXED at roughly 45 degrees, looking "down-right" (the classic Blizzard isometric angle)
- **No camera rotation** — the world is drawn from one fixed angle, just like SC:BW
- **Zoom should be limited** — default zoom shows roughly a 20x15 tile area (simulating the 640x480 viewport of the original). Allow zoom out to maybe 2x that, but the "authentic" feel is the tight default view
- **The minimap** is in the bottom-left corner, showing the entire world as a small radar-style colored rectangle map. Your hero is a blinking dot. Explored areas are visible, unexplored areas are black (fog of war)

### A.2 The Tileset — "Jungle World"
The StarCraft BW Legends Open RPG used the **Jungle tileset**. This is THE defining visual:

**Ground tiles:**
- Rich dark green grass as the base terrain
- Lighter yellow-green dirt paths connecting areas
- Brown/tan mud near water edges
- Dark water (rivers, ponds) with subtle animation
- Rocky gray elevated terrain for cliffs and mountains
- Jungle temple ruins — stone blocks, cracked pillars, overgrown walls (these were "doodads" in SC)

**Vegetation doodads (decorative objects):**
- Tall dark green jungle trees (clusters of 2-4, casting shadow sprites)
- Shorter bushes and ferns scattered on grass
- Vines hanging from cliff edges
- Flower patches (small colored dots on grass)
- Fallen logs
- Mushroom clusters

**Man-made doodads:**
- Stone temple walls and archways (the jungle temple aesthetic)
- Cracked stone floors (ancient ruin areas)
- Torch sprites (small animated flame doodads placed on walls)
- Flags and banners near towns
- Mineral crystal clusters (glowing blue — used as "treasure" or "shop" markers)
- Vespene gas geysers (glowing green — used as special resource points)
- **Beacons** — colored circle pads on the ground (CRITICAL — these are the interaction points, see below)

**Color palette:**
- Dominant: dark greens (#1a3a1a to #3d6b3d), brown earth (#5c4033), gray stone (#707070)
- Accents: blue mineral glow (#4488ff), green gas glow (#44ff44), red enemy markers (#ff4444)
- Water: deep teal-blue (#1a4a5a) with slight transparency/shimmer
- Sky/ambient light: warm tropical — everything has a slight golden-green cast

### A.3 Unit Sprites — How Heroes & Monsters Looked
In SC:BW UMS RPGs, every "character" was a repurposed StarCraft unit. The art style is:
- **Small pixel sprites** — each unit is roughly 32x48 pixels at native resolution
- **8-directional facing** — units face 8 compass directions (N, NE, E, SE, S, SW, W, NW)
- **Idle animation** — subtle breathing/shifting loop (2-4 frames)
- **Walk animation** — smooth 4-8 frame cycle per direction
- **Attack animation** — 3-6 frames of weapon swing/projectile launch
- **Death animation** — unit crumples/explodes, leaves a small debris sprite that fades

**Hero unit equivalents (what SC units represented in RPGs):**
| RPG Role | SC:BW Unit Used | Visual Description |
|----------|----------------|-------------------|
| Warrior/Knight | Zealot or Dragoon | Armored humanoid, glowing weapon |
| Rogue/Assassin | Dark Templar | Dark cloaked figure, green blade glow |
| Mage/Caster | High Templar or Ghost | Robed/suited figure, energy effects |
| Ranger | Marine or Vulture | Armored ranged attacker |
| Tank/Paladin | Archon or Ultralisk | Large glowing/armored unit |
| Healer/Support | Medic or Corsair | Lighter-colored, support appearance |

**Monster/Creep equivalents:**
| Monster Type | SC:BW Unit Used | Visual Description |
|-------------|----------------|-------------------|
| Weak fodder | Zergling, Broodling | Small, fast, swarm in groups of 4-8 |
| Medium melee | Hydralisk, Firebat | Medium-sized, threatening stance |
| Medium ranged | Marine (enemy color), Lurker | Ranged attacks, often positioned in groups |
| Large brute | Ultralisk, Goliath | Big sprite, slow, heavy damage |
| Boss | Archon, Battlecruiser, Cerebrate | Oversized unit, unique coloring, often glowing |
| Flying enemy | Mutalisk, Scout, Wraith | Airborne sprite with shadow underneath |

**KEY VISUAL RULE:** In your Godot game, sprites should be this same approximate size and level of detail. Don't go hi-res or hyper-detailed — keep it chunky, readable pixel art at 32x48 to 64x64 pixel character size. The charm is in the low-fi clarity.

### A.4 Player Colors
- SC:BW used **8 player colors**: Red, Blue, Teal, Purple, Orange, Brown, White, Yellow
- Your hero is always **your player color** (typically White or Teal for the "good guy" feel)
- Enemy creeps are Red (hostile) or Yellow/Orange (neutral-hostile)
- Friendly NPCs are Blue or Teal
- Town buildings are your player color once purchased

### A.5 UI — Replicating the SC:BW Interface Feel

The SC:BW interface is iconic. Replicate its LAYOUT and FEEL:

```
┌────────────────────────────────────────────────────┐
│                                                    │
│                  GAME VIEWPORT                     │
│              (the actual game world)               │
│                                                    │
│                                                    │
│                                                    │
│                                                    │
├──────────┬─────────────────────┬───────────────────┤
│ MINIMAP  │  UNIT INFO PANEL    │  COMMAND PANEL     │
│          │                     │                   │
│ [small   │ [Hero portrait]    │ [Ability buttons] │
│  radar   │ [HP bar]           │ [3x3 grid of      │
│  map]    │ [MP/Energy bar]    │  action buttons]  │
│          │ [Name, Level]      │                   │
│          │ [Stats: STR/AGI/INT]│ [Item slots below]│
└──────────┴─────────────────────┴───────────────────┘
```

**Specific UI details:**
- The bottom panel is a **dark gray/black console** taking up roughly the bottom 25% of screen — just like SC:BW
- **Minimap** in bottom-left: green terrain, white dots for your units, red dots for enemies
- **Unit info** in bottom-center: Shows selected unit's portrait (a drawn/pixel art face), HP bar (green), MP/Energy bar (blue), name, level, and stats
- **Command panel** in bottom-right: A 3x3 grid of square buttons for abilities and actions — THIS IS THE CORE INTERACTION PANEL
- Buttons have small pixel-art icons (sword icon for attack, boot for move, shield for defense ability, etc.)
- **Resource display** at top-right: Shows Minerals (gold) icon + number, Gas (mana/secondary resource) icon + number, Supply (unit count)
- **Text messages** appear in the top-center as scrolling game messages ("You found a Health Potion!", "The Goblin Chief drops 50 gold")

### A.6 Text & Messages
SC:BW UMS maps communicated EVERYTHING through **centered text messages** and **mission briefing text**:
- Game events display as **yellow/white text** that scrolls in the top-center of the screen
- Important discoveries: "You found the Blade of Shadows!" in **green text**
- Damage/danger: "The Dragon breathes fire! -45 HP" in **red text**
- NPC dialogue: Appears as a **text box** overlaying the center of the screen, with the NPC name in a header
- **No voice acting** — all communication is text
- The font should feel monospaced or pixel-font — NOT a smooth modern sans-serif

---

## B. MECHANICAL AUTHENTICITY — How SC:BW UMS RPGs Actually Played

### B.1 The Beacon System (CRITICAL)
This is THE defining interaction mechanic of SC:BW UMS RPGs. **Beacons** were colored circles on the ground that triggered events when your hero walked onto them.

**In your Godot game, implement this as interaction zones:**
- **Visible colored circles/pads on the ground** at every interaction point
- When the hero walks onto a beacon, something happens (shop opens, dialogue triggers, class selection, teleportation, etc.)
- Beacons should be clearly visible — glowing colored circles (blue for friendly, red for danger, yellow for shop/neutral, green for healing)

**Beacon types to implement:**
| Beacon Color | Purpose | Example |
|-------------|---------|---------|
| **Blue** | Information / Quest | "You have entered the Dark Woods. Level 15+ recommended." |
| **Yellow** | Shop / Trade | Opens buy/sell interface |
| **Green** | Heal / Rest | Fully restores HP and MP |
| **Red** | Danger / Boss trigger | Spawns a boss or activates a trap |
| **White** | Teleporter / Fast travel | Moves hero to another beacon location |
| **Purple** | Class selection / Upgrade | Choose abilities, apply stat upgrades |
| **Orange** | Town interaction | Speak to lord, manage settlement |

### B.2 How "Abilities" Worked in SC:BW UMS
SC:BW had NO custom spell system. Map makers faked abilities using triggers:

1. Player's hero moves to a **specific location or beacon**
2. A trigger detects the hero is there
3. The trigger **creates units, removes units, deals damage to units in an area, displays text, etc.**

**What this means for your game:**
- Abilities should feel **positional** — you move your hero to the right spot, then activate
- AoE abilities should be centered on the hero's position (or a target location you click)
- The "casting" animation should be brief — a flash of light, units spawning/dying, damage numbers appearing
- There's a satisfying **delay** between pressing the ability and the effect happening (SC triggers ran every ~2 game-seconds, so effects weren't instant — they had a beat to them)
- **Implement a slight trigger delay (0.3-0.5 seconds) on ability activation** — this recreates the UMS trigger cycle feel where things don't happen instantly but have a rhythmic pulse

### B.3 How "Leveling" Worked
In SC:BW UMS RPGs, leveling was tracked via **death counters** — an internal number the trigger system could read/write. The game would check:
- "Has this player killed X of [unit type]?"
- If yes → "Set death counter to [new level], give player a stronger unit, display text"

**What this means for your game:**
- Leveling should feel **sudden and dramatic** — when you level up:
  - A big centered text message: **"LEVEL UP! You are now Level 12"**
  - A flash or glow effect on the hero
  - Stats immediately increase (you can feel the hero get stronger right away)
  - In the original, your unit was literally **replaced with a stronger version** of itself — so the power jump between levels was noticeable
- **Do NOT use smooth/gradual XP progress** — instead, kills should feel like they're counting toward a threshold, and when you cross it, BANG — level up. The XP bar can exist, but the level-up moment should be a big event.

### B.4 How "Items" Worked
SC:BW has no inventory system. UMS mapmakers faked items using:
- **Mineral crystals** placed on the ground as "items" — your hero walks over them to "pick up"
- **Death counters** tracking which items you have
- **Triggers** that change your unit's stats when items are "equipped"
- **Moving to specific beacons** to "use" items (potions, etc.)

**What this means for your game:**
- Items should appear as **small glowing sprites on the ground** where enemies die
- **Walk-over-to-pickup** — NO separate "pick up" button. If your hero walks over a dropped item, you collect it (with a small pickup sound and text notification)
- Items in shops: walk to the shop beacon → a menu appears → buy items with minerals/gold → item appears in your inventory immediately
- **Item effects should be immediate and obvious** — equipping a sword should visibly change your damage output. No subtle 2% stat increases.

### B.5 How "Shops" Worked
Shops in SC:BW UMS RPGs were:
1. A cluster of buildings (often a Protoss Pylon or Nexus used decoratively)
2. Surrounded by **beacons** — one for each item category
3. Walking your hero onto a beacon + having enough minerals = the item is "bought" (minerals deducted, death counter updated, text displays)

**What this means for your game:**
- Shops should be **physical locations on the map** — a building with beacon-pads around it
- Each beacon-pad near the shop could represent a different item category (weapons, armor, potions)
- Walking onto the pad opens a purchase menu
- The shopkeeper doesn't need a dialogue tree — just a clean buy/sell list
- **Minerals (blue crystals) = Gold.** In SC:BW UMS, minerals were the universal currency. Your game's gold should look like blue mineral crystals to stay authentic, OR you can use gold coins but keep the same "walk over to collect" feel

### B.6 How "Combat" Felt
SC:BW combat is distinctly different from WC3 or Diablo:

- **Units auto-attack** when an enemy enters their attack range
- **Attack speed is rhythmic** — units have an attack cooldown that creates a steady beat (thwack... thwack... thwack...)
- **Ranged attacks have visible projectiles** — bullets, missiles, psi bolts that travel from attacker to target
- **Melee attacks have a short lunge animation** — the unit moves slightly toward the target
- **Damage is displayed as HP reduction** — the HP bar visibly chunks down. In UMS RPGs, text messages often showed: "Goblin takes 24 damage!" or "Critical Hit! 48 damage!"
- **Death is immediate** — when HP hits 0, the unit plays a death animation (blood splatter for biological, explosion for mechanical) and drops loot
- **Overkill feels good** — killing a weak enemy in one hit should feel powerful. Don't scale enemies too tightly to the hero's level
- **Multiple enemies attack simultaneously** — creep camps don't take turns. When you walk into a group of 5 zerglings, ALL 5 attack you at once. This makes camp-clearing feel hectic and position matters (don't get surrounded)

**Attack animations and timing:**
- Melee hero: attack animation ~0.5 seconds, with damage applied at the midpoint (~0.25s)
- Ranged hero: attack animation ~0.3 seconds, projectile travel ~0.3 seconds, damage on impact
- Spell/ability: cast animation ~0.5 seconds, effect after ~0.3-0.5 second delay (the trigger-cycle feel)

### B.7 How "Movement" Felt
- **Click-to-move ONLY** for authentic feel (WASD can be an option but click-to-move is the primary)
- Hero moves at a consistent speed — no acceleration/deceleration. Click destination → hero walks there at fixed speed
- **Pathfinding** around obstacles (trees, buildings, cliffs) — the hero doesn't walk through solid objects
- Movement feels **deliberate, not twitchy** — this isn't a bullet-hell. You click where to go, the hero walks there, you click enemies to attack
- **Right-click = attack-move / interact** (if you right-click on an enemy, the hero walks to attack range and starts attacking. If you right-click on a beacon/NPC, the hero walks there and interacts)
- **Left-click = select / move** (left-click on terrain = move there)

### B.8 Fog of War
- The map starts **completely black** except your immediate surroundings
- As you explore, the fog lifts permanently — explored terrain stays visible but slightly darkened
- **Currently visible area** (near your hero) is fully bright
- **Previously explored but not currently visible** areas are dimmed (you can see the terrain/buildings but not moving units)
- **Unexplored areas** are completely black
- This creates the sense of discovery — you don't know what's in the next region until you walk there

### B.9 Respawning Creeps — The Grind
- Monster camps **respawn on a timer** (60-180 seconds after being cleared)
- Respawned monsters are **slightly weaker** than the originals (e.g., level 20 camp respawns as level 14) — this is a direct mechanic from the original Legends Open RPG
- This means:
  - Fresh camps are worth more XP/gold
  - Grinding already-cleared camps gives diminishing returns
  - The incentive is always to push into NEW, harder territory
  - But you can still farm respawns if you need to
- Respawn should be **visible** — monsters fade/spawn in when the player isn't looking (off-screen). If the player is watching the camp location, monsters just appear after the timer

### B.10 Sound Design — The SC:BW Audio Feel
The sounds of SC:BW are burned into players' memories:

- **Unit acknowledgment** when selected: "Yes?" "Huh?" "What?" — a short voice line
- **Unit movement confirmation**: "Movin' out" "Roger" — when you click to move
- **Attack sounds**: Rhythmic weapon sounds — the Marine rifle burst, the Zealot blade slash, the Hydralisk spike volley
- **Hit confirmation**: A meaty thud/squelch when damage lands
- **Death sounds**: A grunt/scream for biological units, explosion for mechanical
- **Ambient**: Jungle ambient — cicadas, birds, wind through trees, distant water
- **Music**: Terran themes were twangy/military, Protoss themes were ethereal/orchestral, Zerg themes were dark/organic. For your game, aim for the **Terran** vibe — slightly western, slightly military, atmospheric
- **Level up sound**: A triumphant brass stinger
- **Item pickup**: A bright "ding" or crystal chime
- **Shop purchase**: A cash register "ka-ching" or coin sound
- **Error / can't do that**: A flat buzz/beep

---

## C. WORLD DESIGN — SC:BW Map Layout Patterns

### C.1 How SC:BW UMS RPG Maps Were Laid Out
SC:BW RPG maps on the Jungle tileset followed consistent patterns:

**The Starting Town:**
- Located in one corner or edge of the map (usually bottom-left or bottom-center)
- Surrounded by a perimeter of trees/cliffs with one or two clear paths out
- Contains: healing beacon (green), shop building with buy-beacons (yellow), info beacon (blue), and the hero selection area
- Very few or zero enemies inside the town perimeter
- A few weak enemies (level 1-3) immediately outside the town exits

**Zone Transitions:**
- Regions are separated by **natural chokepoints** — narrow paths between cliff walls, bridges over water, passes through dense forest
- Often a beacon at the zone entrance displays: "WARNING: Level 15+ area ahead"
- The chokepoint itself may have a few "gatekeeper" monsters that are slightly stronger than the surrounding area
- This makes progression feel like crossing meaningful thresholds

**Zone Layout (each region):**
```
┌──────────────────────────────┐
│  [Cliff/Tree border]        │
│                              │
│    🔴 Creep Camp A (4 units) │
│                              │
│         Path ═══════╗        │
│                     ║        │
│    🔴 Creep Camp B  ║  🟡 Shop│
│       (6 units)     ║        │
│                     ║        │
│    🟢 Heal beacon   ║        │
│                     ║        │
│         ═══════════╝        │
│                              │
│    🔴🔴 Creep Camp C (boss)  │
│                              │
│    🟣 Artifact hidden spot   │
│                              │
│  [Cliff/Tree border]        │
│         ║ (exit path to next)│
└──────────────────────────────┘
```

**Key principles:**
- Each zone has 3-6 creep camps of varying size
- At least one healing beacon per zone
- One shop per zone (or shared between adjacent zones)
- One hidden artifact location (requires exploration to find — off the main path, behind trees, through a narrow gap)
- Paths wind organically — NOT a straight grid. The terrain should feel natural.

### C.2 Map Scale
The original Legends Open RPG SC:BW map was 256x256 tiles, which is enormous. For your Godot game:
- **Target: 10-15 distinct zones** connected by paths
- Each zone should take **2-5 minutes to clear** of enemies at-level
- Total map exploration (without combat): maybe 20-30 minutes of walking
- Total game time to reach max level: **8-15 hours** of moderate grinding
- The map should feel BIG — you should be able to zoom out on the minimap and feel overwhelmed by how much is unexplored

---

## D. SPECIFIC MECHANICAL ADDITIONS FOR AUTHENTICITY

### D.1 The "Mineral Crystal" Pickup
When enemies die, they should drop small **glowing crystal sprites** on the ground:
- Blue crystals = gold
- Small white crystals = low gold (1-5)
- Larger blue crystals = medium gold (10-25)
- Bright teal crystals = high gold (50-100)
- The crystals sit on the ground and the hero auto-collects them by walking over them
- A satisfying "pling" sound on pickup

### D.2 The "Death Counter" Display
In SC:BW, players tracked stats via death counters displayed as text. Replicate this:
- A persistent stats panel (togglable) showing:
  - Total kills
  - Current level / XP to next
  - Gold (minerals)
  - Alignment: Good/Evil + reputation value
  - Current hero status tier (Adventurer/Veteran/Master/Demigod/Guardian)
  - Artifacts found: X/15

### D.3 The Text Trigger Message Style
Game messages should appear as **big centered text** that fades after 3-4 seconds, like SC:BW trigger messages:
- White text, black outline, centered horizontally, positioned in the upper-third of the screen
- Important messages (level up, artifact found, boss spawned) should be in **colored text** (green for good, red for danger, gold for achievement)
- Optional: a scrolling message log in the bottom-left (like SC:BW's text chat area)

### D.4 The Command Card (3x3 Button Grid)
The bottom-right panel should be a **3x3 grid of buttons** (9 total), just like SC:BW's command card:

```
┌─────┬─────┬─────┐
│  Q  │  W  │  E  │   Row 1: Abilities (with cooldowns overlayed)
├─────┼─────┼─────┤
│  A  │  S  │  D  │   Row 2: Utility (Potion, Scroll, Town Portal)
├─────┼─────┼─────┤
│  Z  │  X  │  C  │   Row 3: Passive/Info (Stats, Inventory, Map)
└─────┴─────┴─────┘
```

Each button has:
- A small pixel-art icon (32x32)
- A hotkey letter displayed in the corner
- A cooldown overlay (darkened sweep) when on cooldown
- A mana cost displayed below the icon
- Greyed out if not enough mana or not yet learned

### D.5 Hero Replacement on Level-Up
In SC:BW UMS RPGs, leveling up often literally **replaced your unit with a stronger version**. Your game should make level-ups feel like a transformation:
- At levels 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 — the hero's **sprite visually upgrades**
- Level 1-4: Basic sprite
- Level 5-9: Slightly different coloring or added detail (shoulder pads, helmet)
- Level 10-14: More pronounced armor/weapon glow
- Level 15-19: Particle effect added (small sparkle on weapon)
- Level 20-24: Full armor upgrade visible, hero sprite slightly larger
- Level 25+: Aura glow around hero
- Level 35+ (Demigod): Full luminous glow, sprite noticeably more imposing
- Level 45+ (Guardian): Ethereal/angelic/demonic appearance, constant particle trail

### D.6 The Town Purchase — "Bring Your Hero to the Castle"
True to the SC:BW beacon system, purchasing a town should work like this:
1. Walk your hero to the town's **castle/hall building**
2. A beacon (orange) triggers the purchase dialogue
3. Text displays: "Lord Aldric of Greenwood Village offers to sell this settlement for 3,000 gold. [Y] Accept [N] Decline"
4. If you accept and have enough gold: "YOU ARE NOW LORD OF GREENWOOD VILLAGE!" — big gold text, fanfare sound
5. All buildings in the town change to YOUR player color
6. Guards spawn at patrol points
7. The town's beacon changes from orange to your color

### D.7 Building Placement — The SC:BW Way
When building in your owned settlement, it should feel like SC:BW building placement:
- Enter build mode → a translucent green building footprint follows your cursor
- Green = valid placement, Red = invalid (overlapping, wrong terrain)
- Click to place → workers (if you have them) walk to the site and construct over time
- Construction shows the building frame gradually filling in (like SC:BW building animation)
- A progress bar appears over the construction site

---

## E. ADDITIONAL NOTES ON FEEL

### E.1 Pacing
SC:BW UMS RPGs had a specific pacing:
- **First 5 minutes:** Hero selection, learning the layout, killing first few weak enemies
- **5-20 minutes:** Getting into a groove, clearing creep camps, finding first shop, buying first item
- **20-60 minutes:** Exploring deeper regions, leveling up steadily, finding a rhythm
- **1-2 hours:** Mid-game — significant power, considering town purchase, finding artifacts
- **2-4 hours:** Late game — pushing into high-level zones, achieving Master/Demigod status
- **4+ hours:** Endgame — hunting final artifacts, Guardian Peak, perfecting your build

### E.2 Grind Feel
The grind should feel **meditative, not frustrating**:
- There should always be a camp within 10-15 seconds walk that you can fight
- Killing a creep camp should take 10-30 seconds depending on level match
- The reward (gold + XP) should feel proportional — you should see your XP bar moving noticeably after each camp
- The map should have enough variety in enemy types and terrain that the grind doesn't feel repetitive even when you're farming the same zone

### E.3 Difficulty Curve
- Enemies should hit hard enough that you can't just AFK — you need to use abilities and retreat to heal
- But enemies shouldn't one-shot you at-level — fights should last long enough to feel like fights
- Being 3-5 levels above an area should make you feel powerful (clearing camps in seconds)
- Being 3-5 levels below an area should feel dangerous but doable with skill (careful ability usage, retreat to heal, kiting)
- Being 10+ levels below should feel suicidal — enemies two-shot you

### E.4 What NOT To Do (Anti-Patterns)
Do NOT add these modern game design elements that break the SC:BW UMS feel:
- ❌ Quest markers / waypoints / objective arrows — let the player explore and discover
- ❌ Minimap icons for every point of interest — only show explored terrain and your hero
- ❌ Cutscenes or elaborate scripted sequences — use text messages only
- ❌ Smooth UI transitions / fancy animations — keep it snappy and instant
- ❌ Hand-holding tutorials — a single "QUEST MENU contains Newbie Information" (press F1) is enough, exactly like the original
- ❌ Level scaling (enemies match your level) — zones have FIXED levels, you outlevel them, that's the point
- ❌ Auto-save every 30 seconds — save at inns/towns, quick-save manually
- ❌ Loot explosions / over-the-top drop effects — items appear simply on the ground where the enemy died
- ❌ Complex crafting systems — buy or find items, that's it
- ❌ Dialogue trees with multiple choices — NPCs say their thing, you buy/sell/leave

---

## F. SUMMARY — The 10 Commandments of SC:BW UMS RPG Authenticity

1. **Fixed isometric camera** — no rotation, limited zoom
2. **Beacons are the interaction system** — colored ground pads that trigger events on walk-over
3. **Click-to-move, right-click to attack** — RTS controls, not action-game controls
4. **Fog of war** — black unexplored, dim explored, bright current view
5. **Text messages are the storytelling** — centered, colored, fade after a few seconds
6. **SC:BW console-style UI** — dark bottom panel with minimap, unit info, command card
7. **Walk-over item pickup** — crystals/items on the ground, collect by touching them
8. **Sudden level-ups with visual upgrade** — not gradual, but dramatic threshold moments
9. **Fixed zone difficulty** — don't scale to player. Let the player outgrow areas.
10. **Meditative grind, then discovery** — the gameplay loop is: grind comfortably → find a new path → enter a new zone → gasp at the difficulty → grind until you can handle it → repeat