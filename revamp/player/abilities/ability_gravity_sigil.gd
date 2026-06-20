extends "res://revamp/player/abilities/ability_base.gd"

const GravitySigilEffect := preload("res://revamp/effects/effect_gravity_sigil.gd")


func _init() -> void:
	cooldown = 9.0
	label = "Gravity Sigil"
	key_hint = "3"
	ability_id = &"sigil"
	icon_color = Color(0.95, 0.55, 0.95)


func use(aim: Vector2) -> void:
	if not can_use():
		return
	var vp := owner_player.get_viewport()
	var target_pos: Vector2 = owner_player.global_position + aim * 260.0
	if vp and not bool(owner_player.get("scripted")):
		var xf := vp.get_canvas_transform().affine_inverse()
		target_pos = xf * vp.get_mouse_position()
	var sigil := GravitySigilEffect.new()
	sigil.global_position = target_pos
	sigil.shooter = owner_player
	sigil.radius = 200.0
	sigil.pull_strength = 380.0
	sigil.duration = 1.8
	sigil.implode_damage = 95.0
	_world_root().add_child(sigil)
	_start_cooldown()
