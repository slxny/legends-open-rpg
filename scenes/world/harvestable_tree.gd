extends StaticBody2D

## Harvestable tree that can be chopped by clicking or spacebar attacks.
## Drops wood logs on death. Three sizes with varied yields (correlated by size).
## Hover to see outline; right-click to inspect wood amount.

signal chopped_down(tree: Node2D)

enum TreeSize { SMALL, MEDIUM, LARGE }

var tree_size: TreeSize = TreeSize.MEDIUM
var max_hp: int = 6
var current_hp: int = 6
var wood_yield: int = 30

var _is_chopped: bool = false
var _sprite: Sprite2D = null
var _hp_bar: SCBar = null
var _shadow: Sprite2D = null
var _info_label: Label = null

# Pre-allocated label settings (shared across all trees)
static var _dmg_label: LabelSettings = null
static var _outline_shader: Shader = null
static var _info_label_settings: LabelSettings = null

func _init() -> void:
	if not _dmg_label:
		_dmg_label = LabelSettings.new()
		_dmg_label.font_size = 12
		_dmg_label.font_color = Color(0.65, 0.45, 0.2)
		_dmg_label.outline_size = 2
		_dmg_label.outline_color = Color.BLACK
	if not _outline_shader:
		_outline_shader = Shader.new()
		_outline_shader.code = "shader_type canvas_item;
uniform bool enabled = false;
uniform vec4 line_color : source_color = vec4(0.3, 1.0, 0.4, 0.85);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (enabled && tex.a < 0.1) {
		vec2 ps = TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		a += texture(TEXTURE, UV + vec2(ps.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(0.0, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
		a += texture(TEXTURE, UV + vec2(ps.x, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a;
		a += texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a;
		a += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a;
		if (a > 0.0) {
			COLOR = line_color;
		} else {
			COLOR = tex;
		}
	} else {
		COLOR = tex;
	}
}
"
	if not _info_label_settings:
		_info_label_settings = LabelSettings.new()
		_info_label_settings.font_size = 11
		_info_label_settings.font_color = Color(0.9, 0.75, 0.4)
		_info_label_settings.outline_size = 2
		_info_label_settings.outline_color = Color.BLACK

func setup(size: TreeSize) -> void:
	tree_size = size
	match size:
		TreeSize.SMALL:
			max_hp = 3
			wood_yield = randi_range(12, 18)   # ~15 avg (5x of old 3)
		TreeSize.MEDIUM:
			max_hp = 6
			wood_yield = randi_range(24, 36)   # ~30 avg (5x of old 6)
		TreeSize.LARGE:
			max_hp = 12
			wood_yield = randi_range(48, 72)   # ~60 avg (5x of old 12)
	current_hp = max_hp

func _ready() -> void:
	add_to_group("harvestable_trees")
	collision_layer = 4  # Environment layer
	collision_mask = 0
	input_pickable = true  # Enable mouse hover/click detection

	# Collision shape based on tree size
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	match tree_size:
		TreeSize.SMALL:
			shape.radius = 8.0
		TreeSize.MEDIUM:
			shape.radius = 12.0
		TreeSize.LARGE:
			shape.radius = 16.0
	col.shape = shape
	add_child(col)

	# Sprite
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match tree_size:
		TreeSize.SMALL:
			_sprite.texture = SpriteGenerator.get_texture("tree_harvest_small")
			_sprite.offset = Vector2(0, -14)
		TreeSize.MEDIUM:
			_sprite.texture = SpriteGenerator.get_texture("tree_harvest_medium")
			_sprite.offset = Vector2(0, -22)
		TreeSize.LARGE:
			_sprite.texture = SpriteGenerator.get_texture("tree_harvest_large")
			_sprite.offset = Vector2(0, -30)
	# Slight random tint variation
	var v = randf_range(-0.04, 0.04)
	_sprite.modulate = Color(1.0 + v, 1.0 + v * 0.5, 1.0 + v)

	# Outline shader material
	var mat = ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("enabled", false)
	mat.set_shader_parameter("line_color", Color(0.3, 1.0, 0.4, 0.85))
	_sprite.material = mat

	add_child(_sprite)

	# Shadow
	_shadow = Sprite2D.new()
	_shadow.texture = SpriteGenerator.get_texture("iso_shadow")
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	add_child(_shadow)

	# HP bar (hidden until hit)
	_hp_bar = SCBar.new()
	_hp_bar.bar_mode = 0
	_hp_bar.show_label = false
	_hp_bar.custom_minimum_size = Vector2(30, 4)
	_hp_bar.size = Vector2(30, 4)
	match tree_size:
		TreeSize.SMALL:
			_hp_bar.position = Vector2(-15, -30)
		TreeSize.MEDIUM:
			_hp_bar.position = Vector2(-15, -44)
		TreeSize.LARGE:
			_hp_bar.position = Vector2(-15, -58)
	_hp_bar.visible = false
	add_child(_hp_bar)

	_hp_bar.set_value(current_hp, max_hp)

	# Connect mouse hover signals for outline
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if not _is_chopped and _sprite and _sprite.material:
		_sprite.material.set_shader_parameter("enabled", true)

func _on_mouse_exited() -> void:
	if _sprite and _sprite.material:
		_sprite.material.set_shader_parameter("enabled", false)

func show_wood_info() -> void:
	if _is_chopped:
		return
	# Remove existing info label if any
	if _info_label and is_instance_valid(_info_label):
		_info_label.queue_free()
	_info_label = Label.new()
	var size_name := ""
	match tree_size:
		TreeSize.SMALL: size_name = "Small"
		TreeSize.MEDIUM: size_name = "Medium"
		TreeSize.LARGE: size_name = "Large"
	_info_label.text = "%s Tree — %d Wood" % [size_name, wood_yield]
	_info_label.label_settings = _info_label_settings
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match tree_size:
		TreeSize.SMALL:
			_info_label.position = Vector2(-45, -48)
		TreeSize.MEDIUM:
			_info_label.position = Vector2(-45, -62)
		TreeSize.LARGE:
			_info_label.position = Vector2(-45, -76)
	add_child(_info_label)
	# Fade out after a moment
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_info_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if _info_label and is_instance_valid(_info_label):
			_info_label.queue_free()
			_info_label = null
	)

func take_damage(amount: int, _is_crit: bool = false) -> void:
	if _is_chopped:
		return
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0
	_hp_bar.set_value(current_hp, max_hp)
	_hp_bar.visible = true
	_spawn_damage_number(amount)
	_do_hit_shake()
	AudioManager.play_sfx("tree_chop", -2.0)

	if current_hp <= 0:
		_chop_down()

func _chop_down() -> void:
	_is_chopped = true
	collision_layer = 0
	input_pickable = false
	_hp_bar.visible = false
	# Disable outline
	if _sprite and _sprite.material:
		_sprite.material.set_shader_parameter("enabled", false)
	chopped_down.emit(self)

	# Spawn wood drops
	_spawn_wood_drops()

	AudioManager.play_sfx("tree_fall")

	# Fall animation: tilt and fade
	if _shadow:
		_shadow.visible = false
	var tween = create_tween()
	# Brief upward pop
	tween.tween_property(_sprite, "position", _sprite.position + Vector2(0, -4), 0.06)
	tween.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.06)
	# Fall over
	tween.set_parallel(true)
	tween.tween_property(_sprite, "rotation", deg_to_rad(75), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(_sprite, "position", _sprite.position + Vector2(12, 6), 0.35)
	tween.set_parallel(false)
	# Replace with stump
	tween.tween_callback(_replace_with_stump)

func _replace_with_stump() -> void:
	# Remove tree sprite, show a stump in its place
	if _sprite:
		_sprite.queue_free()
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteGenerator.get_texture("tree_stump")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate.a = 0.7
	add_child(_sprite)
	# Fade stump after a while
	var fade = create_tween()
	fade.tween_interval(10.0)
	fade.tween_property(_sprite, "modulate:a", 0.0, 3.0)
	fade.tween_callback(queue_free)

func _spawn_wood_drops() -> void:
	var world = _get_world_node()
	# Drop 1-3 wood bundles depending on size, total = wood_yield
	var bundles: int
	var per_bundle: int
	match tree_size:
		TreeSize.SMALL:
			bundles = 1
			per_bundle = wood_yield
		TreeSize.MEDIUM:
			bundles = 2
			per_bundle = wood_yield / 2
		TreeSize.LARGE:
			bundles = 3
			per_bundle = wood_yield / 3

	for i in range(bundles):
		var drop = Area2D.new()
		drop.position = global_position + Vector2(randf_range(-14, 14), randf_range(-8, 8))
		drop.collision_layer = 32  # Pickups layer
		drop.collision_mask = 0
		drop.add_to_group("ground_items")
		drop.set_meta("item_data", {"id": "_wood", "name": "%d Wood" % per_bundle, "wood_amount": per_bundle})

		var shape_node = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 10.0
		shape_node.shape = circle
		drop.add_child(shape_node)

		var visual = Sprite2D.new()
		visual.texture = SpriteGenerator.get_texture("wood_log")
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var s = randf_range(1.2, 1.6)
		visual.scale = Vector2(s, s)
		drop.add_child(visual)

		# Floating bob animation
		var float_tween = drop.create_tween().set_loops()
		float_tween.tween_property(visual, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
		float_tween.tween_property(visual, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

		world.add_child(drop)

	GameManager.game_message.emit("Tree chopped! +%d Wood" % wood_yield, Color(0.65, 0.45, 0.2))

func _spawn_damage_number(amount: int) -> void:
	var label = Label.new()
	label.text = str(amount)
	label.position = Vector2(randf_range(-8, 8), -35)
	label.label_settings = _dmg_label
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 20, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _do_hit_shake() -> void:
	# Quick shake + flash white
	_sprite.modulate = Color(1.5, 1.5, 1.5)
	var base_pos = _sprite.position
	var tween = create_tween()
	tween.tween_property(_sprite, "position", base_pos + Vector2(-2, 0), 0.03)
	tween.tween_property(_sprite, "position", base_pos + Vector2(2, 0), 0.03)
	tween.tween_property(_sprite, "position", base_pos + Vector2(-1, 0), 0.03)
	tween.tween_property(_sprite, "position", base_pos, 0.03)
	tween.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.12)

func _get_world_node() -> Node:
	var world = get_tree().get_nodes_in_group("world")
	if world.size() > 0:
		return world[0]
	return get_tree().current_scene
