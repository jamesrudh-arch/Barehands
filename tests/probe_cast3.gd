extends Node
## S5.1c cast decision: rests + a render of the three candidates.
## The enemy needs a realistic textured human whose rig either
## matches the RPM family (verbatim share + the existing bake) or
## bakes cleanly.
const CANDS := {
	"michelle": "res://assets/v2/cast/Michelle.glb",
	"soldier": "res://assets/v2/cast/Soldier.glb",
	"xbot": "res://assets/v2/cast/Xbot.glb",
}

func _ready() -> void:
	# a light + camera to render each candidate
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 3.2)
	cam.fov = 45.0
	add_child(cam)
	cam.current = true
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
	for tag in CANDS:
		var ps: PackedScene = load(CANDS[tag])
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		var skel: Skeleton3D = inst.find_children("*", "Skeleton3D",
				true, false)[0]
		var prefix := "mixamorig_"
		if skel.find_bone("mixamorig_Hips") < 0:
			prefix = ""
		var hips_i: int = skel.find_bone(prefix + "Hips")
		var head_i: int = skel.find_bone(prefix + "Head")
		var arm_i: int = skel.find_bone(prefix + "LeftArm")
		var foot_i: int = skel.find_bone(prefix + "LeftFoot")
		var qh := skel.get_bone_rest(hips_i).basis.get_rotation_quaternion()
		var qa := skel.get_bone_rest(arm_i).basis.get_rotation_quaternion()
		var gh := skel.get_bone_global_rest(head_i).origin
		var gf := skel.get_bone_global_rest(foot_i).origin
		print("CAST %-9s prefix=%s hips=(%.3f,%.3f,%.3f,%.3f) LeftArm=(%.3f,%.3f,%.3f,%.3f) head_y=%.2f foot_y=%.2f" % [
				tag, prefix, qh.x, qh.y, qh.z, qh.w, qa.x, qa.y, qa.z,
				qa.w, gh.y, gf.y])
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/cast_%s.png" % tag)
		remove_child(inst)
		inst.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
