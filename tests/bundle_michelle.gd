extends Node
## S5.1c: bundle Michelle as a native cast scene with CLEAN bone
## names (mixamorig_ stripped) so every library (the bake, the
## combat renames, the KayKit-era aliases) addresses her by the
## family convention. LAWS (probe-caught): (1) skins bind BY NAME -
## renaming bones without renaming the Skin's bind names collapses
## the mesh to a blob at the root; (2) pack the GLB's OWN root -
## re-parenting children drops the cm->m scale on the root.
func _ready() -> void:
	var ps: PackedScene = load("res://assets/v2/cast/Michelle.glb")
	var inst := ps.instantiate()
	add_child(inst)
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D",
			true, false)[0]
	var renamed := 0
	for b in skel.get_bone_count():
		var n := skel.get_bone_name(b)
		if n.begins_with("mixamorig_"):
			skel.set_bone_name(b, n.trim_prefix("mixamorig_"))
			renamed += 1
	print("BUNDLE renamed=%d of %d bones" % [renamed,
			skel.get_bone_count()])
	# rebind the skins to the renamed bones
	var binds := 0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = mi.skin
		if skin == null:
			continue
		for i in skin.get_bind_count():
			var bn := String(skin.get_bind_name(i))
			if bn.begins_with("mixamorig_"):
				skin.set_bind_name(i, StringName(
						bn.trim_prefix("mixamorig_")))
				binds += 1
	print("BUNDLE rebinds=%d" % binds)
	# the material dump (is she pink because the importer dropped
	# her specular-glossiness materials?)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = mi.mesh
		if mesh == null:
			continue
		for s_idx in mesh.get_surface_count():
			var mat: Material = mesh.surface_get_material(s_idx)
			var albedo_tex: Texture2D = null
			var cls := "?"
			if mat is StandardMaterial3D:
				cls = "std"
				albedo_tex = (mat as StandardMaterial3D).albedo_texture
			elif mat != null:
				cls = mat.get_class()
			print("BUNDLE surf %s/%d mat=%s albedo=%s" % [
					mi.name, s_idx, cls,
					albedo_tex.resource_path if albedo_tex else "-"])
	var packed := PackedScene.new()
	packed.pack(inst)
	var err := ResourceSaver.save(packed,
			"res://assets/native/cast_michelle.tscn")
	print("BUNDLE save err=%s" % err)
	get_tree().quit(0)
