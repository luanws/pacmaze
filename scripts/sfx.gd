extends Node
## Retro sound effects and background music, synthesized at startup so the project needs no audio files.
## Every button in the game clicks automatically. `M` mutes and unmutes.

enum Wave { PULSE, TRIANGLE, SINE, NOISE }

const MIX_RATE := 22050
const VOICES := 8
const ATTACK := 0.004 ## Seconds.
const MUSIC_VOLUME_DB := -6.0
const COMPOSE_BUDGET_USEC := 2500 ## Per frame composing the song after this one, so the game doesn't hitch.
const COMPOSE_RUSH_USEC := 9000 ## Per frame while the song that should be playing isn't ready yet.
const ENCODE_CHUNK := 4096 ## Samples converted to PCM at a time once a song is composed.
## Background loops, one per campaign level (they wrap around) so the music never changes mid-level.
## `root` is the key's pitch class (C is 0) and `minor` its mode; together they pick the harmony
## the arpeggio and the second voice are built from.
## Melodies have one bar per entry, notes are MIDI numbers (0 is a rest) with lengths in sixteenths.
## Bass holds each bar's root and plays `bass_steps` (semitones above it) on the eighths.
## Drums have one char per sixteenth: k kick, s snare, h hi-hat, o open hi-hat.
const SONGS := [
	{ # A minor, the original theme.
		"bpm": 132, "root": 9, "minor": true,
		"lead": Wave.TRIANGLE,
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
		"bpm": 150, "root": 0, "minor": false,
		"lead": Wave.PULSE, "duty": 0.25,
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
		"bpm": 108, "root": 2, "minor": true,
		"lead": Wave.SINE,
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
		"bpm": 160, "root": 4, "minor": true,
		"lead": Wave.PULSE, "duty": 0.125,
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
		"bpm": 120, "root": 5, "minor": false,
		"lead": Wave.TRIANGLE,
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
	{ # G major, marching.
		"bpm": 140, "root": 7, "minor": false,
		"lead": Wave.PULSE, "duty": 0.25,
		"melody": [
			[[79, 2], [74, 2], [71, 2], [74, 2], [79, 4], [83, 4]],
			[[84, 2], [83, 2], [81, 2], [79, 2], [76, 4], [72, 4]],
			[[74, 2], [78, 2], [81, 2], [86, 2], [84, 2], [81, 2], [78, 4]],
			[[79, 6], [0, 2], [71, 2], [74, 2], [79, 4]],
			[[76, 2], [79, 2], [83, 2], [88, 2], [86, 2], [83, 2], [79, 4]],
			[[81, 3], [79, 1], [76, 2], [72, 2], [76, 4], [79, 4]],
			[[78, 2], [81, 2], [78, 2], [74, 2], [81, 2], [78, 2], [74, 2], [72, 2]],
			[[71, 4], [74, 4], [79, 8]],
		],
		"bass": [43, 48, 50, 43, 40, 48, 50, 43],
		"bass_steps": [0, 7, 12, 7, 0, 7, 12, 7],
		"drums": "k.h.s.hkk.h.s.h.",
	},
	{ # A minor, a slow ghostly lullaby.
		"bpm": 96, "root": 9, "minor": true,
		"lead": Wave.SINE,
		"melody": [
			[[76, 4], [72, 4], [69, 4], [72, 4]],
			[[77, 6], [76, 2], [72, 8]],
			[[74, 4], [77, 4], [81, 6], [79, 2]],
			[[80, 8], [76, 4], [71, 4]],
			[[81, 4], [84, 4], [83, 2], [81, 2], [76, 4]],
			[[77, 4], [81, 4], [84, 4], [81, 4]],
			[[83, 4], [80, 4], [76, 2], [74, 2], [71, 4]],
			[[76, 8], [0, 4], [71, 2], [68, 2]],
		],
		"bass": [45, 41, 38, 40, 45, 41, 40, 40],
		"bass_steps": [0, 0, 7, 0, 0, 0, 7, 0],
		"drums": "k.......h.......",
	},
	{ # C minor, racing arpeggios.
		"bpm": 170, "root": 0, "minor": true,
		"lead": Wave.PULSE, "duty": 0.125,
		"melody": [
			[[72, 1], [75, 1], [79, 1], [84, 1], [79, 1], [75, 1], [72, 2], [84, 2], [82, 2], [79, 4]],
			[[80, 2], [84, 2], [87, 2], [84, 2], [80, 4], [75, 4]],
			[[70, 1], [74, 1], [77, 1], [82, 1], [77, 1], [74, 1], [70, 2], [82, 2], [79, 2], [77, 4]],
			[[79, 4], [83, 4], [86, 2], [83, 2], [79, 4]],
			[[84, 2], [82, 2], [79, 2], [75, 2], [79, 2], [84, 2], [87, 4]],
			[[84, 4], [80, 2], [77, 2], [80, 4], [84, 4]],
			[[82, 2], [86, 2], [82, 2], [77, 2], [74, 2], [77, 2], [82, 4]],
			[[83, 4], [79, 2], [74, 2], [71, 4], [74, 4]],
		],
		"bass": [48, 44, 46, 43, 48, 44, 46, 43],
		"bass_steps": [0, 12, 0, 12, 0, 12, 0, 12],
		"drums": "k.hsk.h.k.hsk.hs",
	},
	{ # B-flat major, funky.
		"bpm": 116, "root": 10, "minor": false,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[70, 2], [74, 2], [77, 3], [74, 1], [82, 4], [0, 2], [77, 2]],
			[[79, 2], [82, 2], [79, 2], [74, 2], [70, 4], [74, 4]],
			[[75, 2], [79, 2], [82, 2], [87, 4], [86, 2], [84, 4]],
			[[84, 3], [81, 1], [77, 4], [72, 4], [77, 4]],
			[[82, 2], [86, 2], [89, 4], [86, 2], [82, 2], [77, 4]],
			[[79, 4], [82, 2], [86, 2], [84, 4], [82, 4]],
			[[79, 2], [75, 2], [79, 2], [82, 2], [87, 4], [84, 4]],
			[[81, 4], [77, 4], [72, 2], [74, 2], [77, 4]],
		],
		"bass": [46, 43, 51, 41, 46, 43, 51, 41],
		"bass_steps": [0, 0, 12, 0, 0, 7, 12, 7],
		"drums": "k..hs.h.k.khs..h",
	},
	{ # D major, heroic.
		"bpm": 144, "root": 2, "minor": false,
		"lead": Wave.PULSE, "duty": 0.25,
		"melody": [
			[[74, 4], [78, 2], [81, 2], [86, 6], [81, 2]],
			[[85, 4], [81, 2], [76, 2], [81, 4], [73, 4]],
			[[83, 2], [86, 2], [90, 4], [86, 2], [83, 2], [78, 4]],
			[[79, 4], [83, 2], [86, 2], [83, 4], [79, 4]],
			[[81, 2], [78, 2], [74, 2], [78, 2], [81, 2], [86, 2], [85, 2], [86, 2]],
			[[88, 4], [85, 2], [81, 2], [76, 4], [81, 4]],
			[[83, 2], [79, 2], [74, 2], [79, 2], [83, 2], [86, 2], [83, 4]],
			[[81, 4], [85, 4], [88, 4], [0, 4]],
		],
		"bass": [50, 45, 47, 43, 50, 45, 43, 45],
		"bass_steps": [0, 7, 12, 7, 0, 7, 12, 7],
		"drums": "k.hhs.h.k.hhs.hh",
	},
	{ # F-sharp minor, dreamy.
		"bpm": 100, "root": 6, "minor": true,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[78, 8], [81, 4], [85, 4]],
			[[86, 6], [85, 2], [81, 8]],
			[[83, 4], [80, 4], [76, 4], [80, 4]],
			[[80, 8], [77, 4], [73, 4]],
			[[81, 4], [85, 4], [90, 6], [88, 2]],
			[[86, 4], [81, 4], [78, 4], [81, 4]],
			[[83, 6], [80, 2], [76, 4], [83, 4]],
			[[85, 4], [80, 4], [77, 8]],
		],
		"bass": [42, 38, 40, 37, 42, 38, 40, 37],
		"bass_steps": [0, 7, 12, 19, 12, 7, 12, 7],
		"drums": "k.......k...h...",
	},
	{ # G minor, a frantic chase.
		"bpm": 176, "root": 7, "minor": true,
		"lead": Wave.PULSE, "duty": 0.125,
		"melody": [
			[[79, 1], [79, 1], [0, 1], [79, 1], [82, 2], [79, 2], [86, 4], [82, 4]],
			[[87, 2], [86, 2], [82, 2], [79, 2], [75, 4], [79, 4]],
			[[77, 1], [77, 1], [0, 1], [77, 1], [81, 2], [77, 2], [84, 4], [81, 4]],
			[[78, 2], [81, 2], [86, 2], [81, 2], [78, 4], [74, 4]],
			[[91, 4], [89, 2], [86, 2], [82, 2], [86, 2], [79, 4]],
			[[87, 4], [82, 2], [79, 2], [75, 2], [79, 2], [82, 4]],
			[[84, 2], [81, 2], [77, 2], [81, 2], [84, 2], [89, 2], [87, 4]],
			[[86, 4], [81, 2], [78, 2], [74, 4], [78, 4]],
		],
		"bass": [43, 39, 41, 38, 43, 39, 41, 38],
		"bass_steps": [0, 12, 0, 12, 0, 12, 0, 12],
		"drums": "k.h.s.hkk.h.s.hs",
	},
	{ # E major, cheerful.
		"bpm": 128, "root": 4, "minor": false,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[76, 2], [80, 2], [83, 4], [80, 2], [76, 2], [71, 4]],
			[[78, 2], [83, 2], [87, 4], [85, 2], [83, 2], [78, 4]],
			[[80, 2], [85, 2], [88, 4], [87, 2], [85, 2], [80, 4]],
			[[81, 4], [85, 4], [88, 2], [85, 2], [81, 4]],
			[[88, 4], [87, 2], [88, 2], [83, 4], [80, 4]],
			[[87, 4], [83, 2], [78, 2], [75, 4], [78, 4]],
			[[81, 2], [85, 2], [88, 2], [85, 2], [81, 2], [78, 2], [76, 4]],
			[[75, 4], [78, 4], [83, 4], [0, 4]],
		],
		"bass": [40, 47, 49, 45, 40, 47, 45, 47],
		"bass_steps": [0, 12, 7, 12, 0, 12, 7, 12],
		"drums": "k.h.s.h.k.hks.h.",
	},
	{ # A minor, bluesy with a walking bass.
		"bpm": 112, "root": 9, "minor": true,
		"lead": Wave.PULSE, "duty": 0.25,
		"melody": [
			[[69, 2], [72, 2], [74, 1], [75, 1], [76, 2], [79, 4], [76, 4]],
			[[77, 2], [74, 2], [72, 2], [69, 2], [74, 4], [0, 4]],
			[[81, 2], [79, 2], [76, 2], [75, 1], [74, 1], [72, 4], [69, 4]],
			[[68, 4], [71, 4], [74, 4], [76, 4]],
			[[84, 3], [81, 1], [79, 2], [76, 2], [79, 4], [81, 4]],
			[[77, 2], [81, 2], [84, 2], [81, 2], [77, 4], [74, 4]],
			[[77, 4], [72, 2], [69, 2], [65, 4], [69, 4]],
			[[68, 2], [71, 2], [74, 2], [76, 2], [80, 4], [83, 4]],
		],
		"bass": [45, 50, 45, 40, 45, 50, 41, 40],
		"bass_steps": [0, 3, 7, 10, 12, 10, 7, 3],
		"drums": "k..h..s.k.hh..s.",
	},
	{ # C major, gentle.
		"bpm": 90, "root": 0, "minor": false,
		"lead": Wave.SINE,
		"melody": [
			[[76, 4], [79, 4], [84, 8]],
			[[81, 4], [76, 4], [72, 8]],
			[[77, 4], [81, 4], [84, 4], [81, 4]],
			[[79, 8], [74, 4], [71, 4]],
			[[72, 4], [76, 4], [79, 4], [84, 4]],
			[[83, 6], [79, 2], [76, 8]],
			[[77, 4], [81, 4], [79, 4], [77, 4]],
			[[74, 8], [71, 4], [74, 4]],
		],
		"bass": [48, 45, 41, 43, 48, 40, 41, 43],
		"bass_steps": [0, 7, 12, 7, 0, 7, 12, 7],
		"drums": "k...h...k...h...",
	},
	{ # D minor, a castle descent.
		"bpm": 138, "root": 2, "minor": true,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[74, 2], [77, 2], [81, 2], [77, 2], [86, 4], [81, 4]],
			[[84, 2], [79, 2], [76, 2], [79, 2], [84, 4], [88, 4]],
			[[86, 2], [82, 2], [77, 2], [82, 2], [86, 4], [89, 4]],
			[[88, 4], [85, 4], [81, 4], [76, 4]],
			[[86, 3], [84, 1], [82, 2], [81, 2], [77, 4], [74, 4]],
			[[76, 2], [79, 2], [84, 4], [82, 2], [79, 2], [76, 4]],
			[[77, 2], [82, 2], [86, 4], [84, 2], [82, 2], [77, 4]],
			[[73, 4], [76, 4], [81, 4], [85, 4]],
		],
		"bass": [50, 48, 46, 45, 50, 48, 46, 45],
		"bass_steps": [0, 12, 0, 12, 0, 12, 0, 12],
		"drums": "k.h.k.s.k.h.k.s.",
	},
	{ # E-flat major, groovy.
		"bpm": 124, "root": 3, "minor": false,
		"lead": Wave.PULSE, "duty": 0.25,
		"melody": [
			[[75, 2], [79, 2], [82, 2], [87, 2], [86, 2], [82, 2], [79, 4]],
			[[84, 4], [79, 2], [75, 2], [72, 4], [75, 4]],
			[[80, 2], [84, 2], [87, 2], [84, 2], [80, 4], [77, 4]],
			[[82, 6], [79, 2], [77, 4], [74, 4]],
			[[87, 4], [91, 4], [89, 2], [87, 2], [82, 4]],
			[[84, 2], [87, 2], [84, 2], [79, 2], [75, 4], [79, 4]],
			[[80, 4], [84, 2], [80, 2], [77, 2], [80, 2], [84, 4]],
			[[82, 4], [86, 4], [89, 4], [0, 4]],
		],
		"bass": [39, 48, 44, 46, 39, 48, 44, 46],
		"bass_steps": [0, 12, 7, 12, 0, 12, 7, 12],
		"drums": "k..sk.h.k..sk.hh",
	},
	{ # B minor, tense.
		"bpm": 152, "root": 11, "minor": true,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[83, 2], [78, 2], [74, 2], [78, 2], [83, 2], [86, 2], [83, 4]],
			[[79, 2], [83, 2], [86, 2], [83, 2], [91, 4], [86, 4]],
			[[85, 2], [81, 2], [76, 2], [81, 2], [85, 2], [88, 2], [85, 4]],
			[[82, 4], [78, 2], [73, 2], [78, 4], [82, 4]],
			[[86, 4], [83, 2], [86, 2], [90, 4], [86, 4]],
			[[91, 2], [90, 2], [88, 2], [86, 2], [83, 4], [79, 4]],
			[[81, 2], [85, 2], [88, 2], [85, 2], [81, 4], [76, 4]],
			[[78, 4], [82, 4], [85, 4], [78, 4]],
		],
		"bass": [47, 43, 45, 42, 47, 43, 45, 42],
		"bass_steps": [0, 0, 12, 0, 0, 12, 0, 12],
		"drums": "k.h.h.s.k.hkh.s.",
	},
	{ # F major, sunny.
		"bpm": 136, "root": 5, "minor": false,
		"lead": Wave.PULSE, "duty": 0.25,
		"melody": [
			[[77, 2], [81, 2], [84, 2], [81, 2], [77, 2], [81, 2], [84, 2], [89, 2]],
			[[86, 4], [81, 4], [77, 4], [74, 4]],
			[[82, 2], [86, 2], [89, 2], [86, 2], [82, 2], [77, 2], [74, 4]],
			[[76, 4], [79, 4], [84, 4], [82, 4]],
			[[81, 4], [84, 2], [81, 2], [77, 4], [72, 4]],
			[[76, 2], [81, 2], [84, 2], [88, 2], [84, 4], [81, 4]],
			[[86, 4], [82, 2], [77, 2], [74, 2], [77, 2], [82, 4]],
			[[79, 2], [76, 2], [72, 2], [76, 2], [79, 4], [0, 4]],
		],
		"bass": [41, 38, 46, 48, 41, 45, 46, 48],
		"bass_steps": [0, 12, 7, 12, 0, 12, 7, 12],
		"drums": "k.h.s.hhk.h.s.h.",
	},
	{ # A major, a bright finale.
		"bpm": 158, "root": 9, "minor": false,
		"lead": Wave.TRIANGLE,
		"melody": [
			[[81, 2], [85, 2], [88, 2], [93, 2], [88, 2], [85, 2], [81, 4]],
			[[78, 2], [81, 2], [85, 2], [90, 2], [88, 4], [85, 4]],
			[[86, 4], [81, 2], [78, 2], [74, 4], [78, 4]],
			[[76, 2], [80, 2], [83, 2], [88, 2], [86, 4], [83, 4]],
			[[85, 3], [83, 1], [81, 2], [85, 2], [88, 4], [93, 4]],
			[[92, 4], [88, 2], [85, 2], [80, 4], [85, 4]],
			[[86, 2], [90, 2], [86, 2], [81, 2], [78, 4], [74, 4]],
			[[76, 4], [80, 4], [83, 4], [88, 4]],
		],
		"bass": [45, 42, 38, 40, 45, 37, 38, 40],
		"bass_steps": [0, 12, 7, 12, 0, 12, 7, 12],
		"drums": "k.h.s.h.kkh.s.hs",
	},
]


## Two passes over the melody make one loop, around half a minute long: the first plays it bare over
## an eighth-note arpeggio, the second answers with a harmony voice, sixteenth arpeggios and a
## busier beat, and its last bar turns into a fill that lands back on the top of the loop.
const PASSES := 2
const SONG_CACHE := 3 ## Composed songs kept in memory; each one is a couple of megabytes of PCM.
const LEAD_VOLUME := 0.12
const HARMONY_VOLUME := 0.05
const ARP_VOLUME := 0.045
const BASS_VOLUME := 0.2
## Pulse waves are thin and sines are fat; this evens the leads out so no song jumps in level.
const WAVE_GAIN := {Wave.PULSE: 0.42, Wave.TRIANGLE: 1.0, Wave.SINE: 1.33, Wave.NOISE: 1.0}
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const MINOR := [0, 2, 3, 5, 7, 8, 10]
const DRUM_FILL := "k...s...s.s.ssso" ## Closes the loop, so coming back to the top is announced.
## Chord tones the arpeggio walks, up and back down. Six steps against a bar of sixteen keeps it
## from landing on the same note every beat.
const ARP_STEPS := [0, 1, 2, 3, 2, 1]
const VIBRATO_HZ := 5.5
const VIBRATO_DEPTH := 0.007
const VIBRATO_DELAY := 0.15 ## Seconds the vibrato takes to reach full depth; short notes stay steady.
## Attack, decay and release in seconds, sustain as a fraction of the peak. A decay of zero stretches
## across the whole note, which is the plain fade the sound effects and the drums are made of.
const ENVELOPES := {
	"fade": {"attack": ATTACK, "decay": 0.0, "sustain": 0.0, "release": 0.0},
	"lead": {"attack": 0.008, "decay": 0.09, "sustain": 0.72, "release": 0.09},
	"harmony": {"attack": 0.025, "decay": 0.09, "sustain": 0.6, "release": 0.11},
	"bass": {"attack": 0.003, "decay": 0.07, "sustain": 0.62, "release": 0.05},
	"arp": {"attack": 0.002, "decay": 0.05, "sustain": 0.0, "release": 0.02},
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _songs := {} ## Composed streams by song index.
var _cached: Array[int] = [] ## What `_songs` holds, least recently started first.
var _composing: Array[Dictionary] = [] ## Songs being composed a little each frame: index, notes and progress.
var _song := -1 ## The song playing, or the one being composed before it starts.


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		get_viewport().set_input_as_handled()


## Plays a sound by name. Variation randomizes the pitch a little, so repeated sounds don't tire.
func play(sound: String, pitch_variation := 0.0) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## Switches the background loop, wrapping the index around. Asking for the song already playing
## does nothing, so walking from the menu into a level that shares it doesn't restart the music.
## Songs are composed a few milliseconds per frame and start once they are ready, so nothing
## freezes; the one after this is composed too, ready for whenever the next level begins.
func play_song(index: int) -> void:
	index = posmod(index, SONGS.size())
	if index == _song:
		return
	_song = index
	if _songs.has(index):
		_start(index)
	else:
		_compose(index, true)
	_compose(posmod(index + 1, SONGS.size()))


func _process(_delta: float) -> void:
	var budget := COMPOSE_BUDGET_USEC if _songs.has(_song) else COMPOSE_RUSH_USEC
	var deadline := Time.get_ticks_usec() + budget
	while not _composing.is_empty() and Time.get_ticks_usec() < deadline:
		var job := _composing[0]
		if job.next < job.notes.size():
			var note: Dictionary = job.notes[job.next]
			_add(job.samples, _voice(job.voices, note), note.at)
			job.next += 1
			continue
		var end := mini(job.encoded + ENCODE_CHUNK, job.samples.size())
		_encode(job.samples, job.data, job.encoded, end)
		job.encoded = end
		if end == job.samples.size():
			_remember(job.index, _loop(_stream(job.data)))
			_composing.pop_front()
			if job.index == _song:
				_start(job.index)


func _start(index: int) -> void:
	_music_player.stream = _songs[index]
	_music_player.play()
	_cached.erase(index)
	_cached.append(index)


## Queues a song to be composed in the background, unless it is ready already. `urgent` puts it at
## the head of the queue, for a song the game is waiting on: whoever is ahead of it can wait.
func _compose(index: int, urgent := false) -> void:
	if _songs.has(index):
		return
	for job: Dictionary in _composing:
		if job.index == index:
			if urgent:
				_composing.erase(job)
				_composing.push_front(job)
			return
	var notes := _music_notes(SONGS[index])
	var samples := PackedFloat32Array()
	samples.resize(notes.pop_front())
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var job := {
		"index": index, "samples": samples, "notes": notes, "next": 0,
		"data": data, "encoded": 0, "voices": {},
	}
	if urgent:
		_composing.push_front(job)
	else:
		_composing.append(job)


## Holds on to the most recent songs and drops the rest, so a long session doesn't keep every loop.
func _remember(index: int, stream: AudioStreamWAV) -> void:
	_songs[index] = stream
	_cached.erase(index)
	_cached.append(index)
	while _cached.size() > SONG_CACHE:
		var oldest: int = _cached.pop_front()
		if oldest == _song:
			_cached.append(oldest) # Never drop what is playing.
			continue
		_songs.erase(oldest)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))


## Builds one loop of a song: the loop's length in samples, followed by every note in it.
func _music_notes(song: Dictionary) -> Array:
	var step: float = 15.0 / song.bpm ## A sixteenth note, in seconds.
	var melody: Array = song.melody
	var bars: int = melody.size()
	var bar_length := int(step * 16 * MIX_RATE)
	var scale: Array = MINOR if song.minor else MAJOR
	var notes: Array = [bar_length * bars * PASSES]
	for pass_index in PASSES:
		var full := pass_index > 0 ## The second pass is the loud one.
		for bar in bars:
			var start := (pass_index * bars + bar) * bar_length
			_write_lead(notes, song, scale, melody[bar], start, step, full)
			_write_arpeggio(notes, _chord(song.bass[bar], song.root, scale), start, step, full)
			_write_bass(notes, song, bar, start, step)
			var closing := full and bar == bars - 1
			_write_drums(notes, DRUM_FILL if closing else song.drums, start, step, full)
	return notes


## The melody, doubled a diatonic third below once the arrangement fills out.
func _write_lead(notes: Array, song: Dictionary, scale: Array, bar: Array, start: int, step: float, full: bool) -> void:
	var wave: Wave = song.lead
	var duty: float = song.get("duty", 0.5)
	var offset := 0
	for note: Array in bar:
		if note[0] > 0:
			var at := start + int(offset * step * MIX_RATE)
			var seconds: float = note[1] * step
			notes.append(_note(wave, _midi_to_hz(note[0]), seconds, LEAD_VOLUME * WAVE_GAIN[wave], "lead", at, duty, VIBRATO_DEPTH))
			if full:
				var below := _harmony(note[0], song.root, scale)
				notes.append(_note(Wave.TRIANGLE, _midi_to_hz(below), seconds, HARMONY_VOLUME, "harmony", at))
		offset += note[1]


## The bar's chord, walked one tone at a time: eighths under the bare melody, sixteenths under
## the full one, where it drops back a little to leave the harmony voice room.
func _write_arpeggio(notes: Array, chord: Array, start: int, step: float, full: bool) -> void:
	var every := 1 if full else 2
	var volume := ARP_VOLUME * (0.8 if full else 1.0)
	for i in 16 / every:
		var at := start + int(i * every * step * MIX_RATE)
		var midi: int = chord[ARP_STEPS[i % ARP_STEPS.size()]]
		notes.append(_note(Wave.PULSE, _midi_to_hz(midi), step * every, volume, "arp", at, 0.25))


func _write_bass(notes: Array, song: Dictionary, bar: int, start: int, step: float) -> void:
	for eighth in 8:
		var hz := _midi_to_hz(song.bass[bar] + song.bass_steps[eighth])
		notes.append(_note(Wave.TRIANGLE, hz, 2 * step, BASS_VOLUME, "bass", start + int(eighth * 2 * step * MIX_RATE)))


## The beat. On the full pass the gaps between hits pick up quiet off-beat hi-hats.
func _write_drums(notes: Array, pattern: String, start: int, step: float, full: bool) -> void:
	for sixteenth in 16:
		var at := start + int(sixteenth * step * MIX_RATE)
		var hit := pattern[sixteenth]
		if hit == "." and full and sixteenth % 2 == 1:
			hit = "g"
		match hit:
			"k":
				notes.append(_note(Wave.TRIANGLE, 150.0, 0.13, 0.3, "fade", at, 0.5, 0.0, 42.0))
			"s":
				notes.append(_note(Wave.NOISE, 3000.0, 0.09, 0.07, "fade", at))
				notes.append(_note(Wave.TRIANGLE, 220.0, 0.07, 0.07, "fade", at, 0.5, 0.0, 170.0))
			"h":
				notes.append(_note(Wave.NOISE, 6000.0, 0.025, 0.025, "fade", at))
			"o":
				notes.append(_note(Wave.NOISE, 5200.0, 0.11, 0.03, "fade", at))
			"g":
				notes.append(_note(Wave.NOISE, 6000.0, 0.02, 0.011, "fade", at))


## One note for the synthesizer. `envelope` names an entry in ENVELOPES, `duty` only matters to
## pulse waves, `vibrato` is a fraction of the frequency and `bend` the frequency the note slides
## to, zero holding it steady. `at` is the sample of the loop the note starts on.
func _note(wave: Wave, hz: float, seconds: float, volume: float, envelope: String, at: int, duty := 0.5, vibrato := 0.0, bend := 0.0) -> Dictionary:
	return {
		"wave": wave, "hz": hz, "bend": bend if bend > 0.0 else hz, "seconds": seconds, "volume": volume,
		"envelope": envelope, "duty": duty, "vibrato": vibrato, "at": at,
	}


## The scale degree two steps under a melody note, for the second pass's harmony voice.
func _harmony(midi: int, root: int, scale: Array) -> int:
	var pitch := posmod(midi - root, 12)
	var degree: int = scale.find(pitch)
	if degree < 0:
		return midi - 3 # A passing note, outside the key: a plain minor third below.
	return midi - pitch + scale[posmod(degree - 2, 7)] - (12 if degree < 2 else 0)


## The triad standing on a bass note, with whichever third and fifth the key allows, voiced
## above middle C so the arpeggio sits between the bass and the melody.
func _chord(bass: int, root: int, scale: Array) -> Array:
	var base := bass
	while base < 60:
		base += 12
	var third := 3 if scale.has(posmod(bass + 3 - root, 12)) else 4
	var fifth := 6 if scale.has(posmod(bass + 6 - root, 12)) and not scale.has(posmod(bass + 7 - root, 12)) else 7
	return [base, base + third, base + fifth, base + 12]


func _loop(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream


func _midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## Mixes samples into the buffer at the offset, wrapping past the end so the tail of a note
## lands on the top of the loop instead of being cut off where it restarts.
func _add(buffer: PackedFloat32Array, samples: PackedFloat32Array, offset: int) -> void:
	var size := buffer.size()
	for i in samples.size():
		var at := (offset + i) % size
		buffer[at] += samples[i]


## Notes repeat all over a loop - every kick, every step of an arpeggio, every held bass note - so
## each distinct one is synthesized once and mixed in wherever it lands.
func _voice(voices: Dictionary, note: Dictionary) -> PackedFloat32Array:
	var key := "%s|%d|%.3f|%.3f|%.4f|%.4f|%.3f|%.4f" % [
		note.envelope, note.wave, note.hz, note.bend, note.seconds, note.volume, note.duty, note.vibrato,
	]
	if not voices.has(key):
		voices[key] = _render(note)
	return voices[key]


## A single note that slides from one frequency to another and fades out.
func _tone(wave: Wave, from_hz: float, to_hz: float, duration: float, volume: float) -> PackedFloat32Array:
	return _render(_note(wave, from_hz, duration, volume, "fade", 0, 0.5, 0.0, to_hz))


## Synthesizes a note: an attack, decay, sustain and release envelope over a wave that can slide and wobble.
func _render(note: Dictionary) -> PackedFloat32Array:
	var envelope: Dictionary = ENVELOPES[note.envelope]
	var hold := maxi(int(note.seconds * MIX_RATE), 1)
	var release := int(envelope.release * MIX_RATE)
	var count := hold + release
	var samples := PackedFloat32Array()
	samples.resize(count)
	var attack: float = maxf(envelope.attack, 1.0 / MIX_RATE) * MIX_RATE
	var decay: float = (envelope.decay if envelope.decay > 0.0 else note.seconds) * MIX_RATE
	var sustain: float = envelope.sustain
	if sustain == 0.0 and envelope.decay > 0.0:
		hold = mini(hold, int((envelope.attack + envelope.decay) * MIX_RATE)) # The rest would be silence.
		count = hold + release
		samples.resize(count)
	## The level the note is held at when the release begins, so the fall never jumps.
	var held := hold / attack if hold < attack else lerpf(1.0, sustain, minf((hold - attack) / decay, 1.0))
	var wave: Wave = note.wave
	var duty: float = note.duty
	var from_hz: float = note.hz
	var to_hz: float = note.bend
	var volume: float = note.volume
	var vibrato: float = note.vibrato
	var phase := 0.0
	var noise := 0.0
	for i in count:
		var hz := lerpf(from_hz, to_hz, float(i) / count)
		if vibrato > 0.0:
			var seconds := float(i) / MIX_RATE
			hz *= 1.0 + vibrato * minf(seconds / VIBRATO_DELAY, 1.0) * sin(seconds * TAU * VIBRATO_HZ)
		var previous := phase
		phase = fmod(phase + hz / MIX_RATE, 1.0)
		var value: float
		match wave:
			Wave.PULSE:
				value = 1.0 if phase < duty else -1.0
			Wave.TRIANGLE:
				value = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SINE:
				value = sin(phase * TAU)
			Wave.NOISE:
				# Sample and hold: the frequency sets how often a new random value is drawn.
				if phase < previous:
					noise = randf_range(-1.0, 1.0)
				value = noise
		var amplitude: float
		if i < attack:
			amplitude = i / attack
		elif i < hold:
			amplitude = lerpf(1.0, sustain, minf((i - attack) / decay, 1.0))
		else:
			amplitude = held * (1.0 - float(i - hold) / release)
		samples[i] = value * volume * amplitude
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
	_encode(samples, data, 0, samples.size())
	return _stream(data)


## Converts samples in [from, to) to 16-bit PCM.
func _encode(samples: PackedFloat32Array, data: PackedByteArray, from: int, to: int) -> void:
	for i in range(from, to):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))


func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
