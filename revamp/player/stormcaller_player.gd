extends CharacterBody2D

## Stormcaller — the revamp slice's playable hero. Arcane storm caster
## who builds Arcane Charges with the LMB generator and unleashes them with
## the RMB spender. Uses CombatManager.resolve_hit for damage so the existing
## typed pipeline still does the math.

signal hp_changed(current: float, maximum: float)
signal charges_changed(current: int, maximum: int)
signal potion_changed(current: int, maximum: int)
signal died()
signal cooldowns_changed(snapshot: Dictionary)
signal equipment_changed(item_id: String)
signal damage_received(amount: float, is_crit: bool)

const StormcallerVisual := preload("res://revamp/player/stormcaller_visual.gd")
const ArcaneBolt := preload("res://revamp/player/abilities/ability_arcane_bolt.gd")
const StormBurst := preload("res://revamp/player/abilities/ability_storm_burst.gd")
const AetherStep := preload("res://revamp/player/abilities/ability_aether_step.gd")
const CrystalWard := preload("res://revamp/player/abilities/ability_crystal_ward.gd")
const GravitySigil := preload("res://revamp/player/abilities/ability_gravity_sigil.gd")
const Tempest := preload("res://revamp/player/abilities/ability_tempest.gd")
const DodgeRoll := preload("res://revamp/player/abilities/ability_dodge.gd")
const Potion := preload("res://revamp/player/abilities/ability_potion.gd")

const MAX_HP := 380.0
const MAX_CHARGES := 5
const MOVE_SPEED := 260.0
const DODGE_SPEED := 820.0
const DODGE_DURATION := 0.32
const DODGE_IFRAME := 0.28
const POTION_CHARGES := 4
const POTION_HEAL := 0.55
const ACCEL := 1800.0
const DECEL := 2200.0
const CRIT_CHANCE := 0.18

@export var equipped_item_id: String = ""

var current_hp: float = MAX_HP
var max_hp: float = MAX_HP
var charges: int = 0
var potions: int = POTION_CHARGES
var aim_dir: Vector2 = Vector2.RIGHT

# Scripted-input mode used by the demo controller. When `scripted` is true,
# input vector / aim come from `scripted_move_vec` / aim_dir instead of from
# the keyboard / mouse. Lets the demo drive the slice headlessly.
var scripted: bool = false
var scripted_move_vec: Vector2 = Vector2.ZERO

var visual: Node
var abilities: Dictionary = {}
var _dodge_until_ms: int = 0
var _iframe_until_ms: int = 0
var _hit_invuln_until_ms: int = 0
var _dodge_dir: Vector2 = Vector2.ZERO
var _input_locked_until_ms: int = 0

# Build modifier — boss item changes a single ability's behavior.
var build_mods: Dictionary = {}


func _ready() -> void:
	add_to_group("revamp_player")
	add_to_group("player")  # so existing components that look for 'player' work
	collision_layer = 1
	collision_mask = (1 << 2) | (1 << 5)  # collide with environment + projectiles
	z_index = 4
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 48.0
	shape.shape = cap
	add_child(shape)
	visual = StormcallerVisual.new()
	visual.name = "Visual"
	add_child(visual)
	_register_abilities()
	hp_changed.emit(current_hp, max_hp)
	charges_changed.emit(charges, MAX_CHARGES)
	potion_changed.emit(potions, POTION_CHARGES)


func _register_abilities() -> void:
	for entry in [
		[&"bolt", ArcaneBolt],
		[&"burst", StormBurst],
		[&"step", AetherStep],
		[&"ward", CrystalWard],
		[&"sigil", GravitySigil],
		[&"tempest", Tempest],
		[&"dodge", DodgeRoll],
		[&"potion", Potion],
	]:
		var key: StringName = entry[0]
		var cls: Variant = entry[1]
		var inst: Node = cls.new()
		inst.name = "Ability_" + String(key)
		inst.set("owner_player", self)
		add_child(inst)
		abilities[key] = inst


func _physics_process(delta: float) -> void:
	if not scripted:
		_update_aim()
	var input_vec: Vector2 = scripted_move_vec if scripted else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var now: int = Time.get_ticks_msec()
	var in_dodge: bool = now < _dodge_until_ms
	if in_dodge:
		velocity = _dodge_dir * DODGE_SPEED
	elif now < _input_locked_until_ms:
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	else:
		var target_v: Vector2 = input_vec * MOVE_SPEED
		var rate: float = ACCEL if target_v.length_squared() > velocity.length_squared() else DECEL
		velocity = velocity.move_toward(target_v, rate * delta)
	move_and_slide()
	if visual and visual.has_method("set_move_state"):
		visual.set_move_state(velocity, aim_dir, in_dodge)
	_emit_cooldowns()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	# Mouse buttons drive generator/spender so the slice plays modern-ARPG.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_use(&"bolt")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_use(&"burst")
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_try_use(&"step")
			KEY_2:
				_try_use(&"ward")
			KEY_3:
				_try_use(&"sigil")
			KEY_4:
				_try_use(&"tempest")
			KEY_SPACE:
				_start_dodge()
			KEY_Q:
				_try_use(&"potion")


func _try_use(key: StringName) -> void:
	var ab: Node = abilities.get(key)
	if ab == null:
		return
	if not ab.has_method("can_use") or not ab.can_use():
		return
	if ab.has_method("use"):
		ab.use(aim_dir)


func _start_dodge() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _dodge_until_ms:
		return
	var ab: Node = abilities.get(&"dodge")
	if ab == null or not ab.has_method("can_use") or not ab.can_use():
		return
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length_squared() < 0.04:
		input_vec = aim_dir
	_dodge_dir = input_vec.normalized()
	_dodge_until_ms = now + int(DODGE_DURATION * 1000.0)
	_iframe_until_ms = now + int(DODGE_IFRAME * 1000.0)
	if ab.has_method("use"):
		ab.use(_dodge_dir)
	if visual and visual.has_method("play_dodge"):
		visual.play_dodge(_dodge_dir)


func _update_aim() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var canvas_xform := vp.get_canvas_transform()
	var mouse: Vector2 = (canvas_xform.affine_inverse() * vp.get_mouse_position())
	var d: Vector2 = mouse - global_position
	if d.length_squared() > 25.0:
		aim_dir = d.normalized()


func get_aim_dir() -> Vector2:
	return aim_dir


# === Resource manipulation called by abilities ===

func can_gain_charge() -> bool:
	return charges < MAX_CHARGES


func gain_charge(n: int = 1) -> void:
	charges = clampi(charges + n, 0, MAX_CHARGES)
	charges_changed.emit(charges, MAX_CHARGES)


func spend_charges(n: int) -> int:
	var spent: int = clampi(n, 0, charges)
	charges -= spent
	charges_changed.emit(charges, MAX_CHARGES)
	return spent


func spend_all_charges() -> int:
	var n: int = charges
	charges = 0
	charges_changed.emit(charges, MAX_CHARGES)
	return n


func consume_potion() -> bool:
	if potions <= 0:
		return false
	potions -= 1
	potion_changed.emit(potions, POTION_CHARGES)
	heal(max_hp * POTION_HEAL)
	return true


# === Damage / death ===

func take_damage(amount: float, is_crit: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _iframe_until_ms or now < _hit_invuln_until_ms:
		return
	# Defensive ward absorption (Crystal Ward sets meta "ward_until_ms")
	if has_meta("ward_until_ms") and now < int(get_meta("ward_until_ms")):
		var stored: float = float(get_meta("ward_stored", 0.0))
		set_meta("ward_stored", stored + amount)
		return
	current_hp = maxf(0.0, current_hp - amount)
	_hit_invuln_until_ms = now + 220
	hp_changed.emit(current_hp, max_hp)
	damage_received.emit(amount, is_crit)
	if visual and visual.has_method("flash_hit"):
		visual.flash_hit()
	if current_hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)


func heal_full() -> void:
	current_hp = max_hp
	potions = POTION_CHARGES
	hp_changed.emit(current_hp, max_hp)
	potion_changed.emit(potions, POTION_CHARGES)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	heal_full()
	charges = 0
	charges_changed.emit(charges, MAX_CHARGES)


func lock_input(seconds: float) -> void:
	_input_locked_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


# === Equipment ===

func equip_item_by_id(item_id: String) -> void:
	equipped_item_id = item_id
	_apply_build_mods()
	equipment_changed.emit(item_id)


func _apply_build_mods() -> void:
	build_mods.clear()
	const RevampItems := preload("res://revamp/items/revamp_items.gd")
	var item: Dictionary = RevampItems.get_item(equipped_item_id)
	if item.is_empty():
		return
	if item.has("ability_mods"):
		build_mods = item["ability_mods"].duplicate(true)
	# Apply stat bumps
	var stats: Dictionary = item.get("stats", {})
	if stats.has("max_hp"):
		max_hp = MAX_HP + float(stats["max_hp"])
		current_hp = min(current_hp, max_hp)
		hp_changed.emit(current_hp, max_hp)


func get_build_mod(ability_key: StringName, mod_key: String, default_value: Variant = null) -> Variant:
	if not build_mods.has(String(ability_key)):
		return default_value
	var d: Dictionary = build_mods[String(ability_key)]
	return d.get(mod_key, default_value)


# === Helpers exposed to abilities ===

func crit_roll() -> bool:
	return randf() < CRIT_CHANCE


func make_hit_event(damage_type: StringName, ability_id: StringName, multiplier: float, target: Node) -> Resource:
	const HitEventCls := preload("res://scripts/combat/hit_event.gd")
	var ev: Resource = HitEventCls.new()
	ev.attacker = self
	ev.victim = target
	ev.attack_id = ability_id
	ev.damage_type = damage_type
	ev.ability_multiplier = multiplier
	ev.direction = aim_dir
	ev.weight = 2  # HEAVY
	return ev


func resolve_damage(target: Node, damage_type: StringName, ability_id: StringName, base: float, multiplier: float = 1.0, force_crit: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var atk_stats: Dictionary = {
		"primary_stat": "intelligence",
		"attack_damage": int(base),
		"intelligence": 18,
		"agility": 6,
		"strength": 4,
		"weapon_damage": 0,
	}
	var def_stats: Dictionary = {"armor": 0}
	if target.has_method("get_defense_stats"):
		def_stats = target.get_defense_stats()
	var ev: Resource = make_hit_event(damage_type, ability_id, multiplier, target)
	ev.force_crit = force_crit or crit_roll()
	if Engine.has_singleton("CombatManager") or CombatManager != null:
		CombatManager.resolve_hit(ev, atk_stats, def_stats)
	elif target.has_method("take_damage"):
		target.take_damage(int(base * multiplier), force_crit)


func _emit_cooldowns() -> void:
	var now_s: float = Time.get_ticks_msec() * 0.001
	var snap: Dictionary = {}
	for key in abilities.keys():
		var ab: Node = abilities[key]
		if ab and ab.has_method("get_cooldown_state"):
			snap[key] = ab.get_cooldown_state(now_s)
	cooldowns_changed.emit(snap)
