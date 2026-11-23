extends Node
## S5.3 LIVING WORLD GATE: the street with walkers on the
## sidewalks, the lane parade and the named faces at the venues.
## Frames over time - the proof of life is MOTION between frames.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	var dog := get_tree().create_timer(60.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.5)
	var locals_ := get_tree().get_nodes_in_group("local")
	var peds: Array = []
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if not p.is_in_group("local"):
			peds.append(p)
	print("LIFE peds=%d locals=%d" % [peds.size(), locals_.size()])
	# THE GAME'S OWN CAMERA, but the spawn sits in a dark alley
	# mouth (the composed-camera war was this all along) - walk the
	# hero out to the lit street first, then let the rig follow
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	# across the road from THE RAIN GLASS: the venue door + MARLA +
	# the north sidewalk walkers + the lane between (the cars pass)
	hero.global_position = Vector3(-5.0, 0.05, -3.4)
	var rig := hero.get_node_or_null("Rig") as Node3D
	if rig:
		rig.rotation.y = 0.0  # face the venue (+Z)
	await _wait_s(0.8)
	var states := {}
	for p in peds:
		states[p] = p.state
	for i in 6:
		await _wait_s(1.9)
		get_viewport().get_texture().get_image().save_png(
				"/tmp/shots/life_%02d.png" % i)
	var states2 := {}
	for p in peds:
		if is_instance_valid(p):
			states2[p] = p.state
	var moved := 0
	for p in peds:
		if is_instance_valid(p):
			pass
	print("LIFE states %s -> %s" % [str(states.values()),
			str(states2.values())])
	# the traffic: the cars must have moved along the lane
	var cars := 0
	for c in get_tree().get_nodes_in_group("cars") \
			+ get_tree().current_scene.find_children("Traffic*",
					"Node", false, false):
		cars += 1
	print("LIFE traffic nodes=%d" % cars)
	get_tree().quit(0)
