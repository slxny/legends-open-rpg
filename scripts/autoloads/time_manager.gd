extends Node

## SC:BW-style deterministic tick clock + sole owner of `Engine.time_scale`.
##
## The trigger-evaluation half existed pre-Phase-1B: evaluate all triggers
## every TRIGGER_INTERVAL seconds. That behavior is unchanged.
##
## Phase 1B.0 added the time-scale ownership layer (per plan corr. 2):
##   request_time_scale(scale, duration_ms, priority, source_id) -> bool
##   force_reset() -> void
##   signal time_scale_changed(new_scale: float)
##
## Conflict policy:
##   - Each request carries a priority (int). Higher wins.
##   - While an active request is in flight, equal or lower priority
##     requests are rejected. A higher priority replaces it immediately.
##   - When the active request's wall-clock deadline expires,
##     Engine.time_scale is restored to 1.0.
##
## Timing is wall-clock via Time.get_ticks_usec() — not delta-accumulated
## — so a slowdown does NOT extend its own recovery.
## process_mode = PROCESS_MODE_ALWAYS so this node ticks even while the
## game is paused (so a slowdown active before pause is recovered cleanly).

const TRIGGER_INTERVAL := 0.5  # 2 evaluations per second
var accumulator := 0.0

signal time_scale_changed(new_scale: float)

class _TimeScaleRequest:
	extends RefCounted
	var scale: float = 1.0
	var deadline_usec: int = 0
	var priority: int = 0
	var source_id: StringName = &""

var _active: _TimeScaleRequest = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Explicit reset sources (plan corr. 3) — connect everything that
	# exists; missing signals are added by this stage's accompanying edits.
	get_tree().scene_changed.connect(_on_scene_changed)
	# Shutdown: handled via _notification(NOTIFICATION_WM_CLOSE_REQUEST /
	# NOTIFICATION_PREDELETE) — SceneTree has no tree_exiting signal.
	if RespawnManager.has_signal("player_died"):
		RespawnManager.player_died.connect(_on_player_died)
	if SaveLoadManager.has_signal("game_loaded"):
		SaveLoadManager.game_loaded.connect(force_reset)
	if SaveLoadManager.has_signal("save_about_to_load"):
		SaveLoadManager.save_about_to_load.connect(force_reset)
	if GameManager.has_signal("returning_to_menu"):
		GameManager.returning_to_menu.connect(force_reset)


func _process(delta: float) -> void:
	# Trigger evaluator (unchanged behavior). Skipped while paused so the
	# autoload's PROCESS_MODE_ALWAYS doesn't make triggers fire during pause.
	if not get_tree().paused:
		accumulator += delta
		if accumulator >= TRIGGER_INTERVAL:
			accumulator -= TRIGGER_INTERVAL
			TriggerEngine.evaluate_all()

	# Time-scale recovery uses wall-clock — survives both pause and slowdown.
	if _active != null and Time.get_ticks_usec() >= _active.deadline_usec:
		_clear_active_and_restore()


## Accepts the request if no active request or this is higher priority.
## Returns true on accept, false on reject. source_id is purely diagnostic.
func request_time_scale(scale: float, duration_ms: int, priority: int, source_id: StringName) -> bool:
	if duration_ms <= 0 or scale <= 0.0:
		return false
	if scale >= 1.0:
		# A request that does not slow down is a no-op; not an error.
		return false
	if _active != null and priority <= _active.priority:
		return false
	var req := _TimeScaleRequest.new()
	req.scale = scale
	req.deadline_usec = Time.get_ticks_usec() + duration_ms * 1000
	req.priority = priority
	req.source_id = source_id
	_active = req
	Engine.time_scale = scale
	time_scale_changed.emit(scale)
	return true


## Idempotent. Always brings Engine.time_scale back to 1.0 and drops any
## active request. Connected to scene_changed, player_died, save_loaded,
## save_about_to_load, returning_to_menu, tree_exiting.
func force_reset() -> void:
	_clear_active_and_restore()


func is_time_dilated() -> bool:
	return _active != null


func active_source() -> StringName:
	return _active.source_id if _active != null else &""


func _clear_active_and_restore() -> void:
	if _active == null and is_equal_approx(Engine.time_scale, 1.0):
		return
	_active = null
	Engine.time_scale = 1.0
	time_scale_changed.emit(1.0)


func _on_scene_changed() -> void:
	force_reset()


func _on_player_died(_player_id: int) -> void:
	force_reset()


func _notification(what: int) -> void:
	# Shutdown safety: never leave the engine with time_scale < 1.0.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if not is_equal_approx(Engine.time_scale, 1.0):
			Engine.time_scale = 1.0
