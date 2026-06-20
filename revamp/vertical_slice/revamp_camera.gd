extends Camera2D

## Smooth-follow camera with hit impulse + lookahead toward aim direction.

@export var target: Node2D
@export var follow_speed: float = 6.5
@export var lookahead: float = 80.0
@export var zoom_base: float = 1.95
@export var zoom_boss: float = 1.70

var _impulse: Vector2 = Vector2.ZERO
var _zoom_target: float = 2.6
var _shake_amp: float = 0.0
var _shake_t: float = 0.0


func _ready() -> void:
	zoom = Vector2(zoom_base, zoom_base)
	_zoom_target = zoom_base
	position_smoothing_enabled = false  # we drive it manually
	make_current()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var aim_dir: Vector2 = Vector2.ZERO
	if target.has_method("get_aim_dir"):
		aim_dir = target.get_aim_dir()
	var goal: Vector2 = target.global_position + aim_dir * lookahead
	global_position = global_position.lerp(goal, clampf(delta * follow_speed, 0.0, 1.0))
	# Impulse decay
	_impulse = _impulse.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	# Shake
	if _shake_amp > 0.01:
		_shake_t += delta
		var sx: float = sin(_shake_t * 53.0) * _shake_amp
		var sy: float = cos(_shake_t * 47.0) * _shake_amp
		offset = Vector2(sx, sy) + _impulse
		_shake_amp = maxf(0.0, _shake_amp - delta * 95.0)
	else:
		offset = _impulse
	# Zoom lerp
	var z: float = lerpf(zoom.x, _zoom_target, clampf(delta * 3.0, 0.0, 1.0))
	zoom = Vector2(z, z)


func punch(direction: Vector2, strength: float) -> void:
	_impulse += direction.normalized() * strength


func shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp, amount)


func enter_boss_mode() -> void:
	_zoom_target = zoom_boss
