extends "res://revamp/player/abilities/ability_base.gd"


func _init() -> void:
	cooldown = 1.0
	label = "Healing Draught"
	key_hint = "Q"
	ability_id = &"potion"
	icon_color = Color(0.95, 0.30, 0.35)


func can_use() -> bool:
	if not super.can_use():
		return false
	return int(owner_player.get("potions")) > 0


func use(_aim: Vector2) -> void:
	if not can_use():
		return
	if owner_player.consume_potion():
		_start_cooldown()
