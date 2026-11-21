extends Resource
const CLS_AttackData := preload("res://scripts/attack_data.gd")
## AttackData - one Resource per attack (prompt section 8, COMBAT
## ARCHITECTURE): every gameplay number a landed hit needs lives HERE or
## in Tuning (globals: HP, windows, meters, economy), never inline in a
## script. Better values can be dropped into the .tres without code
## changes; a missing .tres falls back to the built-in default so a lost
## file can never crash a fight (prompt 9C).
##
## Field split vs Tuning.gd:
##   AttackData = per-attack FEEL (damage, hitstop frames, knockback,
##                shake, camera, haptic, audio, style tag, super gain)
##   Tuning     = global BALANCE (HP pools, timing windows, meter rates,
##                economy, trust, crowd caps)

@export var attack_name: String = "jab"

## Damage in the game's small-int scale (1 jab, 2 cross, 3 heavy, 4
## pipe_heavy; 99 = one-shot execution kinds like counter/super).
@export var damage: int = 1

## Hit-stop in LOGIC FRAMES (60 fps): light 3-4, heavy 8-10 (bible 4A).
## The selective hitstop freezes ONLY attacker and target.
@export var hitstop_frames: int = 4

## Knockback in the hit's local frame: x = push along the hit direction,
## y = lift, z = lateral drift. Applied by the target's take_hit().
@export var knockback := Vector3(1.6, 0.0, 0.0)

## Screen shake (Fx units) and the camera push on impact.
@export var shake_intensity: float = 0.2
@export var camera_punch: float = 1.5

## Posture damage toward the target's posture bar (parry fills it fast;
## 0 = this attack does not threaten posture).
@export var posture_damage: float = 0.0

## Light-attack cancel window into dodge, in ms (0,0 = not cancellable -
## heavies never cancel, bible 4A).
@export var cancel_start_ms: float = 150.0
@export var cancel_end_ms: float = 350.0

## Haptic language (prompt section 7): light / heavy / parry / super.
@export var haptic_pattern: String = "light"

## Audio slots (bible section 12): bank clip names, layered.
@export var audio_layers: Array[String] = ["punch_med_0"]

## Style tag this hit feeds the style meter with, and super-meter gain.
@export var style_tag: String = "jab"
@export var super_gain: float = 0.0

## Optional dramatic slow-mo on this hit (seconds, scale) - a CAMERA
## effect, distinct from hitstop, which never touches Engine.time_scale.
@export var slow_mo_seconds: float = 0.0
@export var slow_mo_scale: float = 0.35


## Every swing the hero and the enemies can land, with the shipped feel
## values. The .tres files under res://attacks/ override these; a missing
## or broken .tres falls back here so a fight can never crash.
const DEFAULTS := {
	"jab": {"damage": 1, "hitstop_frames": 4, "knockback": Vector3(3.0, 0.0, 0.0), "posture_damage": 4.0,
		"shake_intensity": 0.2, "camera_punch": 1.5, "haptic_pattern": "light",
		"audio_layers": ["punch_med_0"], "style_tag": "jab", "super_gain": 1.0,
		"cancel_start_ms": 150.0, "cancel_end_ms": 350.0},
	"cross": {"damage": 2, "hitstop_frames": 7, "knockback": Vector3(5.0, 0.0, 0.0), "posture_damage": 8.0,
		"shake_intensity": 0.35, "camera_punch": 3.0, "haptic_pattern": "light",
		"audio_layers": ["punch_heavy_0", "body_med_0"], "style_tag": "cross",
		"super_gain": 2.0, "cancel_start_ms": 150.0, "cancel_end_ms": 350.0},
	"hook": {"damage": 2, "hitstop_frames": 7, "knockback": Vector3(5.0, 0.0, 0.0), "posture_damage": 8.0,
		"shake_intensity": 0.35, "camera_punch": 3.0, "haptic_pattern": "light",
		"audio_layers": ["punch_heavy_0", "body_med_0"], "style_tag": "hook",
		"super_gain": 2.0, "cancel_start_ms": 150.0, "cancel_end_ms": 350.0},
	"heavy": {"damage": 3, "hitstop_frames": 8, "knockback": Vector3(6.5, 0.0, 0.0),
		"shake_intensity": 0.35, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["punch_heavy_0", "sub_hit_0"], "style_tag": "heavy",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"posture_damage": 20.0},
	"counter": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(6.0, 0.0, 0.0),
		"shake_intensity": 0.6, "camera_punch": 5.0, "haptic_pattern": "parry",
		"audio_layers": ["punch_heavy_0", "sub_hit_1", "metal_ring_1"],
		"style_tag": "counter", "super_gain": 6.0, "cancel_start_ms": 0.0,
		"cancel_end_ms": 0.0, "posture_damage": 30.0},
	"launcher": {"damage": 1, "hitstop_frames": 8, "knockback": Vector3(2.5, 6.5, 0.0),
		"shake_intensity": 0.5, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["punch_heavy_1", "sub_hit_0"], "style_tag": "launcher",
		"super_gain": 4.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"posture_damage": 25.0},
	"finisher": {"damage": 99, "hitstop_frames": 10, "knockback": Vector3(3.0, 0.0, 0.0),
		"shake_intensity": 0.8, "camera_punch": -7.0, "haptic_pattern": "super",
		"audio_layers": ["punch_heavy_2", "sub_hit_1"], "style_tag": "finisher",
		"super_gain": 4.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.5, "slow_mo_scale": 0.3},
	"super": {"damage": 99, "hitstop_frames": 12, "knockback": Vector3(7.5, 5.5, 0.0),
		"shake_intensity": 1.0, "camera_punch": 6.0, "haptic_pattern": "super",
		"audio_layers": ["bell_heavy_0"], "style_tag": "super", "super_gain": 0.0,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0, "posture_damage": 60.0,
		"slow_mo_seconds": 0.3, "slow_mo_scale": 0.4},
	"kick": {"damage": 2, "hitstop_frames": 7, "knockback": Vector3(5.5, 0.0, 0.0),
		"shake_intensity": 0.45, "camera_punch": 4.5, "haptic_pattern": "heavy",
		"audio_layers": ["body_heavy_0"], "style_tag": "kick", "super_gain": 2.0,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0, "posture_damage": 15.0},
	"backfist": {"damage": 2, "hitstop_frames": 6, "knockback": Vector3(4.0, 0.0, 0.0), "posture_damage": 10.0,
		"shake_intensity": 0.3, "camera_punch": 3.5, "haptic_pattern": "light",
		"audio_layers": ["punch_med_1"], "style_tag": "backfist", "super_gain": 2.0,
		"cancel_start_ms": 150.0, "cancel_end_ms": 350.0},
	"backfist_counter": {"damage": 6, "hitstop_frames": 8, "knockback": Vector3(7.0, 0.0, 0.0),
		"shake_intensity": 0.6, "camera_punch": 5.0, "haptic_pattern": "parry",
		"audio_layers": ["punch_heavy_0", "metal_ring_1"], "style_tag": "backfist",
		"super_gain": 5.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"posture_damage": 25.0},
	"pipe": {"damage": 2, "hitstop_frames": 6, "knockback": Vector3(4.5, 0.0, 0.0),
		"shake_intensity": 0.35, "camera_punch": 3.5, "haptic_pattern": "light",
		"audio_layers": ["metal_ring_0", "body_med_0"], "style_tag": "pipe",
		"super_gain": 2.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"posture_damage": 20.0},
	"pipe_heavy": {"damage": 4, "hitstop_frames": 8, "knockback": Vector3(6.5, 0.0, 0.0),
		"shake_intensity": 0.5, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["metal_ring_0", "sub_hit_0"], "style_tag": "pipe_heavy",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"posture_damage": 35.0},
	"knee": {"damage": 1, "hitstop_frames": 4, "knockback": Vector3(0.5, 0.0, 0.0), "posture_damage": 6.0,
		"shake_intensity": 0.2, "camera_punch": 1.5, "haptic_pattern": "light",
		"audio_layers": ["punch_med_2"], "style_tag": "knee", "super_gain": 1.0,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0},
	"throw_slam": {"damage": 3, "hitstop_frames": 8, "knockback": Vector3(2.0, 2.0, 0.0), "posture_damage": 40.0,
		"shake_intensity": 0.7, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["wood_heavy_0", "sub_hit_0"], "style_tag": "throw_slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0},
	"tap": {"damage": 1, "hitstop_frames": 3, "knockback": Vector3(0.6, 0.0, 0.0), "posture_damage": 2.0,
		"shake_intensity": 0.15, "camera_punch": 1.0, "haptic_pattern": "light",
		"audio_layers": ["punch_med_0"], "style_tag": "tap", "super_gain": 0.5,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0},
	"slam_wall": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(7.5, 0.0, 0.0), "posture_damage": 30.0,
		"shake_intensity": 0.7, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["wood_heavy_0", "sub_hit_0"], "style_tag": "slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.4, "slow_mo_scale": 0.45},
	"slam_car": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(7.5, 0.0, 0.0), "posture_damage": 30.0,
		"shake_intensity": 0.8, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["metal_ring_0", "sub_hit_0"], "style_tag": "slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.4, "slow_mo_scale": 0.45},
	"slam_rail": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(7.5, 0.0, 0.0), "posture_damage": 30.0,
		"shake_intensity": 0.7, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["metal_ring_0", "sub_hit_0"], "style_tag": "slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.4, "slow_mo_scale": 0.45},
	"slam_shutter": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(7.5, 0.0, 0.0), "posture_damage": 30.0,
		"shake_intensity": 0.8, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["metal_ring_0", "glass_med_0"], "style_tag": "slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.4, "slow_mo_scale": 0.45},
	"slam_chain": {"damage": 99, "hitstop_frames": 8, "knockback": Vector3(7.5, 0.0, 0.0), "posture_damage": 30.0,
		"shake_intensity": 0.8, "camera_punch": 5.0, "haptic_pattern": "heavy",
		"audio_layers": ["metal_ring_1", "sub_hit_0"], "style_tag": "slam",
		"super_gain": 3.0, "cancel_start_ms": 0.0, "cancel_end_ms": 0.0,
		"slow_mo_seconds": 0.4, "slow_mo_scale": 0.45},
	"sweep": {"damage": 2, "hitstop_frames": 6, "knockback": Vector3(1.6, 0.0, 0.0), "posture_damage": 20.0,
		"shake_intensity": 0.5, "camera_punch": 4.0, "haptic_pattern": "heavy",
		"audio_layers": ["body_heavy_0"], "style_tag": "sweep", "super_gain": 2.0,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0},
	"shot": {"damage": 6, "hitstop_frames": 10, "knockback": Vector3(7.0, 0.0, 0.0),
		"shake_intensity": 0.8, "camera_punch": 6.0, "haptic_pattern": "heavy",
		"audio_layers": ["gun_test_0"], "style_tag": "shot", "super_gain": 0.0,
		"cancel_start_ms": 0.0, "cancel_end_ms": 0.0},
}

static var _cache: Dictionary = {}


## The AttackData for a swing: the .tres if it loads, else the built-in
## default, else a neutral fallback. Never returns null, never crashes.
static func for_attack(id: String) -> CLS_AttackData:
	if _cache.has(id):
		return _cache[id]
	var data := CLS_AttackData.new()
	data.attack_name = id
	if DEFAULTS.has(id):
		var d: Dictionary = DEFAULTS[id]
		data.damage = int(d.get("damage", 1))
		data.hitstop_frames = int(d.get("hitstop_frames", 4))
		data.knockback = d.get("knockback", Vector3(1.6, 0.0, 0.0))
		data.shake_intensity = float(d.get("shake_intensity", 0.2))
		data.camera_punch = float(d.get("camera_punch", 1.5))
		data.posture_damage = float(d.get("posture_damage", 0.0))
		data.cancel_start_ms = float(d.get("cancel_start_ms", 0.0))
		data.cancel_end_ms = float(d.get("cancel_end_ms", 0.0))
		data.haptic_pattern = str(d.get("haptic_pattern", "light"))
		var layers: Array[String] = []
		for l in d.get("audio_layers", ["punch_med_0"]):
			layers.append(str(l))
		data.audio_layers = layers
		data.style_tag = str(d.get("style_tag", id))
		data.super_gain = float(d.get("super_gain", 0.0))
		data.slow_mo_seconds = float(d.get("slow_mo_seconds", 0.0))
		data.slow_mo_scale = float(d.get("slow_mo_scale", 0.35))
	# a .tres override (designer-tweakable) replaces the built-in values
	var path := "res://attacks/%s.tres" % id
	if ResourceLoader.exists(path):
		var loaded := load(path) as CLS_AttackData
		if loaded != null:
			data = loaded
	else:
		Log.warn("AttackData: no .tres for '%s' - using built-in default" % id)
	_cache[id] = data
	return data


## Hitstop duration in seconds from the frame count (60 fps logic).
static func hitstop_seconds(frames: int) -> float:
	return float(frames) / 60.0


## A fresh AttackData with this row's values, for the combo table's
## per-hit dictionaries (they carry dmg/cam/shake/snd/hap of their own).
static func from_combo_hit(row: Dictionary, id: String) -> CLS_AttackData:
	var base := for_attack(id)
	var data := CLS_AttackData.new()
	data.attack_name = str(row.get("name", id))
	data.damage = int(row.get("dmg", base.damage))
	data.hitstop_frames = int(row.get("hitstop_frames",
			int(round(row.get("hitstop", 0.08) * 60.0))) if row.has("hitstop")
			else base.hitstop_frames)
	data.knockback = base.knockback
	data.shake_intensity = float(row.get("shake", base.shake_intensity))
	data.camera_punch = float(row.get("cam", base.camera_punch))
	data.posture_damage = float(row.get("posture", base.posture_damage))
	data.cancel_start_ms = base.cancel_start_ms
	data.cancel_end_ms = base.cancel_end_ms
	data.haptic_pattern = str(row.get("hap", base.haptic_pattern))
	var layers: Array[String] = []
	if row.has("snd"):
		layers.append(str(row["snd"]))
	else:
		layers = base.audio_layers
	data.audio_layers = layers
	data.style_tag = str(row.get("style", base.style_tag))
	data.super_gain = float(row.get("super", base.super_gain))
	data.slow_mo_seconds = float(row.get("slow", base.slow_mo_seconds))
	data.slow_mo_scale = base.slow_mo_scale
	return data
