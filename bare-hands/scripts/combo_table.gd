class_name ComboTable
extends Object
## The whole combo list in one file (combo pass PART 2). Sequences are
## written in face-button tokens - A light, B heavy, X kick, Y grab -
## with optional direction prefixes on a press ("f+A" = stick forward).
## Classic scheme emits the same tokens (A = punch tap, B = punch hold,
## Y = grab), so every non-kick combo works in both schemes; kick-string
## combos are Face-scheme inputs.
##
## A combo does not REPLACE the single presses: each press still acts
## immediately (a jab is a jab). Completing a sequence fires the combo's
## own choreography as the payoff move. No combo's sequence is a prefix
## of another's, so a longer string can never be shadowed.
##
## hit fields: anim/anim_t (when the pose switches), t (impact), kind
## (the enemy's hit kind), dmg, cam (camera punch), snd, hap, shake,
## style (style-meter move name), lunge (added impulse at combo start),
## spin (hero does a full turn during the string).

const ALL := [
	# --- fists ----------------------------------------------------------------
	{
		"id": "super_punch", "name": "SUPER PUNCH", "seq": ["A", "B", "A"],
		"level": 2, "desc": "The signature haymaker: a slow wind-up, then the biggest single hit your bare hands can land.",
		"dmg": 6, "lunge": 1.6,
		"hits": [
			{"anim": "Punch_Cross", "anim_t": 0.0, "speed": 0.5, "t": 0.52,
					"kind": "heavy", "dmg": 6, "cam": -8.0, "snd": "bell_heavy_0",
					"snd_pitch": 0.8, "hap": "super", "shake": 0.8, "style": "super_punch",
					"slow": 0.22},
		],
	},
	{
		"id": "sweep", "name": "ANKLE SWEEP", "seq": ["X", "A"],
		"level": 2, "desc": "A low kick that dumps them on the wet asphalt. Cheap, mean, effective.",
		"dmg": 2, "lunge": 1.0,
		"hits": [
			{"anim": "Kick_Code", "anim_t": 0.0, "speed": 1.1, "t": 0.30,
					"kind": "sweep", "dmg": 2, "cam": 4.0, "snd": "cloth_1",
					"snd_pitch": 0.7, "hap": "heavy", "shake": 0.35, "style": "sweep"},
		],
	},
	{
		"id": "knee_rise", "name": "RISING KNEE", "seq": ["A", "A", "B"],
		"level": 3, "desc": "Two quick taps to soften them, then a knee that pops them into the air for a juggle.",
		"dmg": 2, "lunge": 1.2,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.8, "t": 0.30,
					"kind": "launcher", "dmg": 2, "cam": 5.0, "snd": "body_med_0",
					"snd_pitch": 0.9, "hap": "heavy", "shake": 0.4, "style": "launcher"},
		],
	},
	{
		"id": "triple_threat", "name": "TRIPLE THREAT", "seq": ["X", "X", "X"],
		"level": 4, "desc": "Three fast kicks - snap, snap, and a spinning heel that sends them sliding. The kick string.",
		"dmg": 6, "lunge": 1.1,
		"hits": [
			{"anim": "Kick_Code", "anim_t": 0.0, "speed": 1.7, "t": 0.20, "kind": "tap",
					"dmg": 1, "cam": 2.5, "snd": "punch_med_0", "snd_pitch": 1.3,
					"hap": "light", "shake": 0.25, "style": "kick"},
			{"anim": "Kick_Code", "anim_t": 0.28, "speed": 1.7, "t": 0.46, "kind": "tap",
					"dmg": 2, "cam": 3.5, "snd": "body_med_0", "snd_pitch": 1.15,
					"hap": "light", "shake": 0.3, "style": "kick"},
			{"anim": "Kick_Code", "anim_t": 0.54, "speed": 1.1, "t": 0.78, "kind": "heavy",
					"dmg": 3, "cam": 5.5, "snd": "body_heavy_0", "snd_pitch": 0.85,
					"hap": "heavy", "shake": 0.55, "style": "kick"},
		],
	},
	{
		"id": "slam_chain", "name": "POWERBOMB", "seq": ["Y", "B"],
		"level": 3, "requires_grab": true,
		"desc": "While holding someone: hoist and drive them into the ground. The grab-to-throw chain.",
		"dmg": 3,
		"hits": [
			{"anim": "Punch_Cross", "anim_t": 0.0, "speed": 0.8, "t": 0.30,
					"kind": "throw_slam", "dmg": 3, "cam": -7.0, "snd": "wood_heavy_0",
					"snd_pitch": 0.8, "hap": "super", "shake": 0.9, "style": "slam"},
		],
	},
	{
		"id": "backfist_combo", "name": "SPIN BACKFIST", "seq": ["A", "Y"],
		"level": 5, "desc": "A jab that turns into a spinning backfist. Reads like a street fight, not a dojo.",
		"dmg": 3, "lunge": 0.8, "spin": true,
		"hits": [
			{"anim": "Punch_Cross", "anim_t": 0.0, "speed": 1.9, "t": 0.26,
					"kind": "backfist", "dmg": 3, "cam": 5.5, "snd": "cloth_0",
					"snd_pitch": 1.2, "hap": "heavy", "shake": 0.45, "style": "backfist"},
		],
	},
	{
		"id": "hamstring", "name": "HAMSTRING", "seq": ["X", "B"],
		"level": 6, "desc": "Kick the leg, then bring the whole arm down on their neck.",
		"dmg": 4, "lunge": 1.0,
		"hits": [
			{"anim": "Kick_Code", "anim_t": 0.0, "speed": 1.2, "t": 0.24, "kind": "kick",
					"dmg": 1, "cam": 2.5, "snd": "punch_med_0", "snd_pitch": 1.1,
					"hap": "light", "shake": 0.25, "style": "kick"},
			{"anim": "Punch_Cross", "anim_t": 0.30, "speed": 0.7, "t": 0.62,
					"kind": "heavy", "dmg": 3, "cam": 6.0, "snd": "body_heavy_0",
					"snd_pitch": 0.9, "hap": "heavy", "shake": 0.55, "style": "heavy"},
		],
	},
	{
		"id": "uppercut", "name": "RISING DRAGON", "seq": ["f+B"],
		"level": 7, "desc": "Stick forward and drive the heavy up through their chin. The launcher, made explicit.",
		"dmg": 3, "lunge": 2.0,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 0.55, "t": 0.38,
					"kind": "launcher", "dmg": 3, "cam": 6.5, "snd": "metal_ring_0",
					"snd_pitch": 1.3, "hap": "heavy", "shake": 0.5, "style": "launcher",
					"slow": 0.12},
		],
	},
	{
		"id": "cross_counter", "name": "CROSS-COUNTER", "seq": ["B", "A"],
		"level": 8, "desc": "Feint the heavy, then counter over the top of whatever they started.",
		"dmg": 4, "lunge": 1.2,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.9, "t": 0.30,
					"kind": "backfist_counter", "dmg": 4, "cam": -6.0, "snd": "glass_med_0",
					"snd_pitch": 1.0, "hap": "parry", "shake": 0.5, "style": "counter"},
		],
	},
	{
		"id": "cyclone", "name": "CYCLONE", "seq": ["A", "X", "A"],
		"level": 9, "desc": "Punch, kick, punch - with a full body spin that catches everyone around you.",
		"dmg": 5, "lunge": 0.6, "spin": true, "aoe": 2.2,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.5, "t": 0.22, "kind": "tap",
					"dmg": 1, "cam": 3.0, "snd": "punch_med_1", "snd_pitch": 1.1,
					"hap": "light", "shake": 0.3, "style": "jab"},
			{"anim": "Kick_Code", "anim_t": 0.30, "speed": 1.5, "t": 0.48, "kind": "tap",
					"dmg": 2, "cam": 4.0, "snd": "body_med_1", "snd_pitch": 1.0,
					"hap": "light", "shake": 0.35, "style": "kick"},
			{"anim": "Punch_Cross", "anim_t": 0.56, "speed": 1.3, "t": 0.74, "kind": "hook",
					"dmg": 2, "cam": 5.0, "snd": "body_heavy_1", "snd_pitch": 0.95,
					"hap": "heavy", "shake": 0.5, "style": "hook"},
		],
	},
	{
		"id": "headbutt_rush", "name": "BULL RUSH", "seq": ["f+A", "f+A"],
		"level": 10, "desc": "Two lunging shoulder drives. Closes distance like an argument you intend to finish.",
		"dmg": 4, "lunge": 3.2,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.4, "t": 0.26, "kind": "cross",
					"dmg": 2, "cam": 3.5, "snd": "punch_med_0", "snd_pitch": 0.9,
					"hap": "heavy", "shake": 0.4, "style": "cross"},
			{"anim": "Punch_Cross", "anim_t": 0.34, "speed": 1.2, "t": 0.60, "kind": "heavy",
					"dmg": 2, "cam": 5.5, "snd": "body_heavy_0", "snd_pitch": 0.85,
					"hap": "heavy", "shake": 0.6, "style": "heavy"},
		],
	},
	{
		"id": "knockout", "name": "LIGHTS OUT", "seq": ["A", "B", "B"],
		"level": 12, "desc": "Jab, heavy, and a finisher that ends the conversation in slow motion.",
		"dmg": 99, "lunge": 1.4,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.6, "t": 0.22, "kind": "jab",
					"dmg": 1, "cam": 2.5, "snd": "punch_med_0", "snd_pitch": 1.1,
					"hap": "light", "shake": 0.25, "style": "jab"},
			{"anim": "Punch_Cross", "anim_t": 0.30, "speed": 0.8, "t": 0.58,
					"kind": "finisher", "dmg": 99, "cam": -8.0, "snd": "bell_heavy_0",
					"snd_pitch": 0.7, "hap": "super", "shake": 0.9, "style": "finisher",
					"slow": 0.35},
		],
	},
	{
		"id": "six_shooter", "name": "SIX-SHOOTER", "seq": ["A", "A", "X", "A"],
		"level": 15, "desc": "Four beats, one breath. The capstone string for hands that never learned to hold a gun.",
		"dmg": 6, "lunge": 1.0,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.9, "t": 0.16, "kind": "tap",
					"dmg": 1, "cam": 2.0, "snd": "punch_med_0", "snd_pitch": 1.3,
					"hap": "light", "shake": 0.2, "style": "jab"},
			{"anim": "Punch_Cross", "anim_t": 0.22, "speed": 1.9, "t": 0.34, "kind": "tap",
					"dmg": 1, "cam": 2.5, "snd": "punch_med_1", "snd_pitch": 1.3,
					"hap": "light", "shake": 0.25, "style": "cross"},
			{"anim": "Kick_Code", "anim_t": 0.40, "speed": 1.7, "t": 0.54, "kind": "tap",
					"dmg": 2, "cam": 3.5, "snd": "body_med_0", "snd_pitch": 1.1,
					"hap": "heavy", "shake": 0.3, "style": "kick"},
			{"anim": "Punch_Cross", "anim_t": 0.60, "speed": 1.2, "t": 0.84, "kind": "hook",
					"dmg": 2, "cam": 5.0, "snd": "body_heavy_0", "snd_pitch": 0.95,
					"hap": "super", "shake": 0.6, "style": "hook"},
		],
	},
	# --- with the pipe ----------------------------------------------------------
	{
		"id": "pipe_waltz", "name": "PIPE WALTZ", "seq": ["A", "A", "B"], "pipe": true,
		"level": 4, "desc": "Swing, swing, and a heavy finish. The pipe leads; you follow.",
		"dmg": 5, "lunge": 1.2,
		"hits": [
			{"anim": "Punch_Jab", "anim_t": 0.0, "speed": 1.0, "t": 0.30, "kind": "pipe",
					"dmg": 2, "cam": 3.5, "snd": "metal_click_0", "snd_pitch": 1.1,
					"hap": "light", "shake": 0.35, "style": "pipe"},
			{"anim": "Punch_Cross", "anim_t": 0.40, "speed": 0.8, "t": 0.72,
					"kind": "pipe_heavy", "dmg": 3, "cam": 6.0, "snd": "metal_ring_0",
					"snd_pitch": 0.9, "hap": "heavy", "shake": 0.6, "style": "pipe_heavy"},
		],
	},
	{
		"id": "skull_cracker", "name": "SKULL CRACKER", "seq": ["B", "B"], "pipe": true,
		"level": 5, "desc": "Two overhead blows with the full pipe. Nothing subtle about it.",
		"dmg": 6, "lunge": 1.0,
		"hits": [
			{"anim": "Punch_Cross", "anim_t": 0.0, "speed": 0.7, "t": 0.42,
					"kind": "pipe_heavy", "dmg": 3, "cam": -6.0, "snd": "metal_ring_0",
					"snd_pitch": 0.8, "hap": "heavy", "shake": 0.55, "style": "pipe_heavy"},
			{"anim": "Punch_Cross", "anim_t": 0.52, "speed": 0.65, "t": 0.94,
					"kind": "pipe_heavy", "dmg": 3, "cam": -7.0, "snd": "bell_heavy_0",
					"snd_pitch": 0.75, "hap": "super", "shake": 0.8, "style": "pipe_heavy",
					"slow": 0.2},
		],
	},
	{
		"id": "pipe_sweep", "name": "PIPE SWEEP", "seq": ["X", "A"], "pipe": true,
		"level": 6, "desc": "Kick the shin, sweep the legs with the pipe. They go down; you stay standing.",
		"dmg": 3, "lunge": 0.9,
		"hits": [
			{"anim": "Kick_Code", "anim_t": 0.0, "speed": 1.1, "t": 0.28, "kind": "sweep",
					"dmg": 3, "cam": 4.0, "snd": "wood_med_0", "snd_pitch": 0.9,
					"hap": "heavy", "shake": 0.4, "style": "sweep"},
		],
	},
]

## Lookup by id.
static func by_id(id: String) -> Dictionary:
	for c in ALL:
		if c["id"] == id:
			return c
	return {}

## Longest-first list (match order).
static func ordered() -> Array:
	var list := ALL.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# longest first; with the pipe on, the pipe version of a shared
		# string must win over the fist one
		var la := (a["seq"] as Array).size()
		var lb := (b["seq"] as Array).size()
		if la != lb:
			return la > lb
		return bool(a.get("pipe", false)) and not bool(b.get("pipe", false))
	)
	return list
