extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $Panel/MarginContainer/VBox/TopBar/CloseButton
@onready var scroll: ScrollContainer = $Panel/MarginContainer/VBox/Scroll
@onready var entries_container: VBoxContainer = $Panel/MarginContainer/VBox/Scroll/Entries
@onready var version_label: Label = $Panel/MarginContainer/VBox/TopBar/VersionLabel

var _is_visible: bool = false
var _is_mobile: bool = false

const GAME_VERSION := "v0.86.2"

const CHANGELOG: Array[Dictionary] = [
	{
		"version": "v0.86.2",
		"title": "Combat overhaul — Phase 3.1/3.3 telegraph polish + AttackCoordinator danger budget + per-enemy variety",
		"date": "2026-06-15",
		"entries": [
			"ATTACK COORDINATOR. The global danger budget caps simultaneous attackers at 5 tokens. Light enemies (rat/skeleton/goblin) cost 1; medium (bandit/wolf/spider) cost 2; heavy (troll/ogre) cost 3; mini-bosses cost 4. A pack of 8 enemies can now apply real pressure WITHOUT all swinging at you at once — most circle and threaten while 2-3 wind up.",
			"PER-ENEMY ATTACK VARIETY. Wind-up time now encodes enemy identity: rat 0.18s (jab), skeleton/goblin 0.32s, bandit/wolf 0.40s, dark_mage/lich 0.50s, troll/ogre 0.65s (huge telegraph), mini-boss 0.75s. Heavies also lean back further (lean_dist 8 vs 4) and squash more dramatically (1.25 × 0.78 vs 1.18 × 0.85).",
			"TELEGRAPH SEVERITY COLOR. Yellow for light enemies (you'll react fine), orange for medium (be careful), deep red for heavy (the BIG one), magenta for mini-bosses (boss-tier visual). Telegraph bar thickness also scales with cost so heavy attacks LOOK wide on the ground. Glance-readable in a busy fight.",
			"Tokens release on: attack complete, stagger (heavy hit interrupt), enemy death mid-windup. Nothing leaks. If denied a token, the enemy defers half a cooldown and tries again — keeps them mobile instead of frozen.",
			"Internal: static var _attack_tokens_used on Enemy class (shared state, no autoload). _try_reserve_attack_token / _release_attack_token. _get_windup_sec / _get_token_cost / _get_telegraph_severity_color return per-sprite_type values. _process_attack consults the coordinator before _begin_attack_windup.",
		]
	},
	{
		"version": "v0.86.1",
		"title": "Combat overhaul — perfect-dodge COUNTER WINDOW + universal mega-explode",
		"date": "2026-06-15",
		"entries": [
			"PERFECT-DODGE COUNTER WINDOW: nailing a perfect dodge now opens a 1-second counter window. ALL damage during the window is ×1.6, the kill-chain auto-targets the attacker for free retarget, sprite tints cyan, gold 'COUNTER!' floats above the player, and a brief global Engine.time_scale dip (0.35× for 90 ms) cinematically punctuates the moment. Stacks with momentum thresholds and frenzy — a perfect-dodge counter in Frenzy is monstrous.",
			"UNIVERSAL MEGA-EXPLODE: every non-rat enemy now has a chance to detonate on death. Base 4% rate, +8% on crit kill, +12% on overkill (so a big hit at low enemy HP can hit 24% chance).",
			"On trigger: 8-14 blood splatters, 40-70 gibs flying outward with arcing physics, sprite white-flash → deep red wash + 4.5× scale → flatten and explode, expanding red shockwave ring to 18× scale, screen shake 14, brief global time dip (0.25× for 90 ms). Smaller than the rat MEGA (which keeps its 10× signature spectacle) but big enough to make ANY kill potentially memorable.",
			"Combined gameplay loop: perfect-dodge → counter window opens → land an EXECUTION variant C-finisher at ×1.6 → universal mega-explode triggers → cascading carnage. The kind of moment players replay clips of.",
			"Internal: player.gd _counter_window_until_usec / _is_counter_window_active(); _on_perfect_dodge_executed sets the window + locks kill_chain to nearest attacker + tints sprite + spawns counter pop + dispatches global dip. _run_clocked_attack multiplies damage_mult by 1.6 when window active. enemy.gd _play_death_animation rolls universal_mega_chance before the per-sprite death table.",
		]
	},
	{
		"version": "v0.86.0",
		"title": "Combat overhaul — Phase 3.0a enemy attack telegraphs + momentum lifesteal",
		"date": "2026-06-15",
		"entries": [
			"BIGGEST GAMEPLAY UPGRADE YET. Enemies no longer attack instantly — every melee attack now has a 0.35 s anticipation phase before the strike resolves.",
			"During wind-up the enemy sprite leans back, squashes (1.18 × 0.85 scale), turns warning red, and a thin red ground arc grows toward you showing the strike path. Plenty of time to dodge or interrupt with a heavy hit.",
			"Staggering an enemy mid-wind-up cancels the strike entirely — no damage. This is the moment perfect-dodge and dodge-time become real skills, not just reaction reflexes.",
			"LIFESTEAL AT HIGH MOMENTUM: every confirmed hit while HEATED restores +2 HP; while FRENZY, +4 HP. Aggressive play actively sustains you. Encourages keeping the combo going instead of disengaging to heal.",
			"Internal: enemy.gd's _process_attack now splits into anticipation → strike → recovery via _WINDUP_SEC threshold check on the existing _attack_timer. _begin/_end/_cancel_attack_windup helpers manage sprite tween + ground telegraph arc. Cancel hook wired to stagger so staggered enemies drop their wind-up cleanly. Lifesteal: _on_hit_resolved_for_momentum reads MomentumComponent.current_threshold_name and increments stats.current_hp.",
		]
	},
	{
		"version": "v0.85.5",
		"title": "Combat overhaul — Phase 2.12 combat pickups (momentum / health / cooldown orbs)",
		"date": "2026-06-15",
		"entries": [
			"ENEMIES NOW DROP PICKUPS. Kill them to find: momentum orbs (gold, ~14% rate, +15 momentum), health shards (red, ~6% rate, +20 HP), cooldown orbs (cyan, ~1.5% rate, instantly clears dodge cooldown).",
			"Mini-bosses guarantee a momentum orb plus 50% health + 30% cooldown rolls.",
			"Pickups bob in place, glow with a pulse loop, eject from the corpse with a small arc. Magnetize to you within ~90 px; auto-collect at ~14 px. Last 9 seconds, then fade out cleanly.",
			"Collecting a momentum orb mid-combat can push you over the FOCUSED / HEATED / FRENZY threshold, triggering the empowered states without earning every point through hits. Cooldown orb gives you a free dodge mid-encounter — clutch.",
			"Internal: scripts/components/combat_pickup.gd (Area2D, programmatic; no .tscn needed). enemy.gd._roll_combat_pickup independent rolls per type. Cleanup via lifetime expiry — no global cap because the natural drop rate keeps the field uncluttered.",
		]
	},
	{
		"version": "v0.85.4",
		"title": "Combat overhaul — Phase 2.9 context-sensitive C-finisher variants",
		"date": "2026-06-15",
		"entries": [
			"C-FINISHER NOW HAS VARIANTS. Same input → different drama based on what the player set up.",
			"EXECUTION (target HP ≤ 25%): deep red ring expansion, +4 screen-shake, bonus damage = 30% of target's max HP (capped at 60), +8 momentum. Low-HP kills feel like a death blow, not just another swing.",
			"GROUND_SLAM (target poise broken / vulnerable): orange ring + radial AoE knockback + poise on all enemies within 80 px. Punishes when you've just broken a tank — the finisher cleaves the group.",
			"MARKED_BURST (target has EXPOSED status from a previous C/slam): gold ring + extra 20 poise damage + 5 momentum. Rewards the A→B→C → C combo chain.",
			"Default C unchanged.",
			"Internal: _select_finisher_variant inspects target.StatusEffectComponent (exposed), .PoiseComponent (is_vulnerable), and .stats (HP ratio). _apply_finisher_variant dispatches per-variant VFX/damage/momentum. Picked at the moment of contact so the variant reflects the actual hit state, not the swing-start state.",
		]
	},
	{
		"version": "v0.85.3",
		"title": "Combat overhaul — Phase 2.10 kill-chain auto-retarget",
		"date": "2026-06-15",
		"entries": [
			"COMBAT FEEL: combos no longer die when their target dies. Kill an enemy and the next swing within 400 ms automatically locks onto the nearest survivor within 160 px.",
			"On the killing blow, a brief orange chain-arc draws from the corpse to the next target so the link is readable. Bonus +5 momentum on the chain.",
			"Combined with magnetism (2.1), this means: swing → kill → swing again → next kill → swing again → … the combo keeps flowing through a pack without manual retargeting.",
			"Window is short (400 ms) so it ONLY catches 'the next swing'. It doesn't lock indefinitely — if you delay, the next attack picks the normal directional target.",
			"Internal: player.gd gains _kill_chain_target / _kill_chain_expires_usec, _set_kill_chain_target / _consume_kill_chain_target / _spawn_kill_chain_arc. MomentumComponent adds public add_bonus(amount, reason). _try_manual_attack consults the chain target before the mouse target / directional scoring fallback.",
		]
	},
	{
		"version": "v0.85.2",
		"title": "Combat overhaul — Phase 2.8 momentum thresholds + variety bonus",
		"date": "2026-06-15",
		"entries": [
			"MOMENTUM NOW PAYS OFF. Three thresholds with real mechanical effects, not just visual aura.",
			"FOCUSED (33+): attacks are 5% faster (clock duration × 0.95). Cool, controlled.",
			"HEATED (66+): attacks are 10% faster AND every 4th hit fires a free shockwave at the impact — 14 damage + 6 poise + knockback to all enemies within 110 px. Expanding orange ring VFX, screen shake, impact audio.",
			"FRENZY (100): for 6 SECONDS, attacks are 15% faster, all damage ×1.2, ambient momentum decay suppressed, the screen-edge aura goes full red, brief global Engine.time_scale dip on entry (0.25× for 130 ms), banner pulses 'FRENZY' top-center. The shockwave chain still fires every 4 hits. Frenzy ends → momentum capped to 66 so you have to earn it back.",
			"VARIETY BONUS: spamming the same attack now gives diminishing momentum (÷1.4 per repeat in last 4). Using 4 different attacks in a row gives ×1.4 variety bonus. Encourages mixing A→B→C→branch / specials.",
			"Internal: MomentumComponent gains threshold state machine, frenzy timer (wall-clock deadline), variety bonus (rolling window of last 4 attack_ids), heated_shockwave_ready signal. player.gd applies duration_mult to AttackClock + ability_multiplier × damage_mult; subscribes to threshold + shockwave + frenzy signals. Juice layer shows FOCUSED!/HEATED!/FRENZY! pop-ups and a persistent FRENZY banner during empowered state.",
		]
	},
	{
		"version": "v0.85.1",
		"title": "Combat plan — Fun & Combat Depth roadmap (docs only)",
		"date": "2026-06-15",
		"entries": [
			"Docs only. No gameplay changes.",
			"COMBAT_IMPROVEMENT_PLAN.md gains §5c — Fun & Combat Depth: 17 systems (F1–F17) that turn combat into observed decisions with surprising rewards, not just smoother responsiveness.",
			"Cross-mapped against the user's 19 design categories. Identified what's already shipped (momentum, magnetism, dodge, perfect-dodge reward, status interactions, juice layer) vs what's genuinely new (context-sensitive finishers, kill-chain retarget, temporary OP states, combat pickups, encounter modifiers, challenge rooms, behavior-changing upgrade choices, weapon-style identity, adaptive intensity, reactive music, dev sandbox).",
			"Re-tagged future phases with 7 design axes: Responsiveness, Impact, Decisions, Pressure, Build, Encounters, Replayability.",
			"Revised execution order: 0b sandbox scene FIRST (dev iteration multiplier), then F1/F2 momentum thresholds + variety, F3 finisher variants, F4 kill-chain retarget, F5 Frenzy/Berserk, F6 pickups, F9 risk/reward. Then Phase 3 enemy timelines + roles + encounters.",
			"For every system: why it makes combat MORE FUN (not just smoother), smallest viable, dependencies, required Resources/components/signals, acceptance criteria, performance risk, save-format impact.",
			"Save additive only: best_combo_streak (optional), attack_upgrades, cleared_encounters. No new global autoloads (MusicDirector candidate in Phase 5.5 only).",
		]
	},
	{
		"version": "v0.85.0",
		"title": "Combat juice — pop-up labels, combo counter, momentum aura, bigger slashes",
		"date": "2026-06-15",
		"entries": [
			"FLOATING POP-UPS on every meaningful hit. KILL! / DEVASTATING! / CRIT! / FINISHER! / SLAM! / LIFT! / SPIN! / CHARGED! / WHIRLWIND! / POWER! Each colour-coded and sized for impact. Floats up over 0.85 s.",
			"COMBO COUNTER top-center of screen. Shows '1.3x COMBO' (etc.) — pulses on each hit, font scales with multiplier, fades after the combo decays.",
			"MOMENTUM AURA: when momentum ≥ 60, the player gains a warm golden glow that pulses slowly and intensifies with each landed hit. Fades out cleanly when momentum drops.",
			"IMPACT RING on every confirmed hit — a quick radial flash at the point of impact, colored by hit type. Bigger and longer for crits / lethal hits.",
			"BIGGER SLASH ARCS: basic swings A/B are 35% larger. Finisher C is now a 3-arc fan (main + two side blades). Spin E is now a SIX-arc explosion covering 360°. Slam still gets its bonus impact ring on top.",
			"Internal: new scripts/components/combat_juice_layer.gd (CanvasLayer child of player, subscribes to CombatManager.hit_resolved + MomentumComponent.combo_multiplier_changed). Player has a new _momentum_aura sprite tied to momentum_changed. No new pools, no save changes.",
		]
	},
	{
		"version": "v0.84.7",
		"title": "🐀💥💥 RATS EXPLODE × 10, gore now sticks to the player",
		"date": "2026-06-14",
		"entries": [
			"10× the carnage. 150–220 gibs (was 15–22), force 120–320 px reach (was 45–95), 25–40 blood splatters scattered (was 4–6).",
			"DOUBLE shockwave ring — fast primary scaling to 24× then slower secondary to 32× for depth.",
			"Player gore-coat: 20–32 extra gibs fly directly to the player when nearby, REPARENT to the player sprite on impact, and stick / follow movement for 3–5 seconds before fading. You will look like you murdered a rat king with your bare hands.",
			"Screen shake bumped to 18.0 (was 7.5) with 900 px range (was 600).",
			"Time dip: 0.20× for 110 ms (was 0.35× for 70 ms) — heavier punctuation. Still attack_id-deduped via HitStopController so swarm wipeouts don't stutter.",
			"Audio: louder crit_hit at +5 dB followed by a 60 ms later hit_impact for the wet 'BOOM-splat' feel.",
			"Sprite explosion scales 6× then stretches flat at 7× before vanishing.",
		]
	},
	{
		"version": "v0.84.6",
		"title": "🐀💥 RATS EXPLODE",
		"date": "2026-06-14",
		"entries": [
			"12% chance per rat death: full mega-explosion. 15–22 chunky gibs flying outward with arcing physics, 4–6 blood splatters, expanding red shockwave ring, bright white pop into deep red wash, big screen shake (only if a player is nearby), and a brief global time dip (70 ms @ 0.35×) routed through HitStopController so concurrent rat explosions coalesce into one dip.",
			"Independent of the crit-explode roll — even a tiny tap can trigger it. Rare cathartic moment, not every-rat-stutter.",
			"Internal: _die_rat_mega_explode + _spawn_rat_gibs_mega. Reuses existing SpriteGenerator textures (ring_flash with rat_gib fallback) and HitStopController's attack_id dedupe so a swarm wipeout still produces ONE dip.",
		]
	},
	{
		"version": "v0.84.5",
		"title": "Combat overhaul — Phase 2.6/2.7 status effects + apply→consume interaction (Phase 2 COMPLETE)",
		"date": "2026-06-14",
		"entries": [
			"NEW COMBAT LOOP: A→B→C-finisher (or slam) now applies EXPOSED to the target — a 3-second vulnerability marker. The enemy pulses warm orange while exposed. Any special (power strike, charged slash, dash strike) hitting an exposed enemy CONSUMES the mark for +50% damage.",
			"The full rhythm: build with A/B, finisher applies exposed, IMMEDIATELY follow up with a special for the empowered hit. This is the satisfying 'set up the kill' loop the design has been building toward.",
			"Charged slash on exposed boss enemies deals roughly 60 base + 90 (50% bonus) = 150 damage — meaningfully bigger than spamming basics.",
			"Internal: StatusEffectData Resource (id, duration, tick_interval, per_tick_damage, stack_rule, stack_cap, tier). Presets baked in: exposed, bleed, mark. StatusEffectComponent on every enemy: apply / consume / consume_first_tier / stack stacking up to cap / DoT tick processing via wall-clock. AttackTimingData gains apply_status and consume_status_tier + consume_damage_mult fields. CombatManager.resolve_hit consumes BEFORE damage compute (so multiplier scales) and applies AFTER take_damage (so dead targets aren't marked).",
			"Phase 2 COMPLETE: poise → magnetism → directional functions → dodge + i-frames → momentum → perfect-dodge reward → status interactions. Phase 3 (enemy attack timelines + telegraphs + coordinator) is next.",
			"Smoke: +20 status checks (presets, apply/has/consume, stacking, clear_all, AttackTimingData fields).",
		]
	},
	{
		"version": "v0.84.4",
		"title": "Combat overhaul — Phase 2.4/2.5 Momentum + perfect-dodge reward",
		"date": "2026-06-14",
		"entries": [
			"COMBAT FEEL: combat is now a build-and-spend rhythm. Every confirmed hit credits momentum; varied attacks (A→B→C, branches, specials) build it fast. Taking damage drains 25 and resets your combo multiplier. Kills refund 5. Capacity 100.",
			"Per-attack grants: A=5, B=8, C-finisher=15, slam=20, uppercut=15, spin=12, D-thrust=12, E-spin=10, power_strike=15, whirlwind=8/target, charged_slash=25, sniper_shot=22, dash_strike=10. Crits multiply grants by 1.3×.",
			"Combo multiplier sits in [1.0, 2.0]: +0.1 per hit, decays after 1.2 s no-hit window. Resets on damage.",
			"PERFECT-DODGE REWARD (2.5): a perfect dodge (hit landed in the first 80 ms of dodge) now refunds 40 momentum AND freezes every enemy within 130 px for 220 ms via HitStopController. Plenty of room to counter-attack into a free combo.",
			"Internal: MomentumComponent on player. CombatManager.hit_resolved subscriptions credit grants when WE are the attacker, kill credit on result.was_lethal. take_damage drains. UI bar deferred to Phase 6.1. Specials NOT yet gated on momentum — we want to feel the curve before adding friction.",
			"Smoke: +21 momentum checks covering per-attack grants, crit bonus, damage drain + combo reset, kill credit, perfect-dodge grant, try_spend gating, capacity + combo caps.",
		]
	},
	{
		"version": "v0.84.3",
		"title": "Combat overhaul — Phase 2.3 dodge action with i-frames + perfect-dodge detection",
		"date": "2026-06-14",
		"entries": [
			"NEW INPUT: Shift (keyboard) or B / right-stick-press (controller) now dodges. 220 ms of i-frames absorb incoming damage. 250 ms total dodge distance with a punchy ease-out curve.",
			"Perfect-dodge window: the first 80 ms of the dodge fires a perfect_dodge_executed signal when a hit lands. Detection only — Phase 2.5 wires the reward (momentum refund + brief attacker slow). Lets you start play-testing the dodge feel now without the gameplay-incentive complexity.",
			"350 ms cooldown between dodges prevents spamming. Dodge direction follows movement input; falls back to facing when standing still. Player retains sole ownership of CharacterBody2D.velocity — the controller only provides a velocity overlay the player applies.",
			"Internal: DodgeController Node + DodgeData Resource. player.gd creates it in _ready. take_damage consults on_incoming_hit before any damage path runs — i-frames absorb cleanly, perfect-dodge emit happens transparently.",
			"Smoke: +16 dodge checks (start, iframes, perfect window, velocity overlay, cooldown, force_reset).",
		]
	},
	{
		"version": "v0.84.2",
		"title": "Combat overhaul — Phase 2.2 directional attacks have real mechanical roles",
		"date": "2026-06-14",
		"entries": [
			"COMBAT FEEL: directional branches now do something distinct beyond just animation variation.",
			"SLAM (horizontal→down or up→down): plus a radial AoE — every enemy within 80 px of the impact takes knockback 60 + 6 poise damage. Adds a satisfying ground hit visual.",
			"UPPERCUT (down→up or anything→up): visible vertical lift on the locked target via HitReactionComponent (recoil pushed straight up).",
			"SPIN (any→diagonal, vertical→horizontal): chips 8 poise damage off every enemy within 100 px — crowd-control softener that sets up the rest of your combo to break the group.",
			"Internal: _resolve_attack_id maps swing_idx + directional context to branch_slam / branch_uppercut / branch_spin vs the underlying swing_c / swing_d / swing_e. The clock wrappers capture rhythm_class and run branch effects after the main contact callback. AttackTimings.branch_slam (+20 poise base), branch_uppercut (+15), branch_spin (+10) already shipped in 2.0; this commit makes them actually fire.",
			"Specials and natural A→B→C finisher unchanged — directional functions only fire when a directional branch was actually picked.",
		]
	},
	{
		"version": "v0.84.1",
		"title": "Combat overhaul — Phase 2.1 attack magnetism + lean-in motion",
		"date": "2026-06-14",
		"entries": [
			"COMBAT FEEL: every basic swing (A/B/C/D/E) now leans the player slightly toward the locked target on contact, and biases the swing direction toward the enemy. No more swings that 'stop just outside contact range'.",
			"Aim bias: 0.45 for A/B, 0.55 for C-finisher/D/uppercut/slam — the swing arcs onto the enemy even if the stick / mouse was a few degrees off. Spin (E) only 0.30 — spins are meant to pivot, not lock.",
			"Lean-in motion: 18 px for A/B, 22–30 px for C/D/uppercut/slam. Only fires when the target is at least 18 px beyond contact range (no slide-past). Raycast against walls — never pushes the player through geometry.",
			"Specials and charged slash unchanged — they already do their own physics-aware movement.",
			"Internal: AttackMotionData Resource per rhythm class. player.gd's _apply_attack_motion runs at the start of each basic swing in _do_melee_attack and returns the biased direction. Uses a short Tween on global_position with collision raycast. CharacterBody2D.velocity / move_and_slide() ownership unchanged.",
		]
	},
	{
		"version": "v0.84.0",
		"title": "Combat overhaul — Phase 2.0 Poise & stagger break",
		"date": "2026-06-14",
		"entries": [
			"COMBAT FEEL MILESTONE — Phase 2 begins. The A→B→C combo and charged slash now feel like they're WORKING on the enemy, not just dealing damage. Hits build toward a satisfying break.",
			"Every enemy now has a poise pool (LIGHT 15, MEDIUM 40, HEAVY 80, ELITE 120, BOSS 300). Attacks chip poise. When it hits zero the enemy enters a brief vulnerability window — visibly deeper recoil, AI frozen, can't attack — before recovering with brief post-break immunity so chained attacks can't perma-stagger.",
			"Poise damage per attack: A=5, B=6, C-finisher=15, D=12, E=10/hit, branch_slam=20, branch_uppercut=15, power_strike=25/target, whirlwind=8/target, charged_slash=40 (boss-break tool), sniper_shot=30. Crits multiply poise damage by 1.5.",
			"Tier behaviors: LIGHT enemies break to a single A→B→C combo (~26 poise vs 15 cap). MEDIUM needs A→B→C + a heavy or 2 combos. HEAVY needs heavy attacks or charged. ELITE shrugs off light attacks entirely (heavy_only). BOSS has 300 pool, 60% poise resistance, takes ~6+ heavy hits to break (vulnerability windows).",
			"Internal: PoiseComponent (wall-clock regen + monotonic break window + post-break immunity), PoiseProfile Resource with tier presets, poise_damage field on AttackTimingData. CombatManager.resolve_hit routes poise damage to victim's PoiseComponent automatically. Smoke now covers 16 poise scenarios.",
		]
	},
	{
		"version": "v0.83.35",
		"title": "Combat plan — expanded roadmap for Phases 2/3/5/6 (docs only)",
		"date": "2026-06-14",
		"entries": [
			"Docs only. No gameplay changes.",
			"COMBAT_IMPROVEMENT_PLAN.md expanded with 11 future systems: attack magnetism + motion (2.1), directional attack mechanics (2.2), poise & stagger break (2.0), DodgeController + perfect-dodge detection (2.3), Momentum resource (2.4), perfect-dodge reward (2.5), status effect framework + interactions (2.6/2.7), enemy attack timelines + telegraphs (3.0–3.2), per-encounter AttackCoordinator + roles (3.3–3.4), boss vulnerability windows (3.5), EncounterData + SpawnDirector + hazards (3.6/3.7), death & execution feedback per killing attack (5.0), behavior-changing upgrades (6.2).",
			"Each system has: smallest viable scope, dependencies, required Resources/components/signals, acceptance criteria, performance risk note, save-format impact. Two save schema additions identified (cleared_encounters, attack_upgrades) — both additive with default [].",
			"Architectural guard-rails preserved: no new global autoloads, no god-script growth, body-velocity ownership stays with each CharacterBody2D script, motion requests stay request-based, enemy decisions tick ≥ 200 ms.",
		]
	},
	{
		"version": "v0.83.34",
		"title": "Combat overhaul — Phase 1B.6f directional camera shake",
		"date": "2026-06-14",
		"entries": [
			"VISIBLE CHANGE: camera shake now PUNCHES toward where the hit lands instead of bouncing radially. Combined with the trauma model this makes every hit feel like a real impact landing on the enemy rather than a screen-wide jitter.",
			"player.gd: _last_hit_direction is captured at the moment of contact for every basic swing (via _run_clocked_attack) and at the start of every special / charged / dash strike / ranged special. CameraShake2D blends this direction into the trauma vector so the shake leans toward the enemy.",
			"Radial fallback preserved: if no direction is set (e.g. enemy attacks on the player) the shake stays radial.",
		]
	},
	{
		"version": "v0.83.33",
		"title": "Combat overhaul — Phase 1B.6e enemy stagger interrupts attacks",
		"date": "2026-06-14",
		"entries": [
			"VISIBLE CHANGE: heavy hits now INTERRUPT enemy attacks. A C-finisher, D thrust, E spin, or any special / charged / crit landing on a mid-attack light or medium enemy cancels their swing — they stagger briefly, then re-evaluate state instead of resuming the attack.",
			"enemy.gd: connected HitReactionComponent.stagger_requested + stagger_ended. On stagger, current attack timer is reset and freeze is extended to the stagger duration so AI ticks are skipped for the full window. On stagger_ended, ATTACK state transitions to CHASE with a fresh cooldown — plan corr. 10 (never blindly restore prior state).",
			"_on_hit_resolved_for_reaction now derives was_heavy from the CombatFeedbackProfile weight (HEAVY/FINISHER/CRIT/ELITE/BOSS). Light/medium attacks don't trip heavy-only tier gates (HEAVY/ELITE/BOSS enemies require heavy attacks to stagger; LIGHT/MEDIUM enemies stagger on any hit).",
			"Boss tier still immune to stagger (stagger_resistance = 1.0 in preset).",
		]
	},
	{
		"version": "v0.83.32",
		"title": "Combat overhaul — Phase 1B.6d profile-driven feedback (C-finisher distinct)",
		"date": "2026-06-14",
		"entries": [
			"VISIBLE CHANGE: Swing C (finisher) now feels distinctly heavier than A/B. Victim freeze is longer (105 ms vs 35 ms light, 90 ms crit) — the C hit lands with weight. D/E/specials/charged all use the HEAVY profile (85 ms victim freeze).",
			"CombatManager.resolve_hit now derives feedback from each attack's rhythm class via AttackTimings.by_id, builds a CombatFeedbackProfile, and dispatches HitStopController.freeze_target + request_global_dip centrally. Profiles are cached so per-hit allocation is zero.",
			"Removed the ad-hoc enemy-side freeze added in 1B.6c — single dispatcher in CombatManager owns it now (cleaner).",
			"Crit dip still uses CRIT profile (50 ms @ 0.35×, priority 2). Profile priorities for elite-kill (60 ms @ 0.30, p3) and boss-event (70 ms @ 0.25, p4) are wired and ready for Phase 1B.7 escalation.",
		]
	},
	{
		"version": "v0.83.31",
		"title": "Combat overhaul — Phase 1B.6c hit-stop: enemy freeze + crit time dip",
		"date": "2026-06-14",
		"entries": [
			"VISIBLE CHANGE: hits now have WEIGHT.",
			"Localized victim freeze: every confirmed hit briefly pauses the enemy's AI (45 ms basic, 90 ms crit) via HitStopController. The enemy stops chasing/attacking for that real-time window, then resumes. Knockback decay keeps ticking so the enemy never gets physics-stuck.",
			"Crit global dip: critical hits now trigger a brief Engine.time_scale dip (0.35× for 50 ms) routed through TimeManager (sole owner). Per-attack_id dedupe at the HitStopController layer means whirlwind / charged slash killing 5 enemies still only fires ONE dip, not five.",
			"Wall-clock recovery via Time.get_ticks_usec() — slowdowns can NOT extend their own recovery. Pause / scene change / save load / player death / quit-to-menu all force-reset the time scale.",
		]
	},
	{
		"version": "v0.83.30",
		"title": "Combat overhaul — Phase 1B.6b enemies visually flinch on hit",
		"date": "2026-06-14",
		"entries": [
			"VISIBLE CHANGE: every enemy now visually recoils when it takes a confirmed hit. Direction-aware nudge + squash + slight rotation. Heavier enemy tiers (troll/ogre = HEAVY, bandit/wolf = MEDIUM, mini-bosses = ELITE) react less than common enemies.",
			"enemy.gd: HitReactionComponent created in _ready with the enemy's tier preset. Subscribes to CombatManager.hit_resolved and fires visual flinch when event.victim == self. Knockback emission is intentionally skipped (force=0) so the existing apply_knockback path stays the sole writer of _knockback_velocity. Stagger signals from the component are not connected this stage either.",
			"HitReactionComponent: visual layer now only touches modulate when hit_flash_strength != 1.0, so it never fights the existing _do_hit_flash modulate tween.",
			"Result: hits visibly land harder than damage numbers alone communicate, without disrupting any existing enemy behavior.",
		]
	},
	{
		"version": "v0.83.29",
		"title": "Combat overhaul — Phase 1B.6a screen shake routes through CameraShake2D",
		"date": "2026-06-14",
		"entries": [
			"FIRST PHASE 1B GAMEPLAY-VISIBLE CHANGE. Screen shake now uses the trauma model (intensity² mapping) — light hits feel light, heavy and crit hits feel proportionally heavier without a discontinuous step from subtle to screen-filling.",
			"player.gd: CameraShake2D is created as a child of the player's Camera2D in _ready. _do_screen_shake(intensity) now maps the legacy intensity (1.5–10.0) to trauma (clamp(intensity/12, 0, 1)) and calls add_trauma. Legacy random-offset code remains as a fallback if the shake node fails to initialize.",
			"All existing call sites (every swing, every special, every crit) keep working unchanged — the felt response is similar to today, just smoother in decay and with the trauma² curve giving better dynamic range.",
		]
	},
	{
		"version": "v0.83.28",
		"title": "Combat overhaul — Phase 1B.4/1B.5 CombatFeedbackProfile + CombatAudioComponent",
		"date": "2026-06-14",
		"entries": [
			"Internal — no gameplay change yet. Phase 1B.6 wires these into hit_resolved subscribers.",
			"Added scripts/data/combat_feedback_profile.gd: per-weight Resource bundling attacker/victim freeze ms, camera trauma + impulse, global Engine.time_scale dip (scale, ms, priority), audio group ids (swing/impact/body/armor/magical/kill), VFX preset id + flash color, optional reaction tier override.",
			"Presets via apply_preset(weight): LIGHT (no dip), MEDIUM, HEAVY, FINISHER (A→B→C natural finisher), CRIT (50ms @ 0.35), ELITE_KILL (60ms @ 0.30), BOSS_EVENT (70ms @ 0.25). Wide-attack aggregation already handled at HitStopController layer via attack_id dedupe.",
			"Added scripts/components/combat_audio_component.gd: combat-specific audio SELECTION. AudioManager still owns playback / pooling / buses / pitch / variation. Plan corr. 11 — does NOT grow the 2,888-line AudioManager with combat selection.",
			"Smoke now 127 checks.",
		]
	},
	{
		"version": "v0.83.27",
		"title": "Combat overhaul — Phase 1B.3 HitReactionComponent + HitReactionData",
		"date": "2026-06-14",
		"entries": [
			"Internal — no gameplay change yet. Phase 1B.6/1B.7 wire this into enemies.",
			"Added scripts/data/hit_reaction_data.gd: per-tier Resource with separate visual, physical, and stagger params. Tiers LIGHT/MEDIUM/HEAVY/ELITE/BOSS. Presets via instance.apply_preset(tier) — boss is knockback+stagger immune, elite stagger-resists 60% and gates to heavy only, etc.",
			"Added scripts/components/hit_reaction_component.gd: three independent reaction layers (plan §3). Visual flinch on exported reaction_pivot (NO reparenting — pivot is explicit; falls back to transform-only writes on the assigned node). Original transform captured on first reaction, restored exactly on completion. Generation tokens prevent stale tweens fighting newer ones.",
			"Physical knockback is emitted as a signal — component NEVER writes velocity directly. Owner code stays the sole writer of CharacterBody2D.velocity (plan corr. 9 spirit).",
			"Stagger emits request + ended signals. Phase 1B.6 will wire the enemy stagger_ended handler to re-evaluate AI state from CURRENT conditions (plan corr. 10), not blindly restore the prior state.",
			"Repeated-hit dampening per profile.min_interval_ms: rapid hits get a reduced visual flash only — knockback and stagger are skipped until the interval elapses. Prevents stun-lock.",
			"Smoke now 117 checks (presets, react fires/dampens, boss immunity, cancel_reaction, pivot transform restoration).",
		]
	},
	{
		"version": "v0.83.26",
		"title": "Combat overhaul — Phase 1B.2 CameraShake2D",
		"date": "2026-06-14",
		"entries": [
			"Internal — no gameplay change yet. Phase 1B.6 wires this into the player Camera2D.",
			"Added scripts/combat/camera_shake_2d.gd: trauma-model camera shake (Squirrel Eiserloh). trauma ∈ [0,1]; offset = max_offset * trauma² * pseudo-noise. Light impulses feel light, finishers and crits feel proportionally heavier without discontinuity.",
			"Directional impulse: an optional hit-direction Vector2 nudges the noise toward the hit so shake feels pushed, not radially symmetric.",
			"Accessibility: intensity_scalar ∈ [0,1] disables visible shake without affecting trauma logic — gameplay events stay decoupled. process_mode=ALWAYS so decay continues during pause; offset returns exactly to Vector2.ZERO when trauma reaches 0 (drift guard).",
			"Trauma presets baked in for CombatFeedbackProfile use: LIGHT 0.18, MEDIUM 0.30, HEAVY 0.45, FINISHER/CRIT 0.55, ELITE_KILL 0.70, BOSS_EVENT 0.85.",
			"Smoke now 103 checks (trauma add, decay-to-zero, no-op on negative, force_reset, accessibility scalar).",
		]
	},
	{
		"version": "v0.83.25",
		"title": "Combat overhaul — Phase 1B.1 HitStopController",
		"date": "2026-06-14",
		"entries": [
			"Internal — no gameplay change yet. Phase 1B.6 wires player.gd / enemy.gd to consult this.",
			"Added scripts/autoloads/hit_stop_controller.gd: localized freeze API (freeze_target / is_frozen / active_freeze_count) using monotonic Time.get_ticks_usec() deadlines. process_mode=PROCESS_MODE_ALWAYS so freezes expire during pause.",
			"request_global_dip(scale, ms, priority, attack_id) routes through TimeManager (never writes Engine.time_scale directly). Per-attack_id dedupe coalesces wide-attack bursts so 5-enemy whirlwind/charged-slash kills produce one dip, not five.",
			"Mirrors TimeManager's reset sources (scene_changed, player_died, game_loaded, save_about_to_load, returning_to_menu).",
			"Smoke now 93 checks. Grep guard still clean: only TimeManager writes Engine.time_scale.",
		]
	},
	{
		"version": "v0.83.24",
		"title": "Combat overhaul — Phase 1B.0 TimeManager owns Engine.time_scale",
		"date": "2026-06-14",
		"entries": [
			"Internal — no gameplay change yet. Phase 1B feedback systems will use this in subsequent commits.",
			"TimeManager is now the singular owner of Engine.time_scale (plan corr. 2). New API: request_time_scale(scale, duration_ms, priority, source_id) → bool; force_reset(); is_time_dilated(); active_source(); time_scale_changed signal.",
			"Conflict policy: higher priority wins; equal or lower priority during an active request is rejected; stronger requests replace mid-flight.",
			"Timing uses monotonic Time.get_ticks_usec() — slowdowns can NOT extend their own recovery. process_mode=PROCESS_MODE_ALWAYS so recovery ticks even while game is paused.",
			"Added explicit reset sources: SceneTree.scene_changed, RespawnManager.player_died, SaveLoadManager.game_loaded + save_about_to_load, GameManager.returning_to_menu, plus NOTIFICATION_WM_CLOSE_REQUEST / NOTIFICATION_PREDELETE shutdown safety.",
			"New signals: GameManager.returning_to_menu, SaveLoadManager.save_about_to_load (emitted at top of load_game before mutations).",
			"Grep guard: only scripts/autoloads/time_manager.gd writes Engine.time_scale. Smoke now 75 checks including TimeManager API and recovery.",
		]
	},
	{
		"version": "v0.83.23",
		"title": "Combat overhaul — Phase 1A.6 A→B→C natural rhythm finisher",
		"date": "2026-06-14",
		"entries": [
			"REAL GAMEPLAY CHANGE: A → B → C is now the natural horizontal combo rhythm. Two horizontal swings in a row, then the third press is C (overhead chop, the FINISHER_C rhythm class). Previously the third press cycled back to A.",
			"After C / D / E the combo resets so the next press starts at A again — preserves the ability to intentionally stop after any swing.",
			"D (thrust) and E (spin) remain optional higher-commitment extensions reachable only via explicit directional input — they are not part of the natural A→B→C core.",
			"Phase 1B will give C the stronger feedback profile (larger hit-stop, camera trauma, heavier reaction tier) it deserves.",
		]
	},
	{
		"version": "v0.83.22",
		"title": "Combat overhaul — Phase 1A.5m shadow step + shared projectile migrated (1A.5 complete)",
		"date": "2026-06-14",
		"entries": [
			"Shadow step (ranged diagonal special) — backward dodge-roll + 3-arrow spread — now routes damage through the migrated _spawn_projectile. Cooldown derives from AttackTimings.shadow_step().duration_sec.",
			"_spawn_projectile shared infrastructure now takes an attack_id and emits HitResult per body_entered hit, so the basic ranged auto-attack also benefits.",
			"PHASE 1A.5 MILESTONE: All 13 player attacks (5 basic swings + 4 melee specials + 4 ranged specials) plus shared projectile are now data-driven. Every confirmed hit emits a typed HitResult. Cooldowns derive from each attack's AttackTimings duration — no more 0.5/attack_speed constants except as defaults for any attack that hasn't been authored.",
		]
	},
	{
		"version": "v0.83.21",
		"title": "Combat overhaul — Phase 1A.5l sniper shot migrated",
		"date": "2026-06-14",
		"entries": [
			"Sniper shot (ranged hold-1.5s) routes damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.sniper_shot().duration_sec.",
			"Long-range projectile, afterimage trail, single-target lock with travel delay, knockback 120, shake 8, hit-freeze, audio + label identical to legacy.",
		]
	},
	{
		"version": "v0.83.20",
		"title": "Combat overhaul — Phase 1A.5k arrow rain migrated",
		"date": "2026-06-14",
		"entries": [
			"Arrow rain (ranged triple-tap AoE) routes per-target damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.arrow_rain().duration_sec.",
			"12-arrow visual rain, radial knockback 35, shake 3/6, hit-freeze, audio + label identical to legacy.",
		]
	},
	{
		"version": "v0.83.19",
		"title": "Combat overhaul — Phase 1A.5j piercing shot migrated",
		"date": "2026-06-14",
		"entries": [
			"Piercing shot (ranged double-tap) now routes per-pass-through-victim damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.piercing_shot().duration_sec.",
			"Projectile pass-through behavior, knockback 30, single-fire-per-enemy guard, shake 3, audio + label identical to legacy.",
		]
	},
	{
		"version": "v0.83.18",
		"title": "Combat overhaul — Phase 1A.5i dash strike migrated (all melee specials done)",
		"date": "2026-06-14",
		"entries": [
			"Dash strike (diagonal+attack special) now routes per-path-target damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.dash_strike().duration_sec.",
			"Knockback 75, three slash arcs, shake 2/6, audio + 'DASH STRIKE!' label identical to legacy.",
			"Milestone: all four melee specials (power strike, whirlwind, charged slash, dash strike) now data-driven and typed. Ranged class specials (piercing, arrow rain, sniper, shadow step) remain on legacy path.",
		]
	},
	{
		"version": "v0.83.17",
		"title": "Combat overhaul — Phase 1A.5h charged slash migrated",
		"date": "2026-06-14",
		"entries": [
			"Charged slash (hold-1.5s special) now routes per-corridor-target damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.charged_slash().duration_sec.",
			"Dash animation, afterimage ghosts, trail VFX along the slash corridor, big final slash, 140 knockback per enemy, shake 5/10, hit-freeze on hit, audio + label all preserved verbatim.",
		]
	},
	{
		"version": "v0.83.16",
		"title": "Combat overhaul — Phase 1A.5g whirlwind migrated",
		"date": "2026-06-14",
		"entries": [
			"Whirlwind (triple-tap AoE) now routes per-enemy damage through CombatManager.resolve_hit. Cooldown derives from AttackTimings.whirlwind().duration_sec.",
			"720° double-spin visual identity preserved; per-enemy knockback 70, shake 3.0/8.0, hit-freeze on hit, audio + label identical to legacy.",
		]
	},
	{
		"version": "v0.83.15",
		"title": "Combat overhaul — Phase 1A.5f power strike migrated",
		"date": "2026-06-14",
		"entries": [
			"Power strike (double-tap-moving special) now routes per-cone-target damage through CombatManager.resolve_hit (typed HitResult per victim). Cooldown derives from AttackTimings.power_strike().duration_sec.",
			"Visual tween chain (wind-up coil, lunge, impact, recovery bounces) is preserved — too bespoke and well-timed to restructure. Contact trigger is still the visual tween's impact callback.",
			"Knockback 120, slash fan VFX, 5.0/10.0 shake, hit-freeze on hit, audio + 'POWER STRIKE!' label all identical to legacy.",
			"Whirlwind, charged_slash, dash_strike, ranged specials still on legacy path.",
		]
	},
	{
		"version": "v0.83.14",
		"title": "Combat overhaul — Phase 1A.5e swing E migrated (all 5 basic swings done)",
		"date": "2026-06-14",
		"entries": [
			"Swing E (spin slash extension) now drives damage from AttackClock + AttackTimings.swing_e() (EXTENSION_E, wide_attack).",
			"_start_spin_slash_clock wrapper preserves all three slash arcs (forward, +90°, -90°), knockback 60, shake 2.0/6.0.",
			"Milestone: all five basic swings A→B→C→D→E now contact-frame-driven via AttackClock + AttackTimingData. Cooldown per swing now derives from its own duration. C-finisher rhythm class is in place ready for Phase 1B's stronger feedback profile.",
			"Specials (power_strike, whirlwind, dash_strike, charged_slash) and ranged equivalents still on legacy path — next commits migrate them.",
		]
	},
	{
		"version": "v0.83.13",
		"title": "Combat overhaul — Phase 1A.5d swing D migrated",
		"date": "2026-06-14",
		"entries": [
			"Swing D (upward thrust extension) now drives damage from AttackClock + AttackTimings.swing_d() (EXTENSION_D rhythm class).",
			"_start_upward_thrust_clock wrapper preserves bespoke knockback 30, VFX rotated -0.4, shake 1.5/5.0 — identical to legacy callback.",
			"E and all specials still on legacy path.",
		]
	},
	{
		"version": "v0.83.12",
		"title": "Combat overhaul — Phase 1A.5c swing C (finisher) migrated",
		"date": "2026-06-14",
		"entries": [
			"Swing C (overhead chop) — the A→B→C finisher — now drives damage from AttackClock + AttackTimings.swing_c() (FINISHER_C rhythm class).",
			"Extracted _run_clocked_attack(timing, target, dir, mult, on_contact) so each remaining swing/special migration is a small wrapper with bespoke knockback / VFX / shake / freeze, sharing one clock-driven contact path.",
			"swing_a / swing_b now use the new wrappers (no behavior change). swing_c has its own wrapper that applies knockback 55, VFX scale 1.4, shake 2.0/5.0 — preserved verbatim from the legacy callback.",
			"D, E, and all specials still on legacy path.",
		]
	},
	{
		"version": "v0.83.11",
		"title": "Combat overhaul — Phase 1A.5b swing B migrated to AttackClock",
		"date": "2026-06-14",
		"entries": [
			"Swing B (right-to-left backhand) now drives damage from AttackClock + AttackTimings.swing_b() instead of a hard-coded tween_callback.",
			"Refactored swing A helper into _start_basic_horizontal_clock(timing, target, dir, side) so A and B share one path with side=±1.0. Both still preserve their visual identity (slash arc rotation flips sign with side).",
			"Cooldown for both A and B now derives from each swing's duration_sec / attack_speed.",
			"C/D/E and all specials still on the legacy path.",
		]
	},
	{
		"version": "v0.83.10",
		"title": "Combat overhaul — Phase 1A.5a swing A migrated to AttackClock",
		"date": "2026-06-14",
		"entries": [
			"First gameplay-code change of the combat overhaul. Lock-target preserved; felt behavior preserved.",
			"Swing A (left-to-right basic slash) now drives damage from a parallel AttackClock + AttackTimingData rather than a hard-coded tween_callback timestamp. Contact event at 55% normalized progress (matches the legacy timing audit). Damage routes through CombatManager.resolve_hit producing a typed HitResult — Phase 1B feedback systems will subscribe later.",
			"Swing A cooldown is now derived from AttackTimings.swing_a().duration_sec / attack_speed instead of the legacy 0.5/attack_speed constant. Slightly tighter at high attack-speed; matches the actual visual recovery length.",
			"Knockback (40.0), slash VFX, impact VFX, screen shake (1.5 / 4.0 crit), and hit freeze on crit are preserved verbatim from the legacy callback so feel is identical.",
			"Swings B/C/D/E and all specials remain on the legacy path — subsequent commits migrate them one at a time.",
		]
	},
	{
		"version": "v0.83.9",
		"title": "Combat overhaul — Phase 1A.4 AttackClock + AttackTimingData",
		"date": "2026-06-14",
		"entries": [
			"Internal foundation — no gameplay changes (player.gd not yet migrated)",
			"Added scripts/combat/attack_clock.gd: normalized progress (0.0→1.0) driven by a single Tween. Gameplay windows are evaluated against progress, never against the visual Tween's elapsed time (per plan corr. 7). Generation tokens guard against stale callbacks; cancel() emits signal and freezes progress.",
			"Added scripts/data/attack_timing_data.gd: per-attack window Resource (contact_event, active_window, combo_window, dodge_cancel_start, movement_cancel_start, special_branch_window, recovery_end, max_hits_per_target, wide_attack, unstoppable, rhythm_class).",
			"Added scripts/data/attack_timings.gd: 16 per-attack timings calibrated to the Phase 1A.0 audit. swing_c is FINISHER_C (plan corr. 1 — A→B→C core, D/E optional extensions). Includes branch_slam/uppercut/spin and all melee+ranged specials.",
			"Smoke now 51 checks (13 added covering all 16 timings have sane windows, swing_c rhythm class, wide/unstoppable flags, AttackClock progresses to 1.0, fires finished, cancel freezes progress, is_in_window).",
		]
	},
	{
		"version": "v0.83.8",
		"title": "Combat overhaul — Phase 1A.3 AttackIntentResolver",
		"date": "2026-06-14",
		"entries": [
			"Internal foundation — no gameplay changes (player.gd not yet migrated)",
			"Added scripts/combat/attack_intent.gd: typed AttackIntent with Kind enum (BASIC_SWING, POWER_STRIKE, WHIRLWIND, CHARGED_SLASH, DASH_STRIKE, RANGED_BASIC, PIERCING_SHOT, ARROW_RAIN, SNIPER_SHOT, SHADOW_STEP, DODGE) and BranchHint (HORIZONTAL, OVERHEAD, THRUST, SPIN)",
			"Added scripts/combat/attack_intent_resolver.gd: mirrors existing tap-buffer + charge + diagonal-dash + branch-table behavior. Hero-class aware (melee vs ranged). Dodge > attack priority. CombatController (Phase 1C) will drop this in and the duplicate logic in player.gd will be removed atomically.",
			"Smoke now 38 checks (13 added covering single/double/triple tap, charge release threshold, diagonal dash, dodge priority, branch hints for horizontal->down=OVERHEAD and any->up=THRUST, ranged-class variants, sub-threshold charge fallthrough)",
		]
	},
	{
		"version": "v0.83.7",
		"title": "Combat overhaul — Phase 1A.2 InputBuffer",
		"date": "2026-06-14",
		"entries": [
			"Internal foundation — no gameplay changes (player.gd not yet migrated)",
			"Added scripts/combat/input_buffer.gd: raw combat-input event buffer with monotonic timestamps, per-action TTL (attack 140ms, dodge 120ms, direction_intent 180ms, special_tap 180ms, charge_press hold-indefinite), single-consume tokens, per-action generation counter, debug toggle",
			"Buffer stores raw presses only — no tap-count interpretation, no special selection, no priority (those live in AttackIntentResolver in Phase 1A.3)",
			"Smoke test now 25 checks (13 added for InputBuffer push/peek/consume/expiry/generation/release/clear)",
		]
	},
	{
		"version": "v0.83.6",
		"title": "Combat overhaul — Phase 1A.1 typed HitEvent / HitResult",
		"date": "2026-06-14",
		"entries": [
			"Internal foundation — no gameplay changes (legacy damage path unchanged)",
			"Added typed HitEvent and HitResult Resources in scripts/combat/ — Phase 1B feedback systems (hit-stop, camera shake, audio, enemy reaction) will trigger from confirmed HitResults",
			"Extended CombatManager with resolve_hit() typed adapter and hit_resolved signal — calculate_damage() preserved verbatim for all existing callers",
			"Added tests/smoke/combat_smoke.tscn headless validation — 12 checks for boot, autoloads, typed-path, force_crit, time_scale==1.0",
		]
	},
	{
		"version": "v0.83.5",
		"title": "Combat overhaul — Phase 1A.0 audit & plan",
		"date": "2026-06-14",
		"entries": [
			"Docs only — no gameplay changes",
			"Added COMBAT_IMPROVEMENT_PLAN.md: phased plan (1A foundations, 1B feedback, 1C extraction) for Diablo-IV-grade game feel while preserving the 5-swing directional combat system",
			"Added docs/combat/PHASE_1A_0_BEHAVIORAL_CHECKLIST.md: full attack inventory, state-flag inventory, manual + headless regression checklist re-run after every Phase 1 stage",
		]
	},
	{
		"version": "v0.83.4",
		"title": "Combat & movement feel polish",
		"date": "2026-06-14",
		"entries": [
			"Non-crit basic attacks now have a subtle screen shake — every hit feels tactile, not just crits",
			"Added footstep SFX with speed-scaled cadence — movement no longer silent",
		]
	},
	{
		"version": "v0.83.3",
		"title": "Fix Space key triggering UI buttons during combat",
		"date": "2026-03-16",
		"entries": [
			"Fixed critical bug: Space (attack key) was also mapped to Godot's ui_accept, causing focused HUD buttons (Load Game, Save, etc.) to fire when attacking",
			"Disabled keyboard focus on all HUD command card buttons and pause menu buttons so they respond to mouse/touch only",
			"This was the root cause of charged slash teleporting players or triggering load game",
		]
	},
	{
		"version": "v0.83.2",
		"title": "Fix repeated game loading in browser",
		"date": "2026-03-16",
		"entries": [
			"Fixed bug where load game could fire repeatedly in web browsers due to touch/mouse event duplication",
			"Added 1.5s debounce cooldown to load_game() to prevent duplicate loads",
			"Load handlers now check return value and skip SFX/apply when load is blocked",
		]
	},
	{
		"version": "v0.83.1",
		"title": "Fix special attacks teleporting player out of dungeon",
		"date": "2026-03-16",
		"entries": [
			"Fixed bug where charged slash, dash strike, and other movement-based special attacks could accidentally push the player into dungeon exit beacons, teleporting them back to the main level",
			"Beacon teleport activation is now blocked while the player is mid-attack animation",
		]
	},
	{
		"version": "v0.83.0",
		"title": "Hero Animation Overhaul — dramatic death, level-up burst, richer idle",
		"date": "2026-03-16",
		"entries": [
			"Death: multi-phase cinematic — white freeze, stagger wobble, knees buckle, sideways collapse with rising embers",
			"Level Up: golden burst with radial sparkles, expanding ring, bounce settle with screen shake",
			"Hit Reaction: impactful red flash with squash-stretch-wobble instead of flat color fade",
			"Respawn: converging blue sparkles gather inward, ethereal flicker, golden power surge, double-ring flash",
			"4 new idle fidgets: impatient foot tap, battle stance flex, cold shiver, yawn-then-alert snap (8 total)",
		]
	},
	{
		"version": "v0.82.2",
		"title": "Inventory Clarity — equipped vs bag items now visually distinct",
		"date": "2026-03-16",
		"entries": [
			"Equipped items now have a green-bordered 'active gear' style with [E] prefix",
			"Bag items show ▲ (upgrade) or ▼ (downgrade) vs currently equipped gear",
			"Upgrade items have a green-tinted background, downgrades have red-tinted",
			"Comparison panel now separates gains (▲) from losses (▼) for clarity",
			"Empty equipment slots remain visually dimmed to stand out from equipped ones",
		]
	},
	{
		"version": "v0.82.1",
		"title": "Watchtower Damage Visuals — towers show battle wear",
		"date": "2026-03-16",
		"entries": [
			"Watchtower sprite progressively darkens as HP drops (soot tint at 75%, char at 50%, scorched at 30%)",
			"Smoke puffs rise from critically damaged towers (below 30% HP)",
			"Damage visuals persist across repair and upgrade — healed towers brighten back up",
			"All flash effects (hit, heal, upgrade) now blend with the current damage tint",
		]
	},
	{
		"version": "v0.82.0",
		"title": "Unique Death Animations — every enemy type gets a signature death",
		"date": "2026-03-16",
		"entries": [
			"Goblin: panics, stumbles backward, and faceplants",
			"Wolf: recoils, rolls sideways, settles legs-up",
			"Bandit: clutches wound, staggers, collapses to knees",
			"Spider: flips upside-down, curls inward, shrivels into a husk",
			"Troll: wobbles like a falling tree, timber-crashes with ground impact",
			"Dark Mage: arcane flicker, spawns void wisps, implodes into nothing",
			"Ogre: dazed sway, heavy face-first slam with dust thud",
			"Demon Knight: hellfire armor cracks, ember burst, smolders out",
			"Ancient Golem: stone cracks spread, crumbles into rubble pile",
			"Shadow Wraith: ethereal flicker, stretches upward, ghost wisps dissipate",
			"Dragon Whelp: flame burst, spiraling fall with trailing embers",
			"Infernal: demonic glow, reality-tear oscillation, banished implosion",
			"Cave Snake: coils up, spasms, goes limp and flattens",
			"Dungeon Bat: wings fold, plummets straight down, poof on impact",
			"Vampire Bat: swells with blood, bursts, shrivels away",
			"Flan: wobbles wildly, splats flat into a dissolving puddle",
			"Mimic: snaps open, tongue lashes, slams shut, crumbles apart",
			"Ghoul: sickly green flash, staggers, melts into the ground",
			"Crypt Knight: metallic flash, armor shatters, empty shell falls sideways",
			"Lich: soul scream, arcane explosion, soul fragments ascend to the sky",
		]
	},
	{
		"version": "v0.81.1",
		"title": "Watchtower UI polish — emerald green theme, load fix",
		"date": "2026-03-15",
		"entries": [
			"Watchtower colors updated to rich emerald green palette (labels, messages, flashes)",
			"Fixed watchtowers not being restored when loading a save mid-game",
		]
	},
	{
		"version": "v0.81.0",
		"title": "Watchtower Upgrades — upgrade HP and attack directly at the tower",
		"date": "2026-03-15",
		"entries": [
			"Walk near a watchtower and press Q (or tap when at full HP) to upgrade it directly",
			"Each tower can be upgraded individually up to 50 levels (+30 HP, +3 ATK per level)",
			"Upgrade cost scales with level — spend wood to make each tower stronger",
			"Upgrading partially heals the tower and boosts its max HP",
			"Per-tower upgrade levels are saved and restored across sessions",
			"Woodworker upgrades still apply as a base level to all towers",
		]
	},
	{
		"version": "v0.80.0",
		"title": "Multiple Watchtowers — build up to 4, bigger sprite, hero repair",
		"date": "2026-03-08",
		"entries": [
			"Build up to 4 watchtowers — each additional tower costs much more (1x, 4x, 12x, 32x)",
			"Watchtower sprite is now 2x bigger with more detail (flag, door, brick lines)",
			"Walk near a damaged watchtower and press E (or tap) to repair with 2 wood for 40 HP",
			"Repair prompt appears when hero is within range of a damaged tower",
			"Upgrading at the Woodworker now upgrades all placed towers at once",
			"Full save/load support for multiple watchtowers with legacy save migration",
		]
	},
	{
		"version": "v0.79.0",
		"title": "Watchtower — build, place, and upgrade a defensive tower",
		"date": "2026-03-08",
		"entries": [
			"New watchtower building via the Woodworker — purchase and place anywhere on the map",
			"Watchtower has archers that auto-attack nearby enemies and grant XP from kills",
			"Click the watchtower to repair it with wood when damaged",
			"Upgrade the watchtower at the Woodworker for more HP, damage, and attack range",
			"Enemies will aggro and attack the watchtower if they get close",
			"Watchtower state (position, HP, level) is fully saved and loaded",
		]
	},
	{
		"version": "v0.78.1",
		"title": "Fix character stats dialog not closing on desktop",
		"date": "2026-03-08",
		"entries": [
			"Fixed duplicate variable declarations in hero_stats_panel.gd that caused a parse error",
			"Stats dialog close button, keyboard shortcut (Q/Esc), and click-outside now work correctly",
		]
	},
	{
		"version": "v0.78.0",
		"title": "Major frame budget reduction — sleeping enemies fully disabled",
		"date": "2026-03-07",
		"entries": [
			"Sleeping enemies now fully disable _physics_process — eliminates ~100 idle virtual calls/frame",
			"Creep camps handle wake-checking for their sleeping children (0.5s interval)",
			"Fog overlay disables _process when no redraw is pending — zero cost when player is stationary",
			"Minimap skips dead and sleeping enemies during scan — reduces iteration cost",
		]
	},
	{
		"version": "v0.77.0",
		"title": "Combat & camera performance — fewer sqrt, cached queries, smooth zoom",
		"date": "2026-03-07",
		"entries": [
			"Eliminated sqrt/normalized calls in enemy separation push — uses squared-distance approximation",
			"Optimized enemy attack-state movement — avoids sqrt when at ideal combat distance",
			"Cached nearby enemies list (updated 5x/sec) — special attacks no longer scan every enemy in the world",
			"Smooth camera zoom — scroll wheel and trackpad zoom now interpolates instead of jumping",
			"Arrow rain uses single staggered tween instead of 12 separate timers",
			"Enemy label zoom compensation skips redundant scale updates when zoom hasn't changed",
		]
	},
	{
		"version": "v0.76.0",
		"title": "Q key closes panels + smoother gameplay with pooling & vsync",
		"date": "2026-03-07",
		"entries": [
			"Fixed Q key not closing panels — ability_1 and ability_2 input actions were missing from project settings",
			"Added vsync to eliminate uncapped frame rate and reduce CPU waste",
			"Pooled effect labels (status text like BLEED, STUN, KNOCKBACK) — avoids Label.new() per proc",
			"Cached LabelSettings per color — avoids LabelSettings.new() per effect label",
			"Pooled bleed CPUParticles2D instances — reuses particles instead of allocating per tick",
			"Tripled player damage label pool (10 → 30) to handle burst damage without allocations",
			"Cached center message LabelSettings — avoids LabelSettings.new() per dramatic message",
		]
	},
	{
		"version": "v0.75.2",
		"title": "Per-frame overhead reduction for smoother gameplay",
		"date": "2026-03-07",
		"entries": [
			"Cached zoom compensation across all enemies — computed once per frame instead of per-enemy",
			"Throttled enemy separation push to every 3rd physics frame with cached result",
			"Removed move_and_slide() calls from idle and stopped enemies",
			"Removed per-enemy tick of shared rat squeal cooldown — use msec timestamps instead",
			"Removed separation push from patrolling enemies (only needed in combat)",
			"Throttled hero stats panel buff refresh from every frame to 2x/second",
		]
	},
	{
		"version": "v0.75.1",
		"title": "Smooth combat — eliminate attack stutter",
		"date": "2026-03-07",
		"entries": [
			"Replaced Engine.time_scale hit-freeze with sprite-only flash — no more whole-game stutter on every hit",
			"Basic attacks no longer trigger screen shake or hit freeze — reserved for crits and special abilities only",
			"Reduced gib count on rat deaths (5-9 → 3-5 normal, 10-16 → 5-8 crit) to cut node/tween allocations",
			"Reduced blood splatter spawns on enemy deaths",
			"Reduced bone fragment and root tendril counts on skeleton/elk deaths",
		]
	},
	{
		"version": "v0.75.0",
		"title": "Desktop browser performance fix",
		"date": "2026-03-06",
		"entries": [
			"Halved physics tick rate (120 -> 60 Hz) — biggest single perf win for browser/WebGL",
			"Beacons: disabled _physics_process on non-heal beacons, cached player ref on heal beacons",
			"Beacons: disabled _process on beacons without labels",
			"Fog overlay: batched adjacent cells into row spans to reduce draw calls",
			"UI dialogs (shop, armory, tavern, woodworking): disabled _process when not visible",
		]
	},
	{
		"version": "v0.74.2",
		"title": "Fix sponsor links in README",
		"date": "2026-03-02",
		"entries": [
			"Fixed sponsor links to all point to openclassactions.com and use dofollow HTML anchors",
		]
	},
	{
		"version": "v0.74.1",
		"title": "Add sponsor links to README",
		"date": "2026-03-01",
		"entries": [
			"Added Open Class Actions sponsor section with dofollow links to README",
		]
	},
	{
		"version": "v0.74.0",
		"title": "Death animation variety + level-based rat scaling",
		"date": "2026-02-26",
		"entries": [
			"Rat deaths: 4 variants — normal pop, critical explosion, fling, and squish",
			"Critical/overkill kills trigger dramatic death animations with extra gibs and flash",
			"Default enemy deaths: 3 variants — normal fall, critical flash+fragments, knockback slide",
			"Multi-kill stagger: simultaneous deaths are slightly desynchronized for variety",
			"Rats scale up 4% per level (capped at 1.5x) — higher-level rats are visibly bigger",
		]
	},
	{
		"version": "v0.73.4",
		"title": "Fix enemies sticking to player during combat",
		"date": "2026-02-26",
		"entries": [
			"Enemies back off faster when too close (0.4x speed vs 0.15x)",
			"Wider disengage range prevents chase/attack oscillation",
			"Full separation push strength � enemies properly fan out around player",
			"Wider player push radius prevents enemies overlapping the hero",
		]
	},
	{
		"version": "v0.73.3",
		"title": "Fix movement and attack stuck after respawn",
		"date": "2026-02-26",
		"entries": [
			"Reset all movement, joystick, attack, and target state on respawn",
			"Fixes player walking in one direction and unable to attack after dying",
		]
	},
	{
		"version": "v0.73.2",
		"title": "Fix OPT/MAP closing on finger lift — tap to toggle",
		"date": "2026-02-26",
		"entries": [
			"OPT and MAP buttons no longer use Godot's pressed signal (caused double-toggle)",
			"Overlays open on tap and stay open — close via X, button, or tap outside",
			"Multitouch: overlay buttons work with second finger while joystick is held",
		]
	},
	{
		"version": "v0.72.8",
		"title": "Overlays stay open until explicitly closed",
		"date": "2026-02-26",
		"entries": [
			"OPT and MAP overlays now stay open on tap (no longer close on finger lift)",
			"Close via X button, tapping the OPT/MAP button again, or tapping outside",
			"All overlay and bottom-bar buttons support multitouch with joystick",
		]
	},
	{
		"version": "v0.72.2",
		"title": "Fix overlay close on landscape mobile — blocks hero movement",
		"date": "2026-02-25",
		"entries": [
			"Overlays now block ALL touch from reaching the game world when open",
			"Tapping outside the overlay panel closes it without moving the hero",
			"X close button and all overlay buttons work on both portrait and landscape",
		]
	},
	{
		"version": "v0.71.1",
		"title": "Fix overlay close buttons on landscape mobile",
		"date": "2026-02-25",
		"entries": [
			"MAP and OPT overlays now have a dimmer backdrop — tap anywhere outside to close",
			"Fixed CMD overlay positioning (content was overflowing off-screen in landscape)",
			"X close buttons now reliably receive touch input on all overlays",
		]
	},
	{
		"version": "v0.71.0",
		"title": "Landscape mobile: MAP/OPT buttons and proper close buttons",
		"date": "2026-02-25",
		"entries": [
			"Landscape mobile now has MAP and OPT buttons like portrait mode",
			"Minimap overlay with close button works in landscape",
			"Pause menu, help dialog, and command overlay all fit landscape viewports",
			"All close buttons and fonts properly scaled for short landscape screens",
		]
	},
	{
		"version": "v0.70.9",
		"title": "Messenger browser fix, hero select matches loading screen",
		"date": "2026-02-25",
		"entries": [
			"Removed unreliable 'Open in Browser' button from messenger in-app browser detection",
			"Now shows clear instructions to tap menu and choose 'Open in Browser' instead",
			"Hero select screen restyled to match loading screen: dark background, gold glowing title, matching decorative elements",
			"Added no-cache headers to prevent messenger browsers from serving stale pages",
		]
	},
	{
		"version": "v0.70.8",
		"title": "Messages moved below resource bar, level up shows transition",
		"date": "2026-02-25",
		"entries": [
			"Gold, wood, pickup, and upgrade messages now appear below the resource bar instead of overlapping it",
			"Mobile: message position scales with screen size (8% from top)",
			"Level up now shows LVL 4 → LVL 5 format instead of just the new level number",
		]
	},
	{
		"version": "v0.70.7",
		"title": "Woodworker upgrades max level raised to 100",
		"date": "2026-02-25",
		"entries": [
			"All four woodworker upgrades (Bow, Shield, Totem, Watchtower) now go up to level 100",
		]
	},
	{
		"version": "v0.70.6",
		"title": "Dungeon unlock message at level 10",
		"date": "2026-02-25",
		"entries": [
			"Reaching level 10 now shows a dramatic center-screen message: DUNGEON UNLOCKED — check in town!",
			"Level Up messages also now appear as dramatic center-screen text",
		]
	},
	{
		"version": "v0.70.5",
		"title": "Tutorial hints spaced out to 30s minimum",
		"date": "2026-02-25",
		"entries": [
			"Hints now appear at least 30 seconds apart — less spammy, more breathing room",
			"First ability tip still appears early (15s) since it's critical for new players",
			"Dismissing a hint no longer causes the next one to pop up in 2 seconds",
		]
	},
	{
		"version": "v0.70.4",
		"title": "NPC panels auto-close when you walk away",
		"date": "2026-02-25",
		"entries": [
			"Shop, armory, tavern, and woodworker panels now auto-close when you walk ~150px away from the NPC",
			"No more having to manually close panels after walking off",
		]
	},
	{
		"version": "v0.70.2",
		"title": "Inventory text scales with screen size",
		"date": "2026-02-25",
		"entries": [
			"All inventory fonts and button sizes now scale relative to screen height (base 1080p)",
			"Portrait mode gets bigger, more readable text for item stats and comparisons",
			"Detail panel font scaled up from 22 to 30 (at 1080p base) so stats are easy to read",
		]
	},
	{
		"version": "v0.70.1",
		"title": "Inventory: fixed detail panel at bottom, no more overlay",
		"date": "2026-02-25",
		"entries": [
			"Item detail now shows in a fixed panel at the bottom of the inventory — never covers the item list",
			"Bag items: single tap to preview stats + comparison, double-tap to equip",
			"Compact text format: item name, stats, and equipped comparison all fit in 2-3 lines",
			"Mobile: smaller button sizes and fonts so more items fit on screen",
			"Removed popup overlay completely — detail panel is always visible and never blocks interaction",
		]
	},
	{
		"version": "v0.69.2",
		"title": "Bag item detail shows inline, not as overlay",
		"date": "2026-02-25",
		"entries": [
			"Item detail and comparison now appears inline below the bag grid, inside the scroll area",
			"No more fullscreen overlay blocking bag items — buttons stay accessible for double-tap to equip",
			"Single tap selects and shows stats + comparison below, double-tap equips",
		]
	},
	{
		"version": "v0.69.1",
		"title": "Bag items: tap to preview, double-tap to equip",
		"date": "2026-02-25",
		"entries": [
			"Single tap/click on a bag item now shows its stats and a comparison with your equipped item",
			"Stat differences shown (e.g. +5 Strength, -2 Agility) so you can decide before equipping",
			"Double-tap/click to actually equip the item",
		]
	},
	{
		"version": "v0.68.6",
		"title": "Performance optimizations",
		"date": "2026-02-25",
		"entries": [
			"Outline shaders now applied on-demand (hover only) instead of always running on every enemy and tree",
			"Fog of war overlay redraws throttled to max 3x/sec instead of every movement tick",
			"Minimap refresh rate reduced from 4x/sec to 2x/sec",
			"Ambient particle count reduced from 15 to 6",
		]
	},
	{
		"version": "v0.68.5",
		"title": "All panels fully opaque and dark",
		"date": "2026-02-25",
		"entries": [
			"All UI panels (shop, armory, tavern, woodworking, inventory, hero stats, changelog, pause) now have dark opaque backgrounds",
			"Text behind panels no longer bleeds through — much easier to read",
		]
	},
	{
		"version": "v0.68.4",
		"title": "Dungeon enemies are much harder",
		"date": "2026-02-25",
		"entries": [
			"All dungeon crypt enemies got major stat buffs — the dungeon is now genuinely dangerous",
			"Attack damage roughly doubled across all dungeon enemies to match overworld scaling",
			"Flan: speed 40->65, cooldown 2.5->1.6s, damage 12->35, aggro 80->120",
			"Mimic: speed 30->70, cooldown 2.0->1.4s, damage 24->42, aggro 60->120",
			"Ghoul: speed 60->85, cooldown 1.6->1.2s, damage 18->38",
			"Crypt Knight: damage 22->48, cooldown 1.8->1.3s, aggro 130->150",
			"Lich: damage 20->55, speed 50->65, cooldown 2.2->1.4s, aggro 160->180",
			"Bats and snakes also significantly buffed in damage, speed, and aggro range",
		]
	},
	{
		"version": "v0.68.3",
		"title": "Bigger, consistent close buttons everywhere",
		"date": "2026-02-25",
		"entries": [
			"All close/X buttons are now the same size across every panel and dialog",
			"Desktop: 120x40 with font size 20 (up from 90x30 / 40x32 inconsistent sizes)",
			"Mobile: consistent 160x130 with font size 60 across all panels",
			"Hint dismiss X button also enlarged for easier tapping",
		]
	},
	{
		"version": "v0.68.2",
		"title": "Minibosses are bigger",
		"date": "2026-02-25",
		"entries": [
			"All minibosses now use a uniform 2.2x sprite scale (up from 1.5x) — unmistakably large",
		]
	},
	{
		"version": "v0.68.1",
		"title": "Endless miniboss respawns + time played saved",
		"date": "2026-02-25",
		"entries": [
			"After all 8 scheduled bosses spawn, new bosses keep coming indefinitely",
			"Every 5 minutes, if no minibosses are alive, 2 random bosses spawn scaled to your level",
			"Time played is now saved — wave/boss timers resume where you left off after loading",
			"Boss spawn schedule and wave progress persist correctly across save/load",
		]
	},
	{
		"version": "v0.68.0",
		"title": "More minibosses + aggressive roaming + special attacks",
		"date": "2026-02-25",
		"entries": [
			"4 new minibosses: Shadow Fang (Lv5-7), War Spider (Lv12-14), Bone Lord (Lv18-22), Inferno Wyrm (Lv34-40)",
			"8 total minibosses now spawn on a schedule from 5 to 40 minutes",
			"Minibosses roam much wider (~1500px vs ~400px) and avoid town center",
			"Minibosses patrol faster (85% speed) with shorter idle pauses — restless and threatening",
			"Shadow Fang: savage pounce attack with crouch-leap-bite animation",
			"War Spider: venom barrage with rapid jabs and toxic green burst",
			"Bone Lord: death cleave with spinning slash and purple impact",
			"Inferno Wyrm: uses fire breath like Elder Drake — ultimate late-game boss",
		]
	},
	{
		"version": "v0.67.4",
		"title": "Rats slightly less aggressive",
		"date": "2026-02-25",
		"entries": [
			"Rat aggro range reduced from 120 to 90 — they won't chase you from as far away",
		]
	},
	{
		"version": "v0.67.3",
		"title": "Minibosses always visible on minimap",
		"date": "2026-02-25",
		"entries": [
			"Minibosses now always show on the minimap as pulsing red diamonds once spawned",
			"No longer hidden by fog of war — you can track them from anywhere on the map",
			"Diamond indicator made larger and brighter red with outline for better visibility",
		]
	},
	{
		"version": "v0.67.2",
		"title": "Inventory fits on landscape mobile",
		"date": "2026-02-25",
		"entries": [
			"Inventory now fits on landscape mobile — compact slots, smaller fonts, tighter layout",
			"Equipment slots and bag grid properly sized for landscape (46px / 42px vs 110px portrait)",
			"Bag uses 4 columns in landscape (vs 2 portrait) so all 16 slots fit on screen",
			"Item detail is now a floating popup overlay — no longer eats fixed space at the bottom",
			"Detail popup auto-dismisses after 4 seconds so it doesn't block interaction",
			"Stats label and fixed detail panel hidden on mobile to maximize content space",
		]
	},
	{
		"version": "v0.67.1",
		"title": "Multi-touch potion usage",
		"date": "2026-02-25",
		"entries": [
			"Use potions while holding the joystick or attack button (multi-touch)",
			"Potion buttons now respond to any finger, not just the first touch",
			"Fixes Godot Button control ignoring second-finger taps on mobile",
		]
	},
	{
		"version": "v0.67.0",
		"title": "Double-click/tap to buy & upgrade everywhere",
		"date": "2026-02-25",
		"entries": [
			"Double-click/tap to quick-buy items in the shop (Buy tab)",
			"Double-click/tap to quick-sell items in the shop (Sell tab)",
			"Double-click/tap to quick-build upgrades at the woodworker",
			"Double-click/tap to quick-upgrade at the armory",
			"Single click still shows detail panel with stats — both options available",
		]
	},
	{
		"version": "v0.66.9",
		"title": "Armory double-click upgrade + scaling bonuses",
		"date": "2026-02-24",
		"entries": [
			"Armory: single click shows detail panel, double-click/tap quick-upgrades",
			"Weapon Forge bonuses now scale slightly with level (accelerating at higher levels)",
			"Armor Forge bonuses now scale slightly with level (armor and HP accelerate)",
		]
	},
	{
		"version": "v0.66.8",
		"title": "Consistent single-click detail across all shops",
		"date": "2026-02-24",
		"entries": [
			"Single click instantly shows detail panel in armory and woodworker (no more delay)",
			"Removed double-click quick-upgrade from armory and woodworker for consistency",
			"All shops now use the same pattern: click to view stats → button to buy/upgrade",
		]
	},
	{
		"version": "v0.66.7",
		"title": "Tavern back to random visit + UI polish",
		"date": "2026-02-24",
		"entries": [
			"Tavern reverted to simple random visit — single button, random buff/debuff outcome",
			"Tavern shows result text and active buff timer after visiting",
			"Armory keeps sleek detail panel with manual select → view stats → upgrade flow",
		]
	},
	{
		"version": "v0.66.6",
		"title": "Armory & Tavern UI redesign + double-click quick-build",
		"date": "2026-02-24",
		"entries": [
			"Armory redesigned with sleek upgrade list + detail panel (matches woodworker/shop)",
			"Tavern redesigned with browsable buff list + detail panel",
			"Double-click to quick-upgrade in armory, tavern, and woodworker",
			"All NPC dialogs now share consistent UI pattern: compact list → detail on click",
		]
	},
	{
		"version": "v0.66.5",
		"title": "Fix Shadow Ranger attack breaking permanently",
		"date": "2026-02-24",
		"entries": [
			"Fix critical bug: hit-freeze await could leave Engine.time_scale at 0.1 permanently",
			"Attacks now properly reset on death/respawn — no more stuck attack state",
			"Projectile tweens now owned by projectile node — prevents double-free errors",
			"Added safety resets for attack flags and time_scale on death and respawn",
		]
	},
	{
		"version": "v0.66.4",
		"title": "Woodworker UI redesign + enemy stuck fix",
		"date": "2026-02-24",
		"entries": [
			"Woodworker menu redesigned to match shop layout — concise upgrade list",
			"Click/tap an upgrade to see full details, bonuses, and build button",
			"Enemies no longer get stuck on the hero while moving",
			"Enemy attack state closing speed greatly reduced",
		]
	},
	{
		"version": "v0.66.3",
		"title": "Fix enemies getting stuck on the hero",
		"date": "2026-02-24",
		"entries": [
			"Enemies no longer chase the player at full speed while in attack state",
			"Narrowed attack disengage range so enemies let go sooner when player moves away",
			"Added player-repulsion push so enemies don't pile on top of the hero",
		]
	},
	{
		"version": "v0.66.2",
		"title": "Fix PWA orientation and mobile detection",
		"date": "2026-02-24",
		"entries": [
			"Fix PWA (Add to Home Screen) forcing landscape — now allows any orientation",
			"PWA/standalone mode on Android now correctly detects as mobile device",
			"Prioritize CSS pointer:coarse media query — most reliable touch detection for PWAs",
		]
	},
	{
		"version": "v0.66.1",
		"title": "Fix PWA (Add to Home Screen) always showing desktop layout",
		"date": "2026-02-24",
		"entries": [
			"PWA/standalone mode on Android now correctly detects as mobile",
			"Added CSS pointer:coarse media query check — reliably identifies touch-primary devices",
			"Works for Chrome Add to Home Screen, Samsung Internet, and other PWA launchers",
		]
	},
	{
		"version": "v0.66.0",
		"title": "Robust mobile detection with JavaScript fallback",
		"date": "2026-02-24",
		"entries": [
			"Fix landscape on phones showing desktop layout instead of mobile",
			"Centralized mobile detection via GameManager.is_mobile_device()",
			"JavaScript user-agent fallback for web exports where Godot API is unreliable",
			"All 20+ files now use the unified detection for consistent mobile layouts",
		]
	},
	{
		"version": "v0.65.9",
		"title": "Bigger close buttons, tap-outside-to-close, custom cursor",
		"date": "2026-02-24",
		"entries": [
			"Custom gold cursor — 15% larger on mobile for better visibility",
			"All panel X/close buttons enlarged on mobile for easier tapping",
			"Tap outside any open panel to close it (shop, inventory, tavern, etc.)",
			"Early-game tooltip explaining the cursor for new players",
		]
	},
	{
		"version": "v0.65.8",
		"title": "Custom branded loading screen and cinematic title intro",
		"date": "2026-02-24",
		"entries": [
			"Loading screen now shows 'OPEN LEGENDS RPG' title in gold with glowing text animation",
			"Modern slim progress bar with gold shimmer effect replaces the default Godot loading bar",
			"Loading percentage displayed below the bar",
			"Loading screen fades out smoothly when the game is ready",
			"Hero select intro: title fades in with scale punch, subtitle follows, then cards slide up",
			"Each element animates in sequence for a cinematic reveal",
		]
	},
	{
		"version": "v0.65.7",
		"title": "Fix loading in Facebook Messenger and in-app browsers",
		"date": "2026-02-24",
		"entries": [
			"Game now detects in-app browsers (Facebook, Instagram, Snapchat, TikTok, etc.)",
			"Shows a branded 'Open in Browser' page instead of hanging on a loading screen",
			"Tap the button to launch in Chrome/Safari where the game runs properly",
		]
	},
	{
		"version": "v0.65.6",
		"title": "Custom boot screen with cinematic title fade-in",
		"date": "2026-02-24",
		"entries": [
			"Boot splash now shows a dark screen instead of the Godot logo",
			"Title screen fades in cinematically from the dark boot background",
			"Smooth overlay dissolve followed by content reveal for a branded launch experience",
		]
	},
	{
		"version": "v0.65.5",
		"title": "Arrow Rain now reliably hits all nearby enemies",
		"date": "2026-02-24",
		"entries": [
			"Arrow Rain (triple-tap) now centered on the hero instead of offset in attack direction",
			"AoE radius increased from 70 to 150 — covers a much larger area",
			"Arrow count doubled from 6 to 12 for denser visual coverage",
			"Guaranteed AoE damage sweep hits all enemies in radius (no more gaps from random arrow placement)",
		]
	},
	{
		"version": "v0.65.4",
		"title": "Mobile virtual joystick",
		"date": "2026-02-24",
		"entries": [
			"Added floating virtual joystick on the left side of the screen for mobile movement",
			"Touch the left 40% of the screen to summon the joystick, drag to move in any direction",
			"Joystick adapts size for portrait and landscape orientations",
			"Tap-to-move still works outside the joystick area",
			"Joystick styled to match the SC:BW aesthetic (dark base, gold ring and knob)",
		]
	},
	{
		"version": "v0.65.3",
		"title": "Click/tap to aim dash attacks and specials",
		"date": "2026-02-24",
		"entries": [
			"Click or tap anywhere to set attack direction for dash strikes, charge attacks, and specials",
			"Desktop: left/right click sets aim direction (0.6s window) used by next attack",
			"Mobile: any non-ATK finger tap sets aim direction for the next attack",
			"Direction priority: held keys > recent click/tap > mobile touch > velocity > facing",
		]
	},
	{
		"version": "v0.65.2",
		"title": "Fix charge attack direction getting stuck",
		"date": "2026-02-24",
		"entries": [
			"Fixed charge attack direction getting overridden by click-to-move velocity",
			"Movement-based facing no longer resets aim direction while charging",
		]
	},
	{
		"version": "v0.65.1",
		"title": "8-direction hero sprites and charge aim arrow",
		"date": "2026-02-24",
		"entries": [
			"Heroes now face 8 directions instead of 4 — diagonal movement uses unique sprites",
			"New down-side and up-side diagonal idle and walk cycle sprites for both heroes",
			"Angle-based octant detection for smooth 8-way facing transitions",
			"Charge attack now shows a directional arrow indicator pointing where you'll attack",
			"Arrow updates in real-time as you aim during charge hold",
		]
	},
	{
		"version": "v0.65.0",
		"title": "Unique attack animations for all enemy types",
		"date": "2026-02-24",
		"entries": [
			"Every enemy type now has a unique attack animation matching their character",
			"Wolf bite with head shake, spider fang stab, bandit sword slash, skeleton sword swing",
			"Dark mage staff bolt, ogre fist slam, cave snake strike, bat swoop, flan bounce, mimic chomp",
			"Ghoul claw swipe, crypt knight armored swing, and all dungeon enemies",
			"15% chance for special attacks with 1.2-1.4x bonus damage and dramatic animations",
			"Troll mega punch, wolf savage lunge, spider venom strike, mimic devour, and more",
		]
	},
	{
		"version": "v0.64.5",
		"title": "Tap-to-aim during charge attack",
		"date": "2026-02-24",
		"entries": [
			"Mobile: tap anywhere on screen with a second finger while charging to aim the attack",
			"Desktop: click anywhere while holding attack to change aim direction",
			"Taps during charge set facing instead of issuing a move command",
		]
	},
	{
		"version": "v0.64.4",
		"title": "Power Strike rework — AoE lunge slam",
		"date": "2026-02-24",
		"entries": [
			"Power Strike now lunges the hero 80 units forward with a big bouncy slam",
			"Hits up to 5 enemies in a directional cone with 1.5x splash damage",
			"Triple slash VFX fan, stronger knockback (120), and bigger screen shake",
			"Satisfying spring-bounce recovery animation after impact",
		]
	},
	{
		"version": "v0.64.3",
		"title": "Fix charge attack aiming",
		"date": "2026-02-24",
		"entries": [
			"Character now faces aim direction throughout the entire charge hold",
			"Mobile: drag-to-aim works immediately when holding ATK, not just after charge is full",
			"Desktop: arrow keys update facing continuously while charging",
		]
	},
	{
		"version": "v0.64.2",
		"title": "Fill empty map areas with enemy camps",
		"date": "2026-02-24",
		"entries": [
			"Added 20 new enemy camps across previously empty outer and far zones",
			"Wolves, skeletons, spiders, bandits, trolls, dark mages, and ogres now fill gaps",
			"No more large empty stretches when exploring far from town",
		]
	},
	{
		"version": "v0.64.1",
		"title": "Mobile charge attack drag-to-aim",
		"date": "2026-02-24",
		"entries": [
			"Hold ATK to charge, then drag finger to aim the charged slash/sniper shot direction",
			"Hero faces the drag direction in real-time while charging for visual feedback",
			"Works just like holding arrow keys on desktop to aim before releasing",
		]
	},
	{
		"version": "v0.64.0",
		"title": "Dungeon minimap, larger crypt, enemy bounds",
		"date": "2026-02-24",
		"entries": [
			"Minimap now switches to dungeon layout when entering the Crypt",
			"Dungeon minimap shows enemy dots, exit beacon (green), and player position",
			"Click-to-move on minimap works within the dungeon",
			"Minimap restores to Haven's Rest layout on dungeon exit",
			"Dungeon Crypt doubled in size from 1000x1000 to 2000x2000",
			"Added 4 more enemy camps (12 total) spread across the larger dungeon",
			"Enemies now stay within dungeon walls instead of wandering into the void",
		]
	},
	{
		"version": "v0.63.3",
		"title": "Larger ATK button on mobile",
		"date": "2026-02-24",
		"entries": [
			"Mobile ATK button is now 20% larger for easier tapping",
		]
	},
	{
		"version": "v0.63.2",
		"title": "Fix dungeon enter/exit teleport loop",
		"date": "2026-02-24",
		"entries": [
			"Fixed entering dungeon immediately triggering exit beacon (teleport loop)",
			"Moved exit beacon away from dungeon spawn point",
			"Added 1s teleport cooldown to prevent beacon re-trigger after any teleport",
		]
	},
	{
		"version": "v0.63.1",
		"title": "Rat nerf + Bleeding debuff",
		"date": "2026-02-24",
		"entries": [
			"Rats nerfed: 50% reduced XP, attack damage, and attribute growth scaling",
			"Rats now have a 2% chance per hit to cause Bleeding (damage over time for 5 seconds)",
			"Bleeding effect shows red pulsing aura, BLEEDING! label, and blood drip particles",
			"New bleed tick SFX plays each second while bleeding",
		]
	},
	{
		"version": "v0.63.0",
		"title": "Underground Crypt dungeon",
		"date": "2026-02-24",
		"entries": [
			"New dungeon stairwell in town — enter the Crypt (requires Level 10)",
			"8 new dungeon enemy types: Cave Snake, Dungeon Bat, Vampire Bat, Flan, Mimic, Ghoul, Crypt Knight, Lich",
			"Each enemy has unique procedural sprite and death SFX",
			"Dark underground atmosphere with stone corridors",
			"Exit beacon to return to town",
			"Dungeon enter/exit sound effects",
		]
	},
	{
		"version": "v0.62.3",
		"title": "Fix ATK button overlapping OPT menu on mobile",
		"date": "2026-02-24",
		"entries": [
			"ATK button now hides when OPT or MAP overlay is open on mobile",
			"ATK button reappears when overlay is closed",
		]
	},
	{
		"version": "v0.62.2",
		"title": "Improved shop & save/load SFX",
		"date": "2026-02-24",
		"entries": [
			"Sell SFX: obvious CHA-CHING with drawer slam, coin cascade, and bright register bell",
			"Buy SFX: descending coins (spending) + soft thud (goods received) — distinct from sell",
			"New save game SFX: quill scratch on parchment + warm confirmation chime",
			"New load game SFX: page unfurling + ascending chime (world restored)",
		]
	},
	{
		"version": "v0.62.0",
		"title": "Double-tap quick-sell in shop",
		"date": "2026-02-24",
		"entries": [
			"Double-tap/double-click an item in the Sell tab to instantly sell it",
			"Hint label shown above sell list as a reminder",
			"Single-tap still opens item detail panel as before",
		]
	},
	{
		"version": "v0.61.5",
		"title": "Fix minimap tap-to-expand on mobile",
		"date": "2026-02-24",
		"entries": [
			"Small minimap in bottom bar is now tappable to open expanded view",
			"Fixed minimap consuming touch events even when in preview mode",
			"Click-to-move only active in the expanded overlay, not the small preview",
		]
	},
	{
		"version": "v0.61.2",
		"title": "Menu button on all platforms",
		"date": "2026-02-23",
		"entries": [
			"Desktop: Menu button added to command card grid (also Esc key)",
			"Mobile portrait: Menu button added to OPT command overlay",
			"Mobile landscape: Menu button added to compact command grid",
			"Removed unreliable floating top-bar menu button on mobile",
		]
	},
	{
		"version": "v0.61.1",
		"title": "Fix miniboss minimap diamond not appearing",
		"date": "2026-02-23",
		"entries": [
			"Mini-boss camps now spawn enemies immediately regardless of distance",
			"Fixes pulsing diamond indicator not showing on minimap when boss spawns far away",
		]
	},
	{
		"version": "v0.61.0",
		"title": "New enemy: Tree God Elk",
		"date": "2026-02-23",
		"entries": [
			"Added Tree God Elk — majestic nature-infused elk enemy (Lv8-11)",
			"Unique procedural sprite: bark body, branching antlers with green leaf tips, glowing green eyes",
			"Unique antler charge attack animation: rear up, stamp, gore charge, antler toss",
			"Unique nature collapse death animation: stagger wobble, root tendrils grow outward, green fade",
			"Spawns at 6:00 wave between trolls and dark mages",
		]
	},
	{
		"version": "v0.60.4",
		"title": "Miniboss minimap indicator",
		"date": "2026-02-23",
		"entries": [
			"Active minibosses now show as pulsing orange diamond on the minimap",
			"Diamond pulses to draw attention when '!! MINI-BOSS INCOMING !!' announces",
			"Indicator disappears when the miniboss is defeated",
		]
	},
	{
		"version": "v0.60.3",
		"title": "Button visual feedback across all UI",
		"date": "2026-02-23",
		"entries": [
			"All buttons now have hover glow, press feedback, and styled borders",
			"Pause menu: Resume, Save, Load, Changelog, Help, Quit, and Close buttons styled",
			"Tavern: Close and Visit buttons now have press/hover states",
			"Shop: Close, Buy/Sell tabs, Buy/Sell action, and Back buttons styled",
			"Changelog: Close button styled",
			"HUD: Menu button, command overlay buttons, and map overlay close button styled",
			"Help dialog: Close button styled",
		]
	},
	{
		"version": "v0.60.2",
		"title": "Fix mobile top bar cutoff & add kills to stats panel",
		"date": "2026-02-23",
		"entries": [
			"Top bar uses generous percentage-based padding for rounded screen corners",
			"Portrait: 6% horizontal + 4% top padding, Landscape: 5% horizontal padding",
			"Menu button and Kills label no longer hidden behind rounded corners or notch",
			"Hero stats panel now shows Total Kills and Next Milestone target",
		]
	},
	{
		"version": "v0.60.0",
		"title": "Kill Counter & Milestone Rewards",
		"date": "2026-02-23",
		"entries": [
			"Replaced alignment display with a kill counter in the top bar",
			"Kill counter tracks total enemies slain and updates in real-time",
			"Milestone rewards at 100, 200, 500, 1K, 2K, 5K, and 10K kills",
			"Each milestone grants gold and a random gear drop near the player",
			"Higher milestones drop rarer gear (Common → Legendary)",
			"Milestone progress saved and restored with save/load",
		]
	},
	{
		"version": "v0.59.0",
		"title": "Potion system overhaul: stacking % health potions",
		"date": "2026-02-23",
		"entries": [
			"Replaced all consumables with 3 potion types: Small (33% HP), Medium (50% HP), Great (100% HP)",
			"Potions now stack up to 99x in 3 dedicated HUD slots",
			"Healing scales with max HP — potions stay useful at every level",
			"Weak enemies drop Small Potions, mid enemies drop Medium, strong enemies drop Great",
			"Shop updated with all 3 potion tiers",
			"Removed mana potions and elixirs (simplified to health potions only)",
		]
	},
	{
		"version": "v0.58.1",
		"title": "Fix mobile command overlay potion indices",
		"date": "2026-02-23",
		"entries": [
			"Fixed mobile command overlay potion buttons pointing at wrong grid children after ability removal",
		]
	},
	{
		"version": "v0.58.0",
		"title": "Beacon entry sound effects",
		"date": "2026-02-23",
		"entries": [
			"Shop entrance plays welcoming door chime with coin sparkle",
			"Tavern entrance plays cozy wooden door thud with warm hearth tones",
			"Woodworker entrance plays rustic workshop creak with tool clinks",
			"Info beacon plays ethereal mystical knowledge chime",
		]
	},
	{
		"version": "v0.57.6",
		"title": "Desktop hero select screen overhaul",
		"date": "2026-02-23",
		"entries": [
			"Larger hero cards (420x520) with bigger fonts across the board",
			"Hero name now 36px uppercase with hero color accent",
			"Styled select buttons with hero-colored normal/hover/pressed states",
			"Bigger game title (64px), subtitle (22px), byline (20px), and version button (18px)",
			"Added color accent bar at top of each card",
		]
	},
	{
		"version": "v0.57.5",
		"title": "Fix hero load: restore _spawn_projectile",
		"date": "2026-02-23",
		"entries": [
			"Restored _spawn_projectile() to player.gd — was deleted during ability removal but is still used by Shadow Ranger's normal ranged attack and Shadow Step special attack",
		]
	},
	{
		"version": "v0.57.4",
		"title": "Fix hero not loading after ability removal",
		"date": "2026-02-23",
		"entries": [
			"Fixed crash on hero load: hud.gd setup() still referenced player.ability_mgr after AbilityManager was removed",
			"Removed leftover ability_font_size unused variable from hero_select.gd",
		]
	},
	{
		"version": "v0.57.3",
		"title": "Remove Q/E Abilities",
		"date": "2026-02-23",
		"entries": [
			"Removed Q and E ability system entirely from desktop and mobile",
			"Removed Ability1/Ability2 buttons from HUD command card (both scene and script)",
			"Removed ability tooltip system — panel, timer, hover/long-press handlers, builder function",
			"Removed ability buttons from mobile command overlay",
			"Removed Q/E input actions from project input map",
			"Removed AbilityManager node from player scene and all ability execution logic from player script",
			"Removed ability definitions from hero data (Cleave, Shield Wall, Multi-Shot, Evasion)",
			"Removed ability display from hero select screen",
			"Removed Q/E tutorial hints from all platforms; removed 'Hold ability button' mobile tip",
		]
	},
	{
		"version": "v0.57.2",
		"title": "Fix intermittent mobile browser hang on load",
		"date": "2026-02-23",
		"entries": [
			"export_presets: inject AudioContext pre-unlock script in HTML head — prevents Godot audio server stall on iOS/Android (browsers block AudioContext until first user gesture)",
			"AudioManager: trim startup pregeneration from 57 sounds down to 14 essentials — reduces JS thread hold time by ~4x on first frames; all other sounds lazy-load imperceptibly on first use",
			"AudioManager: add one-frame settle delay before pregeneration starts, and reduce batch size from 8 to 3 per frame",
			"SpriteGenerator: reduce web batch size from 10 to 4 sprites/frame; add one-frame settle delay before first batch — keeps hero-select screen responsive on slow mobile CPUs",
		]
	},
	{
		"version": "v0.57.1",
		"title": "Warmer Hero Respawn Sound",
		"date": "2026-02-23",
		"entries": [
			"Respawn complete SFX overhauled: extended to 2.2s (was 0.9s) with deep sub-bass swell, detuned choir unison pairs for natural warmth, harmonics that bloom in progressively, and staggered sparkle cascades",
		]
	},
	{
		"version": "v0.57.0",
		"title": "Mobile UI Overhaul — Bigger Buttons & Better Feedback",
		"date": "2026-02-23",
		"entries": [
			"Armory: upgrade buttons enlarged (320x110), styled hover/pressed/disabled states, tap SFX on press, forge sound lowered",
			"Woodworker: build buttons enlarged (300x100), styled hover/pressed/disabled states, tap SFX on press, build sound lowered",
			"Shop: item rows taller (100px), action buttons bigger (280/220), fonts increased across all labels",
			"Inventory: equipment slots taller (110px), bag grid items taller (110px), unequip buttons bigger (96x96), wider grid spacing",
			"Both armory and woodworker now flash the panel on successful upgrade for visual confirmation",
			"All upgrade/build buttons now have proper hover glow, press feedback, and disabled styling",
			"Item list spacing increased on mobile for easier tapping between rows",
		]
	},
	{
		"version": "v0.56.0",
		"title": "Overhauled Tutorial Tooltips",
		"date": "2026-02-23",
		"entries": [
			"Tooltips are now hero-specific — Blade Knight and Shadow Ranger get their own ability and special attack tips",
			"Mobile tooltips no longer reference keyboard keys (Q/E/SPACE) — uses 'ATK button' and 'left/right ability' instead",
			"Desktop tooltips use proper key names (Q, E, SPACE, I, Esc)",
			"Added close (X) button to tooltip panel — works on both mobile and desktop",
			"New tips: heal beacons and immunity, shops and town upgrades, tree chopping and wood yields, item drops and equipment, visual sprite upgrades every 5 levels, miniboss red beacons",
			"Ability tips now include their description (what the ability actually does)",
			"Special attack tips include damage multipliers and projectile counts",
		]
	},
	{
		"version": "v0.55.0",
		"title": "Hero Sprite Tier Upgrades",
		"date": "2026-02-23",
		"entries": [
			"Both Blade Knight and Shadow Ranger now get visual sprite upgrades every 5 levels (t1–t10)",
			"Blade Knight evolves from steel blue armor to radiant gold with growing crest, shoulder/shield emblems, and longer sword glow",
			"Shadow Ranger evolves from forest green to spectral violet with glowing eyes, bowstring aura, hood trim, and luminous arrow tips",
		]
	},
	{
		"version": "v0.54.1",
		"title": "Level Up SFX On Every Level",
		"date": "2026-02-23",
		"entries": [
			"Level-up rushing SFX now plays on every level up, not just at sprite upgrade milestones",
		]
	},
	{
		"version": "v0.54.0",
		"title": "Hero Long-Press Outline Feedback",
		"date": "2026-02-23",
		"entries": [
			"Touching and holding on the hero (mobile) now highlights the character with a bright green outline while holding",
			"Outline disappears when finger lifts, drifts away, or the stats panel opens",
		]
	},
	{
		"version": "v0.53.0",
		"title": "Proximity Beacon Labels & Longer Tooltips",
		"date": "2026-02-23",
		"entries": [
			"Info and Heal beacon labels now only appear when the hero is nearby (same range as NPC labels)",
			"Tutorial hint tooltips now display for 12 seconds instead of 6 for easier reading",
		]
	},
	{
		"version": "v0.52.0",
		"title": "Shop Q-Key & Consistent Mobile Close Buttons",
		"date": "2026-02-23",
		"entries": [
			"Shop now shows Close [Q] hint on desktop (was missing Q shortcut label)",
			"Mobile close buttons no longer show [Q] text — just a clean X",
			"All mobile X/close buttons are now the same larger size across every panel and modal",
		]
	},
	{
		"version": "v0.51.1",
		"title": "Cap Rat Spawn Level to Hero Level",
		"date": "2026-02-23",
		"entries": [
			"Rats no longer spawn at a higher level than the hero",
		]
	},
	{
		"version": "v0.51.0",
		"title": "Fix Enemies Getting Stuck & Hero Pathfinding",
		"date": "2026-02-23",
		"entries": [
			"Fixed enemies getting stuck oscillating instead of attacking (separation push now fans out around player, not away)",
			"Reduced disengage range from 4x to 2x attack range so enemies stay in combat",
			"Enemies now check range before dealing damage (no phantom hits from across the screen)",
			"Hero now steers around trees and buildings instead of getting stuck on them",
		]
	},
	{
		"version": "v0.50.0",
		"title": "Troll Combat Overhaul — Slow Heavy Attacks",
		"date": "2026-02-23",
		"entries": [
			"Trolls now attack with a slow, powerful overhead club slam (2.8s cooldown vs 1.2s default)",
			"New troll swing animation: long wind-up, menacing pause, heavy slam with impact shake, slow recovery",
			"Troll base attack damage increased (18 base vs formula default) — fewer hits but each one hurts",
			"Attack cooldown is now per-enemy-type (trolls 2.8s, others remain 1.2s)",
			"Troll attack range slightly increased (45 vs 40) to match their long arms",
		]
	},
	{
		"version": "v0.49.0",
		"title": "Fix Save/Load — All Stats & Resources Now Saved",
		"date": "2026-02-23",
		"entries": [
			"Wood amount is now saved and restored (was lost on every load)",
			"All woodwork upgrade levels (Bow, Shield, Totem, Watchtower) are now saved",
			"Hero stats (HP, STR, AGI, INT, armor, ATK, mana) now properly recalculated on load from level growth",
			"Armory and woodwork stat bonuses re-applied on load (weapon/armor/HP/XP bonuses were zeroed out)",
			"Skill points are now saved and restored",
			"Backwards-compatible: old saves load safely with defaults for new fields",
		]
	},
	{
		"version": "v0.48.1",
		"title": "Fix Desktop Tooltip Race Condition",
		"date": "2026-02-23",
		"entries": [
			"Fixed potential crash when quickly moving mouse away from ability buttons during tooltip delay",
		]
	},
	{
		"version": "v0.48.0",
		"title": "Tooltip & Hint System Overhaul",
		"date": "2026-02-23",
		"entries": [
			"Fixed tutorial hints being invisible (positioned off-screen due to anchor bug)",
			"Added gameplay hints: inventory, potions, beacons, trees, pause menu Help",
			"Mobile: hold Q or E for 0.6s to see ability tooltip (mana cost, cooldown, damage)",
			"Mobile: tap hint popups to dismiss them early",
			"Desktop: hover Q/E buttons for ability tooltips (unchanged)",
		]
	},
	{
		"version": "v0.47.1",
		"title": "Fix Top Bar Cutoff on Mobile Fullscreen",
		"date": "2026-02-23",
		"entries": [
			"Top resource bar (Gold, Wood, Alignment) no longer gets clipped at the right edge on mobile fullscreen",
			"Added safe-area-aware right padding so labels stay visible on devices with notches or rounded corners",
		]
	},
	{
		"version": "v0.47.0",
		"title": "Enemy Scaling Overhaul",
		"date": "2026-02-23",
		"entries": [
			"Enemies now scale much closer to the hero's level (85% stat growth vs 60% before)",
			"Respawned enemies stay stronger longer: decay 4% per respawn instead of 10%, floor raised from 60% to 80%",
			"XP per enemy level increased from +5 to +8, gold from +2 to +3 per level",
		]
	},
	{
		"version": "v0.46.1",
		"title": "Fix Reinforced Bow Build SFX",
		"date": "2026-02-23",
		"entries": [
			"Reinforced bow craft sound now ascends in pitch instead of descending, matching other positive upgrade sounds",
		]
	},
	{
		"version": "v0.46.0",
		"title": "More Enemies in the Wilds & Performance Optimization",
		"date": "2026-02-23",
		"entries": [
			"Added 20 new creep camps across mid-to-far zones (wolves, spiders, trolls, dark mages, ogres)",
			"Wave spawns now deploy more camps per wave (3-4 → 5-6) for denser encounters",
			"Reduced base respawn timer from 45s to 30s and wave respawn from 60s to 40s",
			"Performance: enemy separation now checks only camp-mates instead of all enemies globally (O(n²) → O(k))",
		]
	},
	{
		"version": "v0.45.1",
		"title": "More Opaque Panels & Fix Duplicate Close Button",
		"date": "2026-02-23",
		"entries": [
			"All dialog panels (shop, armory, inventory, tavern, etc.) are now much more opaque for better readability (78% -> 93%)",
			"Fixed inventory close button duplicating every time the panel was opened on mobile",
		]
	},
	{
		"version": "v0.45.0",
		"title": "Safari & Cross-Browser Fullscreen Fix",
		"date": "2026-02-23",
		"entries": [
			"iOS Safari: shows a one-time hint to 'Add to Home Screen' for fullscreen (API not supported by Apple)",
			"iOS Safari: maximizes viewport via CSS so the game fills as much screen as possible",
			"Fullscreen now re-engages on next tap if the user exits it (listeners no longer removed)",
			"Added vendor prefixes for older Firefox, Edge, and Safari fullscreen APIs",
			"Tries multiple fullscreen targets (document, body, canvas) for broader compatibility",
		]
	},
	{
		"version": "v0.44.2",
		"title": "More Forgiving Multi-Tap Specials",
		"date": "2026-02-23",
		"entries": [
			"Tap window for double-tap and triple-tap special attacks widened from 120ms to 180ms",
			"Whirlwind (triple-tap) and Power Strike (double-tap) are now much easier to trigger",
			"Same improvement applies to both desktop spacebar and mobile ATK button",
		]
	},
	{
		"version": "v0.44.1",
		"title": "Fix Charge Attack Getting Stuck on Mobile",
		"date": "2026-02-23",
		"entries": [
			"Fixed charge attack VFX getting stuck if finger lifts during an attack animation",
			"Added safety fallback that force-clears charge state if touch release event is lost",
			"Charge glow and sprite shake now always stop immediately on release",
		]
	},
	{
		"version": "v0.44.0",
		"title": "Hero Immunity Visual Feedback",
		"date": "2026-02-23",
		"entries": [
			"Hero now glows green with a pulsing aura when standing on a heal beacon",
			"Floating 'IMMUNE' label bobs above the hero while immunity is active",
			"Hero sprite pulses with a green tint to clearly show protected status",
			"All immunity visuals cleanly fade when stepping off the beacon",
		]
	},
	{
		"version": "v0.43.4",
		"title": "Fix Map Overlay Size in Landscape",
		"date": "2026-02-23",
		"entries": [
			"Map overlay no longer fills the entire screen in landscape mode",
			"Landscape map is now a compact centered panel (50% height, 45% width)",
		]
	},
	{
		"version": "v0.43.3",
		"title": "Fix Chrome Mobile Fullscreen (Again)",
		"date": "2026-02-23",
		"entries": [
			"Switched fullscreen trigger from touchstart/pointerdown to touchend/click events",
			"Chrome treats touchstart as passive, which silently blocks fullscreen requests",
			"Fullscreen listeners now persist until fullscreen actually succeeds instead of removing on first tap",
		]
	},
	{
		"version": "v0.43.2",
		"title": "Larger Mobile Buttons",
		"date": "2026-02-23",
		"entries": [
			"Close/X buttons are bigger and easier to tap on mobile across all dialogs",
			"Shop Buy/Sell and Back buttons enlarged for mobile",
			"Armory upgrade button enlarged for mobile",
		]
	},
	{
		"version": "v0.43.1",
		"title": "Fix Mobile Chrome Fullscreen",
		"date": "2026-02-23",
		"entries": [
			"Fixed fullscreen not triggering on Chrome mobile by using a native JS listener",
			"Fullscreen request now fires inside the browser's own event handler to satisfy user-activation requirements",
		]
	},
	{
		"version": "v0.43.0",
		"title": "Mobile Fullscreen & PWA Support",
		"date": "2026-02-23",
		"entries": [
			"Fullscreen now works more reliably on Android mobile browsers",
			"Enabled PWA so the game can be installed via 'Add to Home Screen'",
			"iOS users can add to home screen for a fullscreen experience",
		]
	},
	{
		"version": "v0.42.6",
		"title": "Consistent Panel Transparency & Mobile UX",
		"date": "2026-02-23",
		"entries": [
			"All menu/dialog panels now share the same 78% opacity for readability",
			"Inventory mobile close button is larger and easier to tap",
		]
	},
	{
		"version": "v0.42.5",
		"title": "More Transparent Inventory Panel",
		"date": "2026-02-23",
		"entries": [
			"Inventory panel is now more see-through (opacity 92% → 78%)",
		]
	},
	{
		"version": "v0.42.4",
		"title": "Fix Mob Group Pathfinding & Attack",
		"date": "2026-02-23",
		"entries": [
			"Enemies no longer physically block each other when chasing the hero",
			"Mobs in a group now swarm and attack aggressively instead of lining up",
			"Replaced hard enemy-to-enemy collision with soft proximity separation",
			"Enemies in attack state close distance on the hero more urgently",
		]
	},
	{
		"version": "v0.42.3",
		"title": "Game Messages Fit Portrait Screens",
		"date": "2026-02-23",
		"entries": [
			"Info beacon and other game messages now word-wrap on narrow screens",
			"Message container stretches to full viewport width with padding",
		]
	},
	{
		"version": "v0.42.2",
		"title": "Sleeker Hero Stats Panel",
		"date": "2026-02-23",
		"entries": [
			"Redesigned hero stats panel with a darker, semi-transparent backdrop",
			"Color-coded stat labels: HP in red, Mana in blue, bonuses in green/red",
			"Buff entries now have subtle tinted backgrounds and arrow icons",
			"Styled close button with hover effects and rounded corners",
			"Panel background uses rounded corners, border glow, and drop shadow",
			"Fixed readability on both desktop and mobile",
		]
	},
	{
		"version": "v0.42.1",
		"title": "Bigger MAP & OPT Buttons in Portrait",
		"date": "2026-02-23",
		"entries": [
			"MAP and OPT are now large square buttons flanking the bars",
			"MAP on the left, OPT (commands) on the right — much easier to tap",
			"Bottom bar height unchanged — buttons fill the full panel height",
		]
	},
	{
		"version": "v0.42.0",
		"title": "Long-Press Hero for Stats (Mobile)",
		"date": "2026-02-23",
		"entries": [
			"Hold your hero for 2 seconds on mobile to open the detailed stats panel",
			"Same panel as desktop right-click — shows HP, Mana, STR, AGI, INT, buffs",
			"Cancels if finger moves too far, so it won't interfere with movement or ATK",
			"Tutorial hints at ~20s, ~3min, and ~8min remind players about this feature",
		]
	},
	{
		"version": "v0.41.1",
		"title": "Fix ATK Button Positioning in Landscape",
		"date": "2026-02-23",
		"entries": [
			"ATK button now repositions on viewport resize via size_changed signal",
			"Fixes button placed off-screen when viewport size differs at _ready() time",
			"Button adapts correctly when switching between portrait and landscape",
		]
	},
	{
		"version": "v0.41.0",
		"title": "Cleaner Level-Up Notifications",
		"date": "2026-02-23",
		"entries": [
			"Level-up message shortened to 'Level Up! Lv X' — no more hero tier text",
			"Individual stat gains (+HP, +STR, etc.) now show as top-down notifications",
			"Level-up no longer triggers big center screen text — top-down only",
			"Removed duplicate LEVEL UP message from sprite upgrade milestones",
		]
	},
	{
		"version": "v0.40.2",
		"title": "Fix ATK Button Hidden in Landscape",
		"date": "2026-02-23",
		"entries": [
			"ATK button canvas layer raised to 11 so it renders above the HUD (layer 10)",
			"Fixes button being invisible in landscape where HUD bottom panel covered it",
		]
	},
	{
		"version": "v0.40.1",
		"title": "Thicker Mobile HP/MP/XP Bars",
		"date": "2026-02-23",
		"entries": [
			"HP/MP/XP bars doubled to 40px on mobile (portrait and landscape)",
			"ATK button and hint panel repositioned for taller bottom panel",
		]
	},
	{
		"version": "v0.40.0",
		"title": "Mobile MAP Button & Minimap Overlay",
		"date": "2026-02-23",
		"entries": [
			"Bottom bar now has CMD and MAP buttons stacked in portrait mode",
			"MAP button opens a fullwidth minimap overlay with click-to-move support",
			"Minimap renders at any size — dots and fog scale with the control",
			"Only one overlay open at a time (CMD closes MAP and vice versa)",
		]
	},
	{
		"version": "v0.39.5",
		"title": "Smooth Bars & Uniform Thickness",
		"date": "2026-02-23",
		"entries": [
			"Removed segmented drawing from HP/MP/XP bars — now smooth continuous fill",
			"All three bars (HP, MP, XP) are the same 20px height on every format",
			"No more per-platform bar size overrides — desktop, landscape, and portrait all match",
		]
	},
	{
		"version": "v0.39.2",
		"title": "Reliable Mobile Detection via Touchscreen API",
		"date": "2026-02-23",
		"entries": [
			"Mobile detection now uses DisplayServer.is_touchscreen_available() as primary check",
			"Fixes mobile layout not loading on high-res phones where both dimensions exceed 700px",
			"Works reliably in both portrait and landscape on all mobile devices",
		]
	},
	{
		"version": "v0.39.1",
		"title": "Fix Mobile Detection in Landscape",
		"date": "2026-02-23",
		"entries": [
			"Fixed mobile detection across all screens — landscape on mobile now correctly uses mobile layout",
			"Hero select screen in landscape on mobile now shows same mobile cards instead of desktop layout",
			"Detection changed from width-only check to min-dimension check (works for both orientations)",
		]
	},
	{
		"version": "v0.39.0",
		"title": "Minimal Mobile HUD — Maximum Map Visibility",
		"date": "2026-02-23",
		"entries": [
			"Bottom HUD in mobile portrait slashed from 380px to ~82px — reclaims ~300px of screen for the map",
			"Command card, minimap, and hero name/level all hidden from the bottom bar in portrait",
			"Bottom bar now shows only HP, MP, XP bars plus a single CMD button",
			"CMD button opens a floating overlay with all 9 command buttons (abilities, potions, items, save/load, log)",
			"Overlay auto-closes after tapping any command for quick one-tap access",
			"ATK button repositioned to sit just above the new thinner bottom bar",
			"Inventory and shop buttons enlarged with visual hover/press states and tap/hover SFX",
		]
	},
	{
		"version": "v0.38.1",
		"title": "Mobile Button Improvements for Inventory & Shop",
		"date": "2026-02-23",
		"entries": [
			"Inventory equipment buttons enlarged from 80px to 96px on mobile with bigger 34px font",
			"Inventory bag grid buttons enlarged from 76px to 92px on mobile with bigger 30px font",
			"Shop item rows enlarged from 60px to 80px on mobile with bigger 36px font",
			"Shop tab and action buttons enlarged for easier tapping on mobile",
			"All inventory and shop buttons now have styled normal/hover/pressed states with golden borders",
			"Added subtle tap SFX on button press and soft hover SFX on mouse enter",
			"Empty inventory slots now have a distinct dimmed style instead of just modulated opacity",
			"Shop item rows highlight with a golden border on hover and brighten on press",
		]
	},
	{
		"version": "v0.38.0",
		"title": "Landscape HUD Radical Compaction",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel slashed from 64px to 36px — nearly half the old height",
			"Minimap and hero name hidden in landscape to reclaim all wasted space",
			"HP/MP bars shrunk to 8px, XP bar to 3px with zero spacing between them",
			"Save/Load/Log buttons hidden in landscape (use Menu instead) — grid drops from 3x3 to 3x2",
			"Command buttons reduced to 52x14px for minimal footprint",
			"Top bar and menu button also shrunk for maximum game view",
			"ATK button repositioned closer to the thinner panel",
		]
	},
	{
		"version": "v0.37.2",
		"title": "Fix Bag Overlay Item Stats Hidden Behind HUD",
		"date": "2026-02-23",
		"entries": [
			"Fixed inventory item stats panel being hidden behind the bottom HUD on desktop",
			"Inventory panel now stops above the bottom HUD so item details are always fully visible",
		]
	},
	{
		"version": "v0.37.1",
		"title": "Fix Beacon Healing & Immunity",
		"date": "2026-02-23",
		"entries": [
			"Fixed heal beacon not healing or granting immunity: beacon_type was not set to 'heal' in the scene, so all healing and immunity code paths were skipped",
		]
	},
	{
		"version": "v0.37.0",
		"title": "Inventory UI Redesign",
		"date": "2026-02-23",
		"entries": [
			"Redesigned inventory as a compact right-side panel that no longer blocks the map",
			"Added tabbed Equipment/Bag layout so items and gear aren't crammed together",
			"Item stats now shown inline when hovering or tapping — no more off-screen tooltips",
			"Compact hero stats bar at the bottom shows HP, MP, ATK, armor, and attributes at a glance",
			"Equipment tab shows slot labels with unequip buttons for easy gear management",
			"Bag tab uses a clean grid with item names color-coded by rarity",
			"Panel is semi-transparent so the game world stays visible behind it",
			"Full-screen layout on mobile with larger tap targets and text",
		]
	},
	{
		"version": "v0.36.2",
		"title": "Beacon Immunity Timing Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed heal beacon immunity not working: moved heal/immunity logic to _physics_process so it runs in the same phase as enemy attacks (was in _process, which runs after enemies already attacked each frame)",
			"Heal beacon now grants immunity instantly on collision entry — no more one-frame vulnerability window",
			"Heal beacon now triggers healing immediately when hero steps on from outside",
			"Immunity flag is now also properly cleared on collision exit for reliable cleanup",
		]
	},
	{
		"version": "v0.36.1",
		"title": "Full Beacon Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now blocks ALL damage at the stats level — no code path can bypass it",
			"Mana is no longer consumed while on heal beacon (abilities are free)",
			"Enemy effects (knockback, paralyze, slow) are blocked while on heal beacon",
		]
	},
	{
		"version": "v0.36.0",
		"title": "Landscape HUD Ultra-Compact",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel reduced from 90px to 64px (~30% shorter)",
			"Command buttons shrunk from 24px to 18px height, 'Commands' label hidden in landscape",
			"HP/MP bars reduced to 12px, XP bar to 6px, minimap to 60x50 for minimal footprint",
			"Top bar and menu button also shrunk for maximum game view in landscape",
		]
	},
	{
		"version": "v0.35.1",
		"title": "Heal Beacon True Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heroes on a heal beacon are now fully immune to all damage (attacks do nothing)",
			"HP and mana are still restored to full every frame while on beacon",
			"Immunity flag is set/cleared as the hero enters/leaves beacon range",
		]
	},
	{
		"version": "v0.35.0",
		"title": "Landscape HUD Further Compacted",
		"date": "2026-02-23",
		"entries": [
			"Landscape bottom panel height reduced from 130px to 90px (~30% smaller)",
			"HP/MP bars shrunk from 22px to 14px, XP bar from 14px to 8px in landscape",
			"Command buttons reduced from 74x36 to 64x24, minimap from 110x90 to 80x65",
			"Top bar and all landscape font sizes reduced for more visible game area",
		]
	},
	{
		"version": "v0.34.1",
		"title": "Heal Beacon Immunity",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now restores HP/MP every frame so hero never loses health while standing on it",
			"Heal SFX and message only play when the beacon actually heals damage (silent at full HP)",
		]
	},
	{
		"version": "v0.34.0",
		"title": "Landscape Layout Optimization",
		"date": "2026-02-23",
		"entries": [
			"Bottom HUD panel height reduced ~30% for much more game view in landscape",
			"HP/MP/XP bars, command buttons, and minimap all compacted for landscape",
			"Mobile landscape layout significantly tighter (bottom panel 220px → 130px)",
			"Bar label font now auto-scales to bar height instead of fixed mobile/desktop sizes",
			"Browser auto-enters fullscreen on first tap to hide the address bar",
		]
	},
	{
		"version": "v0.33.1",
		"title": "Heal Beacon Full Area Fix",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now uses distance check so the entire visible area heals",
			"Heal SFX only plays once on entry, resets when you leave and return",
		]
	},
	{
		"version": "v0.33.0",
		"title": "Shop UI Redesign",
		"date": "2026-02-23",
		"entries": [
			"Completely redesigned shop with sleek tabbed Buy/Sell layout",
			"Tap any item to see full stats, description, rarity, and level requirement",
			"Buy and Sell buttons now inside the item detail panel for easy access",
			"Shop now shows feedback messages for purchases, sales, and errors",
			"ESC/Q closes item detail first, then closes the shop",
			"Much better mobile layout with larger tap targets and readable text",
		]
	},
	{
		"version": "v0.32.0",
		"title": "Loading Performance Optimization",
		"date": "2026-02-23",
		"entries": [
			"Reduced hero select loading lag (faster sprite and audio pre-generation)",
			"Reduced world loading lag (terrain and town now load asynchronously)",
			"Smoother transition when traveling outside the city walls",
		]
	},
	{
		"version": "v0.31.0",
		"title": "Heal Beacon Improvements",
		"date": "2026-02-23",
		"entries": [
			"Heal beacon now heals continuously while standing anywhere on it",
			"Heal SFX only plays when stepping on, not while staying on the beacon",
			"Fixed beacon collision areas not matching visual size (shared shape bug)",
		]
	},
	{
		"version": "v0.30.2",
		"title": "Version Display Fix",
		"date": "2026-02-23",
		"entries": [
			"Hero select version button now auto-reads from changelog (no more stale version)",
		]
	},
	{
		"version": "v0.30.1",
		"title": "Beacon Rendering Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed hero disappearing behind heal beacon and other beacons",
		]
	},
	{
		"version": "v0.30.0",
		"title": "Rat Swarm AI Fix",
		"date": "2026-02-23",
		"entries": [
			"Fixed rats glitching out and freezing when multiple are in combat",
			"Rats no longer get stuck oscillating between chase and attack states",
			"Swarms of enemies now properly surround and attack the player",
			"Capped enemy separation force so packs don't push each other into gridlock",
		]
	},
	{
		"version": "v0.29.0",
		"title": "Touch Attack Fixes & Pause Menu Close Button",
		"date": "2026-02-22 19:00",
		"entries": [
			"ATK button now flashes bright gold and scale-punches on every tap for clear feedback",
			"Fixed multi-touch special attacks not triggering (touches on UI were silently lost)",
			"Hold finger + double-tap ATK now reliably triggers Power Strike / Piercing Shot",
			"Two fingers on screen + tap ATK now reliably triggers Dash Strike / Shadow Step",
			"Attack direction on mobile is now derived from finger position relative to the player",
			"Pause menu now has a close X button in the top-right corner (matches all other menus)",
		]
	},
	{
		"version": "v0.28.0",
		"title": "Mobile Special Attacks & Pinch Zoom",
		"date": "2026-02-22 12:00",
		"entries": [
			"Added ATK button on mobile for special attacks (tap, double-tap, triple-tap, hold)",
			"Fast taps on ATK = same as fast spacebar presses (Power Strike, Whirlwind, etc.)",
			"Hold ATK for 1.5s = Charged Slash / Sniper Shot, just like holding spacebar",
			"Diagonal attacks on mobile: move diagonally then tap ATK for Dash Strike / Shadow Step",
			"Pinch-to-zoom on mobile with two-finger touch tracking",
			"Mobile zoom allows more zoom-in and less zoom-out than desktop (better for small screens)",
			"Tutorial hints updated for mobile controls (ATK button instead of SPACE key)",
		]
	},
	{
		"version": "v0.27.0",
		"title": "Combat Balance",
		"date": "2026-02-21",
		"entries": [
			"Rat damage raised from 8 to 12 (they now bite harder)",
			"Enemies can now override base attack damage per type",
			"Removed passive HP regeneration — use potions and heal beacons instead",
			"Mana still regenerates passively (needed for abilities)",
		]
	},
	{
		"version": "v0.26.0",
		"title": "Pause Menu",
		"date": "2026-02-21",
		"entries": [
			"Escape key now opens a pause menu instead of quitting",
			"Pause menu includes: Resume, Save Game, Load Game, Changelog, Help, Quit Game",
			"Game pauses while the menu is open",
			"Help screen with full controls reference and gameplay tips",
			"Mobile: small 'Menu' button in the top-left corner of the HUD",
			"Escape closes the pause menu when it's already open",
		]
	},
	{
		"version": "v0.25.0",
		"title": "Title Screen Branding",
		"date": "2026-02-21",
		"entries": [
			"Added 'OPEN LEGENDS RPG' game title with golden styling above hero select",
			"Added 'FORGE YOUR LEGEND' tagline beneath the title",
			"Added 'by Steve Levine' byline with clickable link to OpenClassActions.com",
		]
	},
	{
		"version": "v0.24.0",
		"title": "Mobile Text Scaling",
		"date": "2026-02-21",
		"entries": [
			"Enemy name labels doubled for mobile (9px → 18px)",
			"Enemy damage numbers doubled for mobile (14px → 28px normal, 28px → 44px crit)",
			"Enemy info popup text doubled for mobile (11px → 22px)",
			"Shop dialog: item names, prices, and Buy/Sell buttons doubled for mobile",
			"Inventory: equipment/bag buttons and stats text doubled for mobile",
			"Tavern dialog: all text and buttons doubled for mobile",
			"Armory dialog: upgrade text, costs, and buttons doubled for mobile",
			"Woodworking dialog: all upgrade text and buttons doubled for mobile",
			"Hero stats panel: all stats, buff entries, and timers doubled for mobile",
			"Town NPC name labels and beacon labels doubled for mobile",
			"Game messages and dramatic center messages doubled for mobile",
			"HP/Mana/XP bar label text doubled for mobile",
			"All dialog panels now expand to near-fullscreen on mobile",
		]
	},
	{
		"version": "v0.23.0",
		"title": "Enemy AI Aggro Fixes",
		"date": "2026-02-21",
		"entries": [
			"Fixed enemies ignoring the player while walking home (RETURN state now re-aggros)",
			"Fixed knockback pushing enemies past chase range causing them to go passive",
			"Fixed enemies falling asleep mid-walk during RETURN state",
		]
	},
	{
		"version": "v0.22.0",
		"title": "Mobile UI Overhaul",
		"date": "2026-02-21",
		"entries": [
			"Hero select: title/subtitle, card names, type tags, and SELECT buttons all doubled for mobile",
			"In-game HUD: command card buttons doubled from 68x44 to 144x90 with 22px font",
			"HUD top bar resource labels doubled to 32px on mobile",
			"HP/Mana/XP bars, unit info, and minimap all scaled up for mobile",
			"Ability tooltips and tutorial hints scaled to 26-30px font on mobile",
			"All command buttons are now large enough to tap comfortably on phones",
			"Tapping ability buttons (Q/E) now casts abilities on mobile",
			"Tapping potion buttons (1/2/3) now uses consumables on mobile",
			"Tapping Items button now opens inventory on mobile",
			"Disabled tooltip hover on mobile so taps cast instead of showing tooltips",
		]
	},
	{
		"version": "v0.21.0",
		"title": "Licensing & IP Protection",
		"date": "2026-02-21",
		"entries": [
			"Added All Rights Reserved LICENSE for full project protection",
			"Added MIT + Proprietary Assets dual-license option (LICENSE-MIT)",
			"Added ASSETS_LICENSE.txt covering all art, music, characters, and branding",
			"Added CONTRIBUTING.md with IP ownership terms for contributors",
			"Updated README with clear licensing section",
		]
	},
	{
		"version": "v0.20.0",
		"title": "Massive Text Size Increase",
		"date": "2026-02-21",
		"entries": [
			"Changelog headers and entry text are now 2x bigger on both desktop and mobile",
			"Version Log button on hero select is 3x bigger on mobile",
			"Changelog title bar, close button, and version label scaled up to match",
			"Desktop changelog panel enlarged to fit the bigger text",
		]
	},
	{
		"version": "v0.19.0",
		"title": "Full Cache-Busting",
		"date": "2026-02-21",
		"entries": [
			"All JS, CSS, and image assets in the web build are now cache-busted with a git hash",
			"Service worker script is also cache-busted to prevent stale cross-origin isolation",
			"Fixes browsers showing outdated versions after new deploys",
		]
	},
	{
		"version": "v0.18.0",
		"title": "Mobile Changelog Readability",
		"date": "2026-02-21",
		"entries": [
			"Changelog text is now much larger and easier to read on mobile",
			"Changelog panel expands to fill the screen on mobile devices",
			"Close button and title bar are larger on mobile for easier tapping",
			"Version headers now word-wrap on narrow screens",
		]
	},
	{
		"version": "v0.17.0",
		"title": "Changelog Timestamps",
		"date": "2026-02-21",
		"entries": [
			"All changelog entries now display the date they were released",
			"Version bump to v0.17.0",
		]
	},
	{
		"version": "v0.16.0",
		"title": "Mobile Tap Targeting",
		"date": "2026-02-21",
		"entries": [
			"Enemy and tree click/tap targets are now much more forgiving on mobile",
			"Added expanded touch areas around enemies for easier tapping",
			"Added expanded touch areas around harvestable trees for easier tapping",
			"Physics queries now use area overlap instead of point intersection for fat-finger tolerance",
			"Hero select cards are now fully tappable — tap anywhere on the card, not just the SELECT button",
			"Card hover highlight now triggers on the entire card on desktop",
		]
	},
	{
		"version": "v0.15.0",
		"title": "Combat & Equipment Fixes",
		"date": "2026-02-21",
		"entries": [
			"Clicking or spacebar-attacking an enemy now auto-attacks until you move or act",
			"Auto-attacks are always plain basic swings — no combos or specials",
			"Player automatically chases target if it walks out of melee range",
			"Fixed enemies gluing onto hero and moving in sync during combat",
			"Fixed rats and small enemies freezing instead of attacking in groups",
			"Enemies hit while retreating home now fight back instead of ignoring you",
			"Equipping items now shows an error message when level requirement is not met",
			"Ravager's Cleaver can now be equipped immediately after dropping",
		]
	},
	{
		"version": "v0.14.0",
		"title": "Clickable Tree Harvesting",
		"date": "2026-02-21",
		"entries": [
			"Left-click trees to walk to them and auto-chop — no more mashing spacebar",
			"Harvestable trees now glow with a green outline on mouse hover",
			"Right-click any tree to inspect its wood yield before chopping",
			"Wood yields increased 5x: small ~15, medium ~30, large ~60",
			"Each tree has a randomized wood amount that varies by size",
		]
	},
	{
		"version": "v0.13.0",
		"title": "Enemy Overhaul",
		"date": "2026-02-21",
		"entries": [
			"Rats now aggressively pursue players with increased aggro range",
			"Rats randomly alert to player presence even outside direct detection",
			"Added unique sprites for all 6 missing enemy types",
			"Tree chopping now uses a proper pickaxe animation instead of sword attack",
		]
	},
	{
		"version": "v0.12.0",
		"title": "Music & Crafting",
		"date": "2026-02-21",
		"entries": [
			"Town music now rotates between 5 completely different tracks every minute",
			"Expanded town theme to 3:12 with 8 distinct sections",
			"Overhauled town theme sound design with richer timbres, vibrato, and atmosphere",
			"Added woodworking system: spend wood to craft upgrades for character progression",
		]
	},
	{
		"version": "v0.11.0",
		"title": "Buildings & Resources",
		"date": "2026-02-20",
		"entries": [
			"Added tree chopping system with wood resource collection",
			"Added tavern building with wench visit mechanic (buff/debuff system)",
			"Added hero stats panel with buff/debuff display on right-click",
			"Reduced minion loading lag with staggered spawning and distance-based sleep",
			"Reduced combat lag with object pooling and squared distance optimizations",
		]
	},
	{
		"version": "v0.10.0",
		"title": "Performance & World",
		"date": "2026-02-20",
		"entries": [
			"Massive performance overhaul across entire codebase",
			"Fixed remaining performance hotspots across UI and gameplay systems",
			"Massively improved ground tile variety to eliminate repetitive look",
			"Charged slash now hits all enemies in its path, not just one",
			"Power strike requires movement direction held to trigger",
		]
	},
	{
		"version": "v0.9.0",
		"title": "Audio System",
		"date": "2026-02-20",
		"entries": [
			"Added procedural audio system with SFX and ambient soundtrack",
			"Overhauled attack SFX — replaced hollow sine waves with richer sounds",
			"Sword swing now sounds like a blade — metallic shing with warm slice feel",
			"Added charge sound system with looping buildup and blast release",
		]
	},
	{
		"version": "v0.8.0",
		"title": "Items & Combat",
		"date": "2026-02-20",
		"entries": [
			"Simplified dash strike: diagonal keys + space",
			"Massively expanded items, affixes, enemy types, and map population",
			"Fixed dash strike not hitting enemies",
		]
	},
	{
		"version": "v0.7.0",
		"title": "Smoothness & Polish",
		"date": "2026-02-20",
		"entries": [
			"Added large rat swarms near town as starter mobs (15-20 per group)",
			"Fixed hero jitter when idle and during charge attacks",
			"Fixed game choppiness from hit freeze overlap, screen shake stacking, VFX spam",
			"Disabled pixel snap, enabled VSync, softer camera and movement",
			"Bumped physics tick rate 60 -> 120 Hz for smoother movement",
		]
	},
	{
		"version": "v0.6.0",
		"title": "Combat Expansion",
		"date": "2026-02-20",
		"entries": [
			"Added unit effects, right-click attack, and improved minion AI",
			"Added special attack system: double-tap, triple-tap, charge, dash strike",
			"Fixed attack input so normal hold/mash always works",
			"Fixed multi-tap specials with 0.12s buffer for proper resolution",
		]
	},
	{
		"version": "v0.5.0",
		"title": "Movement & Animation",
		"date": "2026-02-20",
		"entries": [
			"Smooth player movement with acceleration, walk bob, and lean",
			"Added proper walk cycle animation replacing programmatic bob",
			"Fixed jitter from per-frame sprite texture reassignment",
			"Enabled physics interpolation and tightened camera for smooth feel",
		]
	},
	{
		"version": "v0.4.0",
		"title": "Controls",
		"date": "2026-02-20",
		"entries": [
			"Arrow key direction now used for abilities (Q/E), not just mouse",
			"Hold Space to auto-attack at normal cooldown rate",
			"Added persistent facing direction and directional idle sprites",
			"Added click-to-move on minimap",
		]
	},
	{
		"version": "v0.3.0",
		"title": "World Expansion",
		"date": "2026-02-20",
		"entries": [
			"Enlarged map to 12000x9000",
			"Added enemy patrol behavior",
		]
	},
	{
		"version": "v0.2.0",
		"title": "Core Architecture",
		"date": "2026-02-20",
		"entries": [
			"Implemented SC:BW-style deterministic architecture with full game systems",
			"Fixed parser and trigger system errors",
		]
	},
	{
		"version": "v0.1.0",
		"title": "Initial Release",
		"date": "2026-02-20",
		"entries": [
			"Fixed crash with Control nodes in Godot 4",
			"Switched from isometric to simple top-down 2D",
			"Fixed game freeze at level 5 from infinite loop in message cleanup",
		]
	},
]

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)
	_style_btn(close_button, Color(1.0, 0.4, 0.3))
	version_label.text = GAME_VERSION

func open() -> void:
	_is_visible = true
	panel.visible = true
	var vp_size = get_viewport().get_visible_rect().size
	_is_mobile = GameManager.is_mobile_device()
	_resize_panel(vp_size)
	_build_entries()
	scroll.scroll_vertical = 0

func _resize_panel(vp_size: Vector2) -> void:
	if _is_mobile:
		# Fill most of the screen on mobile
		var margin = 10.0
		panel.offset_left = -vp_size.x / 2.0 + margin
		panel.offset_right = vp_size.x / 2.0 - margin
		panel.offset_top = -vp_size.y / 2.0 + margin
		panel.offset_bottom = vp_size.y / 2.0 - margin
		close_button.text = "X"
		close_button.custom_minimum_size = Vector2(160, 130)
		close_button.add_theme_font_size_override("font_size", 60)
		version_label.add_theme_font_size_override("font_size", 40)
		$Panel/MarginContainer/VBox/TopBar/Title.add_theme_font_size_override("font_size", 56)
	else:
		panel.offset_left = -420.0
		panel.offset_right = 420.0
		panel.offset_top = -380.0
		panel.offset_bottom = 380.0

func close() -> void:
	_is_visible = false
	panel.visible = false

func _build_entries() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	var header_size = 56 if _is_mobile else 32
	var entry_size = 42 if _is_mobile else 24
	var spacer_height = 24 if _is_mobile else 12

	for patch in CHANGELOG:
		# Version header with date
		var header = Label.new()
		var date_str: String = patch.get("date", "")
		if date_str != "":
			header.text = "%s — %s  (%s)" % [patch["version"], patch["title"], date_str]
		else:
			header.text = "%s — %s" % [patch["version"], patch["title"]]
		header.add_theme_font_size_override("font_size", header_size)
		header.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entries_container.add_child(header)

		# Entries
		for entry in patch["entries"]:
			var line = Label.new()
			line.text = "  • " + entry
			line.add_theme_font_size_override("font_size", entry_size)
			line.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entries_container.add_child(line)

		# Spacer between versions
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, spacer_height)
		entries_container.add_child(spacer)

func _style_btn(btn: Button, accent: Color = Color(0.9, 0.75, 0.3)) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.08, 0.95)
	normal.border_color = accent * Color(0.5, 0.5, 0.5, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(4)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 0.95)
	hover.border_color = accent * Color(0.8, 0.8, 0.8, 0.8)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.25, 0.22, 0.14, 0.95)
	pressed.border_color = accent
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

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
