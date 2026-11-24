extends Node
const OUT := "/tmp/shots2"
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, s)).timeout
		s = 0.0
		left -= 0.1
func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/iso_%s.png" % [OUT, name])
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
	await get_tree().create_timer(1.2).timeout
	await Game.travel("neighbourhood", "start")
	await get_tree().create_timer(1.5).timeout
	var ws := get_tree().get_first_node_in_group("worldsim")
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	hero.global_position = Vector3(-14.0, 0.05, 5.2)
	ws.set_weather("rain")
	await get_tree().create_timer(1.2).timeout
	var cam := await _take_camera()
	cam.global_position = Vector3(-10.0, 1.8, 3.4)
	cam.look_at(Vector3(-40.0, 0.8, 5.4))
	cam.fov = 65.0
	await get_tree().create_timer(0.5).timeout
	var rc := get_tree().current_scene.get_node_or_null("RainColumn") as CPUParticles3D
	print("ISO column=%s emitting=%s amount=%d visible=%s" % [
			str(rc != null), str(rc.emitting if rc else false),
			rc.amount if rc else -1, str(rc.visible if rc else false)])
	await _snap("on")
	if rc:
		rc.visible = false
	await get_tree().create_timer(0.4).timeout
	await _snap("off")
	print("ISO done")
	get_tree().quit(0)
