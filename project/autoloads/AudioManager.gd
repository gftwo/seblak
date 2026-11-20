extends Node

var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamGeneratorPlayback
var bgm_player: AudioStreamPlayer
var bgm_playback: AudioStreamGeneratorPlayback

var sample_rate: float = 22050.0
var is_muted: bool = false

var tone_freq: float = 0.0
var tone_time: float = 0.0
var noise_time: float = 0.0
var sfx_phase: float = 0.0

# BGM Lofi Santai Warung
var bgm_phase: float = 0.0
var bgm_timer: float = 0.0
var bgm_step: int = 0
var bgm_notes: Array = [261.63, 329.63, 392.00, 493.88, 349.23, 440.00, 392.00, 329.63]

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	var sfx_stream = AudioStreamGenerator.new()
	sfx_stream.mix_rate = sample_rate
	sfx_stream.buffer_length = 0.1
	sfx_player.stream = sfx_stream
	sfx_player.volume_db = -9.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback()

	bgm_player = AudioStreamPlayer.new()
	var bgm_stream = AudioStreamGenerator.new()
	bgm_stream.mix_rate = sample_rate
	bgm_stream.buffer_length = 0.15
	bgm_player.stream = bgm_stream
	bgm_player.volume_db = -21.0
	add_child(bgm_player)
	bgm_player.play()
	bgm_playback = bgm_player.get_stream_playback()

func _process(delta: float) -> void:
	if is_muted:
		return

	# Render SFX
	if sfx_playback:
		var frames = sfx_playback.get_frames_available()
		var inc = tone_freq / sample_rate
		for i in range(frames):
			var sample: float = 0.0
			if tone_time > 0.0:
				sample += sin(sfx_phase * TAU) * 0.35
				sfx_phase = fmod(sfx_phase + inc, 1.0)
				tone_time -= 1.0 / sample_rate
			if noise_time > 0.0:
				sample += randf_range(-0.15, 0.15)
				noise_time -= 1.0 / sample_rate
			sfx_playback.push_frame(Vector2(sample, sample))

	# Render BGM Melodi Santai
	if bgm_playback:
		bgm_timer += delta
		if bgm_timer >= 0.48:
			bgm_timer = 0.0
			bgm_step = (bgm_step + 1) % bgm_notes.size()
		var b_frames = bgm_playback.get_frames_available()
		var b_freq = bgm_notes[bgm_step]
		var b_inc = b_freq / sample_rate
		for i in range(b_frames):
			var env = max(0.0, 1.0 - (bgm_timer * 1.6))
			var b_sample = (sin(bgm_phase * TAU) * 0.18 + sin(bgm_phase * TAU * 0.5) * 0.12) * env
			bgm_phase = fmod(bgm_phase + b_inc, 1.0)
			bgm_playback.push_frame(Vector2(b_sample, b_sample))

func play_click() -> void:
	tone_freq = 540.0
	tone_time = 0.06

func play_chili_chop() -> void:
	tone_freq = 760.0
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
	tone_time = 0.24

func play_error() -> void:
	tone_freq = 160.0
	tone_time = 0.30
