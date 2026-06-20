extends Node

## Integration tests for the revamp slice. Run with:
##   Godot --path . res://revamp/tests/revamp_test_runner.tscn --headless
## Exits non-zero if any test fails.

const StormcallerPlayer := preload("res://revamp/player/stormcaller_player.gd")
const Wraithling := preload("res://revamp/enemies/enemy_wraithling.gd")
const Cultist := preload("res://revamp/enemies/enemy_cultist.gd")
const Hexbinder := preload("res://revamp/enemies/enemy_hexbinder.gd")
const Tombwarden := preload("res://revamp/enemies/enemy_tombwarden.gd")
const WyrmAcolyte := preload("res://revamp/enemies/enemy_wyrm_acolyte.gd")
const PlaguebearerElite := preload("res://revamp/enemies/enemy_plaguebearer_elite.gd")
const EmberLord := preload("res://revamp/enemies/boss_ember_lord.gd")
const RevampItems := preload("res://revamp/items/revamp_items.gd")
const LootPickup := preload("res://revamp/items/loot_pickup.gd")
const RevampSaveAdapter := preload("res://revamp/progression/revamp_save_adapter.gd")

var _pass: int = 0
var _fail: int = 0
var _failures: Array = []
var _stage: Node


func _ready() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	await get_tree().process_frame
	await _run_all()
	_summary()
	get_tree().quit(0 if _fail == 0 else 1)


func _summary() -> void:
	print("\n========= REVAMP TEST SUMMARY =========")
	print("PASS: %d   FAIL: %d" % [_pass, _fail])
	if _fail > 0:
		for f in _failures:
			print("  ✗ ", f)
	else:
		print("  All tests passed.")
	print("=======================================")


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ✓ %s" % name)
	else:
		_fail += 1
		_failures.append("%s — %s" % [name, detail])
		print("  ✗ %s   %s" % [name, detail])


func _spawn_player(pos: Vector2 = Vector2.ZERO) -> Node:
	var p: Node = StormcallerPlayer.new()
	p.scripted = true
	_stage.add_child(p)
	p.global_position = pos
	return p


func _spawn_enemy(cls: Variant, pos: Vector2) -> Node:
	var e: Node = cls.new()
	_stage.add_child(e)
	e.global_position = pos
	return e


func _clear() -> void:
	for c in _stage.get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ============================================================
# TESTS
# ============================================================

func _run_all() -> void:
	print("Running revamp integration tests…\n")
	await _test_player_spawn_and_signals()
	await _test_charges_and_burst()
	await _test_arcane_bolt_hits_enemy()
	await _test_ability_cooldowns_independent()
	await _test_dodge_grants_iframes()
	await _test_potion_consumes_and_heals()
	await _test_crystal_ward_absorbs_damage()
	await _test_gravity_sigil_pulls_enemies()
	await _test_aether_step_repositions()
	await _test_tempest_damages_over_time()
	await _test_enemy_types_unique_stats()
	await _test_hexbinder_resistance_applies()
	await _test_tombwarden_takes_lightning_extra()
	await _test_wyrm_acolyte_heals_ally()
	await _test_plaguebearer_drops_toxic_pool()
	await _test_boss_phase_transitions()
	await _test_boss_death_signals()
	await _test_loot_drops_legendary_with_ability_mods()
	await _test_pickup_equips_and_modifies_build()
	await _test_save_load_persists_equipment()


func _test_player_spawn_and_signals() -> void:
	print("\n[player_spawn_and_signals]")
	await _clear()
	var p: Node = _spawn_player()
	await _wait(0.05)
	_ok("player in 'revamp_player' group", p.is_in_group("revamp_player"))
	_ok("starts at max HP", p.current_hp == p.max_hp, "%d vs %d" % [p.current_hp, p.max_hp])
	_ok("starts with 0 charges", int(p.charges) == 0)
	_ok("starts with all potions", int(p.potions) == int(p.POTION_CHARGES))
	_ok("has all 8 abilities registered", p.abilities.size() == 8, "got %d" % p.abilities.size())


func _test_charges_and_burst() -> void:
	print("\n[charges_and_burst]")
	await _clear()
	var p: Node = _spawn_player()
	p.gain_charge(3)
	_ok("gain_charge adds charges", int(p.charges) == 3)
	p.spend_all_charges()
	_ok("spend_all clears charges", int(p.charges) == 0)
	p.gain_charge(99)
	_ok("clamp at max", int(p.charges) == int(p.MAX_CHARGES))


func _test_arcane_bolt_hits_enemy() -> void:
	print("\n[arcane_bolt_hits_enemy]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	var e: Node = _spawn_enemy(Wraithling, Vector2(140, 0))
	await _wait(0.05)
	p.aim_dir = Vector2.RIGHT
	var hp_before: float = e.current_hp
	p.abilities[&"bolt"].use(Vector2.RIGHT)
	# Wait for projectile travel + hit
	await _wait(0.8)
	_ok("wraithling took bolt damage", e == null or not is_instance_valid(e) or e.current_hp < hp_before, "wraith hp %.1f → %.1f" % [hp_before, e.current_hp if is_instance_valid(e) else -1.0])


func _test_ability_cooldowns_independent() -> void:
	print("\n[ability_cooldowns_independent]")
	await _clear()
	var p: Node = _spawn_player(Vector2(-9000, -9000))  # off-stage so no damage
	p.gain_charge(5)
	# Use bolt and burst — bolt cd ~ 0.32, burst cd ~ 0.55. After 0.05s
	# both should be on cooldown.
	p.abilities[&"bolt"].use(Vector2.RIGHT)
	p.abilities[&"burst"].use(Vector2.RIGHT)
	await _wait(0.05)
	_ok("bolt cooldown active", not p.abilities[&"bolt"].can_use())
	_ok("burst cooldown active", not p.abilities[&"burst"].can_use())
	# Step still ready
	_ok("step independent (ready)", p.abilities[&"step"].can_use())
	_ok("tempest independent (ready)", p.abilities[&"tempest"].can_use())


func _test_dodge_grants_iframes() -> void:
	print("\n[dodge_grants_iframes]")
	await _clear()
	var p: Node = _spawn_player()
	p.set_meta("ward_until_ms", 0)  # ensure no ward
	# Trigger dodge via the player's helper (mimics SPACE press)
	p._start_dodge()
	# During iframe, take_damage should be a no-op
	var hp_before: float = p.current_hp
	p.take_damage(50.0, false)
	_ok("damage blocked during iframe", p.current_hp == hp_before, "hp went %.1f → %.1f" % [hp_before, p.current_hp])
	# Wait beyond iframe
	await _wait(0.40)
	p.take_damage(20.0, false)
	_ok("damage applies after iframe expires", p.current_hp < hp_before)


func _test_potion_consumes_and_heals() -> void:
	print("\n[potion_consumes_and_heals]")
	await _clear()
	var p: Node = _spawn_player()
	p.current_hp = 50.0
	var pots_before: int = int(p.potions)
	var hp_before: float = p.current_hp
	p.consume_potion()
	_ok("potion count decreased", int(p.potions) == pots_before - 1)
	_ok("HP increased", p.current_hp > hp_before, "%.1f → %.1f" % [hp_before, p.current_hp])
	# Drain potions and verify can_use returns false
	while int(p.potions) > 0:
		p.consume_potion()
	_ok("can't use potion when empty", not p.abilities[&"potion"].can_use())


func _test_crystal_ward_absorbs_damage() -> void:
	print("\n[crystal_ward_absorbs_damage]")
	await _clear()
	var p: Node = _spawn_player()
	p.abilities[&"ward"].use(Vector2.RIGHT)
	await _wait(0.10)
	var hp_before: float = p.current_hp
	p.take_damage(40.0, false)
	_ok("damage absorbed by ward (no HP loss)", p.current_hp == hp_before, "%.1f vs %.1f" % [hp_before, p.current_hp])
	# Verify ward stored value increased
	var stored: float = float(p.get_meta("ward_stored", 0.0))
	_ok("ward stored damage > 0", stored > 0.0, "stored=%.1f" % stored)


func _test_gravity_sigil_pulls_enemies() -> void:
	print("\n[gravity_sigil_pulls_enemies]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	var e: Node = _spawn_enemy(Wraithling, Vector2(150, 0))
	await _wait(0.05)
	p.aim_dir = Vector2.RIGHT
	# Cast sigil at the enemy position
	p.abilities[&"sigil"].use(Vector2.RIGHT)
	# Wait a tick for pull to apply
	var pos_before: Vector2 = e.global_position
	await _wait(0.5)
	_ok("enemy moved (pulled or pushed)", e.global_position.distance_to(pos_before) > 0.5, "Δ=%.2f" % e.global_position.distance_to(pos_before))


func _test_aether_step_repositions() -> void:
	print("\n[aether_step_repositions]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	p.aim_dir = Vector2.RIGHT
	var pos_before: Vector2 = p.global_position
	p.abilities[&"step"].use(Vector2.RIGHT)
	await _wait(0.02)
	_ok("player repositioned forward", p.global_position.distance_to(pos_before) > 100.0, "Δ=%.1f" % p.global_position.distance_to(pos_before))


func _test_tempest_damages_over_time() -> void:
	print("\n[tempest_damages_over_time]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	var e: Node = _spawn_enemy(Cultist, Vector2(120, 0))
	await _wait(0.05)
	p.aim_dir = Vector2.RIGHT
	var hp_before: float = e.current_hp
	p.abilities[&"tempest"].use(Vector2.RIGHT)
	await _wait(1.2)  # several ticks should fire
	_ok("tempest damaged enemy over time", not is_instance_valid(e) or e.current_hp < hp_before, "hp %.1f → %.1f" % [hp_before, e.current_hp if is_instance_valid(e) else -1.0])


func _test_enemy_types_unique_stats() -> void:
	print("\n[enemy_types_unique_stats]")
	await _clear()
	var w: Node = _spawn_enemy(Wraithling, Vector2(0, 0))
	var c: Node = _spawn_enemy(Cultist, Vector2(0, 0))
	var h: Node = _spawn_enemy(Hexbinder, Vector2(0, 0))
	var t: Node = _spawn_enemy(Tombwarden, Vector2(0, 0))
	await _wait(0.05)
	_ok("wraithling lowest hp", float(w.max_hp) < float(c.max_hp))
	_ok("tombwarden highest hp", float(t.max_hp) > float(c.max_hp) and float(t.max_hp) > float(w.max_hp))
	_ok("hexbinder has range > melee", float(h.attack_range) > float(c.attack_range))
	_ok("tombwarden slowest", float(t.move_speed) < float(w.move_speed) and float(t.move_speed) < float(c.move_speed))
	_ok("wraithling fastest", float(w.move_speed) > float(c.move_speed))
	_ok("families distinct", w.family != c.family and c.family != h.family and h.family != t.family)


func _test_hexbinder_resistance_applies() -> void:
	print("\n[hexbinder_resistance_applies]")
	await _clear()
	var h: Node = _spawn_enemy(Hexbinder, Vector2(0, 0))
	_ok("arcane resist < 1 (resist)", float(h.get_resistance(&"arcane")) < 1.0)
	_ok("physical resist > 1 (vuln)", float(h.get_resistance(&"physical")) > 1.0)
	_ok("neutral default 1.0", is_equal_approx(float(h.get_resistance(&"frost")), 1.0))


func _test_tombwarden_takes_lightning_extra() -> void:
	print("\n[tombwarden_takes_lightning_extra]")
	await _clear()
	var t: Node = _spawn_enemy(Tombwarden, Vector2(0, 0))
	_ok("lightning vuln > 1", float(t.get_resistance(&"lightning")) > 1.0)
	_ok("physical resist < 1", float(t.get_resistance(&"physical")) < 1.0)
	_ok("armor > 0", int(t.get_defense_stats().get("armor", 0)) > 0)


func _test_wyrm_acolyte_heals_ally() -> void:
	print("\n[wyrm_acolyte_heals_ally]")
	await _clear()
	var a: Node = _spawn_enemy(WyrmAcolyte, Vector2(0, 0))
	var c: Node = _spawn_enemy(Cultist, Vector2(80, 0))
	# Damage cultist so acolyte has a heal target
	c.current_hp = 20.0
	# Spawn a dummy player so acolyte has a foe and goes into pursue → attack
	var p: Node = _spawn_player(Vector2(600, 0))
	await _wait(0.05)
	# Call acolyte's heal directly (simulating release_attack)
	var hp_before: float = c.current_hp
	a._release_attack()
	await _wait(0.05)
	_ok("acolyte healed wounded ally", c.current_hp > hp_before, "%.1f → %.1f" % [hp_before, c.current_hp])


func _test_plaguebearer_drops_toxic_pool() -> void:
	print("\n[plaguebearer_drops_toxic_pool]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	var e: Node = _spawn_enemy(PlaguebearerElite, Vector2(120, 0))
	await _wait(0.05)
	# Force a pool drop
	e._drop_pool_at(p.global_position)
	await _wait(0.05)
	# Count toxic pools in the stage
	var found: bool = false
	for n in _stage.get_children():
		if "duration" in n and "damage_per_tick" in n:
			found = true
			break
	_ok("toxic pool spawned", found)
	_ok("elite has 'poison' resistance 0 (immune)", is_equal_approx(float(e.get_resistance(&"poison")), 0.0))


func _test_boss_phase_transitions() -> void:
	print("\n[boss_phase_transitions]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	var b: Node = _spawn_enemy(EmberLord, Vector2(220, 0))
	b.set_arena_center(Vector2(220, 0))
	await _wait(0.05)
	_ok("boss starts phase 1", int(b.phase) == 1)
	b.current_hp = b.max_hp * 0.5
	await _wait(0.10)
	_ok("phase 2 below 66%", int(b.phase) == 2, "phase=%d" % int(b.phase))
	b.current_hp = b.max_hp * 0.20
	await _wait(0.10)
	_ok("phase 3 below 33%", int(b.phase) == 3, "phase=%d" % int(b.phase))
	_ok("boss in 'revamp_boss' group", b.is_in_group("revamp_boss"))


func _test_boss_death_signals() -> void:
	print("\n[boss_death_signals]")
	await _clear()
	var b: Node = _spawn_enemy(EmberLord, Vector2(0, 0))
	b.set_arena_center(Vector2(0, 0))
	var got_pos: Array = []
	b.boss_died_at.connect(func(at: Vector2): got_pos.append(at))
	await _wait(0.05)
	b.take_damage(99999.0, true)
	await _wait(0.05)
	_ok("boss_died_at fired", got_pos.size() > 0)


func _test_loot_drops_legendary_with_ability_mods() -> void:
	print("\n[loot_drops_legendary_with_ability_mods]")
	var item: RefCounted = RevampItems.make_item("ember_circlet")
	_ok("loot item created", item != null)
	_ok("rarity is legendary (4)", int(item.rarity) == 4)
	_ok("has ability_mods", not item.ability_mods.is_empty())
	_ok("modifies bolt to twin", bool(item.ability_mods.get("bolt", {}).get("twin", false)))
	_ok("modifies burst with extra_wave", bool(item.ability_mods.get("burst", {}).get("extra_wave", false)))
	_ok("modifies step with damaging_trail", bool(item.ability_mods.get("step", {}).get("damaging_trail", false)))
	_ok("tooltip contains all three changes", item.tooltip_text().findn("Storm Burst") >= 0 and item.tooltip_text().findn("Aether Step") >= 0 and item.tooltip_text().findn("Arcane Bolt") >= 0)


func _test_pickup_equips_and_modifies_build() -> void:
	print("\n[pickup_equips_and_modifies_build]")
	await _clear()
	var p: Node = _spawn_player(Vector2(0, 0))
	# Pre-condition: bolt 'twin' off
	_ok("twin starts off", not bool(p.get_build_mod(&"bolt", "twin", false)))
	p.equip_item_by_id("ember_circlet")
	_ok("twin now on", bool(p.get_build_mod(&"bolt", "twin", false)))
	_ok("burst extra_wave now on", bool(p.get_build_mod(&"burst", "extra_wave", false)))
	_ok("step damaging_trail now on", bool(p.get_build_mod(&"step", "damaging_trail", false)))
	_ok("equipped_item_id updated", String(p.equipped_item_id) == "ember_circlet")
	_ok("max_hp increased by item stat (+80)", p.max_hp >= 460.0, "max_hp=%.1f" % p.max_hp)


func _test_save_load_persists_equipment() -> void:
	print("\n[save_load_persists_equipment]")
	await _clear()
	var p: Node = _spawn_player()
	p.equip_item_by_id("ember_circlet")
	var adapter: Node = RevampSaveAdapter.new()
	add_child(adapter)
	adapter.bind(p)
	adapter.save()
	# Now spawn a fresh player and load
	await _clear()
	var p2: Node = _spawn_player()
	var adapter2: Node = RevampSaveAdapter.new()
	add_child(adapter2)
	adapter2.bind(p2)
	var loaded: bool = adapter2.try_load()
	_ok("save loaded", loaded)
	_ok("equipment restored", String(p2.equipped_item_id) == "ember_circlet")
	_ok("ability mod restored on reload", bool(p2.get_build_mod(&"burst", "extra_wave", false)))
