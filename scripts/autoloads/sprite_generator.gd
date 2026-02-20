extends Node

## Hybrid sprite system: loads external PNGs from res://assets/sprites/ first,
## falls back to procedural generation via Godot's Image API.
## SC:BW jungle tileset aesthetic with chunky readable pixel art.

# Cache generated textures
var textures: Dictionary = {}

# Maps sprite names to asset subdirectories for external file lookup
var _asset_dirs: Dictionary = {}

func _ready() -> void:
	_init_asset_dirs()
	_generate_all()

func get_texture(name: String) -> ImageTexture:
	return textures.get(name, null)

## Try loading a PNG from res://assets/sprites/<subdir>/<name>.png
## Returns true if loaded successfully, false to fall back to procedural.
func _try_load_external(sprite_name: String) -> bool:
	var subdir: String = _asset_dirs.get(sprite_name, "")
	if subdir.is_empty():
		return false
	var path = "res://assets/sprites/%s/%s.png" % [subdir, sprite_name]
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			textures[sprite_name] = tex
			return true
	return false

func _init_asset_dirs() -> void:
	# Heroes (includes attack animation frames — 5 swing types x 3 frames each)
	var hero_names = ["blade_knight", "shadow_ranger"]
	for swing in ["a", "b", "c", "d", "e"]:
		for frame in [1, 2, 3]:
			hero_names.append("blade_knight_atk%s%d" % [swing, frame])
	# Directional idle sprites for each hero
	for hero in ["blade_knight", "shadow_ranger"]:
		for dir_key in ["down", "up", "side"]:
			hero_names.append("%s_dir_%s" % [hero, dir_key])
	# Walk cycle frames (3 per direction per hero)
	for hero in ["blade_knight", "shadow_ranger"]:
		for dir_key in ["down", "up", "side"]:
			for frame in [1, 2, 3]:
				hero_names.append("%s_walk_%s_%d" % [hero, dir_key, frame])
	for n in hero_names:
		_asset_dirs[n] = "heroes"
	# Enemies
	for n in ["goblin", "wolf", "bandit"]:
		_asset_dirs[n] = "enemies"
	# Environment
	for n in ["tree_jungle", "tree_small", "tree_dead", "rock", "rock_large",
			"bush", "flowers", "grass_tuft", "grass_tuft_tall",
			"mushroom_cluster", "fallen_log", "vines", "ground_debris",
			"dirt_patch", "cliff_face", "icicles"]:
		_asset_dirs[n] = "environment"
	# Buildings
	for n in ["shop_building", "armory_building", "town_hall", "landing_pad", "hatchery",
			"barracks_building", "inn_building", "watch_tower", "town_fountain",
			"stable_building", "chapel_building",
			"crate_stack", "barrel", "well", "lamp_post", "town_wall_h"]:
		_asset_dirs[n] = "buildings"
	# Beacons
	for n in ["beacon_green", "beacon_yellow", "beacon_blue", "beacon_red", "beacon_cyan"]:
		_asset_dirs[n] = "beacons"
	# Items
	for n in ["crystal_blue", "crystal_white", "crystal_teal"]:
		_asset_dirs[n] = "items"
	# Terrain
	for n in ["grass_dark", "grass_light", "dirt", "dirt_path", "water",
			"stone_floor", "snow", "ice", "ground_jungle", "ground_creep",
			"ground_stone", "ground_snow", "ground_dirt", "town_grass"]:
		_asset_dirs[n] = "terrain"
	# UI
	for n in ["skull_icon", "portrait_frame", "hud_frame"]:
		_asset_dirs[n] = "ui"
	# VFX
	for n in ["selection_green", "selection_red", "iso_shadow", "slash_arc",
			"arrow_projectile", "blood_splatter"]:
		_asset_dirs[n] = "vfx"

func _generate_all() -> void:
	# Heroes (+ attack combo frames: 5 swing types x 3 frames)
	_gen_or_load("blade_knight")
	for swing in ["a", "b", "c", "d", "e"]:
		for frame in [1, 2, 3]:
			_gen_or_load("blade_knight_atk%s%d" % [swing, frame])
	_gen_or_load("shadow_ranger")
	# Directional idle sprites for heroes
	for hero in ["blade_knight", "shadow_ranger"]:
		for dir_key in ["down", "up", "side"]:
			_gen_or_load("%s_dir_%s" % [hero, dir_key])
	# Walk cycle frames for heroes
	for hero in ["blade_knight", "shadow_ranger"]:
		for dir_key in ["down", "up", "side"]:
			for frame in [1, 2, 3]:
				_gen_or_load("%s_walk_%s_%d" % [hero, dir_key, frame])
	# Enemies
	_gen_or_load("goblin")
	_gen_or_load("wolf")
	_gen_or_load("bandit")
	# Environment
	_gen_or_load("tree_jungle")
	_gen_or_load("tree_small")
	_gen_or_load("tree_dead")
	_gen_or_load("rock")
	_gen_or_load("rock_large")
	_gen_or_load("bush")
	_gen_or_load("flowers")
	_gen_or_load("cliff_face")
	_gen_or_load("icicles")
	# Buildings
	_gen_or_load("shop_building")
	_gen_or_load("armory_building")
	_gen_or_load("town_hall")
	_gen_or_load("barracks_building")
	_gen_or_load("inn_building")
	_gen_or_load("watch_tower")
	_gen_or_load("town_fountain")
	_gen_or_load("stable_building")
	_gen_or_load("chapel_building")
	_gen_or_load("crate_stack")
	_gen_or_load("barrel")
	_gen_or_load("well")
	_gen_or_load("lamp_post")
	_gen_or_load("town_wall_h")
	_gen_or_load("town_grass")
	_gen_or_load("landing_pad")
	# Beacons
	_gen_or_load("beacon_green")
	_gen_or_load("beacon_yellow")
	_gen_or_load("beacon_blue")
	_gen_or_load("beacon_red")
	_gen_or_load("beacon_cyan")
	# Items
	_gen_or_load("crystal_blue")
	_gen_or_load("crystal_white")
	_gen_or_load("crystal_teal")
	# Terrain tiles
	_gen_or_load("grass_dark")
	_gen_or_load("grass_light")
	_gen_or_load("dirt")
	_gen_or_load("dirt_path")
	_gen_or_load("water")
	_gen_or_load("stone_floor")
	_gen_or_load("snow")
	_gen_or_load("ice")
	# Rich ground tiles (SC:BW style)
	_gen_or_load("ground_jungle")
	_gen_or_load("ground_creep")
	_gen_or_load("ground_stone")
	_gen_or_load("ground_snow")
	_gen_or_load("ground_dirt")
	# Atmospheric decorations
	_gen_or_load("grass_tuft")
	_gen_or_load("grass_tuft_tall")
	_gen_or_load("mushroom_cluster")
	_gen_or_load("fallen_log")
	_gen_or_load("vines")
	_gen_or_load("ground_debris")
	_gen_or_load("dirt_patch")
	# UI
	_gen_or_load("skull_icon")
	# Selection / VFX
	_gen_or_load("selection_green")
	_gen_or_load("selection_red")
	_gen_or_load("iso_shadow")
	_gen_or_load("slash_arc")
	_gen_or_load("arrow_projectile")
	_gen_or_load("blood_splatter")

## Try external PNG first; if not found, call the procedural generator.
func _gen_or_load(sprite_name: String) -> void:
	if _try_load_external(sprite_name):
		return
	var method_name = "_gen_" + sprite_name
	if has_method(method_name):
		call(method_name)

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

# Shared color palette for blade knight frames
func _bk_colors() -> Dictionary:
	return {
		"armor_dark": Color(0.15, 0.25, 0.55),
		"armor_mid": Color(0.25, 0.4, 0.75),
		"armor_light": Color(0.4, 0.55, 0.9),
		"helm": Color(0.3, 0.35, 0.5),
		"visor": Color(0.1, 0.8, 0.9),
		"skin": Color(0.85, 0.7, 0.55),
		"sword": Color(0.75, 0.8, 0.85),
		"sword_glow": Color(0.5, 0.7, 1.0),
		"sword_trail": Color(0.6, 0.8, 1.0, 0.5),
		"shield": Color(0.2, 0.3, 0.6),
		"shield_rim": Color(0.6, 0.65, 0.8),
		"boot": Color(0.2, 0.2, 0.35),
		"shadow": Color(0, 0, 0, 0.3),
	}

func _bk_draw_body(img: Image, c: Dictionary, lean: int = 0) -> void:
	# Shared body parts (boots, legs, torso, helm) with optional lean offset
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 10 + lean, 40, 5, 6, c["boot"])
	_fill_rect(img, 17 + lean, 40, 5, 6, c["boot"])
	_fill_rect(img, 11 + lean, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 17 + lean, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 9 + lean, 18, 14, 15, c["armor_mid"])
	_fill_rect(img, 10 + lean, 19, 12, 13, c["armor_light"])
	_fill_rect(img, 9 + lean, 30, 14, 3, c["armor_dark"])
	_fill_rect(img, 5 + lean, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 21 + lean, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 11 + lean, 6, 10, 13, c["helm"])
	_fill_rect(img, 12 + lean, 7, 8, 11, c["armor_mid"])
	_fill_rect(img, 13 + lean, 11, 6, 3, c["visor"])
	_fill_rect(img, 14 + lean, 4, 4, 4, c["armor_light"])
	# Shield (left hand)
	_fill_rect(img, 2 + lean, 20, 7, 10, c["shield"])
	_fill_rect(img, 2 + lean, 20, 7, 2, c["shield_rim"])
	_fill_rect(img, 2 + lean, 28, 7, 2, c["shield_rim"])
	_fill_rect(img, 2 + lean, 20, 2, 10, c["shield_rim"])

# ---- Swing A: Left-to-right horizontal slash ----
func _gen_blade_knight_atka1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, -1)
	# Sword pulled back to left, arm cocked
	_fill_rect(img, 0, 14, 10, 3, c["sword"])
	_fill_rect(img, 0, 13, 3, 2, c["sword_glow"])
	_fill_rect(img, 9, 13, 4, 4, c["armor_dark"])
	_fill_rect(img, 13, 14, 5, 6, c["armor_mid"])
	textures["blade_knight_atka1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atka2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 1)
	# Sword sweeping across (horizontal mid)
	_fill_rect(img, 8, 18, 24, 3, c["sword"])
	_fill_rect(img, 28, 17, 4, 2, c["sword_glow"])
	_fill_rect(img, 6, 17, 4, 4, c["armor_dark"])
	# Swing trail
	_fill_rect(img, 10, 16, 18, 1, c["sword_trail"])
	_fill_rect(img, 22, 14, 5, 6, c["armor_mid"])
	textures["blade_knight_atka2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atka3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 2)
	# Sword follow-through to right, extended low
	_fill_rect(img, 20, 26, 12, 3, c["sword"])
	_fill_rect(img, 28, 25, 4, 2, c["sword_glow"])
	_fill_rect(img, 18, 25, 4, 4, c["armor_dark"])
	_fill_rect(img, 22, 24, 8, 1, c["sword_trail"])
	_fill_rect(img, 23, 18, 4, 8, c["armor_mid"])
	textures["blade_knight_atka3"] = ImageTexture.create_from_image(img)

# ---- Swing B: Right-to-left backhand slash ----
func _gen_blade_knight_atkb1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 1)
	# Sword pulled back to right (follow-through position of swing A becomes wind-up)
	_fill_rect(img, 22, 14, 10, 3, c["sword"])
	_fill_rect(img, 29, 13, 3, 2, c["sword_glow"])
	_fill_rect(img, 20, 13, 4, 4, c["armor_dark"])
	_fill_rect(img, 22, 16, 5, 6, c["armor_mid"])
	textures["blade_knight_atkb1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkb2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 0)
	# Sword sweeping back across left (backhand)
	_fill_rect(img, 0, 20, 24, 3, c["sword"])
	_fill_rect(img, 0, 19, 4, 2, c["sword_glow"])
	_fill_rect(img, 22, 19, 4, 4, c["armor_dark"])
	_fill_rect(img, 4, 18, 18, 1, c["sword_trail"])
	_fill_rect(img, 18, 16, 5, 6, c["armor_mid"])
	textures["blade_knight_atkb2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkb3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, -1)
	# Sword ends on left side, low
	_fill_rect(img, 0, 28, 12, 3, c["sword"])
	_fill_rect(img, 0, 27, 3, 2, c["sword_glow"])
	_fill_rect(img, 10, 27, 4, 4, c["armor_dark"])
	_fill_rect(img, 2, 26, 8, 1, c["sword_trail"])
	_fill_rect(img, 12, 20, 4, 8, c["armor_mid"])
	textures["blade_knight_atkb3"] = ImageTexture.create_from_image(img)

# ---- Swing C: Overhead chop (finisher) ----
func _gen_blade_knight_atkc1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, -1)
	# Sword raised high above head (two-handed grip feel)
	_fill_rect(img, 14, 0, 4, 12, c["sword"])
	_fill_rect(img, 15, 0, 3, 4, c["sword_glow"])
	_fill_rect(img, 13, 11, 6, 4, c["armor_dark"])
	_fill_rect(img, 19, 10, 5, 8, c["armor_mid"])
	_fill_rect(img, 12, 12, 4, 6, c["armor_mid"])
	textures["blade_knight_atkc1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkc2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 2)
	# Sword mid-chop — vertical blade coming down
	_fill_rect(img, 22, 4, 4, 16, c["sword"])
	_fill_rect(img, 23, 4, 3, 5, c["sword_glow"])
	_fill_rect(img, 21, 18, 6, 4, c["armor_dark"])
	# Vertical trail
	_fill_rect(img, 24, 2, 1, 14, c["sword_trail"])
	_fill_rect(img, 22, 16, 5, 6, c["armor_mid"])
	textures["blade_knight_atkc2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkc3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 3)
	# Sword slammed into ground — blade pointing down at angle
	_fill_rect(img, 24, 24, 4, 18, c["sword"])
	_fill_rect(img, 25, 38, 3, 4, c["sword_glow"])
	_fill_rect(img, 22, 22, 6, 4, c["armor_dark"])
	_fill_rect(img, 25, 20, 1, 16, c["sword_trail"])
	_fill_rect(img, 22, 16, 5, 8, c["armor_mid"])
	textures["blade_knight_atkc3"] = ImageTexture.create_from_image(img)

# ---- Swing D: Upward thrust / uppercut ----
func _gen_blade_knight_atkd1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 0)
	# Sword low, pulled back — about to thrust upward
	_fill_rect(img, 18, 32, 4, 12, c["sword"])
	_fill_rect(img, 19, 40, 3, 4, c["sword_glow"])
	_fill_rect(img, 17, 30, 5, 4, c["armor_dark"])
	_fill_rect(img, 20, 24, 4, 7, c["armor_mid"])
	textures["blade_knight_atkd1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkd2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 1)
	# Sword thrusting upward diagonally
	for i in range(14):
		var px = 20 + i
		var py = 28 - i
		if px >= 0 and px < 32 and py >= 0 and py < 48:
			_fill_rect(img, px, py, 3, 2, c["sword"])
	_fill_rect(img, 30, 16, 2, 3, c["sword_glow"])
	_fill_rect(img, 18, 27, 4, 4, c["armor_dark"])
	# Upward trail
	for i in range(10):
		var px = 22 + i
		var py = 26 - i
		if px >= 0 and px < 32 and py >= 0 and py < 48:
			img.set_pixel(px, py, c["sword_trail"])
	_fill_rect(img, 20, 18, 5, 8, c["armor_mid"])
	textures["blade_knight_atkd2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atkd3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 0)
	# Sword fully extended upward
	_fill_rect(img, 24, 0, 4, 16, c["sword"])
	_fill_rect(img, 25, 0, 3, 5, c["sword_glow"])
	_fill_rect(img, 22, 14, 6, 4, c["armor_dark"])
	_fill_rect(img, 25, 2, 1, 10, c["sword_trail"])
	_fill_rect(img, 22, 12, 5, 8, c["armor_mid"])
	textures["blade_knight_atkd3"] = ImageTexture.create_from_image(img)

# ---- Swing E: Spin slash (360 sweep) ----
func _gen_blade_knight_atke1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 0)
	# Body coiled, sword behind — about to spin
	_fill_rect(img, 0, 16, 10, 3, c["sword"])
	_fill_rect(img, 0, 15, 3, 2, c["sword_glow"])
	_fill_rect(img, 8, 15, 5, 4, c["armor_dark"])
	_fill_rect(img, 12, 16, 5, 6, c["armor_mid"])
	# Coil indicator — slight body tilt
	_fill_rect(img, 8, 22, 3, 3, c["armor_light"])
	textures["blade_knight_atke1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atke2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 0)
	# Mid-spin — sword making a full arc, draw circular trail
	# Sword at top-right
	_fill_rect(img, 22, 6, 8, 3, c["sword"])
	_fill_rect(img, 28, 5, 4, 2, c["sword_glow"])
	_fill_rect(img, 20, 8, 4, 4, c["armor_dark"])
	# Circular trail around the body
	for angle_i in range(12):
		var angle = float(angle_i) / 12.0 * TAU
		var tx = int(16 + cos(angle) * 14)
		var ty = int(24 + sin(angle) * 12)
		if tx >= 0 and tx < 31 and ty >= 0 and ty < 47:
			img.set_pixel(tx, ty, c["sword_trail"])
			img.set_pixel(tx + 1, ty, c["sword_trail"])
	_fill_rect(img, 20, 14, 5, 6, c["armor_mid"])
	textures["blade_knight_atke2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_atke3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_bk_draw_body(img, c, 1)
	# Spin complete — sword extended right at mid-height
	_fill_rect(img, 20, 20, 12, 3, c["sword"])
	_fill_rect(img, 28, 19, 4, 2, c["sword_glow"])
	_fill_rect(img, 18, 19, 4, 4, c["armor_dark"])
	# Full circle trail fading
	for angle_i in range(16):
		var angle = float(angle_i) / 16.0 * TAU
		var tx = int(16 + cos(angle) * 14)
		var ty = int(24 + sin(angle) * 12)
		if tx >= 0 and tx < 31 and ty >= 0 and ty < 47:
			img.set_pixel(tx, ty, c["sword_trail"])
	_fill_rect(img, 22, 16, 5, 6, c["armor_mid"])
	textures["blade_knight_atke3"] = ImageTexture.create_from_image(img)

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
# DIRECTIONAL IDLE SPRITES
# "down" = facing camera (front), "up" = facing away (back),
# "side" = profile view (flip_h handles left vs right)
# ============================================================

# ---- Blade Knight directional sprites ----

func _gen_blade_knight_dir_down() -> void:
	# Front-facing (same as base sprite — armor details, visor visible)
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	_fill_rect(img, 11, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 17, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 9, 18, 14, 15, c["armor_mid"])
	_fill_rect(img, 10, 19, 12, 13, c["armor_light"])
	_fill_rect(img, 9, 30, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 11, 6, 10, 13, c["helm"])
	_fill_rect(img, 12, 7, 8, 11, c["armor_mid"])
	_fill_rect(img, 13, 11, 6, 3, c["visor"])
	_fill_rect(img, 14, 4, 4, 4, c["armor_light"])
	# Sword at side (resting)
	_fill_rect(img, 26, 20, 3, 18, c["sword"])
	_fill_rect(img, 25, 36, 5, 3, c["armor_dark"])
	# Shield in front
	_fill_rect(img, 2, 20, 7, 10, c["shield"])
	_fill_rect(img, 2, 20, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 28, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 20, 2, 10, c["shield_rim"])
	textures["blade_knight_dir_down"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_dir_up() -> void:
	# Back-facing — no visor, cape/back detail visible, sword on back
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	_fill_rect(img, 11, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 17, 32, 4, 9, c["armor_dark"])
	# Torso (back of armor — darker tones)
	_fill_rect(img, 9, 18, 14, 15, c["armor_dark"])
	_fill_rect(img, 10, 19, 12, 13, c["armor_mid"])
	# Cape hanging down the back
	_fill_rect(img, 10, 22, 12, 16, Color(0.15, 0.2, 0.5))
	_fill_rect(img, 11, 23, 10, 14, Color(0.2, 0.25, 0.55))
	_fill_rect(img, 9, 30, 14, 3, c["armor_dark"])
	# Shoulders
	_fill_rect(img, 5, 18, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 18, 6, 5, c["armor_mid"])
	# Helm (back — no visor)
	_fill_rect(img, 11, 6, 10, 13, c["helm"])
	_fill_rect(img, 12, 7, 8, 11, c["armor_dark"])
	_fill_rect(img, 14, 4, 4, 4, c["armor_light"])
	# Sword across back
	_fill_rect(img, 13, 8, 3, 26, c["sword"])
	_fill_rect(img, 12, 32, 5, 3, c["armor_dark"])
	# Shield on back (smaller visible portion)
	_fill_rect(img, 18, 14, 6, 8, c["shield"])
	_fill_rect(img, 18, 14, 6, 2, c["shield_rim"])
	textures["blade_knight_dir_up"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_dir_side() -> void:
	# Side/profile — facing right (flip_h handles left)
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Boots (side view — overlapping)
	_fill_rect(img, 11, 40, 5, 6, c["boot"])
	_fill_rect(img, 16, 41, 5, 5, c["boot"])
	# Legs
	_fill_rect(img, 12, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 16, 33, 4, 8, c["armor_dark"])
	# Torso
	_fill_rect(img, 10, 18, 12, 15, c["armor_mid"])
	_fill_rect(img, 11, 19, 10, 13, c["armor_light"])
	_fill_rect(img, 10, 30, 12, 3, c["armor_dark"])
	# One shoulder visible
	_fill_rect(img, 20, 18, 5, 5, c["armor_mid"])
	# Helm (profile)
	_fill_rect(img, 12, 6, 10, 13, c["helm"])
	_fill_rect(img, 13, 7, 8, 11, c["armor_mid"])
	# Visor slot (side)
	_fill_rect(img, 19, 11, 3, 3, c["visor"])
	_fill_rect(img, 14, 4, 4, 4, c["armor_light"])
	# Sword held forward
	_fill_rect(img, 24, 12, 3, 20, c["sword"])
	_fill_rect(img, 25, 10, 2, 4, c["sword_glow"])
	_fill_rect(img, 23, 30, 5, 3, c["armor_dark"])
	# Shield on left arm (behind body)
	_fill_rect(img, 5, 22, 6, 9, c["shield"])
	_fill_rect(img, 5, 22, 6, 2, c["shield_rim"])
	_fill_rect(img, 5, 29, 6, 2, c["shield_rim"])
	textures["blade_knight_dir_side"] = ImageTexture.create_from_image(img)

# ---- Blade Knight walk cycle frames (4 frames per direction) ----
# Frame 0 = idle pose, 1 = left foot forward, 2 = passing (feet together), 3 = right foot forward

func _gen_blade_knight_walk_down_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Left foot forward, right foot back
	_fill_rect(img, 8, 39, 5, 6, c["boot"])   # left foot forward+left
	_fill_rect(img, 19, 41, 5, 6, c["boot"])   # right foot back+right
	_fill_rect(img, 9, 32, 4, 8, c["armor_dark"])   # left leg forward
	_fill_rect(img, 19, 33, 4, 8, c["armor_dark"])   # right leg back
	# Torso (slight bounce down)
	_fill_rect(img, 9, 19, 14, 15, c["armor_mid"])
	_fill_rect(img, 10, 20, 12, 13, c["armor_light"])
	_fill_rect(img, 9, 31, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 19, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 19, 6, 5, c["armor_mid"])
	# Head
	_fill_rect(img, 11, 7, 10, 13, c["helm"])
	_fill_rect(img, 12, 8, 8, 11, c["armor_mid"])
	_fill_rect(img, 13, 12, 6, 3, c["visor"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	# Sword/shield
	_fill_rect(img, 26, 21, 3, 18, c["sword"])
	_fill_rect(img, 25, 37, 5, 3, c["armor_dark"])
	_fill_rect(img, 2, 21, 7, 10, c["shield"])
	_fill_rect(img, 2, 21, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 29, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 21, 2, 10, c["shield_rim"])
	textures["blade_knight_walk_down_1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_down_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Feet together (passing position)
	_fill_rect(img, 12, 40, 5, 6, c["boot"])
	_fill_rect(img, 15, 40, 5, 6, c["boot"])
	_fill_rect(img, 13, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 15, 32, 4, 9, c["armor_dark"])
	# Torso (up position — bounce)
	_fill_rect(img, 9, 17, 14, 15, c["armor_mid"])
	_fill_rect(img, 10, 18, 12, 13, c["armor_light"])
	_fill_rect(img, 9, 29, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 17, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 17, 6, 5, c["armor_mid"])
	# Head
	_fill_rect(img, 11, 5, 10, 13, c["helm"])
	_fill_rect(img, 12, 6, 8, 11, c["armor_mid"])
	_fill_rect(img, 13, 10, 6, 3, c["visor"])
	_fill_rect(img, 14, 3, 4, 4, c["armor_light"])
	# Sword/shield
	_fill_rect(img, 26, 19, 3, 18, c["sword"])
	_fill_rect(img, 25, 35, 5, 3, c["armor_dark"])
	_fill_rect(img, 2, 19, 7, 10, c["shield"])
	_fill_rect(img, 2, 19, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 27, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 19, 2, 10, c["shield_rim"])
	textures["blade_knight_walk_down_2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_down_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Right foot forward, left foot back (mirror of frame 1)
	_fill_rect(img, 19, 39, 5, 6, c["boot"])   # right foot forward
	_fill_rect(img, 8, 41, 5, 6, c["boot"])    # left foot back
	_fill_rect(img, 19, 32, 4, 8, c["armor_dark"])
	_fill_rect(img, 9, 33, 4, 8, c["armor_dark"])
	# Torso (slight bounce down)
	_fill_rect(img, 9, 19, 14, 15, c["armor_mid"])
	_fill_rect(img, 10, 20, 12, 13, c["armor_light"])
	_fill_rect(img, 9, 31, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 19, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 19, 6, 5, c["armor_mid"])
	# Head
	_fill_rect(img, 11, 7, 10, 13, c["helm"])
	_fill_rect(img, 12, 8, 8, 11, c["armor_mid"])
	_fill_rect(img, 13, 12, 6, 3, c["visor"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	# Sword/shield
	_fill_rect(img, 26, 21, 3, 18, c["sword"])
	_fill_rect(img, 25, 37, 5, 3, c["armor_dark"])
	_fill_rect(img, 2, 21, 7, 10, c["shield"])
	_fill_rect(img, 2, 21, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 29, 7, 2, c["shield_rim"])
	_fill_rect(img, 2, 21, 2, 10, c["shield_rim"])
	textures["blade_knight_walk_down_3"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_up_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Left foot forward, right back
	_fill_rect(img, 8, 39, 5, 6, c["boot"])
	_fill_rect(img, 19, 41, 5, 6, c["boot"])
	_fill_rect(img, 9, 32, 4, 8, c["armor_dark"])
	_fill_rect(img, 19, 33, 4, 8, c["armor_dark"])
	# Torso back
	_fill_rect(img, 9, 19, 14, 15, c["armor_dark"])
	_fill_rect(img, 10, 20, 12, 13, c["armor_mid"])
	_fill_rect(img, 10, 23, 12, 16, Color(0.15, 0.2, 0.5))
	_fill_rect(img, 11, 24, 10, 14, Color(0.2, 0.25, 0.55))
	_fill_rect(img, 9, 31, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 19, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 19, 6, 5, c["armor_mid"])
	# Helm back
	_fill_rect(img, 11, 7, 10, 13, c["helm"])
	_fill_rect(img, 12, 8, 8, 11, c["armor_dark"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	# Sword on back
	_fill_rect(img, 13, 9, 3, 26, c["sword"])
	_fill_rect(img, 12, 33, 5, 3, c["armor_dark"])
	_fill_rect(img, 18, 15, 6, 8, c["shield"])
	_fill_rect(img, 18, 15, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_up_1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_up_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Feet together
	_fill_rect(img, 12, 40, 5, 6, c["boot"])
	_fill_rect(img, 15, 40, 5, 6, c["boot"])
	_fill_rect(img, 13, 32, 4, 9, c["armor_dark"])
	_fill_rect(img, 15, 32, 4, 9, c["armor_dark"])
	# Torso back (up bounce)
	_fill_rect(img, 9, 17, 14, 15, c["armor_dark"])
	_fill_rect(img, 10, 18, 12, 13, c["armor_mid"])
	_fill_rect(img, 10, 21, 12, 16, Color(0.15, 0.2, 0.5))
	_fill_rect(img, 11, 22, 10, 14, Color(0.2, 0.25, 0.55))
	_fill_rect(img, 9, 29, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 17, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 17, 6, 5, c["armor_mid"])
	# Helm
	_fill_rect(img, 11, 5, 10, 13, c["helm"])
	_fill_rect(img, 12, 6, 8, 11, c["armor_dark"])
	_fill_rect(img, 14, 3, 4, 4, c["armor_light"])
	_fill_rect(img, 13, 7, 3, 26, c["sword"])
	_fill_rect(img, 12, 31, 5, 3, c["armor_dark"])
	_fill_rect(img, 18, 13, 6, 8, c["shield"])
	_fill_rect(img, 18, 13, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_up_2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_up_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Right foot forward, left back (mirror of frame 1)
	_fill_rect(img, 19, 39, 5, 6, c["boot"])
	_fill_rect(img, 8, 41, 5, 6, c["boot"])
	_fill_rect(img, 19, 32, 4, 8, c["armor_dark"])
	_fill_rect(img, 9, 33, 4, 8, c["armor_dark"])
	# Torso back
	_fill_rect(img, 9, 19, 14, 15, c["armor_dark"])
	_fill_rect(img, 10, 20, 12, 13, c["armor_mid"])
	_fill_rect(img, 10, 23, 12, 16, Color(0.15, 0.2, 0.5))
	_fill_rect(img, 11, 24, 10, 14, Color(0.2, 0.25, 0.55))
	_fill_rect(img, 9, 31, 14, 3, c["armor_dark"])
	_fill_rect(img, 5, 19, 6, 5, c["armor_mid"])
	_fill_rect(img, 21, 19, 6, 5, c["armor_mid"])
	_fill_rect(img, 11, 7, 10, 13, c["helm"])
	_fill_rect(img, 12, 8, 8, 11, c["armor_dark"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	_fill_rect(img, 13, 9, 3, 26, c["sword"])
	_fill_rect(img, 12, 33, 5, 3, c["armor_dark"])
	_fill_rect(img, 18, 15, 6, 8, c["shield"])
	_fill_rect(img, 18, 15, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_up_3"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_side_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Front foot extended forward, back foot behind
	_fill_rect(img, 17, 39, 5, 6, c["boot"])  # front foot forward
	_fill_rect(img, 9, 41, 5, 6, c["boot"])   # back foot behind
	_fill_rect(img, 17, 32, 4, 8, c["armor_dark"])
	_fill_rect(img, 10, 33, 4, 8, c["armor_dark"])
	# Torso
	_fill_rect(img, 10, 19, 12, 15, c["armor_mid"])
	_fill_rect(img, 11, 20, 10, 13, c["armor_light"])
	_fill_rect(img, 10, 31, 12, 3, c["armor_dark"])
	_fill_rect(img, 20, 19, 5, 5, c["armor_mid"])
	# Helm
	_fill_rect(img, 12, 7, 10, 13, c["helm"])
	_fill_rect(img, 13, 8, 8, 11, c["armor_mid"])
	_fill_rect(img, 19, 12, 3, 3, c["visor"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	# Sword
	_fill_rect(img, 24, 13, 3, 20, c["sword"])
	_fill_rect(img, 25, 11, 2, 4, c["sword_glow"])
	_fill_rect(img, 23, 31, 5, 3, c["armor_dark"])
	# Shield
	_fill_rect(img, 5, 23, 6, 9, c["shield"])
	_fill_rect(img, 5, 23, 6, 2, c["shield_rim"])
	_fill_rect(img, 5, 30, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_side_1"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_side_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Feet together (passing)
	_fill_rect(img, 13, 40, 5, 6, c["boot"])
	_fill_rect(img, 14, 40, 5, 6, c["boot"])
	_fill_rect(img, 14, 32, 4, 9, c["armor_dark"])
	# Torso (up bounce)
	_fill_rect(img, 10, 17, 12, 15, c["armor_mid"])
	_fill_rect(img, 11, 18, 10, 13, c["armor_light"])
	_fill_rect(img, 10, 29, 12, 3, c["armor_dark"])
	_fill_rect(img, 20, 17, 5, 5, c["armor_mid"])
	# Helm
	_fill_rect(img, 12, 5, 10, 13, c["helm"])
	_fill_rect(img, 13, 6, 8, 11, c["armor_mid"])
	_fill_rect(img, 19, 10, 3, 3, c["visor"])
	_fill_rect(img, 14, 3, 4, 4, c["armor_light"])
	# Sword
	_fill_rect(img, 24, 11, 3, 20, c["sword"])
	_fill_rect(img, 25, 9, 2, 4, c["sword_glow"])
	_fill_rect(img, 23, 29, 5, 3, c["armor_dark"])
	# Shield
	_fill_rect(img, 5, 21, 6, 9, c["shield"])
	_fill_rect(img, 5, 21, 6, 2, c["shield_rim"])
	_fill_rect(img, 5, 28, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_side_2"] = ImageTexture.create_from_image(img)

func _gen_blade_knight_walk_side_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _bk_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Back foot forward, front foot behind (mirror of frame 1)
	_fill_rect(img, 9, 39, 5, 6, c["boot"])   # back foot now forward
	_fill_rect(img, 17, 41, 5, 6, c["boot"])   # front foot now behind
	_fill_rect(img, 10, 32, 4, 8, c["armor_dark"])
	_fill_rect(img, 17, 33, 4, 8, c["armor_dark"])
	# Torso
	_fill_rect(img, 10, 19, 12, 15, c["armor_mid"])
	_fill_rect(img, 11, 20, 10, 13, c["armor_light"])
	_fill_rect(img, 10, 31, 12, 3, c["armor_dark"])
	_fill_rect(img, 20, 19, 5, 5, c["armor_mid"])
	# Helm
	_fill_rect(img, 12, 7, 10, 13, c["helm"])
	_fill_rect(img, 13, 8, 8, 11, c["armor_mid"])
	_fill_rect(img, 19, 12, 3, 3, c["visor"])
	_fill_rect(img, 14, 5, 4, 4, c["armor_light"])
	# Sword
	_fill_rect(img, 24, 13, 3, 20, c["sword"])
	_fill_rect(img, 25, 11, 2, 4, c["sword_glow"])
	_fill_rect(img, 23, 31, 5, 3, c["armor_dark"])
	# Shield
	_fill_rect(img, 5, 23, 6, 9, c["shield"])
	_fill_rect(img, 5, 23, 6, 2, c["shield_rim"])
	_fill_rect(img, 5, 30, 6, 2, c["shield_rim"])
	textures["blade_knight_walk_side_3"] = ImageTexture.create_from_image(img)

# ---- Shadow Ranger directional sprites ----

func _sr_colors() -> Dictionary:
	return {
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

func _gen_shadow_ranger_dir_down() -> void:
	# Front-facing (same as base — face/eyes visible, bow at side)
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	_fill_rect(img, 11, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 17, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 8, 16, 16, 18, c["cloak_mid"])
	_fill_rect(img, 9, 17, 14, 16, c["cloak_light"])
	_fill_rect(img, 6, 22, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 22, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 30, 16, 2, c["quiver"])
	_fill_rect(img, 10, 6, 12, 11, c["hood"])
	_fill_rect(img, 11, 7, 10, 9, c["cloak_dark"])
	_fill_rect(img, 13, 10, 6, 5, c["skin"])
	_fill_rect(img, 14, 11, 2, 2, c["eyes"])
	_fill_rect(img, 18, 11, 2, 2, c["eyes"])
	# Bow at side
	_fill_rect(img, 2, 10, 2, 28, c["bow_wood"])
	_fill_rect(img, 1, 8, 2, 3, c["bow_wood"])
	_fill_rect(img, 1, 37, 2, 3, c["bow_wood"])
	_fill_rect(img, 4, 10, 1, 28, c["bow_string"])
	# Quiver on back
	_fill_rect(img, 24, 14, 4, 14, c["quiver"])
	_fill_rect(img, 25, 12, 2, 3, c["bow_wood"])
	textures["shadow_ranger_dir_down"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_dir_up() -> void:
	# Back-facing — hood from behind, quiver prominent, no face
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 10, 40, 5, 6, c["boot"])
	_fill_rect(img, 17, 40, 5, 6, c["boot"])
	_fill_rect(img, 11, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 17, 33, 4, 8, c["cloak_dark"])
	# Cloak back (darker)
	_fill_rect(img, 8, 16, 16, 18, c["cloak_dark"])
	_fill_rect(img, 9, 17, 14, 16, c["cloak_mid"])
	# Cape trailing down
	_fill_rect(img, 9, 28, 14, 12, c["cloak_dark"])
	_fill_rect(img, 10, 29, 12, 10, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 6, 22, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 22, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 30, 16, 2, c["quiver"])
	# Hood (back — solid)
	_fill_rect(img, 10, 6, 12, 11, c["hood"])
	_fill_rect(img, 11, 7, 10, 9, c["cloak_dark"])
	# Quiver prominent on back
	_fill_rect(img, 12, 12, 8, 16, c["quiver"])
	_fill_rect(img, 13, 10, 2, 3, c["bow_wood"])
	_fill_rect(img, 17, 10, 2, 3, c["bow_wood"])
	_fill_rect(img, 15, 9, 2, 3, c["bow_wood"])
	# Bow slung over shoulder
	_fill_rect(img, 5, 14, 2, 22, c["bow_wood"])
	_fill_rect(img, 4, 12, 2, 3, c["bow_wood"])
	_fill_rect(img, 7, 14, 1, 22, c["bow_string"])
	textures["shadow_ranger_dir_up"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_dir_side() -> void:
	# Side/profile — facing right (flip_h for left)
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Boots (side)
	_fill_rect(img, 11, 40, 5, 6, c["boot"])
	_fill_rect(img, 16, 41, 5, 5, c["boot"])
	# Legs
	_fill_rect(img, 12, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 16, 34, 4, 7, c["cloak_dark"])
	# Cloak body
	_fill_rect(img, 9, 16, 14, 18, c["cloak_mid"])
	_fill_rect(img, 10, 17, 12, 16, c["cloak_light"])
	# Cape flowing behind
	_fill_rect(img, 4, 22, 6, 16, c["cloak_dark"])
	_fill_rect(img, 5, 23, 4, 14, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 9, 30, 14, 2, c["quiver"])
	# Hood (profile)
	_fill_rect(img, 11, 6, 11, 11, c["hood"])
	_fill_rect(img, 12, 7, 9, 9, c["cloak_dark"])
	# Face peeking out
	_fill_rect(img, 19, 10, 4, 5, c["skin"])
	_fill_rect(img, 20, 11, 2, 2, c["eyes"])
	# Bow held forward
	_fill_rect(img, 24, 12, 2, 24, c["bow_wood"])
	_fill_rect(img, 23, 10, 2, 3, c["bow_wood"])
	_fill_rect(img, 23, 35, 2, 3, c["bow_wood"])
	_fill_rect(img, 26, 12, 1, 24, c["bow_string"])
	# Quiver on back
	_fill_rect(img, 6, 14, 4, 12, c["quiver"])
	_fill_rect(img, 7, 12, 2, 3, c["bow_wood"])
	textures["shadow_ranger_dir_side"] = ImageTexture.create_from_image(img)

# ---- Shadow Ranger walk cycle frames (4 frames per direction) ----

func _gen_shadow_ranger_walk_down_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Left foot forward, right back
	_fill_rect(img, 8, 39, 5, 6, c["boot"])
	_fill_rect(img, 19, 41, 5, 6, c["boot"])
	_fill_rect(img, 9, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 19, 33, 4, 8, c["cloak_dark"])
	# Cloak body (bounce down)
	_fill_rect(img, 8, 17, 16, 18, c["cloak_mid"])
	_fill_rect(img, 9, 18, 14, 16, c["cloak_light"])
	_fill_rect(img, 6, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 31, 16, 2, c["quiver"])
	# Hood
	_fill_rect(img, 10, 7, 12, 11, c["hood"])
	_fill_rect(img, 11, 8, 10, 9, c["cloak_dark"])
	_fill_rect(img, 13, 11, 6, 5, c["skin"])
	_fill_rect(img, 14, 12, 2, 2, c["eyes"])
	_fill_rect(img, 18, 12, 2, 2, c["eyes"])
	# Bow
	_fill_rect(img, 2, 11, 2, 28, c["bow_wood"])
	_fill_rect(img, 1, 9, 2, 3, c["bow_wood"])
	_fill_rect(img, 1, 38, 2, 3, c["bow_wood"])
	_fill_rect(img, 4, 11, 1, 28, c["bow_string"])
	# Quiver
	_fill_rect(img, 24, 15, 4, 14, c["quiver"])
	_fill_rect(img, 25, 13, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_down_1"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_down_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Feet together
	_fill_rect(img, 12, 40, 5, 6, c["boot"])
	_fill_rect(img, 15, 40, 5, 6, c["boot"])
	_fill_rect(img, 13, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 15, 33, 4, 8, c["cloak_dark"])
	# Cloak body (bounce up)
	_fill_rect(img, 8, 15, 16, 18, c["cloak_mid"])
	_fill_rect(img, 9, 16, 14, 16, c["cloak_light"])
	_fill_rect(img, 6, 21, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 21, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 29, 16, 2, c["quiver"])
	# Hood
	_fill_rect(img, 10, 5, 12, 11, c["hood"])
	_fill_rect(img, 11, 6, 10, 9, c["cloak_dark"])
	_fill_rect(img, 13, 9, 6, 5, c["skin"])
	_fill_rect(img, 14, 10, 2, 2, c["eyes"])
	_fill_rect(img, 18, 10, 2, 2, c["eyes"])
	# Bow
	_fill_rect(img, 2, 9, 2, 28, c["bow_wood"])
	_fill_rect(img, 1, 7, 2, 3, c["bow_wood"])
	_fill_rect(img, 1, 36, 2, 3, c["bow_wood"])
	_fill_rect(img, 4, 9, 1, 28, c["bow_string"])
	# Quiver
	_fill_rect(img, 24, 13, 4, 14, c["quiver"])
	_fill_rect(img, 25, 11, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_down_2"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_down_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	# Right foot forward, left back (mirror of frame 1)
	_fill_rect(img, 19, 39, 5, 6, c["boot"])
	_fill_rect(img, 8, 41, 5, 6, c["boot"])
	_fill_rect(img, 19, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 9, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 8, 17, 16, 18, c["cloak_mid"])
	_fill_rect(img, 9, 18, 14, 16, c["cloak_light"])
	_fill_rect(img, 6, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 31, 16, 2, c["quiver"])
	_fill_rect(img, 10, 7, 12, 11, c["hood"])
	_fill_rect(img, 11, 8, 10, 9, c["cloak_dark"])
	_fill_rect(img, 13, 11, 6, 5, c["skin"])
	_fill_rect(img, 14, 12, 2, 2, c["eyes"])
	_fill_rect(img, 18, 12, 2, 2, c["eyes"])
	_fill_rect(img, 2, 11, 2, 28, c["bow_wood"])
	_fill_rect(img, 1, 9, 2, 3, c["bow_wood"])
	_fill_rect(img, 1, 38, 2, 3, c["bow_wood"])
	_fill_rect(img, 4, 11, 1, 28, c["bow_string"])
	_fill_rect(img, 24, 15, 4, 14, c["quiver"])
	_fill_rect(img, 25, 13, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_down_3"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_up_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 8, 39, 5, 6, c["boot"])
	_fill_rect(img, 19, 41, 5, 6, c["boot"])
	_fill_rect(img, 9, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 19, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 8, 17, 16, 18, c["cloak_dark"])
	_fill_rect(img, 9, 18, 14, 16, c["cloak_mid"])
	_fill_rect(img, 9, 29, 14, 12, c["cloak_dark"])
	_fill_rect(img, 10, 30, 12, 10, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 6, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 31, 16, 2, c["quiver"])
	_fill_rect(img, 10, 7, 12, 11, c["hood"])
	_fill_rect(img, 11, 8, 10, 9, c["cloak_dark"])
	_fill_rect(img, 12, 13, 8, 16, c["quiver"])
	_fill_rect(img, 13, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 17, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 15, 10, 2, 3, c["bow_wood"])
	_fill_rect(img, 5, 15, 2, 22, c["bow_wood"])
	_fill_rect(img, 4, 13, 2, 3, c["bow_wood"])
	_fill_rect(img, 7, 15, 1, 22, c["bow_string"])
	textures["shadow_ranger_walk_up_1"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_up_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 12, 40, 5, 6, c["boot"])
	_fill_rect(img, 15, 40, 5, 6, c["boot"])
	_fill_rect(img, 13, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 15, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 8, 15, 16, 18, c["cloak_dark"])
	_fill_rect(img, 9, 16, 14, 16, c["cloak_mid"])
	_fill_rect(img, 9, 27, 14, 12, c["cloak_dark"])
	_fill_rect(img, 10, 28, 12, 10, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 6, 21, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 21, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 29, 16, 2, c["quiver"])
	_fill_rect(img, 10, 5, 12, 11, c["hood"])
	_fill_rect(img, 11, 6, 10, 9, c["cloak_dark"])
	_fill_rect(img, 12, 11, 8, 16, c["quiver"])
	_fill_rect(img, 13, 9, 2, 3, c["bow_wood"])
	_fill_rect(img, 17, 9, 2, 3, c["bow_wood"])
	_fill_rect(img, 15, 8, 2, 3, c["bow_wood"])
	_fill_rect(img, 5, 13, 2, 22, c["bow_wood"])
	_fill_rect(img, 4, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 7, 13, 1, 22, c["bow_string"])
	textures["shadow_ranger_walk_up_2"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_up_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 19, 39, 5, 6, c["boot"])
	_fill_rect(img, 8, 41, 5, 6, c["boot"])
	_fill_rect(img, 19, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 9, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 8, 17, 16, 18, c["cloak_dark"])
	_fill_rect(img, 9, 18, 14, 16, c["cloak_mid"])
	_fill_rect(img, 9, 29, 14, 12, c["cloak_dark"])
	_fill_rect(img, 10, 30, 12, 10, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 6, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 23, 23, 3, 16, c["cloak_dark"])
	_fill_rect(img, 8, 31, 16, 2, c["quiver"])
	_fill_rect(img, 10, 7, 12, 11, c["hood"])
	_fill_rect(img, 11, 8, 10, 9, c["cloak_dark"])
	_fill_rect(img, 12, 13, 8, 16, c["quiver"])
	_fill_rect(img, 13, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 17, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 15, 10, 2, 3, c["bow_wood"])
	_fill_rect(img, 5, 15, 2, 22, c["bow_wood"])
	_fill_rect(img, 4, 13, 2, 3, c["bow_wood"])
	_fill_rect(img, 7, 15, 1, 22, c["bow_string"])
	textures["shadow_ranger_walk_up_3"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_side_1() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 17, 39, 5, 6, c["boot"])
	_fill_rect(img, 9, 41, 5, 6, c["boot"])
	_fill_rect(img, 17, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 10, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 9, 17, 14, 18, c["cloak_mid"])
	_fill_rect(img, 10, 18, 12, 16, c["cloak_light"])
	_fill_rect(img, 4, 23, 6, 16, c["cloak_dark"])
	_fill_rect(img, 5, 24, 4, 14, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 9, 31, 14, 2, c["quiver"])
	_fill_rect(img, 11, 7, 11, 11, c["hood"])
	_fill_rect(img, 12, 8, 9, 9, c["cloak_dark"])
	_fill_rect(img, 19, 11, 4, 5, c["skin"])
	_fill_rect(img, 20, 12, 2, 2, c["eyes"])
	_fill_rect(img, 24, 13, 2, 24, c["bow_wood"])
	_fill_rect(img, 23, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 23, 36, 2, 3, c["bow_wood"])
	_fill_rect(img, 26, 13, 1, 24, c["bow_string"])
	_fill_rect(img, 6, 15, 4, 12, c["quiver"])
	_fill_rect(img, 7, 13, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_side_1"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_side_2() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 13, 40, 5, 6, c["boot"])
	_fill_rect(img, 14, 40, 5, 6, c["boot"])
	_fill_rect(img, 14, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 9, 15, 14, 18, c["cloak_mid"])
	_fill_rect(img, 10, 16, 12, 16, c["cloak_light"])
	_fill_rect(img, 4, 21, 6, 16, c["cloak_dark"])
	_fill_rect(img, 5, 22, 4, 14, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 9, 29, 14, 2, c["quiver"])
	_fill_rect(img, 11, 5, 11, 11, c["hood"])
	_fill_rect(img, 12, 6, 9, 9, c["cloak_dark"])
	_fill_rect(img, 19, 9, 4, 5, c["skin"])
	_fill_rect(img, 20, 10, 2, 2, c["eyes"])
	_fill_rect(img, 24, 11, 2, 24, c["bow_wood"])
	_fill_rect(img, 23, 9, 2, 3, c["bow_wood"])
	_fill_rect(img, 23, 34, 2, 3, c["bow_wood"])
	_fill_rect(img, 26, 11, 1, 24, c["bow_string"])
	_fill_rect(img, 6, 13, 4, 12, c["quiver"])
	_fill_rect(img, 7, 11, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_side_2"] = ImageTexture.create_from_image(img)

func _gen_shadow_ranger_walk_side_3() -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c = _sr_colors()
	_fill_rect(img, 8, 44, 16, 4, c["shadow"])
	_fill_rect(img, 9, 39, 5, 6, c["boot"])
	_fill_rect(img, 17, 41, 5, 6, c["boot"])
	_fill_rect(img, 10, 32, 4, 8, c["cloak_dark"])
	_fill_rect(img, 17, 33, 4, 8, c["cloak_dark"])
	_fill_rect(img, 9, 17, 14, 18, c["cloak_mid"])
	_fill_rect(img, 10, 18, 12, 16, c["cloak_light"])
	_fill_rect(img, 4, 23, 6, 16, c["cloak_dark"])
	_fill_rect(img, 5, 24, 4, 14, Color(0.14, 0.32, 0.17))
	_fill_rect(img, 9, 31, 14, 2, c["quiver"])
	_fill_rect(img, 11, 7, 11, 11, c["hood"])
	_fill_rect(img, 12, 8, 9, 9, c["cloak_dark"])
	_fill_rect(img, 19, 11, 4, 5, c["skin"])
	_fill_rect(img, 20, 12, 2, 2, c["eyes"])
	_fill_rect(img, 24, 13, 2, 24, c["bow_wood"])
	_fill_rect(img, 23, 11, 2, 3, c["bow_wood"])
	_fill_rect(img, 23, 36, 2, 3, c["bow_wood"])
	_fill_rect(img, 26, 13, 1, 24, c["bow_string"])
	_fill_rect(img, 6, 15, 4, 12, c["quiver"])
	_fill_rect(img, 7, 13, 2, 3, c["bow_wood"])
	textures["shadow_ranger_walk_side_3"] = ImageTexture.create_from_image(img)

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

func _gen_armory_building() -> void:
	var img = Image.create(44, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Shadow
	_fill_rect(img, 4, 38, 36, 5, Color(0, 0, 0, 0.2))
	# Base — dark stone forge
	_fill_rect(img, 4, 18, 36, 22, Color(0.35, 0.3, 0.28))
	_fill_rect(img, 5, 19, 34, 20, Color(0.42, 0.38, 0.35))
	# Roof — iron grey
	_fill_rect(img, 2, 12, 40, 8, Color(0.25, 0.25, 0.3))
	_fill_rect(img, 4, 10, 36, 4, Color(0.3, 0.3, 0.35))
	_fill_rect(img, 8, 8, 28, 4, Color(0.35, 0.33, 0.38))
	# Chimney
	_fill_rect(img, 32, 2, 6, 10, Color(0.3, 0.25, 0.25))
	_fill_rect(img, 33, 0, 4, 3, Color(0.25, 0.2, 0.2))
	# Door — wide workshop entrance
	_fill_rect(img, 14, 24, 12, 16, Color(0.25, 0.18, 0.1))
	_fill_rect(img, 15, 25, 10, 14, Color(0.2, 0.14, 0.07))
	# Forge glow through door
	_fill_rect(img, 17, 30, 6, 8, Color(0.8, 0.4, 0.1, 0.3))
	# Windows with orange forge glow
	_fill_rect(img, 6, 21, 6, 5, Color(0.8, 0.5, 0.2))
	_fill_rect(img, 32, 21, 6, 5, Color(0.8, 0.5, 0.2))
	# Window frames
	_fill_rect(img, 6, 23, 6, 1, Color(0.3, 0.25, 0.2))
	_fill_rect(img, 9, 21, 1, 5, Color(0.3, 0.25, 0.2))
	_fill_rect(img, 32, 23, 6, 1, Color(0.3, 0.25, 0.2))
	_fill_rect(img, 35, 21, 1, 5, Color(0.3, 0.25, 0.2))
	# Anvil sign
	_fill_rect(img, 0, 20, 4, 6, Color(0.5, 0.5, 0.55))
	textures["armory_building"] = ImageTexture.create_from_image(img)

func _gen_barracks_building() -> void:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 42, 40, 5, Color(0, 0, 0, 0.2))
	# Base — grey stone military
	_fill_rect(img, 3, 18, 42, 26, Color(0.4, 0.38, 0.35))
	_fill_rect(img, 4, 19, 40, 24, Color(0.48, 0.45, 0.4))
	# Roof — dark slate
	_fill_rect(img, 1, 12, 46, 8, Color(0.28, 0.26, 0.24))
	_fill_rect(img, 4, 8, 40, 6, Color(0.32, 0.3, 0.28))
	_fill_rect(img, 10, 5, 28, 5, Color(0.36, 0.33, 0.3))
	# Crenellations on roof
	for cx in range(2, 44, 6):
		_fill_rect(img, cx, 10, 3, 3, Color(0.36, 0.33, 0.3))
	# Double doors
	_fill_rect(img, 16, 28, 16, 16, Color(0.3, 0.2, 0.12))
	_fill_rect(img, 17, 29, 6, 14, Color(0.25, 0.16, 0.08))
	_fill_rect(img, 25, 29, 6, 14, Color(0.25, 0.16, 0.08))
	# Arrow slits
	_fill_rect(img, 7, 22, 2, 6, Color(0.15, 0.12, 0.1))
	_fill_rect(img, 39, 22, 2, 6, Color(0.15, 0.12, 0.1))
	# Banner pole + red banner
	_fill_rect(img, 23, 0, 2, 8, Color(0.45, 0.35, 0.25))
	_fill_rect(img, 25, 0, 6, 5, Color(0.7, 0.15, 0.1))
	_fill_rect(img, 25, 5, 4, 2, Color(0.6, 0.12, 0.08))
	textures["barracks_building"] = ImageTexture.create_from_image(img)

func _gen_inn_building() -> void:
	var img = Image.create(42, 42, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 36, 34, 5, Color(0, 0, 0, 0.2))
	# Base — warm wood
	_fill_rect(img, 4, 16, 34, 22, Color(0.5, 0.35, 0.2))
	_fill_rect(img, 5, 17, 32, 20, Color(0.58, 0.42, 0.25))
	# Roof — warm brown
	_fill_rect(img, 2, 10, 38, 8, Color(0.4, 0.22, 0.12))
	_fill_rect(img, 5, 7, 32, 5, Color(0.45, 0.25, 0.14))
	_fill_rect(img, 10, 4, 22, 5, Color(0.5, 0.28, 0.15))
	# Chimney with smoke
	_fill_rect(img, 30, 0, 5, 8, Color(0.4, 0.3, 0.25))
	_fill_rect(img, 31, 0, 1, 1, Color(0.6, 0.6, 0.6, 0.3))
	# Door
	_fill_rect(img, 16, 24, 10, 14, Color(0.35, 0.2, 0.1))
	_fill_rect(img, 17, 25, 8, 12, Color(0.3, 0.17, 0.08))
	# Warm lit windows (yellow glow)
	_fill_rect(img, 6, 20, 7, 6, Color(0.9, 0.75, 0.3))
	_fill_rect(img, 29, 20, 7, 6, Color(0.9, 0.75, 0.3))
	_fill_rect(img, 9, 20, 1, 6, Color(0.45, 0.3, 0.15))
	_fill_rect(img, 6, 23, 7, 1, Color(0.45, 0.3, 0.15))
	_fill_rect(img, 32, 20, 1, 6, Color(0.45, 0.3, 0.15))
	_fill_rect(img, 29, 23, 7, 1, Color(0.45, 0.3, 0.15))
	# Hanging sign
	_fill_rect(img, 0, 18, 3, 2, Color(0.4, 0.3, 0.2))
	_fill_rect(img, 0, 20, 5, 6, Color(0.5, 0.4, 0.2))
	textures["inn_building"] = ImageTexture.create_from_image(img)

func _gen_watch_tower() -> void:
	var img = Image.create(24, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 40, 16, 3, Color(0, 0, 0, 0.2))
	# Base — stone
	_fill_rect(img, 6, 12, 12, 30, Color(0.42, 0.4, 0.36))
	_fill_rect(img, 7, 13, 10, 28, Color(0.5, 0.47, 0.42))
	# Top platform (wider than tower)
	_fill_rect(img, 3, 6, 18, 8, Color(0.38, 0.36, 0.32))
	_fill_rect(img, 4, 7, 16, 6, Color(0.45, 0.42, 0.38))
	# Crenellations
	_fill_rect(img, 3, 4, 3, 3, Color(0.42, 0.4, 0.36))
	_fill_rect(img, 9, 4, 3, 3, Color(0.42, 0.4, 0.36))
	_fill_rect(img, 15, 4, 3, 3, Color(0.42, 0.4, 0.36))
	# Window slit
	_fill_rect(img, 10, 20, 2, 5, Color(0.2, 0.15, 0.12))
	# Torch glow at top
	_fill_rect(img, 11, 2, 2, 3, Color(1.0, 0.7, 0.2, 0.8))
	_fill_rect(img, 10, 1, 4, 2, Color(1.0, 0.6, 0.1, 0.4))
	textures["watch_tower"] = ImageTexture.create_from_image(img)

func _gen_town_fountain() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Outer basin — stone ring
	_fill_rect(img, 4, 10, 24, 18, Color(0.45, 0.42, 0.38))
	_fill_rect(img, 6, 12, 20, 14, Color(0.5, 0.47, 0.42))
	# Water — blue pool
	_fill_rect(img, 7, 13, 18, 12, Color(0.2, 0.45, 0.7))
	_fill_rect(img, 8, 14, 16, 10, Color(0.25, 0.5, 0.75))
	# Central pillar
	_fill_rect(img, 13, 6, 6, 16, Color(0.55, 0.52, 0.48))
	_fill_rect(img, 14, 4, 4, 4, Color(0.6, 0.57, 0.52))
	# Water spray highlights
	_fill_rect(img, 11, 8, 2, 2, Color(0.5, 0.7, 0.9, 0.6))
	_fill_rect(img, 19, 8, 2, 2, Color(0.5, 0.7, 0.9, 0.6))
	_fill_rect(img, 15, 3, 2, 2, Color(0.6, 0.8, 1.0, 0.5))
	# Basin rim highlight
	_fill_rect(img, 4, 10, 24, 1, Color(0.55, 0.52, 0.48))
	textures["town_fountain"] = ImageTexture.create_from_image(img)

func _gen_stable_building() -> void:
	var img = Image.create(44, 38, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 3, 32, 38, 5, Color(0, 0, 0, 0.2))
	# Base — wood barn
	_fill_rect(img, 3, 14, 38, 20, Color(0.45, 0.3, 0.15))
	_fill_rect(img, 4, 15, 36, 18, Color(0.52, 0.35, 0.18))
	# Roof — thatch/straw
	_fill_rect(img, 1, 8, 42, 8, Color(0.55, 0.5, 0.25))
	_fill_rect(img, 4, 5, 36, 5, Color(0.6, 0.55, 0.3))
	_fill_rect(img, 10, 3, 24, 4, Color(0.65, 0.58, 0.32))
	# Wide open front
	_fill_rect(img, 10, 20, 24, 14, Color(0.2, 0.14, 0.08))
	# Hay bales inside
	_fill_rect(img, 12, 28, 8, 5, Color(0.65, 0.6, 0.3))
	_fill_rect(img, 24, 26, 8, 7, Color(0.6, 0.55, 0.28))
	# Fence posts
	_fill_rect(img, 0, 18, 2, 14, Color(0.4, 0.28, 0.14))
	_fill_rect(img, 42, 18, 2, 14, Color(0.4, 0.28, 0.14))
	textures["stable_building"] = ImageTexture.create_from_image(img)

func _gen_chapel_building() -> void:
	var img = Image.create(36, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 42, 28, 5, Color(0, 0, 0, 0.2))
	# Base — white stone
	_fill_rect(img, 4, 20, 28, 24, Color(0.6, 0.58, 0.55))
	_fill_rect(img, 5, 21, 26, 22, Color(0.68, 0.65, 0.62))
	# Roof — dark blue/grey
	_fill_rect(img, 2, 14, 32, 8, Color(0.25, 0.28, 0.38))
	_fill_rect(img, 6, 10, 24, 6, Color(0.3, 0.32, 0.42))
	_fill_rect(img, 10, 7, 16, 5, Color(0.32, 0.35, 0.45))
	# Steeple
	_fill_rect(img, 14, 2, 8, 8, Color(0.6, 0.58, 0.55))
	_fill_rect(img, 16, 0, 4, 4, Color(0.65, 0.62, 0.58))
	# Cross on top
	_fill_rect(img, 17, 0, 2, 1, Color(0.8, 0.75, 0.4))
	# Arched door
	_fill_rect(img, 13, 30, 10, 14, Color(0.35, 0.2, 0.12))
	_fill_rect(img, 14, 28, 8, 2, Color(0.55, 0.52, 0.48))
	# Stained glass window (colored)
	_fill_rect(img, 8, 24, 4, 5, Color(0.3, 0.5, 0.8))
	_fill_rect(img, 24, 24, 4, 5, Color(0.7, 0.3, 0.3))
	textures["chapel_building"] = ImageTexture.create_from_image(img)

func _gen_crate_stack() -> void:
	var img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Bottom crate
	_fill_rect(img, 1, 6, 10, 8, Color(0.5, 0.38, 0.2))
	_fill_rect(img, 2, 7, 8, 6, Color(0.58, 0.44, 0.25))
	_fill_rect(img, 5, 6, 2, 8, Color(0.42, 0.32, 0.16))
	# Top crate (smaller, offset)
	_fill_rect(img, 4, 1, 9, 7, Color(0.52, 0.4, 0.22))
	_fill_rect(img, 5, 2, 7, 5, Color(0.6, 0.46, 0.26))
	_fill_rect(img, 8, 1, 1, 7, Color(0.44, 0.34, 0.18))
	textures["crate_stack"] = ImageTexture.create_from_image(img)

func _gen_barrel() -> void:
	var img = Image.create(12, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Barrel body
	_fill_rect(img, 2, 2, 8, 11, Color(0.48, 0.34, 0.18))
	_fill_rect(img, 3, 3, 6, 9, Color(0.55, 0.4, 0.22))
	# Metal bands
	_fill_rect(img, 1, 4, 10, 1, Color(0.4, 0.4, 0.42))
	_fill_rect(img, 1, 9, 10, 1, Color(0.4, 0.4, 0.42))
	# Top
	_fill_rect(img, 3, 1, 6, 2, Color(0.5, 0.36, 0.2))
	textures["barrel"] = ImageTexture.create_from_image(img)

func _gen_well() -> void:
	var img = Image.create(20, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Stone base ring
	_fill_rect(img, 3, 10, 14, 10, Color(0.45, 0.42, 0.38))
	_fill_rect(img, 4, 11, 12, 8, Color(0.5, 0.47, 0.42))
	# Dark center (water)
	_fill_rect(img, 6, 13, 8, 5, Color(0.12, 0.18, 0.28))
	# Support posts
	_fill_rect(img, 4, 4, 2, 10, Color(0.4, 0.28, 0.14))
	_fill_rect(img, 14, 4, 2, 10, Color(0.4, 0.28, 0.14))
	# Crossbar
	_fill_rect(img, 4, 3, 12, 2, Color(0.42, 0.3, 0.16))
	# Rope
	_fill_rect(img, 9, 5, 1, 8, Color(0.55, 0.45, 0.3))
	# Bucket
	_fill_rect(img, 8, 11, 3, 3, Color(0.4, 0.35, 0.25))
	textures["well"] = ImageTexture.create_from_image(img)

func _gen_lamp_post() -> void:
	var img = Image.create(10, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Post
	_fill_rect(img, 4, 6, 2, 17, Color(0.3, 0.3, 0.32))
	# Base
	_fill_rect(img, 3, 21, 4, 2, Color(0.35, 0.33, 0.3))
	# Lamp housing
	_fill_rect(img, 2, 3, 6, 4, Color(0.35, 0.33, 0.3))
	# Glow
	_fill_rect(img, 3, 4, 4, 2, Color(1.0, 0.85, 0.4, 0.8))
	# Top cap
	_fill_rect(img, 3, 2, 4, 2, Color(0.38, 0.36, 0.33))
	textures["lamp_post"] = ImageTexture.create_from_image(img)

func _gen_town_wall_h() -> void:
	var img = Image.create(40, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Wall body
	_fill_rect(img, 0, 4, 40, 10, Color(0.42, 0.4, 0.36))
	_fill_rect(img, 0, 5, 40, 8, Color(0.48, 0.45, 0.4))
	# Crenellations
	for cx in range(0, 40, 8):
		_fill_rect(img, cx, 0, 4, 5, Color(0.45, 0.42, 0.38))
	# Mortar lines
	_fill_rect(img, 0, 8, 40, 1, Color(0.38, 0.36, 0.32))
	textures["town_wall_h"] = ImageTexture.create_from_image(img)

func _gen_town_grass() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	# Maintained grass — brighter green with subtle variation
	img.fill(Color(0.22, 0.45, 0.15))
	for y in range(16):
		for x in range(16):
			var v = (hash(x * 17 + y * 31) % 100) / 1000.0 - 0.05
			img.set_pixel(x, y, Color(0.22 + v, 0.45 + v * 1.5, 0.15 + v * 0.5))
	textures["town_grass"] = ImageTexture.create_from_image(img)

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

func _gen_beacon_cyan() -> void:
	textures["beacon_cyan"] = _make_beacon(Color(0.0, 0.8, 1.0))

func _make_beacon(color: Color) -> ImageTexture:
	# Large ornate beacon pad (96x48) matching SC:BW landing pads from screenshots
	var w = 96
	var h = 48
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = w / 2
	var cy = h / 2
	var rx = 46
	var ry = 22

	# Dark metallic base (bronze/brown)
	_fill_ellipse(img, cx, cy, rx, ry, Color(0.18, 0.14, 0.08))
	_fill_ellipse(img, cx, cy, rx - 2, ry - 1, Color(0.22, 0.18, 0.1))

	# Inner ring groove
	_fill_ellipse(img, cx, cy, rx - 6, ry - 3, Color(0.12, 0.1, 0.06))
	_fill_ellipse(img, cx, cy, rx - 8, ry - 4, Color(0.15, 0.12, 0.07))

	# Glowing energy cross pattern in center
	var glow = Color(color.r, color.g, color.b, 0.6)
	var glow_bright = Color(color.r, color.g, color.b, 0.85)
	# Horizontal energy line
	_fill_rect(img, cx - 20, cy - 1, 40, 3, glow)
	_fill_rect(img, cx - 14, cy, 28, 1, glow_bright)
	# Vertical energy line (compressed for isometric)
	_fill_rect(img, cx - 1, cy - 10, 3, 20, glow)
	_fill_rect(img, cx, cy - 7, 1, 14, glow_bright)
	# Diamond energy pattern
	for i in range(8):
		var px = cx + int(cos(i * TAU / 8.0) * 16)
		var py = cy + int(sin(i * TAU / 8.0) * 8)
		_fill_rect(img, px - 1, py - 1, 3, 3, glow)

	# Center glow spot
	_fill_ellipse(img, cx, cy, 6, 3, glow_bright)
	_fill_ellipse(img, cx, cy, 3, 2, Color(color.r * 0.5 + 0.5, color.g * 0.5 + 0.5, color.b * 0.5 + 0.5, 0.9))

	# Four metallic corner nodes (N/S/E/W)
	var node_color = Color(0.3, 0.25, 0.15)
	var node_glow = Color(color.r, color.g, color.b, 0.7)
	# East
	_fill_ellipse(img, cx + rx - 6, cy, 4, 3, node_color)
	_fill_ellipse(img, cx + rx - 6, cy, 2, 2, node_glow)
	# West
	_fill_ellipse(img, cx - rx + 6, cy, 4, 3, node_color)
	_fill_ellipse(img, cx - rx + 6, cy, 2, 2, node_glow)
	# North
	_fill_ellipse(img, cx, cy - ry + 4, 4, 3, node_color)
	_fill_ellipse(img, cx, cy - ry + 4, 2, 2, node_glow)
	# South
	_fill_ellipse(img, cx, cy + ry - 4, 4, 3, node_color)
	_fill_ellipse(img, cx, cy + ry - 4, 2, 2, node_glow)

	# Outer glow aura
	_fill_ellipse(img, cx, cy, rx + 1, ry + 1, Color(color.r, color.g, color.b, 0.08))

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
	var size = 48
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = size / 2
	var cy = size / 2
	# Isometric ellipse (wider than tall)
	var rx = 22
	var ry = 12
	# Thick ring: outer boundary at d=1.0, inner at d=0.6 (40% thickness)
	for py in range(size):
		for px in range(size):
			var dx = float(px - cx) / float(rx)
			var dy = float(py - cy) / float(ry)
			var d = dx * dx + dy * dy
			if d <= 1.0 and d >= 0.6:
				img.set_pixel(px, py, Color(color.r, color.g, color.b, 1.0))
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
# NEW SPRITE TYPES — from SC:BW screenshots
# ============================================================

func _gen_snow() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.88, 0.92))
	var rng = RandomNumberGenerator.new()
	rng.seed = 201
	for _i in range(10):
		var x = rng.randi_range(0, 15)
		var y = rng.randi_range(0, 15)
		img.set_pixel(x, y, Color(0.9, 0.92, 0.95))
	for _i in range(6):
		var x = rng.randi_range(0, 15)
		var y = rng.randi_range(0, 15)
		img.set_pixel(x, y, Color(0.78, 0.82, 0.88))
	textures["snow"] = ImageTexture.create_from_image(img)

func _gen_ice() -> void:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.72, 0.82))
	var rng = RandomNumberGenerator.new()
	rng.seed = 202
	for _i in range(8):
		var x = rng.randi_range(0, 15)
		var y = rng.randi_range(0, 15)
		img.set_pixel(x, y, Color(0.65, 0.8, 0.9))
	for _i in range(5):
		var x = rng.randi_range(0, 14)
		var y = rng.randi_range(0, 15)
		img.set_pixel(x, y, Color(0.4, 0.6, 0.75))
		img.set_pixel(x + 1, y, Color(0.45, 0.65, 0.78))
	textures["ice"] = ImageTexture.create_from_image(img)

func _gen_ground_snow() -> void:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# White/light gray snow base — matches screenshot 1 & 3
	img.fill(Color(0.82, 0.85, 0.9))
	var rng = RandomNumberGenerator.new()
	rng.seed = 210

	# Large snow drift patches (lighter and darker areas)
	for _i in range(16):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(10, 30)
		var ry = rng.randi_range(8, 22)
		var shade = rng.randf_range(0.0, 1.0)
		var patch_color: Color
		if shade < 0.4:
			# Lighter snow highlight
			patch_color = Color(
				rng.randf_range(0.88, 0.94),
				rng.randf_range(0.9, 0.95),
				rng.randf_range(0.92, 0.97))
		elif shade < 0.7:
			# Shadow/compressed snow
			patch_color = Color(
				rng.randf_range(0.72, 0.8),
				rng.randf_range(0.76, 0.84),
				rng.randf_range(0.82, 0.9))
		else:
			# Slight blue-gray tinge
			patch_color = Color(
				rng.randf_range(0.68, 0.78),
				rng.randf_range(0.72, 0.82),
				rng.randf_range(0.8, 0.88))
		_fill_ellipse(img, cx, cy, rx, ry, patch_color)

	# Medium bumps for texture
	for _i in range(35):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(3, 8)
		var ry = rng.randi_range(2, 6)
		var c = Color(
			rng.randf_range(0.78, 0.92),
			rng.randf_range(0.82, 0.94),
			rng.randf_range(0.86, 0.96))
		_fill_ellipse(img, cx, cy, rx, ry, c)

	# Fine pixel noise for snow grain
	for _i in range(500):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		var existing = img.get_pixel(x, y)
		var v = rng.randf_range(-0.03, 0.03)
		img.set_pixel(x, y, Color(
			clampf(existing.r + v, 0.65, 0.98),
			clampf(existing.g + v, 0.7, 0.98),
			clampf(existing.b + v, 0.75, 1.0)))

	# Sparse tiny dark spots (pebbles poking through)
	for _i in range(15):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		img.set_pixel(x, y, Color(0.5, 0.48, 0.45))

	textures["ground_snow"] = ImageTexture.create_from_image(img)

func _gen_ground_dirt() -> void:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Brown dirt/badlands base — matches screenshot 2
	img.fill(Color(0.42, 0.35, 0.23))
	var rng = RandomNumberGenerator.new()
	rng.seed = 220

	# Large terrain variation patches
	for _i in range(20):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(8, 28)
		var ry = rng.randi_range(6, 22)
		var shade = rng.randf_range(0.0, 1.0)
		var patch_color: Color
		if shade < 0.35:
			# Lighter sandy dirt
			patch_color = Color(
				rng.randf_range(0.5, 0.58),
				rng.randf_range(0.42, 0.5),
				rng.randf_range(0.28, 0.36))
		elif shade < 0.65:
			# Darker mud
			patch_color = Color(
				rng.randf_range(0.3, 0.4),
				rng.randf_range(0.25, 0.33),
				rng.randf_range(0.15, 0.22))
		else:
			# Red-brown clay
			patch_color = Color(
				rng.randf_range(0.45, 0.55),
				rng.randf_range(0.3, 0.38),
				rng.randf_range(0.18, 0.25))
		_fill_ellipse(img, cx, cy, rx, ry, patch_color)

	# Small grass tufts scattered on dirt
	for _i in range(25):
		var cx = rng.randi_range(0, size - 1)
		var cy = rng.randi_range(0, size - 1)
		var rx = rng.randi_range(2, 5)
		var ry = rng.randi_range(1, 4)
		_fill_ellipse(img, cx, cy, rx, ry, Color(
			rng.randf_range(0.22, 0.35),
			rng.randf_range(0.35, 0.48),
			rng.randf_range(0.15, 0.22)))

	# Fine pixel noise for cracks/pebbles
	for _i in range(500):
		var x = rng.randi_range(0, size - 1)
		var y = rng.randi_range(0, size - 1)
		var existing = img.get_pixel(x, y)
		var v = rng.randf_range(-0.04, 0.04)
		img.set_pixel(x, y, Color(
			clampf(existing.r + v, 0.2, 0.65),
			clampf(existing.g + v, 0.15, 0.55),
			clampf(existing.b + v, 0.08, 0.4)))

	textures["ground_dirt"] = ImageTexture.create_from_image(img)

func _gen_tree_dead() -> void:
	# Bare black/dark tree trunks visible in screenshot 3 (snow areas)
	var img = Image.create(24, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Shadow
	_fill_ellipse(img, 12, 45, 10, 3, Color(0, 0, 0, 0.2))
	# Main trunk
	_fill_rect(img, 10, 16, 4, 30, Color(0.15, 0.12, 0.08))
	_fill_rect(img, 11, 18, 2, 26, Color(0.2, 0.16, 0.1))
	# Left branch
	_fill_rect(img, 4, 14, 7, 2, Color(0.15, 0.12, 0.08))
	_fill_rect(img, 2, 10, 3, 5, Color(0.13, 0.1, 0.07))
	_fill_rect(img, 1, 8, 2, 3, Color(0.12, 0.09, 0.06))
	# Right branch
	_fill_rect(img, 13, 20, 6, 2, Color(0.15, 0.12, 0.08))
	_fill_rect(img, 18, 16, 3, 5, Color(0.13, 0.1, 0.07))
	_fill_rect(img, 20, 14, 2, 3, Color(0.12, 0.09, 0.06))
	# Upper branch
	_fill_rect(img, 8, 8, 3, 2, Color(0.14, 0.11, 0.07))
	_fill_rect(img, 6, 4, 2, 5, Color(0.12, 0.09, 0.06))
	# Small broken stubs
	_fill_rect(img, 14, 26, 3, 2, Color(0.16, 0.13, 0.09))
	_fill_rect(img, 7, 22, 3, 2, Color(0.14, 0.11, 0.07))
	textures["tree_dead"] = ImageTexture.create_from_image(img)

func _gen_cliff_face() -> void:
	# Vertical rock cliff face — dark charcoal stone as in screenshots 1 & 3
	var img = Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Main cliff body (dark gray stone)
	_fill_rect(img, 0, 8, 64, 40, Color(0.22, 0.2, 0.18))
	_fill_rect(img, 2, 10, 60, 36, Color(0.28, 0.26, 0.23))
	# Horizontal rock layers
	_fill_rect(img, 0, 16, 64, 2, Color(0.18, 0.16, 0.14))
	_fill_rect(img, 0, 26, 64, 2, Color(0.2, 0.18, 0.15))
	_fill_rect(img, 0, 35, 64, 2, Color(0.17, 0.15, 0.13))
	# Lighter face highlights
	_fill_rect(img, 5, 11, 12, 4, Color(0.35, 0.33, 0.3))
	_fill_rect(img, 30, 19, 10, 5, Color(0.32, 0.3, 0.27))
	_fill_rect(img, 45, 28, 14, 4, Color(0.33, 0.31, 0.28))
	# Dark crevices
	_fill_rect(img, 20, 12, 2, 12, Color(0.1, 0.09, 0.07))
	_fill_rect(img, 42, 18, 2, 10, Color(0.1, 0.09, 0.07))
	# Top edge (snow on cliff top in ice biome)
	_fill_rect(img, 0, 6, 64, 4, Color(0.8, 0.83, 0.88))
	_fill_rect(img, 3, 8, 8, 2, Color(0.85, 0.88, 0.92))
	_fill_rect(img, 25, 8, 12, 2, Color(0.82, 0.85, 0.9))
	_fill_rect(img, 50, 8, 10, 2, Color(0.84, 0.87, 0.91))
	# Shadow at base
	_fill_rect(img, 0, 44, 64, 4, Color(0.08, 0.07, 0.06, 0.5))
	textures["cliff_face"] = ImageTexture.create_from_image(img)

func _gen_icicles() -> void:
	# Hanging icicles from cliff edges — visible in screenshot 3
	var img = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Several icicle points hanging down
	var ice_light = Color(0.75, 0.88, 0.95)
	var ice_mid = Color(0.6, 0.78, 0.9)
	var ice_dark = Color(0.45, 0.65, 0.8)
	# Icicle 1
	_fill_rect(img, 3, 0, 2, 10, ice_mid)
	_fill_rect(img, 4, 0, 1, 8, ice_light)
	img.set_pixel(3, 10, ice_dark)
	# Icicle 2 (taller)
	_fill_rect(img, 9, 0, 3, 14, ice_mid)
	_fill_rect(img, 10, 0, 1, 12, ice_light)
	img.set_pixel(10, 14, ice_dark)
	# Icicle 3
	_fill_rect(img, 16, 0, 2, 8, ice_mid)
	_fill_rect(img, 17, 0, 1, 6, ice_light)
	# Icicle 4 (tallest)
	_fill_rect(img, 21, 0, 3, 15, ice_mid)
	_fill_rect(img, 22, 0, 1, 13, ice_light)
	img.set_pixel(22, 15, ice_dark)
	# Icicle 5
	_fill_rect(img, 27, 0, 2, 11, ice_mid)
	_fill_rect(img, 28, 0, 1, 9, ice_light)
	textures["icicles"] = ImageTexture.create_from_image(img)

func _gen_landing_pad() -> void:
	# SC:BW-style landing pad structure — visible in screenshot 1
	var img = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Base platform (dark metallic)
	_fill_ellipse(img, 32, 16, 30, 14, Color(0.25, 0.23, 0.2))
	_fill_ellipse(img, 32, 16, 28, 13, Color(0.3, 0.28, 0.25))
	# Inner platform (lighter)
	_fill_ellipse(img, 32, 16, 22, 10, Color(0.35, 0.33, 0.3))
	# Landing markings (cross pattern)
	_fill_rect(img, 14, 15, 36, 2, Color(0.6, 0.55, 0.2))
	_fill_rect(img, 31, 6, 2, 20, Color(0.6, 0.55, 0.2))
	# Corner lights
	_fill_rect(img, 8, 14, 3, 3, Color(0.2, 0.8, 0.2))
	_fill_rect(img, 53, 14, 3, 3, Color(0.2, 0.8, 0.2))
	_fill_rect(img, 30, 4, 3, 3, Color(0.8, 0.2, 0.2))
	_fill_rect(img, 30, 25, 3, 3, Color(0.8, 0.2, 0.2))
	# Shadow underneath
	_fill_ellipse(img, 32, 28, 28, 4, Color(0, 0, 0, 0.2))
	textures["landing_pad"] = ImageTexture.create_from_image(img)

func _gen_blood_splatter() -> void:
	# Red blood on ground where enemies die — visible in screenshot 3
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blood = Color(0.55, 0.05, 0.02)
	var blood_dark = Color(0.35, 0.02, 0.01)
	var blood_light = Color(0.7, 0.1, 0.05)
	# Main splatter (organic blob shape)
	_fill_ellipse(img, 8, 8, 6, 5, blood)
	_fill_ellipse(img, 6, 7, 4, 3, blood_dark)
	_fill_ellipse(img, 10, 9, 4, 3, blood_light)
	# Splatter droplets
	_fill_rect(img, 2, 4, 2, 2, blood)
	_fill_rect(img, 12, 3, 2, 2, blood_dark)
	_fill_rect(img, 13, 11, 2, 2, blood)
	_fill_rect(img, 3, 11, 2, 2, blood_dark)
	img.set_pixel(1, 8, blood)
	img.set_pixel(14, 7, blood)
	textures["blood_splatter"] = ImageTexture.create_from_image(img)

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
