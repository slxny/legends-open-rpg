extends Node
class_name StatusEffectComponent

## Phase 2.6: status effect bag on a node (typically an enemy).
##
## Owner code calls apply(data, source) when CombatManager indicates the
## hit carried a status. The component handles tick processing, expiry,
## stacking, and the consume() API used by Phase 2.7 ability
## interactions (e.g. "specials consume exposed for +50% damage").
##
## Tick model: a single _process loop checks all active records via
## wall-clock Time.get_ticks_usec(). DoT damage is delivered via owner
## reference's take_damage when present.
##
## process_mode = PAUSABLE so statuses pause with the game.

signal status_applied(id: StringName, source: Node, stacks: int)
signal status_expired(id: StringName)
signal status_consumed(id: StringName, by_attack_id: StringName)
signal status_ticked(id: StringName, damage: int, stacks: int)

const StatusEffectDataCls := preload("res://scripts/data/status_effect_data.gd")

class _Record:
	extends RefCounted
	var data: Resource         # StatusEffectData
	var source: Node           # who applied it (nullable)
	var applied_at_usec: int
	var expires_at_usec: int
	var next_tick_usec: int
	var stacks: int = 1


var _records: Dictionary = {}  # StringName -> _Record


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	if _records.is_empty():
		return
	var now: int = Time.get_ticks_usec()
	var to_expire: Array[StringName] = []
	for id in _records.keys():
		var r: _Record = _records[id]
		if now >= r.expires_at_usec:
			to_expire.append(id)
			continue
		# DoT tick.
		if int(r.data.tick_interval_ms) > 0 and now >= r.next_tick_usec:
			r.next_tick_usec = now + int(r.data.tick_interval_ms) * 1000
			var dmg: int = int(r.data.per_tick_damage) * r.stacks
			if dmg > 0:
				var owner_node: Node = get_parent()
				if owner_node != null and owner_node.has_method("take_damage"):
					owner_node.take_damage(dmg, false)
				status_ticked.emit(id, dmg, r.stacks)
	for id in to_expire:
		_records.erase(id)
		status_expired.emit(id)


func apply(data: Resource, source: Node = null) -> void:
	if data == null or StringName(data.get("id")) == &"":
		return
	var id: StringName = StringName(data.get("id"))
	var now: int = Time.get_ticks_usec()
	if _records.has(id):
		var existing: _Record = _records[id]
		var rule: StringName = StringName(data.get("stack_rule"))
		match rule:
			&"ignore":
				return
			&"stack":
				existing.stacks = min(existing.stacks + 1, int(data.get("stack_cap")))
				existing.expires_at_usec = now + int(data.get("duration_ms")) * 1000
			_:
				# refresh (default)
				existing.expires_at_usec = now + int(data.get("duration_ms")) * 1000
		status_applied.emit(id, source, existing.stacks)
		return
	var r := _Record.new()
	r.data = data
	r.source = source
	r.applied_at_usec = now
	r.expires_at_usec = now + int(data.get("duration_ms")) * 1000
	r.next_tick_usec = now + int(data.get("tick_interval_ms")) * 1000 if int(data.get("tick_interval_ms")) > 0 else 0
	r.stacks = 1
	_records[id] = r
	status_applied.emit(id, source, 1)


func has(id: StringName) -> bool:
	return _records.has(id)


func stacks_of(id: StringName) -> int:
	if not _records.has(id):
		return 0
	return _records[id].stacks


## Removes the status from the record book and emits status_consumed.
## Returns the stack count that was consumed.
func consume(id: StringName, by_attack_id: StringName = &"") -> int:
	if not _records.has(id):
		return 0
	var r: _Record = _records[id]
	var s = r.stacks
	_records.erase(id)
	status_consumed.emit(id, by_attack_id)
	return s


## Convenience: find any active status whose tier matches and consume it.
## Returns the consumed status id (empty StringName if none found).
func consume_first_tier(tier: StringName, by_attack_id: StringName = &"") -> StringName:
	for id in _records.keys():
		var r: _Record = _records[id]
		if StringName(r.data.get("tier")) == tier:
			consume(id, by_attack_id)
			return id
	return &""


func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _records.keys():
		out.append(id)
	return out


func clear_all() -> void:
	var ids := _records.keys().duplicate()
	_records.clear()
	for id in ids:
		status_expired.emit(id)


# Phase 2.6 baked presets — caller does:
#   var d := StatusEffectComponent.preset(&"exposed")
#   component.apply(d, attacker)
static func preset(preset_id: StringName) -> Resource:
	return StatusEffectDataCls.new().apply_preset(preset_id)
