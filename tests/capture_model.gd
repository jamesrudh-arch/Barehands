extends Node

## renders the native hero rig + the thug rig alone in a neutral
## studio (grey world, three-point light) - separating MODEL quality
## from in-game presentation for the overhaul audit.

func _ready() -> void:
	for i in 6:
		await get_tree().process_frame
	var world := Node3D.new()
	world.name = "Studio"
	add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.35, 3.0)
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 2.0, 2.0)
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 1.2
	fill.omni_range = 12.0
	world.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(2.0, 2.2, -2.0)
	rim.light_color = Color(1.0, 0.9, 0.8)
	rim.light_energy = 1.0
	rim.omni_range = 12.0
	world.add_child(rim)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.42, 0.44)
	pm.material = m
	floor.mesh = pm
	world.add_child(floor)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(40, 20, 0.5)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.5, 0.5, 0.52)
	bm.material = m2
	bg.mesh = bm
	bg.position = Vector3(0, 10, -6.0)
	world.add_child(bg)
	# S5.1 diagnosis: the bundled hero vs the raw GLB, side by side
	var hero: Node3D = load(
			"res://assets/native/hero_rpm.tscn").instantiate()
	hero.name = "HeroBundle"
	hero.position = Vector3(-0.9, 0, 0)
	world.add_child(hero)
	var raw: Node3D = load(
			"res://assets/v2/cast/readyplayer.me.glb").instantiate()
	raw.name = "HeroRaw"
	raw.position = Vector3(0.9, 0, 0)
	world.add_child(raw)
	print("MODEL mesh instances: bundle=%d raw=%d" % [
			hero.find_children("*", "MeshInstance3D", true, false).size(),
			raw.find_children("*", "MeshInstance3D", true, false).size()])
	# the thug beside it
	var thug: Node3D = load(
			"res://assets/native/thug_kaykit_barbarian.tscn").instantiate()
	thug.name = "Thug"
	thug.position = Vector3(1.5, 0, -0.3)
	world.add_child(thug)
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shots/09_model_studio.png")
	print("STUDIO DONE %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit(0)
