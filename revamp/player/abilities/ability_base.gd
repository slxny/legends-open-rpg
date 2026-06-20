extends Node
class_name RevampAbility

## Base ability: handles cooldown bookkeeping and exposes a uniform interface
## (can_use, use, get_cooldown_state) for the HUD + player to drive.

var owner_player: Node
var cooldown: float = 0.5
var charge_cost: int = 0
var requires_charges: int = 0
var icon_color: Color = Color(0.85, 0.85, 1.0)
var label: String = "Ability"
var key_hint: String = ""
var ability_id: StringName = &"ability"

var _ready_at: float = 0.0


func can_use() -> bool:
	if not is_instance_valid(owner_player):
		return false
	var now_s: float = Time.get_ticks_msec() * 0.001
	if now_s < _ready_at:
		return false
	if requires_charges > 0 and int(owner_player.get("charges")) < requires_charges:
		return false
	return true


func use(_aim: Vector2) -> void:
	# Override in subclasses.
	_start_cooldown()


func _start_cooldown(custom: float = -1.0) -> void:
	var cd: float = cooldown if custom < 0 else custom
	_ready_at = Time.get_ticks_msec() * 0.001 + cd


func get_cooldown_state(now_s: float) -> Dictionary:
	var remaining: float = maxf(0.0, _ready_at - now_s)
	return {
		"label": label,
		"key_hint": key_hint,
		"id": ability_id,
		"color": icon_color,
		"cooldown_remaining": remaining,
		"cooldown_total": cooldown,
		"ready": remaining <= 0.001,
		"requires_charges": requires_charges,
		"charge_cost": charge_cost,
		"charges_available": int(owner_player.get("charges")) if is_instance_valid(owner_player) else 0,
	}


# Helpers for subclasses
func _world_root() -> Node:
	if owner_player and owner_player.get_parent():
		return owner_player.get_parent()
	return get_tree().current_scene


func _enemies_in_radius(at: Vector2, r: float) -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for e in tree.get_nodes_in_group("revamp_enemies"):
		if e is Node2D and is_instance_valid(e):
			if e.global_position.distance_to(at) <= r:
				out.append(e)
	return out
