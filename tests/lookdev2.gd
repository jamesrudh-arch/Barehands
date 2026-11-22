extends Node3D
## B23 Milestone A lookdev: the code-built humanoid on a stage, seen
## before it replaces anything. Rows: body/hair/clothing variety, the
## hero look, poses (guard, punch, kick, phone), walk-cycle frames.
var _cam: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/lookdev")
	var env := WorldEnvironment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.09, 0.1, 0.14)
	sky.sky_horizon_color = Color(0.22, 0.2, 0.22)
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.background_sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 30, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var floor := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(30, 0.1, 12)
	fm.material = StandardMaterial3D.new()
	(fm.material as StandardMaterial3D).albedo_color = Color(0.16, 0.16, 0.18)
	floor.mesh = fm
	floor.position = Vector3(0, -0.05, 0)
	add_child(floor)

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = Vector3(0, 1.6, 6.4)
	_cam.look_at(Vector3(0, 1.0, 0))

	var CLS := load("res://scripts/humanoid.gd")
	# row 1: variety - slim/normal/heavy, hair styles, female, skirt
	var row1 := [
		{"height": 1.82, "build": 0, "hair_style": 1, "top": Color(0.16, 0.17, 0.21), "bottom": Color(0.12, 0.12, 0.15)},
		{"height": 1.78, "build": 1, "hair_style": 0, "top": Color(0.32, 0.2, 0.16), "bottom": Color(0.15, 0.17, 0.2), "jacket": Color(0.12, 0.11, 0.13), "jacket_on": true},
		{"height": 1.62, "build": 1, "female": true, "hair_style": 2, "top": Color(0.4, 0.16, 0.22), "bottom": Color(0.14, 0.14, 0.18), "skirt": true, "skin": Color(0.62, 0.45, 0.36)},
		{"height": 1.88, "build": 2, "hair_style": 4, "top": Color(0.24, 0.25, 0.18), "bottom": Color(0.2, 0.19, 0.16), "skin": Color(0.55, 0.38, 0.28)},
		{"height": 1.7, "build": 1, "female": true, "hair_style": 5, "hair": Color(0.09, 0.07, 0.06), "top": Color(0.18, 0.24, 0.32), "bottom": Color(0.12, 0.12, 0.15)},
		{"height": 1.76, "build": 1, "hair_style": 3, "hair": Color(0.03, 0.03, 0.04), "top": Color(0.5, 0.42, 0.2), "bottom": Color(0.3, 0.28, 0.24), "skin": Color(0.68, 0.5, 0.38)},
	]
	for i in row1.size():
		var h := Node3D.new()
		var script: Node = CLS.new()
		h.add_child(script)
		add_child(h)
		h.position = Vector3(-5.0 + i * 2.0, 0, 0)
		script.call("build", row1[i])
		h.look_at(Vector3(h.position.x, 0, 7.2), Vector3.UP)
	# row 2: the hero + poses
	var poses := ["Idle", "Walk", "Punch_Jab", "Kick_Code", "Hit_Chest", "Guard", "Phone"]
	for i in poses.size():
		var h := Node3D.new()
		var script: Node = CLS.new()
		h.add_child(script)
		add_child(h)
		h.position = Vector3(-5.0 + i * 2.0, 0, -2.2)
		script.call("build", {"height": 1.8, "build": 1, "hair_style": 1,
				"top": Color(0.13, 0.12, 0.15),
				"bottom": Color(0.11, 0.11, 0.13),
				"jacket": Color(0.1, 0.1, 0.12), "jacket_on": true})
		h.look_at(Vector3(h.position.x, 0, 6.4), Vector3.UP)
		h.set_meta("pose", [poses[i]])
		h.add_to_group("lookdev_pose")
		if poses[i] == "Walk":
			script.call("observe_speed", 1.4)
			script.call("play", "Walk", 0.2, 1.0)
		else:
			script.call("play", poses[i], 0.2, 1.0)
	# strikes are transient: re-fire them so the still catches one
	for i in 8:
		await get_tree().create_timer(0.45).timeout
		var idx := 0
		for h2 in get_tree().get_nodes_in_group("lookdev_pose"):
			var poses2: Array = h2.get_meta("pose", ["Idle"])
			h2.get_child(0).call("play", poses2[0], 0.2, 1.0)
			idx += 1
	# capture MID-HOLD: the instant after a re-fire the pose weight is
	# still ~0 and nothing reads (VLM round 3: punches invisible)
	await get_tree().create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/lookdev/humanoids.png")
	print("LOOKDEV2 saved /tmp/lookdev/humanoids.png")
	get_tree().quit(0)
