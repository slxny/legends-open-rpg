extends Node2D

@onready var heal_beacon: Area2D = $HealBeacon
@onready var info_beacon: Area2D = $InfoBeacon

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

func _ready() -> void:
	GameManager.game_message.emit("Welcome to Haven's Rest", Color(1, 1, 1))
	GameManager.game_message.emit("Level 1-5 Zone", Color(0.7, 0.7, 0.7))

	heal_beacon.activated.connect(_on_heal_beacon)
	info_beacon.activated.connect(_on_info_beacon)


	_generate_terrain()
	_generate_town()
	_generate_decorations()

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

	# Scattered dirt patches across the expanded map
	var rng = RandomNumberGenerator.new()
	rng.seed = 555
	for _i in range(120):
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

# ============================================================
# DECORATIONS: Dense SC:BW jungle foliage
# ============================================================

func _generate_decorations() -> void:
	var deco_layer = $Decorations

	# ---- Border trees: dense double-row along all 4 walls ----
	for x in range(-5950, 5951, 55):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -4420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -4350 + randf_range(-20, 20)))
	for x in range(-5950, 5951, 55):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 4420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 4350 + randf_range(-20, 20)))
	for y in range(-4400, 4401, 55):
		_add_tree(deco_layer, Vector2(-5920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(-5850 + randf_range(-15, 15), y + randf_range(-12, 12)))
	for y in range(-4400, 4401, 55):
		_add_tree(deco_layer, Vector2(5920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(5850 + randf_range(-15, 15), y + randf_range(-12, 12)))

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
		for i in range(randi_range(2, 5)):
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			_add_bush(deco_layer, center + offset)
		if randf() > 0.5:
			_add_vines(deco_layer, center + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
		if randf() > 0.6:
			_add_mushrooms(deco_layer, center + Vector2(randf_range(-40, 40), randf_range(-30, 30)))

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

	# ---- Dense grass tufts scattered everywhere ----
	for i in range(400):
		var gx = randf_range(-5700, 5700)
		var gy = randf_range(-4200, 4200)
		if Vector2(gx, gy).length() > 550:
			_add_grass_tuft(deco_layer, Vector2(gx, gy))

	# ---- Bush clusters ----
	for i in range(180):
		var bx = randf_range(-5600, 5600)
		var by = randf_range(-4100, 4100)
		if Vector2(bx, by).length() > 550:
			_add_bush(deco_layer, Vector2(bx, by))

	# ---- Flower patches ----
	for i in range(30):
		var fx = randf_range(-5200, 5200)
		var fy = randf_range(-3800, 3800)
		if Vector2(fx, fy).length() > 600:
			_add_flowers(deco_layer, Vector2(fx, fy))

	# ---- Fallen logs scattered around ----
	for i in range(45):
		var lx = randf_range(-5400, 5400)
		var ly = randf_range(-4000, 4000)
		if Vector2(lx, ly).length() > 550:
			_add_fallen_log(deco_layer, Vector2(lx, ly))

	# ---- Ground debris everywhere ----
	for i in range(280):
		var dx = randf_range(-5700, 5700)
		var dy = randf_range(-4200, 4200)
		_add_ground_debris(deco_layer, Vector2(dx, dy))

	# ---- Mushroom clusters near moist areas ----
	for i in range(70):
		var mx = randf_range(-5400, 5400)
		var my = randf_range(-4000, 4000)
		if Vector2(mx, my).length() > 550:
			_add_mushrooms(deco_layer, Vector2(mx, my))

	# ---- Vine decorations ----
	for i in range(50):
		var vx = randf_range(-5200, 5200)
		var vy = randf_range(-3800, 3800)
		if Vector2(vx, vy).length() > 600:
			_add_vines(deco_layer, Vector2(vx, vy))

	# ---- Ambient floating particles (dust/pollen) ----
	_spawn_ambient_particles()

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
	particles.amount = 30
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
