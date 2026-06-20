extends Node

## Scripted demo: drives the player from spawn to boss, fires abilities,
## picks up loot. Enabled with `--revamp-demo`. Used by MCP / screenshot runs.

# Hold positions roughly in line with the encounter anchors so the demo doesn't
# run past combat. `until_x` (optional) clamps forward motion so the player
# parks at the encounter and fights in place.
const SCRIPT := [
	{"t": 0.2,  "act": "move", "dx": 1.0, "dy": 0.0, "dur": 7.0, "until_x": -1100.0},
	{"t": 0.6,  "act": "bolt", "every": 0.42, "until": 7.0},
	{"t": 6.8,  "act": "burst"},
	{"t": 7.5,  "act": "move", "dx": 1.0, "dy": -0.05, "dur": 7.0, "until_x": -300.0},
	{"t": 7.8,  "act": "bolt", "every": 0.4, "until": 13.0},
	{"t": 9.5,  "act": "step"},
	{"t": 11.5, "act": "burst"},
	{"t": 13.5, "act": "move", "dx": 1.0, "dy": 0.05, "dur": 7.0, "until_x": 600.0},
	{"t": 13.8, "act": "bolt", "every": 0.4, "until": 19.0},
	{"t": 14.5, "act": "burst"},
	{"t": 17.0, "act": "burst"},
	{"t": 19.0, "act": "move", "dx": 1.0, "dy": 0.0, "dur": 7.0, "until_x": 1400.0},
	{"t": 19.3, "act": "bolt", "every": 0.4, "until": 26.0},
	{"t": 20.0, "act": "ward"},
	{"t": 21.0, "act": "sigil"},
	{"t": 23.0, "act": "burst"},
	{"t": 25.0, "act": "burst"},
	{"t": 26.0, "act": "move", "dx": 1.0, "dy": 0.0, "dur": 6.0, "until_x": 2050.0},
	{"t": 26.5, "act": "bolt", "every": 0.4, "until": 33.0},
	{"t": 27.5, "act": "sigil"},
	{"t": 29.0, "act": "tempest"},
	{"t": 30.5, "act": "burst"},
	{"t": 31.5, "act": "ward"},
	{"t": 32.5, "act": "burst"},
	# Approach boss
	{"t": 33.0, "act": "move", "dx": 1.0, "dy": 0.0, "dur": 4.0, "until_x": 2650.0},
	{"t": 33.5, "act": "bolt", "every": 0.35, "until": 60.0},
	{"t": 35.0, "act": "tempest"},
	{"t": 36.0, "act": "ward"},
	{"t": 37.5, "act": "burst"},
	{"t": 38.5, "act": "dodge"},
	{"t": 39.5, "act": "sigil"},
	{"t": 41.0, "act": "burst"},
	{"t": 42.0, "act": "potion"},
	{"t": 43.0, "act": "tempest"},
	{"t": 44.0, "act": "ward"},
	{"t": 45.5, "act": "burst"},
	{"t": 47.0, "act": "burst"},
	{"t": 48.5, "act": "sigil"},
	{"t": 50.0, "act": "tempest"},
	{"t": 52.0, "act": "burst"},
	{"t": 53.5, "act": "potion"},
	{"t": 55.0, "act": "burst"},
	{"t": 56.5, "act": "tempest"},
	{"t": 58.0, "act": "burst"},
]

var slice: Node
var player: Node
var director: Node
var hud: Node

var _running: bool = false
var _t: float = 0.0
var _done_idx: Dictionary = {}
var _move_dir: Vector2 = Vector2.ZERO
var _move_until: float = 0.0
var _move_until_x: float = INF
var _ability_bolt_until: float = 0.0
var _ability_bolt_every: float = 0.4
var _ability_bolt_next: float = 0.0


func bind(s: Node, p: Node, d: Node, h: Node) -> void:
	slice = s
	player = p
	director = d
	hud = h


func start() -> void:
	if not is_instance_valid(player):
		return
	_running = true
	set_process(true)
	# Engage scripted-input mode on the player.
	if "scripted" in player:
		player.scripted = true
	player.aim_dir = Vector2.RIGHT


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	for i in range(SCRIPT.size()):
		if _done_idx.has(i):
			continue
		var entry: Dictionary = SCRIPT[i]
		if float(entry["t"]) <= _t:
			_done_idx[i] = true
			_apply(entry)
	# Sustained move: drive scripted_move_vec each frame. Stops once the
	# player passes the target x.
	var moving: bool = _t < _move_until and _move_dir.length_squared() > 0.01
	if moving and player.global_position.x >= _move_until_x:
		moving = false
	if "scripted_move_vec" in player:
		if moving:
			player.scripted_move_vec = _move_dir.normalized()
			player.aim_dir = _move_dir.normalized()
		else:
			player.scripted_move_vec = Vector2.ZERO
	# At the boss arena, aim at the boss instead of straight east.
	if player.global_position.x >= 2500.0:
		var boss_pos := Vector2(2800.0, -80.0)
		var dir: Vector2 = (boss_pos - player.global_position).normalized()
		if dir.length_squared() > 0.04:
			player.aim_dir = dir
	# Sustained bolt
	if _t < _ability_bolt_until and _t >= _ability_bolt_next:
		_ability_bolt_next = _t + _ability_bolt_every
		_use_ability(&"bolt")


func _apply(entry: Dictionary) -> void:
	var act: String = String(entry.get("act", ""))
	match act:
		"move":
			_move_dir = Vector2(float(entry.get("dx", 1.0)), float(entry.get("dy", 0.0)))
			_move_until = _t + float(entry.get("dur", 1.0))
			_move_until_x = float(entry.get("until_x", INF))
		"bolt":
			# `every` is the interval; `until` is an absolute timestamp (s since start).
			_ability_bolt_every = float(entry.get("every", 0.4))
			_ability_bolt_until = float(entry.get("until", _t + 1.0))
			_ability_bolt_next = _t
		"burst", "step", "ward", "sigil", "tempest", "potion", "dodge":
			_use_ability(StringName(act))


func _use_ability(key: StringName) -> void:
	if not is_instance_valid(player):
		return
	var abilities: Dictionary = player.get("abilities")
	if abilities == null:
		return
	var ab: Node = abilities.get(key)
	if ab == null:
		return
	if ab.has_method("can_use") and ab.can_use() and ab.has_method("use"):
		ab.use(player.aim_dir)
