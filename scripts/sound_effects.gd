class_name SoundEffects extends Node

# Procedural Sound Effect Generator for Kenny Racing
# Generates pleasant arcade/retro audio without any external assets.

var _player: AudioStreamPlayer
var _alert_player: AudioStreamPlayer

var _snd_click: AudioStreamWAV
var _snd_beep_low: AudioStreamWAV
var _snd_beep_high: AudioStreamWAV
var _snd_lap: AudioStreamWAV
var _snd_wrong_way: AudioStreamWAV
var _snd_victory: AudioStreamWAV

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

	_alert_player = AudioStreamPlayer.new()
	_alert_player.bus = "Master"
	add_child(_alert_player)

	_generate_all_sounds()

func _generate_all_sounds() -> void:
	_snd_click = _create_sine_pcm([(880.0, 0.05, 0.4)])
	_snd_beep_low = _create_sine_pcm([(523.25, 0.15, 0.5)])
	_snd_beep_high = _create_sine_pcm([(1046.5, 0.3, 0.6)])
	_snd_lap = _create_sine_pcm([
		(523.25, 0.1, 0.5), # C5
		(659.25, 0.1, 0.55), # E5
		(783.99, 0.25, 0.6)  # G5
	])
	_snd_wrong_way = _create_sine_pcm([
		(392.0, 0.12, 0.5), # G4
		(329.63, 0.2, 0.55)  # E4
	])
	_snd_victory = _create_sine_pcm([
		(523.25, 0.12, 0.5), # C5
		(659.25, 0.12, 0.5), # E5
		(783.99, 0.15, 0.55), # G5
		(1046.5, 0.4, 0.65)  # C6
	])

func _create_sine_pcm(notes: Array) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := 0
	for n in notes:
		total_samples += int(rate * n[1])

	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var byte_idx := 0
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var vol: float = n[2]
		var samples := int(rate * dur)

		for i in range(samples):
			var t := float(i) / float(rate)
			# Smooth linear decay envelope
			var env := maxf(0.0, 1.0 - (t / dur))
			# Soft sine wave
			var s := sin(TAU * freq * t) * env * vol
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(byte_idx, val)
			byte_idx += 2

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func play_click() -> void:
	if _player and _snd_click:
		_player.stream = _snd_click
		_player.play()

func play_countdown_beep(is_go: bool) -> void:
	if _player:
		_player.stream = _snd_beep_high if is_go else _snd_beep_low
		_player.play()

func play_lap_chime() -> void:
	if _player and _snd_lap:
		_player.stream = _snd_lap
		_player.play()

func play_wrong_way_alert() -> void:
	if _alert_player and _snd_wrong_way:
		if not _alert_player.playing:
			_alert_player.stream = _snd_wrong_way
			_alert_player.play()

func play_victory() -> void:
	if _player and _snd_victory:
		_player.stream = _snd_victory
		_player.play()
