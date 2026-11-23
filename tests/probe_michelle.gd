extends Node
## S5.1c: does Michelle share the Mixamo family rests (verbatim
## clip share works) or does she need her own bake?
func _ready() -> void:
	var rigs := {
		"michelle": "res://assets/v2/cast/Michelle.glb",
		"xbot": "res://assets/v2/cast/Xbot.glb",
		"rpm": "res://assets/native/hero_rpm.tscn",
	}
	var data := {}
	for tag in rigs:
		var ps: PackedScene = load(rigs[tag])
		if ps == null:
			print("MCH %s load FAIL" % tag)
			continue
		var inst := ps.instantiate()
		add_child(inst)
		var skel: Skeleton3D = inst.find_children("*", "Skeleton3D",
				true, false)[0]
		var row := {}
		for b in ["Hips", "Spine", "LeftArm", "LeftForeArm",
				"LeftUpLeg", "Head"]:
			var i: int = skel.find_bone(b)
			if i >= 0:
				var q := skel.get_bone_rest(i).basis.get_rotation_quaternion()
				row[b] = "(%.3f,%.3f,%.3f,%.3f)" % [q.x, q.y, q.z, q.w]
		var hi: int = skel.find_bone("Head")
		var hp := skel.get_bone_global_rest(hi).origin
		row["head_h"] = "%.2f" % hp.y
		if tag == "michelle":
			for b in ["mixamorig_Hips", "mixamorig_Spine",
					"mixamorig_LeftArm", "mixamorig_LeftForeArm",
					"mixamorig_LeftUpLeg", "mixamorig_Head"]:
				var bi: int = skel.find_bone(b)
				if bi >= 0:
					var q := skel.get_bone_rest(bi).basis.get_rotation_quaternion()
					var head_name: String = b.trim_prefix("mixamorig_")
					print("MCH rest %-12s = (%.3f,%.3f,%.3f,%.3f)" % [
							head_name, q.x, q.y, q.z, q.w])
			var hi2: int = skel.find_bone("mixamorig_Head")
			print("MCH head global rest y=%.2f" % skel.get_bone_global_rest(hi2).origin.y)
		data[tag] = row
		inst.queue_free()
		await get_tree().process_frame
	for b in ["Hips", "Spine", "LeftArm", "LeftForeArm", "LeftUpLeg",
			"Head", "head_h"]:
		var m: String = data["michelle"].get(b, "-")
		var x: String = data["xbot"].get(b, "-")
		var r: String = data["rpm"].get(b, "-")
		print("MCH %-12s michelle=%s xbot=%s rpm=%s" % [b, m, x, r])
	get_tree().quit(0)
