extends CanvasLayer

## SC:BW-style centered text messages that fade after a few seconds.

@onready var message_container: VBoxContainer = $MessageContainer

func _ready() -> void:
	GameManager.game_message.connect(_on_game_message)

func _on_game_message(text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	# Black outline via LabelSettings
	var settings = LabelSettings.new()
	settings.font_size = 18
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	label.label_settings = settings

	message_container.add_child(label)

	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

	# Keep max 5 messages visible
	while message_container.get_child_count() > 5:
		message_container.get_child(0).queue_free()
