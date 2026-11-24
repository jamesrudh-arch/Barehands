extends Node
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1
func _ready() -> void:
	var dog := get_tree().create_timer(60.0, true, false, true)
	dog.timeout.connect(func(): get_tree().quit(1))
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
	print("DBG scene=%s ws=%s" % [str(get_tree().current_scene), str(ws != null)])
	print("DBG weather now: %s" % str(WorldState.get_value("weather")))

	# decisive: look straight UP into the falling column
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old_cam := get_viewport().get_camera_3d()
	if old_cam != null:
		old_cam.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child.call_deferred(cam)
	await get_tree().process_frame
	cam.current = true
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	cam.global_position = hero.global_position + Vector3(0, 1.5, 0)
	cam.look_at(hero.global_position + Vector3(0.2, 9.0, 0.0))
	ws.set_weather("clear")
	await _wait_s(0.8)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/up_dry.png")
	ws.set_weather("rain")
	await _wait_s(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/up_wet.png")
	print("DBG up-shots saved (node=%s)" % str(
			get_tree().current_scene.get_node_or_null("RainColumn") != null))
	get_tree().quit(0)
