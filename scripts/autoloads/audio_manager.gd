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

func _ready() -> void:
	_generate_all_sfx()
	_generate_all_music()
	_create_players()

# ============================================================
# PUBLIC API
# ============================================================

func get_sfx(sfx_name: String) -> AudioStreamWAV:
	return _sfx_cache.get(sfx_name)

var _next_sfx_player: int = 0  # Round-robin index for SFX pool

func play_sfx(sfx_name: String, volume_offset: float = 0.0) -> void:
	var stream = _sfx_cache.get(sfx_name)
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
	if not stream:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = _music_volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

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
	# Triumphant ascending arpeggio: C4 -> E4 -> G4 -> C5
	var samples = _make_samples(0.7)
	_add_sine_segment(samples, 261.6, 0.5, 0.0, 0.18)
	_add_sine_segment(samples, 329.6, 0.5, 0.13, 0.18)
	_add_sine_segment(samples, 392.0, 0.55, 0.26, 0.18)
	_add_sine_segment(samples, 523.0, 0.6, 0.39, 0.31)
	# Add harmonics to the final note for richness
	_add_sine_segment(samples, 1046.0, 0.15, 0.39, 0.31)
	_add_sine_segment(samples, 784.0, 0.2, 0.39, 0.31)
	_apply_decay(samples, 0.8)
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

# ============================================================
# MUSIC GENERATION
# ============================================================

func _generate_all_music() -> void:
	_music_cache["town"] = _gen_town_music()

# A minor pentatonic frequencies
const PENTA = {
	"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "G3": 196.0,
	"A3": 220.0, "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.0,
	"A4": 440.0, "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 784.0,
}

func _gen_town_music() -> AudioStreamWAV:
	# Fantasy town theme — four distinct sections (~72s total) for variety
	# Section A: Peaceful dawn (0-18s) — sparse, contemplative
	# Section B: Village life (18-36s) — warmer, fuller melody
	# Section C: Twilight reverie (36-54s) — bittersweet, minor color
	# Section D: Hearthside (54-72s) — gentle resolution, leads back to A
	var duration = 72.0
	var samples = _make_samples(duration)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7741

	# Extended scale — natural minor with some borrowed tones for color
	var NOTE = {
		"A2": 110.0, "B2": 123.47, "C3": 130.81, "D3": 146.83, "E3": 164.81,
		"F3": 174.61, "G3": 196.0,
		"A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63,
		"F4": 349.23, "G4": 392.0,
		"A4": 440.0, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
		"F5": 698.46, "G5": 784.0, "A5": 880.0,
	}

	# ---- Layer 1: Evolving bass ----
	# Bass moves through a chord progression instead of droning on one note
	# Am - C - G - Em | Am - F - C - G | Am - Dm - Em - Am | F - G - Am - Am
	var bass_prog = [
		NOTE["A2"], NOTE["A2"], NOTE["C3"], NOTE["C3"],
		NOTE["G3"], NOTE["G3"], NOTE["E3"], NOTE["E3"],
		NOTE["A2"], NOTE["A2"], NOTE["F3"], NOTE["F3"],
		NOTE["C3"], NOTE["C3"], NOTE["G3"], NOTE["G3"],
		NOTE["A2"], NOTE["A2"], NOTE["D3"], NOTE["D3"],
		NOTE["E3"], NOTE["E3"], NOTE["A2"], NOTE["A2"],
		NOTE["F3"], NOTE["F3"], NOTE["G3"], NOTE["G3"],
		NOTE["A2"], NOTE["A2"], NOTE["A2"], NOTE["A2"],
	]
	var bass_note_dur = duration / bass_prog.size()
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var prog_idx = int(t / bass_note_dur) % bass_prog.size()
		var bass_freq = bass_prog[prog_idx]
		# Crossfade between bass notes for smoothness
		var note_t = fmod(t, bass_note_dur) / bass_note_dur
		var bass_env = 0.10 * (0.7 + 0.3 * sin(note_t * PI))
		# Warm bass: fundamental + soft 2nd harmonic
		samples[i] += sin(t * bass_freq * TAU) * bass_env
		samples[i] += sin(t * bass_freq * 2.0 * TAU) * bass_env * 0.2
		# Sub rumble that breathes
		samples[i] += sin(t * bass_freq * 0.5 * TAU) * bass_env * 0.25

	# ---- Layer 2: Pad chords — shift voicing per section ----
	# Each section gets different chord colors for 18s each
	var _pad_chords = [
		# Section A: open fifths + octave (spacious, calm)
		[NOTE["A3"], NOTE["E4"]],
		[NOTE["C4"], NOTE["G4"]],
		[NOTE["G3"], NOTE["D4"]],
		[NOTE["E3"], NOTE["B3"]],
		# Section B: triads (fuller, warmer)
		[NOTE["A3"], NOTE["C4"], NOTE["E4"]],
		[NOTE["F3"], NOTE["A3"], NOTE["C4"]],
		[NOTE["C4"], NOTE["E4"], NOTE["G4"]],
		[NOTE["G3"], NOTE["B3"], NOTE["D4"]],
		# Section C: minor / suspended (bittersweet)
		[NOTE["A3"], NOTE["C4"], NOTE["E4"]],
		[NOTE["D4"], NOTE["F4"], NOTE["A4"]],
		[NOTE["E3"], NOTE["G3"], NOTE["B3"]],
		[NOTE["A3"], NOTE["D4"], NOTE["E4"]],
		# Section D: resolved, gentle (leads back)
		[NOTE["F3"], NOTE["A3"], NOTE["C4"]],
		[NOTE["G3"], NOTE["B3"], NOTE["D4"]],
		[NOTE["A3"], NOTE["C4"], NOTE["E4"]],
		[NOTE["A3"], NOTE["E4"]],
	]
	var pad_chord_dur = duration / _pad_chords.size()  # 4.5s each
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var chord_idx = int(t / pad_chord_dur) % _pad_chords.size()
		var chord = _pad_chords[chord_idx]
		# Swell envelope per chord — rises and falls over its duration
		var chord_t = fmod(t, pad_chord_dur) / pad_chord_dur
		var pad_env = sin(chord_t * PI) * 0.06
		for freq in chord:
			# Slightly detuned pair for warmth
			samples[i] += sin(t * freq * TAU) * pad_env
			samples[i] += sin(t * freq * 1.004 * TAU) * pad_env * 0.5

	# ---- Layer 3: Four distinct melodies, one per section ----
	# Section A (0-18s): Sparse, contemplative — long notes, wide intervals
	var melody_a = [
		[NOTE["E4"], 2.5], [0, 1.0],
		[NOTE["A4"], 2.0], [NOTE["G4"], 1.5], [0, 0.5],
		[NOTE["E4"], 1.5], [NOTE["D4"], 2.0], [0, 1.0],
		[NOTE["C4"], 2.5], [NOTE["E4"], 1.5], [NOTE["A4"], 1.5],
	]
	# Section B (18-36s): Flowing, warmer — stepwise motion, more notes
	var melody_b = [
		[NOTE["A4"], 1.0], [NOTE["B4"], 0.75], [NOTE["C5"], 1.25],
		[NOTE["B4"], 0.75], [NOTE["A4"], 1.0], [NOTE["G4"], 1.25],
		[0, 0.5],
		[NOTE["E4"], 1.0], [NOTE["G4"], 0.75], [NOTE["A4"], 1.25],
		[NOTE["C5"], 1.0], [NOTE["D5"], 0.75], [NOTE["C5"], 1.0],
		[NOTE["A4"], 1.5], [0, 0.5],
		[NOTE["G4"], 0.75], [NOTE["A4"], 0.75], [NOTE["C5"], 1.0],
		[NOTE["B4"], 1.0], [NOTE["A4"], 1.5],
	]
	# Section C (36-54s): Bittersweet — minor color, ornamental
	var melody_c = [
		[NOTE["E5"], 1.5], [NOTE["D5"], 1.0], [NOTE["C5"], 1.5],
		[NOTE["B4"], 0.75], [NOTE["A4"], 1.25], [0, 0.5],
		[NOTE["D5"], 1.5], [NOTE["C5"], 1.0], [NOTE["A4"], 1.5],
		[NOTE["G4"], 0.75], [NOTE["F4"], 1.25], [0, 0.5],
		[NOTE["A4"], 1.0], [NOTE["C5"], 1.0], [NOTE["E5"], 1.5],
		[NOTE["D5"], 1.0], [NOTE["C5"], 1.5],
	]
	# Section D (54-72s): Gentle resolution — calm, brings us home
	var melody_d = [
		[NOTE["C5"], 1.5], [NOTE["A4"], 1.25], [0, 0.5],
		[NOTE["G4"], 1.0], [NOTE["A4"], 1.25], [NOTE["C5"], 1.5],
		[0, 0.5],
		[NOTE["E4"], 1.5], [NOTE["G4"], 1.0], [NOTE["A4"], 2.0],
		[0, 0.5],
		[NOTE["C5"], 1.0], [NOTE["B4"], 0.75], [NOTE["A4"], 2.0],
		[0, 1.0],
		[NOTE["E4"], 1.5], [NOTE["A4"], 1.75],
	]
	var sections = [melody_a, melody_b, melody_c, melody_d]
	var section_dur = 18.0
	for s_idx in range(4):
		var melody = sections[s_idx]
		var section_start = s_idx * section_dur
		var note_time = 0.0
		for note_pair in melody:
			var freq = note_pair[0]
			var ndur = note_pair[1]
			if freq > 0 and note_time + section_start < duration:
				var actual_dur = min(ndur * 1.3, duration - (note_time + section_start))
				var note_samp = _make_samples(actual_dur)
				for i in range(note_samp.size()):
					var t = float(i) / SAMPLE_RATE
					# Rich tone: fundamental + detuned + soft harmonics
					note_samp[i] = sin(t * freq * TAU) * 0.055
					note_samp[i] += sin(t * freq * 1.003 * TAU) * 0.025
					note_samp[i] += sin(t * freq * 2.0 * TAU) * 0.012
					note_samp[i] += sin(t * freq * 3.0 * TAU) * 0.004
				_apply_envelope(note_samp, 0.06, ndur * 0.35, ndur * 0.7)
				_mix_into(samples, note_samp, int((note_time + section_start) * SAMPLE_RATE))
			note_time += ndur

	# ---- Layer 4: Counter-melody / response (sections B and D only) ----
	# A lower voice that answers the main melody
	var counter_b = [
		[0, 2.0],
		[NOTE["E4"], 1.5], [NOTE["D4"], 1.0], [NOTE["C4"], 1.5], [0, 1.0],
		[NOTE["A3"], 1.5], [NOTE["C4"], 1.0], [NOTE["D4"], 1.5], [0, 1.0],
		[NOTE["E4"], 1.5], [NOTE["D4"], 1.0], [NOTE["C4"], 2.0], [0, 1.0],
		[NOTE["A3"], 2.0],
	]
	var counter_d = [
		[0, 3.0],
		[NOTE["A3"], 2.0], [NOTE["C4"], 1.5], [NOTE["E4"], 2.0], [0, 1.0],
		[NOTE["D4"], 1.5], [NOTE["C4"], 2.0], [0, 1.0],
		[NOTE["A3"], 2.0], [NOTE["E4"], 2.0],
	]
	var counters = [[1, counter_b], [3, counter_d]]
	for pair in counters:
		var sec = pair[0]
		var counter = pair[1]
		var counter_start = sec * section_dur
		var ct = 0.0
		for note_pair in counter:
			var freq = note_pair[0]
			var ndur = note_pair[1]
			if freq > 0 and ct + counter_start < duration:
				var actual_dur = min(ndur * 1.2, duration - (ct + counter_start))
				var ns = _make_samples(actual_dur)
				for i in range(ns.size()):
					var t = float(i) / SAMPLE_RATE
					ns[i] = sin(t * freq * TAU) * 0.035
					ns[i] += sin(t * freq * 1.005 * TAU) * 0.015
				_apply_envelope(ns, 0.1, ndur * 0.3, ndur * 0.65)
				_mix_into(samples, ns, int((ct + counter_start) * SAMPLE_RATE))
			ct += ndur

	# ---- Layer 5: Twinkles & atmosphere (vary density by section) ----
	var twinkle_notes = [NOTE["E5"], NOTE["G5"], NOTE["A5"], NOTE["D5"], NOTE["C5"]]
	var twinkle_time = 3.0
	while twinkle_time < duration - 1.0:
		# Section index determines twinkle density
		var sec_idx = int(twinkle_time / section_dur)
		var freq = twinkle_notes[rng.randi() % twinkle_notes.size()]
		var twinkle = _make_samples(0.6)
		for i in range(twinkle.size()):
			var t = float(i) / SAMPLE_RATE
			twinkle[i] = sin(t * freq * TAU) * 0.03
			twinkle[i] += sin(t * freq * 2.0 * TAU) * 0.008  # Shimmer
		_apply_envelope(twinkle, 0.01, 0.06, 0.52)
		_mix_into(samples, twinkle, int(twinkle_time * SAMPLE_RATE))
		# Sparse in A/D, denser in B/C
		if sec_idx == 0 or sec_idx == 3:
			twinkle_time += rng.randf_range(3.5, 6.0)
		else:
			twinkle_time += rng.randf_range(2.0, 3.5)

	# ---- Layer 6: Soft rhythmic pulse (sections B and C only) ----
	# Very gentle, almost subliminal heartbeat gives forward motion
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		if t < 18.0 or t >= 54.0:
			continue
		# Gentle pulse every ~1.5s
		var pulse_phase = fmod(t, 1.5) / 1.5
		if pulse_phase < 0.08:
			var pulse_env = sin(pulse_phase / 0.08 * PI) * 0.025
			samples[i] += sin(t * NOTE["A2"] * TAU) * pulse_env

	# ---- Smooth loop crossfade (last 2s fades, first 2s fades in) ----
	var fade_len = int(2.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac

	return _to_stream(samples, true)
