extends "res://revamp/player/abilities/ability_base.gd"

const ArcaneBoltProjectile := preload("res://revamp/effects/projectile_arcane_bolt.gd")


func _init() -> void:
	cooldown = 0.32
	label = "Arcane Bolt"
	key_hint = "LMB"
	ability_id = &"bolt"
	icon_color = Color(0.55, 0.90, 1.0)


func use(aim: Vector2) -> void:
	if not can_use():
		return
	var spawn_pos: Vector2 = owner_player.global_position + aim * 28.0
	var pierce: int = int(owner_player.get_build_mod(&"bolt", "pierce", 0))
	var twin: bool = bool(owner_player.get_build_mod(&"bolt", "twin", false))
	_spawn_projectile(spawn_pos, aim, pierce)
	if twin:
		_spawn_projectile(spawn_pos, aim.rotated(0.18), pierce)
		_spawn_projectile(spawn_pos, aim.rotated(-0.18), pierce)
	_start_cooldown()


func _spawn_projectile(at: Vector2, dir: Vector2, pierce: int) -> void:
	var proj := ArcaneBoltProjectile.new()
	proj.global_position = at
	proj.set_aim(dir)
	proj.shooter = owner_player
	proj.damage = 26.0
	proj.pierce_max = pierce
	_world_root().add_child(proj)
