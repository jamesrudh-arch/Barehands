extends Node
const OUT := "/tmp/shots"
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1
func _env() -> Environment:
	for we in get_tree().get_nodes_in_group("world_env"):
		if we is WorldEnvironment:
			return (we as WorldEnvironment).environment
	var we := get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
	return (we[0] as WorldEnvironment).environment if we.size() > 0 else null
func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/grade_%s.png" % [OUT, name])
func _take_camera() -> Camera3D:
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old != null:
		old.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child.call_deferred(cam)
	await get_tree().process_frame
	cam.current = true
	return cam
func _ready() -> void:
	var dog := get_tree().create_timer(60.0, true, false, true)
	dog.timeout.connect(func(): get_tree().quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.2)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.5)
	var ws := get_tree().get_first_node_in_group("worldsim")
	ws.set_weather("rain")
	await _wait_s(0.8)
	var cam := await _take_camera()
	cam.global_position = Vector3(-12.0, 1.6, 4.0)
	cam.look_at(Vector3(-40.0, 0.8, 5.4))
	cam.fov = 65.0
	await _wait_s(0.6)
	var env := _env()
	print("GRADE env=%s" % str(env != null))
	if env == null:
		get_tree().quit(1)
		return
	await _snap("a_asis")
	env.fog_enabled = false
	await _wait_s(0.3)
	await _snap("b_nofog")
	env.glow_enabled = false
	await _wait_s(0.3)
	await _snap("c_nofog_noglow")
	env.fog_enabled = true
	env.glow_enabled = true
	print("GRADE done")
	get_tree().quit(0)
