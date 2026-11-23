extends Node

## THE UAL RETARGET (overhaul S5.1b): installs the Universal
## Animation Library's 43 CC0 clips (Unreal bone naming) onto the
## Ready Player Me hero (Mixamo naming). Cross-rig laws so far:
##   1. matched family (Xbot->RPM): copy rotations verbatim;
##   2. bone position tracks NEVER cross rigs (the S5.1 law);
##   3. foreign families need the world-orientation baker below -
##      no local-carry formula survives the A/T-pose mismatch.
## Clip names are remapped to what build_style_data expects, so the
## five fighting styles swing with real motion-capture punches,
## sword arcs, hit reactions, rolls and deaths.

const SOURCE := "res://assets/UAL1_Standard.glb"

## THE BAKER (the reference-pose fix). Probe-caught rig law: UAL's
## rest IS a T-pose (arm straight out horizontal) while RPM's rest
## is an A-pose (arms ~57 deg down) - every local-carry formula
## (rest-delta, either side, global-rest conjugation) skews motion
## by that offset. The baker instead samples the source pose
## stream on a 30 fps grid and maps each bone's WORLD orientation
## through the shared T-pose reference pair:
##   W_dst(t) = D(i) * inv(S(i)) * W_src(t)
## S(i) = UAL's rest global (its T-pose); D(i) = S(i) - a pure
## world-frame transfer (the probe-caught law; a constructed
## RPM T-pose via an arm lift is falsified - direction without
## twist). Destination locals are derived top-down from the
## RETARGETED parent chain, which absorbs every convention
## difference. Rotation-only (the S5.1 law):
## destination positions stay at the RPM rest. The bake runs ONCE
## headless (tests/bake_ual.tscn -> assets/native/ual_baked.res);
## install() loads that; the live path is the fallback.
const BAKED := "res://assets/native/ual_baked.res"

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
static func install(player: AnimationPlayer, skel: Skeleton3D,
		baked_path := BAKED, ambient_map := {}) -> int:
	if player == null or skel == null:
		return 0
	var root_node: Node = player.get_node_or_null(player.root_node)
	if root_node == null:
		return 0
	var dst_rel := str(root_node.get_path_to(skel))
	# the one-time bake loads instantly on the phone; the live bake
	# (a 30 fps full-rig pass per clip) is only the fallback
	var raw: AnimationLibrary = load(baked_path)
	var rewrite := false
	if raw == null or raw.get_animation_list().is_empty():
		raw = _live_bake(skel, dst_rel)
		if raw == null:
			return 0
	else:
		rewrite = true  # baked paths carry the hero_rpm-internal prefix
	var installed: int = raw.get_animation_list().size()
	if installed == 0:
		return 0
	_install_libs(player, raw, dst_rel, rewrite, ambient_map)
	return installed


## The fallback path: bake everything now (slow, seconds).
static func _live_bake(skel: Skeleton3D,
		dst_rel: String) -> AnimationLibrary:
	var scene: PackedScene = load(SOURCE)
	if scene == null:
		return null
	var holder := scene.instantiate()
	var src_player := _find(holder, AnimationPlayer) as AnimationPlayer
	var src_skel := _find(holder, Skeleton3D) as Skeleton3D
	if src_player == null or src_skel == null:
		holder.queue_free()
		return null
	var bone_map := _full_map(src_skel, skel)
	var raw := AnimationLibrary.new()
	# the source's clips may live in ANY library (probe-caught law)
	for lib_name in src_player.get_animation_library_list():
		var slib := src_player.get_animation_library(lib_name)
		for an in slib.get_animation_list():
			var anim: Animation = slib.get_animation(an)
			var copy := _retarget(anim, src_skel, skel, bone_map,
					dst_rel)
			if copy != null:
				raw.add_animation(an, copy)
	holder.queue_free()
	return raw


## Wire the (baked) clip library into the player: the "ual" raw
## library, the "combat" renames the five styles expect, and the
## ambient additions the style data's paths want.
static func _install_libs(player: AnimationPlayer,
		raw: AnimationLibrary, dst_rel: String, rewrite: bool,
		ambient_map := {}) -> void:
	if rewrite:
		# re-point every track to this player's skeleton path
		for an in raw.get_animation_list():
			var anim: Animation = raw.get_animation(an)
			for ti in anim.get_track_count():
				var p := String(anim.track_get_path(ti))
				var colon := p.find(":")
				if colon >= 0:
					anim.track_set_path(ti, "%s:%s" % [dst_rel,
							p.substr(colon + 1)])
	var combat := AnimationLibrary.new()
	var ambient_add: Array = []
	for an in raw.get_animation_list():
		var anim: Animation = raw.get_animation(an)
		# the importer strips a trailing "_Loop" from looping clips
		# (law: Pistol_Idle_Loop imports as Pistol_Idle) - compare
		# through the same normalization the map values use
		var an_norm: String = String(an).trim_suffix("_Loop")
		for want in CLIP_MAP:
			if String(CLP_NORM(CLIP_MAP[want])) == an_norm:
				if want in ["Idle_B", "Throw"]:
					ambient_add.append([want, anim])
				else:
					combat.add_animation(want, anim)
	if combat.get_animation_list().size() > 0:
		if player.has_animation_library("combat"):
			player.remove_animation_library("combat")
		player.add_animation_library("combat", combat)
	if player.has_animation_library("ual"):
		player.remove_animation_library("ual")
	player.add_animation_library("ual", raw)
	# a cast-specific alias set (e.g. the enemy's KayKit-era
	# names Idle_A / walking_a / Hit_A / Death_A -> UAL clips)
	if not ambient_map.is_empty():
		for alias in ambient_map:
			var src_name: String = String(CLP_NORM(
					ambient_map[alias]))
			for an in raw.get_animation_list():
				if String(an).trim_suffix("_Loop") == src_name:
					ambient_add.append([alias, raw.get_animation(an)])
					break
	# ambient: ADD to the existing library (mixamo_lib built it
	# with idle_b) - the style data wants "ambient/Idle_B" etc
	var ambient: AnimationLibrary = null
	if player.has_animation_library("ambient"):
		ambient = player.get_animation_library("ambient")
	else:
		ambient = AnimationLibrary.new()
		player.add_animation_library("ambient", ambient)
	for pair in ambient_add:
		var nm: String = pair[0]
		if ambient.has_animation(nm):
			ambient.remove_animation(nm)
		ambient.add_animation(nm, pair[1])


## The retarget: the world-orientation baker. Returns a new
## Animation with one rotation track per mapped dst bone, keys on
## a uniform 30 fps grid.
static func _retarget(anim: Animation, src: Skeleton3D, dst: Skeleton3D,
		bone_map: Dictionary, dst_rel: String,
		arm := Quaternion.IDENTITY) -> Animation:
	var bone_count := src.get_bone_count()
	# source rotation tracks: bone name -> [times, quats]
	var tracks := {}
	for ti in anim.get_track_count():
		if anim.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var p := String(anim.track_get_path(ti))
		var colon := p.find(":")
		if colon < 0:
			continue
		var times := PackedFloat32Array()
		var quats := []
		for k in anim.track_get_key_count(ti):
			times.append(anim.track_get_key_time(ti, k))
			quats.append(anim.track_get_key_value(ti, k))
		tracks[p.substr(colon + 1)] = [times, quats]
	# reference pair: S = UAL's rest globals (its T-pose),
	# D = RPM's constructed T-pose (arm chains lifted)
	var s_ref := {}
	var src_rest := {}
	for i in bone_count:
		s_ref[i] = src.get_bone_global_rest(i).basis \
				.get_rotation_quaternion()
		src_rest[i] = src.get_bone_rest(i).basis \
				.get_rotation_quaternion()
	var dst_rest_w := {}
	for j in dst.get_bone_count():
		dst_rest_w[j] = dst.get_bone_global_rest(j).basis \
				.get_rotation_quaternion()
	# dst bone idx -> src bone idx
	var src_by_dst := {}
	for i in bone_count:
		var nm := src.get_bone_name(i)
		if bone_map.has(nm):
			var dj := dst.find_bone(bone_map[nm])
			if dj >= 0:
				src_by_dst[dj] = i
	# THE LAW THIS BAKER EMBODIES: D(i) = ARM^-1 * S(i). The shared
	# reference IS the source's rest pose; the map is a world-frame
	# transfer (W_dst = ARM^-1 * W_src) and the destination's
	# RETARGETED PARENT CHAIN absorbs every convention difference
	# (UE axes, the 104-deg pelvis, A-vs-T). ARM is the
	# skeleton-node rotation relative to the rig root - Mixamo GLBs
	# carry the glTF axis fix (90 deg X + cm scale) on an Armature
	# NODE, outside the bone chain (probe-caught: without the term
	# Michelle's bake stands upright in CHAIN space and renders
	# lying 90 deg over). The hero's ARM is identity, so D = S
	# there - the law the punch gate proved.
	var d_ref := {}
	for dj in src_by_dst:
		d_ref[dj] = arm.inverse() * s_ref[src_by_dst[dj]]
	# output
	var step := 1.0 / 30.0
	var n_samples := int(anim.length / step) + 1
	var out := Animation.new()
	out.length = anim.length
	out.loop_mode = anim.loop_mode
	var out_tracks := {}
	for dj in src_by_dst:
		var ti := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(ti, "%s:%s" % [dst_rel,
				dst.get_bone_name(dj)])
		out_tracks[dj] = ti
	# the bake: source worlds (parents first), then the map and
	# destination locals (parents first)
	var w_src := {}
	var w_dst := {}
	var stamp := {}
	for sample in n_samples:
		var t := minf(sample * step, anim.length)
		for i in bone_count:
			var q := _sample_track(tracks, src.get_bone_name(i), t,
					src_rest[i])
			var pi := src.get_bone_parent(i)
			w_src[i] = (Quaternion.IDENTITY if pi < 0
					else w_src[pi]) * q
		for dj in dst.get_bone_count():
			if not src_by_dst.has(dj):
				continue
			var i2: int = src_by_dst[dj]
			var wj: Quaternion = d_ref[dj] * s_ref[i2].inverse() \
					* w_src[i2]
			var pj := dst.get_bone_parent(dj)
			var pw: Quaternion = dst_rest_w[pj] if pj >= 0 \
					else Quaternion.IDENTITY
			if pj >= 0 and int(stamp.get(pj, -1)) == sample:
				pw = w_dst[pj]
			out.track_insert_key(out_tracks[dj], t,
					pw.inverse() * wj)
			w_dst[dj] = wj
			stamp[dj] = sample
	return out


## A track sample: slerp between bracketing keys, clamped at the
## ends; bones without a track hold their rest.
static func _sample_track(tracks: Dictionary, bone: String, t: float,
		fallback: Quaternion) -> Quaternion:
	if not tracks.has(bone):
		return fallback
	var times: PackedFloat32Array = tracks[bone][0]
	var quats: Array = tracks[bone][1]
	var n := times.size()
	if n == 0:
		return fallback
	if t <= times[0]:
		return quats[0]
	if t >= times[n - 1]:
		return quats[n - 1]
	for k in range(1, n):
		if times[k] >= t:
			var f := (t - times[k - 1]) / maxf(0.0001,
					times[k] - times[k - 1])
			return (quats[k - 1] as Quaternion).slerp(quats[k], f)
	return quats[n - 1]


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
