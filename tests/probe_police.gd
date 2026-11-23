extends Node
## S5.4 HEAT GATE: THE COPY comes for the hero, the HUD wears the
## heat pips - framed for the VLM.
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
	await Game.travel("warehouse", "start")
	await _wait_s(1.5)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	# heat past copy_at -> the tier check summons it
	WorldState.set_value("heat", 5.5)
	await _wait_s(0.5)
	var copy: CharacterBody3D = null
	for n in get_tree().get_nodes_in_group("npc"):
		if "Copy" in n.name:
			copy = n
	if copy == null:
		print("POLICE GATE FAIL: no copy")
		get_tree().quit(1)
		return
	print("POLICE GATE copy at %.1fm" % copy.global_position.distance_to(
			hero.global_position))
	# STAGE it at a known-open spot (the pistol-probe's thug spot,
	# the open hall) - a random 14m spawn can land behind pillars
	copy.global_position = hero.global_position + Vector3(-5.0, 0, 0)
	copy.set_physics_process(false)
	await _wait_s(0.6)
	for r in get_tree().get_nodes_in_group("camera_rig"):
		r.set_process(false)
	var old := get_viewport().get_camera_3d()
	if old:
		old.current = false
	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	await get_tree().process_frame
	cam.fov = 52.0
	cam.current = true
	# side-on: hero left, copy right
	# the fight-probe's proven side-on (composed cameras are a
	# graveyard - only known-clear coordinates survive)
	cam.global_position = hero.global_position + Vector3(3.0, 2.0, 3.4)
	cam.look_at(hero.global_position + Vector3(-2.6, 1.25, 0))
	await _wait_s(0.4)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/police_copy.png")
	print("POLICE GATE captured (heat pips=%d)" % ceili(
			float(WorldState.get_value("heat", 0.0))))
	get_tree().quit(0)
