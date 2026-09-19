extends Node
## Retro sound effects and background music, synthesized at startup so the project needs no audio files.
## Every button in the game clicks automatically. `M` mutes and unmutes.

enum Wave { SQUARE, TRIANGLE, SINE, NOISE }

const MIX_RATE := 22050
const VOICES := 8
const ATTACK := 0.004 ## Seconds.
const MUSIC_VOLUME_DB := -6.0
## Background loops, one per campaign level (cycling); the first also plays in the menus.
## Melodies have one bar per entry, notes are MIDI numbers (0 is a rest) with lengths in sixteenths.
## Bass holds each bar's root and plays `bass_steps` (semitones above it) on the eighths.
## Drums have one char per sixteenth: k kick, s snare, h hi-hat.
const SONGS := [
	{ # A minor, the original theme.
		"bpm": 132, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
		"melody": [
			[[69, 2], [72, 2], [76, 2], [81, 2], [79, 2], [76, 2], [72, 4]],
			[[77, 2], [76, 2], [72, 2], [69, 2], [72, 4], [69, 2], [65, 2]],
			[[76, 2], [79, 2], [84, 4], [83, 2], [79, 2], [76, 4]],
			[[74, 4], [71, 2], [67, 2], [74, 2], [71, 2], [67, 4]],
			[[81, 4], [79, 2], [76, 2], [72, 2], [76, 2], [69, 4]],
			[[77, 2], [81, 2], [79, 2], [77, 2], [76, 4], [72, 4]],
			[[74, 2], [79, 2], [83, 2], [86, 2], [83, 2], [79, 2], [74, 4]],
			[[76, 4], [80, 2], [83, 2], [76, 2], [74, 2], [71, 4]],
		],
		"bass": [45, 41, 48, 43, 45, 41, 43, 40],
		"bass_steps": [0, 12, 0, 12, 0, 12, 0, 12],
		"drums": "k.h.h.h.k.h.h.h.",
	},
	{ # C major, bouncy.
		"bpm": 150, "lead": Wave.SQUARE, "lead_volume": 0.05,
		"melody": [
			[[72, 2], [76, 2], [79, 2], [76, 2], [84, 4], [79, 4]],
			[[81, 2], [79, 2], [76, 2], [72, 2], [76, 4], [0, 2], [69, 2]],
			[[77, 2], [81, 2], [84, 2], [81, 2], [77, 4], [72, 4]],
			[[79, 3], [77, 1], [76, 2], [74, 2], [71, 4], [74, 4]],
			[[76, 2], [79, 2], [84, 2], [88, 2], [86, 2], [84, 2], [79, 4]],
			[[81, 2], [84, 2], [81, 2], [76, 2], [72, 4], [76, 4]],
			[[74, 2], [77, 2], [81, 2], [77, 2], [74, 2], [77, 2], [81, 4]],
			[[83, 4], [79, 2], [74, 2], [71, 2], [74, 2], [79, 4]],
		],
		"bass": [48, 45, 41, 43, 48, 45, 50, 43],
		"bass_steps": [0, 7, 12, 7, 0, 7, 12, 7],
		"drums": "k.h.s.h.k.k.s.h.",
	},
	{ # D minor, slow and mysterious.
		"bpm": 108, "lead": Wave.SINE, "lead_volume": 0.16,
		"melody": [
			[[74, 6], [77, 2], [81, 4], [79, 2], [77, 2]],
			[[74, 4], [70, 4], [74, 2], [77, 2], [82, 4]],
			[[79, 6], [76, 2], [72, 4], [76, 4]],
			[[81, 8], [0, 4], [76, 2], [73, 2]],
			[[74, 2], [77, 2], [81, 2], [86, 6], [84, 2], [81, 2]],
			[[82, 4], [81, 2], [79, 2], [77, 4], [74, 4]],
			[[79, 4], [82, 2], [79, 2], [74, 4], [70, 4]],
			[[73, 4], [76, 4], [81, 4], [0, 4]],
		],
		"bass": [38, 46, 48, 45, 38, 46, 43, 45],
		"bass_steps": [0, 0, 12, 0, 0, 7, 12, 7],
		"drums": "k.....h.k...h..h",
	},
	{ # E minor, fast and driving.
		"bpm": 160, "lead": Wave.SQUARE, "lead_volume": 0.05,
		"melody": [
			[[76, 1], [76, 1], [83, 2], [76, 1], [76, 1], [81, 2], [79, 2], [78, 2], [76, 4]],
			[[79, 2], [84, 2], [83, 2], [79, 2], [76, 4], [72, 4]],
			[[74, 1], [74, 1], [81, 2], [74, 1], [74, 1], [79, 2], [78, 2], [76, 2], [74, 4]],
			[[75, 4], [78, 4], [83, 4], [81, 2], [78, 2]],
			[[88, 4], [86, 2], [83, 2], [79, 2], [83, 2], [76, 4]],
			[[84, 4], [83, 2], [79, 2], [76, 4], [79, 4]],
			[[81, 2], [84, 2], [88, 2], [84, 2], [81, 2], [79, 2], [76, 4]],
			[[78, 2], [75, 2], [71, 2], [75, 2], [78, 4], [83, 4]],
		],
		"bass": [40, 48, 50, 47, 40, 48, 45, 47],
		"bass_steps": [0, 12, 0, 12, 0, 12, 0, 12],
		"drums": "k.h.s.h.k.h.s.hh",
	},
	{ # F major, playful.
		"bpm": 120, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
		"melody": [
			[[72, 2], [77, 2], [81, 2], [84, 6], [81, 2], [77, 2]],
			[[86, 4], [84, 2], [81, 2], [77, 4], [74, 4]],
			[[82, 2], [81, 2], [79, 2], [77, 2], [74, 4], [77, 4]],
			[[79, 6], [76, 2], [72, 8]],
			[[81, 2], [84, 2], [89, 4], [88, 2], [86, 2], [84, 4]],
			[[85, 4], [81, 4], [76, 4], [73, 4]],
			[[82, 2], [86, 2], [82, 2], [79, 2], [74, 4], [79, 4]],
			[[76, 4], [79, 4], [84, 4], [0, 4]],
		],
		"bass": [41, 38, 46, 48, 41, 45, 43, 48],
		"bass_steps": [0, 7, 12, 7, 0, 7, 12, 7],
		"drums": "k...s..hk.k.s...",
	},
]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _songs := {} ## Composed streams by index, built the first time each song plays.
var _song := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams = {
		"move": _build(_tone(Wave.SINE, 480, 300, 0.08, 0.16)),
		"bump": _build(_mix(_tone(Wave.TRIANGLE, 150, 50, 0.1, 0.45), _tone(Wave.NOISE, 600, 200, 0.04, 0.05))),
		"key": _build(_notes(Wave.TRIANGLE, [784, 988, 1175], 0.07, 0.28)),
		"door": _build(_tone(Wave.NOISE, 1500, 1500, 0.025, 0.08) + _tone(Wave.TRIANGLE, 200, 500, 0.3, 0.35)),
		"portal": _build(_tone(Wave.SINE, 300, 900, 0.14, 0.28) + _tone(Wave.SINE, 900, 400, 0.14, 0.24)),
		"death": _build(_tone(Wave.TRIANGLE, 700, 100, 0.6, 0.4)),
		"complete": _build(_notes(Wave.TRIANGLE, [523, 659, 784], 0.08, 0.3) + _tone(Wave.TRIANGLE, 1047, 1047, 0.35, 0.3)),
		"victory": _build(_notes(Wave.TRIANGLE, [392, 523, 659, 784, 659, 784], 0.11, 0.3) + _tone(Wave.TRIANGLE, 1047, 1047, 0.55, 0.3)),
		"click": _build(_tone(Wave.SINE, 600, 500, 0.04, 0.15)),
	}
	get_tree().node_added.connect(_on_node_added)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	play_song(0)


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


## Switches the background loop; the index wraps around, and the current song keeps playing untouched.
func play_song(index: int) -> void:
	index = posmod(index, SONGS.size())
	if index == _song:
		return
	_song = index
	if not _songs.has(index):
		var stream := _build(_compose_music(SONGS[index]))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2
		_songs[index] = stream
	_music_player.stream = _songs[index]
	_music_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))


## Chiptune loop: lead melody, triangle bass on the eighths, kick and snare with noise hi-hats.
func _compose_music(song: Dictionary) -> PackedFloat32Array:
	var step: float = 15.0 / song.bpm ## A sixteenth note, in seconds.
	var melody: Array = song.melody
	var drums: String = song.drums
	var bar_length := int(step * 16 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(bar_length * melody.size())
	for bar in melody.size():
		var start := bar * bar_length
		var offset := 0
		for note: Array in melody[bar]:
			if note[0] > 0:
				var hz := _midi_to_hz(note[0])
				_add(samples, _tone(song.lead, hz, hz, note[1] * step, song.lead_volume), start + int(offset * step * MIX_RATE))
			offset += note[1]
		for eighth in 8:
			var bass := _midi_to_hz(song.bass[bar] + song.bass_steps[eighth])
			_add(samples, _tone(Wave.TRIANGLE, bass, bass, 2 * step, 0.22), start + int(eighth * 2 * step * MIX_RATE))
		for sixteenth in 16:
			var at := start + int(sixteenth * step * MIX_RATE)
			match drums[sixteenth]:
				"k":
					_add(samples, _tone(Wave.TRIANGLE, 150, 40, 0.12, 0.3), at)
				"s":
					_add(samples, _tone(Wave.NOISE, 3000, 3000, 0.09, 0.07), at)
				"h":
					_add(samples, _tone(Wave.NOISE, 6000, 6000, 0.025, 0.025), at)
	return samples


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
