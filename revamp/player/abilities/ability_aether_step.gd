extends "res://revamp/player/abilities/ability_base.gd"

const AetherAfterimage := preload("res://revamp/effects/effect_aether_afterimage.gd")

const DASH_DISTANCE := 280.0
const DAMAGE := 35.0


func _init() -> void:
	cooldown = 4.0
	label = "Aether Step"
	key_hint = "1"
	ability_id = &"step"
	icon_color = Color(0.55, 0.95, 0.95)


func use(aim: Vector2) -> void:
	if not can_use():
		return
	var start_pos: Vector2 = owner_player.global_position
	var trail_damage: bool = bool(owner_player.get_build_mod(&"step", "damaging_trail", false))
	var distance: float = DASH_DISTANCE * float(owner_player.get_build_mod(&"step", "distance_mult", 1.0))
	var end_pos: Vector2 = start_pos + aim.normalized() * distance
	owner_player.global_position = end_pos
	owner_player.velocity = aim.normalized() * 100.0
	# Damage at start AND end positions
	for target in _enemies_in_radius(start_pos, 90.0):
		owner_player.resolve_damage(target, &"arcane", ability_id, DAMAGE, 1.0)
	for target in _enemies_in_radius(end_pos, 90.0):
		owner_player.resolve_damage(target, &"arcane", ability_id, DAMAGE * 1.3, 1.0)
	# Visual: a streak of afterimages along the line
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector2 = start_pos.lerp(end_pos, t)
		var ai := AetherAfterimage.new()
		ai.global_position = pos
		ai.delay = i * 0.025
		ai.modulate_color = Color(0.55, 0.95, 0.95, 0.7 * (1.0 - t * 0.5))
		ai.deals_damage = trail_damage
		ai.damage_radius = 80.0
		ai.damage = DAMAGE * 0.4
		ai.shooter = owner_player
		_world_root().add_child(ai)
	_start_cooldown()
