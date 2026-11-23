extends Node
## One-shot scene inspector: dump the RAIN GLASS front's children
## (positions, sizes, emission) - the lookdev truth finder.
func _ready() -> void:
	var dog := get_tree().create_timer(60.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	print("INSPECT travel done")
	await get_tree().create_timer(2.0).timeout
	print("INSPECT waiting done")
	for f in get_tree().current_scene.find_children("Front_*",
			"Node3D", true, false):
		if "RAIN" not in f.name:
			continue
		print("FRONT %s pos=%s rot=%s" % [f.name,
				str(f.global_position), str(f.rotation)])
		for c in f.get_children():
			var extra := ""
			if c is MeshInstance3D:
				var mesh: Mesh = (c as MeshInstance3D).mesh
				var mat: StandardMaterial3D = null
				if mesh is BoxMesh:
					extra = " size=%s" % str((mesh as BoxMesh).size)
					mat = (mesh as BoxMesh).material as StandardMaterial3D
				elif mesh is PrimitiveMesh:
					mat = (mesh as PrimitiveMesh).material as StandardMaterial3D
				if mat:
					extra += " emis=%s e=%.2f" % [
							str(mat.emission_enabled),
							mat.emission_energy_multiplier]
			print("  child %s pos=%s%s" % [c.name,
					str(c.position), extra])
	get_tree().quit(0)
