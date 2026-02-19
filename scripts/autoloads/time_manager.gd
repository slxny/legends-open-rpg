extends Node

## SC:BW-style deterministic tick clock.
## Evaluates all triggers every TRIGGER_INTERVAL seconds,
## recreating the hyper-trigger timing rhythm.

const TRIGGER_INTERVAL := 0.25  # 4 evaluations per second
var accumulator := 0.0

func _process(delta: float) -> void:
	accumulator += delta
	if accumulator >= TRIGGER_INTERVAL:
		accumulator -= TRIGGER_INTERVAL
		TriggerEngine.evaluate_all()
