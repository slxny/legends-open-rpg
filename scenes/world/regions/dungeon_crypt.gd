extends Node2D

# ============================================================
# DUNGEON CRYPT — Small underground dungeon (1000x1000)
# Requires Level 10+ to enter. Dark stone corridors with
# 8 new enemy types: snakes, bats, slimes, mimics, undead.
# ============================================================

const CreepCampScene = preload("res://scenes/enemies/creep_camp.tscn")

@onready var exit_beacon: Area2D = $ExitBeacon

func _ready() -> void:
	# Dark underground atmosphere
	modulate = Color(0.6, 0.55, 0.7)
	_generate_terrain()
	_generate_decorations()
	_spawn_camps()

func _generate_terrain() -> void:
	# Dark stone ground — tiled across the dungeon
	var ground = Sprite2D.new()
	ground.texture = SpriteGenerator.get_texture("ground_stone")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-500, -500, 1000, 1000)
	ground.position = Vector2(-500, -500)
	ground.centered = false
	ground.z_index = -10
	ground.modulate = Color(0.4, 0.35, 0.45)  # Dark tint for underground
	add_child(ground)
	move_child(ground, 0)

	# Creep patches for atmosphere
	var rng = RandomNumberGenerator.new()
	rng.seed = 1234
	for _i in range(8):
		var pos = Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
		var creep = Sprite2D.new()
		creep.texture = SpriteGenerator.get_texture("ground_creep")
		creep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		creep.position = pos
		var s = rng.randf_range(1.5, 3.0)
		creep.scale = Vector2(s, s * rng.randf_range(0.7, 1.0))
		creep.modulate = Color(0.3, 0.25, 0.35, 0.6)
		creep.z_index = -9
		add_child(creep)

func _generate_decorations() -> void:
	var deco = $Decorations
	var rng = RandomNumberGenerator.new()
	rng.seed = 5678

	# Scattered crates and barrels (dungeon-tinted)
	var deco_positions = [
		Vector2(-350, -300), Vector2(300, -250), Vector2(-200, 350),
		Vector2(400, 200), Vector2(-100, -400), Vector2(350, 380),
		Vector2(-400, 100), Vector2(200, -350),
	]
	var deco_types = ["crate_stack", "barrel", "barrel", "crate_stack",
		"barrel", "crate_stack", "barrel", "crate_stack"]
	for i in range(deco_positions.size()):
		var spr = Sprite2D.new()
		spr.texture = SpriteGenerator.get_texture(deco_types[i])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = deco_positions[i]
		spr.modulate = Color(0.5, 0.45, 0.55)  # Dark tint
		spr.z_index = 0
		deco.add_child(spr)

	# Rock formations along walls
	var rock_positions = [
		Vector2(-450, -200), Vector2(-450, 200), Vector2(450, -150),
		Vector2(450, 300), Vector2(-200, -450), Vector2(200, 450),
	]
	for pos in rock_positions:
		var spr = Sprite2D.new()
		spr.texture = SpriteGenerator.get_texture("rock")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = pos
		spr.modulate = Color(0.45, 0.4, 0.5)
		spr.z_index = 0
		deco.add_child(spr)

func _spawn_camps() -> void:
	# 8 camps with increasing difficulty from edges toward center
	var camps = [
		{"type": "dungeon_bat", "pos": Vector2(-300, -300), "count": 8},
		{"type": "cave_snake", "pos": Vector2(300, -250), "count": 5},
		{"type": "dungeon_bat", "pos": Vector2(-250, 280), "count": 6},
		{"type": "flan", "pos": Vector2(280, 300), "count": 4},
		{"type": "vampire_bat", "pos": Vector2(-150, -100), "count": 4},
		{"type": "ghoul", "pos": Vector2(150, -150), "count": 3},
		{"type": "mimic", "pos": Vector2(-100, 200), "count": 2},
		{"type": "crypt_knight", "pos": Vector2(50, 50), "count": 3},
	]

	for camp_def in camps:
		var camp = CreepCampScene.instantiate()
		camp.camp_type = camp_def["type"]
		camp.enemy_count = camp_def["count"]
		camp.respawn_time = 60.0
		camp.position = camp_def["pos"]
		add_child(camp)

		# Creep ground at camp
		for _j in range(3):
			var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			var creep = Sprite2D.new()
			creep.texture = SpriteGenerator.get_texture("ground_creep")
			creep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			creep.position = camp_def["pos"] + offset
			var s = randf_range(0.8, 1.5)
			creep.scale = Vector2(s, s * randf_range(0.7, 1.0))
			creep.modulate = Color(0.3, 0.2, 0.35, 0.7)
			creep.z_index = -9
			add_child(creep)
