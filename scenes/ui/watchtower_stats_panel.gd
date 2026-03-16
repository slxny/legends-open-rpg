extends CanvasLayer

## Watchtower stats panel — right-click on a watchtower to view its stats.

@onready var panel: PanelContainer = $Panel
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/VBox/StatsLabel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var _dim: ColorRect = $Dim

var _tower: Node2D = null
var _is_visible: bool = false
var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.5

const COL_BG        = Color(0.06, 0.06, 0.08, 1.0)
const COL_BORDER    = Color(0.35, 0.5, 0.25, 0.6)
const COL_TITLE     = Color(0.8, 1.0, 0.7)
const COL_LABEL     = Color(0.55, 0.52, 0.48)
const COL_VALUE     = Color(0.92, 0.9, 0.85)
const COL_HP        = Color(0.85, 0.25, 0.22)
const COL_HP_GOOD   = Color(0.3, 0.85, 0.3)
const COL_DIM       = Color(0.0, 0.0, 0.0, 0.45)

func _ready() -> void:
	panel.visible = false
	_dim.visible = false
	close_button.pressed.connect(close)
	_style_panel()

func show_tower(tower: Node2D) -> void:
	_tower = tower
	_is_visible = true
	panel.visible = true
	_dim.visible = true
	_refresh_timer = 0.0
	var is_mobile = GameManager.is_mobile_device()
	if is_mobile:
		var vp_size = get_viewport().get_visible_rect().size
		var margin = 16.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 48)
		close_button.text = "X"
		close_button.add_theme_font_size_override("font_size", 60)
		close_button.custom_minimum_size = Vector2(160, 130)
		stats_label.add_theme_font_size_override("normal_font_size", 34)
	_refresh()

func close() -> void:
	_is_visible = false
	panel.visible = false
	_dim.visible = false
	_tower = null

func _style_panel() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color = COL_BG
	bg.border_color = COL_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(12)
	bg.shadow_color = Color(0, 0, 0, 0.35)
	bg.shadow_size = 8
	panel.add_theme_stylebox_override("panel", bg)

	var cb_normal = StyleBoxFlat.new()
	cb_normal.bg_color = Color(0.18, 0.16, 0.13, 0.9)
	cb_normal.border_color = Color(0.5, 0.4, 0.2, 0.5)
	cb_normal.set_border_width_all(1)
	cb_normal.set_corner_radius_all(6)
	cb_normal.set_content_margin_all(4)
	var cb_hover = cb_normal.duplicate()
	cb_hover.bg_color = Color(0.25, 0.22, 0.16, 0.95)
	cb_hover.border_color = Color(0.7, 0.55, 0.25, 0.7)
	var cb_pressed = cb_normal.duplicate()
	cb_pressed.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	close_button.add_theme_stylebox_override("normal", cb_normal)
	close_button.add_theme_stylebox_override("hover", cb_hover)
	close_button.add_theme_stylebox_override("pressed", cb_pressed)
	close_button.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.65))

	_dim.color = COL_DIM

func _process(delta: float) -> void:
	if _is_visible and _tower and is_instance_valid(_tower):
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = REFRESH_INTERVAL
			_refresh()

func _refresh() -> void:
	if not _tower or not is_instance_valid(_tower):
		close()
		return

	var lines: Array[String] = []
	var extra_level = 0
	if _tower.tower_index >= 0 and _tower.tower_index < GameManager.watchtowers.size():
		extra_level = GameManager.watchtowers[_tower.tower_index].get("level", 0)

	# Title
	lines.append("[color=#%s]Watchtower  Lv %d[/color]" % [
		COL_TITLE.to_html(false), extra_level + 1,
	])
	lines.append("")

	# HP
	var hp_pct = float(_tower.current_hp) / float(_tower.max_hp) if _tower.max_hp > 0 else 1.0
	var hp_color = COL_HP_GOOD if hp_pct > 0.5 else COL_HP
	lines.append(_stat_line("HP", "%d / %d" % [_tower.current_hp, _tower.max_hp], hp_color))
	lines.append("")

	# Combat stats
	lines.append(_stat_line("Attack Damage", str(_tower.attack_damage)))
	lines.append(_stat_line("Attack Range", "%.0f" % _tower.attack_range))
	lines.append(_stat_line("Attack Speed", "%.2fs" % _tower.attack_cooldown))
	lines.append(_stat_line("Armor", str(_tower.tower_level * 2)))
	lines.append("")

	# Upgrade info
	var upgrade_cost = _tower._get_upgrade_cost()
	lines.append(_stat_line("Upgrade Cost", "%d wood" % upgrade_cost, COL_TITLE))

	# Level bonuses
	lines.append("")
	lines.append("[color=#%s]Per Level:[/color]" % COL_LABEL.to_html(false))
	lines.append(_stat_line("  +HP", "+30"))
	lines.append(_stat_line("  +ATK", "+3"))
	lines.append(_stat_line("  +Range", "+10 (max 350)"))
	lines.append(_stat_line("  -Cooldown", "-0.05s (min 0.6s)"))

	stats_label.bbcode_enabled = true
	stats_label.text = "\n".join(lines)

func _stat_line(label: String, value: String, value_color: Color = COL_VALUE) -> String:
	return "[color=#%s]%s[/color]   [color=#%s]%s[/color]" % [
		COL_LABEL.to_html(false), label,
		value_color.to_html(false), value,
	]

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_1"):
		close()
		get_viewport().set_input_as_handled()
		return
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x >= 0 and not panel.get_global_rect().has_point(pos):
		close()
		get_viewport().set_input_as_handled()
