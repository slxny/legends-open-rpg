extends CanvasLayer
class_name CombatJuiceLayer

## Visual juice that doesn't fit on the existing HUD: floating pop-up
## text on big hits, a combo counter that pulses with each strike, and
## the radial impact flash spawned at confirmed hits.
##
## Attached as a child of player.gd. Subscribes to:
##   - CombatManager.hit_resolved  (FINISHER / CRIT / EXPOSED CONSUMED pop-ups + ring)
##   - the player's MomentumComponent (combo display)
##   - any enemy's PoiseComponent.poise_broken proxied via hit reaction
##     (currently routed via HitReactionComponent stagger_requested as a proxy)

const COMBO_FONT_SIZE_BASE: int = 28
const POPUP_LIFETIME_SEC: float = 0.85

var _combo_label: Label = null
var _combo_settings: LabelSettings = null
var _combo_visible_combo: float = 1.0
var _last_combo_pulse_msec: int = 0

# Phase 6.1 — momentum bar UI.
var _momentum_bar_bg: ColorRect = null
var _momentum_bar_fill: ColorRect = null
var _momentum_threshold_label: Label = null
# Phase 6.3 — upgrade list UI.
var _upgrade_panel: ColorRect = null
var _upgrade_list_label: Label = null

var _player: Node2D = null  # parent player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = 80  # above the regular HUD bar

	_combo_settings = LabelSettings.new()
	_combo_settings.font_size = COMBO_FONT_SIZE_BASE
	_combo_settings.font_color = Color(1.0, 0.85, 0.3)
	_combo_settings.outline_size = 4
	_combo_settings.outline_color = Color(0.05, 0.04, 0.02)
	_combo_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_combo_settings.shadow_size = 3

	_combo_label = Label.new()
	_combo_label.label_settings = _combo_settings
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.anchor_top = 0.08
	_combo_label.anchor_bottom = 0.08
	_combo_label.offset_left = -120
	_combo_label.offset_right = 120
	_combo_label.offset_top = -10
	_combo_label.offset_bottom = 50
	_combo_label.modulate.a = 0.0
	add_child(_combo_label)

	# Player parent (juice layer lives under player).
	_player = get_parent() as Node2D

	# Phase 6.1 — momentum bar at bottom-center of screen.
	_build_momentum_bar()
	# Phase 6.3 — upgrade list panel.
	_build_upgrade_panel()

	# Subscribe to combat events.
	if Engine.has_singleton("CombatManager") or get_node_or_null("/root/CombatManager") != null:
		CombatManager.hit_resolved.connect(_on_hit_resolved)

	# Subscribe to player's momentum changes for the combo counter +
	# threshold pop-ups + frenzy banner.
	var mom = _player.get_node_or_null("MomentumComponent") if _player != null else null
	if mom != null:
		if mom.has_signal("combo_multiplier_changed"):
			mom.combo_multiplier_changed.connect(_on_combo_multiplier_changed)
		if mom.has_signal("threshold_entered"):
			mom.threshold_entered.connect(_on_threshold_entered)
		if mom.has_signal("frenzy_started"):
			mom.frenzy_started.connect(_on_frenzy_started_juice)
		if mom.has_signal("frenzy_ended"):
			mom.frenzy_ended.connect(_on_frenzy_ended_juice)
		if mom.has_signal("momentum_changed"):
			mom.momentum_changed.connect(_on_momentum_changed_juice)
	# Phase 6.3 — upgrade list subscriber.
	var upg = _player.get_node_or_null("UpgradeManager") if _player != null else null
	if upg != null and upg.has_signal("upgrade_granted"):
		upg.upgrade_granted.connect(_on_upgrade_granted_refresh)


func _on_combo_multiplier_changed(value: float) -> void:
	_combo_visible_combo = value
	if value <= 1.001:
		_fade_combo_out()
		return
	_show_combo(value)


func _show_combo(combo: float) -> void:
	if _combo_label == null:
		return
	# x1.3 → "1.3x COMBO"
	_combo_label.text = "%.1fx COMBO" % combo
	# Pulse: bigger font + brighter on each tick.
	var pulse_size: int = int(COMBO_FONT_SIZE_BASE + clamp((combo - 1.0) * 14.0, 0.0, 24.0))
	_combo_settings.font_size = pulse_size
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_combo_label, "modulate:a", 1.0, 0.08)
	t.tween_property(_combo_label, "scale", Vector2(1.18, 1.18), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.18)
	_last_combo_pulse_msec = Time.get_ticks_msec()


func _fade_combo_out() -> void:
	if _combo_label == null:
		return
	var t := create_tween()
	t.tween_property(_combo_label, "modulate:a", 0.0, 0.4)


func _on_hit_resolved(result: Resource) -> void:
	if result == null or result.event == null:
		return
	# Only celebrate hits the player landed.
	if _player == null or result.event.attacker != _player:
		return
	if not is_instance_valid(result.event.victim):
		return
	if int(result.damage_dealt) <= 0:
		return

	var victim_pos: Vector2 = result.event.victim.global_position
	var attack_id: StringName = StringName(result.event.attack_id)
	var was_crit: bool = bool(result.was_crit)
	var was_lethal: bool = bool(result.was_lethal)

	# Pick the loudest single label for this hit.
	var label: String = ""
	var color: Color = Color(1.0, 0.85, 0.3)
	# v0.90.7 — positional hits take priority over generic crit labels.
	var positional: StringName = StringName(result.get_meta("positional_tag", ""))
	# Lethal kill — always celebrate.
	if was_lethal:
		label = "KILL!"
		color = Color(1.5, 0.3, 0.3)
	elif positional == &"back":
		label = "FROM BEHIND!"
		color = Color(1.7, 0.4, 1.4)
	elif positional == &"flank":
		label = "FLANKED!"
		color = Color(1.5, 0.9, 0.3)
	elif was_crit:
		# Crit on a finisher reads as a slow-mo blow.
		if attack_id == &"swing_c" or attack_id == &"branch_slam" or attack_id == &"charged_slash":
			label = "DEVASTATING!"
			color = Color(1.6, 0.5, 0.1)
		else:
			label = "CRIT!"
			color = Color(1.0, 0.6, 0.2)
	elif attack_id == &"swing_c":
		label = "FINISHER!"
		color = Color(1.5, 0.85, 0.3)
	elif attack_id == &"branch_slam":
		label = "SLAM!"
		color = Color(1.3, 0.65, 0.15)
	elif attack_id == &"branch_uppercut":
		label = "LIFT!"
		color = Color(1.2, 0.8, 0.4)
	elif attack_id == &"branch_spin":
		label = "SPIN!"
		color = Color(0.9, 0.5, 1.2)
	elif attack_id == &"charged_slash":
		label = "CHARGED!"
		color = Color(1.5, 1.2, 0.4)
	elif attack_id == &"whirlwind":
		label = "WHIRLWIND!"
		color = Color(0.9, 0.5, 1.3)
	elif attack_id == &"power_strike":
		label = "POWER!"
		color = Color(1.4, 0.65, 0.2)

	# EXPOSED-consumed bonus: detected via final_feedback weight + status
	# isn't directly available here, so we approximate: any special with a
	# noticeably higher damage_dealt than baseline reads as bonus. Cheap
	# heuristic — accurate enough for the pop-up.
	# (Status apply text handled separately.)

	if label != "":
		_spawn_floating_text(victim_pos + Vector2(0, -32), label, color, was_lethal or was_crit)

	# Radial blood-ring on every confirmed hit. Cheap pooled-style sprite.
	_spawn_impact_ring(victim_pos, color, was_crit)


func _spawn_floating_text(world_pos: Vector2, text: String, color: Color, big: bool) -> void:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = 48 if big else 32
	settings.font_color = color
	settings.outline_size = 6
	settings.outline_color = Color(0.05, 0.02, 0.02)
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	settings.shadow_size = 4
	label.label_settings = settings
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	add_child(label)
	# Position via top-left → convert world to screen.
	_position_label_at_world(label, world_pos)
	label.scale = Vector2(0.6, 0.6)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "modulate:a", 1.0, 0.05)
	t.tween_property(label, "scale", Vector2(1.1, 1.1) if big else Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	# Float up + linger + fade.
	t.tween_property(label, "position:y", label.position.y - (90 if big else 60), POPUP_LIFETIME_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, POPUP_LIFETIME_SEC * 0.9)
	t.tween_callback(label.queue_free)


func _position_label_at_world(label: Label, world_pos: Vector2) -> void:
	# Convert world to canvas-layer coordinates.
	if _player == null:
		label.position = Vector2.ZERO
		return
	var viewport := _player.get_viewport()
	if viewport == null:
		label.position = world_pos
		return
	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	var screen_pos: Vector2 = canvas_xform * world_pos
	# Center label around screen_pos.
	label.position = screen_pos - Vector2(60, 20)
	label.size = Vector2(120, 40)


# Phase 2.8 threshold pop-ups. Spawned center-top so player can't miss.
var _frenzy_banner: Label = null
func _on_threshold_entered(name: StringName) -> void:
	var text: String = ""
	var color: Color = Color(1.0, 0.85, 0.3)
	match name:
		&"focused":
			text = "FOCUSED!"
			color = Color(0.6, 1.2, 1.6)
		&"heated":
			text = "HEATED!"
			color = Color(1.4, 0.65, 0.15)
		&"frenzy":
			text = "FRENZY!"
			color = Color(1.5, 0.25, 0.15)
	if text == "" or _player == null:
		return
	# Spawn at player position offset up.
	_spawn_floating_text(_player.global_position + Vector2(0, -68), text, color, true)


func _on_frenzy_started_juice(_duration_ms: int) -> void:
	# Persistent banner during frenzy — sticks at top-center.
	if _frenzy_banner != null and is_instance_valid(_frenzy_banner):
		_frenzy_banner.queue_free()
	_frenzy_banner = Label.new()
	var settings := LabelSettings.new()
	settings.font_size = 56
	settings.font_color = Color(1.5, 0.3, 0.15)
	settings.outline_size = 8
	settings.outline_color = Color(0.05, 0.0, 0.0)
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	settings.shadow_size = 5
	_frenzy_banner.label_settings = settings
	_frenzy_banner.text = "FRENZY"
	_frenzy_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frenzy_banner.anchor_left = 0.5
	_frenzy_banner.anchor_right = 0.5
	_frenzy_banner.anchor_top = 0.18
	_frenzy_banner.anchor_bottom = 0.18
	_frenzy_banner.offset_left = -180
	_frenzy_banner.offset_right = 180
	_frenzy_banner.offset_top = -10
	_frenzy_banner.offset_bottom = 70
	_frenzy_banner.modulate.a = 0.0
	add_child(_frenzy_banner)
	var t := _frenzy_banner.create_tween()
	t.tween_property(_frenzy_banner, "modulate:a", 1.0, 0.15)
	# Pulse loop on the banner so it feels alive.
	var pulse := _frenzy_banner.create_tween().set_loops()
	pulse.tween_property(_frenzy_banner, "scale", Vector2(1.06, 1.06), 0.35).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_frenzy_banner, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)


func _on_frenzy_ended_juice() -> void:
	if _frenzy_banner == null or not is_instance_valid(_frenzy_banner):
		return
	var t := _frenzy_banner.create_tween()
	t.tween_property(_frenzy_banner, "modulate:a", 0.0, 0.3)
	var banner_ref := _frenzy_banner
	t.tween_callback(func() -> void:
		if is_instance_valid(banner_ref):
			banner_ref.queue_free())
	_frenzy_banner = null


# Phase 6.1 — momentum bar UI. Bottom-center, slim and unobtrusive.
# Color shifts: gray < FOCUSED, cyan FOCUSED, orange HEATED, red FRENZY.
const _MOMENTUM_BAR_WIDTH: float = 280.0
const _MOMENTUM_BAR_HEIGHT: float = 14.0
func _build_momentum_bar() -> void:
	_momentum_bar_bg = ColorRect.new()
	_momentum_bar_bg.color = Color(0.05, 0.04, 0.03, 0.7)
	_momentum_bar_bg.anchor_left = 0.5
	_momentum_bar_bg.anchor_right = 0.5
	_momentum_bar_bg.anchor_top = 1.0
	_momentum_bar_bg.anchor_bottom = 1.0
	_momentum_bar_bg.offset_left = -_MOMENTUM_BAR_WIDTH / 2.0
	_momentum_bar_bg.offset_right = _MOMENTUM_BAR_WIDTH / 2.0
	_momentum_bar_bg.offset_top = -130.0
	_momentum_bar_bg.offset_bottom = -130.0 + _MOMENTUM_BAR_HEIGHT
	_momentum_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_momentum_bar_bg)
	# Fill rect — anchored full to the bg, width adjusted on update.
	_momentum_bar_fill = ColorRect.new()
	_momentum_bar_fill.color = Color(0.5, 0.6, 0.7, 0.85)
	_momentum_bar_fill.anchor_right = 0.0  # we'll set offset_right based on ratio
	_momentum_bar_fill.anchor_bottom = 1.0
	_momentum_bar_fill.offset_left = 2.0
	_momentum_bar_fill.offset_top = 2.0
	_momentum_bar_fill.offset_right = 2.0
	_momentum_bar_fill.offset_bottom = -2.0
	_momentum_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_momentum_bar_bg.add_child(_momentum_bar_fill)
	# Threshold marker label.
	_momentum_threshold_label = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 12
	ts.font_color = Color(0.9, 0.85, 0.7)
	ts.outline_size = 3
	ts.outline_color = Color(0.05, 0.04, 0.02)
	_momentum_threshold_label.label_settings = ts
	_momentum_threshold_label.text = ""
	_momentum_threshold_label.anchor_left = 0.0
	_momentum_threshold_label.anchor_right = 1.0
	_momentum_threshold_label.anchor_top = -0.8
	_momentum_threshold_label.anchor_bottom = -0.8
	_momentum_threshold_label.offset_top = -14
	_momentum_threshold_label.offset_bottom = 2
	_momentum_threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_momentum_threshold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_momentum_bar_bg.add_child(_momentum_threshold_label)


func _on_momentum_changed_juice(value: float, capacity: int) -> void:
	if _momentum_bar_fill == null:
		return
	var ratio: float = clamp(value / max(1.0, float(capacity)), 0.0, 1.0)
	var fill_w: float = (_MOMENTUM_BAR_WIDTH - 4.0) * ratio
	_momentum_bar_fill.offset_right = 2.0 + fill_w
	# Color by threshold.
	var c: Color
	var label: String = ""
	if value >= 100.0:
		c = Color(1.5, 0.25, 0.15, 0.95)
		label = "FRENZY"
	elif value >= 66.0:
		c = Color(1.4, 0.65, 0.15, 0.92)
		label = "HEATED"
	elif value >= 33.0:
		c = Color(0.5, 1.2, 1.6, 0.88)
		label = "FOCUSED"
	else:
		c = Color(0.7, 0.7, 0.75, 0.85)
		label = ""
	_momentum_bar_fill.color = c
	if _momentum_threshold_label != null:
		_momentum_threshold_label.text = label


# Phase 6.3 — upgrade list panel. Top-right corner. Updates on grant.
const _UPGRADE_PANEL_WIDTH: float = 240.0
func _build_upgrade_panel() -> void:
	_upgrade_panel = ColorRect.new()
	_upgrade_panel.color = Color(0.05, 0.04, 0.03, 0.55)
	_upgrade_panel.anchor_left = 1.0
	_upgrade_panel.anchor_right = 1.0
	_upgrade_panel.anchor_top = 0.16
	_upgrade_panel.anchor_bottom = 0.16
	_upgrade_panel.offset_left = -_UPGRADE_PANEL_WIDTH - 12
	_upgrade_panel.offset_right = -12
	_upgrade_panel.offset_top = 0
	_upgrade_panel.offset_bottom = 100  # auto-fits via label
	_upgrade_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.visible = false  # only show when at least 1 upgrade owned
	add_child(_upgrade_panel)

	_upgrade_list_label = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 13
	ls.font_color = Color(1.0, 0.9, 0.7)
	ls.outline_size = 2
	ls.outline_color = Color(0.05, 0.04, 0.02)
	_upgrade_list_label.label_settings = ls
	_upgrade_list_label.anchor_left = 0.0
	_upgrade_list_label.anchor_right = 1.0
	_upgrade_list_label.anchor_top = 0.0
	_upgrade_list_label.anchor_bottom = 1.0
	_upgrade_list_label.offset_left = 8
	_upgrade_list_label.offset_right = -8
	_upgrade_list_label.offset_top = 6
	_upgrade_list_label.offset_bottom = -6
	_upgrade_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_list_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.add_child(_upgrade_list_label)


func _on_upgrade_granted_refresh(_upgrade_id: StringName) -> void:
	_refresh_upgrade_panel()


func _refresh_upgrade_panel() -> void:
	if _player == null or _upgrade_panel == null or _upgrade_list_label == null:
		return
	var upg = _player.get_node_or_null("UpgradeManager")
	if upg == null:
		return
	var owned: Array = upg.owned_list()
	if owned.is_empty():
		_upgrade_panel.visible = false
		return
	_upgrade_panel.visible = true
	var lines: Array[String] = ["⚡ UPGRADES"]
	for id in owned:
		var display: String = UpgradeManagerCls.display_name(StringName(id))
		lines.append("• " + display)
	_upgrade_list_label.text = "\n".join(lines)
	# Resize panel to fit content.
	var line_count: int = lines.size()
	var height: float = 18.0 + float(line_count) * 18.0
	_upgrade_panel.offset_bottom = height


# Need a reference to UpgradeManagerCls for display_name. Preload mirror.
const UpgradeManagerCls := preload("res://scripts/components/upgrade_manager.gd")


# Impact ring drawn as a stretched gib sprite (we already use this trick
# in the rat mega-explode). Cheap, no new asset.
func _spawn_impact_ring(world_pos: Vector2, color: Color, big: bool) -> void:
	var tex = SpriteGenerator.get_texture("ring_flash")
	if tex == null:
		tex = SpriteGenerator.get_texture("crystal_white")
	if tex == null:
		return
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.global_position = world_pos
	ring.modulate = Color(color.r, color.g, color.b, 0.7)
	ring.scale = Vector2(0.4, 0.4)
	ring.z_index = 6
	# Add to the world node (not the canvas layer) so it tracks the world.
	if _player != null:
		var world = _player.get_parent()
		if world != null:
			world.add_child(ring)
		else:
			add_child(ring)
	else:
		add_child(ring)
	var final_scale: float = 4.0 if big else 2.4
	var dur: float = 0.30 if big else 0.22
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(final_scale, final_scale), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, dur * 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(ring.queue_free)
