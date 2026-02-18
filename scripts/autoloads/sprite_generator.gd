extends Node

## Generates all pixel art sprites at runtime using Godot's Image API.
## SC:BW jungle tileset aesthetic with chunky readable pixel art.

# Cache generated textures
var textures: Dictionary = {}

func _ready() -> void:
	_generate_all()

func get_texture(name: String) -> ImageTexture:
	return textures.get(name, null)

func _generate_all() -> void:
	# Heroes
	_gen_blade_knight()
	_gen_shadow_ranger()
	# Enemies
	_gen_goblin()
	_gen_wolf()
	_gen_bandit()
	# Environment
	_gen_tree_jungle()
	_gen_tree_small()
	_gen_rock()
	_gen_rock_large()
	_gen_bush()
	_gen_flowers()
	# Buildings
	_gen_shop_building()
	_gen_town_hall()
	# Beacons
	_gen_beacon_green()
	_gen_beacon_yellow()
	_gen_beacon_blue()
	_gen_beacon_red()
	# Items
	_gen_crystal_blue()
	_gen_crystal_white()
	_gen_crystal_teal()
	# Terrain tiles
	_gen_grass_dark()
	_gen_grass_light()
	_gen_dirt()
	_gen_dirt_path()
	_gen_water()
	_gen_stone_floor()
	# Rich ground tiles (SC:BW style)
	_gen_ground_jungle()
	_gen_ground_creep()
	_gen_ground_stone()
	# Atmospheric decorations
	_gen_grass_tuft()
	_gen_grass_tuft_tall()
	_gen_mushroom_cluster()
	_gen_fallen_log()
	_gen_vines()
	_gen_ground_debris()
	_gen_dirt_patch()
	# UI
	_gen_skull_icon()
	# Selection / VFX
	_gen_selection_circle_green()
	_gen_selection_circle_red()
	_gen_iso_shadow()
	_gen_slash_arc()
	_gen_arrow_projectile()

# ============================================================
# HERO SPRITES (32x48 — SC:BW unit proportions)
# ============================================================

func _gen_blade_knight() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = {
		"armor_dark": Color(0.15, 0.25, 0.55),
		"armor_mid": Color(0.25, 0.4, 0.75),
		"armor_light": Color(0.4, 0.55, 0.9),
		"helm": Color(0.3, 0.35, 0.5),
		"visor": Color(0.1, 0.8, 0.9),
		"skin": Color(0.85, 0.7, 0.55),
		"sword": Color(0.75, 0.8, 0.85),
		"sword_glow": Color(0.5, 0.7, 1.0),
		"shield": Color(0.2, 0.3, 0.6),
		"shield_rim": Color(0.6, 0.65, 0.8),
		"boot": Color(0.2, 0.2, 0.35),
		"shadow": Color(0, 0, 0, 0.3),
	}
	# Shadow
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Boots
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	# Legs (armor)
	_fill_rect(img, 11, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 17, 32, 4, 9, c["armor_dark"])
	# Torso
	_fill_rect(img, 9, 18, 14, 15, c["armor_mid"])
	_fill_rect(img, 10, 19, 12, 13, c["armor_light"])
	# Belt
	_fill_rect(img, 9, 30, 14, 3, c["armor_dark"])
	# Shoulder pads
	_fill_rect(img, 5, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 18, 6, 5, c["armor_mid"])
	# Head/Helm
	_fill_rect(img, 11, 6, 10, 13, c["helm"])
	_fill_rect(img, 12, 7, 8, 11, c["armor_mid"])
	# Visor
	_fill_rect(img, 13, 11, 6, 3, c["visor"])
	# Helm crest
	_fill_rect(img, 14, 4, 4, 4, c["armor_light"])
	# Sword (right hand)
	_fill_rect(img, 26, 8, 3, 22, c["sword"])
	_fill_rect(img, 27, 6, 2, 4, c["sword_glow"])
	_fill_rect(img, 25, 28, 5, 3, c["armor_dark"])  # Hilt
	# Shield (left hand)
	_fill_rect(img, 2, 20, 7, 10, c["shield"])
	_fill_rect(img, 2, 20, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 28, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 20, 2, 10, c["shield_rim"])

	textures["blade_knight"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = {
		"cloak_dark": Color(0.12, 0.3, 0.15),
		"cloak_mid": Color(0.2, 0.45, 0.25),
		"cloak_light": Color(0.3, 0.6, 0.35),
		"hood": Color(0.15, 0.35, 0.18),
		"skin": Color(0.8, 0.65, 0.5),
		"eyes": Color(0.9, 0.95, 0.4),
		"bow_wood": Color(0.5, 0.35, 0.2),
		"bow_string": Color(0.7, 0.7, 0.65),
		"quiver": Color(0.4, 0.25, 0.15),
		"boot": Color(0.25, 0.2, 0.12),
		"shadow": Color(0, 0, 0, 0.3),
	}
	# Shadow
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Boots
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	# Legs
	_fill_rect(img, 11, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 17, 33, 4, 8, c["cloak_dark"])
	# Torso/Cloak
	_fill_rect(img, 8, 16, 16, 18, c["cloak_mid"])
	_fill_rect(img, 9, 17, 14, 16, c["cloak_light"])
	# Cloak edges (flowing)
	_fill_rect(img, 6, 22, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 22, 3, 16, c["cloak_dark"])
	# Belt
	_fill_rect(img, 8, 30, 16, 2, c["quiver"])
	# Hood
	_fill_rect(img, 10, 6, 12, 11, c["hood"])
	_fill_rect(img, 11, 7, 10, 9, c["cloak_dark"])
	# Face (partially hidden)
	_fill_rect(img, 13, 10, 6, 5, c["skin"])
	# Eyes (glowing)
	_fill_rect(img, 14, 11, 2, 2, c["eyes"])
	_fill_rect(img, 18, 11, 2, 2, c["eyes"])
	# Bow (left side)
	_fill_rect(img, 2, 10, 2, 28, c["bow_wood"])
	_fill_rect(img, 1, 8, 2, 3, c["bow_wood"])
	_fill_rect(img, 1, 37, 2, 3, c["bow_wood"])
	# Bowstring
	_fill_rect(img, 4, 10, 1, 28, c["bow_string"])
	# Quiver on back
	_fill_rect(img, 24, 14, 4, 14, c["quiver"])
	_fill_rect(img, 25, 12, 2, 3, c["bow_wood"])  # Arrow tips

	textures["shadow_ranger"] = ImageTexture.create_from_image(img)

# ============================================================
# ENEMY SPRITES
# ============================================================

func _gen_goblin() -> void:
	var img = Image.create(24, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = {
		"skin": Color(0.3, 0.6, 0.25),
		"skin_dark": Color(0.2, 0.45, 0.15),
		"eyes": Color(0.95, 0.3, 0.1),
		"cloth": Color(0.45, 0.35, 0.2),
		"weapon": Color(0.5, 0.5, 0.45),
		"shadow": Color(0, 0, 0, 0.25),
	}
	_fill_rect(img, 6, 25, 12, 3, c["shadow"])
	# Feet
	_fill_rect(img, 7, 23, 4, 4, c["skin_dark"])
	_fill_rect(img, 13, 23, 4, 4, c["skin_dark"])
	# Legs
	_fill_rect(img, 8, 18, 3, 6, c["cloth"])
	_fill_rect(img, 13, 18, 3, 6, c["cloth"])
	# Body
	_fill_rect(img, 7, 10, 10, 9, c["cloth"])
	_fill_rect(img, 8, 11, 8, 7, c["skin"])
	# Head (large for goblin)
	_fill_rect(img, 6, 1, 12, 10, c["skin"])
	_fill_rect(img, 5, 2, 14, 8, c["skin"])
	# Eyes (big, red)
	_fill_rect(img, 7, 4, 3, 3, c["eyes"])
	_fill_rect(img, 14, 4, 3, 3, c["eyes"])
	# Mouth
	_fill_rect(img, 9, 8, 6, 2, c["skin_dark"])
	# Ears (pointy)
	_fill_rect(img, 3, 3, 3, 2, c["skin"])
	_fill_rect(img, 18, 3, 3, 2, c["skin"])
	# Weapon (small club)
	_fill_rect(img, 19, 8, 3, 10, c["weapon"])
	_fill_rect(img, 18, 6, 5, 3, c["weapon"])

	textures["goblin"] = ImageTexture.create_from_image(img)

func _gen_wolf() -> void:
	var img = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = {
		"fur": Color(0.45, 0.35, 0.25),
		"fur_dark": Color(0.3, 0.22, 0.15),
		"fur_light": Color(0.55, 0.45, 0.35),
		"eyes": Color(0.9, 0.8, 0.2),
		"nose": Color(0.15, 0.1, 0.1),
		"shadow": Color(0, 0, 0, 0.25),
	}
	_fill_rect(img, 6, 21, 20, 3, c["shadow"])
	# Legs
	_fill_rect(img, 7, 17, 3, 6, c["fur_dark"])
	_fill_rect(img, 13, 17, 3, 6, c["fur_dark"])
	_fill_rect(img, 19, 17, 3, 6, c["fur_dark"])
	_fill_rect(img, 24, 17, 3, 6, c["fur_dark"])
	# Body
	_fill_rect(img, 8, 9, 18, 9, c["fur"])
	_fill_rect(img, 9, 10, 16, 7, c["fur_light"])
	# Head
	_fill_rect(img, 2, 6, 10, 8, c["fur"])
	_fill_rect(img, 1, 7, 4, 6, c["fur"])  # Snout
	# Eyes
	_fill_rect(img, 5, 8, 2, 2, c["eyes"])
	_fill_rect(img, 9, 8, 2, 2, c["eyes"])
	# Nose
	_fill_rect(img, 1, 10, 2, 2, c["nose"])
	# Ears
	_fill_rect(img, 4, 4, 3, 3, c["fur_dark"])
	_fill_rect(img, 9, 4, 3, 3, c["fur_dark"])
	# Tail
	_fill_rect(img, 26, 6, 4, 3, c["fur"])
	_fill_rect(img, 29, 4, 3, 3, c["fur_dark"])

	textures["wolf"] = ImageTexture.create_from_image(img)

func _gen_bandit() -> void:
	var img = Image.create(28, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = {
		"tunic": Color(0.5, 0.2, 0.2),
		"tunic_dark": Color(0.35, 0.15, 0.12),
		"skin": Color(0.75, 0.6, 0.45),
		"hair": Color(0.25, 0.18, 0.12),
		"eyes": Color(0.2, 0.2, 0.2),
		"belt": Color(0.3, 0.25, 0.15),
		"boot": Color(0.25, 0.18, 0.1),
		"sword": Color(0.6, 0.6, 0.65),
		"shadow": Color(0, 0, 0, 0.25),
	}
	_fill_rect(img, 6, 37, 16, 3, c["shadow"])
	# Boots
	_fill_rect(img, 8, 34, 5, 5, c["boot"])
	_fill_rect(img, 15, 34, 5, 5, c["boot"])
	# Legs
	_fill_rect(img, 9, 26, 4, 9, c["tunic_dark"])
	_fill_rect(img, 15, 26, 4, 9, c["tunic_dark"])
	# Torso
	_fill_rect(img, 7, 14, 14, 13, c["tunic"])
	_fill_rect(img, 8, 15, 12, 11, c["tunic_dark"])
	# Belt
	_fill_rect(img, 7, 25, 14, 2, c["belt"])
	# Arms
	_fill_rect(img, 4, 15, 4, 10, c["tunic"])
	_fill_rect(img, 20, 15, 4, 10, c["tunic"])
	# Head
	_fill_rect(img, 9, 3, 10, 12, c["skin"])
	# Hair
	_fill_rect(img, 8, 2, 12, 5, c["hair"])
	_fill_rect(img, 8, 2, 3, 8, c["hair"])
	# Eyes
	_fill_rect(img, 11, 8, 2, 2, c["eyes"])
	_fill_rect(img, 15, 8, 2, 2, c["eyes"])
	# Bandana
	_fill_rect(img, 8, 5, 12, 2, c["tunic"])
	# Sword
	_fill_rect(img, 23, 10, 2, 18, c["sword"])
	_fill_rect(img, 22, 26, 4, 3, c["belt"])

	textures["bandit"] = ImageTexture.create_from_image(img)

# ============================================================
# ENVIRONMENT SPRITES
# ============================================================

func _gen_tree_jungle() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Shadow (isometric oval)
	_fill_ellipse(img, 16, 45, 14, 3, Color(0, 0, 0, 0.3))
	# Trunk with bark detail
	_fill_rect(img, 13, 28, 6, 18, Color(0.25, 0.15, 0.08))
	_fill_rect(img, 14, 30, 4, 14, Color(0.3, 0.2, 0.1))
	_fill_rect(img, 15, 32, 2, 10, Color(0.35, 0.24, 0.12))  # Bark highlight
	# Dark canopy base (SC:BW dark jungle)
	_fill_ellipse(img, 16, 18, 15, 15, Color(0.04, 0.12, 0.03))
	# Canopy layers
	_fill_ellipse(img, 12, 15, 11, 11, Color(0.06, 0.18, 0.04))
	_fill_ellipse(img, 20, 13, 11, 11, Color(0.05, 0.16, 0.04))
	_fill_ellipse(img, 16, 11, 13, 11, Color(0.08, 0.22, 0.06))
	# Top canopy (lighter)
	_fill_ellipse(img, 15, 9, 9, 7, Color(0.1, 0.28, 0.08))
	# Highlights (dappled light)
	_fill_rect(img, 11, 7, 4, 3, Color(0.14, 0.35, 0.1))
	_fill_rect(img, 18, 11, 3, 3, Color(0.12, 0.32, 0.1))
	_fill_rect(img, 14, 14, 2, 2, Color(0.16, 0.38, 0.12))
	# Dark shadow areas in canopy
	_fill_rect(img, 8, 16, 4, 4, Color(0.03, 0.08, 0.02))
	_fill_rect(img, 20, 18, 3, 3, Color(0.03, 0.09, 0.02))

	textures["tree_jungle"] = ImageTexture.create_from_image(img)

func _gen_tree_small() -> void:
	var img = Image.create(20, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 10, 26, 8, 2, Color(0, 0, 0, 0.25))
	# Trunk
	_fill_rect(img, 8, 18, 4, 9, Color(0.25, 0.16, 0.08))
	_fill_rect(img, 9, 20, 2, 6, Color(0.3, 0.2, 0.1))
	# Dark canopy
	_fill_ellipse(img, 10, 12, 9, 10, Color(0.05, 0.16, 0.04))
	_fill_ellipse(img, 10, 10, 8, 8, Color(0.08, 0.22, 0.06))
	_fill_ellipse(img, 10, 8, 6, 6, Color(0.1, 0.28, 0.08))
	# Highlight
	_fill_rect(img, 8, 6, 3, 2, Color(0.14, 0.34, 0.1))

	textures["tree_small"] = ImageTexture.create_from_image(img)

func _gen_rock() -> void:
	var img = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 8, 8, 7, 4, Color(0, 0, 0, 0.15))  # Shadow
	_fill_ellipse(img, 8, 7, 7, 5, Color(0.28, 0.26, 0.22))
	_fill_ellipse(img, 7, 6, 5, 4, Color(0.35, 0.33, 0.28))
	_fill_rect(img, 4, 3, 3, 2, Color(0.42, 0.4, 0.35))
	# Moss
	_fill_rect(img, 2, 6, 3, 2, Color(0.1, 0.22, 0.08))

	textures["rock"] = ImageTexture.create_from_image(img)

func _gen_rock_large() -> void:
	var img = Image.create(28, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 14, 16, 13, 4, Color(0, 0, 0, 0.2))  # Shadow
	_fill_ellipse(img, 14, 12, 13, 8, Color(0.25, 0.23, 0.2))
	_fill_ellipse(img, 12, 10, 10, 6, Color(0.32, 0.3, 0.26))
	_fill_ellipse(img, 18, 8, 6, 5, Color(0.28, 0.26, 0.23))
	_fill_rect(img, 8, 5, 6, 3, Color(0.38, 0.36, 0.32))
	# Moss patches
	_fill_ellipse(img, 8, 10, 4, 3, Color(0.08, 0.2, 0.06))
	_fill_rect(img, 18, 12, 3, 2, Color(0.1, 0.22, 0.08))

	textures["rock_large"] = ImageTexture.create_from_image(img)

func _gen_bush() -> void:
	var img = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 8, 8, 7, 4, Color(0.06, 0.18, 0.05))
	_fill_ellipse(img, 8, 7, 7, 5, Color(0.08, 0.24, 0.06))
	_fill_ellipse(img, 6, 5, 4, 4, Color(0.1, 0.3, 0.08))
	_fill_ellipse(img, 11, 6, 4, 3, Color(0.09, 0.26, 0.07))
	# Highlight
	_fill_rect(img, 5, 4, 2, 2, Color(0.14, 0.35, 0.1))

	textures["bush"] = ImageTexture.create_from_image(img)

func _gen_flowers() -> void:
	var img = Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Stems
	img.set_pixel(3, 5, Color(0.2, 0.5, 0.15))
	img.set_pixel(7, 6, Color(0.2, 0.5, 0.15))
	img.set_pixel(11, 5, Color(0.2, 0.5, 0.15))
	# Petals
	_fill_rect(img, 2, 3, 3, 3, Color(0.9, 0.8, 0.2))
	_fill_rect(img, 6, 4, 3, 3, Color(0.85, 0.3, 0.5))
	_fill_rect(img, 10, 3, 3, 3, Color(0.7, 0.4, 0.85))
	# Centers
	img.set_pixel(3, 4, Color(0.95, 0.95, 0.3))
	img.set_pixel(7, 5, Color(0.95, 0.5, 0.6))
	img.set_pixel(11, 4, Color(0.85, 0.6, 0.95))

	textures["flowers"] = ImageTexture.create_from_image(img)

# ============================================================
# BUILDINGS
# ============================================================

func _gen_shop_building() -> void:
	var img = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Shadow
	_fill_rect(img, 4, 34, 32, 5, Color(0, 0, 0, 0.2))
	# Base
	_fill_rect(img, 4, 16, 32, 20, Color(0.45, 0.35, 0.25))
	_fill_rect(img, 5, 17, 30, 18, Color(0.55, 0.42, 0.3))
	# Roof
	_fill_rect(img, 2, 10, 36, 8, Color(0.35, 0.15, 0.1))
	_fill_rect(img, 4, 8, 32, 4, Color(0.4, 0.18, 0.12))
	_fill_rect(img, 8, 6, 24, 4, Color(0.45, 0.2, 0.13))
	# Door
	_fill_rect(img, 15, 24, 10, 12, Color(0.3, 0.2, 0.12))
	_fill_rect(img, 16, 25, 8, 10, Color(0.25, 0.15, 0.08))
	# Windows
	_fill_rect(img, 7, 20, 6, 5, Color(0.3, 0.5, 0.7))
	_fill_rect(img, 27, 20, 6, 5, Color(0.3, 0.5, 0.7))
	# Window frames
	_fill_rect(img, 7, 22, 6, 1, Color(0.35, 0.25, 0.15))
	_fill_rect(img, 10, 20, 1, 5, Color(0.35, 0.25, 0.15))
	_fill_rect(img, 27, 22, 6, 1, Color(0.35, 0.25, 0.15))
	_fill_rect(img, 30, 20, 1, 5, Color(0.35, 0.25, 0.15))
	# Sign
	_fill_rect(img, 34, 18, 5, 8, Color(0.5, 0.4, 0.2))

	textures["shop_building"] = ImageTexture.create_from_image(img)

func _gen_town_hall() -> void:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 40, 40, 6, Color(0, 0, 0, 0.2))
	# Base
	_fill_rect(img, 4, 18, 40, 26, Color(0.5, 0.45, 0.35))
	_fill_rect(img, 5, 19, 38, 24, Color(0.6, 0.52, 0.4))
	# Roof
	_fill_rect(img, 2, 12, 44, 8, Color(0.3, 0.25, 0.2))
	_fill_rect(img, 6, 8, 36, 6, Color(0.35, 0.28, 0.22))
	_fill_rect(img, 12, 4, 24, 6, Color(0.4, 0.3, 0.25))
	# Flag on top
	_fill_rect(img, 22, 0, 2, 6, Color(0.4, 0.3, 0.2))
	_fill_rect(img, 24, 0, 6, 4, Color(0.2, 0.5, 0.8))
	# Door
	_fill_rect(img, 18, 28, 12, 16, Color(0.3, 0.22, 0.14))
	# Columns
	_fill_rect(img, 8, 18, 4, 26, Color(0.55, 0.5, 0.4))
	_fill_rect(img, 36, 18, 4, 26, Color(0.55, 0.5, 0.4))

	textures["town_hall"] = ImageTexture.create_from_image(img)

# ============================================================
# BEACONS (glowing circle pads)
# ============================================================

func _gen_beacon_green() -> void:
	textures["beacon_green"] = _make_beacon(Color(0.2, 0.9, 0.3))

func _gen_beacon_yellow() -> void:
	textures["beacon_yellow"] = _make_beacon(Color(0.95, 0.85, 0.2))

func _gen_beacon_blue() -> void:
	textures["beacon_blue"] = _make_beacon(Color(0.3, 0.5, 1.0))

func _gen_beacon_red() -> void:
	textures["beacon_red"] = _make_beacon(Color(0.9, 0.2, 0.2))

func _make_beacon(color: Color) -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Outer glow
	_fill_ellipse(img, 16, 16, 15, 15, Color(color.r, color.g, color.b, 0.15))
	# Mid ring
	_fill_ellipse(img, 16, 16, 12, 12, Color(color.r, color.g, color.b, 0.25))
	# Inner bright
	_fill_ellipse(img, 16, 16, 8, 8, Color(color.r, color.g, color.b, 0.4))
	# Center
	_fill_ellipse(img, 16, 16, 4, 4, Color(color.r, color.g, color.b, 0.7))
	return ImageTexture.create_from_image(img)

# ============================================================
# ITEM CRYSTALS
# ============================================================

func _gen_crystal_blue() -> void:
	var img = Image.create(12, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Crystal shape
	_fill_rect(img, 4, 2, 4, 10, Color(0.3, 0.5, 0.9))
	_fill_rect(img, 3, 4, 6, 6, Color(0.4, 0.6, 1.0))
	_fill_rect(img, 5, 1, 2, 2, Color(0.5, 0.7, 1.0))
	# Highlight
	_fill_rect(img, 4, 3, 2, 3, Color(0.7, 0.85, 1.0))
	# Glow base
	_fill_ellipse(img, 6, 12, 5, 2, Color(0.3, 0.5, 0.9, 0.3))

	textures["crystal_blue"] = ImageTexture.create_from_image(img)

func _gen_crystal_white() -> void:
	var img = Image.create(8, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 2, 1, 4, 7, Color(0.75, 0.8, 0.9))
	_fill_rect(img, 3, 0, 2, 2, Color(0.85, 0.9, 1.0))
	_fill_rect(img, 3, 2, 2, 2, Color(0.9, 0.95, 1.0))

	textures["crystal_white"] = ImageTexture.create_from_image(img)

func _gen_crystal_teal() -> void:
	var img = Image.create(14, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 1, 6, 12, Color(0.2, 0.7, 0.7))
	_fill_rect(img, 3, 3, 8, 8, Color(0.25, 0.8, 0.8))
	_fill_rect(img, 5, 0, 4, 3, Color(0.3, 0.9, 0.9))
	_fill_rect(img, 5, 2, 3, 3, Color(0.6, 1.0, 1.0))
	_fill_ellipse(img, 7, 14, 6, 2, Color(0.2, 0.7, 0.7, 0.3))

	textures["crystal_teal"] = ImageTexture.create_from_image(img)

# ============================================================
# TERRAIN TILES (16x16)
# ============================================================

func _gen_grass_dark() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.25, 0.08))
	# Variation
	for i in range(8):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.12, 0.3, 0.1))
	for i in range(4):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.08, 0.2, 0.06))

	textures["grass_dark"] = ImageTexture.create_from_image(img)

func _gen_grass_light() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.15, 0.32, 0.12))
	for i in range(6):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.18, 0.38, 0.15))

	textures["grass_light"] = ImageTexture.create_from_image(img)

func _gen_dirt() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.35, 0.25, 0.15))
	for i in range(6):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.4, 0.3, 0.18))

	textures["dirt"] = ImageTexture.create_from_image(img)

func _gen_dirt_path() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.22, 0.12))
	for i in range(4):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.25, 0.18, 0.1))
	for i in range(3):
		var x = randi_range(0, 15)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.35, 0.26, 0.15))

	textures["dirt_path"] = ImageTexture.create_from_image(img)

func _gen_water() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.25, 0.35))
	for i in range(5):
		var x = randi_range(0, 14)
		var y = randi_range(0, 15)
		img.set_pixel(x, y, Color(0.15, 0.3, 0.4))
		img.set_pixel(x + 1, y, Color(0.15, 0.3, 0.4))

	textures["water"] = ImageTexture.create_from_image(img)

func _gen_stone_floor() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.38, 0.35))
	# Grid lines
	for x in range(16):
		img.set_pixel(x, 0, Color(0.35, 0.33, 0.3))
		img.set_pixel(x, 8, Color(0.35, 0.33, 0.3))
	for y in range(16):
		img.set_pixel(0, y, Color(0.35, 0.33, 0.3))
		img.set_pixel(8, y, Color(0.35, 0.33, 0.3))

	textures["stone_floor"] = ImageTexture.create_from_image(img)

# ============================================================
# RICH GROUND TILES (128x128 — SC:BW jungle terrain)
# ============================================================

func _gen_ground_jungle() -> void:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Base dark jungle green
	img.fill(Color(0.06, 0.14, 0.04))

	# Simulate noise-like variation with overlapping patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic for consistent look

	# Large terrain patches (dirt/darker grass areas)
	for _i in range(18):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(8, 25)
		var ry = rng.randi_range(6, 20)
		var shade = rng.randf_range(0.0, 1.0)
		var patch_color: Color
		if shade < 0.3:
			# Dirt patch
			patch_color = Color(
				rng.randf_range(0.12, 0.18),
				rng.randf_range(0.08, 0.12),
				rng.randf_range(0.03, 0.06))
		elif shade < 0.6:
			# Dark green
			patch_color = Color(
				rng.randf_range(0.04, 0.08),
				rng.randf_range(0.1, 0.18),
				rng.randf_range(0.03, 0.06))
		else:
			# Slightly lighter green
			patch_color = Color(
				rng.randf_range(0.07, 0.12),
				rng.randf_range(0.16, 0.24),
				rng.randf_range(0.04, 0.08))
		_fill_ellipse(img, cx, cy, rx, ry, patch_color)

	# Medium detail patches
	for _i in range(40):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(3, 10)
		var ry = rng.randi_range(2, 8)
		var c = Color(
			rng.randf_range(0.05, 0.14),
			rng.randf_range(0.1, 0.22),
			rng.randf_range(0.03, 0.08))
		_fill_ellipse(img, cx, cy, rx, ry, c)

	# Fine pixel noise for texture
	for _i in range(600):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		var existing = img.get_pixel(x, y)
		var variation = rng.randf_range(-0.03, 0.03)
		img.set_pixel(x, y, Color(
			clampf(existing.r + variation, 0.02, 0.2),
			clampf(existing.g + variation * 1.5, 0.06, 0.28),
			clampf(existing.b + variation * 0.5, 0.01, 0.1)))

	# Occasional tiny bright green specks (grass tips)
	for _i in range(80):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		img.set_pixel(x, y, Color(
			rng.randf_range(0.12, 0.2),
			rng.randf_range(0.28, 0.4),
			rng.randf_range(0.06, 0.12)))

	# Tiny dark shadow spots
	for _i in range(30):
		var x = rng.randi_range(0, size - 2)
		var y = rng.randi_range(0, size - 2)
		var dark = Color(0.03, 0.06, 0.02)
		img.set_pixel(x, y, dark)
		img.set_pixel(x + 1, y, dark)
		img.set_pixel(x, y + 1, dark)

	textures["ground_jungle"] = ImageTexture.create_from_image(img)

func _gen_ground_creep() -> void:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Dark corrupted ground (like SC:BW zerg creep / dark wasteland)
	img.fill(Color(0.08, 0.06, 0.04))

	var rng = RandomNumberGenerator.new()
	rng.seed = 99

	# Dark brown/purple patches
	for _i in range(20):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(6, 22)
		var ry = rng.randi_range(5, 18)
		var patch_color = Color(
			rng.randf_range(0.06, 0.14),
			rng.randf_range(0.04, 0.1),
			rng.randf_range(0.03, 0.08))
		_fill_ellipse(img, cx, cy, rx, ry, patch_color)

	# Reddish-brown blood/corruption spots
	for _i in range(12):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(3, 8)
		var ry = rng.randi_range(2, 6)
		_fill_ellipse(img, cx, cy, rx, ry, Color(
			rng.randf_range(0.12, 0.2),
			rng.randf_range(0.05, 0.1),
			rng.randf_range(0.04, 0.07)))

	# Pixel noise
	for _i in range(400):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		var existing = img.get_pixel(x, y)
		var v = rng.randf_range(-0.02, 0.02)
		img.set_pixel(x, y, Color(
			clampf(existing.r + v, 0.03, 0.2),
			clampf(existing.g + v, 0.02, 0.12),
			clampf(existing.b + v * 0.5, 0.01, 0.1)))

	textures["ground_creep"] = ImageTexture.create_from_image(img)

func _gen_ground_stone() -> void:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Stone floor for town area
	img.fill(Color(0.28, 0.26, 0.22))

	var rng = RandomNumberGenerator.new()
	rng.seed = 77

	# Stone block grid lines
	for x in range(size):
		for y_line in [0, 16, 32, 48, 64, 80, 96, 112]:
			if y_line < size:
				var existing = img.get_pixel(x, y_line)
				img.set_pixel(x, y_line, existing.darkened(0.25))
	for y in range(size):
		# Offset every other row for brick pattern
		var row = y / 16
		var x_offset = 8 if row % 2 == 1 else 0
		for x_line in [0, 16, 32, 48, 64, 80, 96, 112]:
			var actual_x = (x_line + x_offset) % size
			if actual_x < size:
				var existing = img.get_pixel(actual_x, y)
				img.set_pixel(actual_x, y, existing.darkened(0.2))

	# Subtle color variation per "stone block"
	for _i in range(30):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(3, 7)
		var ry = rng.randi_range(3, 7)
		var v = rng.randf_range(-0.04, 0.04)
		_fill_ellipse(img, cx, cy, rx, ry, Color(
			0.28 + v, 0.26 + v, 0.22 + v * 0.5))

	# Pixel noise for weathered look
	for _i in range(300):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		var existing = img.get_pixel(x, y)
		var v = rng.randf_range(-0.03, 0.03)
		img.set_pixel(x, y, Color(
			clampf(existing.r + v, 0.18, 0.38),
			clampf(existing.g + v, 0.16, 0.36),
			clampf(existing.b + v, 0.12, 0.32)))

	textures["ground_stone"] = ImageTexture.create_from_image(img)

# ============================================================
# ATMOSPHERIC DECORATIONS
# ============================================================

func _gen_grass_tuft() -> void:
	var img = Image.create(12, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Several grass blades
	var greens = [
		Color(0.1, 0.3, 0.08),
		Color(0.12, 0.35, 0.1),
		Color(0.08, 0.25, 0.06),
		Color(0.14, 0.38, 0.12),
	]
	# Blade 1
	_fill_rect(img, 2, 3, 2, 7, greens[0])
	_fill_rect(img, 1, 2, 2, 2, greens[1])
	# Blade 2
	_fill_rect(img, 5, 4, 2, 6, greens[2])
	_fill_rect(img, 6, 2, 2, 3, greens[3])
	# Blade 3
	_fill_rect(img, 8, 3, 2, 7, greens[1])
	_fill_rect(img, 9, 1, 2, 3, greens[0])
	textures["grass_tuft"] = ImageTexture.create_from_image(img)

func _gen_grass_tuft_tall() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var greens = [
		Color(0.08, 0.22, 0.06),
		Color(0.1, 0.28, 0.08),
		Color(0.12, 0.32, 0.1),
		Color(0.15, 0.38, 0.12),
	]
	# Tall swaying blades
	_fill_rect(img, 2, 4, 2, 12, greens[0])
	_fill_rect(img, 1, 2, 2, 4, greens[1])
	_fill_rect(img, 5, 3, 2, 13, greens[2])
	_fill_rect(img, 6, 1, 2, 3, greens[3])
	_fill_rect(img, 9, 5, 2, 11, greens[1])
	_fill_rect(img, 10, 3, 2, 3, greens[0])
	_fill_rect(img, 12, 4, 2, 12, greens[2])
	_fill_rect(img, 13, 1, 2, 4, greens[3])
	textures["grass_tuft_tall"] = ImageTexture.create_from_image(img)

func _gen_mushroom_cluster() -> void:
	var img = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Mushroom 1
	_fill_rect(img, 3, 7, 2, 5, Color(0.6, 0.55, 0.45))  # Stem
	_fill_ellipse(img, 4, 6, 4, 3, Color(0.55, 0.2, 0.15))  # Cap
	_fill_rect(img, 3, 5, 2, 1, Color(0.7, 0.3, 0.2))  # Cap highlight
	# Mushroom 2 (smaller)
	_fill_rect(img, 10, 8, 2, 4, Color(0.55, 0.5, 0.4))
	_fill_ellipse(img, 11, 7, 3, 2, Color(0.5, 0.18, 0.12))
	# Spots on caps
	img.set_pixel(3, 5, Color(0.9, 0.85, 0.7))
	img.set_pixel(5, 6, Color(0.9, 0.85, 0.7))
	img.set_pixel(10, 7, Color(0.85, 0.8, 0.65))
	textures["mushroom_cluster"] = ImageTexture.create_from_image(img)

func _gen_fallen_log() -> void:
	var img = Image.create(40, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Shadow
	_fill_ellipse(img, 20, 11, 18, 3, Color(0, 0, 0, 0.15))
	# Log body
	_fill_rect(img, 2, 4, 36, 7, Color(0.3, 0.2, 0.12))
	_fill_rect(img, 3, 5, 34, 5, Color(0.35, 0.24, 0.14))
	# Bark texture lines
	_fill_rect(img, 6, 4, 1, 7, Color(0.25, 0.16, 0.1))
	_fill_rect(img, 14, 4, 1, 7, Color(0.25, 0.16, 0.1))
	_fill_rect(img, 22, 4, 1, 7, Color(0.25, 0.16, 0.1))
	_fill_rect(img, 30, 4, 1, 7, Color(0.25, 0.16, 0.1))
	# Moss patches
	_fill_rect(img, 8, 4, 4, 2, Color(0.12, 0.3, 0.1))
	_fill_rect(img, 24, 5, 3, 2, Color(0.1, 0.25, 0.08))
	# End circles
	_fill_ellipse(img, 2, 7, 3, 4, Color(0.28, 0.18, 0.1))
	_fill_ellipse(img, 37, 7, 3, 4, Color(0.28, 0.18, 0.1))
	textures["fallen_log"] = ImageTexture.create_from_image(img)

func _gen_vines() -> void:
	var img = Image.create(20, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Curving vine lines
	var vine_green = Color(0.1, 0.28, 0.08)
	var vine_dark = Color(0.06, 0.18, 0.04)
	# Main vine
	_fill_rect(img, 9, 0, 2, 24, vine_green)
	# Branches
	_fill_rect(img, 4, 4, 6, 2, vine_dark)
	_fill_rect(img, 11, 8, 6, 2, vine_dark)
	_fill_rect(img, 2, 14, 8, 2, vine_green)
	_fill_rect(img, 12, 18, 5, 2, vine_dark)
	# Small leaves
	_fill_rect(img, 2, 3, 3, 3, Color(0.12, 0.32, 0.1))
	_fill_rect(img, 15, 7, 3, 3, Color(0.14, 0.35, 0.12))
	_fill_rect(img, 1, 13, 3, 3, Color(0.1, 0.28, 0.08))
	_fill_rect(img, 16, 17, 3, 3, Color(0.12, 0.3, 0.1))
	textures["vines"] = ImageTexture.create_from_image(img)

func _gen_ground_debris() -> void:
	var img = Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Small sticks, pebbles, leaf litter
	_fill_rect(img, 1, 3, 5, 1, Color(0.3, 0.2, 0.12))  # Stick
	_fill_rect(img, 8, 2, 1, 3, Color(0.28, 0.18, 0.1))  # Stick
	# Pebbles
	img.set_pixel(11, 4, Color(0.4, 0.38, 0.34))
	img.set_pixel(12, 5, Color(0.38, 0.36, 0.32))
	img.set_pixel(14, 3, Color(0.42, 0.4, 0.36))
	# Dead leaf
	_fill_rect(img, 4, 5, 3, 2, Color(0.35, 0.22, 0.08))
	img.set_pixel(5, 6, Color(0.4, 0.28, 0.1))
	textures["ground_debris"] = ImageTexture.create_from_image(img)

func _gen_dirt_patch() -> void:
	# Larger dirt/mud area for variety
	var img = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 16, 12, 15, 11, Color(0.14, 0.1, 0.06, 0.7))
	_fill_ellipse(img, 14, 11, 11, 8, Color(0.16, 0.12, 0.07, 0.6))
	_fill_ellipse(img, 18, 13, 8, 6, Color(0.18, 0.14, 0.08, 0.5))
	textures["dirt_patch"] = ImageTexture.create_from_image(img)

func _gen_skull_icon() -> void:
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 6, 5, 5, 5, Color(0.9, 0.85, 0.75))
	# Eye sockets
	_fill_rect(img, 3, 3, 2, 3, Color(0.2, 0.1, 0.1))
	_fill_rect(img, 7, 3, 2, 3, Color(0.2, 0.1, 0.1))
	# Nose
	img.set_pixel(5, 6, Color(0.3, 0.2, 0.15))
	img.set_pixel(6, 6, Color(0.3, 0.2, 0.15))
	# Jaw
	_fill_rect(img, 3, 8, 6, 3, Color(0.8, 0.75, 0.65))
	_fill_rect(img, 4, 9, 1, 1, Color(0.2, 0.15, 0.1))
	_fill_rect(img, 7, 9, 1, 1, Color(0.2, 0.15, 0.1))

	textures["skull_icon"] = ImageTexture.create_from_image(img)

# ============================================================
# SELECTION CIRCLES & VFX
# ============================================================

func _gen_selection_circle_green() -> void:
	textures["selection_green"] = _make_selection_circle(Color(0.2, 1.0, 0.3))

func _gen_selection_circle_red() -> void:
	textures["selection_red"] = _make_selection_circle(Color(1.0, 0.2, 0.2))

func _make_selection_circle(color: Color) -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = size / 2
	var cy = size / 2
	# Isometric ellipse (wider than tall)
	var rx = 14
	var ry = 8
	for py in range(size):
		for px in range(size):
			var dx = float(px - cx) / float(rx)
			var dy = float(py - cy) / float(ry)
			var d = dx * dx + dy * dy
			if d <= 1.0 and d >= 0.65:
				img.set_pixel(px, py, Color(color.r, color.g, color.b, 0.9))
			elif d < 0.65 and d >= 0.5:
				img.set_pixel(px, py, Color(color.r, color.g, color.b, 0.3))
	return ImageTexture.create_from_image(img)

func _gen_iso_shadow() -> void:
	var img = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 16, 8, 14, 6, Color(0, 0, 0, 0.25))
	textures["iso_shadow"] = ImageTexture.create_from_image(img)

func _gen_slash_arc() -> void:
	# A white slash arc shape for melee attack VFX
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = 24
	var cy = 24
	# Draw a crescent/arc shape
	for py in range(48):
		for px in range(48):
			var dx = float(px - cx)
			var dy = float(py - cy)
			var dist = sqrt(dx * dx + dy * dy)
			if dist >= 14.0 and dist <= 22.0:
				# Only draw the right half arc (0 to PI)
				var angle = atan2(dy, dx)
				if angle >= -PI * 0.6 and angle <= PI * 0.6:
					var alpha = 1.0 - (dist - 14.0) / 8.0
					alpha = clampf(alpha * 1.5, 0.0, 1.0)
					img.set_pixel(px, py, Color(1.0, 0.95, 0.8, alpha))
	textures["slash_arc"] = ImageTexture.create_from_image(img)

func _gen_arrow_projectile() -> void:
	var img = Image.create(16, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Arrow shaft
	_fill_rect(img, 2, 2, 12, 2, Color(0.5, 0.35, 0.2))
	# Arrow head
	_fill_rect(img, 13, 1, 2, 4, Color(0.6, 0.6, 0.65))
	_fill_rect(img, 15, 2, 1, 2, Color(0.7, 0.7, 0.75))
	# Fletching
	_fill_rect(img, 0, 0, 3, 2, Color(0.8, 0.8, 0.8))
	_fill_rect(img, 0, 4, 3, 2, Color(0.8, 0.8, 0.8))
	textures["arrow_projectile"] = ImageTexture.create_from_image(img)

# ============================================================
# DRAWING HELPERS
# ============================================================

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(max(0, y), min(img.get_height(), y + h)):
		for px in range(max(0, x), min(img.get_width(), x + w)):
			if color.a < 1.0:
				var existing = img.get_pixel(px, py)
				img.set_pixel(px, py, existing.blend(color))
			else:
				img.set_pixel(px, py, color)

func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for py in range(max(0, cy - ry), min(img.get_height(), cy + ry)):
		for px in range(max(0, cx - rx), min(img.get_width(), cx + rx)):
			var dx = float(px - cx) / float(rx)
			var dy = float(py - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				if color.a < 1.0:
					var existing = img.get_pixel(px, py)
					img.set_pixel(px, py, existing.blend(color))
				else:
					img.set_pixel(px, py, color)
