extends Node
## S5.2p3 LOOKDEV GATE: the lit doorways + brick massing on the
## street, the skyline + queue people on the club strip.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	var dog := get_tree().create_timer(70.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	# 1) the street: hero ACROSS the road from the RAIN GLASS
	# (the threshold view drowned in interior - pull back for the
	# shopfront read) + diagnostics
	await Game.travel("neighbourhood", "start")
	await _wait_s(2.0)
	# the rig camera is a lottery from probes (extreme close-ups of
	# whichever NPC it passes) - SILENCE it (the fight-probe law)
	# and compose from VERIFIED-CLEAR road coordinates, dead-center
	# on the facade
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var oldcam := get_viewport().get_camera_3d()
	if oldcam:
		oldcam.current = false
	var composed := Camera3D.new()
	get_tree().current_scene.add_child(composed)
	await get_tree().process_frame
	composed.fov = 55.0
	composed.current = true
	# ABOVE THE LANES (probe-caught: a traffic sedan at z=-1.9 sat
	# 0.7m from the lens and filled the frame - the 'black' frames
	# were a car door)
	# ON THE ROAD CENTERLINE between the two lanes (z -+1.9): the
	# sedans pass either side; z=-7.5 was INSIDE the south front row
	# (the fronts stand at z=-7.2 - the 'black void' was a building
	# interior, probe-caught twice over)
	composed.global_position = Vector3(-6.0, 2.4, 0.0)
	composed.look_at(Vector3(-6.0, 2.1, 7.2))
	await _wait_s(0.5)
	var cam := composed
	var front := get_tree().current_scene.find_children(
			"Front_*", "Node3D", false, false)
	var bands := 0
	var spills := 0
	for f in front:
		bands += f.find_children("WindowBand", "", false,
				false).size()
		spills += f.find_children("DoorSpill", "", false,
				false).size()
	print("LOOKDEV cam=%s fronts=%d bands=%d spills=%d" % [
			str(cam.global_position), front.size(), bands, spills])
	var active := get_viewport().get_camera_3d()
	print("LOOKDEV active_cam=%s pos=%s yaw=%.2f fwd=%s" % [
			active.name, str(active.global_position),
			active.rotation.y,
			str(-active.global_transform.basis.z)])
	# project the RAIN GLASS front center into screen space
	var rg: Node3D = null
	for f in front:
		if "RAIN" in f.name:
			rg = f
	if rg:
		var target := rg.global_position + Vector3(0, 2.4, 0)
		var behind := active.is_position_behind(target)
		var sp := active.unproject_position(target)
		print("LOOKDEV rain_front world=%s behind=%s screen=%s vp=%s" % [
				str(rg.global_position), behind, str(sp),
				str(get_viewport().size)])
	for i in 2:
		var ac := get_viewport().get_camera_3d()
		print("LOOKDEV capture%d active=%s pos=%s" % [i, ac.name,
				str(ac.global_position)])
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/door_%02d.png" % i)
		pass
		await _wait_s(0.6)
	print("LOOKDEV door captured")
	# 2) the club: composed from the road at the VELVET ROOM curb
	# (venue + queue + skyline behind)
	await Game.travel("club_district", "start")
	await _wait_s(2.0)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var oldcam2 := get_viewport().get_camera_3d()
	if oldcam2:
		oldcam2.current = false
	var cam2 := Camera3D.new()
	get_tree().current_scene.add_child(cam2)
	await get_tree().process_frame
	cam2.fov = 55.0
	cam2.current = true
	cam2.global_position = Vector3(-31.0, 1.7, -1.2)
	cam2.look_at(Vector3(-42.0, 2.6, -7.5))
	await _wait_s(0.5)
	for i in 2:
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/club_%02d.png" % i)
		await _wait_s(0.6)
	print("LOOKDEV club captured")
	get_tree().quit(0)
