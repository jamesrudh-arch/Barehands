extends Node
## S5.1b proof: the UAL retarget drives the RPM rig with real
## combat motion - pose deltas measured + a mid-swing frame saved.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _arm_hash(skel: Skeleton3D) -> int:
	var h := 0
	for b in ["LeftArm", "RightArm", "LeftForeArm", "Spine1"]:
		var i := skel.find_bone(b)
		var q := skel.get_bone_pose(i).basis.get_rotation_quaternion()
		h = hash([h, snappedf(q.x, 0.01), snappedf(q.y, 0.01),
				snappedf(q.z, 0.01), snappedf(q.w, 0.01)])
	return h

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.0)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var skel := hero.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := hero.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var libs := []
	for l in ap.get_animation_library_list():
		libs.append("%s(%d)" % [l, ap.get_animation_library(l).get_animation_list().size()])
	print("UAL libs: %s" % " ".join(libs))
	var rlist: Array = []
	for rn in ap.get_animation_library("ual").get_animation_list():
		rlist.append(rn)
	print("UAL raw list: %s" % str(rlist))
	var lib_u := load("res://scripts/player/ual_lib.gd")
	for probe_name in ["Pistol_Idle_Loop", "Push_Loop", "Idle_Talking_Loop", "Sword_Idle"]:
		var comp := 0
		for rn2 in rlist:
			if String(rn2) == probe_name:
				comp = 1
		print("UAL cmp %s in raw = %d" % [probe_name, comp])
	var clist: Array = []
	for cn in ap.get_animation_library("combat").get_animation_list():
		clist.append(cn)
	print("UAL combat list: %s" % str(clist))
	var alist: Array = []
	for an2 in ap.get_animation_library("ambient").get_animation_list():
		alist.append(an2)
	print("UAL ambient list: %s" % str(alist))
	for want in ["combat/Melee_Unarmed_Attack_Punch_A", "combat/Melee_2H_Attack_Slice", "ambient/Idle_B", "ual/Roll"]:
		print("UAL has %s = %s" % [want, ap.has_animation(want)])
	var tree := hero.get_node_or_null("Rig/Locomotion") as AnimationTree
	if tree:
		tree.active = false
	# rest comparison (the record: how far apart the rigs are)
	var src_scene: PackedScene = load("res://assets/UAL1_Standard.glb")
	var src_root := src_scene.instantiate()
	var src_skel := src_root.find_children("*", "Skeleton3D", true, false)[0]
	for pair in [["pelvis", "Hips"], ["spine_01", "Spine"],
			["upperarm_l", "LeftArm"], ["thigh_l", "LeftUpLeg"]]:
		var qi: int = src_skel.find_bone(String(pair[0]))
		var qj: int = skel.find_bone(String(pair[1]))
		print("UAL rest %s=%s rpm %s=%s" % [pair[0],
				src_skel.get_bone_rest(qi).basis.get_rotation_quaternion(),
				pair[1], skel.get_bone_rest(qj).basis.get_rotation_quaternion()])
	src_root.queue_free()
	var idle_hash := _arm_hash(skel)
	ap.play("combat/Melee_Unarmed_Attack_Punch_A")
	await _wait_s(0.45)
	var punch_hash := _arm_hash(skel)
	print("UAL pose-delta idle->punch: %s" % (idle_hash != punch_hash))
	# the capture camera (silence the rig first - its law)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	await get_tree().process_frame
	cam.fov = 45.0
	cam.current = true
	# the jab's frames at REAL playback, sampled at the numeric
	# gate's landmarks (guard 0.10 / extension peak 0.26 / recover
	# 0.45) - angle A, then the peak from angle B
	cam.global_position = hero.global_position + Vector3(2.0, 1.9, 3.4)
	cam.look_at(hero.global_position + Vector3(0, 1.35, 0))
	await get_tree().process_frame
	for t in [0.10, 0.26, 0.45]:
		ap.play("combat/Melee_Unarmed_Attack_Punch_A")
		await _wait_s(t)
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/ual_punch_%02d.png" % int(t * 100))
	ap.play("combat/Melee_Unarmed_Attack_Punch_A")
	await _wait_s(0.26)
	cam.global_position = hero.global_position + Vector3(-2.4, 1.7, 2.8)
	cam.look_at(hero.global_position + Vector3(0, 1.4, 0))
	await _wait_s(0.06)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/ual_punch_peak_b.png")
	await _wait_s(0.1)
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ual_punch.png")
	print("UAL shot saved")
	get_tree().quit(0)
