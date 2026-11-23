extends Node
## S5.1b BAKE: runs the world-orientation baker over the UAL pack
## ONCE and saves assets/native/ual_baked.res (the phone loads that
## instantly; no per-mount bake). Then NUMERICALLY gates the
## result on the hero's own skeleton: Punch_Jab world heights
## (source truth: pelvis 0.83 / head 1.46 / feet 0.10) and the
## hand travel a real jab must show.

func _ready() -> void:
	var lib := load("res://scripts/player/ual_lib.gd")
	# the destination rig (the bundled native hero)
	var hscene: PackedScene = load("res://assets/native/hero_rpm.tscn")
	var hero := hscene.instantiate()
	add_child(hero)
	var dst: Skeleton3D = hero.find_children("*", "Skeleton3D",
			true, false)[0]
	# the source
	var sscene: PackedScene = load("res://assets/UAL1_Standard.glb")
	var src_holder := sscene.instantiate()
	add_child(src_holder)
	var src_player: AnimationPlayer = src_holder.find_children("*",
			"AnimationPlayer", true, false)[0]
	var src: Skeleton3D = src_holder.find_children("*",
			"Skeleton3D", true, false)[0]
	var bone_map: Dictionary = lib._full_map(src, dst)
	print("BAKE map size=%d" % bone_map.size())
	var baked := AnimationLibrary.new()
	var count := 0
	for lname in src_player.get_animation_library_list():
		var slib := src_player.get_animation_library(lname)
		for an in slib.get_animation_list():
			var anim: Animation = slib.get_animation(an)
			var copy: Animation = lib._retarget(anim, src, dst,
					bone_map, dst.name)
			if copy != null:
				baked.add_animation(an, copy)
				count += 1
	print("BAKE baked=%d clips" % count)
	var err := ResourceSaver.save(baked,
			"res://assets/native/ual_baked.res")
	print("BAKE save err=%s" % err)

	# --- the numeric gate on Punch_Jab -------------------------
	var jab: Animation = baked.get_animation("Punch_Jab")
	for b in dst.get_bone_count():
		dst.reset_bone_pose(b)
	# gather per-bone key streams from the baked tracks
	var streams := {}
	for ti in jab.get_track_count():
		var p := String(jab.track_get_path(ti))
		var bone := p.substr(p.find(":") + 1)
		var qs := []
		var ts := []
		for k in jab.track_get_key_count(ti):
			ts.append(jab.track_get_key_time(ti, k))
			qs.append(jab.track_get_key_value(ti, k))
		streams[bone] = [ts, qs]
	var keys_n: int = streams.get("Hips", [[], []])[0].size()
	print("BAKE jab keys=%d len=%.2f" % [keys_n, jab.length])
	for frac in [0.0, 0.3, 0.6, 0.9]:
		var idx: int = int(frac * float(keys_n - 1))
		for b in dst.get_bone_count():
			dst.reset_bone_pose(b)
		var applied := 0
		for bone in streams:
			var bi: int = dst.find_bone(bone)
			if bi < 0:
				continue
			var qs: Array = streams[bone][1]
			if idx < qs.size():
				dst.set_bone_pose_rotation(bi, qs[idx])
				applied += 1
		await get_tree().process_frame
		await get_tree().process_frame
		var parts: Array = []
		for b in ["Hips", "Head", "LeftFoot", "LeftHand", "RightHand"]:
			var bi: int = dst.find_bone(b)
			var gp := dst.get_bone_global_pose(bi)
			parts.append("%s(%.2f,%.2f,%.2f)" % [b, gp.origin.x,
					gp.origin.y, gp.origin.z])
		print("BAKE jab t=%.0f%% | %s [applied %d]" % [frac * 100.0,
				" ".join(PackedStringArray(parts)), applied])
	# hand travel across the whole clip (a real jab: 0.3-0.8 m)
	var travel := {"LeftHand": 0.0, "RightHand": 0.0}
	var origin := {}
	for hand in travel:
		var bi: int = dst.find_bone(hand)
		origin[hand] = dst.get_bone_global_pose(bi).origin
	for idx in keys_n:
		for b in dst.get_bone_count():
			dst.reset_bone_pose(b)
		for bone in streams:
			var bi: int = dst.find_bone(bone)
			if bi < 0:
				continue
			var qs: Array = streams[bone][1]
			if idx < qs.size():
				dst.set_bone_pose_rotation(bi, qs[idx])
		await get_tree().process_frame
		for hand in travel:
			var bi: int = dst.find_bone(hand)
			var gp := dst.get_bone_global_pose(bi).origin
			travel[hand] = maxf(travel[hand],
					origin[hand].distance_to(gp))
	print("BAKE jab hand travel L=%.2f R=%.2f" % [travel["LeftHand"],
			travel["RightHand"]])
	get_tree().quit(0)
