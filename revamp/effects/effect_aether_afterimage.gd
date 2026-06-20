extends Node2D

## Ghost-mage afterimage left behind by Aether Step. Optionally deals damage
## when the build mod is active.

@export var delay: float = 0.0
@export var modulate_color: Color = Color(0.55, 0.95, 0.95, 0.7)
@export var deals_damage: bool = false
@export var damage_radius: float = 80.0
@export var damage: float = 18.0

var shooter: Node
var _vis: Polygon2D
var _t: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	_vis = Polygon2D.new()
	_vis.color = modulate_color
	_vis.polygon = PackedVector2Array([
		Vector2(-14, -28), Vector2(14, -28), Vector2(18, -10),
		Vector2(14, 22), Vector2(-14, 22), Vector2(-18, -10),
	])
	_vis.modulate.a = 0.0
	add_child(_vis)


func _process(delta: float) -> void:
	_t += delta
	if not _triggered and _t >= delay:
		_triggered = true
		var tw := create_tween()
		tw.tween_property(_vis, "modulate:a", 1.0, 0.05)
		tw.tween_property(_vis, "modulate:a", 0.0, 0.45)
		tw.tween_callback(queue_free)
		if deals_damage and shooter and shooter.has_method("resolve_damage"):
			var tree := get_tree()
			if tree:
				for e in tree.get_nodes_in_group("revamp_enemies"):
					if e is Node2D and is_instance_valid(e):
						if e.global_position.distance_to(global_position) <= damage_radius:
							shooter.resolve_damage(e, &"arcane", &"aether_trail", damage, 1.0)
