extends Node
## Ground truth: play Punch_Jab on the UAL's OWN skeleton (no
## retarget) and print world bone heights. A standing human jab:
## pelvis ~0.9-1.1 m, head ~1.55-1.75 m, feet ~0. If the SOURCE
## itself is broken as imported, no retarget math can fix it.
func _ready() -> void:
	var scene: PackedScene = load("res://assets/UAL1_Standard.glb")
	var holder := scene.instantiate()
	add_child(holder)
	var skel: Skeleton3D = holder.find_children("*", "Skeleton3D",
			true, false)[0]
	var ap: AnimationPlayer = holder.find_children("*",
			"AnimationPlayer", true, false)[0]
	var h := ap.get_animation_library("").get_animation("Punch_Jab")
	print("SRC clip len=%s tracks=%d" % [h.length, h.get_track_count()])
	for t in [0.0, 0.3, 0.6, 0.9]:
		ap.play("Punch_Jab")
		ap.seek(t * h.length, true)
		ap.pause()
		await get_tree().process_frame
		await get_tree().process_frame
		var parts: Array = []
		for b in ["pelvis", "Head", "foot_l", "foot_r"]:
			var i: int = skel.find_bone(b)
			var gp := skel.get_bone_global_pose(i)
			parts.append("%s y=%.2f" % [b, gp.origin.y])
		print("SRC t=%s | %s" % [t, "  ".join(parts)])
	# the rest pose heights for reference
	var parts2: Array = []
	for b in ["pelvis", "Head", "foot_l", "foot_r"]:
		var i: int = skel.find_bone(b)
		parts2.append("%s restY=%.2f" % [b,
				skel.get_bone_global_rest(i).origin.y])
	print("SRC REST | %s" % "  ".join(parts2))
	get_tree().quit(0)
