extends Node

## Phase 1B.1: localized hit-stop + global-dip dispatcher (plan §3 corr. 4).
##
## Two freeze APIs:
##   freeze_target(node, ms, kind)    — localized; query via is_frozen(node)
##   request_global_dip(profile)      — routes to TimeManager, never writes
##                                       Engine.time_scale directly
##
## Localized: any node (player or enemy) can be marked frozen for a
## monotonic wall-clock duration. Owner code queries is_frozen() before
## ticking AI / advancing animations / consuming input. Phase 1B.6 wires
## this into player.gd and enemy.gd; Phase 1B.1 ships the system only.
##
## Why query-based rather than call set("speed_scale", 0): the project
## uses Tweens for combat animation, not AnimationPlayer. There's no
## single "pause animation" knob. A query model is cheap and lets each
## owner decide which of its tickable things to skip.
##
## Wide-attack aggregation: per-attack_id, a strongest-wins request is
## tracked for the global dip. Stage 1B.6 will pass attack_id from
## CombatManager.hit_resolved subscribers; weak hits during a stronger
## dip do not extend it (TimeManager priority handles that).
##
## process_mode = PROCESS_MODE_ALWAYS so freezes expire even while paused.

const FreezeKind := {
	ATTACKER = 0,
	VICTIM = 1,
}

signal target_frozen(node: Node, kind: int, deadline_usec: int)
signal target_unfrozen(node: Node)

class _FreezeRecord:
	extends RefCounted
	var node_id: int = 0  # instance ID — survives node freed during freeze
	var kind: int = 0
	var deadline_usec: int = 0
	var generation: int = 0

var _records: Array[_FreezeRecord] = []
var _by_node_id: Dictionary = {}  # node_id -> _FreezeRecord
var _gen_counter: int = 0

# Per-attack_id dip dedupe — last (deadline, scale) so weak coalesced hits
# don't repeatedly call TimeManager during a single attack instance.
var _dip_by_attack_id: Dictionary = {}  # attack_id -> deadline_usec


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Mirror TimeManager's reset sources so localized freezes also clear.
	get_tree().scene_changed.connect(force_reset)
	if RespawnManager.has_signal("player_died"):
		RespawnManager.player_died.connect(func(_pid): force_reset())
	if SaveLoadManager.has_signal("game_loaded"):
		SaveLoadManager.game_loaded.connect(force_reset)
	if SaveLoadManager.has_signal("save_about_to_load"):
		SaveLoadManager.save_about_to_load.connect(force_reset)
	if GameManager.has_signal("returning_to_menu"):
		GameManager.returning_to_menu.connect(force_reset)


func _process(_delta: float) -> void:
	if _records.is_empty():
		return
	var now: int = Time.get_ticks_usec()
	var keep: Array[_FreezeRecord] = []
	for r in _records:
		if now >= r.deadline_usec:
			_by_node_id.erase(r.node_id)
			var inst: Object = instance_from_id(r.node_id)
			if inst is Node:
				target_unfrozen.emit(inst)
		else:
			keep.append(r)
	_records = keep


## Freeze a node for `duration_ms` real-time milliseconds. If the node is
## already frozen, the longer of the two deadlines wins (so a stronger
## later freeze cannot be shortened by a leftover weak one).
func freeze_target(node: Node, duration_ms: int, kind: int = FreezeKind.VICTIM) -> bool:
	if node == null or not is_instance_valid(node) or duration_ms <= 0:
		return false
	var node_id: int = node.get_instance_id()
	var new_deadline: int = Time.get_ticks_usec() + duration_ms * 1000
	if _by_node_id.has(node_id):
		var existing: _FreezeRecord = _by_node_id[node_id]
		if new_deadline > existing.deadline_usec:
			existing.deadline_usec = new_deadline
			existing.kind = kind
		return true
	_gen_counter += 1
	var r := _FreezeRecord.new()
	r.node_id = node_id
	r.kind = kind
	r.deadline_usec = new_deadline
	r.generation = _gen_counter
	_records.append(r)
	_by_node_id[node_id] = r
	target_frozen.emit(node, kind, new_deadline)
	return true


## Owner-code query — returns true while the node is in a freeze window.
func is_frozen(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var rec = _by_node_id.get(node.get_instance_id())
	if rec == null:
		return false
	if Time.get_ticks_usec() >= rec.deadline_usec:
		# Expired but _process hasn't pruned yet; treat as unfrozen.
		return false
	return true


## Routes a global time-dilation request through TimeManager (sole owner
## of Engine.time_scale). Returns true if TimeManager accepted.
## `attack_id` dedupes wide-attack bursts — only the first hit of an
## attack instance forwards the request; subsequent same-attack-id
## hits within the dip's lifetime are dropped at this layer.
func request_global_dip(scale: float, duration_ms: int, priority: int, attack_id: StringName) -> bool:
	var now: int = Time.get_ticks_usec()
	var existing_deadline: int = int(_dip_by_attack_id.get(attack_id, 0))
	if existing_deadline > now:
		# Same attack instance already dispatched a dip recently.
		return false
	if TimeManager.request_time_scale(scale, duration_ms, priority, attack_id):
		_dip_by_attack_id[attack_id] = now + duration_ms * 1000
		return true
	return false


func force_reset() -> void:
	for r in _records:
		var inst: Object = instance_from_id(r.node_id)
		if inst is Node:
			target_unfrozen.emit(inst)
	_records.clear()
	_by_node_id.clear()
	_dip_by_attack_id.clear()


func active_freeze_count() -> int:
	return _records.size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_records.clear()
		_by_node_id.clear()
		_dip_by_attack_id.clear()
