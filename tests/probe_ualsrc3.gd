extends Node
## Numeric dissection of the retarget on the live hero: the
## retargeted punch's world heights (source truth: pelvis 0.83,
## head 1.46, feet 0.10) + the raw pelvis track key vs rests.
func _ready() -> void:
	var lib_u := load("res://scripts/player/ual_lib.gd")
	lib_u.MODE = 2
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await get_tree().create_timer(1.0).timeout
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var skel: Skeleton3D = hero.find_children("*", "Skeleton3D",
			true, false)[0]
	var ap: AnimationPlayer = hero.find_children("*",
			"AnimationPlayer", true, false)[0]
	var clip: Animation = ap.get_animation(
			"combat/Melee_Unarmed_Attack_Punch_A")
	print("RT clip len=%s" % clip.length)
	# the raw first-key pelvis value AFTER retarget + the Hips rest
	for ti in clip.get_track_count():
		var p := String(clip.track_get_path(ti))
		if p.ends_with(":Hips"):
			var q0: Quaternion = clip.track_get_key_value(ti, 0)
			var qr := skel.get_bone_rest(skel.find_bone("Hips")).basis.get_rotation_quaternion()
			print("RT hips track q0=%s rest=%s" % [q0, qr])
	# world heights through the punch
	var tree := hero.get_node_or_null("Rig/Locomotion") as AnimationTree
	if tree:
		tree.active = false
	for t in [0.0, 0.3, 0.6]:
		ap.play("combat/Melee_Unarmed_Attack_Punch_A")
		ap.seek(t * clip.length, true)
		ap.pause()
		await get_tree().process_frame
		await get_tree().process_frame
		var parts: Array = []
		for b in ["Hips", "Head", "LeftFoot", "RightFoot"]:
			var i: int = skel.find_bone(b)
			parts.append("%s y=%.2f" % [b,
					skel.get_bone_global_pose(i).origin.y])
		print("RT t=%s | %s" % [t, "  ".join(parts)])
	get_tree().quit(0)
