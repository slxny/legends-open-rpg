extends Node2D

@onready var heal_beacon: Area2D = $HealBeacon
@onready var info_beacon: Area2D = $InfoBeacon

# Creep camp positions for ground darkening
var _camp_positions := [
	Vector2(-700, -500), Vector2(600, -700), Vector2(-300, -900),
	Vector2(-900, 600), Vector2(400, 800),
	Vector2(1000, 700), Vector2(-1200, -200), Vector2(1300, -500),
]

func _ready() -> void:
	GameManager.game_message.emit("Welcome to Haven's Rest", Color(1, 1, 1))
	GameManager.game_message.emit("Level 1-5 Zone", Color(0.7, 0.7, 0.7))

	heal_beacon.activated.connect(_on_heal_beacon)
	info_beacon.activated.connect(_on_info_beacon)

	_generate_terrain()
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
	# Main jungle ground — single Sprite2D with texture repeat covering the map
	var ground_sprite = Sprite2D.new()
	ground_sprite.texture = SpriteGenerator.get_texture("ground_jungle")
	ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_sprite.region_enabled = true
	ground_sprite.region_rect = Rect2(-2000, -1500, 4000, 3000)
	ground_sprite.z_index = -10
	ground_sprite.position = Vector2(-2000, -1500)
	ground_sprite.centered = false
	add_child(ground_sprite)
	move_child(ground_sprite, 0)

	# Town stone floor overlay
	var town_stone = Sprite2D.new()
	town_stone.texture = SpriteGenerator.get_texture("ground_stone")
	town_stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	town_stone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	town_stone.region_enabled = true
	town_stone.region_rect = Rect2(0, 0, 360, 300)
	town_stone.position = Vector2(-180, -150)
	town_stone.centered = false
	town_stone.z_index = -9
	add_child(town_stone)

	# Dark creep ground patches near each camp
	for camp_pos in _camp_positions:
		_add_creep_ground(camp_pos, randf_range(140, 200))

	# Scattered dirt patches across the map for variety
	var rng = RandomNumberGenerator.new()
	rng.seed = 555
	for _i in range(40):
		var pos = Vector2(rng.randf_range(-1800, 1800), rng.randf_range(-1400, 1400))
		if pos.length() > 250:  # Avoid town center
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

# ============================================================
# DECORATIONS: Dense SC:BW jungle foliage
# ============================================================

func _generate_decorations() -> void:
	var deco_layer = $Decorations

	# ---- Border trees: dense double-row along all 4 walls ----
	for x in range(-1950, 1951, 55):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -1420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), -1350 + randf_range(-20, 20)))
	for x in range(-1950, 1951, 55):
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 1420 + randf_range(-25, 25)))
		_add_tree(deco_layer, Vector2(x + randf_range(-12, 12), 1350 + randf_range(-20, 20)))
	for y in range(-1400, 1401, 55):
		_add_tree(deco_layer, Vector2(-1920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(-1850 + randf_range(-15, 15), y + randf_range(-12, 12)))
	for y in range(-1400, 1401, 55):
		_add_tree(deco_layer, Vector2(1920 + randf_range(-15, 15), y + randf_range(-12, 12)))
		_add_tree(deco_layer, Vector2(1850 + randf_range(-15, 15), y + randf_range(-12, 12)))

	# ---- Interior tree clusters (more and denser) ----
	var cluster_centers = [
		Vector2(-400, -700), Vector2(200, -400), Vector2(-1000, 100),
		Vector2(800, -300), Vector2(-600, 400), Vector2(500, 200),
		Vector2(-300, 900), Vector2(700, 600), Vector2(-1400, -700),
		Vector2(1400, -200), Vector2(-1300, 800), Vector2(1200, 900),
		Vector2(0, -1100), Vector2(0, 1100), Vector2(-800, -300),
		Vector2(1000, -800), Vector2(-500, -100), Vector2(300, 500),
		# Additional clusters for density
		Vector2(-200, -500), Vector2(900, 400), Vector2(-1100, -400),
		Vector2(1600, 300), Vector2(-1600, -900), Vector2(1500, -700),
		Vector2(-700, 700), Vector2(100, 900), Vector2(-1500, 500),
		Vector2(600, -1000), Vector2(-400, 1200), Vector2(1100, -100),
	]
	for center in cluster_centers:
		var count = randi_range(4, 9)
		for i in range(count):
			var offset = Vector2(randf_range(-70, 70), randf_range(-70, 70))
			_add_tree(deco_layer, center + offset)
		# Add undergrowth near tree clusters
		for i in range(randi_range(2, 5)):
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			_add_bush(deco_layer, center + offset)
		# Vines and mushrooms near tree bases
		if randf() > 0.5:
			_add_vines(deco_layer, center + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
		if randf() > 0.6:
			_add_mushrooms(deco_layer, center + Vector2(randf_range(-40, 40), randf_range(-30, 30)))

	# ---- Rock formations ----
	var rock_positions = [
		Vector2(-500, -300), Vector2(-510, -290), Vector2(-490, -310),
		Vector2(800, -500), Vector2(810, -490), Vector2(790, -510),
		Vector2(-700, 400), Vector2(350, 700), Vector2(360, 690),
		Vector2(1200, 200), Vector2(-1100, -600), Vector2(-1090, -610),
		Vector2(0, -700), Vector2(-200, 500), Vector2(-210, 490),
		Vector2(900, -100), Vector2(-400, 1000), Vector2(-410, 990),
		Vector2(600, -900), Vector2(-800, -800), Vector2(-810, -790),
		Vector2(1500, 500), Vector2(-1500, 300), Vector2(-1490, 310),
		Vector2(200, 1200), Vector2(-600, -1100), Vector2(-590, -1090),
	]
	for pos in rock_positions:
		_add_rock(deco_layer, pos)

	# ---- Dirt paths radiating from town center (wider and longer) ----
	var path_points = [
		# Path north (wider)
		Vector2(0, -180), Vector2(20, -230), Vector2(-10, -280), Vector2(0, -380),
		Vector2(-50, -480), Vector2(-30, -530), Vector2(-100, -580), Vector2(-200, -700),
		Vector2(-250, -800), Vector2(-300, -900), Vector2(-320, -1000),
		# Path east
		Vector2(180, 0), Vector2(230, -15), Vector2(300, 0), Vector2(380, 10),
		Vector2(420, -30), Vector2(500, -20), Vector2(550, -60), Vector2(700, -100),
		Vector2(900, -200), Vector2(1100, -300), Vector2(1300, -400),
		# Path south
		Vector2(0, 180), Vector2(-15, 240), Vector2(0, 300), Vector2(-40, 420),
		Vector2(-60, 500), Vector2(-80, 560), Vector2(-100, 700), Vector2(0, 750),
		Vector2(100, 800), Vector2(250, 900), Vector2(400, 1000),
		# Path west
		Vector2(-180, 0), Vector2(-240, 15), Vector2(-320, 30), Vector2(-400, 40),
		Vector2(-480, 60), Vector2(-600, 80), Vector2(-640, 100), Vector2(-800, 150),
		Vector2(-1000, 200), Vector2(-1100, 300), Vector2(-1200, 400),
		# Path NE
		Vector2(150, -200), Vector2(250, -350), Vector2(300, -400), Vector2(450, -550),
		Vector2(550, -650), Vector2(650, -750),
		# Path SW
		Vector2(-200, 250), Vector2(-300, 380), Vector2(-400, 450), Vector2(-600, 550),
		Vector2(-800, 600), Vector2(-900, 650),
	]
	for pos in path_points:
		_add_path_segment(deco_layer, pos)

	# ---- Camp skull markers ----
	_add_camp_marker(deco_layer, Vector2(-700, -460), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(600, -660), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(-300, -860), "Goblins Lv1-2")
	_add_camp_marker(deco_layer, Vector2(-900, 560), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(400, 760), "Wolves Lv2-3")
	_add_camp_marker(deco_layer, Vector2(1000, 660), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(-1200, -160), "Bandits Lv3-5")
	_add_camp_marker(deco_layer, Vector2(1300, -460), "Bandits Lv3-5")

	# ---- Dense grass tufts scattered everywhere ----
	for i in range(120):
		var gx = randf_range(-1800, 1800)
		var gy = randf_range(-1400, 1400)
		if Vector2(gx, gy).length() > 180:
			_add_grass_tuft(deco_layer, Vector2(gx, gy))

	# ---- Bush clusters ----
	for i in range(50):
		var bx = randf_range(-1700, 1700)
		var by = randf_range(-1300, 1300)
		if Vector2(bx, by).length() > 200:
			_add_bush(deco_layer, Vector2(bx, by))

	# ---- Flower patches (fewer, SC:BW is dark) ----
	for i in range(8):
		var fx = randf_range(-1500, 1500)
		var fy = randf_range(-1200, 1200)
		if Vector2(fx, fy).length() > 300:
			_add_flowers(deco_layer, Vector2(fx, fy))

	# ---- Fallen logs scattered around ----
	for i in range(12):
		var lx = randf_range(-1600, 1600)
		var ly = randf_range(-1200, 1200)
		if Vector2(lx, ly).length() > 250:
			_add_fallen_log(deco_layer, Vector2(lx, ly))

	# ---- Ground debris everywhere ----
	for i in range(80):
		var dx = randf_range(-1800, 1800)
		var dy = randf_range(-1400, 1400)
		_add_ground_debris(deco_layer, Vector2(dx, dy))

	# ---- Mushroom clusters near moist areas ----
	for i in range(20):
		var mx = randf_range(-1600, 1600)
		var my = randf_range(-1200, 1200)
		if Vector2(mx, my).length() > 200:
			_add_mushrooms(deco_layer, Vector2(mx, my))

	# ---- Vine decorations draped over rocks/trees ----
	for i in range(15):
		var vx = randf_range(-1500, 1500)
		var vy = randf_range(-1100, 1100)
		if Vector2(vx, vy).length() > 300:
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
	log_sprite.rotation = randf_range(-0.3, 0.3)
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
	vine.rotation = randf_range(-0.2, 0.2)
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
	particles.emission_rect_extents = Vector2(500, 350)
	particles.direction = Vector2(1, -0.3)
	particles.spread = 40.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector2(0, 0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = Color(0.7, 0.75, 0.5, 0.12)
	add_child(particles)
