extends Node
## Retro sound effects and background music, synthesized at startup so the project needs no audio files.
## Every button in the game clicks automatically. `M` mutes and unmutes.

enum Wave { SQUARE, TRIANGLE, SINE, NOISE }

const MIX_RATE := 22050
const VOICES := 8
const ATTACK := 0.004 ## Seconds.
const MUSIC_VOLUME_DB := -6.0
const BEAT := 60.0 / 132.0 ## Seconds per beat.
const STEP := BEAT / 4.0 ## A sixteenth note.
## Background loop in A minor, one bar per entry. Notes are MIDI numbers with lengths in sixteenths.
const MELODY := [
	[[69, 2], [72, 2], [76, 2], [81, 2], [79, 2], [76, 2], [72, 4]],
	[[77, 2], [76, 2], [72, 2], [69, 2], [72, 4], [69, 2], [65, 2]],
	[[76, 2], [79, 2], [84, 4], [83, 2], [79, 2], [76, 4]],
	[[74, 4], [71, 2], [67, 2], [74, 2], [71, 2], [67, 4]],
	[[81, 4], [79, 2], [76, 2], [72, 2], [76, 2], [69, 4]],
	[[77, 2], [81, 2], [79, 2], [77, 2], [76, 4], [72, 4]],
	[[74, 2], [79, 2], [83, 2], [86, 2], [83, 2], [79, 2], [74, 4]],
	[[76, 4], [80, 2], [83, 2], [76, 2], [74, 2], [71, 4]],
]
const BASS := [45, 41, 48, 43, 45, 41, 43, 40] ## Root of each bar.

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams = {
		"move": _build(_tone(Wave.SQUARE, 260, 520, 0.06, 0.12)),
		"bump": _build(_mix(_tone(Wave.TRIANGLE, 160, 50, 0.1, 0.5), _tone(Wave.NOISE, 1200, 300, 0.05, 0.15))),
		"key": _build(_notes(Wave.SQUARE, [988, 1319, 1976], 0.06, 0.18)),
		"door": _build(_tone(Wave.NOISE, 3000, 3000, 0.03, 0.25) + _tone(Wave.TRIANGLE, 180, 720, 0.3, 0.45)),
		"portal": _build(_tone(Wave.SINE, 300, 1400, 0.14, 0.35) + _tone(Wave.SINE, 1400, 500, 0.14, 0.3)),
		"death": _build(_mix(_tone(Wave.SQUARE, 900, 90, 0.55, 0.2), _tone(Wave.NOISE, 900, 100, 0.55, 0.08))),
		"complete": _build(_notes(Wave.SQUARE, [523, 659, 784], 0.08, 0.18) + _tone(Wave.SQUARE, 1047, 1047, 0.3, 0.18)),
		"victory": _build(_notes(Wave.SQUARE, [392, 523, 659, 784, 659, 784], 0.11, 0.18) + _tone(Wave.SQUARE, 1047, 1047, 0.5, 0.18)),
		"click": _build(_tone(Wave.SQUARE, 700, 900, 0.035, 0.12)),
	}
	get_tree().node_added.connect(_on_node_added)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _build(_compose_music())
	_music_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream.loop_end = _music_player.stream.data.size() / 2
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	_music_player.play()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_M:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		get_viewport().set_input_as_handled()


## Plays a sound by name. Variation randomizes the pitch a little, so repeated sounds don't tire.
func play(sound: String, pitch_variation := 0.0) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))


## Chiptune loop: square lead, triangle bass jumping octaves, kick on the beats and noise hi-hats.
func _compose_music() -> PackedFloat32Array:
	var bar_length := int(STEP * 16 * MIX_RATE)
	var song := PackedFloat32Array()
	song.resize(bar_length * MELODY.size())
	for bar in MELODY.size():
		var start := bar * bar_length
		var offset := 0
		for note: Array in MELODY[bar]:
			var hz := _midi_to_hz(note[0])
			_add(song, _tone(Wave.SQUARE, hz, hz, note[1] * STEP, 0.07), start + int(offset * STEP * MIX_RATE))
			offset += note[1]
		for eighth in 8:
			var at := start + int(eighth * 2 * STEP * MIX_RATE)
			var bass := _midi_to_hz(BASS[bar] + (12 if eighth % 2 else 0))
			_add(song, _tone(Wave.TRIANGLE, bass, bass, 2 * STEP, 0.22), at)
			if eighth % 4 == 0:
				_add(song, _tone(Wave.TRIANGLE, 150, 40, 0.12, 0.3), at)
			else:
				_add(song, _tone(Wave.NOISE, 8000, 8000, 0.03, 0.04), at)
	return song


func _midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## Mixes samples into the buffer starting at the offset, dropping what doesn't fit.
func _add(buffer: PackedFloat32Array, samples: PackedFloat32Array, offset: int) -> void:
	for i in mini(samples.size(), buffer.size() - offset):
		buffer[offset + i] += samples[i]


## A single note that slides from one frequency to another and fades out.
func _tone(wave: Wave, from_hz: float, to_hz: float, duration: float, volume: float) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var noise := 0.0
	for i in count:
		var t := float(i) / count
		var previous := phase
		phase = fmod(phase + lerpf(from_hz, to_hz, t) / MIX_RATE, 1.0)
		var value: float
		match wave:
			Wave.SQUARE:
				value = 1.0 if phase < 0.5 else -1.0
			Wave.TRIANGLE:
				value = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SINE:
				value = sin(phase * TAU)
			Wave.NOISE:
				# Sample and hold: the frequency sets how often a new random value is drawn.
				if phase < previous:
					noise = randf_range(-1.0, 1.0)
				value = noise
		var attack := minf(float(i) / (ATTACK * MIX_RATE), 1.0)
		samples[i] = value * volume * attack * (1.0 - t)
	return samples


func _notes(wave: Wave, frequencies: Array, duration: float, volume: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for frequency: float in frequencies:
		samples.append_array(_tone(wave, frequency, frequency, duration, volume))
	return samples


## Plays two sounds at the same time.
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var samples := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var shorter := b if a.size() >= b.size() else a
	for i in shorter.size():
		samples[i] += shorter[i]
	return samples


func _build(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
