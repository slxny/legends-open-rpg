# LEGENDS OPEN RPG — Godot Game Design Document

**Version:** 1.0
**Engine:** Godot 4.x
**Perspective:** Top-down / Isometric 2D
**Players:** Single-player (architecture supports future multiplayer expansion)

---

## 1. GAME OVERVIEW

### High Concept
An open-world, sandbox action-RPG inspired by the classic StarCraft/Warcraft III UMS custom map "Legends Open RPG." The player starts as a lone **Mercenary** (Wanderer) — exploring a vast fantasy world, killing monsters, leveling up, collecting loot, and discovering legendary artifacts. As they accumulate wealth and power, they can **purchase entire towns and villages** from their local lords, transitioning from a roaming adventurer into a land-owning ruler who builds, upgrades, and defends settlements.

### Core Fantasy
Start as nobody. Become a legend. Own the world.

### What Made the Original Special
- Total freedom — no forced quest chains, just explore and grow
- Satisfying power curve from weak nobody to godlike Demigod
- The tension between pure combat (Wanderer) and base-building (Builder) playstyles
- Secret legendary artifacts hidden across a massive map
- Emergent, unscripted gameplay moments
- Chill grinding punctuated by sudden danger

---

## 2. CORE GAME LOOP

```
EXPLORE → FIGHT → LOOT → LEVEL UP → EXPLORE HARDER AREAS
                                    ↓
                              ACCUMULATE GOLD
                                    ↓
                         PURCHASE TOWNS / UPGRADE SETTLEMENTS
                                    ↓
                    HIRE TROOPS → DEFEND & EXPAND TERRITORY
                                    ↓
                         ACHIEVE LEGENDARY STATUS
```

### Moment-to-Moment Gameplay
1. Move hero through the world (click-to-move or WASD — configurable)
2. Encounter monster camps → engage in real-time combat
3. Kill monsters → earn XP + Gold + item drops
4. Level up → allocate skill points → grow stronger
5. Visit towns → buy/sell items at shops, interact with NPCs
6. Discover hidden areas → find Legendary Artifacts
7. Accumulate enough gold → negotiate to purchase a town from its lord
8. Manage owned towns → build defenses, hire guards, collect taxes
9. Push into harder regions → repeat at higher stakes

---

## 3. CHARACTER SYSTEM

### 3.1 Hero Selection
At game start, the player chooses from a roster of hero classes at a **Mercenary Camp / Tavern**.

| Hero Class | Primary Stat | Playstyle | Example Abilities |
|-----------|-------------|-----------|-------------------|
| **Blade Knight** | Strength | Melee bruiser, high HP | Cleave, Shield Wall, War Cry, Blade Storm (ult) |
| **Shadow Ranger** | Agility | Ranged DPS, fast | Multi-Shot, Poison Arrow, Evasion, Rain of Arrows (ult) |
| **Arcane Mage** | Intelligence | AoE caster, squishy | Fireball, Frost Nova, Mana Shield, Meteor Strike (ult) |
| **Death Warden** | Strength/Int | Dark melee/caster hybrid | Life Drain, Corpse Explosion, Dark Aura, Summon Undead (ult) |
| **Spirit Druid** | Intelligence | Healer/summoner | Healing Wave, Entangle, Spirit Wolves, Nature's Wrath (ult) |
| **Iron Berserker** | Strength | High-risk melee glass cannon | Frenzy, Leap Attack, Blood Rage, Unstoppable (ult) |

**Room to expand:** New heroes can be added via new Tavern buildings in different regions (e.g., an "Eastern Tavern" with monk/samurai archetypes, a "Dark Tavern" with necromancer types).

### 3.2 Stats
- **Strength (STR):** Max HP, HP regen, melee damage bonus
- **Agility (AGI):** Attack speed, dodge chance, movement speed, ranged damage bonus
- **Intelligence (INT):** Max Mana, mana regen, spell damage bonus
- **Armor:** Flat damage reduction
- **Attack Damage:** Base + stat bonuses + weapon

Each level grants +stat points (auto-distributed based on class with small player choice allocation).

### 3.3 Leveling & Prestige

| Level Range | Tier | Effect |
|------------|------|--------|
| 1–15 | **Adventurer** | Standard progression, learning abilities |
| 16–25 | **Veteran** | Access mid-tier regions, unlock ability rank 4+ |
| 26–35 | **Master** | Ability ranks can exceed 3 (up to rank 5), stat bonus |
| 36–45 | **Demigod** | Massive stat scaling, visual aura effect on hero |
| 46–50 | **Guardian** | Max tier — hero glows, gains passive AoE damage aura |

- **Max level: 50** (with exponentially increasing XP requirements)
- Skills can be leveled beyond rank 3 (up to rank 5 at Master tier, rank 7 at Demigod)
- Each prestige tier unlocks a visible cosmetic change on the hero (glow, particles, wings, etc.)

### 3.4 Abilities
Each hero has:
- **3 Active Abilities** (unlocked at levels 1, 4, 8)
- **1 Ultimate Ability** (unlocked at level 12)
- **1 Passive** (always active, unlocked at level 1)
- Abilities level up when you invest skill points (1 point per level)
- At **Master** tier, ability max rank increases from 3 → 5
- At **Demigod** tier, ability max rank increases from 5 → 7

---

## 4. THE ALIGNMENT SYSTEM

### 4.1 Good vs. Evil
Early in the game, the player encounters a **Crossroads Shrine** where they commit to an alignment:

- **GOOD (Order):**
  - Friendly with human/elf/dwarf NPC towns
  - Can hire "holy" troop types (knights, paladins, archers)
  - Access to healing-focused item shops
  - Hostile with undead/demon towns
  - Townsfolk love you — lower purchase prices for towns
  - Good-aligned Legendary Artifacts become findable

- **EVIL (Chaos):**
  - Friendly with undead/orc/demon NPC towns
  - Can hire "dark" troop types (skeletons, dark knights, warlocks)
  - Access to damage/curse-focused item shops
  - Hostile with human/elf towns (must conquer them to own them, OR pay a MUCH higher premium)
  - Evil-aligned Legendary Artifacts become findable

- **Alignment can shift** slowly over time based on actions (killing good NPCs shifts evil, helping villages shifts good) — but the initial commitment sets your starting faction relationships

---

## 5. TOWN PURCHASING & SETTLEMENT SYSTEM

### 5.1 How It Works
This is the core evolution of the original Builder/Wanderer split. Instead of choosing Builder at game start, you **earn** the Builder role by purchasing settlements.

**Every town/village on the map has a local lord (Duke, Baron, Count, etc.).**
When you visit a town, you can speak to the lord and see the **purchase price**.

| Settlement Type | Approximate Cost | What You Get |
|----------------|-----------------|--------------|
| **Hamlet** (tiny) | 500–1,000 gold | 2-3 buildings, small tax income, 1 guard slot |
| **Village** | 2,000–5,000 gold | 5-8 buildings, market, basic walls, 4 guard slots |
| **Town** | 10,000–25,000 gold | 10-15 buildings, full walls, blacksmith, 8 guard slots |
| **Fortress City** | 50,000–100,000 gold | 20+ buildings, stone walls, towers, barracks, 16 guard slots |

### 5.2 What Owning a Settlement Gives You
Once purchased, you become the **Lord/Lady** of that settlement:

- **Tax Income:** Passive gold generation (scales with settlement prosperity)
- **Building Slots:** You can construct new buildings or upgrade existing ones
- **Guard Slots:** Hire NPC guards that patrol and defend the settlement
- **Shop Access:** Build/upgrade shops that sell better items
- **Resource Collection:** Assign workers to nearby gold mines, lumber camps, farms
- **Rally Point:** Fast-travel / respawn point at your owned towns
- **Troop Training:** Build a barracks to train army units you can command

### 5.3 Settlement Building
Buildings you can construct (within available building slots):

| Building | Cost | Effect |
|---------|------|--------|
| **Watchtower** | 200g | Ranged defense tower, auto-attacks enemies |
| **Stone Wall Section** | 100g | Blocks enemy pathing, must be destroyed |
| **Barracks** | 500g | Train basic melee soldiers |
| **Archery Range** | 600g | Train ranged soldiers |
| **Blacksmith** | 800g | Unlocks weapon/armor upgrades for your hero + troops |
| **Market** | 400g | Increases tax income by 25%, adds item shop |
| **Temple / Dark Shrine** | 1,000g | Alignment-specific bonuses, heals hero on visit |
| **Gold Mine** | 300g | Must be built on a gold deposit — generates gold over time |
| **Farm** | 150g | Increases max troop capacity |
| **Mage Tower** | 1,500g | Train caster units, unlock spell research |
| **Inn** | 250g | Hire wandering mercenary heroes (future: potential companion system) |
| **Stable** | 600g | Unlock mounted troop types, hero mount |

### 5.4 Settlement Attacks
Periodically, enemy factions will raid your settlements:
- **Frequency scales with settlement value** — richer towns attract more raids
- **Raid composition** depends on nearby monster density and enemy faction
- **If you're nearby:** You can fight alongside your guards
- **If you're away:** Guards + towers defend automatically (outcome simulated based on power levels)
- **If a settlement falls:** It becomes damaged, tax income drops, must be rebuilt

---

## 6. THE WORLD

### 6.1 Map Structure
A **very large** seamless open world divided into regions of escalating difficulty.

```
┌─────────────────────────────────────────────┐
│                                             │
│   ┌───────┐    FROZEN WASTES (Lv 40-50)    │
│   │Guardian│    Ice God artifacts here       │
│   │ Peak   │                                │
│   └───────┘         ┌──────────┐            │
│                     │Demon Gate│            │
│   DARK MARSHES      └──────────┘            │
│   (Lv 30-40)              VOLCANIC RIDGE    │
│                           (Lv 35-50)        │
│        ┌──────────┐                         │
│        │ HAUNTED  │    ANCIENT RUINS        │
│        │ FOREST   │    (Lv 25-35)           │
│        │(Lv 20-30)│                         │
│        └──────────┘         ┌─────┐         │
│                             │LAKE │         │
│   ROLLING PLAINS           │REALM│         │
│   (Lv 10-20)              │15-25│         │
│                             └─────┘         │
│        ┌──────────────┐                     │
│        │  GREENWOOD    │                    │
│        │  VALLEY       │  EASTERN           │
│        │  (Lv 5-15)    │  STEPPES           │
│        └──────────────┘  (Lv 10-20)        │
│                                             │
│   ★ STARTING TOWN (Lv 1-5 zone around it)  │
│     "Haven's Rest"                          │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.2 Regions

| Region | Level Range | Tileset/Biome | Key Features |
|--------|-----------|---------------|-------------|
| **Haven's Rest** | 1–5 | Temperate grassland, small town | Starting town, tutorial area, weak goblins & wolves |
| **Greenwood Valley** | 5–15 | Lush forest, streams, cottages | First village to purchase, bandit camps, herbalist |
| **Rolling Plains** | 10–20 | Open fields, farms, ruined forts | Mounted enemy patrols, first fortress city, gold deposits |
| **Eastern Steppes** | 10–20 | Arid grasslands, orc encampments | Orc faction hub, evil-alignment shops |
| **Lake Realm** | 15–25 | Lakeside, islands, fishing village | Water-based enemies, hidden underwater cave artifact |
| **Haunted Forest** | 20–30 | Dead trees, fog, undead ruins | Undead faction, necromancer tower, dark artifacts |
| **Ancient Ruins** | 25–35 | Crumbling temples, stone golems | Puzzle areas, trap corridors, artifact vaults |
| **Dark Marshes** | 30–40 | Swampland, poisonous terrain | DoT zones, witch coven, rare alchemy ingredients |
| **Frozen Wastes** | 40–50 | Snow, ice caves, howling wind | Strongest creeps, Ice God prestige location |
| **Volcanic Ridge** | 35–50 | Lava, obsidian, fire elementals | Demon Gate (endgame dungeon), ultimate artifacts |
| **Guardian Peak** | 50 | Mountain summit, ethereal | Final prestige area — become a Guardian here |

### 6.3 Points of Interest
Each region contains:
- **2-4 Monster Camp clusters** (respawning enemies)
- **1-2 Purchasable settlements** (hamlet/village/town)
- **1 Neutral shop** (items scale to region level)
- **1-2 Hidden artifact locations** (exploration puzzles)
- **1 Boss encounter** (unique named enemy, doesn't respawn — drops legendary loot)
- **Environmental hazards** (poison swamps, lava tiles, ice that slows)

---

## 7. COMBAT SYSTEM

### 7.1 Core Mechanics
- **Real-time action combat** — no turns
- **Click-to-move** with **right-click to attack** (RTS-style) OR **WASD movement** with mouse-aim (configurable)
- **Auto-attack** when in range of enemy (hero swings automatically)
- **Abilities** on hotkeys (Q, W, E, R for skills — or 1, 2, 3, 4)
- **Cooldowns** on abilities (no mana for basic attacks)
- **Damage types:** Physical, Fire, Ice, Lightning, Dark, Holy
- **Resistances:** Enemies have type-specific resistances

### 7.2 Enemy Design

**Creep Camps:** Groups of 3-8 enemies clustered together
- Walk into aggro range → they attack
- Kill them → earn XP + gold + chance for item drop
- They **respawn** after 60-120 seconds (at slightly lower level than original, matching the original game's design)
- Camps have a **visible skull icon** showing approximate difficulty relative to your level

**Boss Monsters:** Unique named enemies
- Much higher HP, special attack patterns
- Do NOT respawn once killed
- Guaranteed rare/legendary item drop
- Example: "Grimjaw the Rot King" (Lv 25 undead boss in Haunted Forest)

### 7.3 Damage Formula (Simple)
```
Damage = (Base_Attack + Stat_Bonus + Weapon_Damage) × Ability_Multiplier - Target_Armor
Minimum damage = 1
Critical Hit chance = AGI / 200 (capped at 40%)
Critical multiplier = 2.0×
```

---

## 8. ITEMS & INVENTORY

### 8.1 Inventory
- **6 equipment slots:** Weapon, Armor, Helm, Boots, Ring, Amulet
- **4 consumable quick-slots** (potions, scrolls)
- **A bag/backpack** with 16 general inventory slots

### 8.2 Item Rarity Tiers
| Rarity | Color | Drop Rate | Power Level |
|--------|-------|-----------|-------------|
| **Common** | White | 60% | Basic stats |
| **Uncommon** | Green | 25% | +1 stat bonus |
| **Rare** | Blue | 10% | +2 stats, may have passive effect |
| **Epic** | Purple | 4% | +3 stats, special passive |
| **Legendary Artifact** | Orange | Found only in secret locations | Unique, extremely powerful, named items |

### 8.3 Legendary Artifacts
Hidden throughout the world — 12-15 total. Each is a unique named item with a powerful unique effect.

Examples:
| Artifact | Location Hint | Effect |
|---------|--------------|--------|
| **Blade of the First King** | Ancient Ruins vault | +50 ATK, attacks cleave all adjacent enemies |
| **Frostweave Cloak** | Frozen Wastes ice cave | +40 Armor, enemies that hit you are slowed 30% |
| **Orb of Eternal Night** | Dark Marshes witch coven | +80 Spell Damage, abilities cost 25% less mana |
| **Crown of the Guardian** | Guardian Peak summit | +All Stats, passive HP regen 5%/sec |
| **Shadowstep Boots** | Haunted Forest crypt | +50% Move Speed, press hotkey to blink-teleport short range |
| **Dragonheart Amulet** | Volcanic Ridge dragon's lair | Immune to fire damage, +20% max HP |

Finding all artifacts unlocks a **special prestige title** and cosmetic.

---

## 9. NPC & SHOP SYSTEM

### 9.1 Town NPCs
Each NPC town contains some of:
- **Lord/Duke/Baron:** Sells you the town, gives region-scale quests
- **Shopkeeper:** Sells consumables (potions, scrolls, basic gear)
- **Blacksmith:** Sells weapons/armor scaled to region level, can upgrade equipment
- **Innkeeper:** Full heal + save point
- **Quest Giver (optional):** Offers bounty-style side quests ("Kill 20 wolves in Greenwood" for bonus gold/XP)

### 9.2 Shop Scaling
Shops sell items appropriate to their region's level. A shop in a Lv 5 area sells Lv 5 gear. Shops you build in YOUR owned towns sell gear scaled to your hero's level (capped by blacksmith upgrade tier).

---

## 10. ECONOMY

### 10.1 Gold Sources
| Source | Amount | Notes |
|--------|--------|-------|
| Killing monsters | 1-50g per kill | Scales with monster level |
| Selling items | Variable | Sell price = 40% of buy price |
| Settlement taxes | 10-200g/min | Scales with town tier + market buildings |
| Gold mines | 5-30g/min | Must build on deposit, deplete over time |
| Boss kills | 100-1,000g | One-time per boss |
| Quest rewards | 50-500g | Per quest |

### 10.2 Gold Sinks
| Sink | Cost Range |
|------|-----------|
| Items from shops | 10-5,000g |
| Town purchases | 500-100,000g |
| Building construction | 100-2,000g |
| Troop hiring | 20-200g per unit |
| Equipment upgrades | 100-3,000g |
| Fast travel | 10-50g per use |

---

## 11. CONTROLS & UI

### 11.1 Default Controls
```
Left Click:         Move to location / Select
Right Click:        Attack target / Interact with NPC
Q, W, E, R:        Abilities 1-4
1, 2, 3, 4:        Consumable quick-slots
I:                  Open inventory
M:                  Open world map
T:                  Open town management (when near owned town)
Tab:                Hero stats/character sheet
Space:              Center camera on hero
Mouse Wheel:        Zoom in/out
F5:                 Quick save
ESC:                Menu / Cancel
```

### 11.2 HUD Layout
```
┌──────────────────────────────────────────┐
│ [Hero Portrait] [HP Bar] [Mana Bar]  [Map]│
│ [Level: 24 - Veteran]          [Gold: 4,820]│
│                                          │
│                                          │
│              GAME WORLD                  │
│                                          │
│                                          │
│                                          │
│ [Q][W][E][R]              [1][2][3][4]   │
│ [Ability Bar]             [Consumables]   │
│ [XP Bar ████████░░░░░░░░░ 67%]           │
└──────────────────────────────────────────┘
```

---

## 12. SAVE SYSTEM

- **Manual save** at Innkeepers or in owned towns
- **Quick save** (F5) anywhere
- **Auto-save** every 5 minutes
- Saves: hero state, inventory, owned settlements, building states, killed bosses, found artifacts, alignment, map exploration state

---

## 13. TECHNICAL ARCHITECTURE (Godot)

### 13.1 Scene Structure
```
Main
├── World (TileMap / large world scene)
│   ├── Regions (child scenes loaded/unloaded by proximity)
│   │   ├── CreepCamps (enemy group spawners)
│   │   ├── Settlements (town scenes)
│   │   ├── NPCs
│   │   └── ArtifactLocations
│   ├── Player (CharacterBody2D)
│   │   ├── AnimatedSprite2D
│   │   ├── AbilityManager
│   │   ├── InventoryManager
│   │   └── StatsComponent
│   └── Camera2D (follows player, zoom-able)
├── UI (CanvasLayer)
│   ├── HUD
│   ├── InventoryScreen
│   ├── TownManagementScreen
│   ├── WorldMap
│   ├── ShopDialog
│   └── CharacterSheet
└── GameManager (autoload singleton)
    ├── SaveLoadManager
    ├── EconomyManager
    ├── SettlementManager
    └── QuestManager
```

### 13.2 Key Systems as Autoloads
- **GameManager:** Global game state, time tracking, difficulty scaling
- **SaveLoadManager:** Serialize/deserialize all game state to JSON or Resource files
- **EconomyManager:** Tracks gold, handles transactions, settlement income ticks
- **SettlementManager:** Tracks owned settlements, building states, guard rosters, raid timers

### 13.3 Future Multiplayer Hooks
Design decisions to make multiplayer expansion easier later:
- All game state changes go through **Manager singletons** (easy to swap for networked RPCs)
- Player character is a separate scene from the World (can instance multiple)
- Settlement ownership stored as **player_id → settlement_id** mapping
- Combat damage routed through a **DamageManager** (can add PvP flags later)
- Use **Godot's MultiplayerSynchronizer** compatible node structure

---

## 14. ART DIRECTION NOTES

### Visual Style (for prompting)
- **2D top-down** or **2.5D isometric** (like classic Warcraft III / StarCraft viewed from above)
- **Pixel art** OR **hand-painted sprite** style — either works, pixel art is faster to produce
- **Resolution:** 16x16 or 32x32 pixel tile size
- **Color palette:** Rich, saturated fantasy colors — lush greens, deep blues, warm golds
- **Hero sprites:** 4-8 directional movement frames, attack animations, ability VFX
- **Environment:** Distinct biome tilesets per region — forest, plains, snow, volcanic, swamp, ruins
- **Buildings:** Clear silhouettes — watchtowers are tall and narrow, barracks are wide and stocky
- **UI:** Clean medieval-fantasy themed frames, parchment textures for menus, gold coin icons

### Audio Direction
- **Music:** Ambient fantasy orchestral per region (calm in safe zones, tense in dangerous areas)
- **SFX:** Satisfying hit sounds, gold pickup chime, level-up fanfare, ability whooshes
- **Ambient:** Birds in forest, wind in wastes, bubbling in swamp, crackling in volcanic

---

## 15. MILESTONE PLAN

### Phase 1: Core Prototype
- [ ] Hero selection (2 classes)
- [ ] Basic movement + camera
- [ ] 1 region with creep camps
- [ ] Combat system (attack + 2 abilities)
- [ ] Leveling + stat growth
- [ ] Basic inventory + item drops
- [ ] 1 NPC shop

### Phase 2: World & Economy
- [ ] 3+ regions with scaling difficulty
- [ ] Full item rarity system
- [ ] Gold economy + shops
- [ ] Alignment system (Good/Evil choice)
- [ ] Save/load system

### Phase 3: Settlement System
- [ ] Town purchasing from lords
- [ ] Building construction UI
- [ ] Settlement income/taxes
- [ ] Guard hiring + patrol AI
- [ ] Settlement raid events

### Phase 4: Content & Polish
- [ ] All 10 regions
- [ ] All 6 hero classes
- [ ] All Legendary Artifacts
- [ ] Boss encounters
- [ ] Prestige system (Master → Demigod → Guardian)
- [ ] Sound + music
- [ ] Full UI polish

### Phase 5: Multiplayer Prep (Future)
- [ ] Networked player instances
- [ ] PvP combat
- [ ] Shared world state
- [ ] Settlement raiding by other players

---

## 16. QUICK REFERENCE — ORIGINAL GAME DNA

What to preserve from the original Legends Open RPG feel:

| Element | Original | This Game |
|---------|----------|-----------|
| Freedom | No mandatory quests | Same — explore at will |
| Power curve | Weak → Demigod | Weak → Guardian (5 prestige tiers) |
| Builder vs Wanderer | Choose at start | Start Wanderer, BUY your way into Builder |
| Good vs Evil | Choose at start | Choose at shrine, affects factions |
| Legendary Artifacts | Hidden across map | Same — 12-15 hidden unique items |
| Creep respawns | Respawn at lower level | Same mechanic |
| Base building | Freeform if Builder | Build within owned settlement slots |
| PvP | Always-on | Future feature (AI raids for now) |
| Hack and slash | Click to kill | Same real-time combat |
| Prestige | Master/Demigod/Guardian | 5-tier system with visual upgrades |
| Massive map | 256x256 tiles | Large seamless world with 10 regions |
| Multiplayer sandbox | 6-12 players | Single-player first, architecture supports expansion |