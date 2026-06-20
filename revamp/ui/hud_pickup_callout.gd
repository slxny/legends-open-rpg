extends Control

## Floating callout shown after loot pickup. Surfaces the item card +
## ability comparison so the player understands the build-change.

const HUDStyle := preload("res://revamp/ui/hud_style.gd")

var _item: Resource
var _name_label: Label
var _body_label: Label
var _t: float = 0.0
var _life: float = 0.0


func _ready() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(20, 16)
	_name_label.size = Vector2(size.x - 40, 28)
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_name_label.add_theme_constant_override("outline_size", 5)
	add_child(_name_label)
	_body_label = Label.new()
	_body_label.position = Vector2(20, 50)
	_body_label.size = Vector2(size.x - 40, size.y - 70)
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", HUDStyle.TEXT_PRIMARY)
	_body_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_body_label.add_theme_constant_override("outline_size", 4)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_body_label)
	set_process(true)


func show_for(item: Resource) -> void:
	_item = item
	visible = true
	_life = 6.0
	if _item == null:
		_name_label.text = "—"
		_body_label.text = ""
	else:
		_name_label.text = _item.display_name
		_name_label.add_theme_color_override("font_color", _item.rarity_color())
		var tip: String = _item.tooltip_text()
		_body_label.text = tip
	# Pop-in animation
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.25)
	queue_redraw()


func _process(delta: float) -> void:
	if _life > 0.0:
		_life = maxf(0.0, _life - delta)
		if _life == 0.0:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): visible = false)
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _item == null:
		return
	HUDStyle.draw_panel(self, Rect2(Vector2.ZERO, size), 6.0)
	# Top color band by rarity
	var col: Color = _item.rarity_color()
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 8)), col, true)
	draw_rect(Rect2(Vector2(0, size.y - 8), Vector2(size.x, 8)), col.darkened(0.4), true)
	# Pulse highlight on the band
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 3)), Color(1, 1, 1, 0.25 + 0.4 * pulse), true)
