extends Node2D

@onready var heal_beacon: Area2D = $HealBeacon
@onready var info_beacon: Area2D = $InfoBeacon

# ============================================================
# PROGRESSIVE DIFFICULTY SYSTEM
# ============================================================
# Waves of increasingly powerful enemies spawn outward from town.
# Mini-bosses appear at intervals with their own music cues.

const CreepCampScene = preload("res://scenes/enemies/creep_camp.tscn")

# Wave definitions: each wave spawns camps of a certain type at a minimum distance
# [camp_type, min_distance, max_distance, camp_count, enemy_per_camp]
const WAVE_SCHEDULE = [
	# Wave 1 (3 min): Tougher wolves + skeleton reinforcements mid-range
	{"time": 180.0, "type": "wolf", "min_dist": 1500.0, "max_dist": 2500.0, "camps": 3, "per_camp": 6, "msg": "Wolves are gathering in the wilds...", "color": Color(0.6, 0.6, 0.9)},
	# Wave 2 (5 min): Bandits push in, trolls appear mid
	{"time": 300.0, "type": "troll", "min_dist": 2000.0, "max_dist": 3500.0, "camps": 3, "per_camp": 4, "msg": "Trolls emerge from the deep forest!", "color": Color(0.4, 0.8, 0.4)},
	# Wave 3 (7 min): Dark mages + first mini-boss
	{"time": 420.0, "type": "dark_mage", "min_dist": 2500.0, "max_dist": 4000.0, "camps": 4, "per_camp": 4, "msg": "Dark magic crackles in the air...", "color": Color(0.7, 0.3, 0.9)},
	# Wave 4 (10 min): Demon Knights arrive
	{"time": 600.0, "type": "demon_knight", "min_dist": 3000.0, "max_dist": 4500.0, "camps": 3, "per_camp": 4, "msg": "Demon Knights march from the shadows!", "color": Color(1.0, 0.3, 0.3)},
	# Wave 5 (13 min): Ancient Golems
	{"time": 780.0, "type": "ancient_golem", "min_dist": 3500.0, "max_dist": 5000.0, "camps": 3, "per_camp": 3, "msg": "The earth trembles... Ancient Golems awaken!", "color": Color(0.7, 0.5, 0.2)},
	# Wave 6 (17 min): Shadow Wraiths
	{"time": 1020.0, "type": "shadow_wraith", "min_dist": 3000.0, "max_dist": 5000.0, "camps": 4, "per_camp": 3, "msg": "Shadow Wraiths phase into existence!", "color": Color(0.5, 0.2, 0.8)},
	# Wave 7 (22 min): Dragon Whelps
	{"time": 1320.0, "type": "dragon_whelp", "min_dist": 3500.0, "max_dist": 5500.0, "camps": 3, "per_camp": 3, "msg": "Dragon Whelps descend from the peaks!", "color": Color(1.0, 0.5, 0.1)},
	# Wave 8 (28 min): Infernals — endgame
	{"time": 1680.0, "type": "infernal", "min_dist": 4000.0, "max_dist": 5500.0, "camps": 3, "per_camp": 2, "msg": "INFERNALS TEAR THROUGH THE VEIL!", "color": Color(1.0, 0.1, 0.1)},
]

# Mini-boss spawn schedule: [time, boss_type, distance_from_town]
const BOSS_SCHEDULE = [
	{"time": 450.0, "type": "mini_boss_ravager", "dist": 2800.0, "count": 1, "msg": "A RAVAGER stalks the outer wilds!"},
	{"time": 720.0, "type": "mini_boss_dread_knight", "dist": 3500.0, "count": 1, "msg": "A DREAD KNIGHT has appeared!"},
	{"time": 1200.0, "type": "mini_boss_elder_drake", "dist": 4200.0, "count": 1, "msg": "An ELDER DRAKE circles above!"},
	{"time": 1800.0, "type": "mini_boss_abyssal_lord", "dist": 5000.0, "count": 1, "msg": "THE ABYSSAL LORD HAS ARRIVED!"},
]

var _elapsed_time: float = 0.0
var _next_wave_index: int = 0
var _next_boss_index: int = 0
var _wave_rng := RandomNumberGenerator.new()
var _spawned_camps: Array[Node2D] = []  # Track dynamically spawned camps

# Creep camp positions for ground darkening (matches .tscn camp positions)
var _camp_positions := [
	# Goblins (close to town)
	Vector2(-1200, -900), Vector2(1100, -1100), Vector2(-700, -1600), Vector2(600, 800),
	# Wolves (mid range)
	Vector2(-2200, 1200), Vector2(900, 1800), Vector2(2400, -700), Vector2(-1800, -1800),
	# Bandits (far out)
	Vector2(3000, 1600), Vector2(-3500, -700), Vector2(3800, -1500),
	Vector2(-2800, 2400), Vector2(-4200, -2500), Vector2(4400, 3000),
	# Skeletons (inner-mid)
	Vector2(-900, -1200), Vector2(1400, -600), Vector2(-600, 1400),
	Vector2(800, -1800), Vector2(-1500, 900), Vector2(2000, 600),
	# Spiders (mid)
	Vector2(-1900, -1400), Vector2(2200, -1200), Vector2(-2400, 800),
	Vector2(1600, 1400), Vector2(-800, -2400), Vector2(200, 2600),
	# Trolls (outer)
	Vector2(-3200, 1400), Vector2(3400, -2200), Vector2(-2600, -2000), Vector2(2800, 2200),
	# Dark Mages (outer)
	Vector2(-3800, -1600), Vector2(4000, 1200), Vector2(-4400, 2800), Vector2(3600, -3000),
	# Ogres (far)
	Vector2(-5000, -2800), Vector2(5000, 2800), Vector2(-4800, 3200),
	# Ogre Bosses (edge)
	Vector2(5200, -3500), Vector2(-5400, -3800),
]

const HarvestableTree = preload("res://scenes/world/harvestable_tree.gd")

func _ready() -> void:
	GameManager.game_message.emit("Welcome to Haven's Rest", Color(1, 1, 1))
	GameManager.game_message.emit("Level 1-5 Zone", Color(0.7, 0.7, 0.7))
	var tracks: Array[String] = ["war_drums", "crystal_caves", "pirate_jig", "dark_cathedral", "desert_caravan"]
	AudioManager.start_rotation(tracks, 60.0, 300.0)

	heal_beacon.activated.connect(_on_heal_beacon)
	info_beacon.activated.connect(_on_info_beacon)

	_wave_rng.seed = 42

	_generate_terrain()
	_generate_town()
	_generate_decorations_async()
	_generate_harvestable_trees_async()

func _process(delta: float) -> void:
	_elapsed_time += delta

	# Check for wave spawns
	if _next_wave_index < WAVE_SCHEDULE.size():
		var wave = WAVE_SCHEDULE[_next_wave_index]
		if _elapsed_time >= wave["time"]:
			_spawn_wave(wave)
			_next_wave_index += 1

	# Check for mini-boss spawns
	if _next_boss_index < BOSS_SCHEDULE.size():
		var boss = BOSS_SCHEDULE[_next_boss_index]
		if _elapsed_time >= boss["time"]:
			_spawn_mini_boss(boss)
			_next_boss_index += 1

	# All waves and bosses done — stop processing
	if _next_wave_index >= WAVE_SCHEDULE.size() and _next_boss_index >= BOSS_SCHEDULE.size():
		set_process(false)

# ============================================================
# WAVE SPAWNING
# ============================================================

func _spawn_wave(wave: Dictionary) -> void:
	# Play warning stinger
	AudioManager.play_music_direct("wave_warning")
	# Announce
	GameManager.game_message.emit(wave["msg"], wave["color"])

	var camp_type: String = wave["type"]
	var min_dist: float = wave["min_dist"]
	var max_dist: float = wave["max_dist"]
	var camp_count: int = wave["camps"]
	var per_camp: int = wave["per_camp"]

	for i in range(camp_count):
		var pos = _random_position_in_ring(min_dist, max_dist)
		var camp = CreepCampScene.instantiate()
		camp.camp_type = camp_type
		camp.enemy_count = per_camp
		camp.respawn_time = 60.0 + _wave_rng.randf_range(-10.0, 10.0)
		camp.position = pos
		add_child(camp)
		_spawned_camps.append(camp)

		# Add creep ground darkening at new camp
		_add_creep_ground(pos, _wave_rng.randf_range(140, 200))

		# Add a marker for the new camp
		var type_data = camp.CAMP_TYPES.get(camp_type, {})
		var type_name = type_data.get("name", camp_type)
		var lvl = type_data.get("level_range", [1, 1])
		var marker_text = "%s Lv%d-%d" % [type_name, lvl[0], lvl[1]]
		_add_camp_marker($Decorations, pos + Vector2(0, -40), marker_text)

func _spawn_mini_boss(boss_info: Dictionary) -> void:
	# Play wave warning stinger for boss announcement
	AudioManager.play_music_direct("wave_warning")

	# Big announcement
	GameManager.game_message.emit("", Color(1, 1, 1))  # Blank line for emphasis
	GameManager.game_message.emit("!! MINI-BOSS INCOMING !!", Color(1.0, 0.2, 0.2))
	GameManager.game_message.emit(boss_info["msg"], Color(1.0, 0.6, 0.2))

	var pos = _random_position_in_ring(boss_info["dist"] - 300.0, boss_info["dist"] + 300.0)
	var camp = CreepCampScene.instantiate()
	camp.camp_type = boss_info["type"]
	camp.enemy_count = boss_info["count"]
	camp.respawn_time = 180.0  # Bosses respawn slowly
	camp.position = pos
	add_child(camp)
	_spawned_camps.append(camp)

	# Connect boss death for announcements
	camp.mini_boss_died.connect(_on_mini_boss_died)

	# Add visuals
	_add_creep_ground(pos, 220)
	var type_data = camp.CAMP_TYPES.get(boss_info["type"], {})
	var boss_name = type_data.get("name", boss_info["type"])
	_add_camp_marker($Decorations, pos + Vector2(0, -50), "BOSS: %s" % boss_name)

func _on_mini_boss_died(boss_name: String, pos: Vector2) -> void:
	GameManager.game_message.emit("", Color(1, 1, 1))
	GameManager.game_message.emit("The %s has been slain!" % boss_name, Color(1.0, 0.85, 0.2))
	GameManager.game_message.emit("The wilds grow quiet... for now.", Color(0.7, 0.7, 0.7))

func _random_position_in_ring(min_dist: float, max_dist: float) -> Vector2:
	# Generate a random position in a ring around the origin, avoiding overlaps
	for _attempt in range(20):
		var angle = _wave_rng.randf_range(0, TAU)
		var dist = _wave_rng.randf_range(min_dist, max_dist)
		var pos = Vector2(cos(angle) * dist, sin(angle) * dist)
		# Clamp to map bounds
		pos.x = clampf(pos.x, -5500.0, 5500.0)
		pos.y = clampf(pos.y, -4200.0, 4200.0)
		# Avoid town center
		if pos.length() < 800.0:
			continue
		# Avoid too-close overlap with existing spawned camps
		var too_close = false
		for existing in _spawned_camps:
			if is_instance_valid(existing) and pos.distance_to(existing.position) < 400.0:
				too_close = true
				break
		if not too_close:
			return pos
	# Fallback: just return a valid position
	return Vector2(_wave_rng.randf_range(-5000, 5000), _wave_rng.randf_range(-3800, 3800))

func _on_heal_beacon(_b: Area2D) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var stats = players[0].stats
		stats.current_hp = stats.get_total_max_hp()
		stats.current_mana = stats.get_total_max_mana()
		stats._emit_all()
		GameManager.game_message.emit("HP and Mana fully restored!", Color(0.2, 1.0, 0.2))

func _on_info_beacon(_b: Area2D) -> void:
	GameManager.game_message.emit("Haven's Rest - A safe haven for adventurers.", Color(0.5, 0.7, 1.0))
	GameManager.game_message.emit("Explore outward to find creep camps. Kill monsters to level up!", Color(0.5, 0.7, 1.0))

# ============================================================
# TERRAIN: Tiled ground textures for SC:BW look
# ============================================================

func _generate_terrain() -> void:
	# Main jungle ground — single Sprite2D with texture repeat covering the expanded map
	var ground_sprite = Sprite2D.new()
	ground_sprite.texture = SpriteGenerator.get_texture("ground_jungle")
	ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_sprite.region_enabled = true
	ground_sprite.region_rect = Rect2(-6000, -4500, 12000, 9000)
	ground_sprite.z_index = -10
	ground_sprite.position = Vector2(-6000, -4500)
	ground_sprite.centered = false
	add_child(ground_sprite)
	move_child(ground_sprite, 0)

	# Town stone floor overlay — large base for the structured town
	var town_stone = Sprite2D.new()
	town_stone.texture = SpriteGenerator.get_texture("ground_stone")
	town_stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	town_stone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	town_stone.region_enabled = true
	town_stone.region_rect = Rect2(0, 0, 1000, 800)
	town_stone.position = Vector2(-500, -400)
	town_stone.centered = false
	town_stone.z_index = -9
	add_child(town_stone)

	# Green grass quadrants overlaid on stone (the uncovered stone forms paths)
	# NW quadrant
	_add_grass_quad(Vector2(-460, -360), Vector2(380, 280))
	# NE quadrant
	_add_grass_quad(Vector2(80, -360), Vector2(380, 280))
	# SW quadrant
	_add_grass_quad(Vector2(-460, 80), Vector2(380, 280))
	# SE quadrant
	_add_grass_quad(Vector2(80, 80), Vector2(380, 280))

	# Dark creep ground patches near each camp
	for camp_pos in _camp_positions:
		_add_creep_ground(camp_pos, randf_range(140, 200))

	# --- Large terrain variation overlays: tinted blobs that break up repetition ---
	var blob_rng = RandomNumberGenerator.new()
	blob_rng.seed = 777
	# Variety of earth/green tints that blend naturally with jungle ground
	var blob_tints = [
		Color(0.15, 0.25, 0.1, 1.0),  # Darker green (dense canopy)
		Color(0.12, 0.22, 0.08, 1.0), # Deep moss
		Color(0.2, 0.3, 0.12, 1.0),   # Lighter clearing
		Color(0.18, 0.15, 0.08, 1.0), # Brown-earth
		Color(0.1, 0.2, 0.15, 1.0),   # Blue-green (damp area)
		Color(0.22, 0.2, 0.1, 1.0),   # Dry patch
		Color(0.08, 0.18, 0.06, 1.0), # Very dark (shadow)
		Color(0.16, 0.28, 0.1, 1.0),  # Bright grass
	]
	for _i in range(45):
		var pos = Vector2(blob_rng.randf_range(-5800, 5800), blob_rng.randf_range(-4300, 4300))
		if pos.length() < 500:
			continue  # Skip town area
		var blob = Sprite2D.new()
		blob.texture = SpriteGenerator.get_texture("terrain_blob")
		blob.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		blob.position = pos
		var s = blob_rng.randf_range(3.0, 8.0)
		blob.scale = Vector2(s, s * blob_rng.randf_range(0.6, 1.4))
		blob.rotation = blob_rng.randf_range(0, TAU)
		blob.modulate = blob_tints[blob_rng.randi() % blob_tints.size()]
		blob.z_index = -9
		add_child(blob)

	# Scattered dirt patches across the expanded map
	var rng = RandomNumberGenerator.new()
	rng.seed = 555
	for _i in range(50):
		var pos = Vector2(rng.randf_range(-5700, 5700), rng.randf_range(-4200, 4200))
		if pos.length() > 550:  # Avoid town area
			_add_dirt_ground_patch(pos)

func _add_creep_ground(center: Vector2, radius: float) -> void:
	# Multiple overlapping dark ground sprites to form organic creep shape
	for i in range(5):
		var offset = Vector2(randf_range(-radius * 0.3, radius * 0.3), randf_range(-radius * 0.3, radius * 0.3))
		var creep = Sprite2D.new()
		creep.texture = SpriteGenerator.get_texture("ground_creep")
		creep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		creep.position = center + offset
		var s = radius / 64.0 * randf_range(0.8, 1.2)
		creep.scale = Vector2(s, s * randf_range(0.7, 1.0))
		creep.modulate.a = randf_range(0.6, 0.85)
		creep.z_index = -9
		add_child(creep)

func _add_dirt_ground_patch(pos: Vector2) -> void:
	var patch = Sprite2D.new()
	patch.texture = SpriteGenerator.get_texture("dirt_patch")
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.position = pos
	var s = randf_range(1.5, 4.0)
	patch.scale = Vector2(s, s * randf_range(0.6, 1.0))
	patch.modulate.a = randf_range(0.4, 0.7)
	patch.z_index = -9
	add_child(patch)

func _add_grass_quad(pos: Vector2, size: Vector2) -> void:
	var grass = Sprite2D.new()
	grass.texture = SpriteGenerator.get_texture("town_grass")
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.region_enabled = true
	grass.region_rect = Rect2(0, 0, size.x, size.y)
	grass.position = pos
	grass.centered = false
	grass.z_index = -8
	add_child(grass)

# ============================================================
# TOWN: Structured buildings, walls, and decorations
# ============================================================

func _generate_town() -> void:
	var town = $Decorations  # Reuse deco layer for z-sorting

	# ---- Town walls / ramparts around perimeter ----
	# North wall
	for wx in range(-460, 461, 42):
		_add_town_building(town, Vector2(wx, -380), "town_wall_h")
	# South wall
	for wx in range(-460, 461, 42):
		_add_town_building(town, Vector2(wx, 370), "town_wall_h")
	# West wall segments (skip gate area around y=0)
	for wy in range(-360, 361, 42):
		if abs(wy) > 60:
			_add_town_building(town, Vector2(-480, wy), "town_wall_h")
	# East wall segments
	for wy in range(-360, 361, 42):
		if abs(wy) > 60:
			_add_town_building(town, Vector2(460, wy), "town_wall_h")

	# ---- Watch towers at 4 corners ----
	_add_town_building(town, Vector2(-460, -370), "watch_tower")
	_add_town_building(town, Vector2(450, -370), "watch_tower")
	_add_town_building(town, Vector2(-460, 340), "watch_tower")
	_add_town_building(town, Vector2(450, 340), "watch_tower")

	# ---- Central fountain / monument ----
	_add_town_building(town, Vector2(0, 10), "town_fountain")

	# ---- Non-interactive buildings (visual only) ----
	# NW quadrant: Inn
	_add_town_building(town, Vector2(-260, -220), "inn_building")
	_add_building_label(town, Vector2(-260, -190), "Inn")
	# NE quadrant: (Shop is interactive, placed via .tscn)
	# SE quadrant: Barracks
	_add_town_building(town, Vector2(260, 160), "barracks_building")
	_add_building_label(town, Vector2(260, 190), "Barracks")
	# Additional buildings in quadrants
	_add_town_building(town, Vector2(-300, 180), "stable_building")
	_add_building_label(town, Vector2(-300, 200), "Stables")
	_add_town_building(town, Vector2(280, -220), "chapel_building")
	_add_building_label(town, Vector2(280, -190), "Chapel")

	# ---- Wall torches along the fortress walls ----
	for wx in range(-420, 421, 84):
		_add_wall_torch(town, Vector2(wx, -375))   # North wall
		_add_wall_torch(town, Vector2(wx, 365))    # South wall
	for wy in range(-320, 321, 84):
		if abs(wy) > 70:  # Skip gate openings
			_add_wall_torch(town, Vector2(-475, wy))  # West wall
			_add_wall_torch(town, Vector2(455, wy))    # East wall

	# ---- Lamp posts along the main roads ----
	for lx in [-160, -80, 80, 160]:
		_add_town_building(town, Vector2(lx, -5), "lamp_post")
	for ly in [-160, -80, 80, 160]:
		_add_town_building(town, Vector2(-5, ly), "lamp_post")

	# ---- Crates, barrels, and wells scattered in town ----
	# Near shop area
	_add_town_building(town, Vector2(220, -100), "crate_stack")
	_add_town_building(town, Vector2(230, -85), "barrel")
	_add_town_building(town, Vector2(210, -85), "barrel")
	# Near armory
	_add_town_building(town, Vector2(-220, -100), "crate_stack")
	_add_town_building(town, Vector2(-230, -85), "crate_stack")
	_add_town_building(town, Vector2(-210, -85), "barrel")
	# Near barracks
	_add_town_building(town, Vector2(310, 130), "crate_stack")
	_add_town_building(town, Vector2(320, 145), "barrel")
	_add_town_building(town, Vector2(200, 140), "barrel")
	# Near inn
	_add_town_building(town, Vector2(-310, -200), "barrel")
	_add_town_building(town, Vector2(-320, -190), "barrel")
	# Near stables
	_add_town_building(town, Vector2(-350, 160), "crate_stack")
	_add_town_building(town, Vector2(-240, 160), "barrel")
	# Well in town
	_add_town_building(town, Vector2(120, 100), "well")
	_add_town_building(town, Vector2(-120, -100), "well")

	# ---- Extra grass tufts within town grass quadrants ----
	var rng = RandomNumberGenerator.new()
	rng.seed = 777
	for _i in range(40):
		var qx = rng.randf_range(-420, 420)
		var qy = rng.randf_range(-320, 320)
		# Only place on grass areas (not on paths)
		if abs(qx) > 50 and abs(qy) > 50:
			_add_grass_tuft($Decorations, Vector2(qx, qy))

func _add_town_building(parent: Node2D, pos: Vector2, tex_name: String) -> void:
	var spr = Sprite2D.new()
	spr.position = pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = SpriteGenerator.get_texture(tex_name)
	spr.z_index = 0
	parent.add_child(spr)

func _add_building_label(parent: Node2D, pos: Vector2, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.position = pos + Vector2(-25, 0)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(50, 0)
	parent.add_child(label)

func _add_wall_torch(parent: Node2D, pos: Vector2) -> void:
	var spr = Sprite2D.new()
	spr.position = pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = SpriteGenerator.get_texture("wall_torch")
	spr.z_index = 1
	parent.add_child(spr)
	# Flickering animation — randomized durations so torches don't sync
	var tween = spr.create_tween().set_loops()
	var d1 = randf_range(0.12, 0.22)
	var d2 = randf_range(0.1, 0.2)
	var d3 = randf_range(0.08, 0.18)
	tween.tween_property(spr, "modulate", Color(1.1, 0.9, 0.55), d1)
	tween.parallel().tween_property(spr, "scale", Vector2(1.0, randf_range(0.9, 1.05)), d1)
	tween.tween_property(spr, "modulate", Color(1.0, 0.75, 0.4), d2)
	tween.parallel().tween_property(spr, "scale", Vector2(0.95, randf_range(0.85, 1.0)), d2)
	tween.tween_property(spr, "modulate", Color(1.2, 0.85, 0.45), d3)
	tween.parallel().tween_property(spr, "scale", Vector2(1.05, randf_range(0.95, 1.1)), d3)

# ============================================================
# DECORATIONS: Dense SC:BW jungle foliage
# ============================================================

func _generate_decorations_async() -> void:
	var deco_layer = $Decorations
	var _nodes_this_frame: int = 0
	const BATCH_SIZE: int = 80  # Yield after this many nodes to keep frames smooth

	# ---- Border trees: double-row along all 4 walls (wider spacing for perf) ----
	for x in range(-5950, 5951, 90):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -4420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -4350 + randf_range(-20, 20)))
		_nodes_this_frame += 2
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame
	for x in range(-5950, 5951, 90):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 4420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 4350 + randf_range(-20, 20)))
		_nodes_this_frame += 2
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame
	for y in range(-4400, 4401, 90):
		_add_tree(deco_layer, Vector2(-5920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(-5850 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_nodes_this_frame += 2
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame
	for y in range(-4400, 4401, 90):
		_add_tree(deco_layer, Vector2(5920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(5850 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_nodes_this_frame += 2
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame

	# ---- Interior tree clusters (expanded across larger map) ----
	var cluster_centers = [
		# Inner ring (just outside town walls)
		Vector2(-600, -700), Vector2(400, -600), Vector2(-700, 500),
		Vector2(600, 500), Vector2(-400, 700), Vector2(700, -500),
		# Mid ring
		Vector2(-1000, -900), Vector2(1000, -800), Vector2(-1200, 500),
		Vector2(1100, 600), Vector2(-800, -600), Vector2(800, 600),
		Vector2(0, -1200), Vector2(0, 1200), Vector2(-600, 900),
		Vector2(700, -700), Vector2(-700, -500), Vector2(500, 800),
		# Outer ring
		Vector2(-2000, -600), Vector2(2000, -400), Vector2(-1800, 1000),
		Vector2(1900, 800), Vector2(-2500, -1200), Vector2(2500, -1100),
		Vector2(-2300, 1600), Vector2(2200, 1500), Vector2(-1500, -1500),
		Vector2(1600, -1400), Vector2(-2800, 0), Vector2(2800, -200),
		Vector2(0, -2000), Vector2(0, 2000), Vector2(-1000, 1600),
		Vector2(1200, 1800), Vector2(-2600, 800), Vector2(2600, 600),
		Vector2(-1600, -800), Vector2(1500, -700), Vector2(-900, 1300),
		Vector2(1300, -1600), Vector2(-2000, 1800), Vector2(2100, -1700),
		Vector2(-3000, -500), Vector2(3000, 400), Vector2(-700, -1800),
		Vector2(800, 1600), Vector2(-2400, -1600), Vector2(2300, 1200),
		# Far ring (new territory in expanded map)
		Vector2(-3800, -1400), Vector2(3600, -1200), Vector2(-4200, 800),
		Vector2(4000, 600), Vector2(-3500, 2000), Vector2(3800, 1800),
		Vector2(-4500, -600), Vector2(4300, -400), Vector2(-3200, -2200),
		Vector2(3400, -2000), Vector2(-2800, 2800), Vector2(3000, 2600),
		Vector2(0, -3200), Vector2(0, 3200), Vector2(-1500, 2800),
		Vector2(1800, 3000), Vector2(-4000, 1400), Vector2(4200, 1200),
		Vector2(-3600, -2600), Vector2(3800, -2400), Vector2(-5000, -1000),
		Vector2(5000, -800), Vector2(-4800, 2000), Vector2(4600, 2200),
		Vector2(-1800, -3200), Vector2(2000, -3000), Vector2(-3200, 3200),
		Vector2(3400, 3400), Vector2(-5200, 400), Vector2(5400, -600),
		Vector2(-4400, -2000), Vector2(4200, -1800), Vector2(-2400, 3600),
		Vector2(2600, 3800), Vector2(-5000, 1600), Vector2(5200, 1400),
	]
	for center in cluster_centers:
		var count = randi_range(4, 9)
		for i in range(count):
			var offset = Vector2(randf_range(-70, 70), randf_range(-70, 70))
			_add_tree(deco_layer, center + offset)
			_nodes_this_frame += 1
		for i in range(randi_range(2, 5)):
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			_add_bush(deco_layer, center + offset)
			_nodes_this_frame += 1
		if randf() > 0.5:
			_add_vines(deco_layer, center + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
		if randf() > 0.6:
			_add_mushrooms(deco_layer, center + Vector2(randf_range(-40, 40), randf_range(-30, 30)))
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame

	# ---- Rock formations ----
	var rock_positions = [
		Vector2(-600, -400), Vector2(-610, -390), Vector2(-590, -410),
		Vector2(900, -600), Vector2(910, -590), Vector2(890, -610),
		Vector2(-800, 500), Vector2(450, 800), Vector2(460, 790),
		Vector2(1400, 300), Vector2(-1300, -700), Vector2(-1290, -710),
		Vector2(0, -800), Vector2(-300, 600), Vector2(-310, 590),
		Vector2(1100, -200), Vector2(-500, 1100), Vector2(-510, 1090),
		Vector2(700, -1000), Vector2(-900, -900), Vector2(-910, -890),
		Vector2(1800, 600), Vector2(-1800, 400), Vector2(-1790, 410),
		Vector2(300, 1400), Vector2(-700, -1300), Vector2(-690, -1290),
		# Outer rocks for expanded map
		Vector2(-2400, -800), Vector2(2500, -600), Vector2(-2100, 1200),
		Vector2(2200, 1000), Vector2(-1600, -1400), Vector2(1700, 1600),
		Vector2(-2800, 200), Vector2(2900, -300),
		# Far rocks for larger map
		Vector2(-3600, -1000), Vector2(3700, -800), Vector2(-3200, 1800),
		Vector2(3400, 1600), Vector2(-4000, -400), Vector2(4100, 200),
		Vector2(-2600, 2600), Vector2(2800, 2800), Vector2(-4500, 1200),
		Vector2(4600, -1400), Vector2(-3800, -2200), Vector2(4000, -2000),
		Vector2(-1400, 3000), Vector2(1600, 3200), Vector2(-5000, 600),
		Vector2(5200, -200),
	]
	for pos in rock_positions:
		_add_rock(deco_layer, pos)
		_nodes_this_frame += 1
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame

	# ---- Dirt paths radiating from town center (longer for bigger map) ----
	var path_points = [
		# Path north
		Vector2(0, -280), Vector2(20, -380), Vector2(-10, -480), Vector2(0, -600),
		Vector2(-50, -750), Vector2(-30, -900), Vector2(-100, -1050), Vector2(-200, -1200),
		Vector2(-250, -1400), Vector2(-300, -1600), Vector2(-350, -1800),
		Vector2(-400, -2100), Vector2(-350, -2500), Vector2(-300, -2900),
		Vector2(-250, -3300), Vector2(-200, -3700),
		# Path east
		Vector2(280, 0), Vector2(400, -15), Vector2(520, 0), Vector2(650, 10),
		Vector2(800, -30), Vector2(1000, -20), Vector2(1200, -60), Vector2(1500, -100),
		Vector2(1800, -200), Vector2(2100, -300), Vector2(2400, -400),
		Vector2(2800, -500), Vector2(3200, -600), Vector2(3600, -700),
		Vector2(4000, -800), Vector2(4500, -900),
		# Path south
		Vector2(0, 280), Vector2(-15, 400), Vector2(0, 520), Vector2(-40, 700),
		Vector2(-60, 850), Vector2(-80, 1000), Vector2(-100, 1200), Vector2(0, 1400),
		Vector2(100, 1600), Vector2(250, 1800), Vector2(400, 2000),
		Vector2(500, 2400), Vector2(600, 2800), Vector2(700, 3200),
		Vector2(800, 3600), Vector2(900, 4000),
		# Path west
		Vector2(-280, 0), Vector2(-400, 15), Vector2(-520, 30), Vector2(-650, 40),
		Vector2(-800, 60), Vector2(-1000, 80), Vector2(-1200, 100), Vector2(-1500, 150),
		Vector2(-1800, 200), Vector2(-2100, 300), Vector2(-2400, 400),
		Vector2(-2800, 500), Vector2(-3200, 600), Vector2(-3600, 700),
		Vector2(-4000, 800), Vector2(-4500, 900),
		# Path NE
		Vector2(200, -300), Vector2(400, -500), Vector2(600, -700), Vector2(800, -900),
		Vector2(1000, -1100), Vector2(1200, -1300),
		Vector2(1500, -1600), Vector2(1800, -1900), Vector2(2200, -2300),
		# Path SW
		Vector2(-300, 350), Vector2(-500, 550), Vector2(-700, 750), Vector2(-1000, 1000),
		Vector2(-1300, 1200), Vector2(-1600, 1400),
		Vector2(-1900, 1700), Vector2(-2200, 2000), Vector2(-2600, 2400),
		# Path NW
		Vector2(-200, -300), Vector2(-400, -500), Vector2(-600, -700), Vector2(-900, -900),
		Vector2(-1200, -1100), Vector2(-1500, -1300),
		Vector2(-1800, -1600), Vector2(-2200, -1900), Vector2(-2600, -2300),
		# Path SE
		Vector2(200, 350), Vector2(400, 550), Vector2(600, 750), Vector2(900, 1000),
		Vector2(1200, 1200), Vector2(1500, 1400),
		Vector2(1800, 1700), Vector2(2200, 2000), Vector2(2600, 2400),
	]
	for pos in path_points:
		_add_path_segment(deco_layer, pos)
		_nodes_this_frame += 1
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame

	# ---- Camp skull markers (match new camp positions) ----
	_add_camp_marker(deco_layer, Vector2(-1200, -860), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(1100, -1060), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(-700, -1560), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(600, 760), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(-2200, 1160), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(900, 1760), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(2400, -660), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(-1800, -1760), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(3000, 1560), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-3500, -660), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(3800, -1460), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-2800, 2360), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-4200, -2460), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(4400, 2960), "Bandits Lv3-5")
	# Skeletons
	_add_camp_marker(deco_layer, Vector2(-900, -1160), "Skeletons Lv2-4")
	_add_camp_marker(deco_layer, Vector2(1400, -560), "Skeletons Lv2-4")
	_add_camp_marker(deco_layer, Vector2(-600, 1360), "Skeletons Lv2-4")
	_add_camp_marker(deco_layer, Vector2(800, -1760), "Skeletons Lv2-4")
	_add_camp_marker(deco_layer, Vector2(-1500, 860), "Skeletons Lv2-4")
	_add_camp_marker(deco_layer, Vector2(2000, 560), "Skeletons Lv2-4")
	# Spiders
	_add_camp_marker(deco_layer, Vector2(-1900, -1360), "Spiders Lv3-5")
	_add_camp_marker(deco_layer, Vector2(2200, -1160), "Spiders Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-2400, 760), "Spiders Lv3-5")
	_add_camp_marker(deco_layer, Vector2(1600, 1360), "Spiders Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-800, -2360), "Spiders Lv3-5")
	_add_camp_marker(deco_layer, Vector2(200, 2560), "Spiders Lv3-5")
	# Trolls
	_add_camp_marker(deco_layer, Vector2(-3200, 1360), "Trolls Lv5-7")
	_add_camp_marker(deco_layer, Vector2(3400, -2160), "Trolls Lv5-7")
	_add_camp_marker(deco_layer, Vector2(-2600, -1960), "Trolls Lv5-7")
	_add_camp_marker(deco_layer, Vector2(2800, 2160), "Trolls Lv5-7")
	# Dark Mages
	_add_camp_marker(deco_layer, Vector2(-3800, -1560), "Dark Mages Lv5-8")
	_add_camp_marker(deco_layer, Vector2(4000, 1160), "Dark Mages Lv5-8")
	_add_camp_marker(deco_layer, Vector2(-4400, 2760), "Dark Mages Lv5-8")
	_add_camp_marker(deco_layer, Vector2(3600, -2960), "Dark Mages Lv5-8")
	# Ogres
	_add_camp_marker(deco_layer, Vector2(-5000, -2760), "Ogres Lv7-10")
	_add_camp_marker(deco_layer, Vector2(5000, 2760), "Ogres Lv7-10")
	_add_camp_marker(deco_layer, Vector2(-4800, 3160), "Ogres Lv7-10")
	# Ogre Bosses
	_add_camp_marker(deco_layer, Vector2(5200, -3460), "OGRE WARLORD Lv10-12")
	_add_camp_marker(deco_layer, Vector2(-5400, -3760), "OGRE WARLORD Lv10-12")

	await get_tree().process_frame

	# ---- Grass tufts scattered (reduced for performance) ----
	for i in range(150):
		var gx = randf_range(-5700, 5700)
		var gy = randf_range(-4200, 4200)
		if Vector2(gx, gy).length() > 550:
			_add_grass_tuft(deco_layer, Vector2(gx, gy))
			_nodes_this_frame += 1
			if _nodes_this_frame >= BATCH_SIZE:
				_nodes_this_frame = 0
				await get_tree().process_frame

	# ---- Bush clusters (reduced for performance) ----
	for i in range(70):
		var bx = randf_range(-5600, 5600)
		var by = randf_range(-4100, 4100)
		if Vector2(bx, by).length() > 550:
			_add_bush(deco_layer, Vector2(bx, by))
			_nodes_this_frame += 1
			if _nodes_this_frame >= BATCH_SIZE:
				_nodes_this_frame = 0
				await get_tree().process_frame

	# ---- Flower patches ----
	for i in range(12):
		var fx = randf_range(-5200, 5200)
		var fy = randf_range(-3800, 3800)
		if Vector2(fx, fy).length() > 600:
			_add_flowers(deco_layer, Vector2(fx, fy))

	# ---- Fallen logs scattered around ----
	for i in range(18):
		var lx = randf_range(-5400, 5400)
		var ly = randf_range(-4000, 4000)
		if Vector2(lx, ly).length() > 550:
			_add_fallen_log(deco_layer, Vector2(lx, ly))

	# ---- Ground debris (reduced for performance) ----
	_nodes_this_frame = 0
	for i in range(100):
		var dx = randf_range(-5700, 5700)
		var dy = randf_range(-4200, 4200)
		_add_ground_debris(deco_layer, Vector2(dx, dy))
		_nodes_this_frame += 1
		if _nodes_this_frame >= BATCH_SIZE:
			_nodes_this_frame = 0
			await get_tree().process_frame

	# ---- Mushroom clusters near moist areas ----
	for i in range(25):
		var mx = randf_range(-5400, 5400)
		var my = randf_range(-4000, 4000)
		if Vector2(mx, my).length() > 550:
			_add_mushrooms(deco_layer, Vector2(mx, my))

	# ---- Vine decorations ----
	for i in range(20):
		var vx = randf_range(-5200, 5200)
		var vy = randf_range(-3800, 3800)
		if Vector2(vx, vy).length() > 600:
			_add_vines(deco_layer, Vector2(vx, vy))

	# ---- Ambient floating particles (dust/pollen) ----
	_spawn_ambient_particles()

# ============================================================
# HARVESTABLE TREES: Choppable trees that drop wood
# ============================================================

func _generate_harvestable_trees_async() -> void:
	var tree_layer = $Decorations
	var rng = RandomNumberGenerator.new()
	rng.seed = 9876

	# Scatter harvestable trees across the map in small groves
	# More trees further from town, mixed sizes
	var grove_centers = [
		# Near town (small trees mostly — easy early wood)
		Vector2(-650, -500), Vector2(550, -450), Vector2(-500, 600),
		Vector2(650, 400), Vector2(-400, -800), Vector2(500, 700),
		# Mid range (medium trees mixed with small)
		Vector2(-1300, -700), Vector2(1200, -600), Vector2(-1100, 900),
		Vector2(1300, 800), Vector2(-900, -1100), Vector2(800, 1200),
		Vector2(-1600, 400), Vector2(1500, -300), Vector2(0, -1400),
		Vector2(0, 1500), Vector2(-700, 1400), Vector2(900, -1300),
		# Outer ring (large trees appear)
		Vector2(-2200, -800), Vector2(2100, -600), Vector2(-2000, 1200),
		Vector2(2300, 1000), Vector2(-2500, -1500), Vector2(2400, -1400),
		Vector2(-1800, 1800), Vector2(2000, 1600), Vector2(-2800, 200),
		Vector2(2700, -100), Vector2(-1400, -2000), Vector2(1600, 2100),
		# Far groves (mostly large)
		Vector2(-3400, -1000), Vector2(3200, -800), Vector2(-3000, 1600),
		Vector2(3300, 1400), Vector2(-3800, 600), Vector2(3600, -400),
		Vector2(-2600, 2400), Vector2(2800, 2200), Vector2(-4000, -500),
		Vector2(4100, 300), Vector2(-3200, -2200), Vector2(3400, -2000),
	]

	var _htree_count: int = 0
	for center in grove_centers:
		# Determine size bias based on distance from town center
		var dist = center.length()
		var tree_count = rng.randi_range(2, 5)
		for _i in range(tree_count):
			var offset = Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
			var pos = center + offset
			# Skip if too close to town
			if pos.length() < 520:
				continue
			# Determine tree size based on distance
			var size_roll = rng.randf()
			var tree_size: int  # 0=SMALL, 1=MEDIUM, 2=LARGE
			if dist < 1000:
				# Near town: mostly small
				tree_size = 0 if size_roll < 0.7 else 1
			elif dist < 2500:
				# Mid range: mixed
				if size_roll < 0.3:
					tree_size = 0
				elif size_roll < 0.75:
					tree_size = 1
				else:
					tree_size = 2
			else:
				# Far out: mostly large
				if size_roll < 0.1:
					tree_size = 0
				elif size_roll < 0.4:
					tree_size = 1
				else:
					tree_size = 2
			_spawn_harvestable_tree(tree_layer, pos, tree_size)
			_htree_count += 1
			if _htree_count >= 20:
				_htree_count = 0
				await get_tree().process_frame

func _spawn_harvestable_tree(parent: Node2D, pos: Vector2, size_enum: int) -> void:
	var tree = HarvestableTree.new()
	tree.setup(size_enum)
	tree.position = pos
	# Slight random scale variation
	var s = randf_range(0.9, 1.15)
	tree.scale = Vector2(s, s)
	parent.add_child(tree)

# ============================================================
# DECORATION HELPERS
# ============================================================

func _add_tree(parent: Node2D, pos: Vector2) -> void:
	var tree_sprite = Sprite2D.new()
	tree_sprite.position = pos
	tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if randf() > 0.35:
		tree_sprite.texture = SpriteGenerator.get_texture("tree_jungle")
		tree_sprite.offset = Vector2(0, -24)
	else:
		tree_sprite.texture = SpriteGenerator.get_texture("tree_small")
		tree_sprite.offset = Vector2(0, -14)
	var s = randf_range(0.8, 1.4)
	tree_sprite.scale = Vector2(s, s)
	# Slight color variation for depth
	var v = randf_range(-0.05, 0.05)
	tree_sprite.modulate = Color(1.0 + v, 1.0 + v * 0.5, 1.0 + v)
	tree_sprite.z_index = 0
	parent.add_child(tree_sprite)

func _add_rock(parent: Node2D, pos: Vector2) -> void:
	var rock_sprite = Sprite2D.new()
	rock_sprite.position = pos
	rock_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if randf() > 0.5:
		rock_sprite.texture = SpriteGenerator.get_texture("rock_large")
	else:
		rock_sprite.texture = SpriteGenerator.get_texture("rock")
	var s = randf_range(0.8, 1.3)
	rock_sprite.scale = Vector2(s, s)
	parent.add_child(rock_sprite)

func _add_path_segment(parent: Node2D, pos: Vector2) -> void:
	var path_sprite = Sprite2D.new()
	path_sprite.position = pos
	path_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	path_sprite.texture = SpriteGenerator.get_texture("dirt_path")
	var sx = randf_range(2.0, 3.5)
	var sy = randf_range(1.2, 2.2)
	path_sprite.scale = Vector2(sx, sy)
	path_sprite.modulate.a = 0.75
	path_sprite.z_index = -8
	parent.add_child(path_sprite)

func _add_camp_marker(parent: Node2D, pos: Vector2, text: String) -> void:
	var skull = Sprite2D.new()
	skull.position = pos
	skull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skull.texture = SpriteGenerator.get_texture("skull_icon")
	skull.modulate = Color(0.9, 0.3, 0.3, 0.8)
	parent.add_child(skull)

	var label = Label.new()
	label.text = text
	label.position = pos + Vector2(-30, -18)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5, 0.7))
	parent.add_child(label)

func _add_flowers(parent: Node2D, pos: Vector2) -> void:
	for i in range(randi_range(2, 4)):
		var flower = Sprite2D.new()
		flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flower.texture = SpriteGenerator.get_texture("flowers")
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		flower.position = pos + offset
		flower.z_index = -1
		parent.add_child(flower)

func _add_bush(parent: Node2D, pos: Vector2) -> void:
	var bush = Sprite2D.new()
	bush.position = pos
	bush.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bush.texture = SpriteGenerator.get_texture("bush")
	var s = randf_range(0.8, 1.5)
	bush.scale = Vector2(s, s)
	parent.add_child(bush)

func _add_grass_tuft(parent: Node2D, pos: Vector2) -> void:
	var grass = Sprite2D.new()
	grass.position = pos
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if randf() > 0.5:
		grass.texture = SpriteGenerator.get_texture("grass_tuft")
	else:
		grass.texture = SpriteGenerator.get_texture("grass_tuft_tall")
	var s = randf_range(0.8, 1.5)
	grass.scale = Vector2(s, s)
	grass.z_index = -1
	parent.add_child(grass)

func _add_fallen_log(parent: Node2D, pos: Vector2) -> void:
	var log_sprite = Sprite2D.new()
	log_sprite.position = pos
	log_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	log_sprite.texture = SpriteGenerator.get_texture("fallen_log")
	var s = randf_range(0.9, 1.3)
	log_sprite.scale = Vector2(s, s)
	parent.add_child(log_sprite)

func _add_ground_debris(parent: Node2D, pos: Vector2) -> void:
	var debris = Sprite2D.new()
	debris.position = pos
	debris.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	debris.texture = SpriteGenerator.get_texture("ground_debris")
	debris.rotation = randf_range(0, TAU)
	debris.modulate.a = randf_range(0.5, 0.8)
	debris.z_index = -2
	parent.add_child(debris)

func _add_mushrooms(parent: Node2D, pos: Vector2) -> void:
	var shroom = Sprite2D.new()
	shroom.position = pos
	shroom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shroom.texture = SpriteGenerator.get_texture("mushroom_cluster")
	var s = randf_range(0.8, 1.3)
	shroom.scale = Vector2(s, s)
	shroom.z_index = -1
	parent.add_child(shroom)

func _add_vines(parent: Node2D, pos: Vector2) -> void:
	var vine = Sprite2D.new()
	vine.position = pos
	vine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vine.texture = SpriteGenerator.get_texture("vines")
	var s = randf_range(0.8, 1.2)
	vine.scale = Vector2(s, s)
	vine.modulate.a = randf_range(0.6, 0.9)
	vine.z_index = -1
	parent.add_child(vine)

# ============================================================
# AMBIENT PARTICLES
# ============================================================

func _spawn_ambient_particles() -> void:
	# Floating dust/pollen particles
	var particles = CPUParticles2D.new()
	particles.z_index = 5
	particles.amount = 15
	particles.lifetime = 8.0
	particles.emitting = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(800, 600)
	particles.direction = Vector2(1, -0.3)
	particles.spread = 40.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector2(0, 0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = Color(0.7, 0.75, 0.5, 0.12)
	add_child(particles)
