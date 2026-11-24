extends Node

## THE S5.19 GATE: the filling station + the river, captured for
## the VLM read (same boot pattern as the other gates).

const OUT := "/tmp/shots7"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	Settings.set_value("skip_intro", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	# --- SHOT 1: the filling station at the east approach
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.2)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var cam := Camera3D.new()
	cam.name = "GateCam"
	get_tree().current_scene.add_child.call_deferred(cam)
	await get_tree().process_frame
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	cam.current = true
	# the PLAYER's vantage: walking the street past the station
	cam.global_position = Vector3(24.0, 1.7, 5.5)
	cam.look_at(Vector3(30.5, 3.4, 8.0))
	cam.fov = 60.0
	await _wait_s(0.6)
	await _snap("filling_station")
	# --- SHOT 2: the river (water shader + fish + wakes + bank)
	await Game.travel("docks", "start")
	await _wait_s(1.4)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var cam2 := Camera3D.new()
	cam2.name = "GateCam2"
	get_tree().current_scene.add_child.call_deferred(cam2)
	await get_tree().process_frame
	var old2 := get_viewport().get_camera_3d()
	if old2:
		old2.current = false
	cam2.current = true
	# from the pier deck looking along the water + the far shore
	cam2.global_position = Vector3(-12.0, 1.6, -16.0)
	cam2.look_at(Vector3(-34.0, -0.2, -26.0))
	cam2.fov = 62.0
	await _wait_s(0.8)
	await _snap("river")
	await _wait_s(1.2)
	await _snap("river2")
	# --- SHOT 3: the club canyon (the glow/halo change's look check)
	await Game.travel("club_district", "start")
	await _wait_s(1.4)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var cam3 := Camera3D.new()
	cam3.name = "GateCam3"
	get_tree().current_scene.add_child.call_deferred(cam3)
	await get_tree().process_frame
	var old3 := get_viewport().get_camera_3d()
	if old3:
		old3.current = false
	cam3.current = true
	cam3.global_position = Vector3(-6.0, 3.0, 8.0)
	cam3.look_at(Vector3(-20.0, 3.5, -6.0))
	cam3.fov = 64.0
	await _wait_s(0.8)
	await _snap("club")
	get_tree().quit(0)


func _wait_s(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/gate_%s.png" % [OUT, name])
		print("  shot %s (%dx%d)" % [name, img.get_width(),
				img.get_height()])
