extends Node

# ============================================================
# AudioManager (Autoload / Singleton)
#
# Gera efeitos sonoros PROCEDURALMENTE por síntese de onda (sem usar
# nenhum arquivo de áudio externo), garantindo que todo som do jogo
# seja 100% original. Também toca música ambiente de fundo (loop
# gerado por acordes simples) e expõe um pool de players 3D para
# tocar sons no mundo (tiros, impactos, passos) sem estourar o
# número de nós.
# ============================================================

const SAMPLE_RATE := 44100
const POOL_SIZE := 16

var _clips: Dictionary = {}
var _pool: Array = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer
var _music_index: int = 0
var _music_tracks: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	_build_clips()
	_build_pool()
	_build_music()


func _ensure_buses() -> void:
	var needed := ["Music", "SFX", "Footsteps", "UI", "Headshot"]
	for bus_name in needed:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.max_distance = 60.0
		add_child(p)
		_pool.append(p)


# ---------------- Síntese de áudio ----------------

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false

	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clamp(samples[i], -1.0, 1.0)
		var s: int = int(v * 32767.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	stream.data = bytes
	return stream


func _envelope(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / max(attack, 0.0001)
	var d := t - attack
	return clamp(1.0 - d / max(decay, 0.0001), 0.0, 1.0)


func _gen_shot() -> AudioStreamWAV:
	# "Crack" curto: ruído filtrado com ataque instantâneo e decaimento rápido
	var duration := 0.14
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		last = last * 0.55 + noise * 0.45  # leve filtro passa-baixa (corpo do som)
		var tone := sin(t * TAU * 120.0) * 0.3
		var env := _envelope(t, 0.001, duration * 0.6)
		samples[i] = (last * 0.8 + tone) * env
	return _make_stream(samples)


func _gen_impact() -> AudioStreamWAV:
	var duration := 0.12
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var thump := sin(t * TAU * 90.0)
		var env := _envelope(t, 0.001, duration * 0.5)
		samples[i] = (noise * 0.3 + thump * 0.7) * env
	return _make_stream(samples)


func _gen_headshot() -> AudioStreamWAV:
	# Timbre agudo e distinto, "ding" metálico, para feedback claro de headshot
	var duration := 0.28
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var f1 := sin(t * TAU * 1400.0)
		var f2 := sin(t * TAU * 2100.0) * 0.5
		var env := _envelope(t, 0.002, duration * 0.85)
		samples[i] = (f1 + f2) * 0.5 * env
	return _make_stream(samples)


func _gen_reload() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var click := 1.0 if fmod(t, 0.07) < 0.006 else 0.0
		var noise := _rng.randf_range(-1.0, 1.0) * 0.15
		samples[i] = click * 0.6 + noise
	return _make_stream(samples)


func _gen_footstep() -> AudioStreamWAV:
	var duration := 0.09
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var thump := sin(t * TAU * 60.0)
		var env := _envelope(t, 0.001, duration * 0.7)
		samples[i] = (noise * 0.4 + thump * 0.6) * env * 0.5
	return _make_stream(samples)


func _gen_hitmarker() -> AudioStreamWAV:
	var duration := 0.05
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var tone := sin(t * TAU * 1800.0)
		var env := _envelope(t, 0.001, duration * 0.9)
		samples[i] = tone * env * 0.6
	return _make_stream(samples)


func _gen_ui_click() -> AudioStreamWAV:
	var duration := 0.045
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var tone := sin(t * TAU * 900.0)
		var env := _envelope(t, 0.001, duration * 0.8)
		samples[i] = tone * env * 0.4
	return _make_stream(samples)


func _build_clips() -> void:
	_clips = {
		"shot": _gen_shot(),
		"impact": _gen_impact(),
		"headshot": _gen_headshot(),
		"reload": _gen_reload(),
		"footstep": _gen_footstep(),
		"hitmarker": _gen_hitmarker(),
		"ui_click": _gen_ui_click(),
	}


func _build_music() -> void:
	# Trilha ambiente leve e minimalista para o treino: um pad de acordes
	# suave gerado por síntese aditiva, em loop, com volume controlável.
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	var duration := 8.0
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var freqs := [110.0, 138.6, 164.8]  # acorde simples (A2, C#3, E3)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		for f in freqs:
			v += sin(t * TAU * f) * 0.12
		var fade: float = clampf(min(t, duration - t) / 0.5, 0.0, 1.0)
		samples[i] = v * fade
	var stream := _make_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = n
	_music_tracks = [stream]


func play_music() -> void:
	if _music_tracks.is_empty():
		return
	_music_player.stream = _music_tracks[_music_index]
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


# ---------------- Reprodução ----------------

func play_sfx_3d(clip_name: String, position: Vector3) -> void:
	if not _clips.has(clip_name):
		return
	var player: AudioStreamPlayer3D = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = _clips[clip_name]
	player.global_position = position
	player.bus = "Headshot" if clip_name == "headshot" else "SFX"
	player.play()


func play_ui(clip_name: String = "ui_click") -> void:
	if not _clips.has(clip_name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _clips[clip_name]
	p.bus = "UI"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
