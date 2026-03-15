extends Node

signal gold_changed(new_amount: int)
signal wood_changed(new_amount: int)
signal kills_changed(new_total: int)
signal hero_selected(hero_class: String)
signal game_started
signal item_picked_up(item_name: String)
signal game_message(text: String, color: Color)

enum HeroClass { BLADE_KNIGHT, SHADOW_RANGER }

var current_hero_class: String = ""
var gold: int = 0:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)
var wood: int = 0:
	set(value):
		wood = max(0, value)
		wood_changed.emit(wood)

var total_kills: int = 0
var killed_bosses: Array[String] = []
var found_artifacts: Array[String] = []

# Kill milestone rewards
const KILL_MILESTONES: Array[Dictionary] = [
	{"kills": 100, "gold": 50, "rarities": [ItemData.Rarity.COMMON, ItemData.Rarity.UNCOMMON]},
	{"kills": 200, "gold": 100, "rarities": [ItemData.Rarity.UNCOMMON]},
	{"kills": 500, "gold": 250, "rarities": [ItemData.Rarity.RARE]},
	{"kills": 1000, "gold": 500, "rarities": [ItemData.Rarity.RARE, ItemData.Rarity.EPIC]},
	{"kills": 2000, "gold": 1000, "rarities": [ItemData.Rarity.EPIC]},
	{"kills": 5000, "gold": 2500, "rarities": [ItemData.Rarity.EPIC, ItemData.Rarity.LEGENDARY]},
	{"kills": 10000, "gold": 5000, "rarities": [ItemData.Rarity.LEGENDARY]},
]
var _claimed_milestones: Array[int] = []

# Armory upgrade levels (0 = no upgrades, 100 = max)
var weapon_upgrade_level: int = 0
var armor_upgrade_level: int = 0

# Woodworking upgrade levels (0 = no upgrades)
var woodwork_bow_level: int = 0      # Reinforced Bow: +attack damage
var woodwork_shield_level: int = 0   # Wooden Bulwark: +armor, +HP
var woodwork_totem_level: int = 0    # Totem of Vigor: +regen, +stats
var woodwork_watchtower_level: int = 0  # Watchtower: building level

# Watchtower state (supports up to 4 towers)
var watchtower_built: bool = false
var watchtower_pos_x: float = 0.0
var watchtower_pos_y: float = 0.0
var watchtower_hp: int = 200
# Multi-tower: array of {built, pos_x, pos_y, hp, level} for towers 0-3
const MAX_WATCHTOWERS: int = 4
var watchtowers: Array[Dictionary] = []

func _init_watchtowers() -> void:
	watchtowers.clear()
	for i in range(MAX_WATCHTOWERS):
		watchtowers.append({"built": false, "pos_x": 0.0, "pos_y": 0.0, "hp": 200, "level": 0})

func get_watchtower_count() -> int:
	var count := 0
	for t in watchtowers:
		if t["built"]:
			count += 1
	return count

# Cost multiplier: each tower costs much more than the last
# Tower 1: base, Tower 2: 4x, Tower 3: 12x, Tower 4: 32x
const WATCHTOWER_COST_MULTIPLIERS: Array[int] = [1, 4, 12, 32]

func get_watchtower_slot_cost(base_cost: int) -> int:
	var count = get_watchtower_count()
	if count >= MAX_WATCHTOWERS:
		return 0
	return base_cost * WATCHTOWER_COST_MULTIPLIERS[count]

# Time played in the current region (persisted across save/load for wave timers)
var region_elapsed_time: float = 0.0

var _cached_is_mobile: int = -1  # -1 = not yet checked, 0 = false, 1 = true

func is_mobile_device() -> bool:
	if _cached_is_mobile >= 0:
		return _cached_is_mobile == 1
	# Primary check: Godot's built-in touchscreen detection
	if DisplayServer.is_touchscreen_available():
		_cached_is_mobile = 1
		return true
	# Fallback for web: JS checks for PWA/standalone mode
	if OS.has_feature("web"):
		# pointer:coarse = touch-primary device (won't false-positive on desktop touchscreen laptops)
		# user-agent regex = covers mobile browsers even if pointer query fails
		# iPad-as-Mac = iPadOS reports as MacIntel but has touch
		var js_result = JavaScriptBridge.eval(
			"(window.matchMedia('(pointer: coarse)').matches || /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile|Tablet/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1))",
			true
		)
		if js_result == true:
			_cached_is_mobile = 1
			return true
	_cached_is_mobile = 0
	return false

func get_upgrade_cost(current_level: int) -> int:
	return int(10 * pow(current_level + 1, 1.5))

func _ready() -> void:
	_init_watchtowers()
	_setup_custom_cursor()
	get_viewport().size_changed.connect(_setup_custom_cursor)

func _setup_custom_cursor() -> void:
	var is_mobile = is_mobile_device()
	# Scale cursor relative to viewport — ~2.5% of the shorter dimension
	# Desktop baseline: 24px at 960px height. Mobile gets 15% extra.
	var vp = get_viewport().get_visible_rect().size
	var short_side = min(vp.x, vp.y)
	var base_sz = max(20, int(short_side * 0.025))
	var sz = int(base_sz * 1.15) if is_mobile else base_sz
	var img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var gold = Color(0.94, 0.8, 0.28)
	var outline = Color(0.12, 0.1, 0.06)
	# Draw a simple arrow pointer: outline then fill
	# Arrow shape points: tip at (1,1), body goes down-right
	var arrow_outline: Array[Vector2i] = []
	var arrow_fill: Array[Vector2i] = []
	# Build arrow pixel rows (scaled to sz)
	var s = sz / 24.0  # scale factor
	# Outline pixels (border of the arrow)
	for row_data in [
		[0, [0]], [1, [0,1]], [2, [0,2]], [3, [0,3]], [4, [0,4]],
		[5, [0,5]], [6, [0,6]], [7, [0,7]], [8, [0,8]], [9, [0,9]],
		[10, [0,10]], [11, [0,11]], [12, [0,6,7,12]], [13, [0,7,8,13]],
		[14, [0,8,9,14]], [15, [0,9,10,15]], [16, [10,11,16]],
		[17, [11,12,17]], [18, [12,13,18]], [19, [13,14]], [20, [14]],
	]:
		var y = int(row_data[0] * s)
		for px in row_data[1]:
			var x = int(px * s)
			if x < sz and y < sz:
				arrow_outline.append(Vector2i(x, y))
	# Fill pixels (interior of the arrow)
	for row_data in [
		[1, [1]], [2, [1]], [3, [1,2]], [4, [1,2,3]], [5, [1,2,3,4]],
		[6, [1,2,3,4,5]], [7, [1,2,3,4,5,6]], [8, [1,2,3,4,5,6,7]],
		[9, [1,2,3,4,5,6,7,8]], [10, [1,2,3,4,5,6,7,8,9]],
		[11, [1,2,3,4,5,6,7,8,9,10]], [12, [1,2,3,4,5]],
		[13, [1,2,3,4,5,6]], [14, [1,2,3,4,5,6,7]],
		[15, [1,2,3,4,5,6,7,8]], [16, [11,12,13,14,15]],
		[17, [12,13,14,15,16]], [18, [13,14,15,16,17]],
		[19, [14,15,16,17,18]], [20, [15,16,17,18,19]],
	]:
		var y = int(row_data[0] * s)
		for px in row_data[1]:
			var x = int(px * s)
			if x < sz and y < sz:
				arrow_fill.append(Vector2i(x, y))
	for p in arrow_outline:
		img.set_pixelv(p, outline)
	for p in arrow_fill:
		img.set_pixelv(p, gold)
	var tex = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(0, 0))

func select_hero(hero_class: String) -> void:
	current_hero_class = hero_class
	hero_selected.emit(hero_class)

func add_gold(amount: int) -> void:
	gold += amount
	# Mirror to EconomyManager for multiplayer-readiness
	EconomyManager.add_gold(amount, 0)

func add_wood(amount: int) -> void:
	wood += amount

func spend_wood(amount: int) -> bool:
	if wood >= amount:
		wood -= amount
		return true
	return false

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		EconomyManager.set_gold(gold, 0)
		return true
	return false

func start_game() -> void:
	gold = 50  # Starting gold
	EconomyManager.set_gold(50, 0)
	# Initialize death counters for game start
	DeathCounterSystem.reset_all()
	DeathCounterSystem.set_value("gold_p0", 50)
	DeathCounterSystem.set_value("game_started", 1)
	game_started.emit()

func record_kill(enemy_name: String) -> void:
	total_kills += 1
	kills_changed.emit(total_kills)
	DeathCounterSystem.add_value("total_kills", 1)
	DeathCounterSystem.add_value("kills_%s" % enemy_name, 1)
	_check_kill_milestone()

func record_boss_kill(boss_id: String) -> void:
	if boss_id not in killed_bosses:
		killed_bosses.append(boss_id)
	DeathCounterSystem.set_flag("boss_killed_%s" % boss_id)

func record_artifact(artifact_id: String) -> void:
	if artifact_id not in found_artifacts:
		found_artifacts.append(artifact_id)
	DeathCounterSystem.set_flag("artifact_%s" % artifact_id)

func _check_kill_milestone() -> void:
	for milestone in KILL_MILESTONES:
		var threshold: int = milestone["kills"]
		if total_kills >= threshold and threshold not in _claimed_milestones:
			_claimed_milestones.append(threshold)
			# Grant gold
			var gold_reward: int = milestone["gold"]
			add_gold(gold_reward)
			# Pick a random equipment item matching the milestone rarities
			var rarities: Array = milestone["rarities"]
			var candidates: Array[String] = []
			for item_id in ItemData.ITEMS:
				var item = ItemData.ITEMS[item_id]
				if item.get("slot", -1) == ItemData.Slot.CONSUMABLE:
					continue
				if item.get("rarity", -1) in rarities:
					candidates.append(item_id)
			if candidates.size() > 0:
				var chosen_id = candidates[randi() % candidates.size()]
				var item = ItemData.get_item(chosen_id)
				ItemData._roll_affixes(item)
				_spawn_milestone_drop(item)
			# Celebration message
			var rarity_name = ItemData.RARITY_NAMES.get(rarities[rarities.size() - 1], "")
			game_message.emit(
				"%d Kills! +%dg + %s gear drop!" % [threshold, gold_reward, rarity_name],
				Color(1.0, 0.85, 0.2)
			)

func _spawn_milestone_drop(item: Dictionary) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	# Build a ground drop Area2D
	var drop = Area2D.new()
	drop.collision_layer = 32
	drop.collision_mask = 0
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape_node.shape = circle
	drop.add_child(shape_node)
	var visual = Sprite2D.new()
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.name = "Visual"
	drop.add_child(visual)

	drop.position = player.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	drop.add_to_group("ground_items")
	drop.set_meta("item_data", item)

	visual.texture = SpriteGenerator.get_texture("crystal_teal")
	var rarity = item.get("rarity", 0)
	visual.modulate = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)

	# Add to world
	var world_nodes = get_tree().get_nodes_in_group("world")
	var world: Node = world_nodes[0] if world_nodes.size() > 0 else get_tree().current_scene
	world.add_child(drop)

	var float_tween = drop.create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	# Announce the drop
	var rarity_name = ItemData.RARITY_NAMES.get(rarity, "")
	if rarity >= ItemData.Rarity.RARE:
		var color = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)
		game_message.emit("%s %s dropped!" % [rarity_name, item.get("name", "Item")], color)
