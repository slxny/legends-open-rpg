extends "res://revamp/player/abilities/ability_base.gd"

const TempestEffect := preload("res://revamp/effects/effect_tempest.gd")


func _init() -> void:
	cooldown = 18.0
	label = "Tempest"
	key_hint = "4"
	ability_id = &"tempest"
	icon_color = Color(1.0, 0.85, 0.30)


func use(aim: Vector2) -> void:
	if not can_use():
		return
	var vp := owner_player.get_viewport()
	var target_pos: Vector2 = owner_player.global_position + aim * 320.0
	if vp and not bool(owner_player.get("scripted")):
		var xf := vp.get_canvas_transform().affine_inverse()
		target_pos = xf * vp.get_mouse_position()
	var t := TempestEffect.new()
	t.global_position = target_pos
	t.shooter = owner_player
	t.radius = 280.0
	t.duration = 4.0
	t.tick_damage = 22.0
	_world_root().add_child(t)
	_start_cooldown()
