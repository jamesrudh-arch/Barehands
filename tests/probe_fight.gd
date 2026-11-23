extends Node
## S5.1c FIGHT GATE: the RPM hero vs the Michelle thug - real AI,
## real retargeted clips on both sides. Captures the exchange for
## the VLM: "two realistic humans fighting?"
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("warehouse", "start")
	await _wait_s(1.2)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var cls := load("res://scripts/npc/enemy.gd")
	var thug: CharacterBody3D = cls.new()
	# into the open hall, away from the training corner (+X side)
	thug.position = hero.position + Vector3(-2.6, 0, 0.5)
	holder.add_child(thug) if false else get_tree().current_scene.add_child(thug)
	await _wait_s(0.3)
	# the capture camera (the rig-silencing law + look_at after
	# add_child + one frame)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	await get_tree().process_frame
	cam.fov = 50.0
	cam.current = true
	# frame BOTH fighters: camera to the side of the hero->thug
	# line, looking at the midpoint (the fixed-camera law: the
	# first attempt framed empty floor + the training corner)
	# the proven s51c punch-camera angle, widened for the pair
	cam.global_position = hero.global_position + Vector3(3.2, 2.0, 3.0)
	cam.look_at(hero.global_position + Vector3(-0.9, 1.3, 0.1))
	# BURST 1: the hero punches (the 0.18s swing windows cannot be
	# caught by coarse sampling - probe-caught: 4 frames of idles)
	Input.action_press("punch")
	await get_tree().process_frame
	Input.action_release("punch")
	var hp0 := thug.hp
	for i in 4:
		await _wait_s(0.13)
		cam.global_position = hero.global_position + Vector3(3.2, 2.0, 3.0)
		cam.look_at(hero.global_position + Vector3(-0.9, 1.3, 0.1))
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/fight_hero_%02d.png" % i)
	print("FIGHT hero-punch thug hp %.0f -> %.0f" % [hp0, thug.hp])
	# BURST 2: the thug's SWING, frame-caught
	var waited := 0.0
	while thug.state != 5 and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	for i in 3:
		await _wait_s(0.07)
		cam.global_position = hero.global_position + Vector3(3.2, 2.0, 3.0)
		cam.look_at(hero.global_position + Vector3(-0.9, 1.3, 0.1))
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/fight_thug_%02d.png" % i)
	print("FIGHT thug-swing caught state=%s hp=%.0f" % [
			thug.state, thug.hp])
	get_tree().quit(0)
