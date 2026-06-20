extends "res://revamp/player/abilities/ability_base.gd"

const CrystalWardVisual := preload("res://revamp/effects/effect_crystal_ward.gd")

const DURATION := 2.0


func _init() -> void:
	cooldown = 8.0
	label = "Crystal Ward"
	key_hint = "2"
	ability_id = &"ward"
	icon_color = Color(0.45, 0.85, 1.0)


func use(_aim: Vector2) -> void:
	if not can_use():
		return
	var now: int = Time.get_ticks_msec()
	var duration: float = DURATION
	owner_player.set_meta("ward_until_ms", now + int(duration * 1000.0))
	owner_player.set_meta("ward_stored", 0.0)
	var w := CrystalWardVisual.new()
	w.host = owner_player
	w.duration = duration
	owner_player.add_child(w)
	# Schedule explosion-on-expiry
	get_tree().create_timer(duration).timeout.connect(_release.bind(owner_player))
	_start_cooldown()


func _release(host: Node) -> void:
	if not is_instance_valid(host):
		return
	var stored: float = float(host.get_meta("ward_stored", 0.0))
	if stored <= 0.0:
		return
	# Shockwave that returns 1.5x stored damage in 180px radius
	for enemy in _enemies_in_radius(host.global_position, 220.0):
		owner_player.resolve_damage(enemy, &"arcane", &"ward_burst", stored * 1.5, 1.0)
	host.set_meta("ward_stored", 0.0)
