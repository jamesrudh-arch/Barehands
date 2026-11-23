extends Node

## THE UAL RETARGET (overhaul S5.1b): installs the Universal
## Animation Library's 43 CC0 clips (Unreal bone naming) onto the
## Ready Player Me hero (Mixamo naming) with the REST-DELTA
## correction - the third cross-rig law:
##   1. matched family (Xbot->RPM): copy rotations verbatim;
##   2. bone position tracks NEVER cross rigs (the S5.1 law);
##   3. foreign families (UAL->RPM): each keyframe rotation carries
##      its DEVIATION from the source rest onto the target rest:
##      q_dst = q_dst_rest * q_src_rest^-1 * q_src_local
## Clip names are remapped to what build_style_data expects, so the
## five fighting styles swing with real motion-capture punches,
## sword arcs, hit reactions, rolls and deaths.

const SOURCE := "res://assets/UAL1_Standard.glb"

## The carry mode. 0 and 1 are the naive local carries (both
## probe-falsified: rests 104 deg apart on the pelvis - the UAL
## rig uses UE bone-axis conventions). 2 is the GLOBAL-REST
## CONJUGATION: the deviation is transported through both
## skeletons' global rest frames so the same WORLD rotation lands
## on the destination bone:
##   d      = inv(q_src_rest) * q_src(t)          (bone frame)
##   d_dst  = inv(W_dst) * W_src * d * inv(W_src) * W_dst
##   q_dst  = q_dst_rest * d_dst
##   = PRE * q_src(t) * SUF   (PRE/SUF precomputed per track)
static var MODE := 2

# UAL (Unreal naming) -> RPM (Mixamo naming)
const BONE_MAP := {
	"pelvis": "Hips",
	"spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
	"neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "clavicle_r": "RightShoulder",
	"upperarm_l": "LeftArm", "upperarm_r": "RightArm",
	"lowerarm_l": "LeftForeArm", "lowerarm_r": "RightForeArm",
	"hand_l": "LeftHand", "hand_r": "RightHand",
	"thigh_l": "LeftUpLeg", "thigh_r": "RightUpLeg",
	"calf_l": "LeftLeg", "calf_r": "RightLeg",
	"foot_l": "LeftFoot", "foot_r": "RightFoot",
	"ball_l": "LeftToeBase", "ball_r": "RightToeBase",
}

# finger chains: UAL <chain>_NN_<side> -> RPM <Side>Hand<Chain>N
const _FINGER_CHAINS := {
	"index": "Index", "middle": "Middle", "pinky": "Pinky",
	"ring": "Ring", "thumb": "Thumb",
}

# the clips build_style_data expects -> UAL source clips
const CLIP_MAP := {
	"Melee_Unarmed_Attack_Punch_A": "Punch_Jab",
	"Melee_Unarmed_Attack_Kick": "Punch_Cross",
	"Melee_1H_Attack_Chop": "Punch_Cross",
	"Melee_1H_Attack_Jump_Chop": "Punch_Cross",
	"Melee_1H_Attack_Slice_Diagonal": "Sword_Attack",
	"Melee_1H_Attack_Slice_Horizontal": "Sword_Attack",
	"Melee_1H_Attack_Stab": "Punch_Jab",
	"Melee_2H_Attack_Chop": "Sword_Attack",
	"Melee_2H_Attack_Slice": "Sword_Attack",
	"Melee_2H_Attack_Spin": "Sword_Attack",
	"Melee_2H_Attack_Spinning": "Sword_Attack",
	"Melee_2H_Attack_Stab": "Sword_Attack",
	"Melee_Dualwield_Attack_Chop": "Punch_Jab",
	"Melee_Dualwield_Attack_Slice": "Sword_Attack",
	"Melee_Dualwield_Attack_Stab": "Punch_Jab",
	"Melee_Block_Attack": "Push_Loop",
	"Melee_Unarmed_Idle": "Sword_Idle",
	"Melee_2H_Idle": "Sword_Idle",
	"Melee_Blocking": "Pistol_Idle_Loop",
	"Idle_B": "Idle_Talking_Loop",
	"Throw": "Spell_Simple_Shoot",
	"Hit_Chest": "Hit_Chest",
	"Hit_Head": "Hit_Head",
	"Death01": "Death01",
	"Roll": "Roll",
	"Reload": "Pistol_Reload",
	"Pistol_Shoot": "Pistol_Shoot",
	"Pistol_Idle": "Pistol_Idle_Loop",
	"Pistol_Aim": "Pistol_Aim_Neutral",
}


## Install the UAL combat/ambient clips (retargeted + renamed) onto
## the hero. Returns the number of clips installed.
static func install(player: AnimationPlayer, skel: Skeleton3D) -> int:
	if player == null or skel == null:
		return 0
	var root_node: Node = player.get_node_or_null(player.root_node)
	if root_node == null:
		return 0
	var dst_rel := str(root_node.get_path_to(skel))
	var scene: PackedScene = load(SOURCE)
	if scene == null:
		return 0
	var holder := scene.instantiate()
	var src_player := _find(holder, AnimationPlayer) as AnimationPlayer
	var src_skel := _find(holder, Skeleton3D) as Skeleton3D
	if src_player == null or src_skel == null:
		holder.queue_free()
		return 0
	var bone_map := _full_map(src_skel, skel)
	var installed := 0
	# three libraries: "combat" (the Melee_* names the styles
	# expect), "ambient" (Idle_B/Throw - the style data's paths),
	# "ual" (raw clip names for the systems that follow)
	var combat := AnimationLibrary.new()
	var raw := AnimationLibrary.new()
	var ambient_add: Array = []
	# the source's clips may live in ANY library (UAL's import does
	# not use the default "" - probe-caught: 0 installed)
	var src_anims: Array = []
	for lib_name in src_player.get_animation_library_list():
		var slib := src_player.get_animation_library(lib_name)
		for an in slib.get_animation_list():
			src_anims.append([an, slib.get_animation(an)])
	for pair in src_anims:
		var an: String = pair[0]
		var anim: Animation = pair[1]
		var copy := _retarget(anim, src_skel, skel, bone_map, dst_rel)
		if copy == null:
			continue
		raw.add_animation(an, copy)
		installed += 1
		# the importer strips a trailing "_Loop" from looping clips
		# (law: Pistol_Idle_Loop imports as Pistol_Idle) - compare
		# through the same normalization the map values use
		var an_norm: String = String(an).trim_suffix("_Loop")
		for want in CLIP_MAP:
			if String(CLP_NORM(CLIP_MAP[want])) == an_norm:
				if want in ["Idle_B", "Throw"]:
					ambient_add.append([want, copy])
				else:
					combat.add_animation(want, copy)
	if combat.get_animation_list().size() > 0:
		if player.has_animation_library("combat"):
			player.remove_animation_library("combat")
		player.add_animation_library("combat", combat)
	if player.has_animation_library("ual"):
		player.remove_animation_library("ual")
	player.add_animation_library("ual", raw)
	# ambient: ADD to the existing library (mixamo_lib built it with
	# idle_b) - the style data wants "ambient/Idle_B" + the throw
	var ambient: AnimationLibrary = player.get_animation_library(
			"ambient") if player.has_animation_library("ambient") 			else null
	if ambient == null:
		ambient = AnimationLibrary.new()
		player.add_animation_library("ambient", ambient)
	for pair in ambient_add:
		var nm: String = pair[0]
		if ambient.has_animation(nm):
			ambient.remove_animation(nm)
		ambient.add_animation(nm, pair[1])
	holder.queue_free()
	return installed


## The retarget itself: rotation-only, rest-delta corrected.
static func _retarget(anim: Animation, src: Skeleton3D, dst: Skeleton3D,
		bone_map: Dictionary, dst_rel: String) -> Animation:
	var copy := anim.duplicate() as Animation
	for ti in range(copy.get_track_count() - 1, -1, -1):
		var s := str(copy.track_get_path(ti))
		var colon := s.find(":")
		if colon < 0:
			copy.remove_track(ti)
			continue
		var bone := s.substr(colon + 1).trim_prefix("mixamorig_")
		var tt := copy.track_get_type(ti)
		if tt != Animation.TYPE_ROTATION_3D:
			copy.remove_track(ti)  # the rotation-only law
			continue
		if not bone_map.has(bone):
			copy.remove_track(ti)
			continue
		var dst_bone: String = bone_map[bone]
		var si := src.find_bone(bone)
		var di := dst.find_bone(dst_bone)
		if si < 0 or di < 0:
			copy.remove_track(ti)
			continue
		var q_src_rest := src.get_bone_rest(si).basis.get_rotation_quaternion()
		var q_dst_rest := dst.get_bone_rest(di).basis.get_rotation_quaternion()
		if MODE == 2:
			# the global-rest conjugation (the UE-axes fix)
			var w_src := src.get_bone_global_rest(si).basis.get_rotation_quaternion()
			var w_dst := dst.get_bone_global_rest(di).basis.get_rotation_quaternion()
			var pre := q_dst_rest * w_dst.inverse() * w_src \
					* q_src_rest.inverse()
			var suf := w_src.inverse() * w_dst
			for ki in copy.track_get_key_count(ti):
				var q2: Quaternion = copy.track_get_key_value(ti, ki)
				copy.track_set_key_value(ti, ki, pre * q2 * suf)
		else:
			# the naive local carries (kept for the record/probes)
			var carry := q_dst_rest * q_src_rest.inverse()
			for ki in copy.track_get_key_count(ti):  # 4.x name (3.x: num_keys)
				# generic value API (4.x has no track_get_key_rotation)
				var q: Quaternion = copy.track_get_key_value(ti, ki)
				if MODE == 0:
					copy.track_set_key_value(ti, ki, carry * q)
				else:
					copy.track_set_key_value(ti, ki, q * carry)
		copy.track_set_path(ti, "%s:%s" % [dst_rel, dst_bone])
	return copy


## Map-value normalizer: accepts both the GLB name and the
## imported (suffix-stripped) name.
static func CLP_NORM(v) -> String:
	return String(v).trim_suffix("_Loop")


## The full bone map (core from BONE_MAP + the finger chains).
static func _full_map(src: Skeleton3D, dst: Skeleton3D) -> Dictionary:
	var m := {}
	for k in BONE_MAP:
		m[k] = BONE_MAP[k]
	for b in src.get_bone_count():
		var n := src.get_bone_name(b)
		var parts := n.split("_")
		if parts.size() == 3 and parts[2] in ["l", "r"] \
				and _FINGER_CHAINS.has(parts[0]) \
				and parts[1].begins_with("0"):
			var side := "Left" if parts[2] == "l" else "Right"
			var chain: String = _FINGER_CHAINS[parts[0]]
			var idx := parts[1].substr(1)
			var dst_name := "%sHand%s%s" % [side, chain, idx]
			if dst.find_bone(dst_name) >= 0:
				m[n] = dst_name
	return m


static func _find(root: Node, what) -> Node:
	if root == null:
		return null
	if is_instance_of(root, what):
		return root
	for c in root.get_children():
		var found := _find(c, what)
		if found:
			return found
	return null
