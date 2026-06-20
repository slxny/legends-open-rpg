extends "res://revamp/player/abilities/ability_base.gd"

const LightningStrike := preload("res://revamp/effects/effect_lightning_strike.gd")


func _init() -> void:
	cooldown = 0.55
	label = "Storm Burst"
	key_hint = "RMB"
	ability_id = &"burst"
	icon_color = Color(0.75, 0.55, 1.0)
	requires_charges = 1


func use(aim: Vector2) -> void:
	if not can_use():
		return
	# Aim at cursor world position (skipped in scripted demo mode).
	var vp := owner_player.get_viewport()
	var target_pos: Vector2 = owner_player.global_position + aim * 220.0
	if vp and not bool(owner_player.get("scripted")):
		var xf := vp.get_canvas_transform().affine_inverse()
		target_pos = xf * vp.get_mouse_position()
	var spent: int = owner_player.spend_all_charges()
	var bonus_wave: bool = bool(owner_player.get_build_mod(&"burst", "extra_wave", false))
	_spawn_strikes(target_pos, spent + (3 if bonus_wave else 0))
	if bonus_wave:
		# Follow-up ring around player
		var center: Vector2 = owner_player.global_position
		for i in range(6):
			var a: float = float(i) / 6.0 * TAU
			_strike(center + Vector2(cos(a), sin(a)) * 120.0, 0.35 + i * 0.06)
	_start_cooldown()


func _spawn_strikes(center: Vector2, n: int) -> void:
	for i in range(max(1, n)):
		var jitter := Vector2(randf_range(-90, 90), randf_range(-60, 60))
		_strike(center + jitter, i * 0.07)


func _strike(at: Vector2, delay: float) -> void:
	var s := LightningStrike.new()
	s.global_position = at
	s.delay = delay
	s.damage = 70.0
	s.radius = 70.0
	s.shooter = owner_player
	_world_root().add_child(s)
