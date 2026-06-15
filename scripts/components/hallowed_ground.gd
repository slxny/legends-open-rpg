extends Node2D
class_name HallowedGround

## Phase 3.x — temporary heal zone spawned at the centroid of a cluster
## of recent kills. Heals the player slowly while they stand inside.
## Fades after LIFETIME_SEC.

const LIFETIME_SEC: float = 8.0
const HEAL_RADIUS_SQ: float = 95.0 * 95.0
const HEAL_PER_SEC: float = 4.0  # ~4 HP/sec while standing inside

var _spawn_msec: int = 0
var _heal_accum: float = 0.0
var _aura: Sprite2D = null
var _aura_tween: Tween = null


func _ready() -> void:
	add_to_group("hallowed_grounds")
	_spawn_msec = Time.get_ticks_msec()

	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	_aura = Sprite2D.new()
	_aura.texture = tex
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura.modulate = Color(1.5, 1.3, 0.4, 0.65)
	_aura.scale = Vector2(7.5, 7.5)
	_aura.z_index = -2
	add_child(_aura)
	# Pulse loop.
	_aura_tween = _aura.create_tween().set_loops()
	_aura_tween.tween_property(_aura, "scale", Vector2(8.5, 8.5), 0.6).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(_aura, "scale", Vector2(7.5, 7.5), 0.6).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	# Heal player if inside.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0]
		if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= HEAL_RADIUS_SQ:
			_heal_accum += delta * HEAL_PER_SEC
			while _heal_accum >= 1.0:
				_heal_accum -= 1.0
				if "stats" in player and "current_hp" in player.stats and "max_hp" in player.stats:
					if int(player.stats.current_hp) < int(player.stats.max_hp):
						player.stats.current_hp = min(int(player.stats.max_hp), int(player.stats.current_hp) + 1)
	# Expire after LIFETIME_SEC.
	var age_sec: float = float(Time.get_ticks_msec() - _spawn_msec) / 1000.0
	if age_sec >= LIFETIME_SEC:
		_expire()
		return
	# Fade tail (last 1.5s).
	if age_sec > LIFETIME_SEC - 1.5:
		var fade: float = clamp((LIFETIME_SEC - age_sec) / 1.5, 0.0, 1.0)
		if _aura != null:
			_aura.modulate.a = 0.65 * fade


func _expire() -> void:
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	queue_free()
