extends Node

## THE S5.18 GATE: the cold open mid-call + the elevated train
## mid-crossing, for the VLM read. Same boot pattern as the
## other gates (SuiteHolder owns current_scene).

const OUT := "/tmp/shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	Settings.set_value("skip_intro", false)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	# --- SHOTS 1-2: the call, early and deep
	await _wait_s(2.4)
	await _snap("intro_early")
	await _wait_s(8.0)
	await _snap("intro_call")
	# end the call deterministically
	var co := get_tree().root.find_child("ColdOpen", true, false)
	if co:
		co.call("_end")
	await _wait_s(0.6)
	# --- SHOT 3: the train mid-crossing
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.2)
	var t := get_tree().current_scene.find_child("ElTrain", true,
			false) as Node
	if t:
		t.set("_t_until", 0.05)
		await _wait_s(0.35)   # departed, mid-street
		t.set_process(false)  # FREEZE it there - deterministic shot
		var hero := get_tree().get_first_node_in_group(
				"player") as Node3D
		hero.global_position = Vector3(-14.0, 0.05, 3.0)
		hero.rotation.y = 0.0
		# the rig steals current back every frame via make_current()
		# - freeze it first (the law from gate_capture)
		for r in get_tree().get_nodes_in_group("camera_rig"):
			r.set_process(false)
		var tcam := Camera3D.new()
		tcam.name = "TrainCam"
		get_tree().current_scene.add_child.call_deferred(tcam)
		await get_tree().process_frame
		var oldc := get_viewport().get_camera_3d()
		if oldc:
			oldc.current = false
		tcam.current = true
		# street-level vantage, clear line: ON the street, south
		# of the rail, looking up at the frozen lead car (the
		# earlier vantage sat inside a south-front wall and shot
		# the BUILDING - the black mass was never the train)
		var ts := t.get_node("TrainSet") as Node3D
		tcam.global_position = ts.global_position \
				+ Vector3(11.5, -7.6, 5.5)
		tcam.look_at(ts.global_position + Vector3(0, 9.9, -7.5))
		tcam.fov = 60.0
		await _wait_s(0.5)
		print("  TRAIN dbg: pos=", ts.global_position,
			" visible=", ts.visible,
			" cars=", ts.get_child_count())
		await _snap("el_train")
	# --- SHOT 4: the critter street (moths at the lamp heads)
	var lamp: Node3D = null
	for n in get_tree().current_scene.get_children():
		if str(n.name).begins_with("LampCone"):
			lamp = n as Node3D
			break
	if lamp == null:
		var found: Array = []
		_find_cones(get_tree().current_scene, found)
		if not found.is_empty():
			lamp = found[0] as Node3D
	if lamp:
		var cam := Camera3D.new()
		cam.name = "GateCam"
		get_tree().current_scene.add_child.call_deferred(cam)
		await get_tree().process_frame
		var old := get_viewport().get_camera_3d()
		if old:
			old.current = false
		cam.current = true
		cam.global_position = lamp.global_position \
				+ Vector3(1.6, -0.4, 1.8)
		cam.look_at(lamp.global_position + Vector3(0, -0.5, 0))
		await _wait_s(0.4)
		await _snap("critter_lamp")
	get_tree().quit(0)


func _find_cones(n: Node, out: Array) -> void:
	if str(n.name).begins_with("LampCone"):
		out.append(n)
	for c in n.get_children():
		_find_cones(c, out)


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
