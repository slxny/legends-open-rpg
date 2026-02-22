extends CanvasLayer

## SC:BW-style dramatic center screen text messages.
## "LEVEL UP!", "BOSS DEFEATED!", etc.
## Instant appearance, brief hold, fade out. No animations.

@onready var message_label: Label = $CenterContainer/MessageLabel

var _message_queue: Array[Dictionary] = []
var _showing: bool = false

func _ready() -> void:
	message_label.visible = false
	# Connect to game message for dramatic messages
	GameManager.game_message.connect(_on_game_message)

func _on_game_message(text: String, color: Color = Color.WHITE) -> void:
	# Only show dramatic messages (level up, boss, settlement, etc.)
	var dramatic_keywords = ["LEVEL UP", "BOSS", "Purchased", "DEFEATED", "Respawned", "Alignment"]
	var is_dramatic = false
	for keyword in dramatic_keywords:
		if text.find(keyword) >= 0:
			is_dramatic = true
			break
	if is_dramatic:
		show_center_message(text, color)

func show_center_message(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	_message_queue.append({"text": text, "color": color, "duration": duration})
	if not _showing:
		_process_queue()

func _process_queue() -> void:
	if _message_queue.is_empty():
		_showing = false
		return
	_showing = true
	var msg = _message_queue.pop_front()
	_display_message(msg["text"], msg["color"], msg["duration"])

func _display_message(text: String, color: Color, duration: float) -> void:
	# SC-style: instant appear, no fade in
	var vp_size = get_viewport().get_visible_rect().size
	var is_mobile = vp_size.x < 700 or (vp_size.x < vp_size.y)
	var settings = LabelSettings.new()
	settings.font_size = 72 if is_mobile else 32
	settings.font_color = color
	settings.outline_size = 8 if is_mobile else 4
	settings.outline_color = Color.BLACK
	message_label.label_settings = settings
	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 1.0

	# Hold then fade
	await get_tree().create_timer(duration).timeout
	var tween = create_tween()
	tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		message_label.visible = false
		message_label.modulate.a = 1.0
		_process_queue()
	)
