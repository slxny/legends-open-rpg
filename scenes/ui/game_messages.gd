extends CanvasLayer

## SC:BW-style centered text messages that fade after a few seconds.

@onready var message_container: VBoxContainer = $MessageContainer

func _ready() -> void:
	GameManager.game_message.connect(_on_game_message)

func _on_game_message(text: String, color: Color = Color.WHITE) -> void:
	# Cap cleanup to avoid unbounded loop
	var excess = message_container.get_child_count() - 4
	for _i in range(excess):
		var old = message_container.get_child(0)
		old.queue_free()

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var is_mobile = GameManager.is_mobile_device()
	var settings = LabelSettings.new()
	settings.font_size = 48 if is_mobile else 18
	settings.font_color = color
	settings.outline_size = 6 if is_mobile else 3
	settings.outline_color = Color.BLACK
	label.label_settings = settings

	message_container.add_child(label)

	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
