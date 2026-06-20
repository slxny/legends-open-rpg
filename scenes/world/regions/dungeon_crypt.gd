extends Node2D

# ============================================================
# DUNGEON CRYPT — Underground dungeon (2000x2000)
# Requires Level 10+ to enter. Dark stone corridors with
# 12 enemy camps: snakes, bats, slimes, mimics, undead.
# ============================================================

const CreepCampScene = preload("res://scenes/enemies/creep_camp.tscn")

@onready var exit_beacon: Area2D = $ExitBeacon

func _ready() -> void:
	# v0.93.2 — DEEPER cold dungeon: bluer + darker than v0.92's 0.6/0.55/0.7.
	modulate = Color(0.46, 0.46, 0.62)
	_generate_terrain()
	_generate_decorations()
	_spawn_camps()
	_spawn_dungeon_atmosphere()


func _spawn_dungeon_atmosphere() -> void:
	# v0.93.2 — atmospheric ambient pass for the crypt:
	#   - 14 candle-pool glow sprites scattered across the floor (warm
	#     orange pools that punch through the cold blue ambient).
	#   - 3 cold fog ribbons drifting slowly horizontally across the room.
	#   - Blood spatters baked around enemy camps.
	#   - 10 cracked-bone debris piles for set dressing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309
	var blob_tex := SpriteGenerator.get_texture("crystal_white")
	if blob_tex == null:
		return

	# Candle-glow pools — warm pulse against the cold ambient.
	for _i in range(14):
		var pos := Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900))
		var pool := Sprite2D.new()
		pool.texture = blob_tex
		pool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pool.position = pos
		pool.scale = Vector2(rng.randf_range(2.6, 4.2), rng.randf_range(1.6, 2.6))
		pool.rotation = rng.randf() * TAU
		pool.modulate = Color(1.5, 0.85, 0.30, 0.55)
		pool.z_index = -6
		add_child(pool)
		# Slow flicker.
		var dur: float = rng.randf_range(1.1, 1.8)
		var tw := pool.create_tween().set_loops()
		tw.tween_property(pool, "modulate:a", 0.72, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pool, "modulate:a", 0.38, dur).set_trans(Tween.TRANS_SINE)

	# Cold drifting fog ribbons.
	for i in range(3):
		var fog := Sprite2D.new()
		fog.texture = blob_tex
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fog.modulate = Color(0.55, 0.65, 0.95, rng.randf_range(0.05, 0.10))
		fog.scale = Vector2(rng.randf_range(80.0, 120.0), rng.randf_range(6.0, 12.0))
		fog.rotation = rng.randf_range(-0.04, 0.04)
		fog.z_index = 7
		var start_y: float = float(i) * 700.0 - 1000.0
		fog.position = Vector2(-1400.0, start_y)
		add_child(fog)
		var dur: float = rng.randf_range(50.0, 80.0)
		var tw := fog.create_tween().set_loops()
		tw.tween_property(fog, "position", Vector2(1400.0, start_y + rng.randf_range(-40, 40)), dur)
		tw.tween_property(fog, "position", fog.position, 0.0)

	# Blood spatters near camps.
	var camp_positions: Array[Vector2] = []
	for child in get_children():
		if child is Node2D and child.has_method("_spawn_enemies_staggered"):
			camp_positions.append((child as Node2D).position)
	for _i in range(48):
		if camp_positions.is_empty():
			break
		var center: Vector2 = camp_positions[rng.randi() % camp_positions.size()]
		var pos: Vector2 = center + Vector2(rng.randf_range(-160, 160), rng.randf_range(-150, 150))
		var s := Sprite2D.new()
		s.texture = blob_tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = pos
		s.scale = Vector2(rng.randf_range(0.8, 1.7), rng.randf_range(0.5, 1.1))
		s.rotation = rng.randf() * TAU
		s.modulate = Color(rng.randf_range(0.30, 0.46), rng.randf_range(0.04, 0.10),
			rng.randf_range(0.03, 0.07), rng.randf_range(0.70, 0.92))
		s.z_index = -7
		add_child(s)

	# Cracked-bone debris piles — small near-white sprite clusters.
	for _i in range(10):
		var center: Vector2 = Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900))
		for _b in range(rng.randi_range(3, 5)):
			var bone := Sprite2D.new()
			bone.texture = blob_tex
			bone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bone.position = center + Vector2(rng.randf_range(-22, 22), rng.randf_range(-18, 18))
			bone.scale = Vector2(rng.randf_range(0.3, 0.55), rng.randf_range(0.10, 0.18))
			bone.rotation = rng.randf() * TAU
			bone.modulate = Color(0.86, 0.82, 0.72, 0.85)
			bone.z_index = -6
			add_child(bone)

func setup_dungeon_minimap() -> void:
	## Call this when the player enters the dungeon to switch the minimap.
	var minimaps = get_tree().get_nodes_in_group("minimap")
	if minimaps.size() > 0:
		var minimap = minimaps[0]
		if minimap.has_method("set_region"):
			# Dungeon is 2000x2000 local, at zoom 3.0 = 6000x6000 world units
			var dungeon_camps: Array = []
			for child in get_children():
				if child.has_method("_spawn_enemies_staggered"):
					dungeon_camps.append(child.global_position)
			var exit_pos = exit_beacon.position if exit_beacon else Vector2(0, -900)
			minimap.set_region(
				Vector2(6000, 6000),
				dungeon_camps,
				[],
				Rect2(),
				false,
				[global_position + exit_pos],
				global_position
			)

func _generate_terrain() -> void:
	# Dark stone ground — tiled across the dungeon
	var ground = Sprite2D.new()
	ground.texture = SpriteGenerator.get_texture("ground_stone")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-1000, -1000, 2000, 2000)
	ground.position = Vector2(-1000, -1000)
	ground.centered = false
	ground.z_index = -10
	ground.modulate = Color(0.4, 0.35, 0.45)  # Dark tint for underground
	add_child(ground)
	move_child(ground, 0)

	# Creep patches for atmosphere
	var rng = RandomNumberGenerator.new()
	rng.seed = 1234
	for _i in range(14):
		var pos = Vector2(rng.randf_range(-800, 800), rng.randf_range(-800, 800))
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

	# Scattered crates and barrels (dungeon-tinted) — more to fill larger space
	var deco_positions = [
		Vector2(-700, -600), Vector2(600, -500), Vector2(-400, 700),
		Vector2(800, 400), Vector2(-200, -800), Vector2(700, 760),
		Vector2(-800, 200), Vector2(400, -700),
		Vector2(-500, 500), Vector2(300, 600), Vector2(-650, -200),
		Vector2(500, -300), Vector2(-300, 850), Vector2(850, -650),
	]
	var deco_types = ["crate_stack", "barrel", "barrel", "crate_stack",
		"barrel", "crate_stack", "barrel", "crate_stack",
		"barrel", "crate_stack", "barrel", "crate_stack",
		"barrel", "crate_stack"]
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
		Vector2(-900, -400), Vector2(-900, 400), Vector2(900, -300),
		Vector2(900, 600), Vector2(-400, -900), Vector2(400, 900),
		Vector2(-900, 0), Vector2(900, 0), Vector2(0, -900), Vector2(0, 900),
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
	# 16 camps spread across the 2000x2000 dungeon with increasing difficulty
	var camps = [
		# Outer ring — swarming enemies
		{"type": "dungeon_bat", "pos": Vector2(-600, -600), "count": 10},
		{"type": "cave_snake", "pos": Vector2(600, -500), "count": 7},
		{"type": "dungeon_bat", "pos": Vector2(-500, 560), "count": 8},
		{"type": "flan", "pos": Vector2(560, 600), "count": 6},
		{"type": "cave_snake", "pos": Vector2(-800, -200), "count": 6},
		# Mid ring — dangerous enemies
		{"type": "vampire_bat", "pos": Vector2(-300, -200), "count": 6},
		{"type": "ghoul", "pos": Vector2(300, -300), "count": 5},
		{"type": "cave_snake", "pos": Vector2(-700, 0), "count": 7},
		{"type": "flan", "pos": Vector2(700, 0), "count": 6},
		{"type": "vampire_bat", "pos": Vector2(750, -700), "count": 5},
		# Inner ring — elite enemies
		{"type": "mimic", "pos": Vector2(-200, 400), "count": 3},
		{"type": "crypt_knight", "pos": Vector2(100, 100), "count": 5},
		{"type": "ghoul", "pos": Vector2(-400, 800), "count": 6},
		{"type": "crypt_knight", "pos": Vector2(400, -750), "count": 4},
		# Core — lich and crypt knight elite guard
		{"type": "lich", "pos": Vector2(-100, -50), "count": 3},
		{"type": "lich", "pos": Vector2(300, 500), "count": 2},
	]

	# Compute world bounds for enemy clamping (20px margin from walls)
	var bounds = Rect2(-980, -980, 1960, 1960)

	for camp_def in camps:
		var camp = CreepCampScene.instantiate()
		camp.camp_type = camp_def["type"]
		camp.enemy_count = camp_def["count"]
		camp.respawn_time = 90.0
		camp.position = camp_def["pos"]
		camp.enemy_bounds = bounds
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
