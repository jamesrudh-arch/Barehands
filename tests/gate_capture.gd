extends Node

## THE S5 GATE CAPTURE: the four outstanding visual gates - the
## rain on the street, the MAP app, the BOARD app, THE CHOICE.
const OUT := "/tmp/shots"

func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [OUT, name])
		print("  shot %s (%dx%d)" % [name, img.get_width(),
				img.get_height()])


func _take_camera() -> Camera3D:
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old != null:
		old.current = false
	var cam := Camera3D.new()
	cam.name = "GateCam"
	get_tree().current_scene.add_child.call_deferred(cam)
	await get_tree().process_frame
	cam.current = true
	return cam


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.4)

	# 1) THE RAIN on the lit street (the signature look)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	var ws := get_tree().get_first_node_in_group("worldsim")
	ws.set_weather("rain")
	await _wait_s(0.8)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-14.0, 0.05, 5.2)
	hero.rotation.y = PI  # face west, down-street
	await _wait_s(0.4)
	var cam := await _take_camera()
	cam.global_position = Vector3(-12.0, 1.9, 2.6)
	cam.look_at(Vector3(-30.0, 3.2, 5.6))
	cam.fov = 65.0
	await _wait_s(0.6)
	await _snap("gate_rain")

	# 2) THE MAP app
	var ph := get_tree().get_first_node_in_group("phone")
	ph.open(false)
	await _wait_s(0.4)
	ph._set_tab("MAP")
	await _wait_s(0.5)
	await _snap("gate_map")
	ph.close()

	# 3) THE BOARD app (two linked VESPER clues + one stale)
	var lv := get_tree().get_first_node_in_group("leverage")
	lv._add_clue("VESPER", "the rumour",
			"Vesper's books have two sets of numbers.")
	lv._add_clue("VESPER", "the rumour",
			"The back room pays the Corporation's collectors.")
	lv._add_clue("TONY", "the rumour", "Tony's gym launders the weight.")
	ph.open(false)
	await _wait_s(0.3)
	ph._set_tab("BOARD")
	await _wait_s(0.4)
	await _snap("gate_board")
	ph.close()

	# 4) THE CHOICE (k4's call, typed out, choices visible)
	var ms := get_tree().get_first_node_in_group("missions")
	ms.start("res://data/missions/k4.tres")
	await _wait_s(0.8)
	ph.open(false)
	ph._set_tab("CALLS")
	await _wait_s(0.3)
	ph._answer()
	await _wait_s(11.0)  # the typewriter finishes, the buttons land
	await _snap("gate_choice")

	print("GATE CAPTURES DONE")
	get_tree().quit(0)
