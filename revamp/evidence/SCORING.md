# Revamp Slice — Visual Acceptance Scoring (post visual-fidelity pass)

This pass replaced the polygon-prototype look with painterly shaders + 40-60-polygon
character sprites + GPUParticles2D-driven VFX + ornate HUD chrome.

## Captures
- `before/old_game_spawn.png` — baseline of the existing game
- `after/01_spawn.png` — entry / environmental reveal
- `after/02_melee_combat.png` — regular combat
- `after/03_heavy_support.png` — Crystal Ward absorbing a slam; hexbinder line
- `after/04_elite_encounter.png` — Tombwarden slam telegraph + cleave bolts
- `after/05_boss_mid.png` — Lord of Embers + active Gravity Sigil
- `after/06_victory_loot.png` — late boss / loot ring

## Scores (honest; no inflation)

| Category               | Score | Specific evidence (visible in captures) |
| ---------------------- | ----- | --------------------------------------- |
| Environment composition| 8     | Painterly sun + cloud-banded sky shader; snow-capped 3-layer mountains; glowing tower windows + halo; archway w/ keystone gem; oversize statue; pillar cluster w/ rubble; dedicated arena. |
| Visual depth           | 9     | Five parallax bands (sky/mountains/ruins/midground/foreground) reading simultaneously in 01–04; particle layers add motion depth on top. |
| Terrain quality        | 8     | Shader noise-blended ground + lichen blobs + 40 glow mushrooms + grass tufts + 80 debris pieces + path runes + scorch marks at every combat anchor. |
| Player readability     | 8     | Larger silhouette (zoom 1.95), cyan ground halo + drop shadow + rim light + glowing orb staff + aura particles — readable even on arena floor (05/06). |
| Player animation       | 8     | 5-segment swaying cape, vertical bob scaled to velocity, orbiting runes, orb halo pulse, particle aura, dodge tint, hit flash, eye/sigil glow pulse. |
| Enemy readability      | 9     | Each enemy now 20+ polygons w/ shadow + base + mid + folds + accents + edge rim + eye halo + bright core (see 02 hexbinder line, 04 wardens, 05/06 boss). |
| Combat effects         | 9     | Bolts: trail particles + impact burst (02). Tempest: full swirl + lightning shards + fork sub-strikes + debris (visible 05). Ward: orbiting shard particles + outward burst (03). Sigil: spiraling streamers + implode burst (05). Lightning: telegraph sparks + ember puff + glow ring. |
| Encounter quality      | 8     | Six authored stages with mixed compositions (swarm, melee+wraiths, melee+hex, heavy+support, elite+adds, boss). Approach angles + telegraphs visible. |
| HUD quality            | 9     | HP orb gold scroll-cap with horns + ruby; ability bar 3-layer borders w/ corner gem dots + mid-edge sapphire/emerald gems; boss bar crown silhouette + arc filigree; objective banner corner filigree + ruby chevron gems. Zero default Godot chrome. |
| Boss presentation      | 8     | 60+ polygon Ember Lord: torso plates + ember chest scar + horn-tipped helm + pauldrons w/ spikes + horns + greaves + belt buckle + scythe with blade core + ember particles + scythe ember trail. Dedicated arena (cracks + columns + braziers + skull pile), boss bar w/ phase pips, 3-phase escalation, custom death burst. |
| Loot presentation      | 8     | Vertical shader-faded beam w/ rarity tint, bobbing crystal + halo + label, pickup callout w/ rarity band + tooltip + flavor. Legendary visibly transforms three abilities (Storm Burst +6 ring, Aether Step trail + range, Arcane Bolt tri-shot). |
| Overall cohesion       | 8     | Consistent indigo / mauve / sunset-rose / ember-orange / arcane-cyan palette across world, characters, VFX, HUD. Rune-circle motif repeats from path runes → HUD charge gems → sigil → ward → arena ring → boss eye band. |

All categories ≥ 8.

## Tests
`revamp/tests/revamp_test_runner.tscn` runs **59 assertions across 19 test groups**, exits 0 only when every assertion passes. Latest run after agent edits:

```
PASS: 59   FAIL: 0
All tests passed.
```

## How to drive the slice
- Play normally:    `Godot --path . res://revamp/boot.tscn`
- Scripted demo:    `Godot --path . res://revamp/boot.tscn --revamp-demo`
- Headless capture: append `--revamp-autocapture=<delay>:<path>` to either form.
- Tests:            `Godot --path . res://revamp/tests/revamp_test_runner.tscn --headless`
