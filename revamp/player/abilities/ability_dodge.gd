extends "res://revamp/player/abilities/ability_base.gd"


func _init() -> void:
	cooldown = 0.85
	label = "Dodge"
	key_hint = "SPACE"
	ability_id = &"dodge"
	icon_color = Color(0.95, 0.95, 0.95)


func use(_aim: Vector2) -> void:
	if not can_use():
		return
	_start_cooldown()
