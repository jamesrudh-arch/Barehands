extends Node
## S5.1b amplitude check: the jab's hand travel on UAL's OWN rig
## vs the baked clip on the RPM rig. If the bake damps the motion
## this shows it; if both are ~equal the clip is just compact.

func _apply(anim: Animation, skel: Skeleton3D, t: float) -> void:
	for b in skel.get_bone_count():
		skel.reset_bone_pose(b)
	for ti in anim.get_track_count():
		if anim.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var p := String(anim.track_get_path(ti))
		var bone := p.substr(p.find(":") + 1)
		var bi: int = skel.find_bone(bone)
		if bi < 0:
			continue
		var n := anim.track_get_key_count(ti)
		var q: Quaternion = anim.track_get_key_value(ti, n - 1)
		for k in n:
			var kt: float = anim.track_get_key_time(ti, k)
			if kt >= t:
				var pk: float = anim.track_get_key_time(ti, k - 1) if k > 0 else 0.0
				var f := (t - pk) / maxf(0.0001, kt - pk) if k > 0 else 0.0
				var qa: Quaternion = anim.track_get_key_value(ti, k - 1) if k > 0 else q
				var qb: Quaternion = anim.track_get_key_value(ti, k)
				q = qa.slerp(qb, clampf(f, 0.0, 1.0))
				break
			q = anim.track_get_key_value(ti, k)
		skel.set_bone_pose_rotation(bi, q)

func _report(tag: String, anim: Animation, skel: Skeleton3D,
		hand: String) -> void:
	var bi: int = skel.find_bone(hand)
	var origin := Vector3.ZERO
	var peak := Vector3.ZERO
	var peak_d := 0.0
	for i in 10:
		var t := anim.length * i / 9.0
		_apply(anim, skel, t)
		await get_tree().process_frame
		var gp := skel.get_bone_global_pose(bi).origin
		if i == 0:
			origin = gp
			peak = gp
		if origin.distance_to(gp) > peak_d:
			peak_d = origin.distance_to(gp)
			peak = gp
	print("JAB %s travel=%.2f peak=(%.2f,%.2f,%.2f) from=(%.2f,%.2f,%.2f)"
			% [tag, peak_d, peak.x, peak.y, peak.z, origin.x, origin.y,
					origin.z])

func _ready() -> void:
	# source rig, its own clip
	var sscene: PackedScene = load("res://assets/UAL1_Standard.glb")
	var src_holder := sscene.instantiate()
	add_child(src_holder)
	var src: Skeleton3D = src_holder.find_children("*", "Skeleton3D",
			true, false)[0]
	var sap: AnimationPlayer = src_holder.find_children("*",
			"AnimationPlayer", true, false)[0]
	var jab_src: Animation = sap.get_animation_library("").get_animation(
			"Punch_Jab")
	await _report("src-R", jab_src, src, "hand_r")
	await _report("src-L", jab_src, src, "hand_l")
	src_holder.queue_free()
	# baked clip on the hero rig
	var hscene: PackedScene = load("res://assets/native/hero_rpm.tscn")
	var hero := hscene.instantiate()
	add_child(hero)
	var dst: Skeleton3D = hero.find_children("*", "Skeleton3D",
			true, false)[0]
	var baked: AnimationLibrary = load("res://assets/native/ual_baked.res")
	var jab_dst: Animation = baked.get_animation("Punch_Jab")
	await _report("bake-R", jab_dst, dst, "RightHand")
	await _report("bake-L", jab_dst, dst, "LeftHand")
	get_tree().quit(0)
