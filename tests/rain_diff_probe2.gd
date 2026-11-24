extends Node
const OUT := "/tmp/shots2"
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1
func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
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
	DirAccess.make_dir_recursive_absolute(OUT)
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.4)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	var ws := get_tree().get_first_node_in_group("worldsim")
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-14.0, 0.05, 5.2)
	var cam := await _take_camera()
	cam.global_position = Vector3(-12.0, 1.6, 4.0)
	cam.look_at(Vector3(-40.0, 0.8, 5.4))
	cam.fov = 65.0
	# rain OFF
	ws.set_weather("clear")
	await _wait_s(1.0)
	await _snap("diff_dry")
	# rain ON
	ws.set_weather("rain")
	await _wait_s(1.2)
	await _snap("diff_wet")
	# particles emitting?
	var rc := get_tree().current_scene.get_node_or_null("RainColumn") as CPUParticles3D
	print("RAINCOLUMN exists=%s emitting=%s amount=%d pos=%s" % [
			str(rc != null), str(rc.emitting if rc else false),
			rc.amount if rc else -1,
			str(rc.global_position) if rc else "?"])
	get_tree().quit(0)
