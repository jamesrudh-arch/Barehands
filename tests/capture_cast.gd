extends Node

## S5.1 THE CAST INSPECTION: what do the new realistic rigs give us
## in Godot - bones, materials, textures, embedded animations - and
## do they PASS the studio visual gate? Renders both new rigs in the
## neutral studio for the vision-model judgement.

const CAST := ["res://assets/v2/cast/readyplayer.me.glb",
		"res://assets/v2/cast/nemetona.glb",
		"res://assets/v2/cast/kira.glb",
		"res://assets/v2/cast/Xbot.glb",
		"res://assets/v2/cast/facecap.glb"]


func _ready() -> void:
	for i in 6:
		await get_tree().process_frame
	var world := Node3D.new()
	world.name = "Studio"
	add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 3.4)
	cam.fov = 45.0
	world.add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 2.0, 2.0)
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 1.1
	fill.omni_range = 12.0
	world.add_child(fill)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24, 24)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.44, 0.44, 0.46)
	pm.material = m
	floor_m.mesh = pm
	world.add_child(floor_m)

	for i in CAST.size():
		var packed: PackedScene = load(CAST[i])
		if packed == null:
			print("CAST %s FAILED TO LOAD" % CAST[i])
			continue
		var rig: Node3D = packed.instantiate()
		rig.name = "Rig_%d" % i
		rig.position = Vector3(i * 1.6 - 0.8, 0, 0)
		world.add_child(rig)
		# the honest inventory
		var skel := rig.find_children("*", "Skeleton3D", true,
				false)[0] as Skeleton3D if rig.find_children(
				"*", "Skeleton3D", true, false).size() > 0 else null
		var anims: Array = []
		var ap := rig.find_children("*", "AnimationPlayer", true,
				false)
		if ap.size() > 0:
			anims = (ap[0] as AnimationPlayer).get_animation_list()
		var mats := {}
		for mi in rig.find_children("*", "MeshInstance3D", true,
				false):
			for s in (mi as MeshInstance3D).get_surface_override_material_count():
				var mat = (mi as MeshInstance3D).get_active_material(s)
				if mat is StandardMaterial3D:
					mats[mat] = (mat as StandardMaterial3D).albedo_texture != null
		var textured := 0
		for k in mats:
			if mats[k]:
				textured += 1
		var root_bones := []
		if skel != null:
			for b in skel.get_bone_count():
				if skel.get_bone_parent(b) == -1:
					root_bones.append(skel.get_bone_name(b))
		print("CAST %s: bones=%d root=%s anims=%s mats=%d textured=%d height_hint=%s" % [
				CAST[i].get_file(), skel.get_bone_count() if skel else -1,
				root_bones, anims, mats.size(), textured,
				"" if skel == null else "has_skel"])
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shots/10_cast_studio.png")
	print("CAST STUDIO DONE %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit(0)
