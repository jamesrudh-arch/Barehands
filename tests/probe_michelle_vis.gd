extends Node
## S5.1c: render-gate the Michelle bake. Applies the baked Idle,
## Walk and Punch_Jab directly to the bundled skeleton and saves
## frames - the node-tree scale normalizes the render, so the
## screenshots are the truth (bone-space numbers are cm).
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
				var qa: Quaternion = anim.track_get_key_value(ti, k - 1) if k > 0 else q
				var qb: Quaternion = anim.track_get_key_value(ti, k)
				var f := 0.0 if k == 0 else (t - anim.track_get_key_time(ti, k - 1)) / maxf(0.0001, kt - anim.track_get_key_time(ti, k - 1))
				q = qa.slerp(qb, clampf(f, 0.0, 1.0))
				break
			q = anim.track_get_key_value(ti, k)
		skel.set_bone_pose_rotation(bi, q)

func _ready() -> void:
	var ps: PackedScene = load("res://assets/native/cast_michelle.tscn")
	var inst := ps.instantiate()
	add_child(inst)
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D",
			true, false)[0]
	# the node-tree scale read (for the record)
	var arm := skel.get_parent()
	print("MVIS armature scale=%s rot=%s" % [arm.scale,
			arm.rotation_degrees])
	var baked: AnimationLibrary = load(
			"res://assets/native/ual_baked_michelle.res")
	var cam := Camera3D.new()
	cam.position = Vector3(3.0, 1.1, 0.6)
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	await get_tree().process_frame
	cam.look_at(Vector3(0, 1.0, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.25, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.4, 0.5)
	e.ambient_light_energy = 1.0
	world.environment = e
	add_child(world)
	# leg-motion numeric proof (chain space; variance = animated)
	var walk: Animation = baked.get_animation("Walk")
	for t in [0.0, 0.25, 0.5, 0.75]:
		_apply(walk, skel, t * walk.length)
		await get_tree().process_frame
		var fi: int = skel.find_bone("LeftFoot")
		var ri: int = skel.find_bone("RightFoot")
		print("MVIS walk t=%.2f Lfoot=(%.1f,%.1f,%.1f) Rfoot=(%.1f,%.1f,%.1f)" % [
				t, skel.get_bone_global_pose(fi).origin.x,
				skel.get_bone_global_pose(fi).origin.y,
				skel.get_bone_global_pose(fi).origin.z,
				skel.get_bone_global_pose(ri).origin.x,
				skel.get_bone_global_pose(ri).origin.y,
				skel.get_bone_global_pose(ri).origin.z])
	for shot in [["Idle", 0.5], ["Walk", 0.0], ["Walk", 0.35],
			["Walk", 0.65], ["Punch_Jab", 0.15], ["Punch_Jab", 0.26],
			["Punch_Jab", 0.42]]:
		var anim: Animation = baked.get_animation(shot[0])
		_apply(anim, skel, float(shot[1]))
		await get_tree().process_frame
		await get_tree().process_frame
		var fn := "%s_%02d" % [shot[0], int(shot[1] * 100)]
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/mvis_%s.png" % fn)
		print("MVIS shot %s saved" % fn)
	get_tree().quit(0)
