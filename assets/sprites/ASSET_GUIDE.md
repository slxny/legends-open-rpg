# Sprite Asset Guide

Drop PNG files into the subdirectories below to override procedural sprites.
The game loads external images first, falling back to procedural generation if no file exists.

## File Naming Convention

Each PNG must match the sprite name used by `SpriteGenerator.get_texture("name")`.
Example: to replace the blade_knight hero, create `heroes/blade_knight.png`.

## Directory Structure

```
assets/sprites/
  heroes/          - Hero character sprites (32x48px recommended)
    blade_knight.png
    shadow_ranger.png
  enemies/         - Enemy unit sprites
    goblin.png        (24x28px)
    wolf.png          (32x24px)
    bandit.png        (28x40px)
  environment/     - Trees, rocks, bushes, vines, debris
    tree_jungle.png   (32x48px)
    tree_small.png    (20x28px)
    tree_dead.png     (24x48px)
    rock.png          (16x12px)
    rock_large.png    (28x20px)
    bush.png          (16x12px)
    flowers.png       (16x8px)
    grass_tuft.png    (12x10px)
    grass_tuft_tall.png (16x16px)
    mushroom_cluster.png (16x12px)
    fallen_log.png    (40x14px)
    vines.png         (20x24px)
    ground_debris.png (16x8px)
    dirt_patch.png    (32x24px)
    cliff_face.png    (64x48px)
    icicles.png       (32x16px)
  buildings/       - Structures
    shop_building.png (40x40px)
    town_hall.png     (48x48px)
    landing_pad.png   (64x32px)
    hatchery.png      (64x64px)
  beacons/         - Interaction pads (96x48px recommended)
    beacon_green.png
    beacon_yellow.png
    beacon_blue.png
    beacon_red.png
    beacon_cyan.png
  items/           - Pickup sprites
    crystal_blue.png  (12x14px)
    crystal_white.png (8x10px)
    crystal_teal.png  (14x16px)
  terrain/         - Ground tile textures
    grass_dark.png    (16x16px)
    grass_light.png   (16x16px)
    dirt.png          (16x16px)
    dirt_path.png     (16x16px)
    water.png         (16x16px)
    stone_floor.png   (16x16px)
    snow.png          (16x16px)
    ice.png           (16x16px)
    ground_jungle.png (128x128px)
    ground_creep.png  (128x128px)
    ground_stone.png  (128x128px)
    ground_snow.png   (128x128px)
    ground_dirt.png   (128x128px)
  ui/              - UI elements
    skull_icon.png    (12x12px)
    portrait_frame.png
    hud_frame.png
  vfx/             - Visual effects
    selection_green.png (32x32px)
    selection_red.png   (32x32px)
    iso_shadow.png      (32x16px)
    slash_arc.png       (48x48px)
    arrow_projectile.png (16x6px)
    blood_splatter.png  (16x16px)
```

## Tips

- Use nearest-neighbor filtering (no anti-aliasing) for pixel art
- Keep transparent backgrounds (RGBA PNG)
- SC:BW native resolution sprites are ideal
- Larger sprites will be used at their native size
