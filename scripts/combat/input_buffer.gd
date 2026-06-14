extends RefCounted
class_name InputBuffer

## Phase 1A.2: raw combat-input event buffer.
##
## Stores presses with monotonic real-time timestamps and a per-action TTL.
## Each record is single-consume — peek() returns it; consume() marks it
## used and prevents re-firing.
##
## What this class does NOT do (by design, per plan corr. 6):
##   - tap-count interpretation
##   - special-attack selection
##   - charge resolution
##   - priority between actions
## All of the above lives in AttackIntentResolver (Phase 1A.3) and
## CombatController (Phase 1C). Keeping the buffer scope tight makes it
## reusable across hero classes (melee + ranged) and trivially testable.

class Record:
	extends RefCounted
	var action: StringName
	var pressed_at_usec: int
	var ttl_ms: int
	var consumed: bool = false
	var generation: int = 0  # 0 = first, increments per re-press of same action

	func is_expired(now_usec: int) -> bool:
		if ttl_ms <= 0:
			return false  # 0/negative TTL means hold-indefinite (charge_press)
		var age_ms := (now_usec - pressed_at_usec) / 1000
		return age_ms > ttl_ms

	func age_ms(now_usec: int) -> int:
		return (now_usec - pressed_at_usec) / 1000


# Default TTLs in milliseconds. Caller may override per-press via `push()`.
const DEFAULT_TTL := {
	&"attack": 140,
	&"dodge": 120,
	&"direction_intent": 180,
	&"special_tap": 180,
	&"charge_press": 0,  # 0 = hold-indefinite, expires on explicit release
}

var _records: Array[Record] = []
var _gen_counter: Dictionary = {}  # StringName -> int

# Debug print toggle. Owner flips this to true to log every push/consume.
var debug: bool = false


func push(action: StringName, now_usec: int, ttl_ms_override: int = -1) -> Record:
	var ttl: int = ttl_ms_override
	if ttl < 0:
		ttl = int(DEFAULT_TTL.get(action, 140))
	var rec := Record.new()
	rec.action = action
	rec.pressed_at_usec = now_usec
	rec.ttl_ms = ttl
	rec.generation = int(_gen_counter.get(action, 0))
	_gen_counter[action] = rec.generation + 1
	_records.append(rec)
	if debug:
		print("[InputBuffer] push action=%s ttl=%dms gen=%d" % [action, ttl, rec.generation])
	return rec


## Returns the most-recent unconsumed, unexpired record for `action`, or null.
func peek(action: StringName, now_usec: int) -> Record:
	_prune(now_usec)
	for i in range(_records.size() - 1, -1, -1):
		var r := _records[i]
		if r.action == action and not r.consumed and not r.is_expired(now_usec):
			return r
	return null


## Marks the record consumed and returns true. False if already consumed
## or expired. Safe to call with null.
func consume(rec: Record, now_usec: int) -> bool:
	if rec == null or rec.consumed:
		return false
	if rec.is_expired(now_usec):
		return false
	rec.consumed = true
	if debug:
		print("[InputBuffer] consume action=%s age=%dms gen=%d" % [rec.action, rec.age_ms(now_usec), rec.generation])
	return true


## Atomic peek+consume helper for the common case.
func take(action: StringName, now_usec: int) -> Record:
	var r := peek(action, now_usec)
	if r != null and consume(r, now_usec):
		return r
	return null


## Explicit expiry for indefinite-TTL actions (charge_press release).
func release(action: StringName) -> void:
	for r in _records:
		if r.action == action and not r.consumed:
			r.consumed = true
			if debug:
				print("[InputBuffer] release action=%s gen=%d" % [r.action, r.generation])


## Drop all records — used on state changes (player death, scene change).
func clear() -> void:
	_records.clear()
	if debug:
		print("[InputBuffer] cleared")


## Diagnostic snapshot.
func active_actions(now_usec: int) -> Array[StringName]:
	_prune(now_usec)
	var seen := {}
	var out: Array[StringName] = []
	for r in _records:
		if not r.consumed and not r.is_expired(now_usec) and not seen.has(r.action):
			seen[r.action] = true
			out.append(r.action)
	return out


func size() -> int:
	return _records.size()


func _prune(now_usec: int) -> void:
	var keep: Array[Record] = []
	for r in _records:
		if r.consumed or r.is_expired(now_usec):
			continue
		keep.append(r)
	_records = keep
