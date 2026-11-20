extends Node

# Procedural Synthesizer Audio (Tanpa aset eksternal, ringan & anti-error)
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0
var is_muted: bool = false

# Queue nada sederhana
var tone_freq: float = 0.0
var tone_time: float = 0.0
var noise_time: float = 0.0
var phase: float = 0.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.1
	player.stream = stream
	player.volume_db = -10.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func _process(delta: float) -> void:
	if not playback or is_muted:
		return
	var frames_available = playback.get_frames_available()
	if frames_available <= 0:
		return
		
	var increment = tone_freq / sample_rate
	for i in range(frames_available):
		var sample: float = 0.0
		if tone_time > 0.0:
			sample += sin(phase * TAU) * 0.35
			phase = fmod(phase + increment, 1.0)
			tone_time -= 1.0 / sample_rate
		if noise_time > 0.0:
			sample += randf_range(-0.15, 0.15)
			noise_time -= 1.0 / sample_rate
		playback.push_frame(Vector2(sample, sample))

func play_click() -> void:
	tone_freq = 520.0
	tone_time = 0.06

func play_chili_chop() -> void:
	tone_freq = 740.0
	tone_time = 0.08
	noise_time = 0.05

func play_sizzle() -> void:
	noise_time = 0.35
	tone_freq = 180.0
	tone_time = 0.12

func play_ready_bell() -> void:
	tone_freq = 880.0
	tone_time = 0.25

func play_cash_register() -> void:
	tone_freq = 1046.5
	tone_time = 0.22

func play_error() -> void:
	tone_freq = 160.0
	tone_time = 0.30
