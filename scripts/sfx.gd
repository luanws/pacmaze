extends Node
## Retro sound effects and background music, synthesized at startup so the project needs no audio files.
## Every button in the game clicks automatically. `M` mutes and unmutes.

enum Wave { SQUARE, TRIANGLE, SINE, NOISE }

const MIX_RATE := 22050
const VOICES := 8
const ATTACK := 0.004 ## Seconds.
const MUSIC_VOLUME_DB := -6.0
## Background loops. The first plays in the menus; during the levels they all take turns in shuffled order.
## Melodies have one bar per entry, notes are MIDI numbers (0 is a rest) with lengths in sixteenths.
## Bass holds each bar's root and plays `bass_steps` (semitones above it) on the eighths.
## Drums have one char per sixteenth: k kick, s snare, h hi-hat.
const PLAYS_PER_SONG := 2 ## Times a song loops before the level playlist moves on.
const COMPOSE_BUDGET_USEC := 3000 ## Per frame, for songs composed ahead of time, so the game doesn't hitch.
const ENCODE_CHUNK := 4096 ## Samples converted at a time when a song composed ahead of time is finished.
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
	{ # G major, marching.
		"bpm": 140, "lead": Wave.SQUARE, "lead_volume": 0.05,
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
		"bpm": 96, "lead": Wave.SINE, "lead_volume": 0.16,
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
		"bpm": 170, "lead": Wave.SQUARE, "lead_volume": 0.045,
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
		"bpm": 116, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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
		"bpm": 144, "lead": Wave.SQUARE, "lead_volume": 0.05,
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
		"bpm": 100, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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
		"bpm": 176, "lead": Wave.SQUARE, "lead_volume": 0.045,
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
		"bpm": 128, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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
		"bpm": 112, "lead": Wave.SQUARE, "lead_volume": 0.05,
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
		"bpm": 90, "lead": Wave.SINE, "lead_volume": 0.16,
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
		"bpm": 138, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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
		"bpm": 124, "lead": Wave.SQUARE, "lead_volume": 0.05,
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
		"bpm": 152, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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
		"bpm": 136, "lead": Wave.SQUARE, "lead_volume": 0.05,
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
		"bpm": 158, "lead": Wave.TRIANGLE, "lead_volume": 0.12,
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

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _songs := {} ## Composed streams by index, built ahead of time or the first time each song plays.
var _composing: Array[Dictionary] = [] ## Songs being composed a little each frame: index, notes and progress.
var _song := -1
var _playlist: Array[int] = [] ## Songs still to play in this round of the shuffle, the next one last.
var _song_timer: Timer


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
	_song_timer = Timer.new()
	_song_timer.one_shot = true
	_song_timer.timeout.connect(_play_next_in_playlist)
	add_child(_song_timer)
	play_song(0)
	_compose_next_in_playlist()


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


## Switches the background loop and leaves the playlist; the index wraps around, and the current song keeps playing untouched.
func play_song(index: int) -> void:
	_song_timer.stop()
	_switch_song(posmod(index, SONGS.size()))


## Starts the level playlist, or keeps it going if it is already playing (e.g. on the next level).
func play_playlist() -> void:
	if _song_timer.is_stopped():
		_play_next_in_playlist()


func _play_next_in_playlist() -> void:
	_compose_next_in_playlist() # Also refills the playlist when a round of the shuffle is over.
	_switch_song(_playlist.pop_back())
	_song_timer.start(_songs[_song].get_length() * PLAYS_PER_SONG)
	_compose_next_in_playlist()


## Starts composing the next song in the background, so switching to it mid-level doesn't freeze the game.
func _compose_next_in_playlist() -> void:
	if _playlist.is_empty():
		_playlist.assign(range(SONGS.size()))
		_playlist.shuffle()
		if _playlist.back() == _song: # Don't repeat the song that just ended.
			_playlist.push_front(_playlist.pop_back())
	var index: int = _playlist.back()
	if _songs.has(index) or _composing.any(func(job: Dictionary) -> bool: return job.index == index):
		return
	var notes := _music_notes(SONGS[index])
	var samples := PackedFloat32Array()
	samples.resize(notes.pop_front())
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	_composing.append({"index": index, "samples": samples, "notes": notes, "next": 0, "data": data, "encoded": 0})


func _process(_delta: float) -> void:
	var deadline := Time.get_ticks_usec() + COMPOSE_BUDGET_USEC
	while not _composing.is_empty() and Time.get_ticks_usec() < deadline:
		var job := _composing[0]
		if job.next < job.notes.size():
			_add_note(job.samples, job.notes[job.next])
			job.next += 1
			continue
		var end := mini(job.encoded + ENCODE_CHUNK, job.samples.size())
		_encode(job.samples, job.data, job.encoded, end)
		job.encoded = end
		if end == job.samples.size():
			_songs[job.index] = _loop(_stream(job.data))
			_composing.pop_front()


func _switch_song(index: int) -> void:
	if index == _song:
		return
	_song = index
	if not _songs.has(index):
		# Not composed ahead of time (or not yet finished): compose it all now.
		for job in _composing:
			if job.index == index:
				_composing.erase(job)
				break
		var notes := _music_notes(SONGS[index])
		var samples := PackedFloat32Array()
		samples.resize(notes.pop_front())
		for note: Array in notes:
			_add_note(samples, note)
		_songs[index] = _loop(_build(samples))
	_music_player.stream = _songs[index]
	_music_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click"))


## Chiptune loop: lead melody, triangle bass on the eighths, kick and snare with noise hi-hats.
## Returns the loop length in samples followed by its notes, each the arguments of `_tone` plus the sample to start at.
func _music_notes(song: Dictionary) -> Array:
	var step: float = 15.0 / song.bpm ## A sixteenth note, in seconds.
	var melody: Array = song.melody
	var drums: String = song.drums
	var bar_length := int(step * 16 * MIX_RATE)
	var notes: Array = [bar_length * melody.size()]
	for bar in melody.size():
		var start := bar * bar_length
		var offset := 0
		for note: Array in melody[bar]:
			if note[0] > 0:
				var hz := _midi_to_hz(note[0])
				notes.append([song.lead, hz, hz, note[1] * step, song.lead_volume, start + int(offset * step * MIX_RATE)])
			offset += note[1]
		for eighth in 8:
			var bass := _midi_to_hz(song.bass[bar] + song.bass_steps[eighth])
			notes.append([Wave.TRIANGLE, bass, bass, 2 * step, 0.22, start + int(eighth * 2 * step * MIX_RATE)])
		for sixteenth in 16:
			var at := start + int(sixteenth * step * MIX_RATE)
			match drums[sixteenth]:
				"k":
					notes.append([Wave.TRIANGLE, 150, 40, 0.12, 0.3, at])
				"s":
					notes.append([Wave.NOISE, 3000, 3000, 0.09, 0.07, at])
				"h":
					notes.append([Wave.NOISE, 6000, 6000, 0.025, 0.025, at])
	return notes


func _add_note(buffer: PackedFloat32Array, note: Array) -> void:
	_add(buffer, _tone(note[0], note[1], note[2], note[3], note[4]), note[5])


func _loop(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream


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
