extends Node

## S5.2 THE LIGHT PROOF: does an OmniLight actually illuminate
## ground under llvmpipe, and does the street's ground brighten
## near its lamp lights? Pixel-measured, not eyeballed.

func _ready() -> void:
	for i in 6:
		await get_tree().process_frame
	# --- isolation control: plane + one omni, nothing else
	var iso := Node3D.new()
	iso.name = "Iso"
	add_child(iso)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.0, 10.0)
	cam.fov = 50.0
	cam.rotation_degrees = Vector3(-50, 0, 0)
	iso.add_child(cam)
	cam.current = true
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.35, 0.38)
	m.roughness = 0.3
	pm.material = m
	plane.mesh = pm
	iso.add_child(plane)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 4.4, 4.0)
	omni.light_color = Color(1.0, 0.7, 0.4)
	omni.light_energy = 1.5
	omni.omni_range = 14.0
	iso.add_child(omni)
	await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shots/iso_light.png")
	# the pool under the lamp is screen-centre; the far corner is
	# upper-left
	var g := Image.new()
	g.copy_from(img)
	g.convert(Image.FORMAT_L8)
	var near_l := _mean(g, g.get_width() * 0.45, g.get_height() * 0.62,
			40)
	var far_l := _mean(g, g.get_width() * 0.08, g.get_height() * 0.08,
			40)
	print("LIGHTPROOF iso near=%.1f far=%.1f ratio=%.2f" % [near_l,
			far_l, near_l / maxf(far_l, 1.0)])
	# --- the street itself
	iso.queue_free()
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	await get_tree().create_timer(0.3).timeout
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	await get_tree().create_timer(1.0).timeout
	# camera high over the lamp at x=16 looking straight down at the
	# ground under it
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)  # it re-asserts make_current each frame
	var old_cam := get_viewport().get_camera_3d()
	if old_cam != null:
		old_cam.current = false
	var cam2 := Camera3D.new()
	get_tree().current_scene.add_child(cam2)
	cam2.global_position = Vector3(16.0, 8.0, 6.8)
	cam2.rotation_degrees = Vector3(-90, 0, 0)
	cam2.fov = 60.0
	cam2.current = true
	await get_tree().create_timer(0.3).timeout
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("/tmp/shots/street_light.png")
	var g2 := Image.new()
	g2.copy_from(img2)
	g2.convert(Image.FORMAT_L8)
	var near2 := _mean(g2, g2.get_width() * 0.5, g2.get_height() * 0.5,
			60)
	var far2 := _mean(g2, g2.get_width() * 0.08, g2.get_height() * 0.5,
			60)
	print("LIGHTPROOF street under_lamp=%.1f west_50m=%.1f ratio=%.2f" % [
			near2, far2, near2 / maxf(far2, 1.0)])
	get_tree().quit(0)


func _mean(img: Image, cx: int, cy: int, half: int) -> float:
	var total := 0.0
	var n := 0
	for y in range(cy - half, cy + half):
		for x in range(cx - half, cx + half):
			if x < 0 or y < 0 or x >= img.get_width() \
					or y >= img.get_height():
				continue
			total += img.get_pixel(x, y).r8
			n += 1
	return total / maxf(n, 1.0)
