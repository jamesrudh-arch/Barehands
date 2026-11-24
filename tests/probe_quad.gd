extends Node3D

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.55)
	mat.emission_energy_multiplier = 4.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 1: plain quad, no rotation
	var q1 := MeshInstance3D.new()
	var m1 := QuadMesh.new()
	m1.size = Vector2(2, 1)
	m1.material = mat
	q1.mesh = m1
	q1.position = Vector3(0, 2, -8)
	add_child(q1)
	# 2: quad rotated 90 (the train window case)
	var q2 := MeshInstance3D.new()
	var m2 := QuadMesh.new()
	m2.size = Vector2(2, 1)
	m2.material = mat.duplicate()
	q2.mesh = m2
	q2.rotation.y = PI / 2.0
	q2.position = Vector3(-4, 2, -8)
	add_child(q2)
	# 3: emissive box (the pylon-material case but emissive)
	var b1 := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(2, 1, 0.1)
	mb.material = mat.duplicate()
	b1.mesh = mb
	b1.position = Vector3(4, 2, -8)
	add_child(b1)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2, 0)
	cam.current = true
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shots/probe_quad.png")
	get_tree().quit(0)
