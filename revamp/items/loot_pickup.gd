extends Area2D

## A visible-on-ground loot drop with a vertical beam of light and bobbing
## crystal. Hovers info on proximity. Auto-equips on touch + announces it.

signal picked_up(item: Resource)

@export var item: Resource

const PICKUP_RADIUS := 60.0

var _crystal: Polygon2D
var _beam: Polygon2D
var _label: Label
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1 << 5  # pickups
	collision_mask = 1        # player
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = PICKUP_RADIUS
	shape.shape = circ
	add_child(shape)
	body_entered.connect(_on_body)
	# Visual beam
	var col: Color = item.rarity_color() if item != null else Color.WHITE
	_beam = Polygon2D.new()
	_beam.color = Color(col.r, col.g, col.b, 0.5)
	_beam.polygon = PackedVector2Array([
		Vector2(-22, -16), Vector2(22, -16), Vector2(40, -480), Vector2(-40, -480),
	])
	_beam.z_index = -1
	add_child(_beam)
	# Beam shader for soft fade
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;
		uniform vec4 col : source_color;
		void fragment() {
			float fade = smoothstep(0.0, 1.0, UV.y);
			float w = abs(UV.x - 0.5) * 2.0;
			float wfade = smoothstep(1.0, 0.0, w);
			COLOR = vec4(col.rgb, col.a * fade * wfade);
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("col", col)
	_beam.material = mat
	# Crystal
	_crystal = Polygon2D.new()
	_crystal.color = col
	_crystal.polygon = PackedVector2Array([
		Vector2(0, -40), Vector2(14, -22), Vector2(10, -8),
		Vector2(-10, -8), Vector2(-14, -22),
	])
	add_child(_crystal)
	# Halo
	var halo := Polygon2D.new()
	halo.color = Color(col.r, col.g, col.b, 0.45)
	halo.polygon = _circle(Vector2(0, -22), 30.0, 24)
	halo.z_index = -1
	add_child(halo)
	# Label
	_label = Label.new()
	_label.text = "" if item == null else item.display_name
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", col)
	_label.position = Vector2(-60, -88)
	_label.size = Vector2(120, 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.rotation = sin(_t * 0.7) * 0.10
		_crystal.position.y = sin(_t * 1.4) * 4.0
	if _beam:
		_beam.scale = Vector2(1.0 + sin(_t * 1.6) * 0.05, 1.0)


func _on_body(body: Node) -> void:
	if body.is_in_group("revamp_player") and item != null:
		picked_up.emit(item)
		_apply_to_player(body)
		_announce(body)
		queue_free()


func _apply_to_player(body: Node) -> void:
	# Tell the slice's HUD to surface comparison + tell player to equip.
	var slice: Node = get_tree().current_scene
	if slice and slice.has_node("RevampHUD"):
		var hud: Node = slice.get_node("RevampHUD")
		if hud.has_method("show_pickup"):
			hud.show_pickup(item)
	if body.has_method("equip_item_by_id"):
		body.equip_item_by_id(item.id)


func _announce(_body: Node) -> void:
	pass


func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var arr: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var a: float = float(i) / float(n) * TAU
		arr.append(c + Vector2(cos(a) * r, sin(a) * r))
	return arr
