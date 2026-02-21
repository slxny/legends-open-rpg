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
	# Fantasy town theme — 8 sections (~3:12), rich timbres, full musical arc
	# A: Dawn mist (0-24)      B: Morning market (24-48)
	# C: Storyteller (48-72)   D: Forge & river (72-96)
	# E: Afternoon shade (96-120)  F: Gathering storm (120-144)
	# G: Celebration (144-168) H: Twilight return (168-192)
	var duration = 192.0
	var samples = _make_samples(duration)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7741
	var section_dur = 24.0
	var num_sections = 8

	var N = {
		"G2": 98.0, "Ab2": 103.83, "A2": 110.0, "Bb2": 116.54, "B2": 123.47,
		"C3": 130.81, "D3": 146.83, "Eb3": 155.56, "E3": 164.81,
		"F3": 174.61, "Fs3": 185.0, "G3": 196.0,
		"A3": 220.0, "Bb3": 233.08, "B3": 246.94,
		"C4": 261.63, "D4": 293.66, "Eb4": 311.13, "E4": 329.63,
		"F4": 349.23, "Fs4": 369.99, "G4": 392.0, "Ab4": 415.30,
		"A4": 440.0, "Bb4": 466.16, "B4": 493.88,
		"C5": 523.25, "D5": 587.33, "Eb5": 622.25, "E5": 659.25,
		"F5": 698.46, "Fs5": 739.99, "G5": 784.0, "Ab5": 830.61,
		"A5": 880.0, "C6": 1046.5,
	}

	# Helper: render a note with timbre and expression into a buffer
	# timbre: 0=flute 1=string 2=oboe 3=horn 4=harp
	# expr: 0=normal 1=swell 2=fade 3=accent
	var _render = func(freq: float, ndur: float, timbre: int, expr: int) -> Array:
		var ns = _make_samples(ndur * 1.4)
		for i in range(ns.size()):
			var t = float(i) / SAMPLE_RATE
			var nf = t / ndur
			var vr = [5.2, 4.8, 5.8, 4.0, 0.0][timbre]
			var vd = [0.003, 0.004, 0.005, 0.003, 0.0][timbre] * clampf(t - 0.12, 0.0, 1.0)
			var f = freq * (1.0 + vd * sin(t * vr * TAU))
			var ph = t * f * TAU
			match timbre:
				0:
					ns[i] = sin(ph) * 0.050 + sin(ph * 3.0) * 0.013
					ns[i] += sin(ph + sin(t * 1337.0) * 0.8) * 0.007
				1:
					ns[i] = sin(ph) * 0.030 + sin(ph * 2.0) * 0.011
					ns[i] += sin(ph * 3.0) * 0.015 + sin(t * freq * 1.002 * TAU) * 0.011
				2:
					ns[i] = sin(ph) * 0.040 + sin(ph * 2.0) * 0.020
					ns[i] += sin(ph * 3.0) * 0.025 + sin(ph * 5.0) * 0.012
				3:
					ns[i] = sin(ph) * 0.045 + sin(ph * 2.0) * 0.018
					ns[i] += sin(t * freq * 1.001 * TAU) * 0.015
				4:
					ns[i] = sin(ph) * 0.045 + sin(t * freq * 2.003 * TAU) * 0.020
					ns[i] += sin(t * freq * 3.008 * TAU) * 0.010
					ns[i] *= exp(-t * 4.0)
			match expr:
				1: ns[i] *= 0.65 + 0.35 * sin(nf * PI)
				2: ns[i] *= maxf(0.0, 1.0 - nf * 0.55)
				3: ns[i] *= 1.0 + 0.4 * exp(-t * 8.0)
		var atk = 0.005 if timbre == 4 else 0.07
		_apply_envelope(ns, atk, ndur * 0.35, ndur * 0.75)
		return ns

	# ---- BASS: 4 notes per section = 32 total ----
	var bass_prog = [
		N["A2"], N["A2"], N["E3"], N["A2"],       # A: pedal
		N["A2"], N["F3"], N["C3"], N["G3"],       # B: lively
		N["A2"], N["D3"], N["E3"], N["A2"],       # C: storytelling
		N["F3"], N["G3"], N["A2"], N["E3"],       # D: rhythmic
		N["D3"], N["G3"], N["A2"], N["C3"],       # E: dorian
		N["A2"], N["Eb3"], N["Bb2"], N["E3"],     # F: chromatic tension
		N["F3"], N["G3"], N["C3"], N["A2"],       # G: triumphant
		N["A2"], N["E3"], N["G2"], N["A2"],       # H: return
	]
	var bass_note_dur = duration / bass_prog.size()
	var prev_bass_freq = bass_prog[0]
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var prog_idx = int(t / bass_note_dur) % bass_prog.size()
		var bass_freq = bass_prog[prog_idx]
		var note_t = fmod(t, bass_note_dur)
		var slide_frac = clampf(note_t / 0.15, 0.0, 1.0)
		var eff_freq = lerpf(prev_bass_freq, bass_freq, slide_frac)
		if note_t < 0.001:
			prev_bass_freq = bass_prog[(prog_idx - 1 + bass_prog.size()) % bass_prog.size()]
		var sec = int(t / section_dur)
		var bvol = 0.08
		if sec == 0 or sec == 7: bvol = 0.06
		elif sec == 3 or sec == 5 or sec == 6: bvol = 0.10
		var env = bvol * (0.6 + 0.4 * exp(-note_t * 1.2))
		var phase = t * eff_freq * TAU
		samples[i] += sin(phase) * env
		samples[i] += sin(phase * 3.0) * env * 0.10
		samples[i] += sin(phase * 5.0) * env * 0.03
		samples[i] += sin(t * eff_freq * 0.5 * TAU) * env * 0.25

	# ---- PAD CHORDS: 4 per section = 32 total ----
	var pad_chords = [
		[N["A3"], N["E4"]], [N["C4"], N["G4"]],
		[N["E3"], N["B3"]], [N["A3"], N["E4"]],
		[N["A3"], N["C4"], N["E4"]], [N["F3"], N["A3"], N["C4"]],
		[N["C4"], N["E4"], N["G4"]], [N["G3"], N["B3"], N["D4"]],
		[N["A3"], N["C4"], N["E4"]], [N["D4"], N["F4"], N["A4"]],
		[N["E3"], N["G3"], N["B3"]], [N["A3"], N["C4"], N["G4"]],
		[N["F3"], N["C4"]], [N["G3"], N["D4"]],
		[N["A3"], N["E4"]], [N["E3"], N["B3"]],
		[N["D4"], N["F4"], N["A4"]], [N["G3"], N["B3"], N["D4"]],
		[N["A3"], N["C4"], N["E4"]], [N["C4"], N["E4"], N["G4"]],
		[N["A3"], N["C4"], N["E4"]], [N["Eb4"], N["G4"], N["Bb4"]],
		[N["Bb3"], N["D4"], N["F4"]], [N["E3"], N["B3"]],
		[N["F3"], N["A3"], N["C4"], N["E4"]], [N["G3"], N["B3"], N["D4"], N["G4"]],
		[N["C4"], N["E4"], N["G4"], N["C5"]], [N["A3"], N["C4"], N["E4"], N["A4"]],
		[N["A3"], N["E4"], N["A4"]], [N["C4"], N["G4"]],
		[N["G3"], N["D4"]], [N["A3"], N["E4"]],
	]
	var pad_dur = duration / pad_chords.size()
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var chord_idx = int(t / pad_dur) % pad_chords.size()
		var chord = pad_chords[chord_idx]
		var chord_t = fmod(t, pad_dur) / pad_dur
		var swell = sin(chord_t * PI)
		var sec = int(t / section_dur)
		var pvol = [0.04, 0.05, 0.05, 0.04, 0.055, 0.06, 0.065, 0.04][sec]
		var bright = [0.06, 0.14, 0.10, 0.08, 0.12, 0.20, 0.18, 0.05][sec]
		swell = pow(swell, 1.3) * pvol
		for freq in chord:
			var p1 = t * freq * TAU
			samples[i] += sin(p1) * swell
			samples[i] += sin(t * freq * 1.003 * TAU) * swell * 0.4
			samples[i] += sin(t * freq * 0.997 * TAU) * swell * 0.4
			samples[i] += sin(p1 * 2.0) * swell * bright
			samples[i] += sin(p1 * 3.0) * swell * bright * 0.35

	# ---- 8 MELODIES — each with unique character and timbre ----
	# [freq, dur, expr] | timbre per section: 0=flute 2=oboe 3=horn 1=string
	var mA = [  # Dawn mist: flute, sparse
		[N["E4"], 3.0, 0], [0, 2.0, 0], [N["A4"], 2.5, 1], [N["G4"], 1.8, 2],
		[0, 1.2, 0], [N["E4"], 1.8, 0], [N["D4"], 3.0, 2], [0, 2.0, 0],
		[N["C4"], 2.5, 1], [N["E4"], 1.8, 0], [N["A4"], 2.0, 2],
	]
	var mB = [  # Morning market: oboe, quick playful
		[N["A4"], 0.5, 3], [N["B4"], 0.4, 0], [N["C5"], 0.6, 1],
		[N["E5"], 0.5, 3], [N["D5"], 0.4, 0], [N["C5"], 0.6, 2],
		[N["A4"], 0.5, 0], [N["G4"], 0.5, 0], [0, 0.5, 0],
		[N["A4"], 0.4, 3], [N["C5"], 0.5, 0], [N["D5"], 0.6, 1],
		[N["E5"], 0.4, 0], [N["C5"], 0.5, 0], [N["A4"], 0.8, 2], [0, 0.6, 0],
		[N["G4"], 0.4, 0], [N["A4"], 0.4, 0], [N["B4"], 0.5, 1],
		[N["C5"], 0.5, 3], [N["D5"], 0.4, 0], [N["E5"], 0.5, 1],
		[N["D5"], 0.4, 0], [N["C5"], 0.5, 0], [N["B4"], 0.4, 0],
		[N["A4"], 1.0, 2], [0, 0.6, 0],
		[N["E5"], 0.5, 3], [N["D5"], 0.5, 0], [N["C5"], 0.5, 0],
		[N["B4"], 0.5, 0], [N["A4"], 0.5, 0], [N["G4"], 0.5, 0],
		[N["A4"], 1.5, 2],
	]
	var mC = [  # Storyteller: flute, lyrical
		[N["A4"], 1.2, 1], [N["C5"], 1.0, 0], [N["E5"], 1.8, 1],
		[N["D5"], 0.8, 0], [N["C5"], 1.5, 2], [0, 0.7, 0],
		[N["B4"], 0.8, 0], [N["A4"], 1.0, 0], [N["G4"], 1.2, 1],
		[N["A4"], 1.5, 2], [0, 0.8, 0],
		[N["E4"], 0.8, 0], [N["G4"], 0.8, 1], [N["A4"], 1.2, 0],
		[N["C5"], 1.5, 1], [N["D5"], 1.0, 0], [N["E5"], 2.0, 1],
		[N["D5"], 1.0, 2], [N["C5"], 1.0, 0], [N["A4"], 2.0, 2],
	]
	var mD = [  # Forge & river: horn, rhythmic
		[N["A4"], 0.6, 3], [0, 0.3, 0], [N["A4"], 0.6, 3], [0, 0.3, 0],
		[N["C5"], 0.8, 1], [N["A4"], 0.5, 0], [0, 0.4, 0],
		[N["G4"], 0.6, 3], [0, 0.3, 0], [N["G4"], 0.6, 3], [0, 0.3, 0],
		[N["E4"], 0.8, 1], [N["G4"], 0.5, 0], [0, 0.4, 0],
		[N["F4"], 0.6, 3], [N["G4"], 0.6, 0], [N["A4"], 1.2, 1],
		[N["C5"], 1.0, 0], [N["B4"], 0.8, 0], [N["A4"], 1.5, 2], [0, 0.8, 0],
		[N["E4"], 0.6, 3], [N["F4"], 0.5, 0], [N["G4"], 0.6, 0],
		[N["A4"], 1.0, 1], [N["G4"], 0.8, 0], [N["E4"], 1.5, 2], [0, 0.5, 0],
		[N["A4"], 0.6, 3], [N["C5"], 0.8, 1], [N["E5"], 1.2, 1],
		[N["D5"], 0.8, 0], [N["C5"], 0.6, 0], [N["A4"], 1.5, 2],
	]
	var mE = [  # Afternoon shade: flute, dorian lazy
		[N["D5"], 2.0, 1], [N["C5"], 1.2, 0], [N["A4"], 2.0, 2], [0, 1.0, 0],
		[N["G4"], 1.5, 0], [N["A4"], 1.0, 0], [N["C5"], 1.8, 1],
		[N["D5"], 1.2, 0], [N["E5"], 2.0, 2], [0, 1.0, 0],
		[N["D5"], 1.5, 1], [N["C5"], 1.0, 0], [N["A4"], 1.8, 2], [0, 0.8, 0],
		[N["Fs4"], 1.5, 1], [N["G4"], 1.0, 0], [N["A4"], 2.2, 2],
	]
	var mF = [  # Gathering storm: string, dramatic chromatic
		[N["E5"], 1.5, 3], [N["Eb5"], 0.8, 0], [N["D5"], 1.5, 2],
		[N["C5"], 0.6, 0], [N["B4"], 1.2, 2], [0, 0.5, 0],
		[N["A4"], 0.8, 3], [N["Bb4"], 0.8, 0], [N["C5"], 1.2, 1],
		[N["D5"], 1.5, 0], [N["Eb5"], 1.5, 1], [0, 0.5, 0],
		[N["E5"], 1.0, 3], [N["D5"], 0.8, 0], [N["C5"], 0.8, 0],
		[N["B4"], 0.8, 0], [N["A4"], 1.2, 2], [0, 0.6, 0],
		[N["Ab4"], 1.2, 1], [N["A4"], 0.8, 0], [N["B4"], 1.0, 0],
		[N["E5"], 2.0, 1], [N["E5"], 2.5, 2],
	]
	var mG = [  # Celebration: horn, triumphant major
		[N["C5"], 0.8, 3], [N["E5"], 0.8, 3], [N["G5"], 1.5, 1],
		[N["E5"], 0.8, 0], [N["C5"], 0.5, 0], [0, 0.4, 0],
		[N["D5"], 0.8, 3], [N["F5"], 0.8, 0], [N["A5"], 1.5, 1],
		[N["G5"], 0.8, 0], [N["E5"], 0.8, 0], [0, 0.4, 0],
		[N["C5"], 0.6, 0], [N["D5"], 0.6, 0], [N["E5"], 0.8, 1],
		[N["G5"], 1.2, 3], [N["A5"], 1.5, 1], [0, 0.5, 0],
		[N["G5"], 0.8, 0], [N["E5"], 0.8, 0], [N["D5"], 0.8, 0],
		[N["C5"], 1.2, 0], [N["E5"], 1.0, 1], [N["C5"], 2.5, 2],
	]
	var mH = [  # Twilight return: flute, reprises dawn
		[N["E4"], 2.5, 0], [N["G4"], 1.0, 0], [0, 1.0, 0],
		[N["A4"], 2.0, 1], [N["B4"], 0.8, 0], [N["A4"], 1.5, 2], [0, 1.0, 0],
		[N["E4"], 1.5, 0], [N["D4"], 1.0, 0], [N["C4"], 2.5, 2], [0, 1.5, 0],
		[N["E4"], 1.0, 0], [N["G4"], 1.0, 1], [N["A4"], 1.5, 0],
		[N["C5"], 2.0, 1], [N["A4"], 2.5, 2],
	]
	var mel_timbres = [0, 2, 0, 3, 0, 1, 3, 0]
	var all_mel = [mA, mB, mC, mD, mE, mF, mG, mH]
	for s_idx in range(num_sections):
		var mel = all_mel[s_idx]
		var ss = s_idx * section_dur
		var tmb = mel_timbres[s_idx]
		var nt = 0.0
		for e in mel:
			if e[0] > 0 and nt + ss < duration:
				var ns = _render.call(e[0], e[1], tmb, e[2])
				_mix_into(samples, ns, int((nt + ss) * SAMPLE_RATE))
			nt += e[1]

	# ---- COUNTER-MELODIES in sections B, C, E, F, G ----
	var cm_data = {
		1: [[0,1.5],[N["E4"],0.5],[N["C4"],0.5],[N["A3"],0.8],[0,1.0],
			[N["G4"],0.5],[N["E4"],0.5],[N["D4"],0.8],[0,0.8],
			[N["C4"],0.5],[N["E4"],0.5],[N["A4"],0.8],[0,0.6],
			[N["G4"],0.6],[N["E4"],0.6],[N["C4"],0.8],[0,0.5],
			[N["D4"],0.5],[N["E4"],0.5],[N["G4"],0.8],[N["A4"],1.0],[0,0.8],
			[N["E4"],0.5],[N["G4"],0.5],[N["A4"],0.8],[N["G4"],0.6],
			[N["E4"],0.5],[N["C4"],0.8],[N["A3"],1.2]],
		2: [[0,3.0],[N["E4"],1.5],[N["D4"],1.0],[N["C4"],1.5],[0,1.0],
			[N["A3"],1.5],[N["C4"],1.0],[N["D4"],1.5],[0,1.0],
			[N["E4"],1.5],[N["D4"],1.0],[N["C4"],2.0],[0,1.0],
			[N["A3"],1.5],[N["G3"],1.0],[N["A3"],2.5]],
		4: [[0,4.0],[N["A3"],2.0],[N["C4"],1.5],[0,1.0],
			[N["D4"],2.0],[N["E4"],1.5],[N["D4"],1.5],[0,1.0],
			[N["C4"],2.0],[N["A3"],1.5],[0,1.0],
			[N["Fs3"],2.0],[N["G3"],1.5],[N["A3"],2.5]],
		5: [[0,2.0],[N["A3"],1.0],[N["Bb3"],1.0],[N["C4"],1.5],
			[N["D4"],1.5],[N["Eb4"],2.0],[0,1.0],
			[N["E4"],1.5],[N["D4"],1.0],[N["C4"],1.0],
			[N["B3"],1.5],[N["A3"],1.5],[0,1.0],
			[N["A3"],1.5],[N["B3"],1.5],[N["E4"],2.5]],
		6: [[0,2.0],[N["G4"],0.6],[N["E4"],0.6],[N["C4"],1.0],[0,0.8],
			[N["A4"],0.6],[N["G4"],0.6],[N["E4"],1.0],[0,0.8],
			[N["C5"],0.6],[N["A4"],0.6],[N["G4"],1.0],
			[N["E4"],0.8],[N["G4"],1.0],[N["C5"],1.5],[0,0.5],
			[N["A4"],0.6],[N["G4"],0.6],[N["E4"],0.8],
			[N["C4"],0.8],[N["E4"],1.0],[N["G4"],1.5],[N["C5"],2.0]],
	}
	var cm_timbres = {1: 4, 2: 1, 4: 1, 5: 1, 6: 3}
	for si in cm_data:
		var cm = cm_data[si]
		var ct = 0.0
		var cs = si * section_dur
		for np in cm:
			if np[0] > 0 and ct + cs < duration:
				var ns = _render.call(np[0], np[1], cm_timbres[si], 0)
				for qi in range(ns.size()): ns[qi] *= 0.7
				_mix_into(samples, ns, int((ct + cs) * SAMPLE_RATE))
			ct += np[1]

	# ---- HARP TWINKLES — follow harmony, vary density ----
	var tw_pools = [
		[N["E5"],N["A5"],N["C5"]],
		[N["A4"],N["C5"],N["E5"],N["G5"]],
		[N["E5"],N["G5"],N["A5"],N["D5"]],
		[N["A4"],N["E5"],N["C5"]],
		[N["D5"],N["Fs5"],N["A5"],N["C5"]],
		[N["E5"],N["Ab5"],N["Bb4"]],
		[N["C5"],N["E5"],N["G5"],N["A5"],N["C6"]],
		[N["E5"],N["A5"],N["C5"],N["G5"]],
	]
	var tw_t = 3.0
	while tw_t < duration - 1.0:
		var si = int(tw_t / section_dur) % num_sections
		var pool = tw_pools[si]
		var freq = pool[rng.randi() % pool.size()]
		var ns = _render.call(freq, 0.6, 4, 0)
		for qi in range(ns.size()): ns[qi] *= 0.55
		_mix_into(samples, ns, int(tw_t * SAMPLE_RATE))
		match si:
			0, 4, 7: tw_t += rng.randf_range(3.5, 6.5)
			1, 6: tw_t += rng.randf_range(1.2, 2.5)
			_: tw_t += rng.randf_range(2.0, 4.0)

	# ---- WIND — breathes through entire piece ----
	var wind = _make_samples(duration)
	var w_rng = RandomNumberGenerator.new()
	w_rng.seed = 9921
	var w_st = 0.0
	var w_pv = 0.0
	for i in range(wind.size()):
		var t = float(i) / SAMPLE_RATE
		if i % 2205 == 0:
			w_st += w_rng.randf_range(-0.02, 0.02)
			w_st = clampf(w_st, -0.3, 0.3)
		var sec = int(t / section_dur)
		var wb = [0.016, 0.005, 0.008, 0.010, 0.008, 0.016, 0.005, 0.016][sec]
		var we = (0.5 + 0.5 * sin(t * TAU / 15.0)) * wb + abs(w_st) * 0.006
		var raw = w_rng.randf_range(-1.0, 1.0)
		w_pv = w_pv * 0.93 + raw * 0.07
		wind[i] = w_pv * we
	_mix_into(samples, wind, 0)

	# ---- PERCUSSION — different rhythm per section ----
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		var sec = int(t / section_dur)
		if sec == 0 or sec == 7: continue  # No perc in dawn/twilight
		var bp = [0, 1.2, 1.8, 0.75, 2.0, 1.5, 1.0, 0][sec]
		var vol = [0, 0.018, 0.015, 0.025, 0.012, 0.020, 0.022, 0][sec]
		var beat_ph = fmod(t, bp)
		if beat_ph < 0.06:
			var p = beat_ph / 0.06
			var env = sin(p * PI) * vol
			var df = 200.0 if sec == 3 else 80.0
			var dd = 50.0 if sec == 3 else 30.0
			samples[i] += sin(t * df * TAU) * env * exp(-beat_ph * dd)
			samples[i] += sin(t * N["A2"] * TAU) * env * 0.4
		elif absf(beat_ph - bp * 0.5) < 0.04:
			var ob = (beat_ph - bp * 0.5 + 0.04) / 0.08
			var env = sin(clampf(ob, 0.0, 1.0) * PI) * vol * 0.35
			samples[i] += sin(t * 130.0 * TAU) * env * exp(-absf(beat_ph - bp * 0.5) * 40.0)

	# ---- NATURE: birds (A/E/H), water (D), crickets (H) ----
	var bird_t = 4.0
	while bird_t < duration:
		var si = int(bird_t / section_dur)
		if si == 0 or si == 4 or si == 7:
			var cd = rng.randf_range(0.10, 0.18)
			var sf = rng.randf_range(1800.0, 2800.0)
			var ef = sf * rng.randf_range(0.6, 0.8)
			var ch = _make_samples(cd)
			var cp = 0.0
			for i in range(ch.size()):
				var t = float(i) / SAMPLE_RATE
				var fr = t / cd
				cp += lerpf(sf, ef, fr) / SAMPLE_RATE
				ch[i] = sin(cp * TAU) * 0.010 * sin(fr * PI)
			_mix_into(samples, ch, int(bird_t * SAMPLE_RATE))
			if rng.randf() < 0.4:
				var c2 = _make_samples(cd * 0.7)
				var c2p = 0.0
				for i in range(c2.size()):
					var t = float(i) / SAMPLE_RATE
					var fr = t / (cd * 0.7)
					c2p += lerpf(sf * 1.08, ef * 1.12, fr) / SAMPLE_RATE
					c2[i] = sin(c2p * TAU) * 0.007 * sin(fr * PI)
				_mix_into(samples, c2, int((bird_t + cd + rng.randf_range(0.12, 0.22)) * SAMPLE_RATE))
		bird_t += rng.randf_range(6.0, 14.0)

	# Water gurgle in section D
	var wt_rng = RandomNumberGenerator.new()
	wt_rng.seed = 5533
	var wp1 = 0.0
	var wp2 = 0.0
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		if t < 72.0 or t >= 96.0: continue
		var raw = wt_rng.randf_range(-1.0, 1.0)
		wp1 = wp1 * 0.85 + raw * 0.15
		wp2 = wp2 * 0.90 + wp1 * 0.10
		var we = (0.5 + 0.5 * sin(t * TAU / 4.0)) * 0.008
		we += (0.5 + 0.5 * sin(t * TAU / 7.3)) * 0.004
		samples[i] += wp2 * we

	# Crickets in section H
	for i in range(samples.size()):
		var t = float(i) / SAMPLE_RATE
		if t < 168.0: continue
		var cp = fmod(t, 1.1)
		if cp < 0.08:
			var env = sin(cp / 0.08 * PI) * 0.006
			samples[i] += sin(t * 4200.0 * TAU) * env * (0.5 + 0.5 * sin(t * 50.0 * TAU))

	# ---- SECTION TRANSITIONS: rising swells before boundaries ----
	for sb in range(1, num_sections):
		var bt = sb * section_dur
		var ss = int((bt - 2.0) * SAMPLE_RATE)
		var se = int(bt * SAMPLE_RATE)
		if ss < 0: continue
		for i in range(ss, mini(se, samples.size())):
			var t = float(i) / SAMPLE_RATE
			var sf = (t - (bt - 2.0)) / 2.0
			var env = pow(sf, 2.0) * 0.025
			var rf = N["E4"] * (1.0 + sf * 0.05)
			samples[i] += sin(t * rf * TAU) * env
			samples[i] += sin(t * rf * 1.5 * TAU) * env * 0.3

	# ---- FINAL: soft clip + loop crossfade ----
	_soft_clip(samples, 1.5)
	var fade_len = int(3.0 * SAMPLE_RATE)
	for i in range(fade_len):
		var frac = float(i) / fade_len
		samples[samples.size() - fade_len + i] *= (1.0 - frac)
		samples[i] *= frac * frac

	return _to_stream(samples, true)
