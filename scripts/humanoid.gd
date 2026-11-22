extends Node3D
## B23 MILESTONE A: the code-built humanoid. A complete character
## framework constructed from primitives at runtime - real joint
## hierarchy (hips/spine/chest/neck/head, shoulders/elbows/hands, hips/
## knees/feet), body meshes with a FACE (brows, eyes, nose, mouth),
## hair styles and layered clothing - animated procedurally: phase-
## driven locomotion blends into named poses (punch, kick, flinch,
## roll, guard...) with per-joint easing. No gltf, no textures, no
## import pipeline: it renders identically on every renderer, which is
## the only character presentation this project can GUARANTEE on
## Xogot/iPhone (the Quaternius gltf path ghosted on the device while
## passing every Linux check). Speaks the rig contract the game
## already uses: play(clip, blend, speed) / set_speed / current().
##
## Faces +Z? No: -Z, Godot forward - look_at() compatibility, and the
## callers (player, enemy, wanderer) all steer with look_at-style math.

const JOINTS := ["hips", "spine", "chest", "neck", "head",
		"shoulder_l", "elbow_l", "hand_l",
		"shoulder_r", "elbow_r", "hand_r",
		"hip_l", "knee_l", "foot_l",
		"hip_r", "knee_r", "foot_r"]

# shared meshes (built once, instanced by every character - mobile
# draw calls stay low and every rig is identical in silhouette)
static var _mesh_cache := {}
static func _shared(kind: String, mk: Callable) -> Mesh:
	if not _mesh_cache.has(kind):
		_mesh_cache[kind] = mk.call()
	return _mesh_cache[kind]

static func _cap(r: float, h: float) -> Mesh:
	return _shared("cap_%.2f_%.2f" % [r, h], func() -> Mesh:
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		return m)

static func _box(x: float, y: float, z: float) -> Mesh:
	return _shared("box_%.2f_%.2f_%.2f" % [x, y, z], func() -> Mesh:
		var m := BoxMesh.new()
		m.size = Vector3(x, y, z)
		return m)

static func _sph(r: float) -> Mesh:
	return _shared("sph_%.2f" % r, func() -> Mesh:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		return m)

static func _cyl(rt: float, rb: float, h: float) -> Mesh:
	return _shared("cyl_%.2f_%.2f_%.2f" % [rt, rb, h], func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		return m)


static func mat(color: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


var _joints: Dictionary = {}        # name -> Node3D pivot
var _rest: Dictionary = {}          # name -> rest rotation (euler)
var _limb_len := 0.0                # leg length, for the stride cycle
var _head_pivot: Node3D = null
var _accent_mats: Array[StandardMaterial3D] = []
var all_mats: Array[StandardMaterial3D] = []  # enemy flash + tint adopts these
var _top_mat: StandardMaterial3D = null
var _hair_mat: StandardMaterial3D = null
var _skin_mat: StandardMaterial3D = null
var _compat: AnimationPlayer = null  # suite-facing mirror of the pose state

# --- animation state ------------------------------------------------------
var _current := ""
var _clip_speed := 1.0
var _cycle_t := 0.0                 # locomotion phase (radians)
var _cycle_rate := 0.0              # from speed, set by locomotion()
var _sway := 0.0                    # smoothed lean
var _breath := 0.0
var _clock := 0.0                   # seconds since play()
var _flinch := 0.0                  # hit reaction envelope
var _lock_retarget := 0.0           # seconds left of hard pose hold

# a pose is {joint: [rx, ry, rz]} in RADIANS; missing joints use rest.
# strikes raise the envelope fast and decay; locomotion always runs
# underneath so a walking punch stays a walking punch.
var _pose: Dictionary = {}
var _pose_w := 0.0                  # current pose weight 0..1
var _pose_target_w := 0.0
var _pose_hold := 0.0               # hard-hold time for strikes
var _pose_transient := false        # strikes decay; holds stay held
var _speed_in := 0.0                # caller's live speed (set_speed)
var _moved_per_s := 0.0             # observed travel (set by hero)


## spec keys: height (m), build (0 slim / 1 normal / 2 heavy), skin,
## hair, hair_style (0 crop / 1 parted / 2 pony / 3 buzz / 4 balding /
## 5 long), top, bottom, shoes, accent (emissive edge, Color), skirt,
## female (bust), jacket (open coat layer color or null)
func build(spec: Dictionary) -> void:
	var height: float = spec.get("height", 1.78)
	var btype: int = spec.get("build", 1)
	var female: bool = spec.get("female", false)
	var s_skin: Color = spec.get("skin", Color(0.72, 0.56, 0.44))
	var s_hair: Color = spec.get("hair", Color(0.16, 0.12, 0.09))
	var s_top: Color = spec.get("top", Color(0.18, 0.19, 0.23))
	var s_bottom: Color = spec.get("bottom", Color(0.13, 0.13, 0.16))
	var s_shoes: Color = spec.get("shoes", Color(0.09, 0.07, 0.06))
	var s_accent: Color = spec.get("accent", Color(0, 0, 0))
	var skirt: bool = spec.get("skirt", false)
	var jacket: Color = spec.get("jacket", Color(0, 0, 0))
	var has_jacket: bool = spec.get("jacket_on", false)
	if spec.has("jacket") and jacket.a > 0.0:
		has_jacket = true
	_skin_mat = mat(s_skin, 0.65)
	_hair_mat = mat(s_hair, 0.8)
	_top_mat = mat(s_top)
	var bot_mat := mat(s_bottom)
	var shoe_mat := mat(s_shoes, 0.55)
	if s_accent.a > 0.0:
		for m in [_top_mat, bot_mat]:
			m.emission_enabled = true
			m.emission = s_accent
			m.emission_energy_multiplier = 0.16

	# proportions scale with the build; the silhouette must read at
	# phone distance: slim = narrow shoulders, heavy = wide mass
	var chest_r := 0.15 + 0.02 * btype
	var waist_r := 0.125 + 0.022 * btype
	var limb_r := 0.052 + 0.004 * btype
	# VLM round 2: the arm capsule OVERLAPPED the torso capsule
	# (sh_w - chest_r - limb_r < 0) - fused slabs. The deltoid now
	# anchors outside the chest with a visible gap.
	var sh_w := chest_r + limb_r + 0.045 \
			+ 0.02 * btype + (0.008 if female else 0.0)
	_limb_len = height * 0.45

	var hips := _joint("hips", null, Vector3(0, height * 0.52, 0))
	var spine := _joint("spine", hips, Vector3(0, 0.11, 0))
	var chest := _joint("chest", spine, Vector3(0, 0.15, 0))
	var neck := _joint("neck", chest, Vector3(0, 0.17, 0))
	_head_pivot = _joint("head", neck, Vector3(0, 0.075, 0))

	# --- the torso mass ---------------------------------------------------
	# pelvis block in the TOP colour (a shirt covers the hips); the
	# trousers overlap upward into it so no waist gap can read
	_m(_cap(waist_r, 0.3), _top_mat, hips, Vector3(0, -0.01, 0))
	_m(_cap(waist_r * 0.96, 0.24), _top_mat, spine, Vector3(0, 0.05, 0))
	_m(_cap(chest_r, 0.3), _top_mat, chest, Vector3(0, 0.02, 0))
	if female:
		var bust := _m(_sph(chest_r * 0.62), _top_mat, chest,
				Vector3(0, 0.07, chest_r * 0.62))
		bust.scale = Vector3(1.25, 0.8, 0.7)
	if has_jacket:
		var jk := mat(jacket, 0.9)
		_accent_mats.append(jk)
		_m(_cap(chest_r * 1.14, 0.42), jk, chest, Vector3(0, 0.0, 0))
		_m(_cap(waist_r * 1.12, 0.2), jk, spine, Vector3(0, 0.02, 0))
		# the coat hem flows over the pelvis, slightly flared - a wide
		# chest over a narrow waist otherwise reads as a floating torso
		_m(_cyl(waist_r * 1.18, waist_r * 1.32, 0.34), jk, hips,
				Vector3(0, -0.08, 0))
		# collar wings
		for sx in [-1.0, 1.0]:
			var col := _m(_box(0.09, 0.12, 0.028), jk, chest,
					Vector3(sx * 0.075, 0.16, -chest_r * 0.9))
			col.rotation.z = sx * -0.35

	# --- the head with a FACE ---------------------------------------------
	# skull + jaw: two spheres read as a head with structure from every
	# angle; the face plane carries the features
	var skull := _m(_sph(0.108), _skin_mat, _head_pivot, Vector3(0, 0.075, 0))
	skull.scale = Vector3(0.88, 1.06, 0.94)
	# jaw/chin mass, forward of the skull centre
	_m(_sph(0.085), _skin_mat, _head_pivot, Vector3(0, 0.0, 0.024))
	var eye_w := mat(Color(0.97, 0.95, 0.9), 0.25)
	eye_w.emission_enabled = true
	eye_w.emission = Color(0.9, 0.88, 0.85)
	eye_w.emission_energy_multiplier = 0.22
	var eye_d := mat(Color(0.04, 0.04, 0.06), 0.25)
	var brow_mat := mat(Color(0.14, 0.1, 0.08), 0.7)
	for sx in [-1.0, 1.0]:
		# eye whites + pupils: bigger, pushed further off the face
		_m(_box(0.056, 0.026, 0.018), eye_w, _head_pivot,
				Vector3(sx * 0.04, 0.076, 0.092))
		_m(_sph(0.012), eye_d, _head_pivot,
				Vector3(sx * 0.042, 0.076, 0.102))
		var brow := _m(_box(0.066, 0.012, 0.018), brow_mat, _head_pivot,
				Vector3(sx * 0.04, 0.106, 0.088))
		brow.name = "BrowL" if sx < 0 else "BrowR"
		# ears
		_m(_sph(0.024), _skin_mat, _head_pivot,
				Vector3(sx * 0.1, 0.07, -0.004))
	# nose: a wedge standing off the face plane
	var nose := _m(_cyl(0.0, 0.019, 0.06), _skin_mat, _head_pivot,
			Vector3(0, 0.048, 0.108))
	nose.rotation.x = 1.35
	# mouth: dark, breakable into a grin by scale
	var mouth := _m(_box(0.05, 0.009, 0.012), mat(Color(0.38, 0.2, 0.19)),
			_head_pivot, Vector3(0, 0.012, 0.097))
	mouth.name = "Mouth"
	_hair(spec.get("hair_style", 1))

	# --- arms ---------------------------------------------------------------
	for sx in [-1, 1]:
		var sfx := "_l" if sx < 0 else "_r"
		var sh := _joint("shoulder" + sfx, chest,
				Vector3(sx * sh_w, 0.1, 0))
		_m(_sph(limb_r * 1.3), _top_mat, sh, Vector3(0, 0, 0))  # deltoid
		_m(_cap(limb_r, 0.26), _top_mat, sh, Vector3(0, -0.13, 0))
		var el := _joint("elbow" + sfx, sh, Vector3(0, -0.28, 0))
		_m(_cap(limb_r * 0.9, 0.24), _skin_mat, el, Vector3(0, -0.11, 0))
		var ha := _joint("hand" + sfx, el, Vector3(0, -0.26, 0))
		var fist := _m(_box(0.055, 0.075, 0.05), _skin_mat, ha,
				Vector3(0, -0.035, 0.008))
		fist.name = "Fist" + sfx

	# --- legs ---------------------------------------------------------------
	for sx in [-1, 1]:
		var sfx := "_l" if sx < 0 else "_r"
		var hp := _joint("hip" + sfx, hips, Vector3(sx * 0.095, -0.04, 0))
		# thighs rise INTO the pelvis capsule: no daylight between
		# torso and leg - skirt or not, the legs EXIST (VLM round 3:
		# shoes floated under the hem with nothing connecting them)
		_m(_cap(limb_r * 1.05, 0.38), bot_mat, hp, Vector3(0, -0.13, 0))
		if skirt:
			_m(_cyl(waist_r * 1.02, waist_r * 1.35, 0.46), _top_mat, hips,
					Vector3(0, -0.19, 0))
		var kn := _joint("knee" + sfx, hp, Vector3(0, -_limb_len * 0.5, 0))
		_m(_cap(limb_r * 0.8, 0.4), bot_mat, kn, Vector3(0, -0.15, 0))
		var ft := _joint("foot" + sfx, kn, Vector3(0, -_limb_len * 0.5, 0))
		var shoe := _m(_box(0.085, 0.07, 0.22), shoe_mat, ft,
				Vector3(0, 0.032, -0.055))
		shoe.name = "Shoe" + sfx

	_rest_setup()
	play("Idle")


func _hair(style: int) -> void:
	# crop cap / side part / ponytail / buzz / balding / long fall
	match style:
		0, 3:
			var cap := _m(_sph(0.113), _hair_mat, _head_pivot,
					Vector3(0, 0.082, -0.004))
			cap.scale = Vector3(0.92, 0.95, 0.96) if style == 0 \
					else Vector3(0.9, 0.72, 0.92)
		1:
			var cap := _m(_sph(0.116), _hair_mat, _head_pivot,
					Vector3(0, 0.096, -0.01))
			cap.scale = Vector3(0.94, 0.92, 1.0)
			var sweep := _m(_box(0.1, 0.016, 0.09), _hair_mat, _head_pivot,
					Vector3(0.012, 0.148, 0.03))
			sweep.rotation.z = -0.12
		2:
			_m(_sph(0.112), _hair_mat, _head_pivot,
					Vector3(0, 0.095, -0.008)).scale = Vector3(0.92, 0.9, 0.95)
			var tail := _m(_cap(0.034, 0.17), _hair_mat, _head_pivot,
					Vector3(0, 0.055, -0.098))
			tail.rotation.x = 0.35
		4:
			var ring := _m(_cyl(0.115, 0.112, 0.05), _hair_mat, _head_pivot,
					Vector3(0, 0.1, 0))
			ring.scale = Vector3(0.92, 1.0, 0.94)
		5:
			var fall := _m(_cap(0.105, 0.34), _hair_mat, _head_pivot,
					Vector3(0, 0.02, -0.055))
			fall.scale = Vector3(1.05, 1.0, 1.0)
		_:
			_m(_sph(0.113), _hair_mat, _head_pivot, Vector3(0, 0.082, 0))


func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	_joints[name] = n
	if parent:
		parent.add_child(n)
	else:
		add_child(n)
	n.position = pos
	return n


func _m(mesh: Mesh, m: StandardMaterial3D, parent: Node3D,
		pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	if m != null and not all_mats.has(m):
		all_mats.append(m)
		if m.emission_energy_multiplier > 0.0:
			_accent_mats.append(m)
	return mi


func _rest_setup() -> void:
	for k in _joints:
		_rest[k] = (_joints[k] as Node3D).rotation
	# the relaxed stance: arms hang slightly forward of the torso line
	# and CLEAR OF IT (VLM round 1: fused arms read as a capsule with
	# legs - the abduction keeps a daylight gap at phone distance),
	# elbows soft - NOT the T-pose spread
	# a body facing its -Z keeps its LEFT side at -X: spreading the
	# left arm OUT is -Z rotation, the right +Z (the B23 sign law -
	# the inverted build crossed the arms toward the torso)
	(_joints.shoulder_l as Node3D).rotation = Vector3(0.12, 0, -0.34)
	(_joints.shoulder_r as Node3D).rotation = Vector3(0.12, 0, 0.34)
	(_joints.elbow_l as Node3D).rotation = Vector3(-0.3, 0, -0.14)
	(_joints.elbow_r as Node3D).rotation = Vector3(-0.3, 0, 0.14)
	for k in _joints:
		_rest[k] = (_joints[k] as Node3D).rotation


# --- the rig contract (drop-in for the gltf rig path) ----------------------

## Clips the game already plays map onto procedural locomotion + poses:
## Idle Walk Sprint Dance | Jump_Start Jump(m_air) Jump_Land | Punch_Jab
## Punch_Cross Kick_Code Kick_* Push Roll Hit_* Grab* | unknown strikes
## fall through a name-parser so future combo tables keep working.
func play(clip: String, blend := 0.25, speed := 1.0) -> bool:
	var changed := clip != _current
	if changed:
		_clock = 0.0
		_current = clip
		_pose_target_w = 0.0
		_pose_transient = false
		_pose_w = minf(_pose_w, 0.6)  # cross-fade, never snap
		_pose = {}
		match clip:
			"Idle", "Dance":
				pass
			"Jump_Start":
				_pose = POSE_CROUCH; _pose_target_w = 1.0; _pose_hold = 0.1
			"Jump", "Jump_Mid", "Fall":
				_pose = POSE_AIR; _pose_target_w = 1.0
			"Jump_Land":
				_pose = POSE_LAND; _pose_target_w = 1.0; _pose_hold = 0.18
			"Punch_Jab", "Punch_Cross", "Punch", "Jab", "Cross", "Hook":
				_pose = POSE_PUNCH if clip.contains("Cross") else POSE_JAB
				_pose_target_w = 1.0
				_pose_hold = 0.22
				_pose_transient = true
			_:
				if clip.contains("Kick"):
					_pose = POSE_KICK; _pose_target_w = 1.0
					_pose_hold = 0.3; _pose_transient = true
				elif clip.contains("Hit") or clip.contains("Hurt"):
					_pose = POSE_HIT; _pose_target_w = 1.0
					_pose_hold = 0.25; _pose_transient = true
				elif clip.contains("Roll"):
					_pose = POSE_ROLL; _pose_target_w = 1.0
					_pose_hold = 0.35; _pose_transient = true
				elif clip.contains("Push"):
					_pose = POSE_PUSH; _pose_target_w = 1.0
					_pose_hold = 0.3; _pose_transient = true
				elif clip.contains("Grab") or clip.contains("Throw"):
					_pose = POSE_GRAB; _pose_target_w = 1.0
					_pose_hold = 0.35; _pose_transient = true
				elif clip.contains("Guard") or clip.contains("Block"):
					_pose = POSE_GUARD; _pose_target_w = 1.0
				elif clip.contains("Phone"):
					_pose = POSE_PHONE; _pose_target_w = 1.0
				elif clip.contains("Sit"):
					_pose = POSE_SIT; _pose_target_w = 1.0
				elif clip.contains("Down") or clip.contains("Knock"):
					_pose = POSE_DOWN; _pose_target_w = 1.0
	set_speed(speed)
	_compat_play(clip)
	return changed


## Suites and tools read animation state the classic way: a real
## AnimationPlayer whose current_animation/is_playing/speed_scale
## mirror the procedural system (empty one-frame animations - the
## POSE engine does the actual animating).
func _compat_play(clip: String) -> void:
	if _compat == null:
		_compat = AnimationPlayer.new()
		_compat.name = "Clips"
		add_child(_compat)
		_compat.add_animation_library("", AnimationLibrary.new())
	if not _compat.has_animation(clip):
		var a := Animation.new()
		a.length = 0.001
		a.loop_mode = Animation.LOOP_LINEAR
		_compat.get_animation_library("").add_animation(clip, a)
	if _compat.current_animation != clip:
		_compat.play(clip)
	_compat.speed_scale = _clip_speed


func main_player() -> AnimationPlayer:
	return _compat


## The hero retunes speed every frame without restarting the clip.
func set_speed(speed: float) -> void:
	_clip_speed = maxf(speed, 0.05)
	_speed_in = speed


func current() -> String:
	return _current


func is_playing() -> bool:
	return true  # procedural: always alive


## The hero reports observed ground speed so the stride matches reality
## (a moving elevator should not stride). Cheap and honest.
func observe_speed(v_per_s: float) -> void:
	_moved_per_s = v_per_s


## Enemy edge glow (the visual-debug panel + kind looks).
func set_edge_glow(on: bool) -> void:
	for m in _accent_mats:
		m.emission_energy_multiplier = 0.16 if on else 0.0


## Diegetic face control: grin, talk flaps, and fear - the B25
## emotion law: a witnessed panic shows on the face (brows up, mouth
## open), and calm restores it. An emotion a player cannot see is a
## variable, not a feeling.
func face(mood: String) -> void:
	var mouth := _head_pivot.get_node_or_null("Mouth") as MeshInstance3D
	var brow_l := _head_pivot.get_node_or_null("BrowL") as MeshInstance3D
	var brow_r := _head_pivot.get_node_or_null("BrowR") as MeshInstance3D
	if mouth == null:
		return
	match mood:
		"grin":
			mouth.scale = Vector3(1.5, 2.2, 1)
			for b in [brow_l, brow_r]:
				if b:
					b.position.y = 0.106
					b.scale = Vector3.ONE
		"talk":
			mouth.scale = Vector3(1.1, 1.0 + 0.8 * absf(sin(_clock * 14.0)), 1)
			for b in [brow_l, brow_r]:
				if b:
					b.position.y = 0.106
					b.scale = Vector3.ONE
		"fear":
			# the visible alarm: brows lift and pinch, the mouth drops
			# open - fear you can read at gameplay distance
			mouth.scale = Vector3(1.15, 3.4, 1)
			mouth.position.y = 0.004
			for b in [brow_l, brow_r]:
				if b:
					b.position.y = 0.115
					b.scale = Vector3(1.05, 1.6, 1)
		_:
			mouth.scale = Vector3.ONE
			mouth.position.y = 0.012
			for b in [brow_l, brow_r]:
				if b:
					b.position.y = 0.106
					b.scale = Vector3.ONE


## Head attachment point (hats, glasses, phones ride here).
func head() -> Node3D:
	return _head_pivot


## Hand attachment point (weapons ride here).
func hand(side: String) -> Node3D:
	return _joints.get("hand_" + side, null) as Node3D


func hips() -> Node3D:
	return _joints.get("hips", null) as Node3D


# --- the pose library (radians, joint euler targets) ------------------------
# Punch: lead arm extends, torso twists into it, rear hand guards.
const POSE_JAB := {
	"shoulder_r": [-1.5, 0.0, 0.1], "elbow_r": [-0.08, 0, 0],
	"shoulder_l": [0.5, 0.0, -0.5], "elbow_l": [-1.6, 0, 0],
	"chest": [0.0, -0.5, 0.0], "hips": [0.0, -0.25, 0.0],
}
const POSE_PUNCH := {
	"shoulder_r": [-1.62, 0.0, -0.12], "elbow_r": [-0.05, 0, 0],
	"shoulder_l": [0.6, 0.0, -0.6], "elbow_l": [-1.9, 0, 0],
	"chest": [0.05, -0.62, 0.0], "hips": [0.0, -0.4, 0.0],
	"head": [0.0, 0.15, 0.0],
}
const POSE_KICK := {
	"hip_r": [-1.35, 0.0, 0.1], "knee_r": [-0.25, 0, 0],
	"hip_l": [0.15, 0, 0], "knee_l": [-0.35, 0, 0],
	"chest": [-0.22, 0.35, 0.0], "hips": [0.0, 0.2, 0.0],
	"shoulder_l": [-0.6, 0, -0.7], "shoulder_r": [0.5, 0, 0.7],
}
const POSE_HIT := {
	"chest": [0.3, 0.15, 0.0], "head": [0.35, 0, -0.12],
	"shoulder_l": [0.7, 0, -0.9], "shoulder_r": [0.7, 0, 0.9],
	"elbow_l": [-1.9, 0, 0], "elbow_r": [-1.9, 0, 0],
	"hips": [0.12, 0, 0],
}
const POSE_ROLL := {
	"hips": [1.15, 0, 0], "chest": [0.9, 0, 0], "head": [0.5, 0, 0],
	"hip_l": [1.6, 0, 0], "knee_l": [-1.7, 0, 0],
	"hip_r": [1.5, 0, 0], "knee_r": [-1.5, 0, 0],
	"shoulder_l": [0.9, 0, -0.8], "shoulder_r": [0.9, 0, 0.8],
}
const POSE_PUSH := {
	"shoulder_l": [-1.35, 0, -0.15], "elbow_l": [-0.15, 0, 0],
	"shoulder_r": [-1.35, 0, 0.15], "elbow_r": [-0.15, 0, 0],
	"chest": [0.22, 0, 0], "hips": [0.1, 0, 0],
}
const POSE_GRAB := {
	"shoulder_l": [-1.1, 0.5, -0.2], "elbow_l": [-0.9, 0, 0],
	"shoulder_r": [-1.1, -0.5, 0.2], "elbow_r": [-0.9, 0, 0],
	"chest": [0.05, 0, 0],
}
const POSE_GUARD := {
	"shoulder_l": [-0.85, 0.35, -0.55], "elbow_l": [-2.1, 0, 0],
	"shoulder_r": [-0.85, -0.35, 0.55], "elbow_r": [-2.1, 0, 0],
	"chest": [0.08, 0, 0], "head": [0.12, 0, 0],
}
const POSE_CROUCH := {
	"hip_l": [0.9, 0, 0], "knee_l": [-1.4, 0, 0],
	"hip_r": [0.9, 0, 0], "knee_r": [-1.4, 0, 0],
	"chest": [0.25, 0, 0],
}
const POSE_AIR := {
	"hip_l": [0.45, 0, 0], "knee_l": [-0.9, 0, 0],
	"hip_r": [-0.25, 0, 0], "knee_r": [-0.5, 0, 0],
	"shoulder_l": [2.45, 0, -0.55], "shoulder_r": [2.45, 0, 0.55],
	"elbow_l": [-0.25, 0, 0], "elbow_r": [-0.25, 0, 0],
	"chest": [0.08, 0, 0],
}
const POSE_LAND := {
	"hip_l": [0.75, 0, 0], "knee_l": [-1.15, 0, 0],
	"hip_r": [0.75, 0, 0], "knee_r": [-1.15, 0, 0],
	"chest": [0.35, 0, 0], "head": [-0.15, 0, 0],
}
const POSE_PHONE := {
	"shoulder_r": [0.45, -0.2, 0.3], "elbow_r": [-2.3, 0, 0],
	"head": [0.0, -0.12, -0.12],
}
const POSE_SIT := {
	"hip_l": [-1.5, 0, 0], "knee_l": [1.5, 0, 0],
	"hip_r": [-1.5, 0, 0], "knee_r": [1.5, 0, 0],
	"chest": [0.12, 0, 0],
}
const POSE_DOWN := {
	"hips": [-1.35, 0, 0], "chest": [-0.35, 0.2, 0], "head": [-0.4, 0, 0],
	"shoulder_l": [0.4, 0, 1.2], "shoulder_r": [0.4, 0, -1.2],
	"hip_l": [0.4, 0, 0.2], "knee_l": [-0.6, 0, 0],
	"hip_r": [0.5, 0, -0.2], "knee_r": [-0.5, 0, 0],
}


# --- the animation driver ---------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	_breath += delta
	# locomotion phase: driven by OBSERVED speed when the hero reports
	# it, else by the clip's own speed (NPC walks)
	var spd := _moved_per_s if _moved_per_s > 0.05 else (
			1.35 if _current == "Walk" else 5.8 if _current == "Sprint"
			else 2.6 if _current == "Run" else 0.0)
	spd *= _clip_speed
	var rate := 0.55 + spd * 1.55
	_cycle_t += delta * rate
	_pose_hold = maxf(_pose_hold - delta, 0.0)
	if _pose_transient and _pose_hold <= 0.0 and _pose_target_w > 0.0:
		# the strike envelope: snap in, ease out after the hold.
		# Persistent poses (guard, air, sit, phone, down) HOLD.
		_pose_target_w = maxf(_pose_target_w - delta * 1.9, 0.0)
	_pose_w = lerpf(_pose_w, _pose_target_w, 1.0 - exp(-14.0 * delta))
	_sway = lerpf(_sway, clampf(spd / 6.0, 0.0, 1.0), 4.0 * delta)
	_apply_pose(delta, spd)


func _rot(j: Node3D, target: Vector3, w: float, k: float) -> void:
	j.rotation = j.rotation.lerp(target, clampf(w * k, 0.0, 1.0))


func _apply_pose(delta: float, spd: float) -> void:
	var k := 1.0 - exp(-12.0 * delta)  # frame-rate independent easing
	var cyc := _cycle_t
	var amp := clampf(spd / 3.1, 0.0, 1.35)  # stride amplitude
	var air := _current == "Jump" or _current == "Jump_Mid" \
			or _current == "Fall"
	var walking := spd > 0.15 and not air

	# hips: the stride drives a vertical bob + a slight roll
	var hips_n := _joints.hips as Node3D
	var bob := absf(sin(cyc)) * 0.035 * amp if walking else 0.0
	hips_n.position.y = (hips_n.position.y - bob) if false \
			else hips_n.position.y  # keep pivot stable; bob via chest
	_rot(hips_n, Vector3(0.0, sin(cyc * 0.5) * 0.06 * amp,
			sin(cyc) * 0.04 * amp), 1.0, k)

	# spine/chest: forward lean grows with speed, twist counters hips
	_rot(_joints.spine as Node3D, Vector3(0.05 + 0.14 * _sway,
			sin(cyc * 0.5) * -0.05 * amp, 0.0), 1.0, k)
	_rot(_joints.chest as Node3D, Vector3(0.04 + 0.1 * _sway,
			sin(cyc * 0.5) * 0.07 * amp + _breath_sway(), 0.0), 1.0, k)

	# head: stabilises (counter-lean), tiny idle look-around
	var look := 0.0
	if spd < 0.2:
		look = sin(_breath * 0.45) * 0.18
	_rot(_joints.head as Node3D, Vector3(-0.06 * _sway, look,
			sin(cyc) * -0.02 * amp), 1.0, k)

	# legs: the stride itself - thigh swings, knee bends on the swing
	# through; feet flatten the toe at push-off. At rest the weight
	# shifts leg to leg (a slow sway the knees feel) - a statue still
	# reads dead even with swinging arms
	for sx in [["l", 1.0], ["r", -1.0]]:
		var s: String = sx[0]
		var ph := cyc + (0.0 if s == "l" else PI)  # opposite phases
		var idle_phase := _breath * 0.9 + (0.0 if s == "l" else PI * 0.5)
		var thigh := sin(ph) * 0.62 * amp if walking else 0.0
		var knee := maxf(0.0, -sin(ph - 0.6)) * 1.05 * amp \
				if walking else 0.0
		var foot_f := maxf(0.0, sin(ph + 0.8)) * 0.35 * amp if walking else 0.0
		var idle_thigh := 0.022 * sin(idle_phase) if not walking else 0.0
		var idle_knee := 0.034 * (0.5 + 0.5 * sin(idle_phase)) \
				if not walking else 0.0
		_rot(_joints["hip_" + s] as Node3D,
				Vector3(thigh + idle_thigh, 0, 0.03 * sx[1]), 1.0, k)
		_rot(_joints["knee_" + s] as Node3D,
				Vector3(-knee - idle_knee, 0, 0), 1.0, k)
		_rot(_joints["foot_" + s] as Node3D, Vector3(-foot_f, 0, 0), 1.0, k)

	# arms: counter-swing to the legs, elbows soften at speed; idle
	# keeps the relaxed hang with a breath lift
	for sx in [["l", 1.0, 1.0], ["r", -1.0, -1.0]]:
		var s: String = sx[0]
		var ph := cyc + (PI if sx[1] > 0 else 0.0)
		var hang := _rest["shoulder_" + s] as Vector3
		var swing := sin(ph) * 0.55 * amp if walking else 0.0
		var idle_l := 0.035 * sin(_breath * 1.7 + (0.0 if s == "l" else 2.1))
		_rot(_joints["shoulder_" + s] as Node3D,
				Vector3(hang.x + swing + idle_l, hang.y, hang.z),
				1.0, k)
		var eh := _rest["elbow_" + s] as Vector3
		var idle_e := 0.06 * sin(_breath * 1.7 + (0.6 if s == "l" else 2.7)) \
				if not walking else 0.0
		_rot(_joints["elbow_" + s] as Node3D,
				Vector3(eh.x - absf(swing) * 0.8 - idle_e, eh.y, eh.z),
				1.0, k)

	# dance: the whole body finds the beat (club crowd, BROWSE corners)
	if _current == "Dance":
		var beat := _breath * 6.0
		_rot(hips_n, Vector3(0, sin(beat * 0.5) * 0.3, 0), 1.0, k)
		_rot(_joints.chest as Node3D,
				Vector3(-0.08, sin(beat * 0.5 + 1.0) * 0.25, 0), 1.0, k)
		for sx in [["l", 1], ["r", -1]]:
			var s: String = sx[0]
			var up := 1.1 + 0.5 * sin(beat + (0.0 if s == "l" else 0.7))
			_rot(_joints["shoulder_" + s] as Node3D,
					Vector3(-up, 0, -sx[1] * 0.4), 1.0, k)

	# the active pose rides ON TOP (strikes, guard, air, hits...)
	if _pose_w > 0.01 and not _pose.is_empty():
		var w := _pose_w
		for jn in _pose:
			var jn2 := _joints.get(jn, null) as Node3D
			if jn2 == null:
				continue
			var base := Vector3.ZERO
			# hips/chest carry the locomotion twist under the pose
			if jn == "hips":
				base = jn2.rotation
			_rot(jn2, base + (Vector3(_pose[jn][0], _pose[jn][1],
					_pose[jn][2])), w, 1.0)


func _breath_sway() -> float:
	return sin(_breath * 1.6) * 0.015
