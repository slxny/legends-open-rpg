extends Node

## Procedural audio manager — generates all SFX and music from code.
## No external audio files needed.

const SAMPLE_RATE = 22050
const SFX_POOL_SIZE = 8

var _sfx_cache: Dictionary = {}   # name -> AudioStreamWAV
var _music_cache: Dictionary = {}  # name -> AudioStreamWAV
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_volume_db: float = -10.0
var _sfx_volume_db: float = 0.0

# Music rotation system
var _rotation_tracks: Array[String] = []
var _rotation_index: int = 0
var _rotation_timer: Timer
var _rotation_active: bool = false

# Background thread for expensive music generation
var _music_gen_thread: Thread = null
var _music_gen_queued: String = ""

func _ready() -> void:
	_create_players()
	_pregenerate_async()

# ============================================================
# PUBLIC API
# ============================================================

func _ensure_sfx(sfx_name: String) -> AudioStreamWAV:
	var cached = _sfx_cache.get(sfx_name)
	if cached:
		return cached
	var method_name = "_gen_" + sfx_name
	if has_method(method_name):
		var stream = call(method_name)
		_sfx_cache[sfx_name] = stream
		return stream
	return null

## Generate a music track on a background thread and play it when done.
## If a thread is already running, queues the request.
func _play_or_gen_music(music_name: String) -> void:
	var stream = _music_cache.get(music_name)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = _music_volume_db
		_music_player.play()
		return
	if not has_method("_gen_" + music_name):
		return
	# If a generation thread is already running, queue this track
	if _music_gen_thread != null:
		_music_gen_queued = music_name
		return
	_music_gen_thread = Thread.new()
	_music_gen_thread.start(_threaded_gen_music.bind(music_name))

func _threaded_gen_music(music_name: String) -> void:
	var method_name = "_gen_" + music_name
	if has_method(method_name):
		var stream = call(method_name)
		_music_cache[music_name] = stream
	call_deferred("_on_threaded_music_done", music_name)

func _on_threaded_music_done(music_name: String) -> void:
	if _music_gen_thread:
		_music_gen_thread.wait_to_finish()
	_music_gen_thread = null
	var stream = _music_cache.get(music_name)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = _music_volume_db
		_music_player.play()
	# Process queued track
	if not _music_gen_queued.is_empty():
		var next = _music_gen_queued
		_music_gen_queued = ""
		_play_or_gen_music(next)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _music_gen_thread and _music_gen_thread.is_started():
			_music_gen_thread.wait_to_finish()

func get_sfx(sfx_name: String) -> AudioStreamWAV:
	return _ensure_sfx(sfx_name)

var _next_sfx_player: int = 0  # Round-robin index for SFX pool

func play_sfx(sfx_name: String, volume_offset: float = 0.0) -> void:
	var stream = _ensure_sfx(sfx_name)
	if not stream:
		return
	# Quick check from round-robin position for an idle player
	for _i in range(SFX_POOL_SIZE):
		var p = _sfx_players[_next_sfx_player]
		_next_sfx_player = (_next_sfx_player + 1) % SFX_POOL_SIZE
		if not p.playing:
			p.stream = stream
			p.volume_db = _sfx_volume_db + volume_offset
			p.play()
			return
	# All players busy — steal the next in round-robin
	var p = _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.volume_db = _sfx_volume_db + volume_offset
	p.play()

func play_music(music_name: String) -> void:
	var stream = _music_cache.get(music_name)
	if stream and _music_player.stream == stream and _music_player.playing:
		return
	_play_or_gen_music(music_name)

func stop_music() -> void:
	_music_player.stop()
	stop_rotation()

func start_rotation(track_names: Array[String], interval: float = 60.0, total_duration: float = 300.0) -> void:
	## Rotates through the given tracks, switching every `interval` seconds.
	## Stops after `total_duration` seconds total.
	stop_rotation()
	_rotation_tracks = track_names
	_rotation_index = 0
	_rotation_active = true
	# Play the first track immediately
	play_music_direct(_rotation_tracks[0])
	# Create the switch timer
	_rotation_timer = Timer.new()
	_rotation_timer.wait_time = interval
	_rotation_timer.one_shot = false
	_rotation_timer.timeout.connect(_on_rotation_tick)
	add_child(_rotation_timer)
	_rotation_timer.start()
	# Create a one-shot timer to stop everything after total_duration
	var stop_timer = Timer.new()
	stop_timer.wait_time = total_duration
	stop_timer.one_shot = true
	stop_timer.timeout.connect(stop_rotation)
	add_child(stop_timer)
	stop_timer.start()

func stop_rotation() -> void:
	_rotation_active = false
	if _rotation_timer and is_instance_valid(_rotation_timer):
		_rotation_timer.stop()
		_rotation_timer.queue_free()
		_rotation_timer = null

func _on_rotation_tick() -> void:
	if not _rotation_active or _rotation_tracks.is_empty():
		return
	_rotation_index = (_rotation_index + 1) % _rotation_tracks.size()
	play_music_direct(_rotation_tracks[_rotation_index])

func play_music_direct(music_name: String) -> void:
	## Like play_music but always restarts even if same track
	_play_or_gen_music(music_name)

var _saved_rotation_tracks: Array[String] = []
var _saved_rotation_active: bool = false

## Temporarily override music (e.g. for boss fights). Pauses rotation.
func override_music(music_name: String) -> void:
	if _rotation_active:
		_saved_rotation_tracks = _rotation_tracks.duplicate()
		_saved_rotation_active = true
		stop_rotation()
	play_music_direct(music_name)

## Restore the normal rotation after a boss override. If oneshot_first plays a short track first (e.g. victory fanfare), then resumes.
func restore_music(oneshot_first: String = "") -> void:
	if oneshot_first != "":
		play_music_direct(oneshot_first)
		# After the oneshot track finishes, resume rotation
		if not _music_player.finished.is_connected(_on_oneshot_done):
			_music_player.finished.connect(_on_oneshot_done, CONNECT_ONE_SHOT)
	else:
		_resume_rotation()

func _on_oneshot_done() -> void:
	_resume_rotation()

func _resume_rotation() -> void:
	if _saved_rotation_active and _saved_rotation_tracks.size() > 0:
		start_rotation(_saved_rotation_tracks, 60.0, 300.0)
		_saved_rotation_active = false
		_saved_rotation_tracks.clear()

# ============================================================
# PLAYER SETUP
# ============================================================

func _create_players() -> void:
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = _music_volume_db
	add_child(_music_player)

## Background pre-generation for lightweight SFX only.
## Music tracks generate on a background Thread when first played
## (see _play_or_gen_music) — each is 60s+ of PCM at 22050Hz, far too
## heavy for the main thread even spread across frames.
func _pregenerate_async() -> void:
	var sfx_names = ["sword_swing", "hit_impact", "crit_hit", "enemy_death",
		"gold_pickup", "item_pickup", "level_up", "dash_swoosh",
		"ability_whoosh", "power_strike", "whirlwind", "player_hurt",
		"charge_loop", "charge_ready", "charge_release", "tree_chop",
		"tree_fall", "rat_squeal_1", "rat_squeal_2", "rat_squeal_3",
		"debuff_apply", "player_death", "respawn_countdown", "respawn_complete",
		"forge_weapon", "forge_armor", "woodwork_bow", "woodwork_shield",
		"woodwork_totem", "woodwork_watchtower", "shop_buy", "shop_sell",
		"equip_weapon", "equip_armor", "equip_helm", "equip_boots",
		"equip_ring", "equip_amulet", "potion_heal", "potion_mana", "potion_buff"]
	var batch: int = 0
	for sfx_name in sfx_names:
		if _sfx_cache.has(sfx_name):
			continue
		_ensure_sfx(sfx_name)
		batch += 1
		if batch >= 3:
			batch = 0
			await get_tree().process_frame

# ============================================================
# WAVEFORM HELPERS
# ============================================================

func _make_samples(duration: float) -> Array[float]:
	var count = int(SAMPLE_RATE * duration)
	var arr: Array[float] = []
	arr.resize(count)
	arr.fill(0.0)
	return arr

func _add_sine(samples: Array[float], freq: float, volume: float = 1.0, start: float = 0.0) -> void:
	var start_idx = int(start * SAMPLE_RATE)
	for i in range(start_idx, samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] += sin(t * freq * TAU) * volume

func _add_sine_segment(samples: Array[float], freq: float, volume: float, start: float, duration: float) -> void:
	var s = int(start * SAMPLE_RATE)
	var e = min(s + int(duration * SAMPLE_RATE), samples.size())
	for i in range(s, e):
		var t = float(i) / SAMPLE_RATE
		var local_t = float(i - s) / max(e - s, 1)
		# Quick fade in/out to avoid clicks
		var env = min(local_t * 20.0, 1.0) * min((1.0 - local_t) * 20.0, 1.0)
		samples[i] += sin(t * freq * TAU) * volume * env

func _add_noise(samples: Array[float], volume: float = 1.0, start: float = 0.0) -> void:
	var start_idx = int(start * SAMPLE_RATE)
	for i in range(start_idx, samples.size()):
		samples[i] += randf_range(-1.0, 1.0) * volume

func _apply_envelope(samples: Array[float], attack: float, sustain: float, release: float) -> void:
	var total = samples.size()
	var a_samples = int(attack * SAMPLE_RATE)
	var s_samples = int(sustain * SAMPLE_RATE)
	var r_samples = int(release * SAMPLE_RATE)
	for i in range(total):
		var env: float
		if i < a_samples:
			env = float(i) / max(a_samples, 1)
		elif i < a_samples + s_samples:
			env = 1.0
		else:
			var ri = i - a_samples - s_samples
			env = max(0.0, 1.0 - float(ri) / max(r_samples, 1))
		samples[i] *= env

func _apply_decay(samples: Array[float], decay_time: float) -> void:
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= max(0.0, 1.0 - t / decay_time)

func _mix_into(dest: Array[float], src: Array[float], offset: int = 0) -> void:
	for i in range(src.size()):
		var di = i + offset
		if di >= 0 and di < dest.size():
			dest[di] += src[i]

func _normalize(samples: Array[float], peak: float = 0.9) -> void:
	var max_val = 0.0
	for s in samples:
		max_val = max(max_val, absf(s))
	if max_val > 0.001:
		var scale = peak / max_val
		for i in range(samples.size()):
			samples[i] *= scale

func _soft_clip(samples: Array[float], drive: float = 2.0) -> void:
	## Warm saturation — adds natural harmonics so things don't sound hollow
	for i in range(samples.size()):
		var x = samples[i] * drive
		samples[i] = x / (1.0 + absf(x))

func _add_pitched_noise(samples: Array[float], center_freq: float, bandwidth: float, volume: float = 1.0, start: float = 0.0) -> void:
	## Band-pass-ish noise — sounds less harsh than raw white noise
	## Uses a simple 1-pole resonator to shape noise around a center frequency
	var start_idx = int(start * SAMPLE_RATE)
	var r = exp(-PI * bandwidth / SAMPLE_RATE)
	var cos_w = cos(TAU * center_freq / SAMPLE_RATE)
	var a1 = -2.0 * r * cos_w
	var a2 = r * r
	var prev1 = 0.0
	var prev2 = 0.0
	for i in range(start_idx, samples.size()):
		var noise_in = randf_range(-1.0, 1.0)
		var out = noise_in - a1 * prev1 - a2 * prev2
		prev2 = prev1
		prev1 = out
		samples[i] += out * volume * (1.0 - r)  # Normalize by bandwidth

func _pitch_sweep_sine(samples: Array[float], freq_start: float, freq_end: float, volume: float = 1.0, start: float = 0.0) -> void:
	## Sine with smooth pitch sweep — sounds organic, not robotic
	var start_idx = int(start * SAMPLE_RATE)
	var phase = 0.0
	for i in range(start_idx, samples.size()):
		var frac = float(i - start_idx) / max(samples.size() - start_idx, 1)
		var freq = lerpf(freq_start, freq_end, frac)
		phase += freq / SAMPLE_RATE
		samples[i] += sin(phase * TAU) * volume

func _to_stream(samples: Array[float], loop: bool = false) -> AudioStreamWAV:
	_normalize(samples)
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

# ============================================================
# SFX GENERATION
# ============================================================

func _generate_all_sfx() -> void:
	_sfx_cache["sword_swing"] = _gen_sword_swing()
	_sfx_cache["hit_impact"] = _gen_hit_impact()
	_sfx_cache["crit_hit"] = _gen_crit_hit()
	_sfx_cache["enemy_death"] = _gen_enemy_death()
	_sfx_cache["gold_pickup"] = _gen_gold_pickup()
	_sfx_cache["item_pickup"] = _gen_item_pickup()
	_sfx_cache["level_up"] = _gen_level_up()
	_sfx_cache["dash_swoosh"] = _gen_dash_swoosh()
	_sfx_cache["ability_whoosh"] = _gen_ability_whoosh()
	_sfx_cache["power_strike"] = _gen_power_strike()
	_sfx_cache["whirlwind"] = _gen_whirlwind()
	_sfx_cache["player_hurt"] = _gen_player_hurt()
	_sfx_cache["charge_loop"] = _gen_charge_loop()
	_sfx_cache["charge_ready"] = _gen_charge_ready()
	_sfx_cache["charge_release"] = _gen_charge_release()
	_sfx_cache["tree_chop"] = _gen_tree_chop()
	_sfx_cache["tree_fall"] = _gen_tree_fall()
	_sfx_cache["beacon_heal"] = _gen_beacon_heal()
	_sfx_cache["forge_weapon"] = _gen_forge_weapon()
	_sfx_cache["forge_armor"] = _gen_forge_armor()
	_sfx_cache["woodwork_bow"] = _gen_woodwork_bow()
	_sfx_cache["woodwork_shield"] = _gen_woodwork_shield()
	_sfx_cache["woodwork_totem"] = _gen_woodwork_totem()
	_sfx_cache["woodwork_watchtower"] = _gen_woodwork_watchtower()
	_sfx_cache["shop_buy"] = _gen_shop_buy()
	_sfx_cache["shop_sell"] = _gen_shop_sell()
	_sfx_cache["equip_weapon"] = _gen_equip_weapon()
	_sfx_cache["equip_armor"] = _gen_equip_armor()
	_sfx_cache["equip_helm"] = _gen_equip_helm()
	_sfx_cache["equip_boots"] = _gen_equip_boots()
	_sfx_cache["equip_ring"] = _gen_equip_ring()
	_sfx_cache["equip_amulet"] = _gen_equip_amulet()
	_sfx_cache["potion_heal"] = _gen_potion_heal()
	_sfx_cache["potion_mana"] = _gen_potion_mana()
	_sfx_cache["potion_buff"] = _gen_potion_buff()

func _gen_sword_swing() -> AudioStreamWAV:
	# Warm blade slice — smooth swoosh with subtle metal edge
	var samples = _make_samples(0.15)
	# Warm descending swoosh body (the core of the slice)
	_pitch_sweep_sine(samples, 700.0, 250.0, 0.3)
	_pitch_sweep_sine(samples, 400.0, 150.0, 0.15)
	# Soft airy layer
	_add_pitched_noise(samples, 1800.0, 1200.0, 0.15)
	# Just a touch of metal edge — quiet and brief, not ringy
	_add_sine(samples, 1600.0, 0.07)
	_add_sine(samples, 2400.0, 0.04)
	_apply_envelope(samples, 0.005, 0.02, 0.12)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_hit_impact() -> AudioStreamWAV:
	# Warm punchy thud — clean bass knock with bright snap on top
	var samples = _make_samples(0.12)
	# Bass body — stays in audible range, not sub-bass mud
	_pitch_sweep_sine(samples, 160.0, 80.0, 0.6)
	# Warm mid harmonic
	_pitch_sweep_sine(samples, 320.0, 160.0, 0.25)
	# Upper presence for definition
	_pitch_sweep_sine(samples, 640.0, 300.0, 0.1)
	# Quick bright snap at the very start
	var snap = _make_samples(0.02)
	_add_pitched_noise(snap, 1800.0, 1200.0, 0.35)
	_apply_envelope(snap, 0.001, 0.003, 0.016)
	_mix_into(samples, snap)
	_apply_envelope(samples, 0.003, 0.02, 0.10)
	_soft_clip(samples, 1.5)
	return _to_stream(samples)

func _gen_crit_hit() -> AudioStreamWAV:
	# Bigger impact — warm bass knock + clear metallic ting
	var samples = _make_samples(0.18)
	# Full bass thump
	_pitch_sweep_sine(samples, 180.0, 90.0, 0.55)
	_pitch_sweep_sine(samples, 360.0, 180.0, 0.25)
	_pitch_sweep_sine(samples, 540.0, 250.0, 0.12)
	# Clean metallic ting (tonal, not noisy)
	var ting = _make_samples(0.08)
	_add_sine(ting, 1200.0, 0.3)
	_add_sine(ting, 2400.0, 0.12)
	_apply_envelope(ting, 0.001, 0.01, 0.07)
	_mix_into(samples, ting)
	# Bright snap transient
	var snap = _make_samples(0.025)
	_add_pitched_noise(snap, 2200.0, 1500.0, 0.3)
	_apply_envelope(snap, 0.001, 0.005, 0.02)
	_mix_into(samples, snap)
	_apply_envelope(samples, 0.002, 0.03, 0.15)
	_soft_clip(samples, 1.6)
	return _to_stream(samples)

func _gen_enemy_death() -> AudioStreamWAV:
	# Satisfying defeat thud — warm descending knock with mid presence
	var samples = _make_samples(0.28)
	# Descending thud in pleasant bass range
	_pitch_sweep_sine(samples, 140.0, 60.0, 0.55)
	_pitch_sweep_sine(samples, 280.0, 120.0, 0.25)
	# Mid-range presence so it's warm not muddy
	_pitch_sweep_sine(samples, 420.0, 200.0, 0.12)
	# Crisp burst at start
	var burst = _make_samples(0.04)
	_add_pitched_noise(burst, 1400.0, 800.0, 0.3)
	_apply_envelope(burst, 0.002, 0.008, 0.03)
	_mix_into(samples, burst)
	_apply_envelope(samples, 0.003, 0.05, 0.23)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_gold_pickup() -> AudioStreamWAV:
	# Ascending coin chime: C5, E5, G5
	var samples = _make_samples(0.25)
	_add_sine_segment(samples, 523.0, 0.5, 0.0, 0.08)
	_add_sine_segment(samples, 659.0, 0.5, 0.06, 0.08)
	_add_sine_segment(samples, 784.0, 0.6, 0.12, 0.13)
	_apply_decay(samples, 0.3)
	return _to_stream(samples)

func _gen_item_pickup() -> AudioStreamWAV:
	# Bright crystal ding
	var samples = _make_samples(0.3)
	_add_sine(samples, 880.0, 0.4)
	_add_sine(samples, 1320.0, 0.2)
	_add_sine(samples, 1760.0, 0.1)
	_apply_envelope(samples, 0.005, 0.05, 0.25)
	return _to_stream(samples)

func _gen_level_up() -> AudioStreamWAV:
	# Rich triumphant fanfare — warm bass foundation with shimmering arpeggio
	var samples = _make_samples(1.2)
	# Warm bass foundation (C3) gives weight and satisfaction
	_add_sine_segment(samples, 130.8, 0.3, 0.0, 0.9)
	_add_sine_segment(samples, 65.4, 0.15, 0.0, 0.7)
	# Ascending arpeggio: C4 -> E4 -> G4 -> C5 with overlapping sustain
	_add_sine_segment(samples, 261.6, 0.35, 0.0, 0.35)
	_add_sine_segment(samples, 329.6, 0.35, 0.12, 0.35)
	_add_sine_segment(samples, 392.0, 0.4, 0.24, 0.35)
	_add_sine_segment(samples, 523.0, 0.45, 0.36, 0.55)
	# Octave shimmer on the final note for brilliance
	_add_sine_segment(samples, 1046.0, 0.15, 0.36, 0.55)
	_add_sine_segment(samples, 784.0, 0.12, 0.36, 0.55)
	_add_sine_segment(samples, 1568.0, 0.06, 0.45, 0.4)
	# Sparkle — high pitched noise burst for that satisfying "ding" feel
	_add_pitched_noise(samples, 4000.0, 2000.0, 0.04, 0.36)
	_add_pitched_noise(samples, 6000.0, 1500.0, 0.03, 0.42)
	# Fifth harmony layer (G4 sustained under the final C5)
	_add_sine_segment(samples, 392.0, 0.15, 0.36, 0.5)
	_apply_decay(samples, 1.3)
	_soft_clip(samples, 1.5)
	return _to_stream(samples)

func _gen_beacon_heal() -> AudioStreamWAV:
	# Soft music-box arpeggio — gentle staggered chime notes, no horn-like sweeps
	var samples = _make_samples(0.9)
	# Ascending major arpeggio: C5 → E5 → G5 → C6, each a short pluck
	var notes = [523.0, 659.0, 784.0, 1046.0]  # C5, E5, G5, C6
	var spacing = 0.12  # time between each note onset
	for idx in range(notes.size()):
		var onset = idx * spacing
		var vol = 0.18 - idx * 0.02  # soften higher notes slightly
		var dur = 0.45 - idx * 0.05  # higher notes ring a bit shorter
		_add_sine_segment(samples, notes[idx], vol, onset, dur)
		# Add soft octave-above harmonic for bell-like quality
		_add_sine_segment(samples, notes[idx] * 2.0, vol * 0.15, onset, dur * 0.6)
	# Delicate high sparkle (very quiet, narrow band)
	_add_pitched_noise(samples, 6000.0, 800.0, 0.012, 0.3)
	_apply_envelope(samples, 0.02, 0.35, 0.53)
	_normalize(samples, 0.55)
	return _to_stream(samples)

func _gen_dash_swoosh() -> AudioStreamWAV:
	# Bright quick swoosh — airy and clean, not rumbling
	var samples = _make_samples(0.15)
	# High-mid noise for rushing air
	_add_pitched_noise(samples, 2800.0, 1800.0, 0.3)
	_add_pitched_noise(samples, 1400.0, 900.0, 0.2)
	# Descending tonal body for motion feel
	_pitch_sweep_sine(samples, 600.0, 200.0, 0.15)
	_pitch_sweep_sine(samples, 1200.0, 400.0, 0.06)
	_apply_envelope(samples, 0.005, 0.02, 0.12)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_ability_whoosh() -> AudioStreamWAV:
	# Rising magical sweep — clean ascending tone with airy shimmer
	var samples = _make_samples(0.25)
	# Bright shimmer noise
	_add_pitched_noise(samples, 2200.0, 1200.0, 0.15)
	# Clean ascending tonal sweep
	_pitch_sweep_sine(samples, 300.0, 900.0, 0.25)
	_pitch_sweep_sine(samples, 600.0, 1800.0, 0.1)
	# Warm mid body
	_pitch_sweep_sine(samples, 450.0, 700.0, 0.1)
	_apply_envelope(samples, 0.01, 0.07, 0.17)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_power_strike() -> AudioStreamWAV:
	# Wind-up then strong warm hit
	var samples = _make_samples(0.26)
	# Phase 1: Clean rising tension
	_pitch_sweep_sine(samples, 250.0, 600.0, 0.18)
	_pitch_sweep_sine(samples, 500.0, 1200.0, 0.07)
	# Phase 2: Warm heavy impact at ~0.13s
	var impact = _make_samples(0.13)
	_pitch_sweep_sine(impact, 200.0, 80.0, 0.6)
	_pitch_sweep_sine(impact, 400.0, 160.0, 0.25)
	_pitch_sweep_sine(impact, 600.0, 250.0, 0.1)
	# Clean bright transient
	var snap = _make_samples(0.03)
	_add_pitched_noise(snap, 2000.0, 1400.0, 0.35)
	_apply_envelope(snap, 0.001, 0.005, 0.025)
	_mix_into(impact, snap)
	_apply_envelope(impact, 0.002, 0.03, 0.10)
	_soft_clip(impact, 1.6)
	_mix_into(samples, impact, int(0.13 * SAMPLE_RATE))
	_apply_envelope(samples, 0.008, 0.07, 0.18)
	return _to_stream(samples)

func _gen_whirlwind() -> AudioStreamWAV:
	# Spinning wind — bright airy texture with gentle modulation
	var samples = _make_samples(0.38)
	# Airy mid-high noise for wind
	_add_pitched_noise(samples, 1200.0, 800.0, 0.25)
	_add_pitched_noise(samples, 2400.0, 1200.0, 0.15)
	# Gentle spinning modulation
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var spin_rate = lerpf(10.0, 28.0, t / 0.38)
		var mod = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * spin_rate))
		samples[i] *= mod
	# Warm tonal body
	_pitch_sweep_sine(samples, 250.0, 350.0, 0.15)
	_pitch_sweep_sine(samples, 500.0, 700.0, 0.06)
	_apply_envelope(samples, 0.02, 0.15, 0.21)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_player_hurt() -> AudioStreamWAV:
	# Quick warm knock — clear and defined, not muffled
	var samples = _make_samples(0.1)
	_pitch_sweep_sine(samples, 200.0, 100.0, 0.5)
	_pitch_sweep_sine(samples, 400.0, 200.0, 0.2)
	# Bit of brightness for clarity
	_add_pitched_noise(samples, 1400.0, 800.0, 0.2)
	_apply_envelope(samples, 0.003, 0.015, 0.08)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_charge_loop() -> AudioStreamWAV:
	# Looping hum that builds tension — rising tone with pulsing energy
	# Kept short and looped so it plays continuously while holding
	var dur = 0.6
	var samples = _make_samples(dur)
	# Low pulsing hum — warm oscillating base
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		# Slowly rising pitch across the loop
		var freq = lerpf(120.0, 180.0, t / dur)
		var phase = t * freq
		samples[i] += sin(phase * TAU) * 0.3
		# Second harmonic for warmth
		samples[i] += sin(phase * 2.0 * TAU) * 0.12
		# Pulsing amplitude modulation — "gathering energy" throb
		var pulse = 0.6 + 0.4 * sin(t * 8.0 * TAU)
		samples[i] *= pulse
	# Soft shimmer on top
	_add_pitched_noise(samples, 1200.0, 600.0, 0.06)
	_soft_clip(samples, 1.3)
	_normalize(samples, 0.7)
	return _to_stream(samples, true)  # loop = true

func _gen_charge_ready() -> AudioStreamWAV:
	# Quick bright chime — tells the player "fully charged, ready to release"
	# Like a confirmation ping / power-up complete ding
	var samples = _make_samples(0.2)
	# Ascending two-note chime
	_add_sine_segment(samples, 600.0, 0.3, 0.0, 0.1)
	_add_sine_segment(samples, 900.0, 0.35, 0.06, 0.14)
	# Harmonics for sparkle
	_add_sine_segment(samples, 1200.0, 0.12, 0.06, 0.14)
	_add_sine_segment(samples, 1800.0, 0.06, 0.06, 0.12)
	_apply_envelope(samples, 0.003, 0.03, 0.17)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_charge_release() -> AudioStreamWAV:
	# Discharge blast — explosive burst of energy releasing at once
	# Like a cannon/energy discharge: sharp transient into booming bass
	var samples = _make_samples(0.3)
	# Sharp bright crack at the very start (the "snap" of release)
	var crack = _make_samples(0.03)
	_add_pitched_noise(crack, 3000.0, 2000.0, 0.4)
	_add_pitched_noise(crack, 1600.0, 1000.0, 0.3)
	_apply_envelope(crack, 0.001, 0.004, 0.025)
	_mix_into(samples, crack)
	# Heavy bass boom — the power behind the release
	_pitch_sweep_sine(samples, 220.0, 80.0, 0.6)
	_pitch_sweep_sine(samples, 440.0, 160.0, 0.25)
	# Mid presence for warmth and clarity
	_pitch_sweep_sine(samples, 660.0, 250.0, 0.12)
	# Whooshing tail — the energy dispersing
	_add_pitched_noise(samples, 800.0, 600.0, 0.15, 0.02)
	_apply_envelope(samples, 0.002, 0.05, 0.25)
	_soft_clip(samples, 1.8)
	return _to_stream(samples)

func _gen_tree_chop() -> AudioStreamWAV:
	# Chunky wood chop — sharp thwack with woody resonance
	var samples = _make_samples(0.15)
	# Sharp crack transient (axe/blade hitting wood)
	var crack = _make_samples(0.02)
	_add_pitched_noise(crack, 2200.0, 1400.0, 0.35)
	_apply_envelope(crack, 0.001, 0.003, 0.016)
	_mix_into(samples, crack)
	# Woody thud body — mid-bass, warm
	_pitch_sweep_sine(samples, 200.0, 100.0, 0.45)
	_pitch_sweep_sine(samples, 400.0, 200.0, 0.2)
	# Woody resonance
	_add_sine_segment(samples, 300.0, 0.15, 0.01, 0.08)
	_apply_envelope(samples, 0.002, 0.02, 0.12)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_tree_fall() -> AudioStreamWAV:
	# Tree falling — creaking descent into ground thump
	var samples = _make_samples(0.5)
	# Creaking (descending tone with harmonics)
	_pitch_sweep_sine(samples, 350.0, 120.0, 0.3)
	_pitch_sweep_sine(samples, 700.0, 240.0, 0.12)
	# Cracking/splintering noise layer
	_add_pitched_noise(samples, 1200.0, 800.0, 0.15, 0.0)
	# Ground impact thump at the end
	var thump = _make_samples(0.15)
	_pitch_sweep_sine(thump, 120.0, 50.0, 0.5)
	_pitch_sweep_sine(thump, 240.0, 100.0, 0.2)
	_apply_envelope(thump, 0.003, 0.02, 0.13)
	_mix_into(samples, thump, int(0.3 * SAMPLE_RATE))
	_apply_envelope(samples, 0.01, 0.1, 0.4)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_debuff_apply() -> AudioStreamWAV:
	# Cutesy descending two-note chime — "boo-boop" minor third drop
	# Sounds negative but adorable, like a music-box going "aww"
	var samples = _make_samples(0.35)
	# Note 1: E5 (high, bright start)
	_add_sine_segment(samples, 659.0, 0.35, 0.0, 0.14)
	_add_sine_segment(samples, 1318.0, 0.10, 0.0, 0.10)   # Octave harmonic for bell quality
	_add_sine_segment(samples, 1978.0, 0.04, 0.0, 0.07)   # Soft upper partial
	# Note 2: C5 (drops down a minor third — the "sad but cute" interval)
	_add_sine_segment(samples, 523.0, 0.38, 0.10, 0.18)
	_add_sine_segment(samples, 1046.0, 0.12, 0.10, 0.14)   # Octave harmonic
	_add_sine_segment(samples, 1569.0, 0.04, 0.10, 0.10)   # Upper partial
	# Tiny wobble on the second note for extra character
	for i in range(int(0.10 * SAMPLE_RATE), samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.9 + 0.1 * sin(t * 18.0 * TAU)
	_apply_envelope(samples, 0.008, 0.10, 0.24)
	_normalize(samples, 0.6)
	return _to_stream(samples)

func _gen_rat_squeal_1() -> AudioStreamWAV:
	# Throaty chitter — low warbling squeak with amplitude modulation
	var samples = _make_samples(0.14)
	_pitch_sweep_sine(samples, 480.0, 720.0, 0.16)
	_pitch_sweep_sine(samples, 650.0, 400.0, 0.10, 0.04)
	# Sub-harmonic growl layer
	_pitch_sweep_sine(samples, 240.0, 360.0, 0.06)
	_add_pitched_noise(samples, 600.0, 400.0, 0.05)
	# Amplitude modulation for warbling/chittering
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.7 + 0.3 * sin(t * 45.0 * TAU)
	_apply_envelope(samples, 0.004, 0.03, 0.10)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_rat_squeal_2() -> AudioStreamWAV:
	# Quick nasal grunt — deep and guttural with pitch wobble
	var samples = _make_samples(0.10)
	_pitch_sweep_sine(samples, 400.0, 650.0, 0.14)
	_pitch_sweep_sine(samples, 550.0, 350.0, 0.08, 0.03)
	# Gritty sub layer
	_pitch_sweep_sine(samples, 200.0, 320.0, 0.05)
	_add_pitched_noise(samples, 500.0, 350.0, 0.06)
	# Pitch wobble for organic feel
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.8 + 0.2 * sin(t * 30.0 * TAU)
	_apply_envelope(samples, 0.003, 0.02, 0.07)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_rat_squeal_3() -> AudioStreamWAV:
	# Breathy hiss-squeak — rising then falling with tremolo
	var samples = _make_samples(0.16)
	_pitch_sweep_sine(samples, 450.0, 800.0, 0.10)
	_pitch_sweep_sine(samples, 700.0, 380.0, 0.08, 0.05)
	_add_pitched_noise(samples, 550.0, 500.0, 0.08)
	# Sub rumble
	_pitch_sweep_sine(samples, 220.0, 280.0, 0.04)
	# Fast tremolo for rattly texture
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.6 + 0.4 * sin(t * 55.0 * TAU)
	_apply_envelope(samples, 0.005, 0.04, 0.11)
	_soft_clip(samples, 1.1)
	return _to_stream(samples)

func _gen_player_death() -> AudioStreamWAV:
	# Dramatic death sound — heavy descending thud with dark reverb tail
	# Deep, final, weighty — like a body hitting the ground with a dark echo
	var samples = _make_samples(0.8)
	# Heavy body-fall impact — deep bass thud
	_pitch_sweep_sine(samples, 100.0, 35.0, 0.6)
	_pitch_sweep_sine(samples, 200.0, 70.0, 0.3)
	# Dark mid-range groan — gives it a dramatic "fallen" quality
	_pitch_sweep_sine(samples, 300.0, 120.0, 0.15)
	# Crack transient at the start (armor/bones hitting ground)
	var crack = _make_samples(0.04)
	_add_pitched_noise(crack, 1600.0, 1000.0, 0.35)
	_apply_envelope(crack, 0.001, 0.006, 0.033)
	_mix_into(samples, crack)
	# Dark reverb tail — low rumbling decay
	var tail = _make_samples(0.5)
	_add_sine(tail, 55.0, 0.12)
	_add_sine(tail, 82.0, 0.06)
	_add_pitched_noise(tail, 200.0, 150.0, 0.04)
	_apply_decay(tail, 0.6)
	_mix_into(samples, tail, int(0.15 * SAMPLE_RATE))
	# Descending minor chord — eerie finality (E3, G3, Bb3 — diminished)
	_add_sine_segment(samples, 164.81, 0.06, 0.05, 0.5)
	_add_sine_segment(samples, 196.0, 0.04, 0.05, 0.45)
	_add_sine_segment(samples, 233.08, 0.03, 0.05, 0.4)
	_apply_envelope(samples, 0.003, 0.1, 0.7)
	_soft_clip(samples, 1.8)
	return _to_stream(samples)

func _gen_respawn_countdown() -> AudioStreamWAV:
	# Short countdown tick — clean, urgent ping for 3-2-1 countdown
	# Like a clock tick with a tonal ring — clear and sharp
	var samples = _make_samples(0.2)
	# Bright tick note (G5)
	_add_sine_segment(samples, 784.0, 0.4, 0.0, 0.12)
	# Harmonic shimmer
	_add_sine_segment(samples, 1568.0, 0.12, 0.0, 0.08)
	_add_sine_segment(samples, 2352.0, 0.05, 0.0, 0.06)
	# Click transient
	var click = _make_samples(0.015)
	_add_pitched_noise(click, 3000.0, 2000.0, 0.2)
	_apply_envelope(click, 0.001, 0.003, 0.011)
	_mix_into(samples, click)
	_apply_envelope(samples, 0.002, 0.03, 0.17)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_respawn_complete() -> AudioStreamWAV:
	# Regeneration complete — bright ascending arpeggio with magical shimmer
	# Triumphant, hopeful, energizing — life returns
	var samples = _make_samples(0.9)
	# Ascending power chord: C4 -> E4 -> G4 -> C5 with warm sustain
	_add_sine_segment(samples, 261.6, 0.30, 0.0, 0.30)
	_add_sine_segment(samples, 329.6, 0.30, 0.08, 0.30)
	_add_sine_segment(samples, 392.0, 0.35, 0.16, 0.30)
	_add_sine_segment(samples, 523.3, 0.40, 0.24, 0.45)
	# Octave shimmer on final note for brilliance
	_add_sine_segment(samples, 1046.0, 0.12, 0.24, 0.40)
	_add_sine_segment(samples, 784.0, 0.10, 0.24, 0.40)
	# Magical sparkle — high frequency noise bursts
	_add_pitched_noise(samples, 5000.0, 2000.0, 0.03, 0.24)
	_add_pitched_noise(samples, 7000.0, 1500.0, 0.02, 0.30)
	# Warm bass foundation
	_add_sine_segment(samples, 130.8, 0.15, 0.0, 0.6)
	_apply_decay(samples, 1.0)
	_soft_clip(samples, 1.5)
	return _to_stream(samples)

func _gen_forge_weapon() -> AudioStreamWAV:
	# Blacksmith hammer strike — sharp metallic clang with rising harmonic ring
	# Satisfying "ting!" of hot metal being shaped, ascending pitch = improvement
	var samples = _make_samples(0.55)
	# Hammer impact — sharp transient crack of metal on metal
	var strike = _make_samples(0.03)
	_add_pitched_noise(strike, 3500.0, 2000.0, 0.4)
	_add_pitched_noise(strike, 5000.0, 1500.0, 0.2)
	_apply_envelope(strike, 0.001, 0.004, 0.025)
	_mix_into(samples, strike)
	# Metallic ring — bright sustained tone that sings after the strike
	_add_sine_segment(samples, 1100.0, 0.3, 0.01, 0.45)
	_add_sine_segment(samples, 2200.0, 0.15, 0.01, 0.35)
	_add_sine_segment(samples, 3300.0, 0.07, 0.01, 0.25)
	# Rising harmonic sweep — the weapon getting stronger
	_pitch_sweep_sine(samples, 800.0, 1400.0, 0.12, 0.02)
	# Warm anvil body thud underneath
	_pitch_sweep_sine(samples, 180.0, 90.0, 0.35)
	_pitch_sweep_sine(samples, 360.0, 180.0, 0.15)
	# Quick ascending two-note confirmation: "done!"
	_add_sine_segment(samples, 660.0, 0.2, 0.30, 0.12)
	_add_sine_segment(samples, 880.0, 0.25, 0.36, 0.15)
	_add_sine_segment(samples, 1760.0, 0.08, 0.36, 0.12)
	_apply_envelope(samples, 0.002, 0.12, 0.43)
	_soft_clip(samples, 1.6)
	return _to_stream(samples)

func _gen_forge_armor() -> AudioStreamWAV:
	# Heavy anvil clang with deep resonant sustain — armor plate being tempered
	# Weightier than weapon forge, more bass, slower ring = solid protection
	var samples = _make_samples(0.65)
	# Heavy hammer blow — deeper and weightier than weapon forge
	var blow = _make_samples(0.04)
	_add_pitched_noise(blow, 2200.0, 1600.0, 0.35)
	_add_pitched_noise(blow, 1200.0, 800.0, 0.25)
	_apply_envelope(blow, 0.001, 0.006, 0.033)
	_mix_into(samples, blow)
	# Deep anvil ring — lower pitch, heavier feeling
	_add_sine_segment(samples, 700.0, 0.3, 0.01, 0.50)
	_add_sine_segment(samples, 1400.0, 0.12, 0.01, 0.40)
	_add_sine_segment(samples, 2100.0, 0.05, 0.01, 0.30)
	# Deep bass body — the weight of the armor
	_pitch_sweep_sine(samples, 120.0, 60.0, 0.4)
	_pitch_sweep_sine(samples, 240.0, 120.0, 0.2)
	# Plate resonance — shimmering mid layer
	_add_sine_segment(samples, 500.0, 0.15, 0.02, 0.35)
	_add_sine_segment(samples, 350.0, 0.10, 0.02, 0.40)
	# Confirmation chord — solid, grounded (C4 + G4)
	_add_sine_segment(samples, 261.6, 0.18, 0.35, 0.20)
	_add_sine_segment(samples, 392.0, 0.15, 0.38, 0.20)
	_add_sine_segment(samples, 523.3, 0.10, 0.40, 0.18)
	_apply_envelope(samples, 0.002, 0.15, 0.50)
	_soft_clip(samples, 1.7)
	return _to_stream(samples)

func _gen_woodwork_bow() -> AudioStreamWAV:
	# Taut bowstring snap with woody resonance — string being drawn and released
	# Sharp twang followed by vibrating string hum, satisfying elastic snap
	var samples = _make_samples(0.45)
	# Bowstring twang — sharp pitched snap that vibrates
	var twang_freq = 330.0  # E4
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		# Vibrating string with natural decay and slight pitch drop
		var freq = twang_freq * (1.0 - t * 0.08)
		samples[i] += sin(t * freq * TAU) * 0.35
		# Harmonics of the string
		samples[i] += sin(t * freq * 2.0 * TAU) * 0.15
		samples[i] += sin(t * freq * 3.0 * TAU) * 0.06
		# Fast tremolo simulating string vibration
		samples[i] *= 0.85 + 0.15 * sin(t * 60.0 * TAU)
	# Woody body resonance underneath
	_add_sine_segment(samples, 165.0, 0.2, 0.0, 0.25)
	_add_sine_segment(samples, 247.0, 0.1, 0.0, 0.20)
	# Sharp initial snap transient
	var snap = _make_samples(0.02)
	_add_pitched_noise(snap, 4000.0, 2500.0, 0.3)
	_apply_envelope(snap, 0.001, 0.003, 0.016)
	_mix_into(samples, snap)
	# Ascending confirmation note
	_add_sine_segment(samples, 494.0, 0.15, 0.25, 0.15)  # B4
	_add_sine_segment(samples, 988.0, 0.05, 0.25, 0.12)
	_apply_envelope(samples, 0.002, 0.10, 0.35)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_woodwork_shield() -> AudioStreamWAV:
	# Solid wooden thud with layered reinforcement — planks being nailed together
	# Multiple quick knocks building up, ending with a deep satisfying "thunk"
	var samples = _make_samples(0.50)
	# Three quick construction taps — rap-rap-rap
	var tap_times = [0.0, 0.07, 0.14]
	for tap_t in tap_times:
		var tap = _make_samples(0.06)
		_pitch_sweep_sine(tap, 280.0, 140.0, 0.35)
		_pitch_sweep_sine(tap, 560.0, 280.0, 0.15)
		_add_pitched_noise(tap, 1800.0, 1000.0, 0.15)
		_apply_envelope(tap, 0.002, 0.01, 0.05)
		_mix_into(samples, tap, int(tap_t * SAMPLE_RATE))
	# Final heavy thunk — the shield is complete, solid and weighty
	var thunk = _make_samples(0.20)
	_pitch_sweep_sine(thunk, 160.0, 70.0, 0.5)
	_pitch_sweep_sine(thunk, 320.0, 140.0, 0.25)
	_add_sine_segment(thunk, 220.0, 0.15, 0.01, 0.12)
	_add_pitched_noise(thunk, 1200.0, 700.0, 0.15)
	_apply_envelope(thunk, 0.003, 0.04, 0.16)
	_soft_clip(thunk, 1.5)
	_mix_into(samples, thunk, int(0.22 * SAMPLE_RATE))
	# Warm confirmation tone
	_add_sine_segment(samples, 349.0, 0.12, 0.35, 0.12)  # F4
	_add_sine_segment(samples, 440.0, 0.10, 0.38, 0.10)  # A4
	_apply_envelope(samples, 0.002, 0.15, 0.35)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_woodwork_totem() -> AudioStreamWAV:
	# Mystical nature chime — ethereal harmonics with earthy resonance
	# Spiritual, otherworldly — carved totem channeling power
	var samples = _make_samples(0.70)
	# Deep earth hum — the totem's grounding presence
	_add_sine_segment(samples, 110.0, 0.2, 0.0, 0.55)
	_add_sine_segment(samples, 165.0, 0.1, 0.0, 0.50)
	# Ethereal ascending chime arpeggio — pentatonic scale for mystical feel
	# D5, F#5, A5, D6 (D major pentatonic)
	_add_sine_segment(samples, 587.0, 0.25, 0.05, 0.30)
	_add_sine_segment(samples, 740.0, 0.25, 0.13, 0.28)
	_add_sine_segment(samples, 880.0, 0.28, 0.21, 0.26)
	_add_sine_segment(samples, 1175.0, 0.30, 0.29, 0.30)
	# Bell-like overtones on each note
	_add_sine_segment(samples, 1175.0, 0.06, 0.05, 0.25)
	_add_sine_segment(samples, 1480.0, 0.05, 0.13, 0.22)
	_add_sine_segment(samples, 1760.0, 0.04, 0.21, 0.20)
	_add_sine_segment(samples, 2350.0, 0.03, 0.29, 0.18)
	# Nature shimmer — soft high-pitched sparkle
	_add_pitched_noise(samples, 6000.0, 1500.0, 0.02, 0.15)
	_add_pitched_noise(samples, 8000.0, 1000.0, 0.015, 0.25)
	# Gentle wobble for organic feel
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.92 + 0.08 * sin(t * 6.0 * TAU)
	_apply_envelope(samples, 0.02, 0.25, 0.43)
	_normalize(samples, 0.7)
	return _to_stream(samples)

func _gen_woodwork_watchtower() -> AudioStreamWAV:
	# Ascending stone-and-wood stacking — building upward, gaining height
	# Each "layer" is a slightly higher pitched knock, ending with a bright lookout chime
	var samples = _make_samples(0.60)
	# Four ascending construction hits — each higher pitched = building taller
	var hit_data = [
		{"t": 0.0, "freq": 150.0, "vol": 0.3},
		{"t": 0.08, "freq": 200.0, "vol": 0.3},
		{"t": 0.16, "freq": 260.0, "vol": 0.35},
		{"t": 0.24, "freq": 330.0, "vol": 0.35},
	]
	for hd in hit_data:
		var hit = _make_samples(0.08)
		_pitch_sweep_sine(hit, hd["freq"] * 1.5, hd["freq"], hd["vol"])
		_add_pitched_noise(hit, 1500.0, 800.0, 0.12)
		_apply_envelope(hit, 0.002, 0.015, 0.063)
		_mix_into(samples, hit, int(float(hd["t"]) * SAMPLE_RATE))
	# Bright lookout chime at the top — "the watchtower is complete"
	# High, clear, and far-reaching like a bell at the top of a tower
	_add_sine_segment(samples, 1047.0, 0.3, 0.34, 0.22)  # C6
	_add_sine_segment(samples, 1319.0, 0.2, 0.37, 0.18)  # E6
	_add_sine_segment(samples, 2094.0, 0.08, 0.34, 0.15)  # C7 overtone
	# Shimmering decay — the view from the top
	_add_pitched_noise(samples, 5000.0, 1500.0, 0.025, 0.34)
	# Warm foundation
	_add_sine_segment(samples, 261.6, 0.12, 0.0, 0.40)
	_apply_envelope(samples, 0.002, 0.18, 0.40)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_shop_buy() -> AudioStreamWAV:
	# Satisfying coin exchange — coins clinking on counter with register confirmation
	# Multiple quick metallic clinks followed by a warm "cha-ching" tone
	var samples = _make_samples(0.40)
	# Coin clinks — three quick high metallic tinks at slightly different pitches
	var clink_freqs = [3200.0, 3600.0, 4100.0]
	var clink_times = [0.0, 0.04, 0.09]
	for j in range(3):
		var clink = _make_samples(0.05)
		_add_sine(clink, clink_freqs[j], 0.2)
		_add_sine(clink, clink_freqs[j] * 0.5, 0.1)
		_add_pitched_noise(clink, clink_freqs[j], 800.0, 0.08)
		_apply_envelope(clink, 0.001, 0.008, 0.04)
		_mix_into(samples, clink, int(clink_times[j] * SAMPLE_RATE))
	# Register confirmation — warm descending "cha-ching" two-note
	_add_sine_segment(samples, 784.0, 0.3, 0.14, 0.10)   # G5
	_add_sine_segment(samples, 523.0, 0.35, 0.20, 0.16)   # C5
	_add_sine_segment(samples, 1046.0, 0.10, 0.20, 0.12)  # C6 overtone
	# Warmth underneath
	_add_sine_segment(samples, 261.6, 0.12, 0.14, 0.20)
	_apply_envelope(samples, 0.002, 0.12, 0.28)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_shop_sell() -> AudioStreamWAV:
	# Lighter coin toss — coins received, ascending pitch = profit gained
	# Brighter and airier than buy, with ascending confirmation
	var samples = _make_samples(0.35)
	# Light coin toss sound — single bright metallic clink
	var toss = _make_samples(0.04)
	_add_sine(toss, 3800.0, 0.15)
	_add_sine(toss, 1900.0, 0.08)
	_add_pitched_noise(toss, 4500.0, 1200.0, 0.06)
	_apply_envelope(toss, 0.001, 0.006, 0.033)
	_mix_into(samples, toss)
	# Ascending two-note "profit" chime — cheerful and quick
	_add_sine_segment(samples, 659.0, 0.28, 0.05, 0.12)   # E5
	_add_sine_segment(samples, 880.0, 0.32, 0.11, 0.16)   # A5
	_add_sine_segment(samples, 1760.0, 0.08, 0.11, 0.12)  # A6 shimmer
	# Sparkle on top
	_add_pitched_noise(samples, 5500.0, 1200.0, 0.02, 0.11)
	_apply_envelope(samples, 0.002, 0.10, 0.24)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_equip_weapon() -> AudioStreamWAV:
	# Sword drawn from sheath — sharp metallic slide ending in a bright ring
	var samples = _make_samples(0.35)
	# Sheath slide — ascending metallic friction
	_pitch_sweep_sine(samples, 1200.0, 2800.0, 0.12, 0.0)
	_add_pitched_noise(samples, 2500.0, 1800.0, 0.1, 0.0)
	# Blade ring at the end — weapon is ready
	_add_sine_segment(samples, 1400.0, 0.3, 0.12, 0.20)
	_add_sine_segment(samples, 2800.0, 0.12, 0.12, 0.15)
	_add_sine_segment(samples, 4200.0, 0.05, 0.12, 0.10)
	# Quick low thud of hand gripping the hilt
	_pitch_sweep_sine(samples, 200.0, 100.0, 0.15, 0.0)
	_apply_envelope(samples, 0.003, 0.10, 0.24)
	_soft_clip(samples, 1.4)
	return _to_stream(samples)

func _gen_equip_armor() -> AudioStreamWAV:
	# Heavy armor being fastened — layered metallic clasps with weighty settle
	var samples = _make_samples(0.40)
	# Clasp buckle sound — two quick clicks
	var click1 = _make_samples(0.03)
	_add_pitched_noise(click1, 2800.0, 1500.0, 0.25)
	_add_sine(click1, 1800.0, 0.15)
	_apply_envelope(click1, 0.001, 0.005, 0.024)
	_mix_into(samples, click1)
	var click2 = _make_samples(0.03)
	_add_pitched_noise(click2, 3200.0, 1500.0, 0.25)
	_add_sine(click2, 2000.0, 0.15)
	_apply_envelope(click2, 0.001, 0.005, 0.024)
	_mix_into(samples, click2, int(0.08 * SAMPLE_RATE))
	# Heavy armor settle — deep resonant clank
	_pitch_sweep_sine(samples, 300.0, 150.0, 0.3, 0.14)
	_add_sine_segment(samples, 600.0, 0.15, 0.14, 0.20)
	_add_sine_segment(samples, 900.0, 0.08, 0.14, 0.15)
	# Weight settling hum
	_add_sine_segment(samples, 180.0, 0.12, 0.16, 0.20)
	_apply_envelope(samples, 0.002, 0.14, 0.26)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_equip_helm() -> AudioStreamWAV:
	# Helmet placed on head — dull metallic tap with muffled resonance
	var samples = _make_samples(0.25)
	# Solid tap — helmet meeting head
	var tap = _make_samples(0.03)
	_add_pitched_noise(tap, 2000.0, 1200.0, 0.2)
	_add_sine(tap, 800.0, 0.2)
	_apply_envelope(tap, 0.001, 0.006, 0.023)
	_mix_into(samples, tap)
	# Hollow helmet resonance — lower and more rounded than armor
	_add_sine_segment(samples, 450.0, 0.25, 0.02, 0.18)
	_add_sine_segment(samples, 900.0, 0.08, 0.02, 0.12)
	# Visor click
	_add_sine_segment(samples, 1600.0, 0.1, 0.10, 0.05)
	_apply_envelope(samples, 0.002, 0.06, 0.19)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_equip_boots() -> AudioStreamWAV:
	# Boots laced and stomped — leather stretch followed by firm ground stomp
	var samples = _make_samples(0.30)
	# Leather creak/stretch
	_add_pitched_noise(samples, 800.0, 500.0, 0.1, 0.0)
	_pitch_sweep_sine(samples, 300.0, 450.0, 0.08, 0.0)
	# Stomp — firm thud with ground resonance
	var stomp = _make_samples(0.10)
	_pitch_sweep_sine(stomp, 140.0, 60.0, 0.45)
	_pitch_sweep_sine(stomp, 280.0, 120.0, 0.2)
	_add_pitched_noise(stomp, 1000.0, 600.0, 0.12)
	_apply_envelope(stomp, 0.002, 0.02, 0.08)
	_mix_into(samples, stomp, int(0.10 * SAMPLE_RATE))
	# Light step confidence tap
	var tap = _make_samples(0.05)
	_pitch_sweep_sine(tap, 180.0, 90.0, 0.2)
	_apply_envelope(tap, 0.002, 0.01, 0.04)
	_mix_into(samples, tap, int(0.20 * SAMPLE_RATE))
	_apply_envelope(samples, 0.003, 0.10, 0.19)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_equip_ring() -> AudioStreamWAV:
	# Ring slid onto finger — delicate crystalline chime with magical shimmer
	var samples = _make_samples(0.35)
	# Tiny metallic slide
	_pitch_sweep_sine(samples, 2000.0, 3000.0, 0.06, 0.0)
	# Crystal chime — pure and bell-like
	_add_sine_segment(samples, 2093.0, 0.3, 0.04, 0.25)   # C7
	_add_sine_segment(samples, 4186.0, 0.1, 0.04, 0.18)   # C8 overtone
	_add_sine_segment(samples, 2637.0, 0.12, 0.06, 0.20)  # E7
	# Magical pulse — ring activating
	_add_sine_segment(samples, 1047.0, 0.08, 0.08, 0.22)  # C6 warmth
	# Faint sparkle
	_add_pitched_noise(samples, 7000.0, 1500.0, 0.015, 0.05)
	_apply_envelope(samples, 0.005, 0.08, 0.26)
	_normalize(samples, 0.65)
	return _to_stream(samples)

func _gen_equip_amulet() -> AudioStreamWAV:
	# Amulet clasped around neck — chain links settling with warm mystical hum
	var samples = _make_samples(0.40)
	# Chain links — series of tiny clinks
	var link_times = [0.0, 0.03, 0.055, 0.08]
	for lt in link_times:
		var clink = _make_samples(0.025)
		_add_sine(clink, 3400.0 + randf() * 400.0, 0.12)
		_add_pitched_noise(clink, 4000.0, 1200.0, 0.05)
		_apply_envelope(clink, 0.001, 0.004, 0.02)
		_mix_into(samples, clink, int(lt * SAMPLE_RATE))
	# Clasp snap
	var snap = _make_samples(0.02)
	_add_pitched_noise(snap, 2800.0, 1500.0, 0.2)
	_apply_envelope(snap, 0.001, 0.004, 0.015)
	_mix_into(samples, snap, int(0.10 * SAMPLE_RATE))
	# Mystical hum — amulet's magic activating against the chest
	_add_sine_segment(samples, 220.0, 0.15, 0.12, 0.25)
	_add_sine_segment(samples, 330.0, 0.10, 0.14, 0.22)
	_add_sine_segment(samples, 440.0, 0.06, 0.16, 0.18)
	# Gentle wobble for magical feel
	for i in range(int(0.12 * SAMPLE_RATE), samples.size()):
		var t = float(i) / SAMPLE_RATE
		samples[i] *= 0.9 + 0.1 * sin(t * 7.0 * TAU)
	_apply_envelope(samples, 0.002, 0.14, 0.26)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_potion_heal() -> AudioStreamWAV:
	# Cork pop followed by warm liquid gulp and soothing heal chime
	# Unique bubbly, restorative feeling — distinct from any other SFX
	var samples = _make_samples(0.50)
	# Cork pop — quick bright burst
	var pop = _make_samples(0.025)
	_pitch_sweep_sine(pop, 800.0, 400.0, 0.3)
	_add_pitched_noise(pop, 3000.0, 2000.0, 0.2)
	_apply_envelope(pop, 0.001, 0.004, 0.02)
	_mix_into(samples, pop)
	# Liquid glug — bubbly warble
	for i in range(int(0.03 * SAMPLE_RATE), int(0.18 * SAMPLE_RATE)):
		var t = float(i) / SAMPLE_RATE
		# Bubbling — irregular pitch wobbles
		var bubble = sin(t * 280.0 * TAU) * 0.12
		bubble += sin(t * 350.0 * TAU + sin(t * 12.0 * TAU) * 3.0) * 0.08
		samples[i] += bubble
	# Healing chime — warm ascending major third (C5 -> E5)
	_add_sine_segment(samples, 523.0, 0.25, 0.18, 0.15)   # C5
	_add_sine_segment(samples, 659.0, 0.30, 0.24, 0.20)   # E5
	_add_sine_segment(samples, 1046.0, 0.08, 0.18, 0.12)  # C6 shimmer
	_add_sine_segment(samples, 1318.0, 0.06, 0.24, 0.15)  # E6 shimmer
	# Warm restorative glow — soft bass pad
	_add_sine_segment(samples, 261.6, 0.10, 0.18, 0.28)
	# Sparkle of health restored
	_add_pitched_noise(samples, 5000.0, 1200.0, 0.02, 0.24)
	_apply_envelope(samples, 0.002, 0.16, 0.32)
	_soft_clip(samples, 1.3)
	return _to_stream(samples)

func _gen_potion_mana() -> AudioStreamWAV:
	# Cork pop with cool crystalline cascade — magical energy rushing in
	# Distinctly different from heal: cooler, more "electric" and shimmery
	var samples = _make_samples(0.50)
	# Cork pop — slightly higher pitched than heal potion
	var pop = _make_samples(0.025)
	_pitch_sweep_sine(pop, 900.0, 500.0, 0.25)
	_add_pitched_noise(pop, 3500.0, 2000.0, 0.18)
	_apply_envelope(pop, 0.001, 0.004, 0.02)
	_mix_into(samples, pop)
	# Crystalline cascade — descending sparkle like magic flowing
	_add_sine_segment(samples, 1568.0, 0.15, 0.03, 0.12)  # G6
	_add_sine_segment(samples, 1318.0, 0.18, 0.07, 0.12)  # E6
	_add_sine_segment(samples, 1046.0, 0.20, 0.11, 0.14)  # C6
	_add_sine_segment(samples, 784.0, 0.22, 0.15, 0.16)   # G5
	# Each note has a high harmonic shimmer
	_add_sine_segment(samples, 3136.0, 0.04, 0.03, 0.08)
	_add_sine_segment(samples, 2637.0, 0.04, 0.07, 0.08)
	_add_sine_segment(samples, 2093.0, 0.05, 0.11, 0.10)
	# Cool magical hum underneath
	_add_sine_segment(samples, 196.0, 0.12, 0.05, 0.35)   # G3
	_add_sine_segment(samples, 294.0, 0.06, 0.05, 0.30)   # D4
	# Arcane sparkle
	_add_pitched_noise(samples, 6000.0, 1500.0, 0.025, 0.05)
	_add_pitched_noise(samples, 8000.0, 1000.0, 0.015, 0.12)
	_apply_envelope(samples, 0.002, 0.15, 0.33)
	_soft_clip(samples, 1.2)
	return _to_stream(samples)

func _gen_potion_buff() -> AudioStreamWAV:
	# Elixir power surge — cork pop then rising power chord with energy crackle
	# Feels empowering and intense — you just drank raw power
	var samples = _make_samples(0.45)
	# Quick cork pop
	var pop = _make_samples(0.02)
	_pitch_sweep_sine(pop, 700.0, 350.0, 0.25)
	_add_pitched_noise(pop, 2800.0, 1800.0, 0.15)
	_apply_envelope(pop, 0.001, 0.003, 0.016)
	_mix_into(samples, pop)
	# Rising power chord — ascending with growing intensity
	_pitch_sweep_sine(samples, 220.0, 440.0, 0.25, 0.03)
	_pitch_sweep_sine(samples, 330.0, 660.0, 0.15, 0.05)
	_pitch_sweep_sine(samples, 440.0, 880.0, 0.08, 0.07)
	# Energy crackle — high frequency bursts
	_add_pitched_noise(samples, 3000.0, 2000.0, 0.06, 0.10)
	_add_pitched_noise(samples, 4500.0, 1500.0, 0.04, 0.15)
	# Power confirmation tone — strong fifth interval (C5 + G5)
	_add_sine_segment(samples, 523.0, 0.3, 0.25, 0.16)
	_add_sine_segment(samples, 784.0, 0.25, 0.27, 0.14)
	_add_sine_segment(samples, 1046.0, 0.10, 0.25, 0.12)
	_apply_envelope(samples, 0.002, 0.14, 0.29)
	_soft_clip(samples, 1.5)
	return _to_stream(samples)

# ============================================================
# MUSIC GENERATION — 5 completely different tracks, rotated every minute
# ============================================================

func _generate_all_music() -> void:
	_music_cache["war_drums"] = _gen_war_drums()
	_music_cache["crystal_caves"] = _gen_crystal_caves()
	_music_cache["pirate_jig"] = _gen_pirate_jig()
	_music_cache["dark_cathedral"] = _gen_dark_cathedral()
	_music_cache["desert_caravan"] = _gen_desert_caravan()
	_music_cache["boss_encounter"] = _gen_boss_encounter()
	_music_cache["boss_idle"] = _gen_boss_idle()
	_music_cache["boss_victory"] = _gen_boss_victory()
	_music_cache["wave_warning"] = _gen_wave_warning()

# ---- Track 1: WAR DRUMS — Aggressive tribal percussion, deep bass, chanting ----
func _gen_war_drums() -> AudioStreamWAV:
	var dur = 60.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3317

	# Heavy kick drum pattern — driving 4/4 with syncopation
	var kick_pattern = [0.0, 0.5, 0.75, 1.0, 1.5, 2.0, 2.25, 2.5, 3.0, 3.5]
	var bar_len = 4.0  # 4 seconds per bar
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bar_t = fmod(t, bar_len)
		# Kick drums
		for kick_t in kick_pattern:
			var dt = bar_t - kick_t
			if dt >= 0.0 and dt < 0.15:
				var env = exp(-dt * 25.0) * 0.35
				samples[i] += sin(t * 55.0 * TAU * (1.0 - dt * 3.0)) * env
				samples[i] += sin(t * 110.0 * TAU) * env * 0.15
		# Snare hits on beats 1.0 and 3.0
		for snare_t in [1.0, 3.0]:
			var sdt = bar_t - snare_t
			if sdt >= 0.0 and sdt < 0.1:
				var senv = exp(-sdt * 30.0) * 0.20
				samples[i] += sin(t * 180.0 * TAU) * senv * 0.5
		# Tom fills every other bar
		if fmod(t, bar_len * 2.0) > bar_len:
			for tom_off in [3.25, 3.5, 3.625, 3.75, 3.875]:
				var tdt = bar_t - tom_off
				if tdt >= 0.0 and tdt < 0.12:
					var tom_freq = lerpf(200.0, 80.0, (tom_off - 3.25) / 0.625)
					var tenv = exp(-tdt * 20.0) * 0.18
					samples[i] += sin(t * tom_freq * TAU) * tenv

	# Snare noise layer
	var sn_rng = RandomNumberGenerator.new()
	sn_rng.seed = 4401
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bar_t = fmod(t, bar_len)
		for snare_t in [1.0, 3.0]:
			var sdt = bar_t - snare_t
			if sdt >= 0.0 and sdt < 0.08:
				var senv = exp(-sdt * 35.0) * 0.15
				samples[i] += sn_rng.randf_range(-1.0, 1.0) * senv

	# Deep war bass — menacing low drone that shifts
	var bass_notes = [55.0, 55.0, 41.2, 49.0, 55.0, 61.7, 49.0, 55.0]
	var bass_dur = dur / bass_notes.size()
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bi = int(t / bass_dur) % bass_notes.size()
		var bf = bass_notes[bi]
		var note_t = fmod(t, bass_dur)
		var benv = 0.12 * (0.7 + 0.3 * exp(-note_t * 0.5))
		samples[i] += sin(t * bf * TAU) * benv
		samples[i] += sin(t * bf * 2.0 * TAU) * benv * 0.3
		samples[i] += sin(t * bf * 3.0 * TAU) * benv * 0.08

	# Tribal chant — parallel fifths droning
	var chant_freqs = [220.0, 330.0]  # A3 + E4 (perfect fifth)
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var chant_pulse = 0.5 + 0.5 * sin(t * 2.5 * TAU)
		var section = int(t / 15.0) % 4
		var chant_vol = [0.0, 0.04, 0.06, 0.03][section]
		for cf in chant_freqs:
			var vib = 1.0 + 0.004 * sin(t * 5.5 * TAU)
			samples[i] += sin(t * cf * vib * TAU) * chant_vol * chant_pulse
			samples[i] += sin(t * cf * vib * 2.0 * TAU) * chant_vol * chant_pulse * 0.2

	# War horn blasts at section transitions
	for sec_start in [0.0, 15.0, 30.0, 45.0]:
		var horn_start = int(sec_start * SAMPLE_RATE)
		var horn_dur = int(3.0 * SAMPLE_RATE)
		for i in range(horn_dur):
			var di = horn_start + i
			if di >= samples.size():
				break
			var t = float(di) / SAMPLE_RATE
			var ht = float(i) / SAMPLE_RATE
			var henv = sin(clampf(ht / 3.0, 0.0, 1.0) * PI) * 0.07
			var hf = 146.83  # D3
			samples[di] += sin(t * hf * TAU) * henv
			samples[di] += sin(t * hf * 2.0 * TAU) * henv * 0.4
			samples[di] += sin(t * hf * 3.0 * TAU) * henv * 0.15

	_soft_clip(samples, 2.0)
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- Track 2: CRYSTAL CAVES — Ethereal bells, shimmering arpeggios, reverb-like delays ----
func _gen_crystal_caves() -> AudioStreamWAV:
	var dur = 60.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 8832

	# Crystalline arpeggio patterns — whole tone scale for otherworldly feel
	var wt_scale = [261.6, 293.7, 329.6, 370.0, 415.3, 466.2, 523.3, 587.3, 659.3, 740.0]
	var arp_speed = 0.3  # seconds per note
	var arp_t = 0.0
	while arp_t < dur:
		var note_idx = rng.randi() % wt_scale.size()
		var freq = wt_scale[note_idx]
		var ndur = rng.randf_range(0.8, 2.0)
		var bell = _make_samples(ndur)
		for i in range(bell.size()):
			var t = float(i) / SAMPLE_RATE
			# Bell-like: fundamental + inharmonic partials
			bell[i] = sin(t * freq * TAU) * 0.04 * exp(-t * 2.5)
			bell[i] += sin(t * freq * 2.76 * TAU) * 0.02 * exp(-t * 4.0)
			bell[i] += sin(t * freq * 5.4 * TAU) * 0.008 * exp(-t * 6.0)
			bell[i] += sin(t * freq * 8.93 * TAU) * 0.003 * exp(-t * 8.0)
		_mix_into(samples, bell, int(arp_t * SAMPLE_RATE))
		# Echo/delay effect — repeat quieter
		if arp_t + 0.4 < dur:
			for qi in range(bell.size()):
				bell[qi] *= 0.35
			_mix_into(samples, bell, int((arp_t + 0.4) * SAMPLE_RATE))
		if arp_t + 0.8 < dur:
			for qi in range(bell.size()):
				bell[qi] *= 0.4
			_mix_into(samples, bell, int((arp_t + 0.8) * SAMPLE_RATE))
		arp_t += rng.randf_range(0.2, 0.6)

	# Deep cave drone — very low, slow-moving
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var drone_f = 65.0 + 5.0 * sin(t * 0.1 * TAU)
		var drone_vol = 0.06 + 0.02 * sin(t * 0.07 * TAU)
		samples[i] += sin(t * drone_f * TAU) * drone_vol
		samples[i] += sin(t * drone_f * 1.5 * TAU) * drone_vol * 0.3

	# Shimmering pad — high-frequency washing
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var shimmer_vol = 0.015 * (0.5 + 0.5 * sin(t * 0.15 * TAU))
		# Cluster of close frequencies for chorus effect
		samples[i] += sin(t * 880.0 * TAU) * shimmer_vol
		samples[i] += sin(t * 882.5 * TAU) * shimmer_vol * 0.8
		samples[i] += sin(t * 877.5 * TAU) * shimmer_vol * 0.8
		samples[i] += sin(t * 1320.0 * TAU) * shimmer_vol * 0.4
		samples[i] += sin(t * 1322.0 * TAU) * shimmer_vol * 0.3

	# Water drops — random plinks
	var drop_t = 2.0
	while drop_t < dur - 1.0:
		var dfreq = rng.randf_range(1200.0, 3000.0)
		var ddur = rng.randf_range(0.15, 0.4)
		var drop = _make_samples(ddur)
		for i in range(drop.size()):
			var t = float(i) / SAMPLE_RATE
			drop[i] = sin(t * dfreq * TAU) * 0.02 * exp(-t * 10.0)
			drop[i] += sin(t * dfreq * 0.5 * TAU) * 0.01 * exp(-t * 8.0)
		_mix_into(samples, drop, int(drop_t * SAMPLE_RATE))
		drop_t += rng.randf_range(1.5, 5.0)

	_soft_clip(samples, 1.3)
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- Track 3: PIRATE JIG — Upbeat 6/8 bouncy dance, fiddle-like melody ----
func _gen_pirate_jig() -> AudioStreamWAV:
	var dur = 60.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5577

	# D major scale for bright sea-faring feel
	# D4=293.66, E4=329.63, Fs4=370.0, G4=392.0, A4=440.0, B4=493.88, Cs5=554.37, D5=587.33
	var beat = 0.25  # Eighth note = 0.25s (fast jig tempo)
	var bar = beat * 6.0  # 6/8 time

	# Bouncy bass — root-fifth pattern in 6/8
	var bass_prog_notes = [
		[146.83, 220.0],  # D3, A3
		[146.83, 220.0],
		[196.0, 293.66],  # G3, D4
		[164.81, 246.94],  # E3, B3
		[174.61, 261.63],  # F3, C4
		[130.81, 196.0],  # C3, G3
		[146.83, 220.0],
		[146.83, 220.0],
	]
	var bass_bar_dur = bar
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bar_idx = int(t / bass_bar_dur) % bass_prog_notes.size()
		var root = bass_prog_notes[bar_idx][0]
		var fifth = bass_prog_notes[bar_idx][1]
		var bar_t = fmod(t, bass_bar_dur)
		# Beat pattern: root on 1, fifth on 4
		var beat_in_bar = int(bar_t / beat) % 6
		var cur_bass = root if beat_in_bar < 3 else fifth
		var note_in_beat = fmod(bar_t, beat)
		var benv = 0.10 * exp(-note_in_beat * 6.0)
		samples[i] += sin(t * cur_bass * TAU) * benv
		samples[i] += sin(t * cur_bass * 2.0 * TAU) * benv * 0.2

	# "Accordion" chords — bright sustained chords with tremolo
	var chord_prog = [
		[293.66, 370.0, 440.0],   # D major
		[293.66, 370.0, 440.0],
		[392.0, 493.88, 587.33],  # G major
		[329.63, 415.30, 493.88], # E minor
		[349.23, 440.0, 523.25],  # F major
		[261.63, 329.63, 392.0],  # C major
		[293.66, 370.0, 440.0],
		[293.66, 370.0, 440.0],
	]
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var ci = int(t / bar) % chord_prog.size()
		var chord = chord_prog[ci]
		# Tremolo for accordion effect
		var trem = 0.6 + 0.4 * sin(t * 12.0 * TAU)
		var cvol = 0.025 * trem
		for cf in chord:
			samples[i] += sin(t * cf * TAU) * cvol
			samples[i] += sin(t * cf * 1.002 * TAU) * cvol * 0.5  # Detuned for richness

	# Fiddle melody — fast ornamental tune
	var melody = [
		# Bar 1-2: Opening phrase
		[293.66, 1], [329.63, 1], [370.0, 1], [440.0, 2], [370.0, 1],
		[440.0, 1], [493.88, 1], [440.0, 1], [370.0, 1], [329.63, 1], [293.66, 1],
		# Bar 3-4
		[392.0, 2], [440.0, 1], [493.88, 1], [587.33, 2],
		[493.88, 1], [440.0, 1], [392.0, 1], [370.0, 1], [329.63, 1], [293.66, 1],
		# Bar 5-6: Contrasting phrase
		[349.23, 1], [440.0, 1], [523.25, 2], [440.0, 1], [349.23, 1],
		[329.63, 1], [392.0, 1], [440.0, 1], [493.88, 2], [440.0, 1],
		# Bar 7-8: Return
		[587.33, 1], [493.88, 1], [440.0, 1], [370.0, 1], [329.63, 1], [293.66, 1],
		[293.66, 2], [329.63, 1], [293.66, 3],
	]
	# Repeat melody to fill 60 seconds
	var mel_t = 0.0
	var mel_idx = 0
	while mel_t < dur - 1.0:
		var note = melody[mel_idx % melody.size()]
		var freq = note[0]
		var ndur_beats = note[1]
		var ndur = ndur_beats * beat
		var ns = _make_samples(ndur * 1.3)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			var nf = t / ndur
			# Fiddle: bright sawtooth-ish with vibrato
			var vib = 1.0 + 0.006 * sin(t * 6.0 * TAU) * clampf(t - 0.05, 0.0, 1.0)
			var f = freq * vib
			ns[i] = sin(t * f * TAU) * 0.04
			ns[i] += sin(t * f * 2.0 * TAU) * 0.025
			ns[i] += sin(t * f * 3.0 * TAU) * 0.015
			ns[i] += sin(t * f * 4.0 * TAU) * 0.008
			# Envelope
			var env = min(t * 30.0, 1.0) * maxf(0.0, 1.0 - nf * 0.3)
			ns[i] *= env
		_mix_into(samples, ns, int(mel_t * SAMPLE_RATE))
		mel_t += ndur
		mel_idx += 1

	# Percussion — jig rhythm: boom-chick-chick pattern
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bar_t = fmod(t, bar)
		var beat_pos = int(bar_t / beat) % 6
		var bt = fmod(bar_t, beat)
		if beat_pos == 0 and bt < 0.06:
			# Kick on beat 1
			var env = exp(-bt * 30.0) * 0.12
			samples[i] += sin(t * 80.0 * TAU) * env
		elif (beat_pos == 1 or beat_pos == 2 or beat_pos == 4 or beat_pos == 5) and bt < 0.04:
			# Hi-hat on off-beats
			var env = exp(-bt * 50.0) * 0.04
			samples[i] += rng.randf_range(-1.0, 1.0) * env
		elif beat_pos == 3 and bt < 0.05:
			# Accent on beat 4
			var env = exp(-bt * 35.0) * 0.10
			samples[i] += sin(t * 120.0 * TAU) * env

	_soft_clip(samples, 1.8)
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- Track 4: DARK CATHEDRAL — Deep organ drones, gothic choirs, ominous minor ----
func _gen_dark_cathedral() -> AudioStreamWAV:
	var dur = 60.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 6613

	# Organ drone — rich harmonic series like a pipe organ
	var organ_prog = [
		[65.41, 98.0],    # C2 + G2
		[61.74, 92.50],   # B1 + Fs2
		[55.0, 82.41],    # A1 + E2
		[58.27, 87.31],   # Bb1 + F2
	]
	var organ_dur = dur / organ_prog.size()
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var oi = int(t / organ_dur) % organ_prog.size()
		var note_t = fmod(t, organ_dur)
		# Crossfade between organ notes
		var xf = clampf(note_t / 2.0, 0.0, 1.0) * clampf((organ_dur - note_t) / 2.0, 0.0, 1.0)
		for bf in organ_prog[oi]:
			# Organ: many harmonics, slight detuning
			var ovol = 0.06 * xf
			for h in range(1, 9):
				var hf = float(h)
				var hvol = ovol / (hf * 0.7)
				samples[i] += sin(t * bf * hf * TAU) * hvol
				# Slight detuning for warmth
				samples[i] += sin(t * bf * hf * 1.001 * TAU) * hvol * 0.3

	# Gothic choir — sustained vowel-like tones (formant synthesis)
	var choir_notes = [
		# Phrase 1: descending minor
		[261.63, 8.0], [246.94, 6.0], [220.0, 8.0], [196.0, 6.0],
		# Phrase 2: chromatic tension
		[207.65, 6.0], [220.0, 4.0], [233.08, 8.0], [220.0, 6.0],
	]
	var choir_t = 2.0
	for cn in choir_notes:
		if choir_t >= dur:
			break
		var freq = cn[0]
		var ndur = cn[1]
		var ns = _make_samples(ndur + 2.0)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			var nf = t / ndur
			# "Ah" vowel formants: ~730Hz, ~1090Hz, ~2440Hz
			var vib = 1.0 + 0.003 * sin(t * 5.0 * TAU) * clampf(t - 0.3, 0.0, 1.0)
			var f = freq * vib
			# Build harmonics and weight by formant proximity
			var val = 0.0
			for h in range(1, 16):
				var hfreq = f * float(h)
				# Formant weighting
				var fw = 0.0
				fw += exp(-pow((hfreq - 730.0) / 120.0, 2.0)) * 1.0
				fw += exp(-pow((hfreq - 1090.0) / 150.0, 2.0)) * 0.7
				fw += exp(-pow((hfreq - 2440.0) / 200.0, 2.0)) * 0.3
				fw = maxf(fw, 0.05)
				val += sin(t * hfreq * TAU) * fw / float(h)
			var env = sin(clampf(nf, 0.0, 1.0) * PI) * 0.035
			ns[i] = val * env
		_mix_into(samples, ns, int(choir_t * SAMPLE_RATE))
		choir_t += ndur - 1.0  # Overlap notes slightly

	# Tolling bell — deep, resonant, every 8 seconds
	var bell_t = 4.0
	while bell_t < dur - 3.0:
		var bell_f = 130.81  # C3
		var bdur = 4.0
		var bell = _make_samples(bdur)
		for i in range(bell.size()):
			var t = float(i) / SAMPLE_RATE
			bell[i] = sin(t * bell_f * TAU) * 0.05 * exp(-t * 0.8)
			bell[i] += sin(t * bell_f * 2.0 * TAU) * 0.03 * exp(-t * 1.2)
			bell[i] += sin(t * bell_f * 3.76 * TAU) * 0.015 * exp(-t * 2.0)
			bell[i] += sin(t * bell_f * 6.28 * TAU) * 0.005 * exp(-t * 3.0)
		_mix_into(samples, bell, int(bell_t * SAMPLE_RATE))
		bell_t += rng.randf_range(7.0, 10.0)

	# Whispering wind layer
	var w_rng = RandomNumberGenerator.new()
	w_rng.seed = 2244
	var wpv = 0.0
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var raw = w_rng.randf_range(-1.0, 1.0)
		wpv = wpv * 0.95 + raw * 0.05
		var wvol = (0.5 + 0.5 * sin(t * 0.08 * TAU)) * 0.012
		samples[i] += wpv * wvol

	_soft_clip(samples, 1.4)
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- Track 5: DESERT CARAVAN — Exotic scales, snake-charmer melody, hand drums ----
func _gen_desert_caravan() -> AudioStreamWAV:
	var dur = 60.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9944

	# Phrygian dominant scale (Arabic/flamenco feel)
	# E4, F4, Ab4, A4, B4, C5, D5, E5
	var scale = [329.63, 349.23, 415.30, 440.0, 493.88, 523.25, 587.33, 659.25]
	var scale_low = [164.81, 174.61, 207.65, 220.0, 246.94, 261.63, 293.66, 329.63]

	# Sitar-like drone on root + fifth
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		# Buzzy sitar drone: root E3 with sympathetic strings
		var drone_e = 0.0
		var df = 164.81
		for h in range(1, 12):
			var hf = df * float(h)
			var hv = 0.025 / float(h) * (1.0 + 0.3 * sin(t * 0.2 * TAU))
			drone_e += sin(t * hf * TAU) * hv
		# Add buzz (modulated noise)
		drone_e += sin(t * df * TAU + sin(t * df * 13.0 * TAU) * 0.3) * 0.015
		var drone_vol = 0.5 + 0.3 * sin(t * 0.12 * TAU)
		samples[i] += drone_e * drone_vol

	# Snake charmer melody — ornamental, microtonal slides
	var melody_phrases = [
		# Phrase 1: ascending
		[0, 2], [1, 1], [2, 2], [3, 1], [4, 3], [3, 1], [2, 2],
		# Phrase 2: descending with ornament
		[7, 2], [6, 1], [5, 1], [4, 2], [3, 1], [2, 2], [1, 1], [0, 3],
		# Phrase 3: dancing
		[2, 1], [4, 1], [2, 1], [4, 1], [5, 2], [4, 1], [3, 1], [2, 2], [0, 2],
		# Phrase 4: climax
		[4, 1], [5, 1], [6, 1], [7, 2], [6, 1], [5, 1], [4, 1],
		[3, 1], [2, 1], [1, 1], [0, 3],
	]
	var note_dur = 0.35  # Base note duration
	var mel_t = 1.0
	var phrase_idx = 0
	while mel_t < dur - 2.0:
		var phrase = melody_phrases[phrase_idx % melody_phrases.size()]
		var freq = scale[phrase[0]]
		var ndur = phrase[1] * note_dur
		var ns = _make_samples(ndur * 1.5)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			# Oboe-like nasal timbre for snake charmer
			var vib = 1.0 + 0.008 * sin(t * 6.0 * TAU) * clampf(t - 0.08, 0.0, 1.0)
			var f = freq * vib
			ns[i] = sin(t * f * TAU) * 0.045
			ns[i] += sin(t * f * 2.0 * TAU) * 0.030
			ns[i] += sin(t * f * 3.0 * TAU) * 0.025
			ns[i] += sin(t * f * 4.0 * TAU) * 0.015
			ns[i] += sin(t * f * 5.0 * TAU) * 0.008
			var nf = t / ndur
			var env = min(t * 20.0, 1.0) * maxf(0.0, 1.0 - nf * 0.4)
			ns[i] *= env
		_mix_into(samples, ns, int(mel_t * SAMPLE_RATE))
		mel_t += ndur
		phrase_idx += 1
		# Brief pause between phrases occasionally
		if phrase_idx % melody_phrases.size() == 0:
			mel_t += note_dur * 2.0

	# Hand drum pattern — doumbek/tabla style
	var beat = 0.5
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var cycle = fmod(t, beat * 8.0)
		var beat_num = int(cycle / beat) % 8
		var bt = fmod(cycle, beat)
		# Doum (deep) on beats 0, 3, 6
		if (beat_num == 0 or beat_num == 3 or beat_num == 6) and bt < 0.1:
			var env = exp(-bt * 20.0) * 0.12
			samples[i] += sin(t * 80.0 * TAU) * env
			samples[i] += sin(t * 160.0 * TAU) * env * 0.3
		# Tek (high) on beats 1, 2, 4, 5, 7
		elif bt < 0.05:
			var env = exp(-bt * 40.0) * 0.06
			samples[i] += sin(t * 300.0 * TAU) * env
			samples[i] += rng.randf_range(-1.0, 1.0) * env * 0.3

	# Finger cymbals — zill accents
	var zill_t = 3.0
	while zill_t < dur - 1.0:
		var zdur = 0.5
		var zill = _make_samples(zdur)
		for i in range(zill.size()):
			var t = float(i) / SAMPLE_RATE
			zill[i] = sin(t * 4200.0 * TAU) * 0.008 * exp(-t * 8.0)
			zill[i] += sin(t * 5800.0 * TAU) * 0.004 * exp(-t * 10.0)
		_mix_into(samples, zill, int(zill_t * SAMPLE_RATE))
		zill_t += rng.randf_range(2.0, 5.0)

	_soft_clip(samples, 1.6)
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- BOSS ENCOUNTER — Intense, driving, menacing combat music ----
func _gen_boss_encounter() -> AudioStreamWAV:
	var dur = 30.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7777

	# Aggressive double-time kick/snare — frantic combat pulse
	var beat = 0.25  # Fast tempo
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var bar_t = fmod(t, beat * 8.0)
		var beat_num = int(bar_t / beat) % 8
		var bt = fmod(bar_t, beat)
		# Heavy kick on 0, 2, 4, 6
		if beat_num % 2 == 0 and bt < 0.08:
			var env = exp(-bt * 25.0) * 0.3
			samples[i] += sin(t * 50.0 * TAU * (1.0 - bt * 2.5)) * env
			samples[i] += sin(t * 100.0 * TAU) * env * 0.2
		# Snare on 1, 3, 5, 7
		elif bt < 0.06:
			var env = exp(-bt * 35.0) * 0.15
			samples[i] += sin(t * 200.0 * TAU) * env * 0.5
			samples[i] += rng.randf_range(-1.0, 1.0) * env * 0.6

	# Menacing bass riff — chromatic descending in minor
	# E2=82.4, Eb2=77.8, D2=73.4, Db2=69.3, C2=65.4, B1=61.7
	var bass_riff = [82.41, 82.41, 77.78, 73.42, 69.30, 65.41, 61.74, 65.41]
	var riff_note_dur = beat * 2.0  # Each bass note = 2 beats
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var riff_cycle = fmod(t, riff_note_dur * bass_riff.size())
		var ri = int(riff_cycle / riff_note_dur) % bass_riff.size()
		var bf = bass_riff[ri]
		var note_t = fmod(riff_cycle, riff_note_dur)
		var benv = 0.18 * exp(-note_t * 1.5)
		# Distorted bass — heavy harmonics
		samples[i] += sin(t * bf * TAU) * benv
		samples[i] += sin(t * bf * 2.0 * TAU) * benv * 0.5
		samples[i] += sin(t * bf * 3.0 * TAU) * benv * 0.25
		samples[i] += sin(t * bf * 4.0 * TAU) * benv * 0.12

	# Dissonant power chord stabs — diminished chord hits
	var stab_times = [0.0, 2.0, 4.0, 4.5, 6.0, 8.0, 10.0, 10.5, 12.0, 14.0]
	var stab_cycle = 16.0
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var ct = fmod(t, stab_cycle)
		for st in stab_times:
			var dt = ct - st
			if dt >= 0.0 and dt < 0.4:
				var env = exp(-dt * 5.0) * 0.08
				# Diminished chord: E, G, Bb — dissonant and menacing
				samples[i] += sin(t * 164.81 * TAU) * env
				samples[i] += sin(t * 196.0 * TAU) * env * 0.8
				samples[i] += sin(t * 233.08 * TAU) * env * 0.7
				samples[i] += sin(t * 329.63 * TAU) * env * 0.4

	# Ominous string tremolo — high tension
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var trem = 0.5 + 0.5 * sin(t * 14.0 * TAU)
		var section = int(t / 7.5) % 4
		var str_vol = [0.03, 0.04, 0.05, 0.06][section] * trem
		# High minor second cluster — maximum tension
		samples[i] += sin(t * 622.25 * TAU) * str_vol
		samples[i] += sin(t * 659.25 * TAU) * str_vol * 0.8

	_soft_clip(samples, 2.2)
	var fade_len = int(1.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- BOSS IDLE — Low menacing drone, ambient danger when boss is nearby but not aggroed ----
func _gen_boss_idle() -> AudioStreamWAV:
	var dur = 20.0
	var samples = _make_samples(dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 6666

	# Deep rumbling drone
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var drone_f = 45.0 + 3.0 * sin(t * 0.15 * TAU)
		var drone_vol = 0.08 + 0.03 * sin(t * 0.1 * TAU)
		samples[i] += sin(t * drone_f * TAU) * drone_vol
		samples[i] += sin(t * drone_f * 1.5 * TAU) * drone_vol * 0.4
		samples[i] += sin(t * drone_f * 2.0 * TAU) * drone_vol * 0.15

	# Heartbeat-like pulse
	var hb_period = 1.2
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var hbt = fmod(t, hb_period)
		# Double thump like a heartbeat
		if hbt < 0.1:
			var env = exp(-hbt * 20.0) * 0.12
			samples[i] += sin(t * 40.0 * TAU) * env
		elif hbt > 0.2 and hbt < 0.3:
			var env = exp(-(hbt - 0.2) * 25.0) * 0.08
			samples[i] += sin(t * 35.0 * TAU) * env

	# Creepy whisper layer
	var w_rng = RandomNumberGenerator.new()
	w_rng.seed = 3333
	var wpv = 0.0
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var raw = w_rng.randf_range(-1.0, 1.0)
		wpv = wpv * 0.97 + raw * 0.03
		var wvol = (0.5 + 0.5 * sin(t * 0.06 * TAU)) * 0.02
		samples[i] += wpv * wvol

	_soft_clip(samples, 1.3)
	var fade_len = int(1.5 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac
	return _to_stream(samples, true)

# ---- BOSS VICTORY — Short triumphant fanfare after defeating a boss ----
func _gen_boss_victory() -> AudioStreamWAV:
	var dur = 6.0
	var samples = _make_samples(dur)

	# Triumphant brass fanfare: C major -> G major -> C major (up octave)
	# C4=261.6, E4=329.6, G4=392.0, C5=523.3
	var fanfare = [
		[261.63, 0.0, 0.5],  # C4
		[329.63, 0.4, 0.5],  # E4
		[392.0, 0.8, 0.6],   # G4
		[523.25, 1.3, 1.2],  # C5 (held longer)
		[659.25, 2.3, 0.6],  # E5
		[784.0, 2.8, 1.5],   # G5 (final note, held long)
	]
	for note in fanfare:
		var freq = note[0]
		var start = note[1]
		var ndur = note[2]
		var ns = _make_samples(ndur + 0.5)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			var nf = t / ndur
			var vib = 1.0 + 0.003 * sin(t * 5.0 * TAU) * clampf(t - 0.1, 0.0, 1.0)
			var f = freq * vib
			# Brass: odd harmonics stronger
			ns[i] = sin(t * f * TAU) * 0.06
			ns[i] += sin(t * f * 2.0 * TAU) * 0.03
			ns[i] += sin(t * f * 3.0 * TAU) * 0.04
			ns[i] += sin(t * f * 4.0 * TAU) * 0.015
			ns[i] += sin(t * f * 5.0 * TAU) * 0.02
			var env = min(t * 15.0, 1.0) * maxf(0.0, 1.0 - maxf(nf - 0.7, 0.0) * 3.3)
			ns[i] *= env
		_mix_into(samples, ns, int(start * SAMPLE_RATE))

	# Cymbal crash at the climax
	var crash_start = int(1.3 * SAMPLE_RATE)
	var crash_dur = int(3.0 * SAMPLE_RATE)
	var c_rng = RandomNumberGenerator.new()
	c_rng.seed = 1234
	for i in range(crash_dur):
		var di = crash_start + i
		if di >= samples.size():
			break
		var t = float(i) / SAMPLE_RATE
		var env = exp(-t * 1.5) * 0.06
		samples[di] += c_rng.randf_range(-1.0, 1.0) * env
		samples[di] += sin(float(di) / SAMPLE_RATE * 3000.0 * TAU) * env * 0.1

	_soft_clip(samples, 1.5)
	# Fade out at end
	var fade_len = int(1.5 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
	# Fade in at start
	var fade_in = int(0.1 * SAMPLE_RATE)
	for i in range(fade_in):
		samples[i] *= float(i) / fade_in
	return _to_stream(samples, false)

# ---- WAVE WARNING — Short ominous stinger when a new wave of enemies spawns ----
func _gen_wave_warning() -> AudioStreamWAV:
	var dur = 3.0
	var samples = _make_samples(dur)

	# Descending brass stab — warning horn
	var horn_notes = [220.0, 196.0, 174.61, 164.81]
	var note_dur = 0.4
	for ni in range(horn_notes.size()):
		var freq = horn_notes[ni]
		var start = ni * note_dur * 0.8
		var ns = _make_samples(note_dur + 0.3)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			var vib = 1.0 + 0.005 * sin(t * 6.0 * TAU)
			var f = freq * vib
			ns[i] = sin(t * f * TAU) * 0.08
			ns[i] += sin(t * f * 2.0 * TAU) * 0.04
			ns[i] += sin(t * f * 3.0 * TAU) * 0.05
			var env = min(t * 20.0, 1.0) * exp(-t * 3.0)
			ns[i] *= env
		_mix_into(samples, ns, int(start * SAMPLE_RATE))

	# Timpani roll underneath
	var t_rng = RandomNumberGenerator.new()
	t_rng.seed = 8888
	var roll_t = 0.0
	while roll_t < 2.0:
		var ti = int(roll_t * SAMPLE_RATE)
		var tdur = int(0.08 * SAMPLE_RATE)
		for i in range(tdur):
			var di = ti + i
			if di >= samples.size():
				break
			var t = float(i) / SAMPLE_RATE
			var env = exp(-t * 18.0) * 0.1
			samples[di] += sin(float(di) / SAMPLE_RATE * 65.0 * TAU) * env
		roll_t += t_rng.randf_range(0.06, 0.12)

	_soft_clip(samples, 1.5)
	var fade_len = int(0.8 * SAMPLE_RATE)
	for i in range(fade_len):
		samples[samples.size() - fade_len + i] *= 1.0 - float(i) / fade_len
	return _to_stream(samples, false)
