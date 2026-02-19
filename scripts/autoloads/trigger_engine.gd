extends Node

## SC:BW-style deterministic trigger engine.
## Every game mechanic is expressed as a Trigger with conditions and actions.
## Evaluated on a fixed tick by TimeManager.

var triggers: Array = []

func register(trigger: Trigger) -> void:
	triggers.append(trigger)

func unregister(trigger: Trigger) -> void:
	triggers.erase(trigger)

func evaluate_all() -> void:
	for t in triggers:
		if is_instance_valid(t) or t is Trigger:
			t.evaluate()

func clear() -> void:
	triggers.clear()


class Trigger:
	## A single SC-style trigger: list of condition callables + list of action callables.
	var conditions: Array = []
	var actions: Array = []
	var enabled: bool = true
	var once: bool = false  # If true, auto-disable after first firing
	var _has_fired: bool = false

	func evaluate() -> void:
		if not enabled:
			return
		if once and _has_fired:
			return
		for c in conditions:
			if not c.call():
				return
		# All conditions passed — fire actions
		for a in actions:
			a.call()
		if once:
			_has_fired = true
			enabled = false
