extends Node

## THE OVERHAUL AUDIT CAPTURE: real gameplay frames from every area
## plus character/vehicle close-ups - the visual quality report's
## evidence. Saved to /tmp/shots and copied into the audit folder.

const OUT := "/tmp/shots"
var _shots := 0


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	print("PH0 start")
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	holder.name = "SuiteHolder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder

	# 1 the title (menu + the 3D backdrop drift)
	print("PH1 go_menu")
	Game.go_menu()
	await _wait_s(2.0)
	print("PH1 waited")
	await _snap("01_title_menu")
	print("PH1 snapped")

	# 2 the home (warehouse loft + training corner)
	print("PH2 travel")
	await Game.travel("warehouse", "start")
	print("PH2 landed")
	await _wait_s(1.5)
	await _snap("02_home_warehouse")

	# 3-4 the neighbourhood at night: establishing + the new hero
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.5)
	# composed from street facts: the road runs X -60..60, the LIT
	# lamp row is z=+7 (posts at x -48/-16/16/48). Stand west on the
	# south walk, look east DOWN the lit line, hero placed in frame.
	var hero2 := get_tree().get_first_node_in_group("player") as Node3D
	hero2.global_position = Vector3(-30.0, 0.05, 6.2)
	hero2.rotation.y = PI / 2.0
	await _wait_s(0.4)
	var cam := await _take_camera()
	cam.fov = 55.0
	cam.global_position = Vector3(-46.0, 2.6, 10.8)
	cam.look_at(Vector3(24.0, 1.5, 7.4))
	await _snap("03_street_night")
	await _aim_at_player(Vector3(0.9, 1.5, 1.6), 50.0)
	await _snap("04_hero_closeup")

	print("AUDIT CAPTURE DONE (%d shots)" % _shots)
	get_tree().quit(0)


func _snap(name: String) -> void:
	print("  snap %s: frames" % name)
	await get_tree().process_frame
	await get_tree().process_frame
	print("  snap %s: get_image..." % name)
	var img := get_viewport().get_texture().get_image()
	print("  snap %s: got it" % name)
	if img != null:
		img.save_png("%s/%s.png" % [OUT, name])
		_shots += 1
		print("  shot %s (%dx%d)" % [name, img.get_width(), img.get_height()])


## park a fresh camera near the hero's head looking back at the face
func _aim_at_player(offset: Vector3, fov: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		return
	var cam := await _take_camera()
	cam.fov = fov
	cam.global_position = hero.global_position + offset
	cam.look_at(hero.global_position + Vector3(0, 1.55, 0))


## park a fresh camera at a world point looking at another point
func _aim_at_world(eye: Vector3, at: Vector3, fov: float) -> void:
	var cam := await _take_camera()
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(at)


func _take_camera() -> Camera3D:
	# THE RIG LAW (S5.2, probe-caught): camera_rig._process calls
	# make_current() EVERY FRAME - any other camera is instantly
	# overridden. Silence the rig first.
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old != null:
		old.current = false
	var cam := Camera3D.new()
	cam.name = "AuditCam"
	get_tree().current_scene.add_child.call_deferred(cam)
	await get_tree().process_frame
	cam.current = true
	return cam
