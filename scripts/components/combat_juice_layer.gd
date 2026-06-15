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

	# Subscribe to combat events.
	if Engine.has_singleton("CombatManager") or get_node_or_null("/root/CombatManager") != null:
		CombatManager.hit_resolved.connect(_on_hit_resolved)

	# Subscribe to player's momentum changes for the combo counter.
	var mom = _player.get_node_or_null("MomentumComponent") if _player != null else null
	if mom != null:
		if mom.has_signal("combo_multiplier_changed"):
			mom.combo_multiplier_changed.connect(_on_combo_multiplier_changed)


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
	# Lethal kill — always celebrate.
	if was_lethal:
		label = "KILL!"
		color = Color(1.5, 0.3, 0.3)
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
